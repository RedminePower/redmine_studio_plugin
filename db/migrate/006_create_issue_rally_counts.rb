# frozen_string_literal: true

class CreateIssueRallyCounts < ActiveRecord::Migration[5.2]
  def up
    unless table_exists?(:issue_rally_counts)
      create_table :issue_rally_counts do |t|
        t.bigint :issue_id, null: false
        t.integer :count, null: false, default: 0
      end
      add_index :issue_rally_counts, :issue_id, unique: true
    end

    # 既存チケットのラリー回数を一括計算
    execute <<-SQL
      INSERT INTO issue_rally_counts (issue_id, count)
      SELECT j.journalized_id, COUNT(*)
      FROM journals j
      INNER JOIN journal_details jd ON jd.journal_id = j.id
      WHERE j.journalized_type = 'Issue'
      AND jd.property = 'attr' AND jd.prop_key = 'assigned_to_id'
      GROUP BY j.journalized_id
    SQL
  end

  def down
    drop_table :issue_rally_counts if table_exists?(:issue_rally_counts)
  end
end
