# frozen_string_literal: true

module RedmineStudioPlugin
  module ChildrenCount
    module IssuePatch
      extend ActiveSupport::Concern

      # ツールチップに表示する件名の最大文字数（全角）
      SUBJECT_MAX_LENGTH = 30
      # items（API レスポンス）とツールチップ表示に含める子チケットの最大件数
      MAX_ITEMS = 10

      included do
        attr_writer :children_count_value, :children_items
      end

      # プリロード済みの子チケット数を返す。
      # プリロードされていない場合は個別にロードする。
      def children_count_value
        return @children_count_value if defined?(@children_count_value)

        @children_count_value = Issue.visible.where(parent_id: id).count
      end

      # 子チケット（先頭 MAX_ITEMS 件）を { id:, name: 件名 } の配列で返す。
      # プリロードされていない場合は個別にロードする。
      def children_items
        return @children_items if defined?(@children_items)

        @children_items = load_visible_children.first(MAX_ITEMS).map { |cid, subject| { id: cid, name: subject } }
      end

      # HTML カラム表示用のツールチップ。children_items から組み立てる。
      def children_tooltip
        self.class.build_children_tooltip(children_items, children_count_value)
      end

      class_methods do
        # チケット一覧に対して、子チケット数と children_items を一括プリロードする。
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
            issue.children_items = rows.first(MAX_ITEMS).map { |_, id, subject| { id: id, name: subject } }
          end
        end

        # children_items とトータル件数からツールチップ文字列を構築する。
        def build_children_tooltip(items, total_count)
          return '' if items.empty?

          lines = items.map { |item| "##{item[:id]} #{truncate_subject(item[:name])}" }

          remaining = total_count - items.size
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
