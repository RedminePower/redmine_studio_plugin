# frozen_string_literal: true

module RedmineStudioPlugin
  module JournalsList
    class QueryColumn < ::QueryColumn
      def initialize
        super(:journals_list, inline: false, caption: :field_journals_list)
      end

      def value_object(issue)
        issue.visible_journals_with_notes
      end
    end
  end
end
