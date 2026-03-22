# frozen_string_literal: true

# AJAX 経由で呼ばれるため、エラー時はクライアント側で "Failed to load." と表示されるだけで
# 原因の特定が困難になる。そのため、他のコントローラーと異なりログ出力を追加している。
class JournalsListController < ApplicationController
  before_action :find_journal, only: [:show]
  before_action :find_journals, only: [:show_all]

  # GET /journals_list/:id
  # 単一ジャーナルの Wiki レンダリング結果を返す
  def show
    html = view_context.textilizable(@journal, :notes)
    render plain: html, content_type: 'text/html'
  rescue => e
    Rails.logger.error "[JournalsList] Render error: issue_id=#{@journal&.journalized_id}, journal_id=#{@journal&.id}, error=#{e.class}: #{e.message}"
    render plain: 'Render error', status: :internal_server_error
  end

  # GET /journals_list/show_all?ids[]=1&ids[]=2
  # 複数ジャーナルの Wiki レンダリング結果を一括で返す
  def show_all
    result = {}
    @journals.each do |journal|
      result[journal.id] = view_context.textilizable(journal, :notes)
    end
    render json: result
  rescue => e
    journal_info = @journals&.map { |j| "issue_id=#{j.journalized_id},journal_id=#{j.id}" }&.join('; ')
    Rails.logger.error "[JournalsList] Render error in show_all: #{journal_info}, error=#{e.class}: #{e.message}"
    render json: { error: 'Render error' }, status: :internal_server_error
  end

  private

  def find_journal
    @journal = Journal.find(params[:id])
    unless @journal.journalized.visible? && @journal.visible?
      Rails.logger.warn "[JournalsList] Unauthorized: issue_id=#{@journal.journalized_id}, journal_id=#{params[:id]}, user=#{User.current.login}"
      raise Unauthorized
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "[JournalsList] NotFound: journal_id=#{params[:id]}, user=#{User.current.login}"
    render_404
  end

  def find_journals
    ids = Array(params[:ids]).map(&:to_i)
    @journals = Journal.where(id: ids).preload(journalized: :project).to_a
    filtered_count = @journals.size
    @journals.select! { |j| j.journalized.visible? && j.visible? }
    if @journals.size < filtered_count
      Rails.logger.warn "[JournalsList] Filtered #{filtered_count - @journals.size} journals due to visibility: user=#{User.current.login}"
    end
  end
end
