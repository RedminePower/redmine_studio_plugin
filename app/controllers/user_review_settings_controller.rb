# frozen_string_literal: true

class UserReviewSettingsController < ApplicationController
  accept_api_auth :index

  before_action :require_login
  before_action :find_user

  # GET /users/:id/review_settings
  def index
    @assignments = ReviewSettingAssignment.where(user_id: @user.id)
                                          .joins(:setting)
                                          .where(review_settings: { deleted_on: nil })
                                          .order(:id)

    respond_to do |format|
      format.api do
        render json: @assignments.map(&:as_json)
      end
    end
  end

  private

  def find_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.api do
        render json: { error: "User not found: id=#{params[:id]}" }, status: :not_found
      end
    end
  end
end
