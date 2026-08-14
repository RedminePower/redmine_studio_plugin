# frozen_string_literal: true

class OauthClientController < ApplicationController
  accept_api_auth :show
  # サインイン開始前に、認証情報なしで client_id を取得するための唯一の匿名窓口。
  # 本体の login_required 設定に関わらず匿名で到達させるため、ログイン要求だけスキップする。
  skip_before_action :check_if_login_required, only: [:show]

  # GET /oauth_client
  def show
    @application = RedmineStudioPlugin::OauthClient::AppRegistrar.registered_application
    @scopes = @application ? @application.scopes.all : []
    respond_to do |format|
      format.api
    end
  end
end
