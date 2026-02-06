# frozen_string_literal: true

module RedmineStudioPlugin
  module DateIndependent
    class Hooks < Redmine::Hook::ViewListener

      # 全ビューのベースHTMLを作成時
      def view_layouts_base_html_head(context = { })
          stylesheet_link_tag('date_independent.css', :plugin => 'redmine_studio_plugin')
      end

    end
  end
end
