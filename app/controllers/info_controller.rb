# frozen_string_literal: true

class InfoController < ApplicationController
  accept_api_auth :show

  # GET /info
  def show
    @info = gather_info
    respond_to do |format|
      format.api
    end
  end

  private

  def gather_info
    {
      redmine_version: Redmine::VERSION.to_s,
      ruby_version: "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]",
      rails_version: Rails::VERSION::STRING,
      environment: Rails.env,
      database_adapter: ActiveRecord::Base.connection.adapter_name,
      mailer_queue: ActionMailer::MailDeliveryJob.queue_adapter.class.name,
      mailer_delivery: ActionMailer::Base.delivery_method.to_s,
      redmine_theme: Setting.ui_theme.presence || 'Default',
      scm: gather_scm_info,
      plugins: gather_plugins_info
    }
  end

  def gather_scm_info
    Redmine::Scm::Base.all.filter_map do |scm|
      scm_class = "Repository::#{scm}".constantize
      version = scm_class.scm_version_string
      { name: scm, version: version } if version.present?
    end
  end

  def gather_plugins_info
    Redmine::Plugin.all.map do |plugin|
      { id: plugin.id.to_s, version: plugin.version.to_s }
    end
  end
end
