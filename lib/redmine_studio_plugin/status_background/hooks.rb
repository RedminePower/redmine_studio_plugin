# frozen_string_literal: true

module RedmineStudioPlugin
  module StatusBackground
    class Hooks < Redmine::Hook::ViewListener
      # チケット詳細画面だけ、ステータスごとの背景色の CSS を head に入れる
      def view_layouts_base_html_head(context = {})
        controller = context[:controller]
        return '' unless controller.is_a?(::IssuesController) && controller.action_name == 'show'

        css = StyleBuilder.css(Setting.plugin_redmine_studio_plugin, ::IssueStatus.all)
        # 色は StyleBuilder で #rrggbb の形だけに絞っている
        css.empty? ? '' : content_tag(:style, css.html_safe)
      end
    end
  end
end
