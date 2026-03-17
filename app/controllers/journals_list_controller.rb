# frozen_string_literal: true

class JournalsListController < ApplicationController
  before_action :find_journal, only: [:show]
  before_action :find_journals, only: [:show_all]

  # GET /journals_list/:id
  # 単一ジャーナルの Wiki レンダリング結果を返す
  def show
    html = view_context.textilizable(@journal, :notes)
    render plain: html, content_type: 'text/html'
  end

  # GET /journals_list/show_all?ids[]=1&ids[]=2
  # 複数ジャーナルの Wiki レンダリング結果を一括で返す
  def show_all
    result = {}
    @journals.each do |journal|
      result[journal.id] = view_context.textilizable(journal, :notes)
    end
    render json: result
  end

  private

  def find_journal
    @journal = Journal.find(params[:id])
    raise Unauthorized unless @journal.journalized.visible? && @journal.visible?
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_journals
    ids = Array(params[:ids]).map(&:to_i)
    @journals = Journal.where(id: ids).preload(journalized: :project).to_a
    @journals.select! { |j| j.journalized.visible? && j.visible? }
  end
end
