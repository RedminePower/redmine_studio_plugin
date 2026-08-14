# frozen_string_literal: true

module RedmineStudioPlugin
  module OauthClient
    # サインイン用の OAuth アプリ登録を自己修復する。
    # Redmine 起動のたびに「未登録なら登録／スコープ定義がズレていれば追従」を行う。
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
      def registered_application
        return nil unless available?

        Doorkeeper::Application.find_by(name: APP_NAME)
      end

      # 起動時に呼ぶ自己修復登録。失敗しても起動は妨げない。
      def ensure_registered
        return unless available?

        desired = ScopeProvider.scope_names.map(&:to_s).sort
        app = Doorkeeper::Application.find_by(name: APP_NAME)
        if app.nil?
          # 未登録なら公開クライアントとして新規登録する
          Doorkeeper::Application.create!(
            name: APP_NAME,
            redirect_uri: REDIRECT_URI,
            scopes: desired.join(' '),
            confidential: false
          )
        elsif app.scopes.all.sort != desired
          # スコープ定義が変わっていたら登録側を追従させる（将来の権限追加の反映）
          app.update!(scopes: desired.join(' '))
        end
      rescue => e
        # マイグレーション前・DB 未接続・同時起動の競合など。登録失敗で起動を止めない
        Rails.logger.warn "[redmine_studio_plugin] OAuth client registration skipped: #{e.class}: #{e.message}"
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
