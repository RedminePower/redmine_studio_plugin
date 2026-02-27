# frozen_string_literal: true

class StudioSettingUsersController < ApplicationController
  accept_api_auth :index, :replace, :add, :remove

  before_action :require_login
  before_action :find_studio_setting

  # GET /studio_settings/:id/users
  def index
    scope = @studio_setting.assignments

    # Pagination
    @offset, @limit = api_offset_and_limit
    @total_count = scope.count
    @assignments = scope.order(:id).limit(@limit).offset(@offset)

    respond_to do |format|
      format.api do
        render json: {
          studio_setting_assignments: @assignments.map(&:as_json),
          total_count: @total_count,
          offset: @offset || 0,
          limit: @limit
        }
      end
    end
  end

  # PUT /studio_settings/:id/users
  def replace
    body = JSON.parse(request.body.read) rescue {}
    user_ids = body['user_ids'] || []

    # Ensure user_ids is an array
    unless user_ids.is_a?(Array)
      respond_to do |format|
        format.api do
          render json: { errors: ['user_ids must be an array'] }, status: :unprocessable_entity
        end
      end
      return
    end

    StudioSettingAssignment.transaction do
      # Remove all existing assignments
      @studio_setting.assignments.destroy_all

      # Create new assignments
      @assignments = user_ids.map do |user_id|
        assignment = StudioSettingAssignment.new(
          setting: @studio_setting,
          user_id: user_id,
          assigned_by: User.current
        )
        assignment.save!
        assignment
      end
    end

    respond_to do |format|
      format.api do
        render json: { studio_setting_assignments: @assignments.map(&:as_json) }
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.api do
        render json: { errors: [e.message] }, status: :unprocessable_entity
      end
    end
  end

  # POST /studio_settings/:id/users/:user_id
  def add
    user_id = params[:user_id]

    # Check if assignment already exists
    existing = @studio_setting.assignments.find_by(user_id: user_id)
    if existing
      respond_to do |format|
        format.api do
          render json: { studio_setting_assignment: existing.as_json }
        end
      end
      return
    end

    @assignment = StudioSettingAssignment.new(
      setting: @studio_setting,
      user_id: user_id,
      assigned_by: User.current
    )

    if @assignment.save
      respond_to do |format|
        format.api do
          render json: { studio_setting_assignment: @assignment.as_json }, status: :created
        end
      end
    else
      respond_to do |format|
        format.api do
          render json: { errors: @assignment.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /studio_settings/:id/users/:user_id
  def remove
    user_id = params[:user_id]
    assignment = @studio_setting.assignments.find_by(user_id: user_id)

    if assignment
      assignment.destroy
      respond_to do |format|
        format.api do
          head :no_content
        end
      end
    else
      render_404
    end
  end

  private

  def find_studio_setting
    @studio_setting = StudioSetting.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
