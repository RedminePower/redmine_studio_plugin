# frozen_string_literal: true

module RedmineStudioPlugin
  module OauthClient
    # 前段 Basic 認証ゲートの裏でトークンエンドポイント（/oauth/token）を通すためのパッチ。
    #
    # 前段プロキシの Basic 認証を通すため、クライアントは Authorization: Basic にゲートの
    # 資格情報を載せる。ところが Doorkeeper はこのヘッダを OAuth クライアント資格情報
    # （client_id:client_secret）として解釈するため、ゲートの資格情報では該当クライアントが
    # 見つからず invalid_client（401）になってしまう。
    #
    # ここでは Basic のユーザー名が「登録済み OAuth アプリの uid」でない場合に限り、
    # クライアント資格情報としては無視して nil を返し、from_params（リクエストボディの
    # client_id）へフォールバックさせる。登録済みクライアントの Basic 認証は従来どおり尊重する。
    module DoorkeeperClientCredentialsPatch
      def from_basic(request)
        credentials = super
        return credentials if credentials.nil?

        uid = credentials.first
        # Basic の uid が登録済み OAuth アプリなら、正規のクライアント認証として尊重する
        return credentials if uid.present? && Doorkeeper.config.application_model.by_uid(uid)

        # それ以外（前段ゲートの資格情報など）はクライアント資格情報とみなさない
        nil
      end
    end
  end
end
