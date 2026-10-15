# frozen_string_literal: true

module RedmineStudioPlugin
  module SubtaskListAccordion
    module IssuesHelperPatch
      extend ActiveSupport::Concern

      # wrap original method
      included do
        alias_method :render_descendants_tree_original, :render_descendants_tree
        alias_method :render_descendants_tree, :switch_render_descendants_tree
      end

      # switch by enable condition
      def switch_render_descendants_tree(issue)
        if sla_has_grandson_issues?(issue) && !subtask_tree_client_processing?
          render_descendants_tree_accordion(issue)
        else
          render_descendants_tree_original(issue)
        end
      end

      # Inject accordion attributes into the core subtask table so that columns,
      # headers and buttons always stay identical to the core rendering
      # (which follows the related-issues display settings)
      def render_descendants_tree_accordion(issue)
        children = []
        issue_list(issue.descendants.visible.preload(:status, :priority, :tracker, :assigned_to).sort_by(&:lft)) do |child, level|
          children << [child, level]
        end

        core_html = render_descendants_tree_original(issue)
        doc = Nokogiri::HTML::DocumentFragment.parse(core_html)
        rows = doc.css('tr.issue')
        # Rows must correspond one-to-one to the issue list built from the same query;
        # fall back to the plain core table if they do not
        return core_html unless rows.size == children.size

        tr_idx = 0
        collapsed_level = 999
        rows.each_with_index do |row, i|
          child, level = children[i]
          if collapsed_level < level
            expand_tree_at_first = false
            show_at_first = false
          else
            expand_tree_at_first = expand_tree_at_first?(issue, child)
            show_at_first = true
            collapsed_level = expand_tree_at_first ? 999 : level
          end

          descendant_count = child.descendants.visible.count
          row.add_class('haschild') if child.children?
          row.add_class(expand_tree_at_first ? 'expand' : 'collapse')
          row['cs'] = (tr_idx += 1).to_s
          row['ce'] = (tr_idx + descendant_count - 1).to_s
          row['rank'] = level.to_s
          row['style'] = 'display: none;' unless level <= 0 || show_at_first

          if descendant_count > 0
            row.at_css('td.subject')&.prepend_child('<span class="treearrow"></span>')
          end
        end
        doc.to_html.html_safe
      end

      def expand_tree_at_first?(issue, child = nil)
        expand_all = Setting.plugin_redmine_studio_plugin['subtask_list_accordion_expand_all']
        if expand_all
          collapsed_tracker_ids = Setting.plugin_redmine_studio_plugin['subtask_list_accordion_collapsed_tracker_ids']

          if collapsed_tracker_ids.present? && child
            return collapsed_tracker_ids.exclude?(child.tracker.id.to_s)
          end

          return true
        end

        return issue.descendants.visible.count <= User.current.pref.subtasks_default_expand_limit_upper
      end

      def sla_has_grandson_issues?(issue)
        return issue.descendants.visible.where(["issues.parent_id <> ?", issue.id]).count > 0
      end

      def subtask_tree_client_processing?
        return !Setting.plugin_redmine_studio_plugin['subtask_list_accordion_enable_server_scripting_mode']
      end
    end
  end
end
