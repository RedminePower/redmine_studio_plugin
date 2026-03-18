# frozen_string_literal: true

module RedmineStudioPlugin
  module RallyCount
    class QueryColumn < ::QueryColumn
      def initialize
        super(
          :rally_count,
          sortable: "COALESCE(#{IssueRallyCount.table_name}.count, 0)",
          default_order: 'desc',
          caption: :field_rally_count
        )
      end

      def value_object(issue)
        issue.rally_count_record&.count || 0
      end
    end
  end
end
