# frozen_string_literal: true

class StudioSettingsController < ApplicationController
  accept_api_auth :index, :show, :create, :update, :destroy

  before_action :require_login
  before_action :find_studio_setting, only: [:show, :update, :destroy]

  # GET /studio_settings
  def index
    scope = StudioSetting.all

    # Filter by schema_type
    if params[:schema_type].present?
      scope = scope.where(schema_type: params[:schema_type])
    end

    # Filter by scope_type
    if params[:scope_type].present?
      scope = scope.where(scope_type: params[:scope_type])
    end

    # Filter by scope_id
    if params[:scope_id].present?
      scope = scope.where(scope_id: params[:scope_id])
    end

    # Include deleted or not (default: exclude deleted)
    unless params[:include_deleted] == '1'
      scope = scope.not_deleted
    end

    # Pagination
    @offset, @limit = api_offset_and_limit
    @total_count = scope.count
    @studio_settings = scope.order(:id).limit(@limit).offset(@offset)
    @include_options = parse_include_params

    respond_to do |format|
      format.api
    end
  end

  # GET /studio_settings/:id
  def show
    @include_options = parse_include_params

    respond_to do |format|
      format.api
    end
  end

  # POST /studio_settings
  def create
    @studio_setting = StudioSetting.new(studio_setting_params)
    @studio_setting.created_by = User.current
    @studio_setting.updated_by = User.current

    if @studio_setting.save
      respond_to do |format|
        format.api do
          render :action => 'show', :status => :created,
                 :location => studio_setting_url(@studio_setting)
        end
      end
    else
      respond_to do |format|
        format.api { render_validation_errors(@studio_setting) }
      end
    end
  end

  # PUT /studio_settings/:id
  def update
    @studio_setting.attributes = studio_setting_params
    @studio_setting.updated_by = User.current

    if @studio_setting.save
      respond_to do |format|
        format.api { render :action => 'show', :status => :ok }
      end
    else
      respond_to do |format|
        format.api { render_validation_errors(@studio_setting) }
      end
    end
  end

  # DELETE /studio_settings/:id
  def destroy
    if params[:force] == '1'
      # Physical delete
      @studio_setting.destroy
    else
      # Logical delete
      @studio_setting.soft_delete(User.current)
    end

    respond_to do |format|
      format.api do
        head :no_content
      end
    end
  end

  private

  def find_studio_setting
    @studio_setting = StudioSetting.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def studio_setting_params
    params.require(:studio_setting).permit(:name, :schema_type, :scope_type, :scope_id, :payload, :schema_version)
  end

  def parse_include_params
    includes = params[:include].to_s.split(',').map(&:strip)
    {
      include_payload: includes.include?('payload'),
      include_assignments: includes.include?('assignments')
    }
  end
end
