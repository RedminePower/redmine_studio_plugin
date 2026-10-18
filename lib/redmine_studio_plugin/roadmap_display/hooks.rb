# frozen_string_literal: true

module RedmineStudioPlugin
  module RoadmapDisplay
    class Hooks < Redmine::Hook::ViewListener
      # バージョン画面の下部で一覧を描画し、JS で「関連するチケット」の位置へ移す
      render_on :view_versions_show_bottom, partial: 'roadmap_displays/version_hook'

      def view_layouts_base_html_head(context = {})
        tags = stylesheet_link_tag('roadmap_display.css', plugin: :redmine_studio_plugin)
        hide = standard_list_hidden_style(context)
        hide ? tags + hide : tags
      end

      private

      # 一覧を差し込む前に標準の一覧がちらつかないよう、head で隠しておく
      def standard_list_hidden_style(context)
        controller = context[:controller]
        return nil unless controller.is_a?(::VersionsController) && controller.action_name == 'show'

        version = controller.instance_variable_get(:@version)
        display = version && ::RoadmapDisplay.for_project(version.project)
        return nil if display.nil? || display.keep_standard_list

        content_tag(:style, '#roadmap table.related-issues { display: none; }')
      end
    end
  end
end
