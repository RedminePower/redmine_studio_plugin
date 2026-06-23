# frozen_string_literal: true

# Cache Bundle API
#
# Redmine Studio (Windows クライアント) のキャッシュ更新を 1 リクエストで完結させるエンドポイント。
# 以下のセクションを 1 つの JSON で返す:
#   - markup_lang
#   - projects（trackers / enabled_modules / issue_categories / time_entry_activities / issue_custom_fields 込み）
#   - trackers / issue_statuses / issue_priorities / time_entry_activities / queries / custom_fields / users / roles / groups
#   - project_memberships / project_versions / project_issue_categories（プロジェクト ID をキーとした dict）
#   - errors（部分失敗のメタデータ）
#
# 部分失敗時はステータス 200 を返しつつ、失敗したセクションは空配列で埋め errors に記録する。
# レスポンスは Accept-Encoding: gzip があれば gzip 圧縮して返す（Apache の mod_deflate に依存しない）。
class CacheBundlesController < ApplicationController
  accept_api_auth :show

  # GET /cache_bundle?user_id=N
  def show
    target_user = resolve_target_user
    return if performed?

    @errors = []

    bundle = {
      markup_lang:              with_error_handling('markup_lang')              { fetch_markup_lang },
      projects:                 with_error_handling('projects')                 { fetch_projects },
      trackers:                 with_error_handling('trackers')                 { fetch_trackers },
      issue_statuses:           with_error_handling('issue_statuses')           { fetch_issue_statuses },
      issue_priorities:         with_error_handling('issue_priorities')         { fetch_issue_priorities },
      time_entry_activities:    with_error_handling('time_entry_activities')    { fetch_time_entry_activities },
      queries:                  with_error_handling('queries')                  { fetch_queries(target_user) },
      custom_fields:            with_error_handling('custom_fields')            { fetch_custom_fields },
      users:                    with_error_handling('users')                    { fetch_users },
      roles:                    with_error_handling('roles')                    { fetch_roles },
      groups:                   with_error_handling('groups')                   { fetch_groups },
      project_memberships:      fetch_per_project_memberships(target_user),
      project_versions:         fetch_per_project_versions(target_user),
      project_issue_categories: fetch_per_project_issue_categories(target_user),
      errors:                   @errors
    }

    send_bundle(bundle)
  end

  private

  # ---- 共通 ------------------------------------------------------------

  # user_id パラメータからスコープ解決対象のユーザを決定する。
  # 省略時は User.current（accept_api_auth で認証済み）。
  # 非 admin ユーザは自分以外の user_id を指定不可。
  def resolve_target_user
    return User.current if params[:user_id].blank?

    user = User.find_by(id: params[:user_id])
    if user.nil?
      respond_to { |format| format.api { render_api_errors("user_id #{params[:user_id]} not found") } }
      return nil
    end
    if !User.current.admin? && user.id != User.current.id
      respond_to { |format| format.api { render_api_errors('user_id mismatch: non-admin can only request own user') } }
      return nil
    end
    user
  end

  def with_error_handling(section)
    yield
  rescue => e
    Rails.logger.warn "cache_bundle: section '#{section}' failed: #{e.class} #{e.message}"
    @errors << { section: section, code: 500, message: "#{e.class}: #{e.message}" }
    section == 'markup_lang' ? nil : []
  end

  def send_bundle(bundle)
    payload = { cache_bundle: bundle }

    if request.accept_encoding.to_s.include?('gzip')
      json = payload.to_json
      compressed = ActiveSupport::Gzip.compress(json)
      response.headers['Content-Encoding'] = 'gzip'
      response.headers['Vary'] = 'Accept-Encoding'
      Rails.logger.info "cache_bundle: response size raw=#{json.bytesize} bytes, gzipped=#{compressed.bytesize} bytes"
      render plain: compressed, content_type: 'application/json'
    else
      json = payload.to_json
      Rails.logger.info "cache_bundle: response size raw=#{json.bytesize} bytes (no compression)"
      render plain: json, content_type: 'application/json'
    end
  end

  # ---- 各セクションの取得 -----------------------------------------------

  def fetch_markup_lang
    Setting.text_formatting
  end

  # Project 一覧（全 status、include: trackers / enabled_modules / issue_categories / time_entry_activities / issue_custom_fields）。
  # アプリ側（RedmineTimePuncher の CacheService.projectsPrms）と同等の include 構成。
  def fetch_projects
    Project.where(status: [Project::STATUS_ACTIVE, Project::STATUS_CLOSED, Project::STATUS_ARCHIVED])
           .preload(:trackers, :enabled_modules, :issue_categories, :parent)
           .map do |p|
      hash = {
        id: p.id,
        name: p.name,
        identifier: p.identifier,
        description: p.description,
        homepage: p.homepage,
        status: p.status,
        is_public: p.is_public,
        inherit_members: p.inherit_members,
        created_on: p.created_on,
        updated_on: p.updated_on,
        trackers: p.trackers.map { |t| { id: t.id, name: t.name } },
        enabled_modules: p.enabled_modules.map { |m| { id: m.id, name: m.name } },
        issue_categories: p.issue_categories.map { |c| { id: c.id, name: c.name } },
        time_entry_activities: p.activities(true).map { |a| { id: a.id, name: a.name } },
        issue_custom_fields: p.issue_custom_fields.map { |cf| { id: cf.id, name: cf.name } }
      }
      hash[:parent] = { id: p.parent.id, name: p.parent.name } if p.parent
      hash
    end
  end

  def fetch_trackers
    Tracker.preload(:default_status).map do |t|
      hash = { id: t.id, name: t.name }
      hash[:default_status] = { id: t.default_status.id, name: t.default_status.name } if t.default_status
      hash[:description] = t.description if t.description.present?
      hash
    end
  end

  def fetch_issue_statuses
    IssueStatus.sorted.map do |s|
      { id: s.id, name: s.name, is_closed: s.is_closed }
    end
  end

  def fetch_issue_priorities
    IssuePriority.active.map do |p|
      hash = { id: p.id, name: p.name }
      hash[:is_default] = true if p.is_default?
      hash
    end
  end

  def fetch_time_entry_activities
    TimeEntryActivity.active.map do |a|
      hash = { id: a.id, name: a.name }
      hash[:is_default] = true if a.is_default?
      hash
    end
  end

  def fetch_queries(user)
    base = IssueQuery.visible(user)
    base.map do |q|
      hash = { id: q.id, name: q.name, is_public: q.visibility != IssueQuery::VISIBILITY_PRIVATE }
      hash[:project_id] = q.project_id if q.project_id
      hash
    end
  end

  # 全 CustomField（admin 権限が必要）。caller が admin でなければ空配列で返す（現状の app 側挙動と同等）。
  def fetch_custom_fields
    return [] unless User.current.admin?

    CustomField.all.map do |cf|
      hash = {
        id: cf.id,
        name: cf.name,
        customized_type: cf.class.customized_class.name.underscore,
        field_format: cf.field_format,
        regexp: cf.regexp,
        min_length: cf.min_length || 0,
        max_length: cf.max_length || 0,
        is_required: cf.is_required,
        is_filter: cf.is_filter,
        searchable: cf.searchable,
        multiple: cf.multiple,
        default_value: cf.default_value,
        visible: cf.visible
      }
      if cf.possible_values.is_a?(Array) && cf.possible_values.any?
        hash[:possible_values] = cf.possible_values.map { |v| { value: v } }
      end
      if cf.respond_to?(:trackers) && cf.trackers.any?
        hash[:trackers] = cf.trackers.map { |t| { id: t.id, name: t.name } }
      end
      if cf.respond_to?(:roles) && cf.roles.any?
        hash[:roles] = cf.roles.map { |r| { id: r.id, name: r.name } }
      end
      hash
    end
  end

  # 全 User（ロックユーザ含む）。admin 権限が必要。caller が admin でなければ空配列で返す。
  def fetch_users
    return [] unless User.current.admin?

    User.where(type: 'User').preload(:memberships).map { |u| user_to_hash(u) }
  end

  def user_to_hash(u)
    hash = {
      id: u.id,
      login: u.login,
      firstname: u.firstname,
      lastname: u.lastname,
      created_on: u.created_on
    }
    hash[:mail] = u.mail if u.mail.present?
    hash[:last_login_on] = u.last_login_on if u.last_login_on
    hash[:status] = u.status if u.status
    hash[:admin] = u.admin? if u.admin?
    # API キーと auth_source などは現状の app 側で使っていないので含めない
    hash
  end

  # Role 一覧 + 各 Role の詳細（permissions）。
  # 現状 CacheService は GetObjects + 各 GetObject(id) の N+1 だが、ここでサーバ側でまとめて返す。
  def fetch_roles
    Role.all.map do |r|
      hash = {
        id: r.id,
        name: r.name,
        assignable: r.assignable,
        issues_visibility: r.issues_visibility,
        time_entries_visibility: r.time_entries_visibility,
        users_visibility: r.users_visibility
      }
      # 個別取得（GetObject<Role>(id)）で取れる permissions を含める
      hash[:permissions] = (r.permissions || []).map { |p| { info: p.to_s } }
      hash
    end
  end

  # Group 一覧 + 各 Group の詳細（users 含む）。admin 権限が必要。
  def fetch_groups
    return [] unless User.current.admin?

    Group.preload(:users).map do |g|
      hash = { id: g.id, name: g.name }
      hash[:users] = g.users.map { |u| { id: u.id, name: u.name } }
      hash
    end
  end

  # ---- per-project セクション ------------------------------------------

  # 対象ユーザが member となっているプロジェクトの ID 集合を返す。
  def visible_project_ids(user)
    return [] unless user

    user.memberships.map(&:project_id).uniq
  end

  # ProjectMemberships: { project_id => [...] }
  # ロックユーザの membership は除外する（現状の CacheService.updateProjectMembershipsAsync と同等）。
  def fetch_per_project_memberships(user)
    result = {}
    visible_project_ids(user).each do |pid|
      begin
        members = Member.where(project_id: pid).preload(:user, :roles).map do |m|
          h = {
            id: m.id,
            project: { id: pid, name: m.project.name },
            roles: m.roles.map { |r| { id: r.id, name: r.name, inherited: m.member_roles.find { |mr| mr.role_id == r.id }&.inherited_from.present? || false } }
          }
          if m.user.is_a?(User) && m.user.status != User::STATUS_LOCKED
            h[:user] = { id: m.user.id, name: m.user.name }
          elsif m.principal.is_a?(Group)
            h[:group] = { id: m.principal.id, name: m.principal.name }
          else
            # ロックユーザのみの membership はスキップ
            next nil
          end
          h
        end.compact
        result[pid.to_s] = members
      rescue => e
        Rails.logger.warn "cache_bundle: project_memberships project_id=#{pid} failed: #{e.class} #{e.message}"
        @errors << { section: 'project_memberships', project_id: pid, code: 500, message: "#{e.class}: #{e.message}" }
        result[pid.to_s] = []
      end
    end
    result
  end

  # ProjectVersions: { project_id => [...] }
  def fetch_per_project_versions(user)
    result = {}
    visible_project_ids(user).each do |pid|
      begin
        versions = Version.where(project_id: pid).map do |v|
          h = {
            id: v.id,
            project: { id: pid, name: v.project.name },
            name: v.name,
            description: v.description,
            status: v.status,
            sharing: v.sharing,
            created_on: v.created_on,
            updated_on: v.updated_on
          }
          h[:due_date] = v.due_date if v.due_date
          h[:wiki_page_title] = v.wiki_page_title if v.wiki_page_title.present?
          h
        end
        result[pid.to_s] = versions
      rescue => e
        Rails.logger.warn "cache_bundle: project_versions project_id=#{pid} failed: #{e.class} #{e.message}"
        @errors << { section: 'project_versions', project_id: pid, code: 500, message: "#{e.class}: #{e.message}" }
        result[pid.to_s] = []
      end
    end
    result
  end

  # ProjectIssueCategories: { project_id => [...] }
  # Active なプロジェクトのみが対象（現状 CacheService.updateProjectIssueCategoriesAsync の Status == Active フィルタ相当）。
  def fetch_per_project_issue_categories(user)
    result = {}
    active_project_ids = Project.where(id: visible_project_ids(user), status: Project::STATUS_ACTIVE).pluck(:id)
    active_project_ids.each do |pid|
      begin
        categories = IssueCategory.where(project_id: pid).preload(:assigned_to).map do |c|
          h = {
            id: c.id,
            project: { id: pid, name: c.project.name },
            name: c.name
          }
          h[:assigned_to] = { id: c.assigned_to.id, name: c.assigned_to.name } if c.assigned_to
          h
        end
        result[pid.to_s] = categories
      rescue => e
        Rails.logger.warn "cache_bundle: project_issue_categories project_id=#{pid} failed: #{e.class} #{e.message}"
        @errors << { section: 'project_issue_categories', project_id: pid, code: 500, message: "#{e.class}: #{e.message}" }
        result[pid.to_s] = []
      end
    end
    result
  end
end
