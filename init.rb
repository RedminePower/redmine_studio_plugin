# frozen_string_literal: true

require 'yaml'

Rails.logger.info 'Starting Redmine Studio Plugin'

# Load integrated plugins list from config
plugin_root = File.dirname(__FILE__)
config_path = File.join(plugin_root, 'config', 'integrated_plugins.yml')
config = YAML.load_file(config_path)
integrated_plugins = config['integrated_plugins'] || []

# Check for conflicting plugins (integrated plugins that still exist)
plugins_dir = Rails.root.join('plugins')
conflicting_plugins = integrated_plugins.select do |plugin|
  plugin_path = plugins_dir.join(plugin)
  # Check if plugin folder exists AND contains init.rb (valid plugin)
  File.directory?(plugin_path) && File.exist?(plugin_path.join('init.rb'))
end

if conflicting_plugins.any?
  # Warning message for console and log
  message = "WARNING: Setup is not complete. " \
            "Run 'bundle exec rake redmine_studio_plugin:install RAILS_ENV=production' to complete setup."
  Rails.logger.warn message
  puts message

  # Register plugin with warning in description
  Redmine::Plugin.register :redmine_studio_plugin do
    name 'Redmine Studio plugin'
    author 'Redmine Power'
    description "WARNING: Setup is not complete. " \
                "Run 'bundle exec rake redmine_studio_plugin:install RAILS_ENV=production'. " \
                "Until then, integrated features are disabled to prevent conflicts."
    version '1.0.0'
    url 'https://github.com/RedminePower/redmine_studio_plugin'
    author_url 'https://www.redmine-power.com/'
  end
else
  # Normal registration with all features enabled
  Redmine::Plugin.register :redmine_studio_plugin do
    name 'Redmine Studio plugin'
    author 'Redmine Power'
    description 'Provides features for Redmine Studio (Windows client application provided by Redmine Power).'
    version '1.0.0'
    url 'https://github.com/RedminePower/redmine_studio_plugin'
    author_url 'https://www.redmine-power.com/'

    # Reply Button module (same name as original plugin for settings inheritance)
    project_module :reply_button do
      permission :reply_button, :reply_button => [:index]
    end

    # Teams Button module (same name as original plugin for settings inheritance)
    project_module :teams_button do
      permission :teams_button, :teams_button => [:index]
    end

    # Auto Close - admin menu
    menu :admin_menu, :auto_closes,
         { controller: 'auto_closes', action: 'index' },
         caption: :label_auto_close,
         html: { class: 'icon icon-auto_close' },
         if: proc { User.current.admin? }

    # Date Independent - admin menu
    menu :admin_menu, :date_independents,
         { controller: 'date_independents', action: 'index' },
         caption: :di_label_date_independent,
         html: { class: 'icon icon-date_independent' },
         if: proc { User.current.admin? }

    # Subtask List Accordion settings
    settings default: {
      'subtask_list_accordion_enable_server_scripting_mode' => true,
      'subtask_list_accordion_expand_all' => false,
      'subtask_list_accordion_collapsed_trackers' => '',
      'subtask_list_accordion_collapsed_tracker_ids' => []
    }, partial: 'settings/subtask_list_accordion/settings'
  end

  # Load hooks only when no conflicts
  require_relative 'lib/redmine_studio_plugin/reply_button/hooks'
  require_relative 'lib/redmine_studio_plugin/teams_button/hooks'

  # Load Auto Close
  require_relative 'lib/redmine_studio_plugin/auto_close/hooks'
  require_relative 'lib/redmine_studio_plugin/auto_close/auto_close_service'
  require_relative 'lib/redmine_studio_plugin/auto_close/issue_patch'

  # Load Date Independent
  require_relative 'lib/redmine_studio_plugin/date_independent/hooks'
  require_relative 'lib/redmine_studio_plugin/date_independent/issue_patch'

  # Load Wiki Lists macros
  require_relative 'lib/redmine_studio_plugin/wiki_lists/wiki_list'
  require_relative 'lib/redmine_studio_plugin/wiki_lists/issue_name_link'
  require_relative 'lib/redmine_studio_plugin/wiki_lists/ref_issues/parser'
  require_relative 'lib/redmine_studio_plugin/wiki_lists/ref_issues'

  # Load Subtask List Accordion
  require_relative 'lib/redmine_studio_plugin/subtask_list_accordion/hooks'
  require_relative 'lib/redmine_studio_plugin/subtask_list_accordion/issues_helper_patch'
  require_relative 'lib/redmine_studio_plugin/subtask_list_accordion/user_preference_patch'

  # Apply patches directly (init.rb is already executed inside to_prepare)
  Issue.include RedmineStudioPlugin::AutoClose::IssuePatch
  Issue.prepend RedmineStudioPlugin::DateIndependent::IssuePatch

  # Subtask List Accordion patches
  UserPreference.prepend RedmineStudioPlugin::SubtaskListAccordion::UserPreferencePatch
  IssuesHelper.include RedmineStudioPlugin::SubtaskListAccordion::IssuesHelperPatch
end
