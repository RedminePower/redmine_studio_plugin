# frozen_string_literal: true

module RedmineStudioPlugin
  module RoadmapDisplay
    module QueriesHelperPatch
      extend ActiveSupport::Concern

      included do
        alias_method :column_content_without_roadmap_display, :column_content
        alias_method :column_content, :column_content_with_roadmap_display
      end

      # ロードマップ表示の中だけ、標準のロードマップと同じく担当者の前にアバターを付ける。
      # 標準のチケット一覧（issues/list）の見た目は変えない。
      def column_content_with_roadmap_display(column, item)
        content = column_content_without_roadmap_display(column, item)
        return content unless @rsp_roadmap_display && column.name == :assigned_to && item.respond_to?(:assigned_to)

        assignee = item.assigned_to
        return content unless assignee

        avatar_tag = respond_to?(:assignee_avatar) ? assignee_avatar(assignee, size: 16) : avatar(assignee, size: 16)
        avatar_tag.present? ? safe_join([avatar_tag, ' ', content]) : content
      end
    end
  end
end
