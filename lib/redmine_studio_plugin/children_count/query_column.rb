# frozen_string_literal: true

module RedmineStudioPlugin
  module ChildrenCount
    class QueryColumn < ::QueryColumn
      def initialize
        super(
          :children_count,
          sortable: 'COALESCE(issue_children_counts_subquery.cnt, 0)',
          default_order: 'desc',
          caption: :field_children_count
        )
      end

      def value_object(issue)
        issue.children_count_value
      end
    end
  end
end
