# frozen_string_literal: true

class InfoController < ApplicationController
  accept_api_auth :show
  # 追加 API は本体の login_required 設定に関わらず一律ログイン必須にする（匿名アクセス遮断）
  before_action :require_login

  # GET /info
  def show
    @info = gather_info
    respond_to do |format|
      format.api
    end
  end

  private

  def gather_info
    info = {
      redmine_version: Redmine::VERSION.to_s,
      ruby_version: "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]",
      rails_version: Rails::VERSION::STRING,
      environment: Rails.env,
      database_adapter: ActiveRecord::Base.connection.adapter_name,
      mailer_queue: ActionMailer::MailDeliveryJob.queue_adapter.class.name,
      mailer_delivery: ActionMailer::Base.delivery_method.to_s,
      redmine_theme: Setting.ui_theme.presence || 'Default',
      text_formatting: Setting.text_formatting,
      scm: gather_scm_info,
      plugins: gather_plugins_info
    }
    # サーバーの種類・同時に処理できる数・ログのレベルは、システム管理者のときだけ返す
    if User.current.admin?
      info[:app_server] = RedmineStudioPlugin::ServerLogs::AppServerInfo.app_server(request&.env || {})
      info[:log_level] = RedmineStudioPlugin::ServerLogs::AppServerInfo.log_level
    end
    info
  end

  def gather_scm_info
    Redmine::Scm::Base.all.map do |scm|
      scm_class = "Repository::#{scm}".constantize
      version = scm_class.scm_version_string
      { name: scm, version: version } if version.present?
    end.compact
  end

  def gather_plugins_info
    Redmine::Plugin.all.map do |plugin|
      { id: plugin.id.to_s, version: plugin.version.to_s }
    end
  end
end
