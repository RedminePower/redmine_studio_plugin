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

          journals = Journal.joins(issue: :project)
            .where(journalized_type: 'Issue', journalized_id: issue_ids)
            .where.not(notes: '')
            .where.not(notes: nil)
            .where(Journal.visible_notes_condition(user, skip_pre_condition: true))
            .preload(:user)
            .order(:id)
            .to_a

          journals_by_issue = journals.group_by(&:journalized_id)

          # 各チケットのジャーナル内でのノート番号を計算するため、
          # 全ジャーナル（コメントなし含む）の通し番号を取得
          all_journal_ids = Journal
            .where(journalized_type: 'Issue', journalized_id: issue_ids)
            .order(:id)
            .pluck(:journalized_id, :id)

          # issue_id => { journal_id => note_number } のマッピングを構築
          note_numbers = {}
          all_journal_ids.each do |issue_id, journal_id|
            note_numbers[issue_id] ||= {}
            note_numbers[issue_id][journal_id] = note_numbers[issue_id].size + 1
          end

          issues.each do |issue|
            issue_journals = journals_by_issue[issue.id] || []
            # 各ジャーナルにノート番号を設定
            issue_journals.each do |journal|
              journal.instance_variable_set(:@note_number, note_numbers.dig(issue.id, journal.id))
            end
            issue.visible_journals_with_notes = issue_journals
          end
        end
      end

      private

      def load_visible_journals_with_notes
        journals = self.journals.visible
          .where.not(notes: '')
          .where.not(notes: nil)
          .preload(:user)
          .order(:id)
          .to_a

        # ノート番号を計算
        all_journals = self.journals.order(:id).pluck(:id)
        journals.each do |journal|
          note_number = all_journals.index(journal.id)
          journal.instance_variable_set(:@note_number, note_number ? note_number + 1 : nil)
        end

        journals
      end
    end
  end
end
