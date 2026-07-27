# frozen_string_literal: true

module RedmineStudioPlugin
  module ReplyCount
    module QueriesHelperPatch
      extend ActiveSupport::Concern

      included do
        alias_method :column_value_without_reply_count, :column_value
        alias_method :column_value, :column_value_with_reply_count
      end

      def column_value_with_reply_count(column, item, value)
        if column.name == :reply_count
          tooltip = item.reply_tooltip
          content_tag(:span, value.to_s, title: tooltip, class: 'reply-count')
        else
          column_value_without_reply_count(column, item, value)
        end
      end
    end
  end
end
