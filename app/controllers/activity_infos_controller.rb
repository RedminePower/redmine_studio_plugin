# frozen_string_literal: true

class ActivityInfosController < ApplicationController
  accept_api_auth :index
  # 追加 API は本体の login_required 設定に関わらず一律ログイン必須にする（匿名アクセス遮断）
  before_action :require_login

  # 活動 1 件の組み立てで出ても飛ばさず、一覧ごと失敗にする例外（データベースの例外・タイムアウト）。
  # 一時的な障害で欠けた結果を、成功として返さないため。
  NOT_SKIPPED_ERRORS = [ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished, Timeout::Error].freeze

  PLUGIN_ROOT = File.expand_path('../..', __dir__)

  # GET /activity_infos?user_id=N&from=YYYY-MM-DD&to=YYYY-MM-DD
  def index
    return unless validate_params!

    author = User.visible.active.find(params[:user_id])
    from = params[:from].to_date
    to = params[:to].to_date
    context = "user_id=#{author.id} from=#{from} to=#{to}"

    begin
      @activity_infos, skipped = build_activity_infos(author, from, to, context)
      @skipped_count = skipped.size
      @skipped_errors = skipped.map { |e| describe_error(e) }.uniq.join(', ')

      # 書き出しの失敗もここで拾えるよう、アクションの中で書き出す（ブロックが無いと、アクションの後で書き出される）
      respond_to do |format|
        format.api { render :action => 'index' }
      end
    rescue ActionController::UnknownFormat, ::Unauthorized
      # 形式の誤り（406）と権限の不足は、今までどおり Redmine 本体に任せる
      raise
    rescue StandardError => e
      logger.error "[ActivityInfos] failed: #{context} #{e.class}: #{e.message}\n#{Array(e.backtrace).join("\n")}"
      render_activity_error(e)
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

  # 期間の活動を組み立てる。活動 1 件の組み立てで失敗したらその 1 件を飛ばし、
  # [組み立てた活動の配列, 飛ばした例外の配列] を返す。
  # 1 件ずつに分けられない所・データベースの例外・タイムアウト・全件の失敗は、例外のまま上げる。
  def build_activity_infos(author, from, to, context)
    # Fetcher で issues タイプの活動イベントを取得
    fetcher = Redmine::Activity::Fetcher.new(User.current, :author => author)
    fetcher.scope = ['issues']
    events = fetcher.events(from, to + 1) # to は inclusive なので +1 日

    # イベントに関連するチケットの ID を収集
    issue_ids = events.map do |e|
      e.is_a?(Journal) ? e.journalized_id : (e.is_a?(Issue) ? e.id : nil)
    end.compact.uniq

    # 親チケット階層も含めた全チケット ID を収集し、Journal を一括プリロード
    all_issue_ids = collect_all_issue_ids(issue_ids)
    journals_by_issue = preload_journals(all_issue_ids)

    # ルックアップテーブルを構築（DB クエリを最小化）
    # 親チケット階層に閲覧権限の無いチケットが混ざり得るため .visible で絞る。
    # 可視でない親は issues_by_id から外れ、build_ticket_tree がそこで階層を打ち切る
    issues_by_id = Issue.visible.where(:id => all_issue_ids).preload(:tracker, :project, :priority, :author).index_by(&:id)
    status_lookup = IssueStatus.where(:id => collect_all_status_ids(journals_by_issue, issues_by_id)).index_by(&:id)
    principal_lookup = Principal.where(:id => collect_all_principal_ids(journals_by_issue, issues_by_id)).index_by(&:id)

    # 親チケット階層のキャッシュ（同じチケットの親階層は共通）
    parent_cache = {}

    infos = []
    skipped = []
    logged_classes = {}
    events.each do |event|
      begin
        info = build_activity_info(event, journals_by_issue, issues_by_id, parent_cache, status_lookup, principal_lookup)
        infos << info if info
      rescue *NOT_SKIPPED_ERRORS
        raise
      rescue StandardError => e
        skipped << e
        log_skipped(e, event, context, logged_classes)
      end
    end

    # 全件が失敗したときは、空の一覧を「活動なし」と取り違えないよう、一覧ごとの失敗にする
    raise skipped.first if infos.empty? && skipped.any?

    [infos, skipped]
  end

  # 飛ばした活動をログに残す。スタックトレースは、1 回の呼び出しで例外のクラスごとに最初の 1 件だけ書く
  def log_skipped(error, event, context, logged_classes)
    message = "[ActivityInfos] skipped: #{context} #{event.class.name}##{event.id} #{error.class}: #{error.message}"
    if logged_classes[error.class]
      logger.error message
    else
      logged_classes[error.class] = true
      logger.error "#{message}\n#{Array(error.backtrace).join("\n")}"
    end
  end

  # 応答に入れる例外の説明。「クラス名 (ファイル名:行)」。メッセージは入れない（件名などが混ざりうるため）。
  # 場所は、スタックトレースのうちプラグインの中で最初に出てくる行。無ければ最初の行。フォルダの名前は入れない
  def describe_error(error)
    # ビューの書き出しで出た例外は、Rails が包んでいるので、中の例外を出す
    error = error.cause if error.is_a?(ActionView::Template::Error) && error.cause
    lines = Array(error.backtrace)
    line = lines.find { |l| l.start_with?(PLUGIN_ROOT + '/') } || lines.first
    match = line && line.match(/\A(.+?):(\d+)/)
    name = error.class.name || error.class.to_s
    match ? "#{name} (#{File.basename(match[1])}:#{match[2]})" : name
  end

  # 一覧ごとの失敗を 500 で返す。本文は API の形（errors）にし、利用者への案内と例外の説明の 2 つを入れる
  # （アプリは errors をそのままダイアログに出すので、案内が無いと例外の説明だけになる）。
  # 書き出しの途中で失敗したときも、応答はまだ書かれていないので、ここで書ける
  def render_activity_error(error)
    @error_messages = [l(:error_activity_infos_failed), describe_error(error)]
    render :template => 'common/error_messages', :formats => [:api], :status => 500
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

  # 活動 1 件を、応答に書く値だけのハッシュにする。
  # ビューの途中で例外が出ると 1 件だけ飛ばせないため、モデルは入れず、文字列・数値・日時・nil・配列・ハッシュだけを入れる
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
      :journal => journal_values(journal),
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

  # Journal を、応答に書く値だけのハッシュにする（変更の詳細は、呼んだ人に見えるものだけ）
  def journal_values(journal)
    {
      :id => journal.id,
      :user => id_name(journal.user),
      :notes => journal.notes,
      :created_on => journal.created_on,
      :private_notes => journal.private_notes,
      :details => journal.visible_details.map do |detail|
        { :property => detail.property, :name => detail.prop_key, :old_value => detail.old_value, :new_value => detail.value }
      end
    }
  end

  # モデルを { id, name } のハッシュにする。無ければ nil
  def id_name(record)
    record ? { :id => record.id, :name => record.name } : nil
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
      :tracker => id_name(issue.tracker),
      :status_id => restored_status_id,
      :status => restored_status_id ? { :id => restored_status_id, :name => status_lookup[restored_status_id]&.name } : nil,
      :assigned_to_id => restored_assigned_to_id,
      :assigned_to => restored_assigned_to_id ? { :id => restored_assigned_to_id, :name => principal_lookup[restored_assigned_to_id]&.name } : nil,
      :project => id_name(issue.project),
      :parent_id => issue.parent_id,
      :priority => id_name(issue.priority),
      :author => id_name(issue.author),
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
