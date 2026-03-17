# frozen_string_literal: true

module RedmineStudioPlugin
  module JournalsList
    module IssueQueryPatch
      def issues(options = {})
        issues = super(options)
        if has_column?(:journals_list)
          Issue.load_visible_journals_list(issues)
        end
        issues
      end
    end
  end
end
