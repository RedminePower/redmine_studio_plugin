# frozen_string_literal: true

class RoadmapDisplaysController < ApplicationController
  layout 'admin'
  self.main_menu = false

  before_action :require_admin
  before_action :find_roadmap_display, only: %i[edit update destroy]

  helper :queries
  helper :issues
  helper :sort
  include SortHelper

  def index
    @roadmap_displays = RoadmapDisplay.sorted.to_a
  end

  def new
    source = RoadmapDisplay.find_by(id: params[:copy_from])
    @roadmap_display = source ? source.copy : RoadmapDisplay.new
    @query = @roadmap_display.build_query
  end

  def create
    @roadmap_display = RoadmapDisplay.new
    @roadmap_display.attributes = roadmap_display_params
    if @roadmap_display.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to roadmap_displays_path
    else
      @query = @roadmap_display.build_query
      render action: 'new'
    end
  end

  def edit
    @query = @roadmap_display.build_query
  end

  def update
    @roadmap_display.attributes = roadmap_display_params
    if @roadmap_display.save
      respond_to do |format|
        format.html do
          flash[:notice] = l(:notice_successful_update)
          redirect_to roadmap_displays_path
        end
        format.js { head :ok }
      end
    else
      respond_to do |format|
        format.html do
          @query = @roadmap_display.build_query
          render action: 'edit'
        end
        format.js { head 422 }
      end
    end
  end

  def destroy
    @roadmap_display.destroy
    redirect_to roadmap_displays_path
  end

  # 編集中のプロジェクトパターンに当てはまるプロジェクト（保存前の確認用）
  def matches
    @roadmap_display = RoadmapDisplay.find_by(id: params[:id]) || RoadmapDisplay.new
    @roadmap_display.project_pattern = params[:project_pattern].to_s
    @roadmap_display.is_enabled = true
    render partial: 'roadmap_displays/matches', locals: { roadmap_display: @roadmap_display }
  end

  # 編集中の内容で、指定バージョンの表示を確認する
  def preview
    @roadmap_display = RoadmapDisplay.find_by(id: params[:id]) || RoadmapDisplay.new
    @roadmap_display.attributes = roadmap_display_params if params[:roadmap_display]
    version = Version.visible.find_by(id: params[:version_id])
    return render plain: l(:rd_text_select_version) unless version

    render partial: 'roadmap_displays/issue_list',
           locals: { roadmap_display: @roadmap_display, version: version }
  end

  private

  def find_roadmap_display
    @roadmap_display = RoadmapDisplay.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def roadmap_display_params
    raw = params.require(:roadmap_display)
    permitted = raw.permit(
      :name, :is_enabled, :project_pattern, :position, :group_by, :status_scope, :keep_standard_list,
      column_names: [], totalable_names: []
    ).to_h
    # 並び替えのつまみ（position だけの更新）では列などを空にしない
    return permitted if permitted.keys == ['position']

    permitted['column_names'] = Array(permitted['column_names']).reject(&:blank?)
    permitted['totalable_names'] = Array(permitted['totalable_names']).reject(&:blank?)
    permitted['sort_criteria'] = normalize_sort_criteria(raw[:sort_criteria])
    permitted
  end

  # {"0"=>["status","asc"], "1"=>["", ""]} → [["status", "asc"]]
  def normalize_sort_criteria(value)
    return [] if value.blank?

    hash = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
    hash.sort_by { |k, _| k.to_i }.map { |_, v| Array(v).map(&:to_s) }
        .select { |field, _| field.present? }
        .map { |field, order| [field, order.presence || 'asc'] }
  end
end
