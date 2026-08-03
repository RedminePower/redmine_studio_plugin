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
      projects:                 with_error_handling('projects')                 { fetch_projects(target_user) },
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

  # 日時を Redmine コア API (Redmine::Views::Builders::Structure の xmlschema(0)) と同じ
  # 「小数秒なし」で整形する。to_json 既定（ミリ秒付き）だと個別 API とタイムスタンプ表現が
  # 食い違い、クライアントの日時パースがずれるため揃える。
  def to_api_time(t)
    t&.xmlschema(0)
  end

  # カスタムフィールド値を Redmine コア API (render_api_custom_values) と同じ形で出力する。
  # 個別 API (XML) の custom_fields と同一構造にすることで、cache_bundle 経由でも
  # redmine-net-api が同じ CacheBundle を復元できるようにする。
  # value は単一値ならスカラー、複数値なら配列。値が無い（visible な CF が 0 件）の場合は
  # 空配列を返し、呼び出し側で custom_fields キー自体を省略する（コアの unless empty? と揃える）。
  def to_api_custom_field_values(custom_values)
    custom_values.map do |cv|
      h = { id: cv.custom_field_id, name: cv.custom_field.name }
      h[:multiple] = true if cv.custom_field.multiple?
      h[:value] = cv.value
      h
    end
  end

  # ---- 各セクションの取得 -----------------------------------------------

  def fetch_markup_lang
    Setting.text_formatting
  end

  # Project 一覧（target_user が可視できるプロジェクトのみ。include: trackers / enabled_modules / issue_categories / time_entry_activities / issue_custom_fields）。
  # 個別 API (GET /projects.json) と同等の可視性スコープ (Project.visible)。
  # SQL レベルで status IN (1, 5) が強制されるため、Archived (status=9) は含まれない。
  def fetch_projects(target_user)
    # 並び順も個別 API に揃える。projects#index は ProjectQuery 経由で lft 順（Project.sorted）で返すため、
    # ここでも .sorted（order(:lft)）を適用して要素順を一致させる。
    projects = Project.visible(target_user)
                      .sorted
                      .preload(:enabled_modules, :issue_categories, :parent, :issue_custom_fields)
                      .to_a
    pids = projects.map(&:id)

    # per-project の N+1 を畳む。可視プロジェクト id 集合（parent 可視判定に流用）、
    # activities（システム活動 1 回＋プロジェクト上書きを IN で一括）、for_all の issue CF（1 回）を先に用意。
    visible_ids = pids.to_set
    activities_by_pid = build_project_activities(pids)
    for_all_issue_cfs = IssueCustomField.sorted.where(is_for_all: true).to_a

    projects.map do |p|
      hash = {
        id: p.id,
        name: p.name,
        identifier: p.identifier,
        description: p.description,
        homepage: p.homepage,
        status: p.status,
        is_public: p.is_public,
        inherit_members: p.inherit_members,
        created_on: to_api_time(p.created_on),
        updated_on: to_api_time(p.updated_on),
        # 個別 API (render_api_includes) と揃える。trackers は rolled_up_trackers(false).visible
        # （issue_tracking モジュール有効＋対象ユーザの view_issues 可視性でフィルタ）。
        # プロジェクトごとにロール×可視性で SQL が変わり畳めないため per-project のまま据え置く。
        trackers: p.rolled_up_trackers(false).visible(target_user).map { |t| { id: t.id, name: t.name } },
        enabled_modules: p.enabled_modules.map { |m| { id: m.id, name: m.name } },
        issue_categories: p.issue_categories.map { |c| { id: c.id, name: c.name } },
        # time_entry_activities は activities（アクティブのみ）。上で一括取得した辞書から引く。
        time_entry_activities: activities_by_pid[p.id].map { |a| { id: a.id, name: a.name } },
        # 個別 API (GET /projects.json?include=issue_custom_fields) は all_issue_custom_fields
        # （is_for_all の CF も含む）を返す。for_all＋当該プロジェクト明示紐付け（preload 済み）をマージして揃える。
        issue_custom_fields: merge_issue_custom_fields(for_all_issue_cfs, p.issue_custom_fields).map { |cf| { id: cf.id, name: cf.name } }
      }
      # 個別 API (projects/index.api.rsb) は parent.visible? のときだけ親を出す。
      # parent.visible? は allowed_to?(:view_project) で Project.visible スコープと同一判定のため、
      # 可視プロジェクト id 集合に parent_id が含まれるかで厳密等価に判定（per-project クエリを廃止）。
      hash[:parent] = { id: p.parent.id, name: p.parent.name } if p.parent_id && visible_ids.include?(p.parent_id)
      hash
    end
  end

  # 各プロジェクトの time_entry_activities（Project#activities＝アクティブのみ）を一括算出する。
  # システム活動（project_id IS NULL）を 1 回、プロジェクト個別活動を IN で 1 回取得し、
  # プロジェクトごとに「上書き元（parent_id）を除いたシステム活動＋自プロジェクトのアクティブ活動」を組む。
  # 戻り値: { project_id => [TimeEntryActivity...] }
  def build_project_activities(pids)
    system_active = TimeEntryActivity.where(project_id: nil).active.to_a
    # 個別活動は inactive も取る（上書き元 parent_id の算出に必要。出力には active のみ使う）。
    project_acts_by_pid = TimeEntryActivity.where(project_id: pids).group_by(&:project_id)

    pids.index_with do |pid|
      own = project_acts_by_pid[pid] || []
      overridden_parent_ids = own.map(&:parent_id).compact
      system_part = overridden_parent_ids.empty? ? system_active : system_active.reject { |a| overridden_parent_ids.include?(a.id) }
      (system_part + own.select(&:active?)).sort_by(&:position)
    end
  end

  # for_all の issue CF と、プロジェクトに明示紐付けされた issue CF をマージする（Project#all_issue_custom_fields 相当）。
  def merge_issue_custom_fields(for_all_issue_cfs, project_issue_cfs)
    (for_all_issue_cfs + project_issue_cfs).uniq.sort_by(&:position)
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

  # 個別 API (GET /enumerations/issue_priorities.json) と同じく shared.sorted で全件（inactive 含む）を返し、
  # active キーも付与する。
  def fetch_issue_priorities
    IssuePriority.shared.sorted.map do |p|
      hash = { id: p.id, name: p.name, active: p.active }
      hash[:is_default] = true if p.is_default?
      hash
    end
  end

  # 個別 API (GET /enumerations/time_entry_activities.json) と同じく shared.sorted で全件（inactive 含む）を返し、
  # active キーも付与する。
  def fetch_time_entry_activities
    TimeEntryActivity.shared.sorted.map do |a|
      hash = { id: a.id, name: a.name, active: a.active }
      hash[:is_default] = true if a.is_default?
      hash
    end
  end

  # 本体 queries API と同じく、is_public は VISIBILITY_PUBLIC のみ true とする。
  # （VISIBILITY_ROLES は「特定ロールにのみ公開」で is_public=false 扱い）
  def fetch_queries(user)
    # 並び順も個別 API に揃える（queries#index は order("#{Query.table_name}.name") で name 順）。
    base = IssueQuery.visible(user).order(:name)
    base.map do |q|
      hash = { id: q.id, name: q.name, is_public: q.visibility == IssueQuery::VISIBILITY_PUBLIC }
      hash[:project_id] = q.project_id if q.project_id
      hash
    end
  end

  # CustomField 一覧。非 admin は CustomField.visible（visible=true の CF＋自分のロールに紐づく role 限定 CF）に
  # 絞り、admin は全件。全 customized 型を返す（アプリが IsIssueType() で client filter するため shape を揃える）。
  def fetch_custom_fields
    fields = (User.current.admin? ? CustomField.all : CustomField.visible(User.current)).preload(:roles).to_a

    # trackers は IssueCustomField 限定の関連のため、混在集合に preload できない。
    # issue CF の id だけ抜き、trackers を別クエリで preload して id→trackers 辞書にする（per-CF N+1 を回避）。
    trackers_by_cf = {}
    issue_cf_ids = fields.select { |cf| cf.is_a?(IssueCustomField) }.map(&:id)
    IssueCustomField.where(id: issue_cf_ids).preload(:trackers).each do |icf|
      trackers_by_cf[icf.id] = icf.trackers
    end

    fields.map do |cf|
      hash = {
        id: cf.id,
        name: cf.name,
        customized_type: cf.class.customized_class.name.underscore,
        field_format: cf.field_format,
        regexp: cf.regexp,
        min_length: cf.min_length,
        max_length: cf.max_length,
        is_required: cf.is_required,
        is_filter: cf.is_filter,
        searchable: cf.searchable,
        multiple: cf.multiple,
        default_value: cf.default_value,
        visible: cf.visible
      }
      values = cf.possible_values_options
      if values.present?
        hash[:possible_values] = values.map do |label, value|
          { value: value || label, label: label }
        end
      end
      cf_trackers = trackers_by_cf[cf.id]
      if cf_trackers.present?
        hash[:trackers] = cf_trackers.map { |t| { id: t.id, name: t.name } }
      end
      # roles は基底 CustomField の関連。preload(:roles) 済みのため追加クエリなし。
      if cf.roles.any?
        hash[:roles] = cf.roles.map { |r| { id: r.id, name: r.name } }
      end
      hash
    end
  end

  # User 一覧。非 admin は User.visible（自分＋可視プロジェクトのメンバー、または users_visibility='all'
  # ロールで全アクティブユーザ）に絞り、admin は従来どおり全アクティブユーザ。どちらも匿名ユーザ (type != 'User') は除外。
  def fetch_users
    if User.current.admin?
      # 個別 API (GET /users.json) の既定挙動 (status=1) に合わせて全アクティブユーザ。
      # User.visible は admin だと status 無視の all（locked 含む）になるため、admin 経路はスコープを使わない。
      User.where(type: 'User', status: User::STATUS_ACTIVE).order(:login).map { |u| user_to_hash(u) }
    else
      visible_users.map { |u| user_to_hash(u) }
    end
  end

  def user_to_hash(u)
    hash = {
      id: u.id,
      login: u.login,
      firstname: u.firstname,
      lastname: u.lastname,
      created_on: to_api_time(u.created_on)
    }
    hash[:mail] = u.mail if u.mail.present?
    hash[:last_login_on] = to_api_time(u.last_login_on) if u.last_login_on
    hash[:status] = u.status if u.status
    hash[:admin] = u.admin? if u.admin?
    # 個別 API (GET /users.json) が返すフィールドに揃える。
    hash[:updated_on] = to_api_time(u.updated_on)
    hash[:passwd_changed_on] = to_api_time(u.passwd_changed_on)
    hash[:twofa_scheme] = u.twofa_scheme
    # API キーと auth_source などは個別 API も返さないため含めない
    hash
  end

  # Role 一覧 + 各 Role の詳細（permissions）。
  # 現状 CacheService は GetObjects + 各 GetObject(id) の N+1 だが、ここでサーバ側でまとめて返す。
  # givable（builtin=0）のみ。個別 API (GET /roles.json) はビルトインロール
  # （Non member / Anonymous）を除外するため、それに揃える。
  def fetch_roles
    Role.givable.map do |r|
      hash = {
        id: r.id,
        name: r.name,
        assignable: r.assignable,
        issues_visibility: r.issues_visibility,
        time_entries_visibility: r.time_entries_visibility,
        users_visibility: r.users_visibility
      }
      # 個別取得（GetObject<Role>(id)）で取れる permissions を含める。
      # 本体 roles/:id API と同じく文字列配列 (["add_issues", ...]) 形式で返す。
      hash[:permissions] = (r.permissions || []).map(&:to_s)
      hash
    end
  end

  # Group 一覧 + 各 Group の詳細（users 含む）。非 admin は Group.givable.visible に絞る。
  # givable（type='Group'）のみ。個別 API (GET /groups.json) はビルトイングループ
  # （Anonymous / Non member）を builtin=1 指定時以外は除外するため、それに揃える。
  def fetch_groups
    admin = User.current.admin?
    scope = admin ? Group.givable : Group.givable.visible(User.current)

    # 並び順も個別 API に揃える（groups#index は Group.sorted = order(type, lastname)）。
    scope.sorted.preload(:users).map do |g|
      # 非 admin には見えないユーザを漏らさないよう、メンバーを可視ユーザ id 集合と交差させる。
      members = admin ? g.users : g.users.select { |u| visible_user_ids.include?(u.id) }
      { id: g.id, name: g.name, users: members.map { |u| { id: u.id, name: u.name } } }
    end
  end

  # current_user に可視な active User の一覧（fetch_users と groups のメンバー絞り込みで共有）。
  # admin 経路では使わない（admin は User.visible が locked 含む all になるため）。
  def visible_users
    @visible_users ||= User.visible(User.current).where(type: 'User').order(:login).to_a
  end

  # 可視ユーザの id 集合（groups のメンバー交差用）。visible_users から派生し追加クエリなし。
  def visible_user_ids
    @visible_user_ids ||= visible_users.map(&:id).to_set
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
    pids = visible_project_ids(user)
    result = pids.each_with_object({}) { |pid, h| h[pid.to_s] = [] }
    begin
      # 全対象プロジェクトの member を 1 クエリで取得し project_id で束ねる。
      # member_roles / project も preload し、per-member の入れ子 N+1 も同時に解消する。
      members_by_pid = Member.where(project_id: pids)
                             .preload(:user, :principal, :roles, :member_roles, :project)
                             .group_by(&:project_id)
      pids.each do |pid|
        result[pid.to_s] = (members_by_pid[pid] || []).map { |m| membership_to_hash(m) }.compact
      end
    rescue => e
      Rails.logger.warn "cache_bundle: project_memberships failed: #{e.class} #{e.message}"
      @errors << { section: 'project_memberships', code: 500, message: "#{e.class}: #{e.message}" }
      pids.each { |pid| result[pid.to_s] = [] }
    end
    result
  end

  def membership_to_hash(m)
    h = {
      id: m.id,
      project: { id: m.project_id, name: m.project.name },
      roles: m.roles.map { |r| { id: r.id, name: r.name, inherited: m.member_roles.find { |mr| mr.role_id == r.id }&.inherited_from.present? || false } }
    }
    if m.user.is_a?(User) && m.user.status != User::STATUS_LOCKED
      h[:user] = { id: m.user.id, name: m.user.name }
    elsif m.principal.is_a?(Group)
      h[:group] = { id: m.principal.id, name: m.principal.name }
    else
      # ロックユーザのみの membership はスキップ
      return nil
    end
    h
  end

  # ProjectVersions: { project_id => [...] }
  # 個別 API (GET /projects/:id/versions.json) はコアで view_issues 権限を要求する
  # （versions#index は view_issues 配下）。cache_bundle でも対象ユーザの view_issues を確認し、
  # 権限が無いプロジェクトは空で返す（過剰露出の是正）。
  def fetch_per_project_versions(user)
    projects = Project.where(id: visible_project_ids(user)).to_a
    result = projects.each_with_object({}) { |pr, h| h[pr.id.to_s] = [] }
    # view_issues を持たないロールは個別 API では 403 になるため、権限のあるプロジェクトのみ版を返す（他は空のまま）。
    allowed = projects.select { |pr| user.allowed_to?(:view_issues, pr) }
    begin
      # 権限のある全プロジェクトの版を 1 クエリで取得。custom_values を preload し per-version の CF 値 N+1 を解消。
      versions_by_pid = Version.where(project_id: allowed.map(&:id))
                               .preload(:custom_values, :project)
                               .group_by(&:project_id)
      allowed.each do |pr|
        result[pr.id.to_s] = (versions_by_pid[pr.id] || []).map { |v| version_to_hash(v, user) }
      end
    rescue => e
      Rails.logger.warn "cache_bundle: project_versions failed: #{e.class} #{e.message}"
      @errors << { section: 'project_versions', code: 500, message: "#{e.class}: #{e.message}" }
      allowed.each { |pr| result[pr.id.to_s] = [] }
    end
    result
  end

  def version_to_hash(v, user)
    h = {
      id: v.id,
      project: { id: v.project_id, name: v.project.name },
      name: v.name,
      description: v.description,
      status: v.status,
      sharing: v.sharing,
      created_on: to_api_time(v.created_on),
      updated_on: to_api_time(v.updated_on)
    }
    h[:due_date] = v.due_date if v.due_date
    h[:wiki_page_title] = v.wiki_page_title if v.wiki_page_title.present?
    # 個別 API (GET /projects/:id/versions.json) は render_api_custom_values で
    # 対象ユーザに可視な CF 値を返す。可視性はコアの visible_custom_field_values にそのまま委ねる
    # （preload 済み custom_values の上で評価するため追加クエリなし）。
    cf_values = to_api_custom_field_values(v.visible_custom_field_values(user))
    h[:custom_fields] = cf_values if cf_values.present?
    h
  end

  # ProjectIssueCategories: { project_id => [...] }
  # Active なプロジェクトのみが対象（現状 CacheService.updateProjectIssueCategoriesAsync の Status == Active フィルタ相当）。
  #
  # 個別 API (GET /projects/:id/issue_categories.json) はコアで manage_categories 権限を要求する
  # （view_members / view_issues のような閲覧用の緩い権限が存在しない）。cache_bundle は本来サーバ側で
  # 権限判定して個別 API と等価な結果を返す契約のため、ここでも対象ユーザの manage_categories を確認し、
  # 権限が無いプロジェクトは空で返す（過剰露出の是正・最小権限化）。
  def fetch_per_project_issue_categories(user)
    active_projects = Project.where(id: visible_project_ids(user), status: Project::STATUS_ACTIVE).to_a
    result = active_projects.each_with_object({}) { |pr, h| h[pr.id.to_s] = [] }
    # manage_categories を持たないロールは個別 API では 403 になるため、権限のあるプロジェクトのみカテゴリを返す（他は空のまま）。
    allowed = active_projects.select { |pr| user.allowed_to?(:manage_categories, pr) }
    begin
      # 権限のある全プロジェクトのカテゴリを 1 クエリで取得し project_id で束ねる。
      categories_by_pid = IssueCategory.where(project_id: allowed.map(&:id))
                                       .preload(:assigned_to, :project)
                                       .group_by(&:project_id)
      allowed.each do |pr|
        result[pr.id.to_s] = (categories_by_pid[pr.id] || []).map { |c| category_to_hash(c) }
      end
    rescue => e
      Rails.logger.warn "cache_bundle: project_issue_categories failed: #{e.class} #{e.message}"
      @errors << { section: 'project_issue_categories', code: 500, message: "#{e.class}: #{e.message}" }
      allowed.each { |pr| result[pr.id.to_s] = [] }
    end
    result
  end

  def category_to_hash(c)
    h = {
      id: c.id,
      project: { id: c.project_id, name: c.project.name },
      name: c.name
    }
    h[:assigned_to] = { id: c.assigned_to.id, name: c.assigned_to.name } if c.assigned_to
    h
  end
end
