# frozen_string_literal: true

module RedmineStudioPlugin
  module SubtaskListAccordion
    module UserPreferencePatch
      def self.prepended(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          if defined? safe_attributes
            safe_attributes :subtasks_default_expand_limit_upper
          end
        end
      end

      module InstanceMethods
        def subtasks_default_expand_limit_upper
          (self[:subtasks_default_expand_limit_upper] || 0).to_i
        end

        def subtasks_default_expand_limit_upper=(val)
          self[:subtasks_default_expand_limit_upper] = val
        end
      end
    end
  end
end
