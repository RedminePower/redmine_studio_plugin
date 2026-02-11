# frozen_string_literal: true

module RedmineStudioPlugin
  module SubtaskListAccordion
    class Hooks < Redmine::Hook::ViewListener
      render_on :view_issues_show_description_bottom, :partial => 'issues/subtask_list_accordion/partial'
      render_on :view_my_account_preferences, :partial => 'my/subtask_list_accordion/preferences'

      def view_issues_context_menu_start(context = {})
        if issue_page?(context[:back])
          context[:controller].send(:render_to_string, {
            :partial => "context_menus/subtask_list_accordion/menu",
            :locals => context
          })
        end
      end

      private

      def issue_page?(path)
        path =~ Regexp.new("issues/+[0-9]")
      end
    end
  end
end
