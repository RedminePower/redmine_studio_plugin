# frozen_string_literal: true

module RedmineStudioPlugin
  module ChildrenCount
    module QueriesHelperPatch
      extend ActiveSupport::Concern

      included do
        alias_method :column_value_without_children_count, :column_value
        alias_method :column_value, :column_value_with_children_count
      end

      def column_value_with_children_count(column, item, value)
        if column.name == :children_count
          count = value.to_i
          if count == 0
            content_tag(:span, '0', class: 'children-count')
          else
            # project_id: nil を明示しないと、プロジェクトスコープのページから開いたとき
            # 現在の project_id が URL ヘルパに引き継がれて /projects/<id>/issues になってしまう
            url = url_for(controller: 'issues', action: 'index',
                          project_id: nil,
                          only_path: true,
                          set_filter: 1,
                          f: ['parent_id'],
                          op: { parent_id: '=' },
                          v: { parent_id: [item.id] })
            link_to(count.to_s, url, title: item.children_tooltip, class: 'children-count')
          end
        else
          column_value_without_children_count(column, item, value)
        end
      end
    end
  end
end
