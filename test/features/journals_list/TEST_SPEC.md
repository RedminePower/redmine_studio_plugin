# Journals List（コメント履歴）テスト仕様書

## 概要

チケット一覧に「コメント履歴」ブロックカラムを追加する機能のテスト仕様。チケットのコメント一覧を折りたたみ/展開可能なテーブル形式で表示する。各コメント時点のステータスと担当者を累積値で表示する。展開時のコンテンツは AJAX で遅延ロードする。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| カラム名 | `:journals_list` |
| カラムクラス | `RedmineStudioPlugin::JournalsList::QueryColumn` |
| Issue パッチ | `RedmineStudioPlugin::JournalsList::IssuePatch` |
| IssueQuery パッチ | `RedmineStudioPlugin::JournalsList::IssueQueryPatch` |
| QueriesHelper パッチ | `RedmineStudioPlugin::JournalsList::QueriesHelperPatch` |
| コントローラー | `JournalsListController` |
| ロケールファイル | `config/locales/journals_list_ja.yml`, `config/locales/journals_list_en.yml` |

### AJAX エンドポイント

| エンドポイント | メソッド | 用途 |
|---------------|---------|------|
| `/journals_list/:id` | GET | 単一ジャーナルの Wiki レンダリング結果を返す |
| `/journals_list/show_all?ids[]=...` | GET | 複数ジャーナルの Wiki レンダリング結果を JSON で一括返す |

**認証:** ログイン必須（本体の `login_required` 設定に関わらず一律）。`before_action :require_login` を付与。ブラウザ UI 補助の AJAX エンドポイントのため、認証はセッション（ログイン中ユーザ）で行う。未認証（匿名）はログイン画面へリダイレクト（302）され、ジャーナル本文は取得できない。各ジャーナルの可視性は従来どおり `journalized.visible? && journal.visible?` で個別に判定する。

---

## 1. Runner テスト

チケットなどが要る試験は、試験の中でプロジェクト・チケット・ユーザーを作り、終わったら消す。

### [1-1] カラムクラス定義確認

**確認方法:**
```ruby
puts defined?(RedmineStudioPlugin::JournalsList::QueryColumn)
```

**期待結果:** `constant` が出力される

### [1-2] Issue パッチ適用確認

**確認方法:**
```ruby
puts Issue.included_modules.map(&:name).include?('RedmineStudioPlugin::JournalsList::IssuePatch')
```

**期待結果:** `true` が出力される

### [1-3] IssueQuery パッチ適用確認

**確認方法:**
```ruby
puts IssueQuery.ancestors.map(&:name).include?('RedmineStudioPlugin::JournalsList::IssueQueryPatch')
```

**期待結果:** `true` が出力される

### [1-4] QueriesHelper パッチ適用確認

**確認方法:**
```ruby
puts QueriesHelper.instance_methods.include?(:column_content_with_journals_list)
```

**期待結果:** `true` が出力される

### [1-5] カラム登録確認

**確認方法:**
```ruby
col = IssueQuery.available_columns.find { |c| c.name == :journals_list }
puts "found: #{col ? true : false}"
puts "inline: #{col ? col.inline? : 'N/A'}"
```

**期待結果:**
- `found: true`
- `inline: false`

### [1-6] カラムがブロックカラムとして動作する

**確認方法:**
```ruby
q = IssueQuery.new(name: 'test', filters: {})
q.column_names = [:id, :subject, :journals_list]
puts "inline: #{q.inline_columns.map { |c| c.name.to_s }.join(', ')}"
puts "block: #{q.block_columns.map { |c| c.name.to_s }.join(', ')}"
```

**期待結果:**
- `inline: id, subject`
- `block: journals_list`

### [1-7] ロケールファイル存在確認

**確認方法:**
```ruby
files = [
  'config/locales/journals_list_ja.yml',
  'config/locales/journals_list_en.yml'
]
files.each do |f|
  path = Rails.root.join('plugins', 'redmine_studio_plugin', f)
  puts "#{f}: #{File.exist?(path)}"
end
```

**期待結果:** すべて `true`

### [1-8] ロケールキー確認

**確認方法:**
```ruby
I18n.locale = :ja
puts "field_journals_list: #{I18n.t(:field_journals_list)}"
puts "label_journals_list_author: #{I18n.t(:label_journals_list_author)}"
puts "label_journals_list_date: #{I18n.t(:label_journals_list_date)}"
puts "label_journals_list_notes: #{I18n.t(:label_journals_list_notes)}"
puts "label_journals_list_show_detail: #{I18n.t(:label_journals_list_show_detail)}"
puts "label_journals_list_hide_detail: #{I18n.t(:label_journals_list_hide_detail)}"
puts "label_journals_list_show_all: #{I18n.t(:label_journals_list_show_all)}"
puts "label_journals_list_hide_all: #{I18n.t(:label_journals_list_hide_all)}"
```

**期待結果:**
- `field_journals_list: コメント履歴`
- `label_journals_list_author: 更新者`
- `label_journals_list_date: 更新日`
- `label_journals_list_notes: コメント`
- `label_journals_list_show_detail: 詳細を表示`
- `label_journals_list_hide_detail: 詳細を隠す`
- `label_journals_list_show_all: すべての詳細を表示`
- `label_journals_list_hide_all: すべての詳細を隠す`

### [1-9] Issue#visible_journals_with_notes の動作確認

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = Project.new(name: "JL_#{sfx}", identifier: "jl-#{sfx}")
project.enabled_module_names = %w[issue_tracking]
project.trackers = [Tracker.first]
project.save!
begin
  issue = Issue.create!(project: project, tracker: project.trackers.first, subject: 'JL_1-9_Test', author: admin)
  Journal.create!(journalized: issue, user: admin, notes: 'Test comment 1')
  Journal.create!(journalized: issue, user: admin, notes: 'Test comment 2')
  Journal.create(journalized: issue, user: admin, notes: '')

  journals = Issue.find(issue.id).visible_journals_with_notes
  puts "count: #{journals.size}"
  puts "all_have_notes: #{journals.all? { |j| j.notes.present? }}"
  puts "note_numbers_set: #{journals.all? { |j| j.instance_variable_get(:@note_number).is_a?(Integer) }}"
ensure
  User.current = admin
  project.destroy
end
```

**期待結果:**
- `count: 2`（ノートありのみ）
- `all_have_notes: true`
- `note_numbers_set: true`

### [1-10] プライベートコメントのフィルタリング確認

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = Project.new(name: "JL_#{sfx}", identifier: "jl-#{sfx}")
project.enabled_module_names = %w[issue_tracking]
project.trackers = [Tracker.first]
project.save!
role = user = nil
mk_user = ->(name) {
  u = User.new(login: "jl_#{name}_#{sfx}", firstname: 'JL', lastname: name, mail: "jl_#{name}_#{sfx}@example.com", status: 1)
  u.password = u.password_confirmation = 'password123'
  u.save!
  u
}
begin
  issue = Issue.create!(project: project, tracker: project.trackers.first, subject: 'JL_1-10_PrivateTest', author: admin)
  Journal.create!(journalized: issue, user: admin, notes: 'Public comment')
  Journal.create!(journalized: issue, user: admin, notes: 'Private comment', private_notes: true)

  admin_journals = Issue.find(issue.id).visible_journals_with_notes
  puts "admin_count: #{admin_journals.size}"

  # プライベートコメントを見る権限（:view_private_notes）の無いロールのメンバー
  role = Role.create!(name: "JL_#{sfx}", permissions: [:view_issues])
  user = mk_user.call('member')
  Member.create!(principal: user, project: project, roles: [role])
  User.current = user
  user_journals = Issue.find(issue.id).visible_journals_with_notes
  puts "user_count: #{user_journals.size}"
ensure
  User.current = admin
  project.destroy
  user&.destroy
  role&.destroy
end
```

**期待結果:**
- `admin_count: 2`（パブリック + プライベート）
- `user_count: 1`（`:view_private_notes` の無いユーザーにはパブリックだけ）

### [1-11] 一括プリロード（N+1 対策）確認

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = Project.new(name: "JL_#{sfx}", identifier: "jl-#{sfx}")
project.enabled_module_names = %w[issue_tracking]
project.trackers = [Tracker.first]
project.save!
begin
  2.times do |n|
    i = Issue.create!(project: project, tracker: project.trackers.first, subject: "JL_1-11_#{n}", author: admin)
    Journal.create!(journalized: i, user: admin, notes: "Comment #{n}")
  end
  q = IssueQuery.new(name: 'test', filters: {}, project: project)
  q.column_names = [:id, :subject, :journals_list]
  issues = q.issues(limit: 5)
  preloaded = issues.select { |i| i.instance_variable_defined?(:@visible_journals_with_notes) }
  puts "preloaded_count: #{preloaded.size}"
  puts "total_issues: #{issues.size}"
ensure
  User.current = admin
  project.destroy
end
```

**期待結果:**
- `preloaded_count: 2`・`total_issues: 2`（作った 2 件がすべてプリロードされる）

### [1-12] ルーティング確認

**確認方法:**
```ruby
show_all_route = Rails.application.routes.recognize_path('/journals_list/show_all')
puts "show_all_action: #{show_all_route[:action]}"

show_route = Rails.application.routes.recognize_path('/journals_list/123')
puts "show_action: #{show_route[:action]}"
puts "show_id: #{show_route[:id]}"
```

**期待結果:**
- `show_all_action: show_all`
- `show_action: show`
- `show_id: 123`

### [1-13] 累積ステータスの計算確認（次のコメント直前の値）

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = Project.new(name: "JL_#{sfx}", identifier: "jl-#{sfx}")
project.enabled_module_names = %w[issue_tracking]
project.trackers = [Tracker.first]
project.save!
begin
  conn = ActiveRecord::Base.connection
  status_1 = IssueStatus.first
  status_2 = IssueStatus.second

  issue = Issue.create!(project: project, tracker: project.trackers.first, subject: 'JL_1-13_Status', author: admin, status: status_1)
  issue.update_columns(status_id: status_1.id)

  # コメント1
  j1 = Journal.create!(journalized: issue, user: admin, notes: 'Comment 1')

  # コメントなしでステータス変更
  j2_id = conn.insert("INSERT INTO journals (journalized_id, journalized_type, user_id, notes, created_on) VALUES (#{issue.id}, 'Issue', 1, '', '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}')")
  conn.execute("INSERT INTO journal_details (journal_id, property, prop_key, old_value, value) VALUES (#{j2_id}, 'attr', 'status_id', '#{status_1.id}', '#{status_2.id}')")

  # コメント2
  j3 = Journal.create!(journalized: issue, user: admin, notes: 'Comment 2')

  issue.update_columns(status_id: status_2.id)
  journals = Issue.find(issue.id).visible_journals_with_notes
  puts "j1_status: #{journals[0].instance_variable_get(:@cumulative_status_name)}"
  puts "j2_status: #{journals[1].instance_variable_get(:@cumulative_status_name)}"
  puts "expected: #{status_2.name}"
ensure
  User.current = admin
  project.destroy
end
```

**期待結果:**
- `j1_status`: ステータス2の名前（`expected` と一致。次のコメント直前にステータス変更が反映される）
- `j2_status`: ステータス2の名前（`expected` と一致。最後のコメントなので現在値）

### [1-14] 累積担当者の計算確認（次のコメント直前の値）

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = Project.new(name: "JL_#{sfx}", identifier: "jl-#{sfx}")
project.enabled_module_names = %w[issue_tracking]
project.trackers = [Tracker.first]
project.save!
user_b = nil
mk_user = ->(name) {
  u = User.new(login: "jl_#{name}_#{sfx}", firstname: 'JL', lastname: name, mail: "jl_#{name}_#{sfx}@example.com", status: 1)
  u.password = u.password_confirmation = 'password123'
  u.save!
  u
}
begin
  conn = ActiveRecord::Base.connection
  user_a = admin
  user_b = mk_user.call('assignee')

  issue = Issue.create!(project: project, tracker: project.trackers.first, subject: 'JL_1-14_Assign', author: user_a)
  issue.update_columns(assigned_to_id: nil)

  # コメント1
  j1 = Journal.create!(journalized: issue, user: user_a, notes: 'Comment 1')

  # コメントなしで担当者変更
  j2_id = conn.insert("INSERT INTO journals (journalized_id, journalized_type, user_id, notes, created_on) VALUES (#{issue.id}, 'Issue', #{user_a.id}, '', '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}')")
  conn.execute("INSERT INTO journal_details (journal_id, property, prop_key, old_value, value) VALUES (#{j2_id}, 'attr', 'assigned_to_id', '', '#{user_b.id}')")

  # コメント2
  j3 = Journal.create!(journalized: issue, user: user_a, notes: 'Comment 2')

  issue.update_columns(assigned_to_id: user_b.id)
  journals = Issue.find(issue.id).visible_journals_with_notes
  puts "j1_assigned: #{journals[0].instance_variable_get(:@cumulative_assigned_to_name)}"
  puts "j1_expected: #{user_b.name}"
  puts "j2_assigned: #{journals[1].instance_variable_get(:@cumulative_assigned_to_name)}"
  puts "j2_expected: #{user_b.name}"
ensure
  User.current = admin
  project.destroy
  user_b&.destroy
end
```

**期待結果:**
- `j1_assigned` と `j1_expected` が一致（次のコメント直前に担当者変更が反映される）
- `j2_assigned` と `j2_expected` が一致（最後のコメントなので現在値）

### [1-15] コメントなしジャーナルの属性変更が次のコメント行に反映される確認

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = Project.new(name: "JL_#{sfx}", identifier: "jl-#{sfx}")
project.enabled_module_names = %w[issue_tracking]
project.trackers = [Tracker.first]
project.save!
begin
  conn = ActiveRecord::Base.connection
  status_1 = IssueStatus.first
  status_2 = IssueStatus.second

  issue = Issue.create!(project: project, tracker: project.trackers.first, subject: 'JL_1-15_NoNote', author: admin, status: status_1)
  issue.update_columns(status_id: status_1.id)

  # コメント1
  Journal.create!(journalized: issue, user: admin, notes: 'Comment 1')

  # 属性変更のみ（コメントなし）
  j_id = conn.insert("INSERT INTO journals (journalized_id, journalized_type, user_id, notes, created_on) VALUES (#{issue.id}, 'Issue', 1, '', '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}')")
  conn.execute("INSERT INTO journal_details (journal_id, property, prop_key, old_value, value) VALUES (#{j_id}, 'attr', 'status_id', '#{status_1.id}', '#{status_2.id}')")

  # コメント2
  Journal.create!(journalized: issue, user: admin, notes: 'Comment 2')

  issue.update_columns(status_id: status_2.id)
  journals = Issue.find(issue.id).visible_journals_with_notes
  puts "count: #{journals.size}"
  puts "j1_status: #{journals[0].instance_variable_get(:@cumulative_status_name)}"
  puts "j2_status: #{journals[1].instance_variable_get(:@cumulative_status_name)}"
  puts "j1_expected: #{status_2.name}"
  puts "j2_expected: #{status_2.name}"
ensure
  User.current = admin
  project.destroy
end
```

**期待結果:**
- `count: 2`（コメント付きのみ）
- `j1_status` と `j1_expected` が一致（コメントなしジャーナルの変更が次のコメント直前の値として反映）
- `j2_status` と `j2_expected` が一致（最後のコメントなので現在値）

### [1-16] 担当者がグループ・削除したグループのときの累積担当者

担当が「なし →（コメント1）→ グループ（後で削除） →（コメント2）→ グループ →（コメント3）」と移り、今の担当がグループのチケットで、1 件ずつ引く場合と一括で引く場合の両方を確かめる。
グループへの割り当ての設定に左右されないよう、履歴は直接書く。
担当者の列のリンクは本体の `link_to_principal` で作るので、担当者そのもの（`@cumulative_assigned_to`）も確かめる。

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = Project.new(name: "JL_#{sfx}", identifier: "jl-#{sfx}")
project.enabled_module_names = %w[issue_tracking]
project.trackers = [Tracker.first]
project.save!
suffix = sfx
group = Group.create!(lastname: "JL_Group_#{suffix}")
gone = Group.create!(lastname: "JL_Gone_#{suffix}")
issue = Issue.create!(project: project, tracker: project.trackers.first, subject: 'JL_1-16_Principals', author: admin)
add_change = ->(ov, v) {
  j = Journal.create!(journalized: issue, user: admin, notes: '')
  JournalDetail.create!(journal: j, property: 'attr', prop_key: 'assigned_to_id', old_value: ov.to_s, value: v.to_s)
}
begin
  Journal.create!(journalized: issue, user: admin, notes: 'Comment 1')
  add_change.call('', gone.id)
  Journal.create!(journalized: issue, user: admin, notes: 'Comment 2')
  add_change.call(gone.id, group.id)
  Journal.create!(journalized: issue, user: admin, notes: 'Comment 3')
  issue.update_columns(assigned_to_id: group.id)
  gone.destroy

  describe = ->(journals) {
    journals.map { |j| [j.instance_variable_get(:@cumulative_assigned_to_name), j.instance_variable_get(:@cumulative_assigned_to)&.class&.name] }
  }
  expected = [['', nil], [group.name, 'Group'], [group.name, 'Group']]
  puts "single: #{describe.call(Issue.find(issue.id).visible_journals_with_notes) == expected}"
  batch_issue = Issue.find(issue.id)
  Issue.load_visible_journals_list([batch_issue], admin)
  puts "batch: #{describe.call(batch_issue.visible_journals_with_notes) == expected}"
ensure
  User.current = admin
  project.destroy
  group.destroy
  gone.destroy if Group.exists?(gone.id)
end
```

**期待結果:**
- `single: true`・`batch: true`（コメント1 は削除したグループなので空、コメント2・3 はグループの名前とグループそのもの）

---

### [1-17] 担当者・書いた人のリンク（グループ・ロック中のユーザー）

担当がグループで、コメントを書いた人がロック中のユーザーのチケットで、一覧の表を描いて確かめる。
本体と同じく、グループはグループのページへのリンクになる。ロック中のユーザーは、管理者以外にはリンクなし（名前だけ）、管理者にはリンクになる。

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = Project.new(name: "JL_#{sfx}", identifier: "jl-#{sfx}")
project.enabled_module_names = %w[issue_tracking]
project.trackers = [Tracker.first]
project.save!
suffix = sfx
group = Group.create!(lastname: "JL_Group_#{suffix}")
locked = User.new(login: "jl_lock_#{suffix}", firstname: 'Locked', lastname: 'User', mail: "jl_lock_#{suffix}@example.com", status: 1)
locked.password = locked.password_confirmation = 'password123'
locked.save!
issue = Issue.create!(project: project, tracker: project.trackers.first, subject: 'JL_1-17_Links', author: admin)
begin
  j = Journal.create!(journalized: issue, user: locked, notes: 'Comment 1')
  JournalDetail.create!(journal: j, property: 'attr', prop_key: 'assigned_to_id', old_value: '', value: group.id.to_s)
  issue.update_columns(assigned_to_id: group.id)
  locked.update_columns(status: User::STATUS_LOCKED)

  column = IssueQuery.new(name: '_').available_columns.find { |c| c.name == :journals_list }
  target = Issue.find(issue.id)
  Issue.load_visible_journals_list([target], admin)
  # ロック中の人へのリンクは見る人（User.current）で変わるので、管理者以外（匿名）と管理者の両方で描く
  draw = ->(viewer) {
    User.current = viewer
    IssuesController.renderer.render(inline: '<%= column_content(column, target) %>', locals: { column: column, target: target })
  }
  html = draw.call(User.anonymous)
  admin_html = draw.call(admin)
  assignee_cell = html[/<td class="jl-assigned-to">.*?<\/td>/m].to_s
  author_cell = html[/<td class="jl-author">.*?<\/td>/m].to_s
  admin_author_cell = admin_html[/<td class="jl-author">.*?<\/td>/m].to_s
  puts "group_link: #{assignee_cell.include?("/groups/#{group.id}\"") && assignee_cell.include?(group.name)}"
  puts "locked_no_link: #{!author_cell.include?('<a') && author_cell.include?(locked.name)}"
  puts "locked_admin_link: #{admin_author_cell.include?("/users/#{locked.id}\"")}"
ensure
  User.current = admin
  project.destroy
  locked.destroy
  group.destroy
end
```

**期待結果:**
- `group_link: true`（担当者の列はグループのページ `/groups/<id>` へのリンク）
- `locked_no_link: true`（管理者以外には、書いた人の列はロック中のユーザーの名前だけで、リンクなし）
- `locked_admin_link: true`（管理者には、ロック中のユーザーもユーザーのページへのリンク）

---

## 2. HTTP テスト

**実行方法:** 各ブロックを PowerShell で流す。`{Username}` / `{Password}` は管理者。

**用意（HTTP テストの前に 1 回）:**
コメントのあるチケットと、コメントのないチケットを Runner で作る（前回の残りがあれば先に消す）。
コメントのあるチケットは、管理者がコメントを 2 つ書き（1 つ目は Wiki 記法の太字を含む）、担当者は管理者。
最後の行の `IssueId`・`NoCommentId`・`JournalId`・`JournalId2`・`MissingJournalId`（存在しないジャーナル ID）を、各試験の `{IssueId}` などに入れる。

```ruby
admin = User.find(1)
User.current = admin
# 前回の残りを消す
Project.where('identifier LIKE ?', 'jl-http-%').each(&:destroy)
sfx = SecureRandom.hex(3)
pr = Project.new(name: "JL_HTTP_#{sfx}", identifier: "jl-http-#{sfx}")
pr.enabled_module_names = %w[issue_tracking]
pr.trackers = [Tracker.first]
pr.save!
issue = Issue.create!(project: pr, tracker: pr.trackers.first, subject: "JL_HTTP_comment_#{sfx}", author: admin)
j1 = Journal.create!(journalized: issue, user: admin, notes: 'JL **bold** comment 1')
j2 = Journal.create!(journalized: issue, user: admin, notes: 'JL comment 2')
issue.update_columns(assigned_to_id: admin.id)
none = Issue.create!(project: pr, tracker: pr.trackers.first, subject: "JL_HTTP_none_#{sfx}", author: admin)
puts({ IssueId: issue.id, NoCommentId: none.id, JournalId: j1.id, JournalId2: j2.id, MissingJournalId: Journal.maximum(:id) + 100000 }.to_json)
```

**後片付け（HTTP テストのあとに 1 回）:**

```ruby
User.current = User.find(1)
Project.where('identifier LIKE ?', 'jl-http-%').each(&:destroy)
puts Project.where('identifier LIKE ?', 'jl-http-%').count
```

**期待結果（後片付け）:** `0`

### チケット一覧の HTML 出力

### [2-1] チケット一覧で journals_list カラムを指定して表示できる

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
```

**期待結果:** `200`

### [2-2] コメント付きチケットで journals-list テーブルが出力される

用意で作ったコメントのあるチケット（`{IssueId}`）を表示する。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list&f[]=issue_id&op[issue_id]==&v[issue_id][]={IssueId}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'journals-list'
```

**期待結果:** `True`

### [2-3] テーブルのセル構造が正しい

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list&f[]=issue_id&op[issue_id]==&v[issue_id][]={IssueId}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'class="jl-note"'
$response.Content -match 'class="jl-author"'
$response.Content -match 'class="jl-date"'
$response.Content -match 'class="jl-status"'
$response.Content -match 'class="jl-assigned-to"'
$response.Content -match 'class="jl-preview"'
$response.Content -match 'class="jl-toggle"'
```

**期待結果:** すべて `True`

### [2-4] コメントなしチケットでは journals-list が出力されない

用意で作ったコメントのないチケット（`{NoCommentId}`）を表示する。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list&f[]=issue_id&op[issue_id]==&v[issue_id][]={NoCommentId}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'journals-list'
```

**期待結果:** `False`

### [2-5] ブロックカラムとして block_column クラスが付与される

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list&f[]=issue_id&op[issue_id]==&v[issue_id][]={IssueId}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'journals_list block_column'
```

**期待結果:** `True`

### [2-6] チケット一覧カラムオプションに journals_list が表示される

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'journals_list'
```

**期待結果:** `True`

### [2-7] コメント番号のリンクが正しいアンカーを持つ

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list&f[]=issue_id&op[issue_id]==&v[issue_id][]={IssueId}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'href="[^"]*/issues/{IssueId}#note-'
```

**期待結果:** `True`

### [2-8] 投稿者名がユーザーページへのリンクになっている

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list&f[]=issue_id&op[issue_id]==&v[issue_id][]={IssueId}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'jl-author.*href="[^"]*/users/\d+"'
```

**期待結果:** `True`

### [2-9] 折りたたみ/展開ボタンと AJAX 用属性が出力される

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list&f[]=issue_id&op[issue_id]==&v[issue_id][]={IssueId}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'jl-expand-btn'
$response.Content -match 'jl-collapse-btn'
$response.Content -match 'data-journal-id'
```

**期待結果:** すべて `True`

### [2-10] ソート用の data 属性が出力される（6要素）

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list&f[]=issue_id&op[issue_id]==&v[issue_id][]={IssueId}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'data-sort-col'
$response.Content -match 'data-sort-keys'
```

**期待結果:** 両方 `True`

### [2-11] CSS と JavaScript が出力される

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list&f[]=issue_id&op[issue_id]==&v[issue_id][]={IssueId}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'table\.journals-list'
$response.Content -match 'jl-context-menu'
$response.Content -match 'expandJournal'
$response.Content -match 'dblclick'
```

**期待結果:** すべて `True`

### [2-12] ステータス列とソート属性が出力される

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list&f[]=issue_id&op[issue_id]==&v[issue_id][]={IssueId}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'th.*jl-status.*jl-sortable'
$response.Content -match 'td.*class="jl-status"'
```

**期待結果:** 両方 `True`

### [2-13] 担当者列がリンク付きで出力される

用意で作ったチケットは担当者が管理者なので、最後のコメントの担当者の列がユーザーのページへのリンクになる。

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list&f[]=issue_id&op[issue_id]==&v[issue_id][]={IssueId}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'th.*jl-assigned-to.*jl-sortable'
$response.Content -match 'jl-assigned-to.*href="[^"]*/users/\d+"'
```

**期待結果:** 両方 `True`

### AJAX エンドポイント

ブラウザ UI 補助のエンドポイントなので、Basic 認証は効かない。[2-14]〜[2-17] は、ログイン画面から管理者でログインしたセッション（`$session`）で送る。

### [2-14] JournalsListController#show - 単一ジャーナル取得

用意で作ったコメント（`{JournalId}`）を取得する。

**確認方法:**
```powershell
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable session -UseBasicParsing
$token = [Net.WebUtility]::HtmlDecode([regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value)
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -WebSession $session -UseBasicParsing `
  -Body @{ authenticity_token = $token; username = '{Username}'; password = '{Password}' } | Out-Null
$response = Invoke-WebRequest -Uri '{BaseUrl}/journals_list/{JournalId}' -WebSession $session -UseBasicParsing
$response.StatusCode
$response.Headers['Content-Type']
```

**期待結果:**
- ステータスコード: `200`
- Content-Type: `text/html` を含む

### [2-15] JournalsListController#show - Wiki レンダリング確認

用意で作ったコメント（`{JournalId}`）は Wiki 記法の太字を含む。

**確認方法:**
```powershell
# [2-14] と同じリクエスト
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable session -UseBasicParsing
$token = [Net.WebUtility]::HtmlDecode([regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value)
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -WebSession $session -UseBasicParsing `
  -Body @{ authenticity_token = $token; username = '{Username}'; password = '{Password}' } | Out-Null
$response = Invoke-WebRequest -Uri '{BaseUrl}/journals_list/{JournalId}' -WebSession $session -UseBasicParsing
$response.Content.Length -gt 0
$response.Content -match '<(strong|b)>bold</(strong|b)>'
```

**期待結果:** 両方 `True`（空でないレスポンスで、太字がレンダリングされている）

### [2-16] JournalsListController#show_all - 複数ジャーナル一括取得

用意で作った 2 つのコメント（`{JournalId}`・`{JournalId2}`）を一括で取得する。

**確認方法:**
```powershell
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable session -UseBasicParsing
$token = [Net.WebUtility]::HtmlDecode([regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value)
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -WebSession $session -UseBasicParsing `
  -Body @{ authenticity_token = $token; username = '{Username}'; password = '{Password}' } | Out-Null
$response = Invoke-WebRequest -Uri '{BaseUrl}/journals_list/show_all?ids[]={JournalId}&ids[]={JournalId2}' -WebSession $session -UseBasicParsing
$response.StatusCode
$response.Headers['Content-Type']
$json = $response.Content | ConvertFrom-Json
($json.PSObject.Properties.Name -contains '{JournalId}') -and ($json.PSObject.Properties.Name -contains '{JournalId2}')
```

**期待結果:**
- ステータスコード: `200`
- Content-Type: `application/json` を含む
- `True`（JSON のキーに `{JournalId}`, `{JournalId2}` が含まれる）

### [2-17] JournalsListController#show - 存在しない ID で 404 エラー

存在しない ID は、用意で今ある最大のジャーナル ID より大きい値（`{MissingJournalId}`）を選ぶ。

**確認方法:**
```powershell
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable session -UseBasicParsing
$token = [Net.WebUtility]::HtmlDecode([regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value)
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -WebSession $session -UseBasicParsing `
  -Body @{ authenticity_token = $token; username = '{Username}'; password = '{Password}' } | Out-Null
try {
  Invoke-WebRequest -Uri '{BaseUrl}/journals_list/{MissingJournalId}' -WebSession $session -UseBasicParsing
} catch {
  $_.Exception.Response.StatusCode.Value__
}
```

**期待結果:** `404`

### [2-18] 未認証（匿名）はログイン画面へリダイレクトされる（302・login_required 無効環境でも）

追加エンドポイントは本体の `login_required` 設定に関わらず一律ログイン必須（`before_action :require_login`）。認証情報（セッション Cookie）なしのアクセスは、本体 `login_required` が無効な環境でもログイン画面へリダイレクト（302）され、ジャーナル本文は取得できない。

**確認方法:**
```powershell
# 認証情報を付けずにアクセス（-MaximumRedirection 0 でリダイレクトを追わない）
try {
  Invoke-WebRequest -Uri '{BaseUrl}/journals_list/show_all?ids[]=1' -MaximumRedirection 0
} catch {
  $_.Exception.Response.StatusCode.Value__
}
```

**期待結果:** `302`（ログイン画面 `/login` へのリダイレクト。匿名では取得不可）

---

## 3. ブラウザテスト

### セットアップデータ

以下のデータが必要。テスト環境に存在しなければ作成する。

**チケット:**

| テストID | subject | 備考 |
|---------|---------|------|
| 用途 | JL_Browser_TestIssue | 複数ユーザーによるコメント、ステータス・担当者変更を含む |

**コメント（ステータス・担当者変更付き）:**

| # | 投稿者 | ステータス変更 | 担当者変更 | 内容 |
|---|--------|-------------|----------|------|
| 1 | admin | 新規→進行中 | →admin | 着手します |
| 2 | admin | - | admin→一般ユーザー | レビューお願いします |
| 3 | 一般ユーザー | - | 一般ユーザー→admin | 確認しました |

### [3-1] 折りたたみ/展開操作

**手順:**
1. admin でログイン
2. チケット一覧で `journals_list` カラムを有効にし、テストチケットを表示
3. コメント #1 の「表示」リンクをクリック

**確認1:** コメント #1 の詳細（Wiki レンダリングされた全文）が展開される

4. コメント #1 の「隠す」リンクをクリック

**確認2:** コメント #1 の詳細が折りたたまれる

5. 再度コメント #1 の「表示」をクリック

**確認3:** AJAX リクエストなしで即座に展開される（キャッシュ動作）

### [3-2] ダブルクリックで展開/折りたたみ

**手順:**
1. コメント #1 のヘッダー行をダブルクリック

**確認1:** 詳細が展開される。テキスト選択は残らない

2. 再度ヘッダー行をダブルクリック

**確認2:** 詳細が折りたたまれる

3. 展開された詳細部分をダブルクリック

**確認3:** テキストが選択される（詳細は折りたたまれない）

### [3-3] ソート操作

**手順:**
1. 「更新者」ヘッダーをクリック

**確認1:** コメントが更新者名の昇順でソートされる。ソートアイコンが表示される

2. 「ステータス」ヘッダーをクリック

**確認2:** コメントがステータスの昇順でソートされる。「更新者」のソートアイコンが消える

3. 「担当者」ヘッダーをクリック

**確認3:** コメントが担当者名でソートされる

### [3-4] ステータス・担当者列の表示確認

**手順:**
1. テストチケットのコメント一覧を表示

**確認1:** 各コメント行にステータス列と担当者列が表示される

**確認2:** 担当者名がリンクになっている（ユーザーはユーザーのページ、グループはグループのページに遷移。ロック中のユーザーは管理者以外にはリンクなし）

**確認3:** ステータスと担当者が各コメント時点の正しい値を表示している

### [3-5] 右クリックコンテキストメニュー

**手順:**
1. 折りたたまれたコメントのヘッダー行を右クリック

**確認1:** 「詳細を表示」が表示される。「詳細を隠す」は表示されない

2. 「詳細を表示」をクリック → 展開されたコメントを右クリック

**確認2:** 「詳細を隠す」が表示される。「詳細を表示」は表示されない

3. 右クリック → 「すべての詳細を表示」

**確認3:** すべてのコメントが展開される

4. 右クリック → 「すべての詳細を隠す」

**確認4:** すべてのコメントが折りたたまれる

### [3-6] コンテキストメニューの閉じ動作と既存メニューとの排他

**手順:**
1. コメントを右クリックしてメニュー表示 → メニュー外をクリック

**確認1:** メニューが閉じる

2. コメントを右クリックしてメニュー表示 → チケット行を右クリック

**確認2:** コメント履歴メニューが閉じ、Redmine 標準メニューが表示される

3. Redmine 標準メニューが表示された状態で、コメントを右クリック

**確認3:** Redmine 標準メニューが閉じ、コメント履歴メニューが表示される
