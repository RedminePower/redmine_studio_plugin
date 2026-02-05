# frozen_string_literal: true

require 'yaml'

namespace :redmine_studio_plugin do
  desc 'プラグインのインストール（旧プラグイン削除 + DBマイグレーション + cron登録）'
  task install: :environment do
    puts '=== redmine_studio_plugin install ==='
    Rails.logger.info '[redmine_studio_plugin] Install task started'

    # 1. 旧スタンドアロンプラグインの削除
    puts "\n[1/3] Removing integrated plugins..."
    plugin_root = Rails.root.join('plugins', 'redmine_studio_plugin')
    config_path = plugin_root.join('config', 'integrated_plugins.yml')
    config = YAML.load_file(config_path)
    integrated_plugins = config['integrated_plugins'] || []

    plugins_dir = Rails.root.join('plugins')

    removed_plugins = []
    integrated_plugins.each do |plugin|
      plugin_path = plugins_dir.join(plugin)
      if File.directory?(plugin_path)
        puts "  Removing #{plugin}..."
        FileUtils.rm_rf(plugin_path)
        puts "  #{plugin} removed."
        removed_plugins << plugin
      else
        puts "  #{plugin} not found (already removed or not installed)."
      end
    end

    if removed_plugins.any?
      puts "  #{removed_plugins.size} plugin(s) removed."
      Rails.logger.info "[redmine_studio_plugin] Removed plugins: #{removed_plugins.join(', ')}"
    else
      puts "  No plugins to remove."
    end

    # 2. DBマイグレーション
    puts "\n[2/3] Running DB migration..."
    Rake::Task['redmine:plugins:migrate'].invoke
    puts 'Done'

    # 3. cron登録
    puts "\n[3/3] Registering cron job..."
    redmine_path = Rails.root
    cron_line = "0 3 * * * cd #{redmine_path} && bundle exec rake redmine_studio_plugin:auto_close:check_expired RAILS_ENV=production >> log/auto_close.log 2>&1"
    current_cron = `crontab -l 2>/dev/null` rescue ''

    # 旧プラグイン（redmine_auto_close）の cron エントリを削除
    if current_cron.include?('redmine_auto_close:check_expired')
      current_cron = current_cron.lines.reject { |line| line.include?('redmine_auto_close:check_expired') }.join
      IO.popen('crontab -', 'w') { |io| io.write(current_cron) }
      puts 'Removed legacy cron job (redmine_auto_close)'
    end

    if current_cron.include?('redmine_studio_plugin:auto_close:check_expired')
      puts 'Already registered'
    else
      new_cron = current_cron.chomp + "\n" + cron_line + "\n"
      IO.popen('crontab -', 'w') { |io| io.write(new_cron) }
      puts "Registered cron job: #{cron_line}"
    end

    puts "\n=== Install completed ==="
    puts 'Please restart Redmine to apply changes.'
    Rails.logger.info '[redmine_studio_plugin] Install task completed'
  end
end
