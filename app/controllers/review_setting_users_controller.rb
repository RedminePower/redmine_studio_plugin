# frozen_string_literal: true

class ReviewSettingUsersController < ApplicationController
  accept_api_auth :index, :replace, :add, :remove

  before_action :require_login
  before_action :find_review_setting

  # GET /review_settings/:id/users
  def index
    respond_to do |format|
      format.api do
        render json: @review_setting.assignments.map(&:as_json)
      end
    end
  end

  # PUT /review_settings/:id/users
  def replace
    user_ids = JSON.parse(request.body.read) rescue []

    # Ensure user_ids is an array
    unless user_ids.is_a?(Array)
      respond_to do |format|
        format.api do
          render json: { errors: ['Request body must be an array of user IDs'] }, status: :unprocessable_entity
        end
      end
      return
    end

    ReviewSettingAssignment.transaction do
      # Remove all existing assignments
      @review_setting.assignments.destroy_all

      # Create new assignments
      @assignments = user_ids.map do |user_id|
        assignment = ReviewSettingAssignment.new(
          setting: @review_setting,
          user_id: user_id,
          assigned_by: User.current
        )
        assignment.save!
        assignment
      end
    end

    respond_to do |format|
      format.api do
        render json: @assignments.map(&:as_json)
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.api do
        render json: { errors: [e.message] }, status: :unprocessable_entity
      end
    end
  end

  # POST /review_settings/:id/users/:user_id
  def add
    user_id = params[:user_id]

    # Check if assignment already exists
    existing = @review_setting.assignments.find_by(user_id: user_id)
    if existing
      respond_to do |format|
        format.api do
          render json: existing.as_json
        end
      end
      return
    end

    @assignment = ReviewSettingAssignment.new(
      setting: @review_setting,
      user_id: user_id,
      assigned_by: User.current
    )

    if @assignment.save
      respond_to do |format|
        format.api do
          render json: @assignment.as_json, status: :created
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

  # DELETE /review_settings/:id/users/:user_id
  def remove
    user_id = params[:user_id]
    assignment = @review_setting.assignments.find_by(user_id: user_id)

    if assignment
      assignment.destroy
      respond_to do |format|
        format.api do
          head :no_content
        end
      end
    else
      respond_to do |format|
        format.api do
          render json: { error: "Assignment not found: setting_id=#{params[:id]}, user_id=#{params[:user_id]}" }, status: :not_found
        end
      end
    end
  end

  private

  def find_review_setting
    @review_setting = ReviewSetting.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.api do
        render json: { error: "Review setting not found: id=#{params[:id]}" }, status: :not_found
      end
    end
  end
end
