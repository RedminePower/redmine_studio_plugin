# frozen_string_literal: true

module RedmineStudioPlugin
  module TeamsButton
    class Hooks < Redmine::Hook::ViewListener
      # CSSを差し込む
      def view_layouts_base_html_head(context = {})
        stylesheet_link_tag('teams_button.css', :plugin => 'redmine_studio_plugin')
      end

      # Teamsボタンを表示する
      def view_issues_edit_notes_bottom(context = {})
        return false unless context[:issue].project.module_enabled?(:teams_button)

        context[:controller].send(:render_to_string, {
          :partial => "issues/teams_button/teams_button",
          :locals => context
        })
      end
    end
  end
end
