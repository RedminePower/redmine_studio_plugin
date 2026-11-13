# frozen_string_literal: true

module RedmineStudioPlugin
  module OauthClient
    # サインイン用の OAuth アプリ登録を自己修復する。
    # Redmine 起動のたびに「未登録なら登録／二重に登録されていれば 1 つにまとめる／スコープ定義がズレていれば追従」を行う。
    # 公開クライアント（confidential=false）は管理画面から作れないためプログラム登録が必須。
    # ループバックのリダイレクト URI はポート差を Doorkeeper が許容するため、パスだけ固定して登録する。
    module AppRegistrar
      APP_NAME = 'Redmine Studio'
      REDIRECT_URI = 'http://127.0.0.1/'

      module_function

      # サインイン方式は Redmine 6.1 以上が前提（Doorkeeper の PKCE S256 対応）。
      def signin_supported?
        v = Redmine::VERSION
        v::MAJOR > 6 || (v::MAJOR == 6 && v::MINOR >= 1)
      end

      # 登録済みのサインイン用アプリ。未登録・非対応なら nil。
      # 同時の起動で二重に登録されたときも、いちばん古いものを正とする
      def registered_application
        return nil unless available?

        canonical_application
      end

      # 起動時に呼ぶ自己修復登録。失敗しても起動は妨げない。
      def ensure_registered
        return unless available?

        desired = ScopeProvider.scope_names.map(&:to_s).sort
        unless canonical_application
          # 未登録なら公開クライアントとして新規登録する
          Doorkeeper::Application.create!(
            name: APP_NAME,
            redirect_uri: REDIRECT_URI,
            scopes: desired.join(' '),
            confidential: false
          )
        end
        # 名前に重複を禁じる仕組みが無いので、同時に起動したほかのプロセスも作っていることがある。
        # 作った後も、すでに二重になっている環境も、ここで 1 つにまとめる
        app = merge_duplicates
        warn_other_same_name_apps(app)
        if app.scopes.all.sort != desired
          # スコープ定義が変わっていたら登録側を追従させる（将来の権限追加の反映）
          app.update!(scopes: desired.join(' '))
        end
      rescue => e
        # マイグレーション前・DB 未接続・同時起動の競合など。登録失敗で起動を止めない
        Rails.logger.warn "[redmine_studio_plugin] OAuth client registration skipped: #{e.class}: #{e.message}"
      end

      # サインイン用アプリと見なすもの（作るときと同じ名前・リダイレクト先の公開クライアント）を古い順に。
      # 管理者が画面から同じ名前で作った、設定の違うアプリは含めない（消さない・正にしない）
      def signin_applications
        Doorkeeper::Application.where(name: APP_NAME, redirect_uri: REDIRECT_URI, confidential: false).order(:id)
      end

      # サインイン用アプリのうち、いちばん古いもの。
      def canonical_application
        signin_applications.first
      end

      # サインイン用アプリが複数あれば、いちばん古いものに 1 つにまとめて、それを返す。
      # ほかのアプリで発行したトークン・認可コードは古いものへ付け替える。
      # アプリは client_id を毎回 /oauth_client から取り直すので、付け替えておけばトークンの更新もそのまま通る。
      def merge_duplicates
        apps = signin_applications.to_a
        keep = apps.shift
        return keep if keep.nil? || apps.empty?

        ids = apps.map(&:id)
        Doorkeeper::Application.transaction do
          Doorkeeper.config.access_token_model.where(application_id: ids).update_all(application_id: keep.id)
          Doorkeeper.config.access_grant_model.where(application_id: ids).update_all(application_id: keep.id)
          Doorkeeper::Application.where(id: ids).delete_all
        end
        keep
      end

      # 同じ名前で設定の違うアプリ（管理者が作ったもの）は手を付けず、知らせだけ残す
      def warn_other_same_name_apps(app)
        others = Doorkeeper::Application.where(name: APP_NAME).where.not(id: app.id).pluck(:id)
        return if others.empty?

        Rails.logger.warn "[redmine_studio_plugin] OAuth applications named '#{APP_NAME}' with other settings are left as they are: #{others.join(', ')}"
      end

      # 6.1 以上かつ Doorkeeper の oauth_applications テーブルが使えるときだけ動く。
      def available?
        return false unless signin_supported?
        return false unless defined?(Doorkeeper::Application)

        ActiveRecord::Base.connection.table_exists?('oauth_applications')
      rescue => e
        # DB 未接続（assets:precompile 等）でも落とさない
        Rails.logger.warn "[redmine_studio_plugin] OAuth availability check failed: #{e.class}: #{e.message}"
        false
      end
    end
  end
end
