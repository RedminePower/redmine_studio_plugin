# Children Count（子チケット数）テスト仕様書

## 概要

チケット一覧に「子チケット数」カラムを追加する機能のテスト仕様。直下の子チケット数を表示し、リンクをクリックすると親が当該チケットの一覧画面に遷移する。ツールチップで子チケットの ID と件名を確認できる。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| カラム名 | `:children_count` |
| カラムクラス | `RedmineStudioPlugin::ChildrenCount::QueryColumn` |
| Issue パッチ | `RedmineStudioPlugin::ChildrenCount::IssuePatch` |
| IssueQuery パッチ | `RedmineStudioPlugin::ChildrenCount::IssueQueryPatch` |
| QueriesHelper パッチ | `RedmineStudioPlugin::ChildrenCount::QueriesHelperPatch` |
| 専用テーブル/モデル | **なし**（オンザフライ集計、`Issue.parent_id` を直接 GROUP BY） |
| ロケールファイル | `config/locales/children_count_ja.yml`, `config/locales/children_count_en.yml` |

## 仕様

| 項目 | 値 |
|------|-----|
| 集計対象 | 直下の子チケット（孫以降は含めない） |
| visibility | 適用（ユーザーから見える子のみカウント） |
| 表示 | 0 件: `<span class="children-count">0</span>` / 1 件以上: parent_id フィルタへの link_to |
| デフォルトソート順 | desc（多い順） |
| ツールチップ件数上限 | 10 件まで。超過時は最終行に `...他 N 件`（en: `...N more`） |
| 件名文字数上限 | 30 文字。超過時は末尾に `...` |

---

## 1. Runner テスト

### [1-1] Issue パッチ適用確認

**確認方法:**
```ruby
puts Issue.included_modules.map(&:name).include?('RedmineStudioPlugin::ChildrenCount::IssuePatch')
```

**期待結果:** `true`

### [1-2] IssueQuery パッチ適用確認

**確認方法:**
```ruby
puts IssueQuery.ancestors.map(&:name).include?('RedmineStudioPlugin::ChildrenCount::IssueQueryPatch')
```

**期待結果:** `true`

### [1-3] QueriesHelper パッチ適用確認

**確認方法:**
```ruby
puts QueriesHelper.instance_methods.include?(:column_value_with_children_count)
```

**期待結果:** `true`

### [1-4] カラム登録確認

**確認方法:**
```ruby
col = IssueQuery.available_columns.find { |c| c.name == :children_count }
puts "found: #{(col.nil? == false)}"
puts "inline: #{col ? col.inline? : 'N/A'}"
puts "sortable: #{col ? col.sortable? : 'N/A'}"
puts "default_order: #{col ? col.default_order : 'N/A'}"
```

**期待結果:**
- `found: true`
- `inline: true`
- `sortable: true`
- `default_order: desc`

### [1-5] ロケールキー確認（日本語）

**確認方法:**
```ruby
I18n.locale = :ja
puts "field_children_count: #{I18n.t(:field_children_count)}"
puts "label_children_count_others: #{I18n.t(:label_children_count_others, count: 3)}"
```

**期待結果:**
- `field_children_count: 子チケット数`
- `label_children_count_others: 他 3 件`

### [1-6] ロケールキー確認（英語）

**確認方法:**
```ruby
I18n.locale = :en
puts "field_children_count: #{I18n.t(:field_children_count)}"
puts "label_children_count_others: #{I18n.t(:label_children_count_others, count: 3)}"
```

**期待結果:**
- `field_children_count: Children Count`
- `label_children_count_others: 3 more`

### [1-7] 子チケットがない場合のカウントは 0

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)

parent = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-7_NoChildren', author: user_a)

puts "count: #{parent.children_count_value}"
```

**期待結果:** `count: 0`

### [1-8] 直下の子チケットが正しくカウントされる

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)

parent = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-8_Parent', author: user_a)
child1 = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-8_Child1', author: user_a, parent_issue_id: parent.id)
child2 = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-8_Child2', author: user_a, parent_issue_id: parent.id)
child3 = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-8_Child3', author: user_a, parent_issue_id: parent.id)

fresh = Issue.find(parent.id)
puts "count: #{fresh.children_count_value}"
```

**期待結果:** `count: 3`

### [1-9] 孫チケットはカウントに含まれない

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)

parent = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-9_Parent', author: user_a)
child = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-9_Child', author: user_a, parent_issue_id: parent.id)
grandchild = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-9_Grandchild', author: user_a, parent_issue_id: child.id)

fresh_parent = Issue.find(parent.id)
fresh_child = Issue.find(child.id)
puts "parent_count: #{fresh_parent.children_count_value}"
puts "child_count: #{fresh_child.children_count_value}"
```

**期待結果:**
- `parent_count: 1`（直下の child のみ）
- `child_count: 1`（直下の grandchild のみ）

### [1-10] ツールチップに ID と件名が出力される

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)

parent = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-10_Parent', author: user_a)
child1 = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-10_Child1', author: user_a, parent_issue_id: parent.id)
child2 = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-10_Child2', author: user_a, parent_issue_id: parent.id)

fresh = Issue.find(parent.id)
tooltip = fresh.children_tooltip
puts "tooltip:"
puts tooltip
puts "---"
puts "contains_child1: #{tooltip.include?("##{child1.id} CC_1-10_Child1")}"
puts "contains_child2: #{tooltip.include?("##{child2.id} CC_1-10_Child2")}"
```

**期待結果:**
- `contains_child1: true`
- `contains_child2: true`

### [1-11] ツールチップの件数上限（10 件まで表示、超過時は `...他 N 件`）

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)

parent = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-11_Parent', author: user_a)

# 12 件の子チケットを作成
12.times do |i|
  Issue.create(project: project, tracker: project.trackers.first, subject: "CC_1-11_Child_#{i + 1}", author: user_a, parent_issue_id: parent.id)
end

fresh = Issue.find(parent.id)
tooltip = fresh.children_tooltip
lines = tooltip.split("\n")
puts "total_lines: #{lines.size}"
puts "last_line: #{lines.last}"
puts "count: #{fresh.children_count_value}"
```

**期待結果:**
- `total_lines: 11`（10 件分 + `...他 2 件` の 1 行）
- `last_line: ...他 2 件`
- `count: 12`

### [1-12] ツールチップの件名文字数上限（30 文字、超過時は `...`）

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)

parent = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-12_Parent', author: user_a)

long_subject = 'あ' * 40  # 40 文字
child = Issue.create(project: project, tracker: project.trackers.first, subject: long_subject, author: user_a, parent_issue_id: parent.id)

fresh = Issue.find(parent.id)
tooltip = fresh.children_tooltip
puts "tooltip: #{tooltip}"

expected_truncated = ('あ' * 30) + '...'
puts "contains_truncated: #{tooltip.include?(expected_truncated)}"
```

**期待結果:**
- `contains_truncated: true`（先頭 30 文字 + `...` で省略されている）

### [1-13] 件名がちょうど 30 文字の場合は省略されない

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)

parent = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-13_Parent', author: user_a)

exact_subject = 'い' * 30  # ちょうど 30 文字
child = Issue.create(project: project, tracker: project.trackers.first, subject: exact_subject, author: user_a, parent_issue_id: parent.id)

fresh = Issue.find(parent.id)
tooltip = fresh.children_tooltip
puts "ends_with_dots: #{tooltip.end_with?('...')}"
puts "contains_exact: #{tooltip.include?(exact_subject)}"
```

**期待結果:**
- `ends_with_dots: false`
- `contains_exact: true`

### [1-14] visibility 適用: 権限のない子はカウントに含まれない

**前提条件:**
- 別プロジェクトに子チケットを作成するため、`Setting.cross_project_subtasks = 'system'` に一時的に設定（テスト後に元に戻す）

**確認方法:**
```ruby
# 非表示プロジェクト（is_public: false、メンバー外）を用意し、
# その配下の子チケットがカウントされないことを確認

orig_setting = Setting.cross_project_subtasks
Setting.cross_project_subtasks = 'system'

User.current = User.find(1)  # admin
project_public = Project.first

private_proj = Project.where(is_public: false, name: 'CC_1-14_Private').first
unless private_proj
  private_proj = Project.create(name: 'CC_1-14_Private', identifier: "cc_1_14_private_#{Time.now.to_i}", is_public: false)
  private_proj.trackers = project_public.trackers
  private_proj.enabled_module_names = ['issue_tracking']
  private_proj.save
end

admin = User.find(1)

parent = Issue.create(project: project_public, tracker: project_public.trackers.first, subject: 'CC_1-14_Parent', author: admin)
visible_child = Issue.create(project: project_public, tracker: project_public.trackers.first, subject: 'CC_1-14_Visible', author: admin, parent_issue_id: parent.id)
hidden_child = Issue.create(project: private_proj, tracker: private_proj.trackers.first, subject: 'CC_1-14_Hidden', author: admin, parent_issue_id: parent.id)

# 一般ユーザー（非メンバー）視点でカウント
guest = User.find_by(login: 'cc_guest_user')
unless guest
  guest = User.new(login: 'cc_guest_user', firstname: 'CC', lastname: 'Guest', mail: 'cc_guest@example.com', status: 1)
  guest.password = 'password123'
  guest.password_confirmation = 'password123'
  guest.save
end

User.current = guest
fresh = Issue.find(parent.id)
count = fresh.children_count_value
puts "guest_count: #{count}"

# admin 視点では両方カウントされる
User.current = User.find(1)
admin_count = Issue.find(parent.id).children_count_value
puts "admin_count: #{admin_count}"

Setting.cross_project_subtasks = orig_setting
```

**期待結果:**
- `guest_count: 1`（visible_child のみ）
- `admin_count: 2`（visible_child + hidden_child）

### [1-15] プリロードによる children_count_value の設定確認

**確認方法:**
```ruby
User.current = User.find(1)

q = IssueQuery.new(name: 'test_1_15', filters: {})
q.column_names = [:id, :subject, :children_count]
issues = q.issues(limit: 5)

preloaded = issues.select { |i| i.instance_variable_defined?(:@children_count_value) }
puts "preloaded: #{preloaded.size}"
puts "total: #{issues.size}"
```

**期待結果:** `preloaded` と `total` が同じ値

### [1-15b] プリロード時に children_tooltip もセットされる

**確認方法:**
```ruby
User.current = User.find(1)

q = IssueQuery.new(name: 'test_1_15b', filters: {})
q.column_names = [:id, :subject, :children_count]
issues = q.issues(limit: 5)

with_count = issues.select { |i| i.instance_variable_defined?(:@children_count_value) }
with_tooltip = issues.select { |i| i.instance_variable_defined?(:@children_tooltip) }
puts "with_count: #{with_count.size}"
puts "with_tooltip: #{with_tooltip.size}"
puts "total: #{issues.size}"
```

**期待結果:** `with_count`、`with_tooltip`、`total` がすべて同じ値（プリロードで両方セット済み）

### [1-16] ソート実行確認（joins_for_order_statement）

**確認方法:**
```ruby
User.current = User.find(1)

q = IssueQuery.new(name: 'test_1_16', filters: {})
q.column_names = [:id, :children_count]
q.sort_criteria = [['children_count', 'desc']]

# ソート実行でエラーが出ないことを確認
issues = q.issues(limit: 5)
puts "sort_ok: true"
puts "count: #{issues.size}"
```

**期待結果:**
- `sort_ok: true`（エラーなし）
- `count:` 0以上の数値

### [1-16b] ソート結果の順序検証（多い順）

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)

# 子の数が異なる 3 つの親を作成
parent_3 = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-16b_Parent3', author: user_a)
3.times { |i| Issue.create(project: project, tracker: project.trackers.first, subject: "CC_1-16b_P3_C#{i + 1}", author: user_a, parent_issue_id: parent_3.id) }

parent_1 = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-16b_Parent1', author: user_a)
Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-16b_P1_C1', author: user_a, parent_issue_id: parent_1.id)

parent_5 = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-16b_Parent5', author: user_a)
5.times { |i| Issue.create(project: project, tracker: project.trackers.first, subject: "CC_1-16b_P5_C#{i + 1}", author: user_a, parent_issue_id: parent_5.id) }

# desc ソートで取得し、3 件中の並び順を確認
q = IssueQuery.new(name: 'test_1_16b', filters: {})
q.column_names = [:id, :subject, :children_count]
q.sort_criteria = [['children_count', 'desc']]
q.add_filter('subject', '~', ['CC_1-16b_Parent'])

results = q.issues
ordered_ids = results.map(&:id)
puts "order: #{ordered_ids.inspect}"

# parent_5 → parent_3 → parent_1 の順になっていること
idx_5 = ordered_ids.index(parent_5.id)
idx_3 = ordered_ids.index(parent_3.id)
idx_1 = ordered_ids.index(parent_1.id)
puts "desc_order_ok: #{idx_5 < idx_3 && idx_3 < idx_1}"
```

**期待結果:** `desc_order_ok: true`（子チケットの多い親から順に並ぶ）

### [1-17] デフォルトソート順序の確認

**確認方法:**
```ruby
col = IssueQuery.available_columns.find { |c| c.name == :children_count }
puts "default_order: #{col.default_order}"
```

**期待結果:** `default_order: desc`

### [1-18] 子チケットなしの場合のツールチップは空文字

**確認方法:**
```ruby
User.current = User.find(1)
project = Project.first
user_a = User.find(1)

parent = Issue.create(project: project, tracker: project.trackers.first, subject: 'CC_1-18_NoChildren', author: user_a)

fresh = Issue.find(parent.id)
puts "tooltip: '#{fresh.children_tooltip}'"
puts "is_empty: #{fresh.children_tooltip.empty?}"
```

**期待結果:**
- `is_empty: true`

---

## 2. HTTP テスト

### [2-1] チケット一覧で children_count カラムを指定して表示できる

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:3061/redmine_61/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
```

**期待結果:** `200`

### [2-2] children_count カラムがチケット一覧のカラムオプションに表示される

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:3061/redmine_61/issues?set_filter=1' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'children_count'
```

**期待結果:** `True`

### [2-3] カウント値が 0 のチケットは span でレンダリングされる

**前提条件:**
- 子チケットがないチケットが存在すること

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:3061/redmine_61/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:asc' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match '<span class="children-count">0</span>'
```

**期待結果:** `True`

### [2-4] カウント値が 1 以上のチケットは a タグでリンクされる

**前提条件:**
- 子チケットがあるチケットが存在すること（[1-8] などで作成済み）

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:3061/redmine_61/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:desc' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'class="children-count"[^>]*>\d+</a>'
```

**期待結果:** `True`

### [2-5] リンク先 URL に parent_id フィルタが含まれる

**確認方法:**
```powershell
# [2-4] と同じリクエスト結果を使う
$response.Content -match 'parent_id.*set_filter=1|set_filter=1.*parent_id'
```

**期待結果:** `True`（v=parent_id か f[]=parent_id が URL 内に存在）

### [2-5b] リンク先 URL はクロスプロジェクト（project_id を含まない）

**前提条件:**
- 特定のプロジェクト配下の一覧画面（プロジェクトスコープ）からアクセスする

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))

# 任意のプロジェクト identifier を1つ取得（最初のプロジェクト）
$projIdResponse = Invoke-RestMethod -Uri 'http://localhost:3061/redmine_61/projects.json?limit=1' `
  -Credential $cred -AllowUnencryptedAuthentication
$projectId = $projIdResponse.projects[0].identifier

# プロジェクトスコープのチケット一覧を取得
$response = Invoke-WebRequest -Uri "http://localhost:3061/redmine_61/projects/$projectId/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:desc" `
  -Credential $cred -AllowUnencryptedAuthentication

# children-count クラスを持つ link の href を抽出
$matches = [regex]::Matches($response.Content, 'href="([^"]+)"[^>]*class="children-count"')
if ($matches.Count -eq 0) {
  # class が先・href が後のパターンも試す
  $matches = [regex]::Matches($response.Content, 'class="children-count"[^>]*href="([^"]+)"')
}

$hasProjectId = $false
foreach ($m in $matches) {
  $href = $m.Groups[1].Value
  # /issues? か /issues/? で始まり、/projects/{id}/issues ではないこと
  if ($href -match '/projects/[^/]+/issues') {
    $hasProjectId = $true
    break
  }
}
Write-Host "matched_links: $($matches.Count)"
Write-Host "any_link_has_project_scope: $hasProjectId"
```

**期待結果:**
- `matched_links` が 1 以上（リンクが存在）
- `any_link_has_project_scope: False`（リンク先はすべてクロスプロジェクトの `/issues?...`）

### [2-6] ツールチップ（title 属性）が出力される

**確認方法:**
```powershell
# [2-4] と同じリクエスト結果を使う
$response.Content -match 'title=".*#\d+'
```

**期待結果:** `True`

### [2-7] children_count でソートできる（降順）

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:3061/redmine_61/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:desc' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
```

**期待結果:** `200`（エラーなくソートされた一覧が表示）

### [2-8] children_count でソートできる（昇順）

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:3061/redmine_61/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:asc' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
```

**期待結果:** `200`

### [2-9] children_count を含めても CSV エクスポートが成功する

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:3061/redmine_61/issues.csv?set_filter=1&c[]=id&c[]=subject&c[]=children_count' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
# CSV に HTML タグが混入していないことも確認
$response.Content -notmatch '<span|<a '
```

**期待結果:**
- `StatusCode: 200`
- `<span` / `<a ` を含まない（CSV には純粋な数値のみ）

### [2-9b] CSV に数値が正しく出力される

**前提条件:**
- 子チケットがあるチケットが存在すること（[1-8] や [1-16b] で作成済み）

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:3061/redmine_61/issues.csv?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:desc' `
  -Credential $cred -AllowUnencryptedAuthentication

$csv = $response.Content
$lines = $csv -split "`n"
# 1 行目はヘッダー、2 行目以降がデータ
Write-Host "header: $($lines[0])"
Write-Host "first_data_row: $($lines[1])"

# 1 行目に "children_count" 相当のヘッダーがあること
$hasHeader = $lines[0] -match '子チケット数|Children Count'
Write-Host "has_header: $hasHeader"

# 2 行目以降の最後のカラム（children_count）が数値のみ（HTML タグなし）
$firstDataFields = $lines[1] -split ','
$lastField = $firstDataFields[$firstDataFields.Length - 1].Trim() -replace '"', ''
Write-Host "last_field: '$lastField'"
$isNumeric = $lastField -match '^\d+$'
Write-Host "last_field_is_numeric: $isNumeric"
```

**期待結果:**
- `has_header: True`（CSV ヘッダーに「子チケット数」または「Children Count」が含まれる）
- `last_field_is_numeric: True`（先頭データ行の children_count 列が純粋な数値）

---

## 3. ブラウザテスト

該当なし（リンク遷移先の表示確認は HTTP テスト [2-4] / [2-5] で URL 構造を検証済み。実際の遷移は標準 Redmine のフィルタ機能のため、プラグイン固有の確認項目はない）。
