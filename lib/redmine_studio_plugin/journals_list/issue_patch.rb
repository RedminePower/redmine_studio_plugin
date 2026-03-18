# frozen_string_literal: true

module RedmineStudioPlugin
  module JournalsList
    module IssuePatch
      extend ActiveSupport::Concern

      included do
        # プリロードされたジャーナル一覧を保持するインスタンス変数
        attr_writer :visible_journals_with_notes
      end

      # プリロード済みのジャーナル一覧を返す。
      # プリロードされていない場合は個別にクエリを実行する。
      def visible_journals_with_notes
        @visible_journals_with_notes || load_visible_journals_with_notes
      end

      class_methods do
        # チケット一覧に対して、コメント付きジャーナルを一括プリロードする。
        # IssueQuery#issues から呼び出される。
        def load_visible_journals_list(issues, user = User.current)
          return unless issues.any?

          issue_ids = issues.map(&:id)

          # コメント付きジャーナル（表示対象）を取得
          journals = Journal.joins(issue: :project)
            .where(journalized_type: 'Issue', journalized_id: issue_ids)
            .where.not(notes: '')
            .where.not(notes: nil)
            .where(Journal.visible_notes_condition(user, skip_pre_condition: true))
            .preload(:user)
            .order(:id)
            .to_a

          journals_by_issue = journals.group_by(&:journalized_id)

          # 全ジャーナル（コメントなし含む）の通し番号と属性変更を取得
          all_journal_data = Journal
            .where(journalized_type: 'Issue', journalized_id: issue_ids)
            .order(:id)
            .pluck(:journalized_id, :id)

          # ノート番号のマッピング
          note_numbers = {}
          all_journal_data.each do |issue_id, journal_id|
            note_numbers[issue_id] ||= {}
            note_numbers[issue_id][journal_id] = note_numbers[issue_id].size + 1
          end

          # 全ジャーナルの属性変更（status_id, assigned_to_id）を取得
          all_journal_ids = all_journal_data.map(&:last)
          attr_changes = JournalDetail
            .where(journal_id: all_journal_ids, property: 'attr', prop_key: %w[status_id assigned_to_id])
            .pluck(:journal_id, :prop_key, :old_value, :value)

          # journal_id => { prop_key => { old: old_value, new: value } }
          changes_by_journal = {}
          attr_changes.each do |journal_id, prop_key, old_value, value|
            changes_by_journal[journal_id] ||= {}
            changes_by_journal[journal_id][prop_key] = { old: old_value, new: value }
          end

          # ステータスとユーザーの名前を一括取得
          status_ids = attr_changes.flat_map { |_, pk, ov, v| pk == 'status_id' ? [ov, v] : [] }.compact.uniq
          user_ids = attr_changes.flat_map { |_, pk, ov, v| pk == 'assigned_to_id' ? [ov, v] : [] }.compact.uniq
          status_names = IssueStatus.where(id: status_ids).pluck(:id, :name).to_h
          user_names = User.where(id: user_ids).map { |u| [u.id, u.name] }.to_h

          issues.each do |issue|
            issue_journals = journals_by_issue[issue.id] || []
            issue_journal_ids = (note_numbers[issue.id] || {}).sort_by { |_, num| num }.map(&:first)

            # 初期値を逆算: 最初の変更の old_value、または現在の値
            current_status_id = issue.status_id
            current_assigned_to_id = issue.assigned_to_id
            running_status_id = current_status_id
            running_assigned_to_id = current_assigned_to_id

            # 全ジャーナルを逆順に走査して初期値を求める
            issue_journal_ids.reverse_each do |jid|
              changes = changes_by_journal[jid]
              next unless changes

              if changes['status_id']
                running_status_id = changes['status_id'][:old]&.to_i
              end
              if changes['assigned_to_id']
                old_val = changes['assigned_to_id'][:old]
                running_assigned_to_id = old_val.present? ? old_val.to_i : nil
              end
            end

            # 初期値から順に走査して累積値を計算
            comment_journal_ids = issue_journals.map(&:id).to_set
            issue_journal_ids.each do |jid|
              changes = changes_by_journal[jid]
              if changes
                if changes['status_id']
                  new_val = changes['status_id'][:new]
                  running_status_id = new_val&.to_i
                end
                if changes['assigned_to_id']
                  new_val = changes['assigned_to_id'][:new]
                  running_assigned_to_id = new_val.present? ? new_val.to_i : nil
                end
              end

              # コメント付きジャーナルの場合、累積値を設定
              if comment_journal_ids.include?(jid)
                journal = issue_journals.find { |j| j.id == jid }
                journal.instance_variable_set(:@note_number, note_numbers.dig(issue.id, jid))
                journal.instance_variable_set(:@cumulative_status_name,
                  status_names[running_status_id] || IssueStatus.find_by(id: running_status_id)&.name || '')
                journal.instance_variable_set(:@cumulative_assigned_to_id, running_assigned_to_id)
                journal.instance_variable_set(:@cumulative_assigned_to_name,
                  running_assigned_to_id ? (user_names[running_assigned_to_id] || User.find_by(id: running_assigned_to_id)&.name || '') : '')
              end
            end

            issue.visible_journals_with_notes = issue_journals
          end
        end
      end

      private

      def load_visible_journals_with_notes
        # コメント付きジャーナルを取得
        journals = self.journals.visible
          .where.not(notes: '')
          .where.not(notes: nil)
          .preload(:user)
          .order(:id)
          .to_a

        # 全ジャーナルのIDを取得（ノート番号と累積値の計算用）
        all_journal_ids = self.journals.order(:id).pluck(:id)

        # 属性変更を取得
        attr_changes = JournalDetail
          .where(journal_id: all_journal_ids, property: 'attr', prop_key: %w[status_id assigned_to_id])
          .pluck(:journal_id, :prop_key, :old_value, :value)

        changes_by_journal = {}
        attr_changes.each do |journal_id, prop_key, old_value, value|
          changes_by_journal[journal_id] ||= {}
          changes_by_journal[journal_id][prop_key] = { old: old_value, new: value }
        end

        # 初期値を逆算
        running_status_id = self.status_id
        running_assigned_to_id = self.assigned_to_id
        all_journal_ids.reverse_each do |jid|
          changes = changes_by_journal[jid]
          next unless changes

          if changes['status_id']
            running_status_id = changes['status_id'][:old]&.to_i
          end
          if changes['assigned_to_id']
            old_val = changes['assigned_to_id'][:old]
            running_assigned_to_id = old_val.present? ? old_val.to_i : nil
          end
        end

        # 累積値を計算
        comment_journal_ids = journals.map(&:id).to_set
        all_journal_ids.each_with_index do |jid, idx|
          changes = changes_by_journal[jid]
          if changes
            if changes['status_id']
              running_status_id = changes['status_id'][:new]&.to_i
            end
            if changes['assigned_to_id']
              new_val = changes['assigned_to_id'][:new]
              running_assigned_to_id = new_val.present? ? new_val.to_i : nil
            end
          end

          if comment_journal_ids.include?(jid)
            journal = journals.find { |j| j.id == jid }
            journal.instance_variable_set(:@note_number, idx + 1)
            journal.instance_variable_set(:@cumulative_status_name,
              IssueStatus.find_by(id: running_status_id)&.name || '')
            journal.instance_variable_set(:@cumulative_assigned_to_name,
              running_assigned_to_id ? (User.find_by(id: running_assigned_to_id)&.name || '') : '')
          end
        end

        journals
      end
    end
  end
end
