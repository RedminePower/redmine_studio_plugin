namespace :redmine_studio_plugin do
  desc 'Setup: remove integrated plugins'
  task :setup => :environment do
    Rails.logger.info "[redmine_studio_plugin] Setup task started"

    plugins_dir = Rails.root.join('plugins')
    integrated_plugins = ['redmine_reply_button', 'redmine_teams_button']

    removed_plugins = []
    integrated_plugins.each do |plugin|
      plugin_path = plugins_dir.join(plugin)
      if File.directory?(plugin_path)
        puts "Removing #{plugin}..."
        FileUtils.rm_rf(plugin_path)
        puts "  #{plugin} removed."
        removed_plugins << plugin
      else
        puts "  #{plugin} not found (already removed or not installed)."
      end
    end

    puts ""
    if removed_plugins.any?
      puts "#{removed_plugins.size} plugin(s) removed."
      Rails.logger.info "[redmine_studio_plugin] Removed plugins: #{removed_plugins.join(', ')}"
    else
      puts "No plugins to remove."
      Rails.logger.info "[redmine_studio_plugin] No plugins to remove"
    end
    puts ""
    puts "Setup completed. Please restart Redmine to apply changes."

    Rails.logger.info "[redmine_studio_plugin] Setup task completed"
  end
end
