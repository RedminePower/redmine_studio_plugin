# frozen_string_literal: true

class ReviewSettingsController < ApplicationController
  accept_api_auth :index, :show, :create, :update, :destroy

  before_action :require_login
  before_action :find_review_setting, only: [:show, :update, :destroy]

  # GET /review_settings
  def index
    scope = ReviewSetting.all

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

    @review_settings = scope.order(:id)
    @include_payload = params[:include] == 'payload'

    respond_to do |format|
      format.api do
        render json: @review_settings.map { |s| s.as_json(include_payload: @include_payload) }
      end
    end
  end

  # GET /review_settings/:id
  def show
    respond_to do |format|
      format.api do
        render json: @review_setting.as_json(include_payload: true)
      end
    end
  end

  # POST /review_settings
  def create
    @review_setting = ReviewSetting.new(review_setting_params)
    @review_setting.created_by = User.current
    @review_setting.updated_by = User.current

    if @review_setting.save
      respond_to do |format|
        format.api do
          render json: @review_setting.as_json(include_payload: true), status: :created
        end
      end
    else
      respond_to do |format|
        format.api do
          render json: { errors: @review_setting.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end

  # PUT /review_settings/:id
  def update
    @review_setting.attributes = review_setting_params
    @review_setting.updated_by = User.current

    if @review_setting.save
      respond_to do |format|
        format.api do
          render json: @review_setting.as_json(include_payload: true)
        end
      end
    else
      respond_to do |format|
        format.api do
          render json: { errors: @review_setting.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /review_settings/:id
  def destroy
    if params[:force] == '1'
      # Physical delete
      @review_setting.destroy
    else
      # Logical delete
      @review_setting.soft_delete(User.current)
    end

    respond_to do |format|
      format.api do
        head :no_content
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

  def review_setting_params
    params.require(:review_setting).permit(:name, :scope_type, :scope_id, :payload, :schema_version)
  end
end
