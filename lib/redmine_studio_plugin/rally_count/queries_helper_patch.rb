# frozen_string_literal: true

module RedmineStudioPlugin
  module RallyCount
    module QueriesHelperPatch
      extend ActiveSupport::Concern

      included do
        alias_method :column_value_without_rally_count, :column_value
        alias_method :column_value, :column_value_with_rally_count
      end

      def column_value_with_rally_count(column, item, value)
        if column.name == :rally_count
          tooltip = item.rally_tooltip
          content_tag(:span, value.to_s, title: tooltip, class: 'rally-count')
        else
          column_value_without_rally_count(column, item, value)
        end
      end
    end
  end
end
