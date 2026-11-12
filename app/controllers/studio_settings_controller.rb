# frozen_string_literal: true

class StudioSettingsController < ApplicationController
  accept_api_auth :index, :show, :create, :update, :destroy, :versions

  before_action :require_login
  before_action :find_studio_setting, only: [:show, :update, :destroy]
  before_action :authorize_studio_setting, only: [:show]
  before_action :authorize_edit_studio_setting, only: [:update, :destroy]

  # GET /studio_settings
  def index
    scope = StudioSetting.visible(User.current)

    # Filter by ids（カンマ区切り。変化したものだけをまとめて読むため）
    if params[:ids].present?
      scope = scope.where(id: parse_ids(params[:ids]))
    end

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

  # POST /studio_settings/versions
  # 本人の設定（own: schema_type の配列）と、id で頼んだ設定（ids: id の配列。範囲は問わない）の版だけを返す。
  # 求めたのに返らないものは「確定的に無い」。そう読めるよう、読めない依頼は 200 の空で返さず 422 で断る。
  def versions
    # XML は一番外側の要素が 1 つ要るので studio_setting_versions で包んで送られる。包みがあればその中から読む
    src = params[:studio_setting_versions].is_a?(ActionController::Parameters) ? params[:studio_setting_versions] : params
    unless src.key?(:own) || src.key?(:ids)
      return render_api_errors('own or ids is required')
    end

    own_types = versions_list(src, :own) { |v| v.is_a?(String) && v.present? }
    return render_api_errors('own must be an array of schema_type') if own_types.nil?

    team_ids = versions_list(src, :ids) { |v| v.is_a?(Integer) || (v.is_a?(String) && v =~ /\A\d+\z/) }
    return render_api_errors('ids must be an array of integers') if team_ids.nil?

    team_ids = team_ids.map(&:to_i).uniq

    @own_settings =
      if own_types.empty?
        []
      else
        StudioSetting.not_deleted
                     .where(scope_type: StudioSetting::SCOPE_USER, owner_id: User.current.id, schema_type: own_types)
                     .order(:id).to_a
      end
    @team_settings =
      if team_ids.empty?
        []
      else
        StudioSetting.visible(User.current).not_deleted.where(id: team_ids).order(:id).to_a
      end

    respond_to do |format|
      format.api
    end
  end

  # POST /studio_settings
  def create
    @studio_setting = StudioSetting.new(studio_setting_params)
    # 本人の設定は持ち主を省けば自分。他人の分を作れるのは管理者だけ。
    if @studio_setting.user_scope?
      @studio_setting.scope_id ||= User.current.id
      return render_403 unless @studio_setting.editable?(User.current)
    end
    # project スコープはメンバー（or admin）のみ作成可。global は誰でも作れる。決まった値でない範囲は検証（422）で断る
    return render_403 if @studio_setting.scope_type == 'project' && !@studio_setting.visible?(User.current)

    @studio_setting.created_by = User.current
    @studio_setting.updated_by = User.current

    # 本人の設定が既にある（2 台同時の初回保存など）なら、後の方を断り、今ある設定を返す
    return render_existing_user_setting if @studio_setting.user_scope? && existing_user_setting

    if save_with_history(@studio_setting, 'create')
      respond_to do |format|
        format.api do
          render :action => 'show', :status => :created,
                 :location => studio_setting_url(@studio_setting)
        end
      end
    else
      # 確かめた後に別の端末が先に作った（重複禁止の索引か、重複の検証で断られた）
      return render_existing_user_setting if @studio_setting.user_scope? && existing_user_setting

      respond_to do |format|
        format.api { render_validation_errors(@studio_setting) }
      end
    end
  end

  # PUT /studio_settings/:id
  def update
    attrs = studio_setting_params
    # 範囲は付け替えさせない（本人の設定を他人の物にしたり、本人の設定に変えたりしない）
    if attrs.key?(:scope_type) && attrs[:scope_type].to_s != @studio_setting.scope_type &&
       (@studio_setting.user_scope? || attrs[:scope_type].to_s == StudioSetting::SCOPE_USER)
      return render_api_errors('scope_type cannot be changed to or from user')
    end
    if @studio_setting.user_scope?
      attrs = attrs.except(:scope_id, :schema_type)
    end

    expected = expected_version_param
    # 添えたのに数として読めない版は、「無し」と同じに扱わず断る（黙って上書きしない）
    return render_api_errors('expected_version must be an integer') if expected == :invalid
    # 本人の設定は、最後にそろえた版を必ず添えてもらう（黙って上書きしない）
    if @studio_setting.user_scope? && expected.nil?
      return render_api_errors('expected_version is required')
    end

    saved = false
    conflict = false
    StudioSetting.transaction do
      # 版の確認と保存の間に別の書き込みが入らないよう、行を押さえてから比べる
      @studio_setting.lock!
      if !expected.nil? && @studio_setting.version != expected
        conflict = true
        raise ActiveRecord::Rollback
      end

      @studio_setting.attributes = attrs
      @studio_setting.updated_by = User.current
      saved = @studio_setting.save
      # 履歴も同じ取引の中で作る（行を押さえている間に番号を決める）。
      # Undelete is handled solely by the restore API (deleted_on is not permitted here).
      @studio_setting.create_history('update', User.current, comment: params[:studio_setting][:comment]) if saved
    end
    return render_version_conflict if conflict

    if saved
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
    if @studio_setting.user_scope?
      # 本人の設定は履歴も残さないので、消した印も付けずに消す（作り直せるように）
      @studio_setting.destroy
    elsif params[:force] == '1'
      # Physical delete (histories will be deleted by CASCADE)
      @studio_setting.destroy
    else
      # Logical delete (creates history record)
      @studio_setting.soft_delete(User.current, comment: params[:comment])
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

  def authorize_studio_setting
    render_403 unless @studio_setting.visible?(User.current)
  end

  def authorize_edit_studio_setting
    render_403 unless @studio_setting.editable?(User.current)
  end

  def studio_setting_params
    params.require(:studio_setting).permit(:name, :schema_type, :scope_type, :scope_id, :payload, :schema_version)
  end

  # 最後にそろえた版。studio_setting の中だけで受ける（読みの version と同じ要素の中に置く）。
  # 無ければ nil、数として読めなければ :invalid
  def expected_version_param
    raw = params.dig(:studio_setting, :expected_version)
    return nil if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)
    return raw if raw.is_a?(Integer)
    return :invalid unless raw.is_a?(String)

    Integer(raw.strip, 10)
  rescue ArgumentError
    :invalid
  end

  # 版の口の own・ids を配列として読む。鍵が無い・空なら []、配列でない・決まりに合わない値があれば nil
  def versions_list(src, key)
    return [] unless src.key?(key)

    raw = src[key]
    return [] if raw.nil? || raw == ''
    return nil unless raw.is_a?(Array)
    return nil unless raw.all? { |v| yield v }

    raw
  end

  # "1,2,3" でも ["1","2"] でも受ける
  def parse_ids(raw)
    list = raw.is_a?(Array) ? raw : raw.to_s.split(',')
    list.map { |v| v.to_s.strip }.select { |v| v =~ /\A\d+\z/ }.map(&:to_i).uniq
  end

  def existing_user_setting
    StudioSetting.find_user_setting(@studio_setting.scope_id, @studio_setting.schema_type)
  end

  # 保存と履歴の作成を 1 つの取引で行う。
  # 本人の設定で、確かめた直後に別の端末が作った場合は、データベースの重複禁止で断られる（false を返し、呼ぶ側が今ある設定を返す）
  def save_with_history(setting, change_type)
    saved = false
    StudioSetting.transaction do
      saved = setting.save
      setting.create_history(change_type, User.current, comment: params[:studio_setting][:comment]) if saved
    end
    saved
  rescue ActiveRecord::RecordNotUnique
    raise unless setting.user_scope?

    false
  end

  # 409：本人の設定は既にある。今ある設定（id・version・中身）を返す
  def render_existing_user_setting
    @studio_setting = existing_user_setting
    respond_to do |format|
      format.api { render action: 'show', status: :conflict }
    end
  end

  # 409：版が古い。今の設定（id・version・中身）を返すので、それに重ね直してもらう
  def render_version_conflict
    @studio_setting.reload
    respond_to do |format|
      format.api { render action: 'show', status: :conflict }
    end
  end

  def parse_include_params
    includes = params[:include].to_s.split(',').map(&:strip)
    {
      include_payload: includes.include?('payload'),
      include_assignments: includes.include?('assignments')
    }
  end
end
