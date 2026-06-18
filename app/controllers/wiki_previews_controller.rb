# frozen_string_literal: true

class WikiPreviewsController < ApplicationController
  accept_api_auth :create

  # POST /wiki_preview
  def create
    return unless validate_params!

    project = find_project
    @html = render_wiki(params[:text].to_s, project)

    respond_to do |format|
      format.api
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  private

  # textilizable で Redmine 本体のプレビューと同等のレンダリングを行う。
  # 基本記法に加え、マクロ・#123 チケットリンク・[[Wiki]] リンクも展開される。
  #
  # マクロ（ref_issues など）は内部で HTML パーシャル（issues/_list 等）を描画するため、
  # 実行中だけレンダリングのフォーマットを HTML に固定する。リクエストは JSON/XML のため、
  # 固定しないとパーシャル探索が :json/:api になり「Missing partial」で失敗する。
  # lookup_context はコントローラと共有されるので、ensure で必ず元に戻し、
  # 後続の format.api（create.api.rsb）の応答描画に影響させない。
  def render_wiki(text, project)
    view = view_context
    lookup = view.lookup_context
    original = lookup.formats
    lookup.formats = [:html]
    view.textilizable(text, :project => project)
  ensure
    lookup.formats = original if lookup
  end

  def validate_params!
    # text は必須（空文字は許可し、空の HTML を返す）。
    if params[:text].nil?
      respond_to do |format|
        format.api { render_api_errors('text is required') }
      end
      return false
    end
    true
  end

  # project_id は任意。指定された場合のみプロジェクトコンテキストで
  # レンダリングする（マクロや #123 / [[Wiki]] リンクの解決に使用）。
  # 閲覧できないプロジェクトを指定した場合は 404 を返す。
  def find_project
    return nil if params[:project_id].blank?

    Project.visible.find(params[:project_id])
  end
end
