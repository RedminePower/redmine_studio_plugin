# frozen_string_literal: true

module RedmineStudioPlugin
  module RallyCount
    module IssueQueryPatch
      def issues(options = {})
        issues = super(options)
        if has_column?(:rally_count)
          Issue.load_rally_tooltips(issues)
        end
        issues
      end

      def joins_for_order_statement(order_options)
        joins = [super]

        if order_options&.include?('issue_rally_counts')
          joins << "LEFT OUTER JOIN #{IssueRallyCount.table_name}" \
                   " ON #{IssueRallyCount.table_name}.issue_id = #{Issue.table_name}.id"
        end

        joins.compact!
        joins.any? ? joins.join(' ') : nil
      end
    end
  end
end
