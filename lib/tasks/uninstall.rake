# frozen_string_literal: true

require_relative '../redmine_studio_plugin/auto_close/cron_job'

namespace :redmine_studio_plugin do
  desc 'プラグインのアンインストール（cron解除 + DBロールバック）'
  task uninstall: :environment do
    puts '=== redmine_studio_plugin uninstall ==='
    Rails.logger.info '[redmine_studio_plugin] Uninstall task started'

    # 1. cron解除（扱うのは実行した利用者の crontab の、この Redmine の行だけ）
    puts "\n[1/2] Removing cron job..."
    cron_cleared = redmine_studio_plugin_unregister_cron_job

    # 2. DBロールバック
    puts "\n[2/2] Rolling back DB migration..."
    ENV['NAME'] = 'redmine_studio_plugin'
    ENV['VERSION'] = '0'
    Rake::Task['redmine:plugins:migrate'].reenable
    Rake::Task['redmine:plugins:migrate'].invoke
    puts 'Done'

    unless cron_cleared
      puts "\nWARNING: A cron job for this Redmine may remain (see [1/2]). It fails every day after the uninstall, so remove it."
    end
    puts "\n=== Uninstall completed ==="
    Rails.logger.info '[redmine_studio_plugin] Uninstall task completed'
  end

  # 期限切れ時の自動クローズを毎日動かす cron の行を外す。この Redmine の行が残っていないとき true
  def redmine_studio_plugin_unregister_cron_job
    cron = RedmineStudioPlugin::AutoClose::CronJob
    root = Rails.root
    user = cron.user_name
    cleared = true
    current, error = cron.read_crontab
    if current.nil?
      puts "  Could not read the crontab of user '#{user}': #{error}"
      cleared = false
    else
      plan = cron.plan_uninstall(current, root)
      if plan[:removed].empty?
        puts "  No cron job in the crontab of user '#{user}' (run this as the user who ran the install)."
      else
        ok, message = cron.write_crontab(plan[:text])
        if ok
          plan[:removed].each { |line| puts "  Removed: #{line}" }
        else
          puts "  Could not write the crontab of user '#{user}': #{message}"
          cleared = false
        end
      end
      cron.other_lines(current, root).each { |line| puts "  Left as is (not for this Redmine): #{line}" }
    end
    cron.system_entries(root).each do |file, line|
      puts "  Also registered in #{file} (remove it manually): #{line}"
      cleared = false
    end
    cleared
  end
end
