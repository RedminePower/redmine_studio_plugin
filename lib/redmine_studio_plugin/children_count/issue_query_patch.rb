# frozen_string_literal: true

module RedmineStudioPlugin
  module ChildrenCount
    module IssueQueryPatch
      def issues(options = {})
        issues = super(options)
        if has_column?(:children_count)
          Issue.load_children_counts(issues)
        end
        issues
      end

      def joins_for_order_statement(order_options)
        joins = [super]

        if order_options&.include?('issue_children_counts_subquery')
          joins << "LEFT OUTER JOIN (SELECT parent_id, COUNT(*) AS cnt FROM #{Issue.table_name}" \
                   " WHERE parent_id IS NOT NULL GROUP BY parent_id) issue_children_counts_subquery" \
                   " ON issue_children_counts_subquery.parent_id = #{Issue.table_name}.id"
        end

        joins.compact!
        joins.any? ? joins.join(' ') : nil
      end
    end
  end
end
