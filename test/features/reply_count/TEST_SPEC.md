# Reply Count（返答回数）テスト仕様書

## 概要

チケット一覧に「返答回数」カラムを追加する機能のテスト仕様。担当者の切り替え回数を表示し、ツールチップで担当者の変更履歴を確認できる。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| カラム名 | `:reply_count` |
| カラムクラス | `RedmineStudioPlugin::ReplyCount::QueryColumn` |
| Issue パッチ | `RedmineStudioPlugin::ReplyCount::IssuePatch` |
| IssueQuery パッチ | `RedmineStudioPlugin::ReplyCount::IssueQueryPatch` |
| QueriesHelper パッチ | `RedmineStudioPlugin::ReplyCount::QueriesHelperPatch` |
| モデル | `IssueReplyCount` |
| テーブル | `issue_reply_counts` |
| ロケールファイル | `config/locales/reply_count_ja.yml`, `config/locales/reply_count_en.yml` |

---

## 1. Runner テスト

チケットが要る試験は、試験の中でプロジェクト・ロール・ユーザー・チケットを作り、終わったら消す。

### [1-1] テーブル存在確認

**確認方法:**
```ruby
puts ActiveRecord::Base.connection.table_exists?(:issue_reply_counts)
```

**期待結果:** `true`

### [1-2] テーブルのカラム構造確認

**確認方法:**
```ruby
columns = ActiveRecord::Base.connection.columns(:issue_reply_counts)
columns.each { |c| puts "#{c.name}: #{c.type}" }
```

**期待結果:**
- `id: integer`
- `issue_id: integer`
- `count: integer`

### [1-3] モデルクラス定義確認

**確認方法:**
```ruby
puts defined?(IssueReplyCount)
puts IssueReplyCount.ancestors.include?(ActiveRecord::Base)
```

**期待結果:** 両方 `true` または `constant` と `true`

### [1-4] Issue パッチ適用確認

**確認方法:**
```ruby
puts Issue.included_modules.map(&:name).include?('RedmineStudioPlugin::ReplyCount::IssuePatch')
```

**期待結果:** `true`

### [1-5] IssueQuery パッチ適用確認

**確認方法:**
```ruby
puts IssueQuery.ancestors.map(&:name).include?('RedmineStudioPlugin::ReplyCount::IssueQueryPatch')
```

**期待結果:** `true`

### [1-6] QueriesHelper パッチ適用確認

**確認方法:**
```ruby
puts QueriesHelper.instance_methods.include?(:column_value_with_reply_count)
```

**期待結果:** `true`

### [1-7] カラム登録確認

**確認方法:**
```ruby
col = IssueQuery.available_columns.find { |c| c.name == :reply_count }
puts "found: #{col ? true : false}"
puts "inline: #{col ? col.inline? : 'N/A'}"
puts "sortable: #{col ? col.sortable? : 'N/A'}"
```

**期待結果:**
- `found: true`
- `inline: true`
- `sortable: true`

### [1-8] ロケールキー確認

**確認方法:**
```ruby
I18n.locale = :ja
puts "field_reply_count: #{I18n.t(:field_reply_count)}"
puts "label_reply_count_no_assignee: #{I18n.t(:label_reply_count_no_assignee)}"
```

**期待結果:**
- `field_reply_count: 返答回数`
- `label_reply_count_no_assignee: （担当者なし）`

### [1-9] 担当者変更時にカウントがインクリメントされる

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
# 担当者にできるロールのメンバー 2 人（user_a・user_b）がいるプロジェクト
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = role = user_a = user_b = nil
mk_user = ->(name) {
  u = User.new(login: "rc_#{name}_#{sfx}", firstname: 'RC', lastname: name, mail: "rc_#{name}_#{sfx}@example.com", status: 1)
  u.password = u.password_confirmation = 'password123'
  u.save!
  u
}
begin
  role = Role.create!(name: "RC_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  project = Project.new(name: "RC_#{sfx}", identifier: "rc-#{sfx}")
  project.enabled_module_names = %w[issue_tracking]
  project.trackers = [Tracker.first]
  project.save!
  user_a = mk_user.call('a')
  user_b = mk_user.call('b')
  [user_a, user_b].each { |u| Member.create!(principal: u, project: project, roles: [role]) }

  issue = Issue.create!(project: project, tracker: project.trackers.first, subject: 'RC_1-9_Increment', author: user_a)
  # 作成時はカウントなし
  count_after_create = IssueReplyCount.find_by(issue_id: issue.id)&.count || 0
  puts "after_create: #{count_after_create}"

  # 担当者変更1回目
  issue.reload
  issue.init_journal(user_a)
  issue.assigned_to = user_b
  issue.save!
  count_after_first = IssueReplyCount.find_by(issue_id: issue.id)&.count || 0
  puts "after_first_change: #{count_after_first}"

  # 担当者変更2回目
  issue.reload
  issue.init_journal(user_a)
  issue.assigned_to = user_a
  issue.save!
  count_after_second = IssueReplyCount.find_by(issue_id: issue.id)&.count || 0
  puts "after_second_change: #{count_after_second}"
ensure
  User.current = admin
  project&.destroy
  [user_a, user_b].compact.each { |u| u.destroy if User.exists?(u.id) }
  role&.destroy
end
```

**期待結果:**
- `after_create: 0`（新規作成時はカウントしない）
- `after_first_change: 1`
- `after_second_change: 2`

### [1-10] チケット作成時に担当者を設定してもカウントされない

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
# 担当者にできるロールのメンバー 2 人（user_a・user_b）がいるプロジェクト
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = role = user_a = user_b = nil
mk_user = ->(name) {
  u = User.new(login: "rc_#{name}_#{sfx}", firstname: 'RC', lastname: name, mail: "rc_#{name}_#{sfx}@example.com", status: 1)
  u.password = u.password_confirmation = 'password123'
  u.save!
  u
}
begin
  role = Role.create!(name: "RC_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  project = Project.new(name: "RC_#{sfx}", identifier: "rc-#{sfx}")
  project.enabled_module_names = %w[issue_tracking]
  project.trackers = [Tracker.first]
  project.save!
  user_a = mk_user.call('a')
  user_b = mk_user.call('b')
  [user_a, user_b].each { |u| Member.create!(principal: u, project: project, roles: [role]) }

  issue = Issue.create!(project: project, tracker: project.trackers.first, subject: 'RC_1-10_CreateWithAssignee', author: user_a, assigned_to: user_a)
  puts "assigned: #{issue.reload.assigned_to_id == user_a.id}"
  count = IssueReplyCount.find_by(issue_id: issue.id)&.count || 0
  puts "count: #{count}"
ensure
  User.current = admin
  project&.destroy
  [user_a, user_b].compact.each { |u| u.destroy if User.exists?(u.id) }
  role&.destroy
end
```

**期待結果:** `assigned: true`（担当者を付けて作れた）、`count: 0`

### [1-11] 担当者クリアもカウントされる

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
# 担当者にできるロールのメンバー 2 人（user_a・user_b）がいるプロジェクト
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = role = user_a = user_b = nil
mk_user = ->(name) {
  u = User.new(login: "rc_#{name}_#{sfx}", firstname: 'RC', lastname: name, mail: "rc_#{name}_#{sfx}@example.com", status: 1)
  u.password = u.password_confirmation = 'password123'
  u.save!
  u
}
begin
  role = Role.create!(name: "RC_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  project = Project.new(name: "RC_#{sfx}", identifier: "rc-#{sfx}")
  project.enabled_module_names = %w[issue_tracking]
  project.trackers = [Tracker.first]
  project.save!
  user_a = mk_user.call('a')
  user_b = mk_user.call('b')
  [user_a, user_b].each { |u| Member.create!(principal: u, project: project, roles: [role]) }

  issue = Issue.create!(project: project, tracker: project.trackers.first, subject: 'RC_1-11_ClearAssignee', author: user_a, assigned_to: user_a)

  issue.reload
  issue.init_journal(user_a)
  issue.assigned_to = nil
  issue.save!
  count = IssueReplyCount.find_by(issue_id: issue.id)&.count || 0
  puts "count: #{count}"
ensure
  User.current = admin
  project&.destroy
  [user_a, user_b].compact.each { |u| u.destroy if User.exists?(u.id) }
  role&.destroy
end
```

**期待結果:** `count: 1`

### [1-12] チケット削除時にレコードも削除される

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
# 担当者にできるロールのメンバー 2 人（user_a・user_b）がいるプロジェクト
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = role = user_a = user_b = nil
mk_user = ->(name) {
  u = User.new(login: "rc_#{name}_#{sfx}", firstname: 'RC', lastname: name, mail: "rc_#{name}_#{sfx}@example.com", status: 1)
  u.password = u.password_confirmation = 'password123'
  u.save!
  u
}
begin
  role = Role.create!(name: "RC_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  project = Project.new(name: "RC_#{sfx}", identifier: "rc-#{sfx}")
  project.enabled_module_names = %w[issue_tracking]
  project.trackers = [Tracker.first]
  project.save!
  user_a = mk_user.call('a')
  user_b = mk_user.call('b')
  [user_a, user_b].each { |u| Member.create!(principal: u, project: project, roles: [role]) }

  issue = Issue.create!(project: project, tracker: project.trackers.first, subject: 'RC_1-12_Delete', author: user_a)
  issue.reload
  issue.init_journal(user_a)
  issue.assigned_to = user_b
  issue.save!

  issue_id = issue.id
  exists_before = IssueReplyCount.exists?(issue_id: issue_id)
  issue.destroy
  exists_after = IssueReplyCount.exists?(issue_id: issue_id)

  puts "before_delete: #{exists_before}"
  puts "after_delete: #{exists_after}"
ensure
  User.current = admin
  project&.destroy
  [user_a, user_b].compact.each { |u| u.destroy if User.exists?(u.id) }
  role&.destroy
end
```

**期待結果:**
- `before_delete: true`
- `after_delete: false`

### [1-13] ツールチップの内容確認

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
# 担当者にできるロールのメンバー 2 人（user_a・user_b）がいるプロジェクト
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = role = user_a = user_b = nil
mk_user = ->(name) {
  u = User.new(login: "rc_#{name}_#{sfx}", firstname: 'RC', lastname: name, mail: "rc_#{name}_#{sfx}@example.com", status: 1)
  u.password = u.password_confirmation = 'password123'
  u.save!
  u
}
begin
  role = Role.create!(name: "RC_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  project = Project.new(name: "RC_#{sfx}", identifier: "rc-#{sfx}")
  project.enabled_module_names = %w[issue_tracking]
  project.trackers = [Tracker.first]
  project.save!
  user_a = mk_user.call('a')
  user_b = mk_user.call('b')
  [user_a, user_b].each { |u| Member.create!(principal: u, project: project, roles: [role]) }

  issue = Issue.create!(project: project, tracker: project.trackers.first, subject: 'RC_1-13_Tooltip', author: user_a)

  issue.reload
  issue.init_journal(user_a)
  issue.assigned_to = user_b
  issue.save!

  issue.reload
  issue.init_journal(user_a)
  issue.assigned_to = user_a
  issue.save!

  fresh = Issue.find(issue.id)
  tooltip = fresh.reply_tooltip
  puts tooltip
  expected = [I18n.t(:label_reply_count_no_assignee), " - #{user_b.name}", " - #{user_a.name}"].join("\n")
  puts "match: #{tooltip == expected}"
ensure
  User.current = admin
  project&.destroy
  [user_a, user_b].compact.each { |u| u.destroy if User.exists?(u.id) }
  role&.destroy
end
```

**期待結果:**
```
（担当者なし）
 - {user_b の名前}
 - {user_a の名前}
match: true
```

### [1-14] reply_items のプリロード確認

reply_count カラム表示時に reply_items (担当者の遷移) が一括プリロードされ、ツールチップは reply_items から導出できることを確認する。

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
# 担当者にできるロールのメンバー 2 人（user_a・user_b）がいるプロジェクト
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = role = user_a = user_b = nil
mk_user = ->(name) {
  u = User.new(login: "rc_#{name}_#{sfx}", firstname: 'RC', lastname: name, mail: "rc_#{name}_#{sfx}@example.com", status: 1)
  u.password = u.password_confirmation = 'password123'
  u.save!
  u
}
begin
  role = Role.create!(name: "RC_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  project = Project.new(name: "RC_#{sfx}", identifier: "rc-#{sfx}")
  project.enabled_module_names = %w[issue_tracking]
  project.trackers = [Tracker.first]
  project.save!
  user_a = mk_user.call('a')
  user_b = mk_user.call('b')
  [user_a, user_b].each { |u| Member.create!(principal: u, project: project, roles: [role]) }

  2.times do |n|
    i = Issue.create!(project: project, tracker: project.trackers.first, subject: "RC_1-14_#{n}", author: user_a)
    i.reload
    i.init_journal(user_a)
    i.assigned_to = user_b
    i.save!
  end
  q = IssueQuery.new(name: 'test', filters: {}, project: project)
  q.column_names = [:id, :subject, :reply_count]
  issues = q.issues(limit: 5)
  preloaded = issues.select { |i| i.instance_variable_get(:@reply_items) }
  puts "preloaded: #{preloaded.size}"
  puts "total: #{issues.size}"
  puts "tooltip_ok: #{issues.all? { |i| i.reply_tooltip.is_a?(String) }}"
ensure
  User.current = admin
  project&.destroy
  [user_a, user_b].compact.each { |u| u.destroy if User.exists?(u.id) }
  role&.destroy
end
```

**期待結果:**
- `preloaded: 2`・`total: 2`（作った 2 件がすべてプリロードされる）
- `tooltip_ok: true`（reply_items から導出したツールチップが文字列で得られる）

### [1-15] ソート実行確認（joins_for_order_statement）

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
# 担当者にできるロールのメンバー 2 人（user_a・user_b）がいるプロジェクト
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
project = role = user_a = user_b = nil
mk_user = ->(name) {
  u = User.new(login: "rc_#{name}_#{sfx}", firstname: 'RC', lastname: name, mail: "rc_#{name}_#{sfx}@example.com", status: 1)
  u.password = u.password_confirmation = 'password123'
  u.save!
  u
}
begin
  role = Role.create!(name: "RC_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  project = Project.new(name: "RC_#{sfx}", identifier: "rc-#{sfx}")
  project.enabled_module_names = %w[issue_tracking]
  project.trackers = [Tracker.first]
  project.save!
  user_a = mk_user.call('a')
  user_b = mk_user.call('b')
  [user_a, user_b].each { |u| Member.create!(principal: u, project: project, roles: [role]) }

  # 返答回数 1 回と 2 回のチケット
  [1, 2].each do |times|
    i = Issue.create!(project: project, tracker: project.trackers.first, subject: "RC_1-15_#{times}", author: user_a)
    times.times do |k|
      i.reload
      i.init_journal(user_a)
      i.assigned_to = k.even? ? user_b : user_a
      i.save!
    end
  end
  q = IssueQuery.new(name: 'test', filters: {}, project: project)
  q.column_names = [:id, :reply_count]
  q.sort_criteria = [['reply_count', 'desc']]
  # ソート実行でエラーが出ないことを確認
  issues = q.issues(limit: 5)
  puts "sort_ok: true"
  puts "count: #{issues.size}"
  puts "order: #{issues.map { |i| IssueReplyCount.find_by(issue_id: i.id)&.count }.inspect}"
ensure
  User.current = admin
  project&.destroy
  [user_a, user_b].compact.each { |u| u.destroy if User.exists?(u.id) }
  role&.destroy
end
```

**期待結果:**
- `sort_ok: true`（エラーなし）
- `count: 2`
- `order: [2, 1]`（返答回数の多い順）

### [1-16] デフォルトソート順序の確認

**確認方法:**
```ruby
col = IssueQuery.available_columns.find { |c| c.name == :reply_count }
puts "default_order: #{col.default_order}"
```

**期待結果:** `default_order: desc`

### [1-17] 担当者がグループ・削除したユーザー・削除したグループのときの名前

担当が「なし → ユーザー（後で削除） → グループ → グループ（後で削除） → admin」と移ったチケットで、1 件ずつ引く場合と一括で引く場合の両方を確かめる。
グループへの割り当ての設定に左右されないよう、履歴は直接書く。
削除したユーザーは、Redmine が履歴の担当者を匿名ユーザーに置き換える。削除したグループは id だけが残る。

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
admin = User.find(1)
User.current = admin
suffix = SecureRandom.hex(3)
project = Project.new(name: "RC_#{suffix}", identifier: "rc-#{suffix}")
project.enabled_module_names = %w[issue_tracking]
project.trackers = [Tracker.first]
project.save!
temp_user = User.new(login: "rc_tmp_#{suffix}", firstname: 'Temp', lastname: 'User', mail: "rc_tmp_#{suffix}@example.com", status: 1)
temp_user.password = temp_user.password_confirmation = 'password123'
temp_user.save!
group = Group.create!(lastname: "RC_Group_#{suffix}")
gone = Group.create!(lastname: "RC_Gone_#{suffix}")

issue = Issue.create!(project: project, tracker: project.trackers.first, subject: 'RC_1-17_Principals', author: admin)
begin
  [['', temp_user.id], [temp_user.id, group.id], [group.id, gone.id], [gone.id, admin.id]].each do |ov, v|
    j = Journal.create!(journalized: issue, user: admin, notes: '')
    JournalDetail.create!(journal: j, property: 'attr', prop_key: 'assigned_to_id', old_value: ov.to_s, value: v.to_s)
  end
  temp_user.destroy
  gone.destroy

  expected = ['', User.anonymous.name, group.name, '', admin.name]
  single = Issue.find(issue.id).reply_items.map { |i| i[:name] }
  batch_issue = Issue.find(issue.id)
  Issue.load_reply_items([batch_issue])
  batch = batch_issue.reply_items.map { |i| i[:name] }
  no_assignee = I18n.t(:label_reply_count_no_assignee)
  tooltip_expected = ([no_assignee] + [User.anonymous.name, group.name, no_assignee, admin.name].map { |n| " - #{n}" }).join("\n")
  puts "single: #{single == expected}"
  puts "batch: #{batch == expected}"
  puts "tooltip: #{Issue.find(issue.id).reply_tooltip == tooltip_expected}"
ensure
  User.current = admin
  project.destroy
  group.destroy
  temp_user.destroy if User.exists?(temp_user.id)
  gone.destroy if Group.exists?(gone.id)
end
```

**期待結果:**
- `single: true`・`batch: true`（グループはグループの名前、削除したユーザーは匿名ユーザー、削除したグループと担当者なしは空）
- `tooltip: true`（空の所は「（担当者なし）」）

---

## 2. HTTP テスト

**実行方法:** 各ブロックを PowerShell で流す。`{Username}` / `{Password}` は管理者。

**用意（HTTP テストの前に 1 回）:**
担当者を 1 回替えたチケットと、担当者を替えていないチケットを Runner で作る（前回の残りがあれば先に消す）。
最後の行の `ReplyId`（返答回数 1）・`NoReplyId`（返答回数 0）を、各試験の `{ReplyId}`・`{NoReplyId}` に入れる。

```ruby
admin = User.find(1)
User.current = admin
# 前回の残りを消す
Project.where('identifier LIKE ?', 'rc-http-%').each(&:destroy)
User.where('login LIKE ?', 'rc_http_%').each(&:destroy)
Role.where('name LIKE ?', 'RC_HTTP_%').each(&:destroy)
sfx = SecureRandom.hex(3)
role = Role.create!(name: "RC_HTTP_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
pr = Project.new(name: "RC_HTTP_#{sfx}", identifier: "rc-http-#{sfx}")
pr.enabled_module_names = %w[issue_tracking]
pr.trackers = [Tracker.first]
pr.save!
mk_user = ->(name) {
  u = User.new(login: "rc_http_#{name}_#{sfx}", firstname: 'RC', lastname: name, mail: "rc_http_#{name}_#{sfx}@example.com", status: 1)
  u.password = u.password_confirmation = 'password123'
  u.save!
  Member.create!(principal: u, project: pr, roles: [role])
  u
}
user_a = mk_user.call('a')
user_b = mk_user.call('b')
replied = Issue.create!(project: pr, tracker: pr.trackers.first, subject: "RC_HTTP_replied_#{sfx}", author: user_a)
replied.reload
replied.init_journal(user_a)
replied.assigned_to = user_b
replied.save!
none = Issue.create!(project: pr, tracker: pr.trackers.first, subject: "RC_HTTP_none_#{sfx}", author: user_a)
puts({ ReplyId: replied.id, NoReplyId: none.id }.to_json)
```

**後片付け（HTTP テストのあとに 1 回）:**

```ruby
User.current = User.find(1)
Project.where('identifier LIKE ?', 'rc-http-%').each(&:destroy)
User.where('login LIKE ?', 'rc_http_%').each(&:destroy)
Role.where('name LIKE ?', 'RC_HTTP_%').each(&:destroy)
puts [Project.where('identifier LIKE ?', 'rc-http-%').count, User.where('login LIKE ?', 'rc_http_%').count, Role.where('name LIKE ?', 'RC_HTTP_%').count].sum
```

**期待結果（後片付け）:** `0`

### [2-1] チケット一覧で reply_count カラムを指定して表示できる

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=reply_count' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
```

**期待結果:** `200`

### [2-2] reply_count カラムがチケット一覧のカラムオプションに表示される

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'reply_count'
```

**期待結果:** `True`

### [2-3] 返答回数の値が HTML に出力される

用意で作った、担当者を 1 回替えたチケット（`{ReplyId}`）を表示する。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=reply_count&sort=reply_count:desc&f[]=issue_id&op[issue_id]==&v[issue_id][]={ReplyId}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'class="reply-count">1<'
```

**期待結果:** `True`（返答回数 1 が出る）

### [2-4] ツールチップ（title 属性）が出力される

**確認方法:**
```powershell
# [2-3] と同じリクエスト（title は担当者履歴で複数行になりうるため (?s) で改行も跨がせる）
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=reply_count&sort=reply_count:desc&f[]=issue_id&op[issue_id]==&v[issue_id][]={ReplyId}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match '(?s)title=.*class="reply-count"'
```

**期待結果:** `True`

### [2-5] 返答回数でソートできる（降順）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=reply_count&sort=reply_count:desc' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
```

**期待結果:** `200`（エラーなくソートされた一覧が表示）

### [2-6] 返答回数でソートできる（昇順）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=reply_count&sort=reply_count:asc' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
```

**期待結果:** `200`

### [2-7] 返答回数 0 のチケットも表示される

用意で作った、担当者を替えていないチケット（`{NoReplyId}`）を表示する。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=reply_count&f[]=issue_id&op[issue_id]==&v[issue_id][]={NoReplyId}' `
  -Credential $cred -AllowUnencryptedAuthentication
# span は title 属性 → class="reply-count" の順で出力される（title は複数行になりうるため (?s)）
$response.Content -match '(?s)title=.*class="reply-count">0<'
```

**期待結果:** `True`

---

## 3. ブラウザテスト

該当なし（すべて Runner / HTTP テストでカバー済み）
