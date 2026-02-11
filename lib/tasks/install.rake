# frozen_string_literal: true

require 'yaml'

namespace :redmine_studio_plugin do
  desc 'プラグインのインストール（設定移行 + 旧プラグイン削除 + DBマイグレーション + cron登録）'
  task install: :environment do
    puts '=== redmine_studio_plugin install ==='
    Rails.logger.info '[redmine_studio_plugin] Install task started'

    # 1. 旧プラグインからの設定移行
    puts "\n[1/4] Migrating settings from legacy plugins..."
    migrate_subtask_list_accordion_settings

    # 2. 旧スタンドアロンプラグインの削除
    puts "\n[2/4] Removing integrated plugins..."
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

    # 3. DBマイグレーション
    puts "\n[3/4] Running DB migration..."
    Rake::Task['redmine:plugins:migrate'].invoke
    puts 'Done'

    # 4. cron登録
    puts "\n[4/4] Registering cron job..."
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

  # Subtask List Accordion の設定移行
  def migrate_subtask_list_accordion_settings
    # 旧プラグインが削除されている場合、動的メソッドは使えないため DB から直接読み取る
    # Setting#value は available_settings を参照するため、[:value] で直接アクセスする
    legacy_record = Setting.find_by(name: 'plugin_redmine_subtask_list_accordion')

    if legacy_record.nil? || legacy_record[:value].blank?
      puts '  redmine_subtask_list_accordion: No settings to migrate (not installed or no settings).'
      return
    end

    legacy_settings = YAML.safe_load(legacy_record[:value], permitted_classes: [Symbol]) rescue {}

    if legacy_settings.blank?
      puts '  redmine_subtask_list_accordion: No settings to migrate (empty settings).'
      return
    end

    # 移行対象のキーマッピング（元のキー => 新しいキー）
    key_mapping = {
      'enable_server_scripting_mode' => 'subtask_list_accordion_enable_server_scripting_mode',
      'expand_all' => 'subtask_list_accordion_expand_all',
      'collapsed_trackers' => 'subtask_list_accordion_collapsed_trackers',
      'collapsed_tracker_ids' => 'subtask_list_accordion_collapsed_tracker_ids'
    }

    current_settings = Setting.plugin_redmine_studio_plugin || {}
    migrated_keys = []

    key_mapping.each do |old_key, new_key|
      if legacy_settings.key?(old_key) && !current_settings.key?(new_key)
        current_settings[new_key] = legacy_settings[old_key]
        migrated_keys << old_key
      end
    end

    if migrated_keys.any?
      Setting.plugin_redmine_studio_plugin = current_settings
      puts "  redmine_subtask_list_accordion: Migrated #{migrated_keys.size} setting(s): #{migrated_keys.join(', ')}"
      Rails.logger.info "[redmine_studio_plugin] Migrated subtask_list_accordion settings: #{migrated_keys.join(', ')}"
    else
      puts '  redmine_subtask_list_accordion: Settings already migrated or using defaults.'
    end
  end
end
