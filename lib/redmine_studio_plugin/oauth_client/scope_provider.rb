# frozen_string_literal: true

module RedmineStudioPlugin
  module OauthClient
    # Redmine Studio がサインイン方式で必要とする権限範囲（OAuth スコープ）を定義・維持する。
    # スコープ名は Redmine の権限名で、トークンに載る権限と利用者本人のロール権限は AND で効く。
    # ここは「アプリが要求してよい上限」を最小権限で定義する場所。
    module ScopeProvider
      # 閲覧系は広めに許可する（read フラグの付いた権限を採用）。
      # ただし read フラグ付きでも破壊的な操作はサインイン方式では使わないため除外する
      # （Redmine コアでは close_project / delete_project が read 扱いのため明示的に外す）。
      READ_DENYLIST = %i[close_project delete_project].freeze

      # カテゴリー一覧の取得（アプリのカテゴリー選択肢）はコアに閲覧専用の権限が無く、
      # 個別 API も cache_bundle も manage_categories を要求するため、閲覧目的で含める。
      READ_EXTRA_SCOPES = %i[manage_categories].freeze

      # プラグインはアプリより更新が届きにくい（顧客側 Redmine の管理者作業が要る）ため、
      # アプリの将来機能で使う見込みの権限は先行して確保する。
      # ただし操作を取り消せるものに限る（Wiki の編集は版履歴で戻せるため含める。
      # ページ削除は履歴ごと消えて戻せないため含めない）。
      PROVISIONED_SCOPES = %i[edit_wiki_pages].freeze

      # 変更系はアプリが実際に呼ぶ操作だけに限定する（チケットの作成・更新・注記・親チケットの設定、
      # 時間記録の登録・更新・削除）。
      # 「自分のものだけ」ロール向けに own 版も含める。含めないと本人が持つ own 権限が
      # スコープとの AND で削られ、ブラウザでは編集できるのにアプリからは編集できなくなる。
      # manage_subtasks が無いと parent_issue_id が safe_attributes で黙って無視され、
      # 親チケットを指定した作成・更新が親なしで通ってしまう。
      WRITE_SCOPES = %i[
        add_issues
        edit_issues
        edit_own_issues
        manage_subtasks
        add_issue_notes
        log_time
        edit_time_entries
        edit_own_time_entries
      ].freeze

      # admin スコープは絶対に含めない（含めるとトークンが管理者として振る舞い得る）。

      module_function

      # 登録・要求に使うスコープ名（Symbol）の一覧。並びは安定させる（登録との差分検出のため）。
      def scope_names
        read = Redmine::AccessControl.permissions.select(&:read?).map(&:name)
        (read - READ_DENYLIST + READ_EXTRA_SCOPES + PROVISIONED_SCOPES + WRITE_SCOPES).uniq.sort
      end

      # スペース区切りのスコープ文字列（Doorkeeper の scopes 形式）。
      def scope_string
        scope_names.map(&:to_s).join(' ')
      end
    end
  end
end
