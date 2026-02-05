# frozen_string_literal: true

namespace :redmine_studio_plugin do
  namespace :auto_close do
    desc '期限切れチケットの自動クローズを実行'
    task check_expired: :environment do
      processed_ids = []
      failed_ids = []
      skipped_rule_ids = []
      # 処理済みチケットを記録（issue_id => rule_id）
      already_processed = {}
      skipped_issue_ids = []

      rules = AutoClose.where(trigger_type: AutoClose::TRIGGER_TYPES_EXPIRED, is_enabled: true).order(:id)

      rules.each do |rule|
        issues = RedmineStudioPlugin::AutoClose::AutoCloseService.find_expired_issues(rule)

        # 閾値チェック
        if issues.count > rule.max_issues_per_run
          Rails.logger.warn "[redmine_studio_plugin:auto_close] Warning: Rule ##{rule.id} '#{rule.title}' targets #{issues.count} issues > threshold #{rule.max_issues_per_run} -> skipped"
          skipped_rule_ids << rule.id
          next
        end

        issues.each do |issue|
          # 既に他のルールで処理済みの場合はスキップ
          if already_processed.key?(issue.id)
            Rails.logger.info "[redmine_studio_plugin:auto_close] Info: Issue ##{issue.id} already processed by rule ##{already_processed[issue.id]}, skipping rule ##{rule.id}"
            skipped_issue_ids << issue.id unless skipped_issue_ids.include?(issue.id)
            next
          end

          begin
            # action_user を解決して User.current に設定
            action_user = RedmineStudioPlugin::AutoClose::AutoCloseService.resolve_action_user(rule, issue)
            if action_user.nil?
              Rails.logger.error "[redmine_studio_plugin:auto_close] Error: Failed to process issue ##{issue.id}: Could not resolve action user"
              failed_ids << issue.id
              next
            end

            User.current = action_user
            RedmineStudioPlugin::AutoClose::AutoCloseService.apply_rule(rule, issue)
            processed_ids << issue.id
            already_processed[issue.id] = rule.id
          rescue => e
            Rails.logger.error "[redmine_studio_plugin:auto_close] Error: Failed to process issue ##{issue.id}: #{e.message}"
            failed_ids << issue.id
          end
        end
      end

      summary = "[redmine_studio_plugin:auto_close] Completed: #{processed_ids.size} processed / #{failed_ids.size} failed / #{skipped_issue_ids.size} skipped (already processed) / #{skipped_rule_ids.size} rules skipped"
      if processed_ids.any? || failed_ids.any? || skipped_issue_ids.any? || skipped_rule_ids.any?
        details = []
        details << "processed: #{processed_ids.map { |id| "##{id}" }.join(', ')}" if processed_ids.any?
        details << "failed: #{failed_ids.map { |id| "##{id}" }.join(', ')}" if failed_ids.any?
        details << "skipped: #{skipped_issue_ids.map { |id| "##{id}" }.join(', ')}" if skipped_issue_ids.any?
        details << "skipped rules: #{skipped_rule_ids.map { |id| "##{id}" }.join(', ')}" if skipped_rule_ids.any?
        summary += " (#{details.join(' / ')})"
      end
      Rails.logger.info summary
      puts summary # cron の stdout リダイレクトで /log/auto_close.log に出力
    end
  end
end
