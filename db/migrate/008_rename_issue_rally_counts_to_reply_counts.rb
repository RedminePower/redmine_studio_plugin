# frozen_string_literal: true

# 命名を全面的に reply_count に統一するための rename マイグレーション。
# 変更内容:
#   1. issue_rally_counts テーブルを issue_reply_counts にリネーム
#   2. queries.column_names に含まれる :rally_count シンボルを :reply_count に置換
#   3. queries.sort_criteria に含まれる 'rally_count' 文字列を 'reply_count' に置換
# 既存の migration 006 で作成済みの環境向け。冪等 (テーブル/カラムの存在チェック済)。
class RenameIssueRallyCountsToReplyCounts < ActiveRecord::Migration[6.1]
  def up
    if table_exists?(:issue_rally_counts) && !table_exists?(:issue_reply_counts)
      rename_table :issue_rally_counts, :issue_reply_counts
    end

    migrate_queries(from_col: :rally_count, to_col: :reply_count,
                    from_sort: 'rally_count', to_sort: 'reply_count')
  end

  def down
    if table_exists?(:issue_reply_counts) && !table_exists?(:issue_rally_counts)
      rename_table :issue_reply_counts, :issue_rally_counts
    end

    migrate_queries(from_col: :reply_count, to_col: :rally_count,
                    from_sort: 'reply_count', to_sort: 'rally_count')
  end

  private

  # queries.column_names (Symbol の配列) と queries.sort_criteria ([[String, String]] の配列) を
  # AR モデル経由で読み書きすることで、YAML シリアライズを Rails 側に任せる。
  def migrate_queries(from_col:, to_col:, from_sort:, to_sort:)
    like = "%#{from_col}%"
    Query.where('column_names LIKE ? OR sort_criteria LIKE ?', like, like).find_each do |q|
      changed = false

      cols = q.column_names
      if cols.is_a?(Array) && cols.include?(from_col)
        q.column_names = cols.map { |c| c == from_col ? to_col : c }
        changed = true
      end

      crits = q.sort_criteria
      if crits.is_a?(Array) && crits.any? { |c| c.is_a?(Array) && c[0] == from_sort }
        q.sort_criteria = crits.map { |c| (c.is_a?(Array) && c[0] == from_sort) ? [to_sort, c[1]] : c }
        changed = true
      end

      q.save(validate: false) if changed
    end
  end
end
