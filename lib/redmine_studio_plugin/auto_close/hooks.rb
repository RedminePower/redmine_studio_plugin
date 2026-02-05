# frozen_string_literal: true

module RedmineStudioPlugin
  module AutoClose
    class Hooks < Redmine::Hook::ViewListener
      # Inject CSS into all views
      def view_layouts_base_html_head(_context = {})
        stylesheet_link_tag('auto_close.css', plugin: :redmine_studio_plugin)
      end
    end
  end
end
