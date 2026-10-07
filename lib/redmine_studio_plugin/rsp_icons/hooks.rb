# frozen_string_literal: true

module RedmineStudioPlugin
  module RspIcons
    # Load the bundled, self-contained icon styles so the plugin's buttons keep their icons
    # regardless of changes to Redmine's own icon assets (e.g. the raster icon classes that
    # Redmine 7.0 removed from the core stylesheet).
    class Hooks < Redmine::Hook::ViewListener
      def view_layouts_base_html_head(_context = {})
        stylesheet_link_tag('rsp_icons.css', plugin: :redmine_studio_plugin)
      end
    end
  end
end
