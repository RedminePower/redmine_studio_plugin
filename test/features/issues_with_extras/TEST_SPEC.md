# Issues With Extras API テスト仕様書

## 概要

`GET /issues_with_extras/:id` および `GET /issues_with_extras` のテスト仕様。Redmine 標準の `GET /issues/:id.json` / `/issues.json` のレスポンスに、本 Plugin が提供する `reply_count` / `children_count` / `spent_hours_by_user` と、Redmine 標準の一覧カラム（標準 API では返らない）である `last_updated_by` / `last_notes` を追加で含めて返す専用エンドポイント。

標準の `IssuesController` を継承し、view (`app/views/issues_with_extras/*.api.rsb`) でフィールドを追加している。標準の `/issues` エンドポイントは変更しないため、他 Plugin と共存可能。

`reply_count` / `children_count` は `count` + `items` のネストオブジェクトで返す。`items` は表示の元情報（id + name の配列）で、整形（ラベル化・件名の省略・「他N件」）はクライアント側の責務とする。

`last_updated_by` / `last_notes` は Redmine 本体の `Issue#last_updated_by` / `Issue#last_notes`（およびプリロード `load_visible_last_updated_by` / `load_visible_last_notes`）をそのまま利用する。プラグインでの再実装はしない。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| Controller | `IssuesWithExtrasController` (`IssuesController` を継承) |
| ファイル | `app/controllers/issues_with_extras_controller.rb` |
| ルーティング | `GET /issues_with_extras`, `GET /issues_with_extras/:id` |
| View ファイル | `app/views/issues_with_extras/show.api.rsb`, `app/views/issues_with_extras/index.api.rsb` |
| 認証 | ログイン必須（本体の `login_required` 設定に関わらず一律。未認証は 401）。`before_action :require_login`（`accept_api_auth :index, :show` は継承）。標準 `/issues` より厳格 |
| 権限 | 認証済みユーザに対しては標準 `view_issues` を流用（`authorize` を controller 名 `'issues'` で override） |
| レスポンス形式 | JSON / XML 両対応 |

### 追加されるフィールド

- `reply_count`: ネストオブジェクト
  - `count`: `issue.reply_count_value`（担当者変更回数、reply_count 機能と同じ値）
  - `items`: 担当者の遷移（初期担当者 → 変更ごとの新担当者）の `{ id, name }` 配列。担当者なしは `id=0, name=''`、削除済み等の無効ユーザーは `id=元のID, name=''`。変更履歴がないチケットは現在の担当者 1 件
- `children_count`: ネストオブジェクト
  - `count`: `issue.children_count_value`（直下の子チケット数、children_count 機能と同じ値）
  - `items`: 子チケットの `{ id, name=件名 }` 配列（先頭 10 件、`MAX_ITEMS` キャップ、visible スコープ適用）
- `last_updated_by`: `{ id, name }`（`issue.last_updated_by`＝可視ジャーナルの最新更新者）。更新履歴が無い、または最新ジャーナルの投稿者が実在しない場合は **プロパティごと省略**（nullable ネストの標準パターン）
- `last_notes`: 文字列（`issue.last_notes`＝可視の最新コメント本文）。コメントが無い場合は空文字 `""`（単純文字列なので常に出力する）
- `spent_hours_by_user`: `{ user_id, hours }` の配列（`issue.spent_hours_by_user_items`）。チケットとその子孫（subtree）に紐づく作業時間を担当者ごとに合計したもの。集計範囲は `total_spent_hours` と同じ subtree（nested set の `root_id` 一致 + `lft`/`rgt` 包含）で、`hours` の総和は `total_spent_hours` に一致する。可視な作業時間のみ対象（`TimeEntry.visible`）で self-guard のため権限ガードは付けず常に出力（作業時間ゼロは空配列）

---

## 1. Runner テスト

### [1-1] Controller が IssuesController を継承している

**確認方法:**
```ruby
puts IssuesWithExtrasController.ancestors.map(&:name).include?('IssuesController')
```

**期待結果:** `true`

### [1-2] Route が登録されている

**確認方法:**
```ruby
routes = Rails.application.routes.routes.map do |r|
  { verb: r.verb, path: r.path.spec.to_s, controller: r.defaults[:controller], action: r.defaults[:action] }
end
show_route = routes.find { |r| r[:controller] == 'issues_with_extras' && r[:action] == 'show' }
index_route = routes.find { |r| r[:controller] == 'issues_with_extras' && r[:action] == 'index' }
puts "show: #{show_route.inspect}"
puts "index: #{index_route.inspect}"
```

**期待結果:**
- `show: {verb: 'GET', path: '/issues_with_extras/:id(.:format)', ...}` が存在
- `index: {verb: 'GET', path: '/issues_with_extras(.:format)', ...}` が存在

### [1-3] View ファイルが存在する

**確認方法:**
```ruby
plugin_dir = Redmine::Plugin.registered_plugins[:redmine_studio_plugin].directory
show_view = File.join(plugin_dir, 'app/views/issues_with_extras/show.api.rsb')
index_view = File.join(plugin_dir, 'app/views/issues_with_extras/index.api.rsb')
puts "show_exists: #{File.exist?(show_view)}"
puts "index_exists: #{File.exist?(index_view)}"
```

**期待結果:**
- `show_exists: true`
- `index_exists: true`

---

## 2. HTTP テスト

**実行方法:**
PowerShell 7 で各エンドポイントに GET し、Basic 認証（管理者）で取得する。
`-Authentication Basic` で最初から認証情報を送る（付けないと、匿名で読める標準の `/issues.json` は匿名のまま返り、非公開プロジェクトのチケットが見えない）。
`{BaseUrl}`・`{Username}`・`{Password}`（Redmine 管理者）は実行環境から注入する（プレースホルダの契約は `test/README.md`）。
一覧（index）の試験は、用意で作ったプロジェクト（`project_id={ProjectId}`）に絞って、前からあるチケットに左右されないようにする。

**用意（HTTP テストの前に 1 回）:**
試験に使うデータを Runner で作る（前回の残りがあれば先に消す）。
- 非公開のプロジェクトと、そのメンバーのユーザー 2 人（担当者になれるロール）
- 更新履歴のあるチケット（`{IssueId}`）: 担当者 なし → ユーザー A → ユーザー B に 2 回変え、最後にユーザー B がコメント（`IWE_note`）を書く
- 更新履歴のないチケット（`{NoJournalIssueId}`）
- 子チケットを 11 件持つ親チケット（`{ParentIssueId}`）
- 作業時間のある親チケット（`{SpentParentId}`）: 親にユーザー A の 1.5 時間、子にユーザー B の 2.0 時間
- 終了したチケット 1 件（プロジェクトのチケットは全部で 17 件、そのうち未完了が 16 件）

最後の行の値を、各試験の `{ProjectId}`・`{IssueId}`・`{NoJournalIssueId}`・`{ParentIssueId}`・`{SpentParentId}`・`{UserAId}`・`{UserBId}`・`{UserBName}` に入れる。

```ruby
admin = User.find(1)
User.current = admin
# 前回の残りを消す
Project.where('identifier LIKE ?', 'iwe-%').order(lft: :desc).each(&:destroy)
User.where('login LIKE ?', 'iwe_%').each(&:destroy)
Role.where('name LIKE ?', 'IWE_%').each(&:destroy)
sfx = SecureRandom.hex(3)
tracker = Tracker.order(:position).first
open_status = IssueStatus.where(is_closed: false).order(:position).first
closed_status = IssueStatus.where(is_closed: true).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
activity = TimeEntryActivity.active.first || TimeEntryActivity.create!(name: "IWE_#{sfx}", active: true)
role = Role.create!(name: "IWE_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues, :log_time, :view_time_entries], assignable: true)
pr = Project.new(name: "IWE_#{sfx}", identifier: "iwe-#{sfx}", is_public: false)
pr.enabled_module_names = %w[issue_tracking time_tracking]
pr.trackers = [tracker]
pr.save!
mk_user = ->(name) {
  u = User.new(login: "iwe_#{name}_#{sfx}", firstname: 'IWE', lastname: name, mail: "iwe_#{name}_#{sfx}@example.com", status: User::STATUS_ACTIVE)
  u.password = u.password_confirmation = SecureRandom.hex(8)
  u.save!
  Member.create!(principal: u, project: pr, roles: [role])
  u
}
ua = mk_user.call('a')
ub = mk_user.call('b')
mk = ->(name, parent = nil, status = open_status) {
  Issue.create!(project: pr, tracker: tracker, subject: "IWE_#{name}_#{sfx}", author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
# 更新履歴のあるチケット（担当者の変更 2 回と、最後にコメント）
issue = mk.call('updated')
[ua, ub].each do |u|
  issue = Issue.find(issue.id)
  issue.init_journal(admin)
  issue.assigned_to = u
  issue.save!
end
issue = Issue.find(issue.id)
issue.init_journal(ub, 'IWE_note')
issue.save!
no_journal = mk.call('nojournal')
parent = mk.call('parent')
11.times { |i| mk.call("child#{i + 1}", parent) }
spent_parent = mk.call('spent')
spent_child = mk.call('spentchild', spent_parent)
TimeEntry.create!(project: pr, issue: spent_parent, user: ua, author: ua, hours: 1.5, spent_on: Date.today, activity: activity)
TimeEntry.create!(project: pr, issue: spent_child, user: ub, author: ub, hours: 2.0, spent_on: Date.today, activity: activity)
mk.call('closed', nil, closed_status)
puts({ ProjectId: pr.id, IssueId: issue.id, NoJournalIssueId: no_journal.id, ParentIssueId: parent.id, SpentParentId: spent_parent.id,
       UserAId: ua.id, UserBId: ub.id, UserBName: ub.name }.to_json)
```

**後片付け（HTTP テストのあとに 1 回）:**

```ruby
User.current = User.find(1)
Project.where('identifier LIKE ?', 'iwe-%').order(lft: :desc).each(&:destroy)
User.where('login LIKE ?', 'iwe_%').each(&:destroy)
Role.where('name LIKE ?', 'IWE_%').each(&:destroy)
TimeEntryActivity.where('name LIKE ?', 'IWE_%').each(&:destroy)
puts 'cleaned'
```

### [2-1] GET /issues_with_extras/:id.json で reply_count / children_count が返る

用意で作ったチケット（`{IssueId}`）を使う。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras/{IssueId}.json' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
Write-Host "has_reply_count: $($r.issue.PSObject.Properties.Name -contains 'reply_count')"
Write-Host "has_children_count: $($r.issue.PSObject.Properties.Name -contains 'children_count')"
Write-Host "reply_count_count: $($r.issue.reply_count.count)"
Write-Host "reply_items_is_array: $($r.issue.reply_count.items -is [array] -or $r.issue.reply_count.items -eq $null -or $r.issue.reply_count.items.Count -ge 0)"
Write-Host "children_count_count: $($r.issue.children_count.count)"
```

**期待結果:**
- `has_reply_count: True`
- `has_children_count: True`
- `reply_count_count: 2`（`count` プロパティ。用意で担当者を 2 回変えた）
- `reply_items_is_array: True`（`items` プロパティが配列）
- `children_count_count: 0`

### [2-2] GET /issues_with_extras/:id.xml で reply_count / children_count が返る

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues_with_extras/{IssueId}.xml' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
Write-Host "reply_count_matched: $($response.Content -match '<reply_count><count>\d+</count><items type=\"array\">')"
Write-Host "children_count_matched: $($response.Content -match '<children_count><count>\d+</count><items type=\"array\">')"
```

**期待結果:**
- `reply_count_matched: True`（`<reply_count><count>N</count><items type="array">` のネスト構造）
- `children_count_matched: True`

### [2-3] GET /issues_with_extras.json で issues 配列に reply_count / children_count が返る

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras.json?project_id={ProjectId}&limit=3' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
Write-Host "issues_count: $($r.issues.Count)"
Write-Host "first_has_reply_count: $($r.issues[0].PSObject.Properties.Name -contains 'reply_count')"
Write-Host "first_has_children_count: $($r.issues[0].PSObject.Properties.Name -contains 'children_count')"
```

**期待結果:**
- `issues_count: 3`
- `first_has_reply_count: True`
- `first_has_children_count: True`

### [2-4] GET /issues_with_extras.xml で issue 要素に reply_count / children_count が返る

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues_with_extras.xml?project_id={ProjectId}&limit=3' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
Write-Host "reply_count_matched: $($response.Content -match '<reply_count><count>\d+</count><items type=\"array\">')"
Write-Host "children_count_matched: $($response.Content -match '<children_count><count>\d+</count><items type=\"array\">')"
```

**期待結果:**
- `reply_count_matched: True`（ネスト構造）
- `children_count_matched: True`

### [2-5] 標準 GET /issues/:id.json では reply_count / children_count が返らない（副作用ゼロ確認）

Plugin が標準エンドポイントを変更していないことを確認する回帰テスト。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues/{IssueId}.json' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
Write-Host "has_reply_count: $($r.issue.PSObject.Properties.Name -contains 'reply_count')"
Write-Host "has_children_count: $($r.issue.PSObject.Properties.Name -contains 'children_count')"
```

**期待結果:**
- `has_reply_count: False`
- `has_children_count: False`

### [2-6] 標準 GET /issues.json では reply_count / children_count が返らない（副作用ゼロ確認）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues.json?project_id={ProjectId}&limit=1' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
Write-Host "first_has_reply_count: $($r.issues[0].PSObject.Properties.Name -contains 'reply_count')"
Write-Host "first_has_children_count: $($r.issues[0].PSObject.Properties.Name -contains 'children_count')"
```

**期待結果:**
- `first_has_reply_count: False`
- `first_has_children_count: False`

### [2-7] 未認証（匿名）は 401 で拒否される（標準 /issues より厳格）

追加 API は本体の `login_required` 設定に関わらず一律ログイン必須（`before_action :require_login`）。標準 `/issues/:id.json` は `login_required` 無効環境では公開チケットを匿名に 200 で返すが、本エンドポイントは匿名を常に 401 で拒否する（＝標準よりも厳格）。

**確認方法:**
```powershell
# 認証ヘッダなしで、標準 /issues/{ID}.json と /issues_with_extras/{ID}.json のステータスコードを比較
$stdStatus = 0
try { $r = Invoke-WebRequest -Uri '{BaseUrl}/issues/{IssueId}.json' -UseBasicParsing -ErrorAction Stop; $stdStatus = $r.StatusCode } catch { $stdStatus = $_.Exception.Response.StatusCode.value__ }

$extStatus = 0
try { $r = Invoke-WebRequest -Uri '{BaseUrl}/issues_with_extras/{IssueId}.json' -UseBasicParsing -ErrorAction Stop; $extStatus = $r.StatusCode } catch { $extStatus = $_.Exception.Response.StatusCode.value__ }

Write-Host "std: $stdStatus / ext: $extStatus"
```

**期待結果:**
- `ext: 401`（本エンドポイントは匿名を常に 401 で拒否）
- 参考: `login_required` 無効環境では公開チケットに対し `std: 200` となり、本エンドポイントが標準より厳格であることが分かる（`std` の値は本体設定・チケットの公開/非公開により変わるため、判定は `ext` の 401 のみを対象とする）

### [2-8] Issue API レスポンスの他フィールドが Redmine 本体と同一（等価性検証、show）

Redmine 本体の `issues/show.api.rsb` の全 API フィールドが `issues_with_extras/show.api.rsb` にも含まれることを確認する回帰テスト。本体側の view 更新への追従漏れを検知する。

**確認方法:**

`GET /issues/{IssueId}.json?include=journals,attachments,relations,children,watchers,allowed_statuses,changesets` と `GET /issues_with_extras/{IssueId}.json?include=journals,attachments,relations,children,watchers,allowed_statuses,changesets` を Runner または PowerShell で取得し、issue 直下のキーを比較する。

```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$include = 'journals,attachments,relations,children,watchers,allowed_statuses,changesets'
$std = Invoke-RestMethod -Uri "{BaseUrl}/issues/{IssueId}.json?include=$include" -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
$ext = Invoke-RestMethod -Uri "{BaseUrl}/issues_with_extras/{IssueId}.json?include=$include" -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication

$stdKeys = $std.issue.PSObject.Properties.Name | Sort-Object
$extKeys = $ext.issue.PSObject.Properties.Name | Sort-Object

$onlyInExt = $extKeys | Where-Object { $stdKeys -notcontains $_ }
$onlyInStd = $stdKeys | Where-Object { $extKeys -notcontains $_ }
Write-Host "only_in_extras: $($onlyInExt -join ',')"
Write-Host "only_in_std: $($onlyInStd -join ',')"
```

**期待結果（`{IssueId}` は更新履歴のあるチケット）:**
- `only_in_extras: children_count,last_notes,last_updated_by,reply_count,spent_hours_by_user`（追加した 5 フィールドのみ差分）
- `only_in_std:` (空)

※ `last_updated_by` は最終更新者が居るときだけ出力される。更新履歴が無いチケット（`{NoJournalIssueId}`）を使うと `last_updated_by` が差分に現れず 4 フィールドになる。`spent_hours_by_user` は作業時間ゼロでも空配列で常に出力される。

### [2-9] Issue API レスポンスの他フィールドが Redmine 本体と同一（等価性検証、index）

show と同様に、`/issues.json` と `/issues_with_extras.json` の issue 配列各要素のキーを比較する。更新履歴のある `{IssueId}` に絞って取る。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$std = Invoke-RestMethod -Uri '{BaseUrl}/issues.json?issue_id={IssueId}' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
$ext = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras.json?issue_id={IssueId}' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication

$stdKeys = $std.issues[0].PSObject.Properties.Name | Sort-Object
$extKeys = $ext.issues[0].PSObject.Properties.Name | Sort-Object

$onlyInExt = $extKeys | Where-Object { $stdKeys -notcontains $_ }
$onlyInStd = $stdKeys | Where-Object { $extKeys -notcontains $_ }
Write-Host "only_in_extras: $($onlyInExt -join ',')"
Write-Host "only_in_std: $($onlyInStd -join ',')"
```

**期待結果:**
- `only_in_extras: children_count,last_notes,last_updated_by,reply_count,spent_hours_by_user`（追加した 5 フィールドのみ差分。`{IssueId}` は更新履歴があるので `last_updated_by` も出る）
- `only_in_std:` (空)

### [2-10] pagination が動作する

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras.json?project_id={ProjectId}&limit=2&offset=0' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
Write-Host "issues_count: $($r.issues.Count)"
Write-Host "total_count: $($r.total_count)"
Write-Host "offset: $($r.offset)"
Write-Host "limit: $($r.limit)"
```

**期待結果:**
- `issues_count: 2`
- `total_count: 16`（`status_id` を付けないと未完了だけが対象。用意のチケット 17 件のうち未完了は 16 件）
- `offset: 0`
- `limit: 2`

### [2-11] filter が動作する（status_id）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras.json?project_id={ProjectId}&status_id=open&limit=3' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
Write-Host "issues_count: $($r.issues.Count)"
$allOpen = $true
foreach ($i in $r.issues) {
  if ($i.status.is_closed) { $allOpen = $false; break }
}
Write-Host "all_open: $allOpen"
```

**期待結果:**
- `issues_count: 3`
- `all_open: True`

### [2-12] 存在しない ID で 404

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
try {
  $response = Invoke-WebRequest -Uri '{BaseUrl}/issues_with_extras/9999999.json' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
  Write-Host "status: $($response.StatusCode)"
} catch {
  Write-Host "status: $($_.Exception.Response.StatusCode.value__)"
}
```

**期待結果:** `status: 404`

### [2-13] reply_count.items が担当者の遷移を表す

用意で担当者を なし → ユーザー A → ユーザー B と 2 回変えたチケット（`{IssueId}`）と、変更のないチケット（`{NoJournalIssueId}`）を使う。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras/{IssueId}.json' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
$rc = $r.issue.reply_count
Write-Host "count: $($rc.count)"
Write-Host "items_count: $($rc.items.Count)"
Write-Host "chain: $($rc.items | ForEach-Object { "$($_.id):$($_.name)" } | Join-String -Separator ' -> ')"
Write-Host "chain_ids_ok: $(($rc.items.id -join ',') -eq '0,{UserAId},{UserBId}')"
$n = (Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras/{NoJournalIssueId}.json' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication).issue.reply_count
Write-Host "no_change: count=$($n.count) items=$($n.items.Count) first=$($n.items[0].id):'$($n.items[0].name)'"
```

**期待結果:**
- `count: 2`、`items_count: 3`（= `count + 1`。初期担当者 + 変更ごとの新担当者）
- `chain` が `0: -> {UserAId}:IWE a -> {UserBId}:IWE b` の形（担当者なし → A → B。各要素に `id` と `name` がある）、`chain_ids_ok: True`
- 担当者変更がないチケットでは `no_change: count=0 items=1 first=0:''`（`items` は現在の担当者 1 件。担当者未設定なので `id=0, name=''`）

### [2-14] children_count.items が子チケット一覧（最大 10 件）を表す

用意で子チケットを 11 件作った親チケット（`{ParentIssueId}`）を使う。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras/{ParentIssueId}.json' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
$cc = $r.issue.children_count
Write-Host "count: $($cc.count)"
Write-Host "items_count: $($cc.items.Count)"
Write-Host "first_item: id=$($cc.items[0].id) name=$($cc.items[0].name)"
Write-Host "capped: $($cc.items.Count -le 10)"
```

**期待結果:**
- `count: 11`（直下の子チケット数、visible スコープ適用）
- `items_count: 10`、`capped: True`（`items` は最大 10 件。`count` が 10 超でも `items` は 10 件まで）
- `items` の各要素は `id` = 子チケット ID、`name` = 件名（省略なしの全文。`IWE_child1_…` の形）

### [2-15] show で last_updated_by / last_notes が返る

用意で更新履歴を作ったチケット（`{IssueId}`。最後の更新者はユーザー B、最新コメントは `IWE_note`）を使う。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras/{IssueId}.json' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
Write-Host "has_last_updated_by: $($r.issue.PSObject.Properties.Name -contains 'last_updated_by')"
Write-Host "last_updated_by: id=$($r.issue.last_updated_by.id) name=$($r.issue.last_updated_by.name)"
Write-Host "has_last_notes: $($r.issue.PSObject.Properties.Name -contains 'last_notes')"
Write-Host "last_notes: $($r.issue.last_notes)"
Write-Host "match: $($r.issue.last_updated_by.id -eq {UserBId} -and $r.issue.last_updated_by.name -eq '{UserBName}' -and $r.issue.last_notes -eq 'IWE_note')"
```

**期待結果:**
- `has_last_updated_by: True`（最終更新者が居るチケットの場合。id / name を持つ）
- `has_last_notes: True`（コメントが無いチケットでも空文字で必ず出力される）
- `last_updated_by` が最終更新者（ユーザー B）、`last_notes: IWE_note`（最新コメント本文）。`match: True`

### [2-16] index で last_updated_by / last_notes が返る（プリロード経路）

デフォルトの並び順に依存しないよう、用意で作った更新履歴ありの `{IssueId}` と履歴なしの `{NoJournalIssueId}` を `issue_id` フィルタで明示して一覧取得し、プリロード経路（`load_visible_last_updated_by` / `load_visible_last_notes`）が正しく値を配ることを確認する。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras.json?issue_id={IssueId},{NoJournalIssueId}' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
foreach ($i in $r.issues) {
  $hasLub = $i.PSObject.Properties.Name -contains 'last_updated_by'
  Write-Host "#$($i.id) has_last_updated_by=$hasLub last_notes='$($i.last_notes)'"
}
```

**期待結果:**
- `last_notes` は全 issue で出力される（コメント無しは空文字）
- `#{IssueId} has_last_updated_by=True last_notes='IWE_note'`
- `#{NoJournalIssueId} has_last_updated_by=False last_notes=''`（更新履歴が無いので `last_updated_by` は省略）
- 値が show（[2-15]）と一致する = プリロード経路と単一取得経路で同値

### [2-17] 標準 GET /issues では last_updated_by / last_notes が返らない（副作用ゼロ確認）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues/{IssueId}.json' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
Write-Host "has_last_updated_by: $($r.issue.PSObject.Properties.Name -contains 'last_updated_by')"
Write-Host "has_last_notes: $($r.issue.PSObject.Properties.Name -contains 'last_notes')"
```

**期待結果:**
- `has_last_updated_by: False`
- `has_last_notes: False`

### [2-18] spent_hours_by_user が担当者ごとの subtree 作業時間を表す

用意で作業時間を登録した親チケット（`{SpentParentId}`。親にユーザー A の 1.5 時間、子にユーザー B の 2.0 時間）を使う。作業時間のないチケット（`{NoJournalIssueId}`）では空配列になることも確かめる。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras/{SpentParentId}.json' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
$sh = $r.issue.spent_hours_by_user
$sum = ($sh | Measure-Object -Property hours -Sum).Sum
Write-Host "has_field: $($r.issue.PSObject.Properties.Name -contains 'spent_hours_by_user')"
Write-Host "entries: $($sh | ForEach-Object { "$($_.user_id):$($_.hours)" } | Join-String -Separator ',')"
Write-Host "sum: $sum / total_spent_hours: $($r.issue.total_spent_hours) / match: $($sum -eq $r.issue.total_spent_hours)"
$none = (Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras/{NoJournalIssueId}.json' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication).issue
Write-Host "empty: has_field=$($none.PSObject.Properties.Name -contains 'spent_hours_by_user') count=$(@($none.spent_hours_by_user).Count)"
```

**期待結果:**
- `has_field: True`（配列で常に出力される）
- `entries` が `{UserAId}:1.5` と `{UserBId}:2` の 2 件（各要素は `user_id` = ユーザー ID、`hours` = そのユーザーの subtree 合計時間）
- `sum: 3.5 / total_spent_hours: 3.5 / match: True`（`hours` の総和 = `total_spent_hours`。subtree 集計が正しい）
- `empty: has_field=True count=0`（作業時間が 1 件も無いチケットでは空配列 `[]`）

### [2-19] 標準 GET /issues では spent_hours_by_user が返らない（副作用ゼロ確認）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues/{IssueId}.json' -Credential $cred -Authentication Basic -AllowUnencryptedAuthentication
Write-Host "has_spent_hours_by_user: $($r.issue.PSObject.Properties.Name -contains 'spent_hours_by_user')"
```

**期待結果:**
- `has_spent_hours_by_user: False`

---

## 3. ブラウザテスト

該当なし（すべて Runner / HTTP テストでカバー済み）
