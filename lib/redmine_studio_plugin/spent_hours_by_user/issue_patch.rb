# frozen_string_literal: true

module RedmineStudioPlugin
  module SpentHoursByUser
    module IssuePatch
      extend ActiveSupport::Concern

      included do
        attr_writer :spent_hours_by_user_items
      end

      # 本チケットとその子孫（subtree）に紐づく作業時間を、担当者(ユーザー)ごとに集計した配列を返す。
      # 要素は { user_id:, hours: }。アプリ（表編集）は担当者を切り替えるたびにこの配列から
      # 該当ユーザーの合計を引き、per-issue の作業時間再取得を避ける。
      # プリロードされていない場合は個別にロードする。
      def spent_hours_by_user_items
        return @spent_hours_by_user_items if defined?(@spent_hours_by_user_items)

        @spent_hours_by_user_items = load_own_spent_hours_by_user
      end

      class_methods do
        # チケット一覧に対して、担当者ごとの subtree 作業時間を一括プリロードする（N+1 回避）。
        # core の load_visible_total_spent_hours と同じ nested set 結合で subtree を辿り、user_id を足して集計する。
        def load_spent_hours_by_user(issues)
          return unless issues.any?

          issue_ids = issues.map(&:id)

          # 可視な作業時間のみ対象（TimeEntry.visible）。 => { [parent_id, user_id] => hours }
          hours = TimeEntry.visible
                           .joins(:issue)
                           .joins("JOIN #{Issue.table_name} parent ON parent.root_id = #{Issue.table_name}.root_id" \
                                  " AND parent.lft <= #{Issue.table_name}.lft AND parent.rgt >= #{Issue.table_name}.rgt")
                           .where("parent.id IN (?)", issue_ids)
                           .group("parent.id", "#{TimeEntry.table_name}.user_id")
                           .sum("#{TimeEntry.table_name}.hours")

          hours_by_issue = Hash.new { |h, k| h[k] = {} }
          hours.each do |(parent_id, user_id), total|
            hours_by_issue[parent_id][user_id] = total
          end

          issues.each do |issue|
            issue.spent_hours_by_user_items = to_spent_hours_items(hours_by_issue[issue.id])
          end
        end

        # { user_id => hours } を API 出力用の { user_id:, hours: } 配列に変換する。
        def to_spent_hours_items(hours_by_user)
          hours_by_user.map { |user_id, hours| { user_id: user_id, hours: hours.to_f } }
        end
      end

      private

      # 単一チケットの subtree 作業時間を担当者別に集計する。
      # subtree の絞り込みは core の TimeEntry.on_issue スコープをそのまま利用する。
      def load_own_spent_hours_by_user
        self.class.to_spent_hours_items(TimeEntry.visible.on_issue(self).group(:user_id).sum(:hours))
      end
    end
  end
end
