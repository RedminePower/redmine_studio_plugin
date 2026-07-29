# frozen_string_literal: true

module RedmineStudioPlugin
  module ReplyCount
    module IssueQueryPatch
      def issues(options = {})
        issues = super(options)
        if has_column?(:reply_count)
          Issue.load_reply_items(issues)
        end
        issues
      end

      def joins_for_order_statement(order_options)
        joins = [super]

        if order_options&.include?('issue_reply_counts')
          joins << "LEFT OUTER JOIN #{IssueReplyCount.table_name}" \
                   " ON #{IssueReplyCount.table_name}.issue_id = #{Issue.table_name}.id"
        end

        joins.compact!
        joins.any? ? joins.join(' ') : nil
      end
    end
  end
end
