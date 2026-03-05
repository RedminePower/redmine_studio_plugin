# frozen_string_literal: true

class UserStudioSettingsController < ApplicationController
  accept_api_auth :index

  before_action :require_login
  before_action :find_user

  # GET /users/:id/studio_settings
  def index
    scope = StudioSettingAssignment.where(user_id: @user.id)
                                   .joins(:setting)
                                   .where(studio_settings: { deleted_on: nil })

    # Pagination
    @offset, @limit = api_offset_and_limit
    @total_count = scope.count
    @assignments = scope.order(:id).limit(@limit).offset(@offset)

    respond_to do |format|
      format.api
    end
  end

  private

  def find_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
