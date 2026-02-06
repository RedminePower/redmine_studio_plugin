# frozen_string_literal: true

class DateIndependentsController < ApplicationController
  layout 'admin'

  before_action :require_admin
  before_action :find_date_independent, :except => [:index, :new, :create]

  helper :sort
  include SortHelper

  def index
    sort_init 'id', 'desc'
    sort_update %w(id title is_enabled)
    items = DateIndependent.order(sort_clause)
    for item in items do
      item.migrate_project_pattern
      item.migrate_calculate_status_pattern
    end
    @date_independents = items

  end

  def new
    @date_independent = DateIndependent.new
  end

  def create
    @date_independent = DateIndependent.new(date_independent_params)
    @date_independent.project_ids = params[:date_independent][:project_ids]&.select(&:present?).map(&:to_i) || []
    @date_independent.calculate_status_ids = params[:date_independent][:calculate_status_ids]&.select(&:present?).map(&:to_i) || []

    if @date_independent.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to date_independent_path(@date_independent.id)
    else
      render :action => 'new'
    end
  end

  def show
  end

  def edit
  end

  def update
    @date_independent.attributes = date_independent_params
    @date_independent.project_ids = params[:date_independent][:project_ids]&.select(&:present?).map(&:to_i) || []
    @date_independent.calculate_status_ids = params[:date_independent][:calculate_status_ids]&.select(&:present?).map(&:to_i) || []

    if @date_independent.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to date_independent_path(@date_independent.id)
    else
      render :action => 'edit'
    end
  rescue ActiveRecord::StaleObjectError
    flash.now[:error] = l(:notice_locking_conflict)
    render :action => 'edit'
  end

  def destroy
    @date_independent.destroy
    redirect_to date_independents_path
  end

  private

  def find_date_independent
    @date_independent = DateIndependent.find(params[:id])
  end

  def date_independent_params
    params.require(:date_independent)
      .permit(
        :title,
        :is_enabled,
        :project_pattern,
        :calculate_status_pattern,
        :project_ids,
        :calculate_status_ids
      )
  end

end
