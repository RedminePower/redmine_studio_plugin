# Rally Count（ラリー回数）テスト仕様書

## 概要

チケット一覧に「ラリー回数」カラムを追加する機能のテスト仕様。担当者の切り替え回数を表示し、ツールチップで担当者の変更履歴を確認できる。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| カラム名 | `:rally_count` |
| カラムクラス | `RedmineStudioPlugin::RallyCount::QueryColumn` |
| Issue パッチ | `RedmineStudioPlugin::RallyCount::IssuePatch` |
| IssueQuery パッチ | `RedmineStudioPlugin::RallyCount::IssueQueryPatch` |
| QueriesHelper パッチ | `RedmineStudioPlugin::RallyCount::QueriesHelperPatch` |
| モデル | `IssueRallyCount` |
| テーブル | `issue_rally_counts` |
| ロケールファイル | `config/locales/rally_count_ja.yml`, `config/locales/rally_count_en.yml` |

---

## 1. Runner テスト

### [1-1] テーブル存在確認

**確認方法:**
```ruby
puts ActiveRecord::Base.connection.table_exists?(:issue_rally_counts)
```

**期待結果:** `true`

### [1-2] テーブルのカラム構造確認

**確認方法:**
```ruby
columns = ActiveRecord::Base.connection.columns(:issue_rally_counts)
columns.each { |c| puts "#{c.name}: #{c.type}" }
```

**期待結果:**
- `id: integer`
- `issue_id: integer`
- `count: integer`

### [1-3] モデルクラス定義確認

**確認方法:**
```ruby
puts defined?(IssueRallyCount)
puts IssueRallyCount.ancestors.include?(ActiveRecord::Base)
```

**期待結果:** 両方 `true` または `constant` と `true`

### [1-4] Issue パッチ適用確認

**確認方法:**
```ruby
puts Issue.included_modules.map(&:name).include?('RedmineStudioPlugin::RallyCount::IssuePatch')
```

**期待結果:** `true`

### [1-5] IssueQuery パッチ適用確認

**確認方法:**
```ruby
puts IssueQuery.ancestors.map(&:name).include?('RedmineStudioPlugin::RallyCount::IssueQueryPatch')
```

**期待結果:** `true`

### [1-6] QueriesHelper パッチ適用確認

**確認方法:**
```ruby
puts QueriesHelper.instance_methods.include?(:column_value_with_rally_count)
```

**期待結果:** `true`

### [1-7] カラム登録確認

**確認方法:**
```ruby
col = IssueQuery.available_columns.find { |c| c.name == :rally_count }
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
puts "field_rally_count: #{I18n.t(:field_rally_count)}"
puts "label_rally_count_no_assignee: #{I18n.t(:label_rally_count_no_assignee)}"
```

**期待結果:**
- `field_rally_count: ラリー回数`
- `label_rally_count_no_assignee: （担当者なし）`

### [1-9] 担当者変更時にカウントがインクリメントされる

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)
user_b = User.where(status: 1).where.not(id: 1).first

issue = Issue.create(project: project, tracker: project.trackers.first, subject: 'RC_1-9_Increment', author: user_a)
# 作成時はカウントなし
count_after_create = IssueRallyCount.find_by(issue_id: issue.id)&.count || 0
puts "after_create: #{count_after_create}"

# 担当者変更1回目
issue.reload
issue.init_journal(user_a)
issue.assigned_to = user_b
issue.save
count_after_first = IssueRallyCount.find_by(issue_id: issue.id)&.count || 0
puts "after_first_change: #{count_after_first}"

# 担当者変更2回目
issue.reload
issue.init_journal(user_a)
issue.assigned_to = user_a
issue.save
count_after_second = IssueRallyCount.find_by(issue_id: issue.id)&.count || 0
puts "after_second_change: #{count_after_second}"
```

**期待結果:**
- `after_create: 0`（新規作成時はカウントしない）
- `after_first_change: 1`
- `after_second_change: 2`

### [1-10] チケット作成時に担当者を設定してもカウントされない

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)

issue = Issue.create(project: project, tracker: project.trackers.first, subject: 'RC_1-10_CreateWithAssignee', author: user_a, assigned_to: user_a)
count = IssueRallyCount.find_by(issue_id: issue.id)&.count || 0
puts "count: #{count}"
```

**期待結果:** `count: 0`

### [1-11] 担当者クリアもカウントされる

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)

issue = Issue.create(project: project, tracker: project.trackers.first, subject: 'RC_1-11_ClearAssignee', author: user_a, assigned_to: user_a)

issue.reload
issue.init_journal(user_a)
issue.assigned_to = nil
issue.save
count = IssueRallyCount.find_by(issue_id: issue.id)&.count || 0
puts "count: #{count}"
```

**期待結果:** `count: 1`

### [1-12] チケット削除時にレコードも削除される

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)
user_b = User.where(status: 1).where.not(id: 1).first

issue = Issue.create(project: project, tracker: project.trackers.first, subject: 'RC_1-12_Delete', author: user_a)
issue.reload
issue.init_journal(user_a)
issue.assigned_to = user_b
issue.save

issue_id = issue.id
exists_before = IssueRallyCount.exists?(issue_id: issue_id)
issue.destroy
exists_after = IssueRallyCount.exists?(issue_id: issue_id)

puts "before_delete: #{exists_before}"
puts "after_delete: #{exists_after}"
```

**期待結果:**
- `before_delete: true`
- `after_delete: false`

### [1-13] ツールチップの内容確認

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)
user_b = User.where(status: 1).where.not(id: 1).first

issue = Issue.create(project: project, tracker: project.trackers.first, subject: 'RC_1-13_Tooltip', author: user_a)

issue.reload
issue.init_journal(user_a)
issue.assigned_to = user_b
issue.save

issue.reload
issue.init_journal(user_a)
issue.assigned_to = user_a
issue.save

fresh = Issue.find(issue.id)
tooltip = fresh.rally_tooltip
puts tooltip
```

**期待結果:**
```
（担当者なし）
 - {user_b の名前}
 - {user_a の名前}
```

### [1-14] ツールチップのプリロード確認

**確認方法:**
```ruby
User.current = User.find(1)
q = IssueQuery.new(name: 'test', filters: {})
q.column_names = [:id, :subject, :rally_count]
issues = q.issues(limit: 5)
preloaded = issues.select { |i| i.instance_variable_defined?(:@rally_tooltip) }
puts "preloaded: #{preloaded.size}"
puts "total: #{issues.size}"
```

**期待結果:** `preloaded` と `total` が同じ値

### [1-15] ソート実行確認（joins_for_order_statement）

**確認方法:**
```ruby
q = IssueQuery.new(name: 'test', filters: {})
q.column_names = [:id, :rally_count]
q.sort_criteria = [['rally_count', 'desc']]
# ソート実行でエラーが出ないことを確認
issues = q.issues(limit: 5)
puts "sort_ok: true"
puts "count: #{issues.size}"
```

**期待結果:**
- `sort_ok: true`（エラーなし）
- `count:` 0以上の数値

### [1-16] デフォルトソート順序の確認

**確認方法:**
```ruby
col = IssueQuery.available_columns.find { |c| c.name == :rally_count }
puts "default_order: #{col.default_order}"
```

**期待結果:** `default_order: desc`

### [1-17] 削除済みユーザーのツールチップ表示

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)

# テスト用ユーザーを作成して担当者に設定後、削除
temp_user = User.create(login: 'rc_temp_user', firstname: 'Temp', lastname: 'User', mail: 'rc_temp@example.com', status: 1)
temp_user.password = 'password123'
temp_user.password_confirmation = 'password123'
temp_user.save

issue = Issue.create(project: project, tracker: project.trackers.first, subject: 'RC_1-17_DeletedUser', author: user_a)

# 担当者にtemp_userを設定
issue.reload
issue.init_journal(user_a)
issue.assigned_to = temp_user
issue.save

# temp_userを削除
temp_user.destroy

# ツールチップを確認（エラーにならないこと）
fresh = Issue.find(issue.id)
tooltip = fresh.rally_tooltip
puts "tooltip: #{tooltip}"
puts "no_error: true"

no_assignee = I18n.t(:label_rally_count_no_assignee)
puts "contains_no_assignee: #{tooltip.include?(no_assignee)}"
```

**期待結果:**
- `no_error: true`（エラーなし）
- `contains_no_assignee: true`（削除済みユーザーは「（担当者なし）」と表示される）

---

## 2. HTTP テスト

### [2-1] チケット一覧で rally_count カラムを指定して表示できる

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=rally_count' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
```

**期待結果:** `200`

### [2-2] rally_count カラムがチケット一覧のカラムオプションに表示される

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'rally_count'
```

**期待結果:** `True`

### [2-3] ラリー回数の値が HTML に出力される

**前提条件:**
- 担当者変更のあるチケットが存在すること

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=rally_count&sort=rally_count:desc' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'class="rally-count"'
```

**期待結果:** `True`

### [2-4] ツールチップ（title 属性）が出力される

**確認方法:**
```powershell
# [2-3] と同じリクエスト
$response.Content -match 'title=.*class="rally-count"'
```

**期待結果:** `True`

### [2-5] ラリー回数でソートできる（降順）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=rally_count&sort=rally_count:desc' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
```

**期待結果:** `200`（エラーなくソートされた一覧が表示）

### [2-6] ラリー回数でソートできる（昇順）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=rally_count&sort=rally_count:asc' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
```

**期待結果:** `200`

### [2-7] ラリー回数 0 のチケットも表示される

**前提条件:**
- 担当者変更のないチケットが存在すること（チケットID を `{NO_RALLY_ID}` とする）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=rally_count&f[]=issue_id&op[issue_id]==&v[issue_id][]={NO_RALLY_ID}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'rally-count.*title=.*>0<'
```

**期待結果:** `True`

---

## 3. ブラウザテスト

該当なし（すべて Runner / HTTP テストでカバー済み）
