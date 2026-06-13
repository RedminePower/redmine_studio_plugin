# frozen_string_literal: true

module RedmineStudioPlugin
  module ChildrenCount
    module IssuePatch
      extend ActiveSupport::Concern

      # ツールチップに表示する件名の最大文字数（全角）
      SUBJECT_MAX_LENGTH = 30
      # ツールチップに表示する子チケットの最大件数
      TOOLTIP_MAX_CHILDREN = 10

      included do
        attr_writer :children_count_value, :children_tooltip
      end

      # プリロード済みの子チケット数を返す。
      # プリロードされていない場合は個別にロードする。
      def children_count_value
        return @children_count_value if defined?(@children_count_value)

        @children_count_value = Issue.visible.where(parent_id: id).count
      end

      # プリロード済みのツールチップを返す。
      # プリロードされていない場合は個別にロードする。
      def children_tooltip
        return @children_tooltip if defined?(@children_tooltip)

        @children_tooltip = self.class.build_children_tooltip(load_visible_children)
      end

      class_methods do
        # チケット一覧に対して、子チケット数とツールチップを一括プリロードする。
        def load_children_counts(issues)
          return unless issues.any?

          issue_ids = issues.map(&:id)

          # 子チケット情報を一括取得（visibility 適用）
          children_by_parent = Issue.visible
                                    .where(parent_id: issue_ids)
                                    .order(:id)
                                    .pluck(:parent_id, :id, :subject)
                                    .group_by(&:first)

          issues.each do |issue|
            rows = children_by_parent[issue.id] || []
            issue.children_count_value = rows.size
            issue.children_tooltip = build_children_tooltip(rows.map { |_, id, subject| [id, subject] })
          end
        end

        # 子チケットのツールチップ文字列を構築する。
        # rows: [[child_id, subject], ...]
        def build_children_tooltip(rows)
          return '' if rows.empty?

          displayed = rows.first(TOOLTIP_MAX_CHILDREN)
          lines = displayed.map { |child_id, subject| "##{child_id} #{truncate_subject(subject)}" }

          remaining = rows.size - displayed.size
          lines << "...#{I18n.t(:label_children_count_others, count: remaining)}" if remaining > 0

          lines.join("\n")
        end

        # 全角文字を考慮した件名の省略
        def truncate_subject(subject)
          return '' if subject.nil?
          return subject if subject.length <= SUBJECT_MAX_LENGTH

          "#{subject[0, SUBJECT_MAX_LENGTH]}..."
        end
      end

      private

      def load_visible_children
        Issue.visible
             .where(parent_id: id)
             .order(:id)
             .pluck(:id, :subject)
      end
    end
  end
end
