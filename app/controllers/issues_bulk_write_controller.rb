# frozen_string_literal: true

# Issues Bulk Write API
#
# 複数の Issue の作成/更新を 1 リクエストで完結させるエンドポイント。
# Redmine 本体の POST /issues.json は notes をサポートせず、また 1 リクエスト = 1 Issue のため、
# 大量作成/更新のシナリオ（例: RedmineStudio のチケット表編集「一括追加」→「Redmineに反映」）で
# 認証・セッション・DB 接続のオーバヘッドが N 倍になる問題を解消する。
#
# 主な特徴:
# - create/update 混在可能（op で切り替え）
# - create 時に notes を指定すると初期コメントとして journal に載る
#   （Redmine 本体の POST /issues.json は notes を silent no-op で無視するが、本 API は init_journal で明示的に処理する）
# - Partial success: 各 operation は独立トランザクション。1 件失敗しても他は commit
# - レスポンスは operation ごとの結果配列（成功: issue / 失敗: errors）
# - Redmine 本体の IssuesController#create / #update の処理を可能な限り踏襲し、既存 API と結果差分ゼロを目指す
#   （call_hook、safe_attributes、権限チェックを踏襲）
class IssuesBulkWriteController < ApplicationController
  # .api.rsb ビューで render_api_custom_values（CustomFieldsHelper）を使うため helper 参照が必要
  helper :custom_fields

  # 状態変更 API のため必ず認証を要求する。accept_api_auth と併用することで API キー認証もサポートする。
  # 標準 Redmine の POST /issues.json は無認証で 401 を返すため、その挙動に揃える。
  before_action :require_login
  accept_api_auth :create

  # POST /issues/bulk_write
  #
  # Request body:
  #   {
  #     "operations": [
  #       { "op": "create", "issue": { "project_id": 1, "tracker_id": 2, "subject": "...", "notes": "..." } },
  #       { "op": "update", "id": 123, "issue": { "subject": "...", "notes": "..." } }
  #     ]
  #   }
  #
  # Response body (200):
  #   {
  #     "results": [
  #       { "index": 0, "op": "create", "success": true, "issue": { "id": 100, ... } },
  #       { "index": 1, "op": "update", "success": false, "errors": ["Subject cannot be blank"] }
  #     ]
  #   }
  def create
    operations = params[:operations]
    unless operations.is_a?(Array) || operations.is_a?(ActionController::Parameters)
      return respond_to { |format| format.api { render_api_errors('operations must be an array') } }
    end

    ops = operations.respond_to?(:to_unsafe_hash) ? operations.map(&:to_unsafe_hash) : operations.map { |o| o.respond_to?(:to_unsafe_hash) ? o.to_unsafe_hash : o }

    if ops.empty?
      return respond_to { |format| format.api { render_api_errors('operations must not be empty') } }
    end

    @results = ops.each_with_index.map do |op_hash, index|
      process_operation(op_hash, index)
    end

    respond_to do |format|
      format.api
    end
  end

  private

  # 1 operation を独立トランザクションで処理する。
  # 例外・バリデーションエラー・権限エラーは result hash に変換して返す。
  def process_operation(op_hash, index)
    op = op_hash['op'] || op_hash[:op]
    case op
    when 'create'
      process_create(op_hash, index)
    when 'update'
      process_update(op_hash, index)
    else
      { index: index, op: op, success: false, errors: ["unknown op: #{op.inspect}"] }
    end
  rescue => e
    Rails.logger.error "bulk_write: index=#{index} op=#{op} unexpected error: #{e.class} #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    { index: index, op: op, success: false, errors: ["#{e.class}: #{e.message}"] }
  end

  # ---- create ---------------------------------------------------------
  #
  # Redmine 本体の IssuesController#create + #build_new_issue_from_params 相当の処理を行う。
  # 差分:
  # - notes が指定されていれば init_journal(User.current, notes) を明示的に呼ぶ
  #   （本体の create は init_journal を呼ばないため、送っても silent no-op で無視される）
  def process_create(op_hash, index)
    issue_params = extract_issue_params(op_hash)

    project = resolve_project(issue_params)
    unless project
      return { index: index, op: 'create', success: false, errors: ['project not found or not visible'] }
    end

    # 本体 IssuesController#create の権限チェック (line 152-154) を踏襲
    unless User.current.allowed_to?(:add_issues, project, global: true)
      return { index: index, op: 'create', success: false, errors: ['forbidden: add_issues permission required'] }
    end

    issue = Issue.new
    issue.project = project
    issue.author ||= User.current
    if Setting.default_issue_start_date_to_creation_date?
      issue.start_date ||= User.current.today
    end

    # notes を先に取り出し、init_journal で journal に載せる。
    # 本体は init_journal を呼ばないため safe_attributes 経由の notes= は current_journal が nil で silent no-op になる。
    # 本 API では notes が指定されていれば init_journal を明示的に呼び、載せる。
    notes = extract_notes(issue_params)
    issue.init_journal(User.current, notes || '')

    # 本体 build_new_issue_from_params (line 631) 相当: 'me' を現在ユーザーに変換
    if issue_params['assigned_to_id'] == 'me'
      issue_params['assigned_to_id'] = User.current.id
    end

    apply_safe_attributes(issue, issue_params)

    # 本体と同じく tracker / status の default 設定 (build_new_issue_from_params line 634-649)
    if issue.tracker.nil?
      issue.tracker = issue.allowed_target_trackers.first
      unless issue.tracker
        return { index: index, op: 'create', success: false, errors: ['no tracker allowed for new issue in project'] }
      end
    end
    if issue.status.nil?
      return { index: index, op: 'create', success: false, errors: ['no default issue status'] }
    end

    call_hook(:controller_issues_new_before_save, params: params, issue: issue)

    if issue.save
      call_hook(:controller_issues_new_after_save, params: params, issue: issue)
      { index: index, op: 'create', success: true, issue: issue }
    else
      { index: index, op: 'create', success: false, errors: issue.errors.full_messages }
    end
  end

  # ---- update ---------------------------------------------------------
  #
  # Redmine 本体の IssuesController#update + #update_issue_from_params + #save_issue_with_child_records
  # 相当の処理を行う。ただし time_entry / attachments は本 API では未サポート。
  def process_update(op_hash, index)
    id = op_hash['id'] || op_hash[:id]
    if id.blank?
      return { index: index, op: 'update', success: false, errors: ['id is required for update'] }
    end

    issue = Issue.visible.find_by(id: id)
    unless issue
      return { index: index, op: 'update', success: false, errors: ["issue #{id} not found or not visible"] }
    end

    # 本体は before_action :authorize（controller レベル）で権限チェックしている。
    # accept_api_auth のため controller_name / action_name を渡す形での明示チェックが必要。
    unless User.current.allowed_to?({ controller: 'issues', action: 'update' }, issue.project)
      return { index: index, op: 'update', success: false, errors: ["forbidden: edit_issues permission required for issue #{id}"] }
    end

    # 本体 IssuesController#update_issue_from_params (line 561-) を踏襲
    issue.init_journal(User.current)

    issue_params = extract_issue_params(op_hash)
    if issue_params['assigned_to_id'] == 'me'
      issue_params['assigned_to_id'] = User.current.id
    end

    # 本体 update_issue_from_params (line 583) 相当: 'none' 文字列を空文字に置換
    # （明示的な unset 操作: dropdown で「なし」選択に相当）
    issue_params = replace_none_values_with_blank(issue_params)

    apply_safe_attributes(issue, issue_params)

    # 本体 IssuesController#save_issue_with_child_records (line 660-) を踏襲
    # time_entry / attachments は未サポートのため省略
    saved = false
    begin
      Issue.transaction do
        call_hook(
          :controller_issues_edit_before_save,
          params: params, issue: issue, time_entry: nil, journal: issue.current_journal
        )
        if issue.save
          call_hook(
            :controller_issues_edit_after_save,
            params: params, issue: issue, time_entry: nil, journal: issue.current_journal
          )
          saved = true
        else
          raise ActiveRecord::Rollback
        end
      end
    rescue ActiveRecord::StaleObjectError
      return { index: index, op: 'update', success: false, errors: ["stale object: issue #{id} was modified by another user"] }
    end

    if saved
      { index: index, op: 'update', success: true, issue: issue }
    else
      { index: index, op: 'update', success: false, errors: issue.errors.full_messages }
    end
  end

  # ---- helpers --------------------------------------------------------

  # op_hash から issue 属性ハッシュを取り出す。文字列/シンボルキー両対応。
  def extract_issue_params(op_hash)
    raw = op_hash['issue'] || op_hash[:issue] || {}
    raw = raw.to_unsafe_hash if raw.respond_to?(:to_unsafe_hash)
    raw.stringify_keys
  end

  # issue_params から notes を破壊的に取り出す。
  # 本体は notes を safe_attributes 経由で処理するが、本 API では init_journal で明示処理するため
  # 事前に取り出しておく（重複適用防止）。
  def extract_notes(issue_params)
    notes = issue_params.delete('notes')
    notes = notes.to_s if notes
    notes.presence
  end

  # project_id からプロジェクトを解決する。identifier / id の両方に対応（本体 safe_attributes= と同挙動）。
  def resolve_project(issue_params)
    pid = issue_params['project_id']
    return nil if pid.blank?

    if pid.is_a?(String) && !/^\d*$/.match?(pid)
      Project.find_by(identifier: pid)
    else
      Project.find_by(id: pid.to_i)
    end
  end

  # 本体の safe_attributes= を呼ぶ。attrs の変更は自動的に safe_attributes= 側で filter される。
  def apply_safe_attributes(issue, issue_params)
    issue.safe_attributes = issue_params
  end
end
