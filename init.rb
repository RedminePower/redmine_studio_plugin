# frozen_string_literal: true

Rails.logger.info 'Starting Redmine Studio Plugin'

# Check for conflicting plugins (integrated plugins that still exist)
plugins_dir = Rails.root.join('plugins')
integrated_plugins = ['redmine_reply_button']
conflicting_plugins = integrated_plugins.select do |plugin|
  plugin_path = plugins_dir.join(plugin)
  # Check if plugin folder exists AND contains init.rb (valid plugin)
  File.directory?(plugin_path) && File.exist?(plugin_path.join('init.rb'))
end

if conflicting_plugins.any?
  # Warning message for console and log
  message = "WARNING: #{conflicting_plugins.join(', ')} should be removed. " \
            "Run 'bundle exec rake redmine_studio_plugin:setup RAILS_ENV=production' to remove them."
  Rails.logger.warn message
  puts message

  # Register plugin with warning in description
  Redmine::Plugin.register :redmine_studio_plugin do
    name 'Redmine Studio plugin'
    author 'Redmine Power'
    description "WARNING: Please remove #{conflicting_plugins.join(', ')} and run " \
                "'bundle exec rake redmine_studio_plugin:setup RAILS_ENV=production'. " \
                "Until then, integrated features are disabled to prevent conflicts."
    version '0.1.0'
    url 'https://github.com/RedminePower/redmine_studio_plugin'
    author_url 'https://www.redmine-power.com/'
  end
else
  # Normal registration with all features enabled
  Redmine::Plugin.register :redmine_studio_plugin do
    name 'Redmine Studio plugin'
    author 'Redmine Power'
    description 'Provides features for Redmine Studio (Windows client application provided by Redmine Power).'
    version '0.1.0'
    url 'https://github.com/RedminePower/redmine_studio_plugin'
    author_url 'https://www.redmine-power.com/'

    # Reply Button module (same name as original plugin for settings inheritance)
    project_module :reply_button do
      permission :reply_button, :reply_button => [:index]
    end
  end

  # Load hooks only when no conflicts
  require_relative 'lib/redmine_studio_plugin/reply_button/hooks'
end
