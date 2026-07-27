# frozen_string_literal: true

module RedmineStudioPlugin
  module ReplyCount
    module IssuePatch
      extend ActiveSupport::Concern

      included do
        after_save :update_reply_count
        has_one :reply_count_record, class_name: 'IssueReplyCount', dependent: :destroy
        attr_writer :reply_tooltip
      end

      # 返答回数の値を返す。
      # IssueReplyCount レコードが未生成のチケット（担当者変更が一度もない）は 0 を返す。
      # children_count_value と対の位置づけで、カラム表示・API レスポンス双方から本メソッドを呼ぶ。
      def reply_count_value
        reply_count_record&.count || 0
      end

      # プリロード済みのツールチップを返す。
      # プリロードされていない場合は個別にロードする。
      def reply_tooltip
        @reply_tooltip || load_reply_tooltip
      end

      class_methods do
        # チケット一覧に対して、返答回数のツールチップを一括プリロードする。
        def load_reply_tooltips(issues)
          return unless issues.any?

          issue_ids = issues.map(&:id)

          # 担当者変更履歴を一括取得
          changes = JournalDetail
            .joins(:journal)
            .where(journals: { journalized_type: 'Issue', journalized_id: issue_ids })
            .where(property: 'attr', prop_key: 'assigned_to_id')
            .order('journals.id')
            .pluck('journals.journalized_id', :old_value, :value)

          # ユーザー名を一括取得
          user_ids = changes.flat_map { |_, ov, v| [ov, v] }.compact.reject(&:empty?).map(&:to_i).uniq
          user_names = User.where(id: user_ids).map { |u| [u.id, u.name] }.to_h

          no_assignee = I18n.t(:label_reply_count_no_assignee)

          # チケットごとにツールチップを構築
          changes_by_issue = {}
          changes.each do |issue_id, old_value, new_value|
            changes_by_issue[issue_id] ||= []
            changes_by_issue[issue_id] << { old: old_value, new: new_value }
          end

          issues.each do |issue|
            issue_changes = changes_by_issue[issue.id]
            if issue_changes.nil? || issue_changes.empty?
              # 変更なし: 現在の担当者のみ
              name = issue.assigned_to ? issue.assigned_to.name : no_assignee
              issue.reply_tooltip = name
            else
              # 初期担当者（最初の変更の old_value）
              first_old = issue_changes.first[:old]
              initial = first_old.present? ? (user_names[first_old.to_i] || no_assignee) : no_assignee

              lines = [initial]
              issue_changes.each do |change|
                new_val = change[:new]
                name = new_val.present? ? (user_names[new_val.to_i] || no_assignee) : no_assignee
                lines << " - #{name}"
              end

              issue.reply_tooltip = lines.join("\n")
            end
          end
        end
      end

      private

      def update_reply_count
        return unless saved_change_to_assigned_to_id?
        return if id_previously_changed? # 新規作成時は除外

        record = IssueReplyCount.find_or_initialize_by(issue_id: id)
        record.count = (record.count || 0) + 1
        record.save
      end

      def load_reply_tooltip
        changes = JournalDetail
          .joins(:journal)
          .where(journals: { journalized_type: 'Issue', journalized_id: id })
          .where(property: 'attr', prop_key: 'assigned_to_id')
          .order('journals.id')
          .pluck(:old_value, :value)

        no_assignee = I18n.t(:label_reply_count_no_assignee)

        if changes.empty?
          name = assigned_to ? assigned_to.name : no_assignee
          return name
        end

        first_old = changes.first[0]
        initial = first_old.present? ? (User.find_by(id: first_old.to_i)&.name || no_assignee) : no_assignee

        lines = [initial]
        changes.each do |old_value, new_value|
          name = new_value.present? ? (User.find_by(id: new_value.to_i)&.name || no_assignee) : no_assignee
          lines << " - #{name}"
        end

        lines.join("\n")
      end
    end
  end
end
