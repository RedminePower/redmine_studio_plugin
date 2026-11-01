# frozen_string_literal: true

require 'yaml'
require_relative '../redmine_studio_plugin/auto_close/cron_job'

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

    # 4. cron登録（扱うのは実行した利用者の crontab の、この Redmine の行だけ）
    puts "\n[4/4] Registering cron job..."
    redmine_studio_plugin_register_cron_job

    puts "\n=== Install completed ==="
    puts 'Please restart Redmine to apply changes.'
    Rails.logger.info '[redmine_studio_plugin] Install task completed'
  end

  # 期限切れ時の自動クローズを毎日動かす cron の行を登録する
  def redmine_studio_plugin_register_cron_job
    cron = RedmineStudioPlugin::AutoClose::CronJob
    root = Rails.root
    user = cron.user_name
    env = cron.cron_env
    elsewhere = cron.system_entries(root)
    current, error = cron.read_crontab
    if error == :no_crontab_command
      # crontab が無い環境（Docker の公式イメージなど）では、止めずに知らせて続ける
      if elsewhere.any?
        elsewhere.each { |file, line| puts "  Already registered in #{file}: #{line}" }
        return
      end
      puts '  WARNING: The crontab command was not found, so the cron job was not registered.'
      puts '  To use the overdue trigger of Auto Close, add the following line to a crontab yourself'
      puts '  (for Docker, add it to the crontab on the host. See "About the cron job" in README):'
      puts "    #{cron.build_line(root, env)}"
      redmine_studio_plugin_check_cron_job(cron, root, env, 'Checked: the line above can start rake.')
      return
    end
    if current.nil?
      puts "  Could not read the crontab of user '#{user}': #{error}"
      puts '  The cron job was not registered.'
      return
    end

    plan = cron.plan_install(current, root, env, registered_elsewhere: elsewhere.any?)

    if plan[:text] != current
      ok, message = cron.write_crontab(plan[:text])
      unless ok
        puts "  Could not write the crontab of user '#{user}': #{message}"
        puts '  The cron job was not registered, and the crontab was not changed.'
        return
      end
    end

    plan[:removed].each { |line| puts "  Removed: #{line}" }
    cron.other_lines(current, root).each { |line| puts "  Left as is (not for this Redmine): #{line}" }
    if elsewhere.any?
      elsewhere.each { |file, line| puts "  Already registered in #{file}: #{line}" }
      puts "  Not added to the crontab of user '#{user}' to avoid running twice."
      return
    end

    state = plan[:added] ? 'Registered' : 'Already registered'
    puts "  #{state} in the crontab of user '#{user}': #{plan[:line]}"
    redmine_studio_plugin_check_cron_job(cron, root, env, 'Checked: rake can be started under cron.')
  end

  # cron の中と同じ条件で、登録する行の rake を起動できるかを試して表示する
  def redmine_studio_plugin_check_cron_job(cron, root, env, checked_message)
    ok, output = cron.self_test(root, env)
    if ok
      puts "  #{checked_message}"
    else
      puts '  WARNING: rake could not be started in the same environment as cron (PATH=/usr/bin:/bin, no other variables).'
      puts '  The cron job will probably fail. Error:'
      output.lines.reject { |line| line.start_with?("\tfrom") }.first(3).each { |line| puts "    #{line.chomp[0, 300]}" }
    end
    puts '  Each run writes its result to log/auto_close.log ("Completed" on success).'
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
