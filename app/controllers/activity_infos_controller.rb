# frozen_string_literal: true

class ActivityInfosController < ApplicationController
  accept_api_auth :index

  # GET /activity_infos?user_id=N&from=YYYY-MM-DD&to=YYYY-MM-DD
  def index
    return unless validate_params!

    author = User.visible.active.find(params[:user_id])
    from = params[:from].to_date
    to = params[:to].to_date

    # Fetcher で issues タイプの活動イベントを取得
    fetcher = Redmine::Activity::Fetcher.new(User.current, :author => author)
    fetcher.scope = ['issues']
    events = fetcher.events(from, to + 1) # to は inclusive なので +1 日

    # イベントに関連するチケットの ID を収集
    issue_ids = events.filter_map do |e|
      e.is_a?(Journal) ? e.journalized_id : (e.is_a?(Issue) ? e.id : nil)
    end.uniq

    # 親チケット階層も含めた全チケット ID を収集し、Journal を一括プリロード
    all_issue_ids = collect_all_issue_ids(issue_ids)
    journals_by_issue = preload_journals(all_issue_ids)

    # ルックアップテーブルを構築（DB クエリを最小化）
    issues_by_id = Issue.where(:id => all_issue_ids).preload(:tracker, :project, :priority, :author).index_by(&:id)
    status_lookup = IssueStatus.where(:id => collect_all_status_ids(journals_by_issue, issues_by_id)).index_by(&:id)
    principal_lookup = Principal.where(:id => collect_all_principal_ids(journals_by_issue, issues_by_id)).index_by(&:id)

    # 親チケット階層のキャッシュ（同じチケットの親階層は共通）
    parent_cache = {}

    @activity_infos = events.filter_map do |event|
      build_activity_info(event, journals_by_issue, issues_by_id, parent_cache, status_lookup, principal_lookup)
    end

    respond_to do |format|
      format.api
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  private

  def validate_params!
    %w[user_id from to].each do |key|
      if params[key].blank?
        respond_to do |format|
          format.api { render_api_errors("#{key} is required") }
        end
        return false
      end
    end
    true
  end

  # 親チケットを再帰的にたどり、関連するすべてのチケット ID を収集する
  def collect_all_issue_ids(issue_ids)
    all_ids = Set.new(issue_ids)
    ids_to_check = issue_ids.dup

    while ids_to_check.any?
      parent_ids = Issue.where(:id => ids_to_check).pluck(:parent_id).compact - all_ids.to_a
      break if parent_ids.empty?

      all_ids.merge(parent_ids)
      ids_to_check = parent_ids
    end

    all_ids.to_a
  end

  # チケットの Journal を一括プリロードする
  def preload_journals(issue_ids)
    result = {}
    return result if issue_ids.empty?

    Issue.where(:id => issue_ids).preload(:journals => :details).each do |issue|
      result[issue.id] = issue.journals.sort_by(&:created_on)
    end
    result
  end

  # Journal の Details から参照される全ステータス ID を収集する
  def collect_all_status_ids(journals_by_issue, issues_by_id)
    ids = Set.new
    journals_by_issue.each_value do |journals|
      journals.each do |j|
        j.details.each do |d|
          next unless d.property == 'attr' && d.prop_key == 'status_id'

          ids.add(d.old_value.to_i) if d.old_value
          ids.add(d.value.to_i) if d.value
        end
      end
    end
    # 現在のステータスも含める
    issues_by_id.each_value do |issue|
      ids.add(issue.status_id) if issue.status_id
    end
    ids.to_a
  end

  # Journal の Details から参照される全ユーザー ID を収集する
  def collect_all_principal_ids(journals_by_issue, issues_by_id)
    ids = Set.new
    journals_by_issue.each_value do |journals|
      journals.each do |j|
        j.details.each do |d|
          next unless d.property == 'attr' && d.prop_key == 'assigned_to_id'

          ids.add(d.old_value.to_i) if d.old_value
          ids.add(d.value.to_i) if d.value
        end
      end
    end
    # 現在の担当者も含める
    issues_by_id.each_value do |issue|
      ids.add(issue.assigned_to_id) if issue.assigned_to_id
    end
    ids.to_a
  end

  def build_activity_info(event, journals_by_issue, issues_by_id, parent_cache, status_lookup, principal_lookup)
    if event.is_a?(Journal)
      build_from_journal(event, journals_by_issue, issues_by_id, parent_cache, status_lookup, principal_lookup)
    elsif event.is_a?(Issue)
      build_from_issue(event, journals_by_issue, issues_by_id, parent_cache, status_lookup, principal_lookup)
    end
  end

  # Journal（チケット更新）イベントから ActivityInfo を構築
  def build_from_journal(journal, journals_by_issue, issues_by_id, parent_cache, status_lookup, principal_lookup)
    issue = journal.issue
    return nil unless issue

    restored = restore_status(issue, journal.created_on, journals_by_issue[issue.id] || [], status_lookup, principal_lookup)
    ticket_tree = build_ticket_tree(issue, journal.created_on, journals_by_issue, issues_by_id, parent_cache, status_lookup, principal_lookup)

    {
      :activity_datetime => journal.created_on,
      :description => journal.event_description,
      :issue_id => issue.id,
      :journal_id => journal.id,
      :issue => restored,
      :journal => journal,
      :ticket_tree => ticket_tree
    }
  end

  # Issue（チケット作成）イベントから ActivityInfo を構築
  def build_from_issue(issue, journals_by_issue, issues_by_id, parent_cache, status_lookup, principal_lookup)
    restored = restore_status(issue, issue.created_on, journals_by_issue[issue.id] || [], status_lookup, principal_lookup)
    ticket_tree = build_ticket_tree(issue, issue.created_on, journals_by_issue, issues_by_id, parent_cache, status_lookup, principal_lookup)

    {
      :activity_datetime => issue.created_on,
      :description => issue.event_description,
      :issue_id => issue.id,
      :journal_id => nil,
      :issue => restored,
      :journal => nil,
      :ticket_tree => ticket_tree
    }
  end

  # 活動時点の status_id と assigned_to_id を復元する
  # target_time 以降の Journal を新しい順に遡り、変更を逆適用する
  def restore_status(issue, target_time, journals, status_lookup, principal_lookup)
    restored_status_id = issue.status_id
    restored_assigned_to_id = issue.assigned_to_id

    journals.sort_by(&:created_on).reverse_each do |j|
      break if j.created_on < target_time

      j.details.each do |detail|
        next unless detail.property == 'attr'

        case detail.prop_key
        when 'status_id'
          restored_status_id = detail.old_value&.to_i
        when 'assigned_to_id'
          restored_assigned_to_id = detail.old_value&.to_i
        end
      end
    end

    # 復元した値を持つハッシュとして返す（元の Issue を変更しない）
    {
      :id => issue.id,
      :subject => issue.subject,
      :tracker => issue.tracker,
      :status_id => restored_status_id,
      :status => restored_status_id ? status_lookup[restored_status_id] : nil,
      :assigned_to_id => restored_assigned_to_id,
      :assigned_to => restored_assigned_to_id ? principal_lookup[restored_assigned_to_id] : nil,
      :project => issue.project,
      :parent_id => issue.parent_id,
      :priority => issue.priority,
      :author => issue.author,
      :done_ratio => issue.done_ratio,
      :start_date => issue.start_date,
      :due_date => issue.due_date,
      :created_on => issue.created_on,
      :updated_on => issue.updated_on,
      :description => issue.description
    }
  end

  # 親チケット階層を構築する（ルートから順）
  # 各チケットも活動時点の状態に復元する
  def build_ticket_tree(issue, target_time, journals_by_issue, issues_by_id, parent_cache, status_lookup, principal_lookup)
    cache_key = "#{issue.id}_#{target_time.to_i}"
    return parent_cache[cache_key] if parent_cache.key?(cache_key)

    tree = []
    current = issue
    while current
      restored = restore_status(current, target_time, journals_by_issue[current.id] || [], status_lookup, principal_lookup)
      tree.unshift(restored)
      current = current.parent_id ? issues_by_id[current.parent_id] : nil
    end

    parent_cache[cache_key] = tree
    tree
  end
end
