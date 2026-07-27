# frozen_string_literal: true

module RedmineStudioPlugin
  module ReplyCount
    class QueryColumn < ::QueryColumn
      def initialize
        super(
          :reply_count,
          sortable: "COALESCE(#{IssueReplyCount.table_name}.count, 0)",
          default_order: 'desc',
          caption: :field_reply_count
        )
      end

      def value_object(issue)
        issue.reply_count_value
      end
    end
  end
end
