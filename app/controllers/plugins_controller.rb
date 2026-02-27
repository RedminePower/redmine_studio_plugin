# frozen_string_literal: true

class PluginsController < ApplicationController
  accept_api_auth :index, :show

  before_action :require_login
  before_action :find_plugin, :only => [:show]

  def index
    all_plugins = Redmine::Plugin.all

    # Pagination
    @offset, @limit = api_offset_and_limit
    @total_count = all_plugins.count
    @plugins = all_plugins.drop(@offset).first(@limit)

    respond_to do |format|
      format.api
    end
  end

  def show
    respond_to do |format|
      format.api
    end
  end

  private

  def find_plugin
    @plugin = Redmine::Plugin.find(params[:id])
  rescue Redmine::PluginNotFound
    render_404
  end
end
