# frozen_string_literal: true

module RedmineStudioPlugin
  module ServerLogs
    # サーバーのログと、サーバーの種類などの項目を見せてよい人か。システム管理者だけ。
    #
    # ブラウザでサインイン（OAuth）した人は、鍵の権限範囲に admin が無いと、Redmine 本体が管理者として扱わない
    # （User#admin? が偽）。サインイン用の鍵には admin を入れていない（ScopeProvider）ので、そのままでは
    # システム管理者でもログを読めない。そこで Redmine Studio のサインイン用アプリの鍵に限って、
    # ユーザーの設定（admin の列）で判定する。ほかのアプリに渡した鍵では読めない。
    module AdminAccess
      module_function

      def allowed?(user, request)
        return false unless user&.logged?
        return true if user.admin?
        return false unless user.respond_to?(:authorized_by_oauth?) && user.authorized_by_oauth?
        # 本体の admin? は権限範囲で偽になるので、列の値を見る
        return false unless user[:admin]

        studio_token?(request)
      end

      # 届いた鍵が、Redmine Studio のサインイン用アプリが発行したものか
      def studio_token?(request)
        app = RedmineStudioPlugin::OauthClient::AppRegistrar.registered_application
        return false if app.nil?

        token = Doorkeeper.authenticate(request)
        !token.nil? && token.accessible? && token.application_id == app.id
      rescue StandardError => e
        Rails.logger.warn "[redmine_studio_plugin] Server logs access check failed: #{e.class}: #{e.message}"
        false
      end
    end
  end
end
