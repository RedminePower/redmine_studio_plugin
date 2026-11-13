# frozen_string_literal: true

class StudioSettingUsersController < ApplicationController
  accept_api_auth :index, :replace, :add, :remove
  helper :studio_setting_assignments

  before_action :require_login
  before_action :find_studio_setting
  before_action :authorize_studio_setting, only: [:index]
  before_action :authorize_edit_studio_setting, only: [:replace, :add, :remove]
  before_action :reject_user_scope, only: [:replace, :add]

  # GET /studio_settings/:id/users
  def index
    scope = @studio_setting.assignments

    # Pagination
    @offset, @limit = api_offset_and_limit
    @total_count = scope.count
    @assignments = scope.order(:id).limit(@limit).offset(@offset)

    respond_to do |format|
      format.api
    end
  end

  # PUT /studio_settings/:id/users
  def replace
    # JSON / XML どちらのリクエストボディも受けられるよう、生ボディの JSON.parse ではなく Rails の params 経由で取得する
    user_ids = params[:user_ids] || []

    # Ensure user_ids is an array
    unless user_ids.is_a?(Array)
      respond_to do |format|
        format.api { render_api_errors('user_ids must be an array') }
      end
      return
    end

    StudioSettingAssignment.transaction do
      # 設定の行を押さえてから読む（同時の置き換え・割り当てで、互いの結果が混ざらないように）
      @studio_setting.lock!

      # 送られた中に今もいる人の割り当ては、確かめ直さずにそのまま残す
      # （今の一覧を読んで送り返すと、ロック中の人などがいるだけで全体が断られないように）。
      # 列と同じ型にそろえて比べる（"5" と 5 を同じ人として扱う）
      user_id_type = StudioSettingAssignment.type_for_attribute(:user_id)
      requested = user_ids.map { |user_id| user_id_type.cast(user_id) }
      kept, to_remove = @studio_setting.assignments.to_a.partition { |a| requested.include?(a.user_id) }
      to_remove.each(&:destroy!)
      kept_by_user = kept.index_by(&:user_id)

      # 新しく足す人だけを作る（同じ人が 2 回あると、2 回目は重複で断る）
      @assignments = user_ids.map do |user_id|
        kept_by_user.delete(user_id_type.cast(user_id)) ||
          StudioSettingAssignment.create!(
            setting: @studio_setting,
            user_id: user_id,
            assigned_by: User.current
          )
      end
    end

    respond_to do |format|
      format.api
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.api { render_validation_errors(e.record) }
    end
  end

  # POST /studio_settings/:id/users/:user_id
  def add
    # もう割り当て済みなら（同時に届いた同じ依頼が先に書いた場合も）、今ある割り当てを 200 で返す
    @assignment, created = StudioSettingAssignment.assign(@studio_setting, params[:user_id], User.current)

    if @assignment.persisted?
      respond_to do |format|
        format.api { render :action => 'add', :status => created ? :created : :ok }
      end
    else
      respond_to do |format|
        format.api { render_validation_errors(@assignment) }
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

  def authorize_studio_setting
    render_403 unless @studio_setting.visible?(User.current)
  end

  # 本人の設定の割り当ては、本人と管理者だけが変えられる
  def authorize_edit_studio_setting
    render_403 unless @studio_setting.editable?(User.current)
  end

  # 本人の設定は本人だけが使うので、人に割り当てない（割り当てると相手の一覧に出てしまう）
  def reject_user_scope
    return unless @studio_setting.user_scope?

    # before_action の中では、respond_to で包まないと Redmine 5.1 で Content-Type が text/html になる
    respond_to do |format|
      format.api { render_api_errors('A user setting cannot be assigned to users') }
    end
  end
end
