# frozen_string_literal: true

namespace :redmine_studio_plugin do
  desc 'プラグインのアンインストール（cron解除 + DBロールバック）'
  task uninstall: :environment do
    puts '=== redmine_studio_plugin uninstall ==='
    Rails.logger.info '[redmine_studio_plugin] Uninstall task started'

    # 1. cron解除
    puts "\n[1/2] Removing cron job..."
    current_cron = `crontab -l 2>/dev/null` rescue ''
    new_cron = current_cron.lines.reject { |line| line.include?('redmine_studio_plugin:auto_close:check_expired') }.join
    IO.popen('crontab -', 'w') { |io| io.write(new_cron) }
    puts 'Cron job removed'

    # 2. DBロールバック
    puts "\n[2/2] Rolling back DB migration..."
    ENV['NAME'] = 'redmine_studio_plugin'
    ENV['VERSION'] = '0'
    Rake::Task['redmine:plugins:migrate'].reenable
    Rake::Task['redmine:plugins:migrate'].invoke
    puts 'Done'

    puts "\n=== Uninstall completed ==="
    Rails.logger.info '[redmine_studio_plugin] Uninstall task completed'
  end
end
