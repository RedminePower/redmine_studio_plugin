# frozen_string_literal: true

class StudioSettingHistoriesController < ApplicationController
  accept_api_auth :index, :show, :destroy, :restore

  before_action :require_login
  before_action :find_studio_setting
  before_action :find_history, only: [:show, :destroy]

  # GET /studio_settings/:studio_setting_id/histories
  def index
    scope = @studio_setting.histories.ordered

    # Pagination
    @offset, @limit = api_offset_and_limit
    @total_count = scope.count
    @histories = scope.limit(@limit).offset(@offset)
    @include_payload = params[:include].to_s.include?('payload')

    respond_to do |format|
      format.api
    end
  end

  # GET /studio_settings/:studio_setting_id/histories/:version
  def show
    respond_to do |format|
      format.api
    end
  end

  # DELETE /studio_settings/:studio_setting_id/histories/:version
  def destroy
    unless @history.deletable?
      respond_to do |format|
        format.api { render_api_errors('Cannot delete the current version') }
      end
      return
    end

    @history.destroy

    respond_to do |format|
      format.api { head :no_content }
    end
  end

  # POST /studio_settings/:id/restore
  def restore
    version = params[:version].to_i

    # Check if trying to restore to current version
    if version == @studio_setting.current_version
      respond_to do |format|
        format.api { render_api_errors('Cannot restore to the current version') }
      end
      return
    end

    # Check if version exists
    unless @studio_setting.histories.exists?(version: version)
      render_404
      return
    end

    comment = params[:comment]

    if @studio_setting.restore_from_version(version, User.current, comment: comment)
      respond_to do |format|
        format.api do
          @include_options = { include_payload: true }
          render 'studio_settings/show', status: :ok
        end
      end
    else
      respond_to do |format|
        format.api { render_validation_errors(@studio_setting) }
      end
    end
  end

  private

  def find_studio_setting
    # member routes use :id, nested routes use :studio_setting_id
    setting_id = params[:studio_setting_id] || params[:id]
    @studio_setting = StudioSetting.find(setting_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_history
    @history = @studio_setting.histories.find_by(version: params[:version])
    render_404 unless @history
  end
end
