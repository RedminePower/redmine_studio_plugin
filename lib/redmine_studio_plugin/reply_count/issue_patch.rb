# frozen_string_literal: true

module RedmineStudioPlugin
  module ReplyCount
    module IssuePatch
      extend ActiveSupport::Concern

      included do
        after_save :update_reply_count
        has_one :reply_count_record, class_name: 'IssueReplyCount', dependent: :destroy
        attr_writer :reply_items
      end

      # 返答回数の値を返す。
      # IssueReplyCount レコードが未生成のチケット（担当者変更が一度もない）は 0 を返す。
      # children_count_value と対の位置づけで、カラム表示・API レスポンス双方から本メソッドを呼ぶ。
      def reply_count_value
        reply_count_record&.count || 0
      end

      # 担当者の遷移（初期担当者 → 変更ごとの新担当者）を { id:, name: } の配列で返す。
      # 担当者なしは id: 0, name: ''、削除済み等の無効ユーザーは id: 元のID, name: '' で表現する。
      # 変更履歴がないチケットは現在の担当者 1 件を返す。
      # プリロードされていない場合は個別にロードする。
      def reply_items
        @reply_items || load_own_reply_items
      end

      # HTML カラム表示用のツールチップ。reply_items から組み立てる。
      def reply_tooltip
        self.class.build_reply_tooltip(reply_items)
      end

      class_methods do
        # チケット一覧に対して、担当者の遷移 (reply_items) を一括プリロードする。
        def load_reply_items(issues)
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

          changes_by_issue = changes.group_by(&:first)

          issues.each do |issue|
            issue_changes = changes_by_issue[issue.id]
            if issue_changes.nil? || issue_changes.empty?
              # 変更なし: 現在の担当者のみ
              issue.reply_items = [current_assignee_item(issue)]
            else
              # 初期担当者（最初の変更の old_value）→ 変更ごとの新担当者
              items = [to_reply_item(issue_changes.first[1], user_names)]
              issue_changes.each do |_, _, new_value|
                items << to_reply_item(new_value, user_names)
              end
              issue.reply_items = items
            end
          end
        end

        # reply_items からツールチップ文字列を構築する。
        # 名前が引けない要素（担当者なし・無効ユーザー）はラベルに置き換える。
        def build_reply_tooltip(items)
          no_assignee = I18n.t(:label_reply_count_no_assignee)
          names = items.map { |item| item[:name].presence || no_assignee }
          ([names.first] + names.drop(1).map { |n| " - #{n}" }).join("\n")
        end

        # user id (文字列) を reply_items の 1 要素に変換する。
        def to_reply_item(value, user_names)
          return { id: 0, name: '' } if value.blank?

          { id: value.to_i, name: user_names[value.to_i] || '' }
        end

        # 現在の担当者を reply_items の 1 要素に変換する。
        def current_assignee_item(issue)
          issue.assigned_to ? { id: issue.assigned_to.id, name: issue.assigned_to.name } : { id: 0, name: '' }
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

      # 単一チケット用: 担当者変更履歴から reply_items を構築する。
      def load_own_reply_items
        changes = JournalDetail
          .joins(:journal)
          .where(journals: { journalized_type: 'Issue', journalized_id: id })
          .where(property: 'attr', prop_key: 'assigned_to_id')
          .order('journals.id')
          .pluck(:old_value, :value)

        return [self.class.current_assignee_item(self)] if changes.empty?

        user_ids = changes.flatten.compact.reject(&:empty?).map(&:to_i).uniq
        user_names = User.where(id: user_ids).map { |u| [u.id, u.name] }.to_h

        # 初期担当者（最初の変更の old_value）→ 変更ごとの新担当者
        items = [self.class.to_reply_item(changes.first[0], user_names)]
        changes.each do |_, new_value|
          items << self.class.to_reply_item(new_value, user_names)
        end
        items
      end
    end
  end
end
