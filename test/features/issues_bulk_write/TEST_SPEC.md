# Issues Bulk Write API テスト仕様書

## 概要

`POST /issues/bulk_write` のテスト仕様。複数の Issue の作成/更新を 1 リクエストで完結させるエンドポイント。

Redmine 本体の POST /issues.json は notes をサポートせず、また 1 リクエスト = 1 Issue のため、大量作成/更新のシナリオで認証・セッション・DB 接続のオーバヘッドが N 倍になる問題を解消するために追加された。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| Controller | `IssuesBulkWriteController` |
| ファイル | `app/controllers/issues_bulk_write_controller.rb` |
| ルーティング | `POST /issues/bulk_write` |
| View ファイル | `app/views/issues_bulk_write/create.api.rsb` |
| 認証 | API キー必須（`accept_api_auth :create`） |
| レスポンス形式 | JSON / XML 両対応 |

### リクエスト

```json
{
  "operations": [
    { "op": "create", "issue": { "project_id": 1, "tracker_id": 2, "subject": "...", "notes": "..." } },
    { "op": "update", "id": 123, "issue": { "subject": "...", "notes": "..." } }
  ]
}
```

### レスポンス (200)

```json
{
  "results": [
    { "index": 0, "op": "create", "success": true, "issue": { "id": 100, ... } },
    { "index": 1, "op": "update", "success": false, "errors": ["Subject cannot be blank"] }
  ]
}
```

### Redmine 本体との差分

| 項目 | 本体 | bulk_write |
|------|------|-----------|
| `notes` on create | silent no-op (init_journal 未呼び出し) | init_journal で明示処理、journal に載る |
| Response | 単一 issue | operations 配列に対応した results 配列 |
| Partial success | N/A (1 issue のみ) | 各 op 独立、成功/失敗を個別に返す |
| 権限チェック | `authorize` before_action | 明示的な `User.current.allowed_to?` |
| 主要処理 | 標準 `IssuesController#create/#update` | 上記を踏襲、time_entry/attachments 未サポート |

### 未サポート機能 (v1)

- `time_entry`（1 API 呼び出しで時間記録も同時作成）
- `attachments` / `uploads`
- `copy_from`（Issue コピー）
- `include=xxx` パラメータ（response の追加フィールド）

## 環境パラメータ

接続先（BaseUrl）と管理者の認証情報は実行環境から注入する（プレースホルダの契約は `test/README.md`）。HTTP 例の相対パスは BaseUrl に続けて実行する。

## テスト前提条件

### テストデータ（HTTP テストの用意で作る）

| データ | 用途 |
|-------|------|
| プロジェクト `ibw-spec-<印>`（JSON の `ProjectId`） | テスト用プロジェクト |
| トラッカー: 既存の並び順の先頭（`TrackerId`） | 既存を使用 |
| カスタムフィールド `IBW_Spec_CF_String_<印>` (issue, string。`CfStringId`) | Redmine 標準 CF |
| カスタムフィールド `IBW_Spec_CF_List_<印>` (issue, list, values: ["A", "B", "C"]。`CfListId`) | list 型 CF |
| ユーザー writer（用意で作るロール: 閲覧・追加・編集・注記。API キー `WriterKey`） | 権限あり |
| ユーザー viewer（用意で作るロール: 閲覧だけ。API キー `ViewerKey`） | 権限なし |
| 既存 Issue #X・#Y・#Z・#W・#P・#Q（`IssueX` など） | update 系・等価性の試験 |

`<印>` は `SecureRandom.hex(3)` の 6 桁。HTTP テストの前に用意を流し、あとで後片付けを流す（その場で作って消す）。

## 1. Runner テスト

### [1-1] コントローラクラスの存在確認

**確認方法:**
```ruby
loc = IssuesBulkWriteController.instance_method(:create).source_location
puts loc.first.include?('plugins/redmine_studio_plugin/app/controllers/issues_bulk_write_controller.rb') ? 'PASS' : "FAIL: #{loc.inspect}"
```

**期待結果:**
- 定義元パスが `plugins/redmine_studio_plugin/app/controllers/issues_bulk_write_controller.rb` を含む（`PASS`）

### [1-2] ルーティングの登録確認

**確認方法:**
```ruby
r = Rails.application.routes.recognize_path('/issues/bulk_write', method: :post)
puts r[:controller] == 'issues_bulk_write' && r[:action] == 'create' ? 'PASS' : "FAIL: #{r.inspect}"
```

**期待結果:**
- `{controller: "issues_bulk_write", action: "create"}` が返る（`PASS`）

### [1-3] View ファイルの存在確認

**確認方法:**
```ruby
puts File.exist?(Rails.root.join('plugins', 'redmine_studio_plugin', 'app', 'views', 'issues_bulk_write', 'create.api.rsb')) ? 'PASS' : 'FAIL'
```

**期待結果:**
- true（`PASS`）

## 2. HTTP テスト

**実行方法:** 下の用意を流して JSON を受け取り、各試験のブロックの `{ProjectId}`・`{WriterKey}` などを JSON の値に、`{BaseUrl}`・`{ApiKey}`（管理者）を実行環境の値にして流す。チケットの中身の確認は管理者の API キーで `GET /issues/<id>.json?include=journals` を見る。最後に後片付けを流す。

**用意（HTTP テストの前に 1 回）:** 前回の残りを消してから、上の「テストデータ」を作る。最後の行に JSON を出す。

```ruby
Project.where('identifier LIKE ?', 'ibw-spec-%').order(id: :desc).each(&:destroy)
User.where('login LIKE ?', 'ibw_spec_%').each(&:destroy)
Role.where('name LIKE ?', 'IBW_Spec_%').each(&:destroy)
IssueCustomField.where('name LIKE ?', 'IBW_Spec_%').each(&:destroy)
sfx = SecureRandom.hex(3)
admin = User.find(1)
tracker = Tracker.sorted.first
priority = IssuePriority.default || IssuePriority.active.first
prj = Project.new(name: "IBW_Spec_#{sfx}", identifier: "ibw-spec-#{sfx}", is_public: false)
prj.enabled_module_names = %w[issue_tracking]
prj.trackers = [tracker]
prj.save!
cf_s = IssueCustomField.create!(name: "IBW_Spec_CF_String_#{sfx}", field_format: 'string', is_for_all: false, visible: true, projects: [prj], trackers: [tracker])
cf_l = IssueCustomField.create!(name: "IBW_Spec_CF_List_#{sfx}", field_format: 'list', possible_values: %w[A B C], is_for_all: false, visible: true, projects: [prj], trackers: [tracker])
w_role = Role.create!(name: "IBW_Spec_Writer_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues, :add_issue_notes], assignable: true)
v_role = Role.create!(name: "IBW_Spec_Viewer_#{sfx}", permissions: [:view_issues])
# エラー文を英語で比べるので、言語は en にする
mk_user = ->(name, role) {
  u = User.new(login: "ibw_spec_#{name}_#{sfx}", firstname: 'IBW', lastname: name, mail: "ibw_spec_#{name}_#{sfx}@example.com", status: User::STATUS_ACTIVE, language: 'en')
  u.password = u.password_confirmation = "Pw-#{sfx}-x9Z"
  u.save!
  Member.create!(principal: u, project: prj, roles: [role])
  [u, Token.create!(user: u, action: 'api').value]
}
writer, writer_key = mk_user.call('writer', w_role)
viewer, viewer_key = mk_user.call('viewer', v_role)
# 更新の試験で使うチケット（試験ごとに別のもの）
mk = ->(name, attrs = {}) { Issue.create!({ project: prj, tracker: tracker, subject: "BulkWrite_#{name}_#{sfx}", author: writer, priority: priority }.merge(attrs)).id }
puts({ Sfx: sfx, ProjectId: prj.id, TrackerId: tracker.id, StatusId: tracker.default_status.id, PriorityId: priority.id,
       CfStringId: cf_s.id, CfListId: cf_l.id, WriterId: writer.id, WriterKey: writer_key, ViewerKey: viewer_key,
       IssueX: mk.call('Original'), IssueY: mk.call('Y'), IssueZ: mk.call('Z', assigned_to: writer), IssueW: mk.call('W'),
       IssueP: mk.call('E2_Orig'), IssueQ: mk.call('E2_Orig') }.to_json)
```

**後片付け（HTTP テストのあとに 1 回）:**

```ruby
Project.where('identifier LIKE ?', 'ibw-spec-%').order(id: :desc).each(&:destroy)
User.where('login LIKE ?', 'ibw_spec_%').each(&:destroy)
Role.where('name LIKE ?', 'IBW_Spec_%').each(&:destroy)
IssueCustomField.where('name LIKE ?', 'IBW_Spec_%').each(&:destroy)
puts 'cleanup: ok'
```

### 2.A create 系

#### [2-A-1] 単一 create (最小構成)

書き手（用意で作る writer。API キー `{WriterKey}`）で送る。

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"create","issue":{"project_id":{ProjectId},"subject":"BulkWrite_2A1_Simple"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
"[2-A-1] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $true -and $x.op -eq 'create' -and $x.issue.id -is [long] -and $x.issue.subject -eq 'BulkWrite_2A1_Simple' -and $x.issue.tracker.id -eq {TrackerId} -and $x.issue.status.id -eq {StatusId} -and $x.issue.author.id -eq {WriterId}) { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-A-1] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == true`
- `results[0].op == "create"`
- `results[0].issue.id` が数値で存在
- `results[0].issue.subject == "BulkWrite_2A1_Simple"`
- `results[0].issue.tracker.id` が正常に設定されている（デフォルト tracker）
- `results[0].issue.status.id` が正常に設定されている（デフォルト status）
- `results[0].issue.author.id` が 書き手 の ID

#### [2-A-2] create with notes

```powershell
function Get-Issue($id) { (Invoke-RestMethod -Uri "{BaseUrl}/issues/$id.json?include=journals" -Headers @{ 'X-Redmine-API-Key' = '{ApiKey}' }).issue }
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"create","issue":{"project_id":{ProjectId},"subject":"BulkWrite_2A2_Notes","notes":"初期コメント"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
$js = @((Get-Issue $x.issue.id).journals)
"[2-A-2] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $true -and $js.Count -eq 1 -and $js[0].notes -eq '初期コメント') { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-A-2] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == true`
- 作成された Issue に **journal が 1 件存在**し、notes が「初期コメント」
- 検証は Runner で `Issue.find(id).journals.count == 1 && journals.first.notes == "初期コメント"`

#### [2-A-3] create with notes (空文字)

```powershell
function Get-Issue($id) { (Invoke-RestMethod -Uri "{BaseUrl}/issues/$id.json?include=journals" -Headers @{ 'X-Redmine-API-Key' = '{ApiKey}' }).issue }
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"create","issue":{"project_id":{ProjectId},"subject":"BulkWrite_2A3_EmptyNotes","notes":""}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
$js = @((Get-Issue $x.issue.id).journals)
"[2-A-3] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $true -and $js.Count -eq 0) { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-A-3] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == true`
- 作成された Issue に **journal が 0 件**（空 notes は保存されない、本体の journal.rb line 105 と整合）

#### [2-A-4] create with custom fields

`<cf_string_id>`・`<cf_list_id>` は用意で作る文字列・リストのカスタムフィールド（`{CfStringId}`・`{CfListId}`）。

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"create","issue":{"project_id":{ProjectId},"subject":"BulkWrite_2A4_CF","custom_field_values":{"{CfStringId}":"CFValue1","{CfListId}":"A"}}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
$cf = @($x.issue.custom_fields | Where-Object { $_.id -in {CfStringId}, {CfListId} } | ForEach-Object { "$($_.id)=$($_.value)" })
"[2-A-4] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $true -and ($cf -join ',') -eq '{CfStringId}=CFValue1,{CfListId}=A') { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-A-4] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == true`
- `results[0].issue.custom_fields` に 2 個のエントリが含まれる（値: "CFValue1", "A"）

#### [2-A-5] create with assigned_to_id: "me"

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"create","issue":{"project_id":{ProjectId},"subject":"BulkWrite_2A5_Me","assigned_to_id":"me"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
"[2-A-5] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $true -and $x.issue.assigned_to.id -eq {WriterId}) { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-A-5] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == true`
- `results[0].issue.assigned_to.id == <書き手の user id（`{WriterId}`）>`（"me" → current user への変換）

#### [2-A-6] create: project_id 未指定

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"create","issue":{"subject":"No Project"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
"[2-A-6] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $false -and ($x.errors -join ' ') -match 'project not found or not visible') { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-A-6] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "project not found or not visible" を含む

#### [2-A-7] create: 存在しない project_id

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"create","issue":{"project_id":99999,"subject":"Ghost"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
"[2-A-7] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $false -and ($x.errors -join ' ') -match 'project not found or not visible') { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-A-7] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "project not found or not visible" を含む

#### [2-A-8] create: 権限なし (Reporter で add_issues 不可)

閲覧者（用意で作る viewer。`view_issues` だけ。API キー `{ViewerKey}`）で送る。

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{ViewerKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"create","issue":{"project_id":{ProjectId},"subject":"BulkWrite_2A8_NoPerm"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
"[2-A-8] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $false -and ($x.errors -join ' ') -match 'forbidden|add_issues permission') { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-A-8] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "forbidden" または "add_issues permission" を含む

#### [2-A-9] create: validation error (subject 空)

書き手の言語は用意で en にしてある（エラー文の属性名を英語で比べる）。

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"create","issue":{"project_id":{ProjectId},"subject":""}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
"[2-A-9] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $false -and @($x.errors | Where-Object { $_ -like 'Subject*' }).Count -gt 0) { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-A-9] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "Subject" で始まるメッセージを含む（ロケール非依存: 属性名のみ確認）

### 2.B update 系

#### [2-B-1] 単一 update (subject 変更)

既存 Issue #X は用意で作る（`{IssueX}`、subject: `BulkWrite_Original_<印>`）。

```powershell
function Get-Issue($id) { (Invoke-RestMethod -Uri "{BaseUrl}/issues/$id.json?include=journals" -Headers @{ 'X-Redmine-API-Key' = '{ApiKey}' }).issue }
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"update","id":{IssueX},"issue":{"subject":"BulkWrite_2B1_Updated"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
$i = Get-Issue {IssueX}; $js = @($i.journals)
"[2-B-1] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $true -and $i.subject -eq 'BulkWrite_2B1_Updated' -and $js.Count -eq 1 -and -not $js[0].notes -and @($js[0].details | Where-Object { $_.name -eq 'subject' }).Count -eq 1) { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-B-1] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == true`
- Issue #X の subject が "BulkWrite_2B1_Updated" に変更されている
- journal が 1 件追加され、subject の変更履歴を含む（notes は空）

#### [2-B-2] update with notes

既存 Issue #Y は用意で作る（`{IssueY}`）。

```powershell
function Get-Issue($id) { (Invoke-RestMethod -Uri "{BaseUrl}/issues/$id.json?include=journals" -Headers @{ 'X-Redmine-API-Key' = '{ApiKey}' }).issue }
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"update","id":{IssueY},"issue":{"notes":"コメント追加"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
$js = @((Get-Issue {IssueY}).journals)
"[2-B-2] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $true -and $js.Count -eq 1 -and $js[0].notes -eq 'コメント追加') { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-B-2] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == true`
- Issue #Y に journal が 1 件追加され、notes が「コメント追加」

#### [2-B-3] update: id 未指定

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"update","issue":{"subject":"no id"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
"[2-B-3] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $false -and ($x.errors -join ' ') -match 'id is required') { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-B-3] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "id is required" を含む

#### [2-B-4] update: 存在しない id

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"update","id":99999,"issue":{"subject":"Ghost"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
"[2-B-4] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $false -and ($x.errors -join ' ') -match 'not found') { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-B-4] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "not found" を含む

#### [2-B-5] update: 権限なし (viewer で edit_issues 不可)

閲覧者（`{ViewerKey}`）で、見られるが編集できない Issue #X（`{IssueX}`）を更新する。

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{ViewerKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"update","id":{IssueX},"issue":{"subject":"no perm"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
"[2-B-5] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $false -and ($x.errors -join ' ') -match 'forbidden') { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-B-5] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "forbidden" を含む

#### [2-B-6] update: replace_none_values_with_blank

Issue #Z は用意で作る（`{IssueZ}`、担当者は書き手）。

```powershell
function Get-Issue($id) { (Invoke-RestMethod -Uri "{BaseUrl}/issues/$id.json?include=journals" -Headers @{ 'X-Redmine-API-Key' = '{ApiKey}' }).issue }
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"update","id":{IssueZ},"issue":{"assigned_to_id":"none"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
$i = Get-Issue {IssueZ}
"[2-B-6] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $true -and $null -eq $i.assigned_to) { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-B-6] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == true`
- Issue #Z の assigned_to が nil にクリアされている

### 2.C 混在

#### [2-C-1] create + update 混在

既存 Issue #W は用意で作る（`{IssueW}`）。

```powershell
function Get-Issue($id) { (Invoke-RestMethod -Uri "{BaseUrl}/issues/$id.json?include=journals" -Headers @{ 'X-Redmine-API-Key' = '{ApiKey}' }).issue }
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"create","issue":{"project_id":{ProjectId},"subject":"BulkWrite_2C1_New"}},{"op":"update","id":{IssueW},"issue":{"subject":"BulkWrite_2C1_Updated"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $rs = @($j.results)
"[2-C-1] " + $(if ($r.StatusCode -eq 200 -and $rs.Count -eq 2 -and $rs[0].success -and $rs[0].op -eq 'create' -and $rs[1].success -and $rs[1].op -eq 'update' -and (Get-Issue $rs[0].issue.id).subject -eq 'BulkWrite_2C1_New' -and (Get-Issue {IssueW}).subject -eq 'BulkWrite_2C1_Updated') { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-C-1] PASS`（次をすべて確かめる）
- Status: 200
- `results.length == 2`
- `results[0].success == true`, `results[0].op == "create"`
- `results[1].success == true`, `results[1].op == "update"`
- 両 Issue が期待通り DB に反映

#### [2-C-2] Partial success (成功 + 失敗)

```powershell
function Get-Issue($id) { (Invoke-RestMethod -Uri "{BaseUrl}/issues/$id.json?include=journals" -Headers @{ 'X-Redmine-API-Key' = '{ApiKey}' }).issue }
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"create","issue":{"project_id":{ProjectId},"subject":"Good"}},{"op":"create","issue":{"project_id":99999,"subject":"Bad"}},{"op":"create","issue":{"project_id":{ProjectId},"subject":"Good2"}}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $rs = @($j.results)
"[2-C-2] " + $(if ($r.StatusCode -eq 200 -and $rs.Count -eq 3 -and $rs[0].success -and -not $rs[1].success -and ($rs[1].errors -join ' ') -match 'project not found' -and $rs[2].success -and (Get-Issue $rs[0].issue.id).subject -eq 'Good' -and (Get-Issue $rs[2].issue.id).subject -eq 'Good2') { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-C-2] PASS`（次をすべて確かめる）
- Status: 200
- `results.length == 3`
- `results[0].success == true`
- `results[1].success == false`（project not found）
- `results[2].success == true`
- 成功した 2 件は DB に存在（部分成功: 失敗による全 rollback ではない）

#### [2-C-3] 14 件 create（実運用想定）

14 件の create operations（実運用で報告のあった件数と同じシナリオ）。かかった時間も出す。

```powershell
$ops = 1..14 | ForEach-Object { @{ op = 'create'; issue = @{ project_id = {ProjectId}; subject = "BulkWrite_2C3_$_" } } }
$body = @{ operations = @($ops) } | ConvertTo-Json -Depth 5 -Compress
$sw = [Diagnostics.Stopwatch]::StartNew()
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -SkipHttpErrorCheck
$sw.Stop()
$rs = @(($r.Content | ConvertFrom-Json).results)
$ids = @($rs | Where-Object { $_.success } | ForEach-Object { $_.issue.id })
$found = @((Invoke-RestMethod -Uri "{BaseUrl}/issues.json?issue_id=$($ids -join ',')&status_id=*&limit=100" -Headers @{ 'X-Redmine-API-Key' = '{ApiKey}' }).issues).Count
"[2-C-3] " + $(if ($r.StatusCode -eq 200 -and $rs.Count -eq 14 -and $ids.Count -eq 14 -and $found -eq 14) { 'PASS' } else { "FAIL: $($r.StatusCode) results=$($rs.Count) ok=$($ids.Count) found=$found" })
"elapsed: $([math]::Round($sw.Elapsed.TotalSeconds, 1)) 秒"
```

**期待結果:** `[2-C-3] PASS`（次をすべて確かめる）
- Status: 200
- `results.length == 14`
- 全て `success == true`
- 14 件が DB に作成されている
- レスポンス時間の目安: 5 秒以内（本 API 導入の主目的の確認）。`elapsed:` で見る（`PASS` の判定には入れない）

### 2.D エラー入力

#### [2-D-1] operations が空配列

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[]}')) -SkipHttpErrorCheck
"[2-D-1] " + $(if ($r.StatusCode -eq 422 -and $r.Content.Contains('operations must not be empty')) { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-D-1] PASS`（次をすべて確かめる）
- Status: 422
- レスポンスに "operations must not be empty" を含む

#### [2-D-2] operations が配列でない

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":"not an array"}')) -SkipHttpErrorCheck
"[2-D-2] " + $(if ($r.StatusCode -eq 422 -and $r.Content.Contains('operations must be an array')) { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-D-2] PASS`（次をすべて確かめる）
- Status: 422
- レスポンスに "operations must be an array" を含む

#### [2-D-3] operations 未指定

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{}')) -SkipHttpErrorCheck
"[2-D-3] " + $(if ($r.StatusCode -eq 422 -and $r.Content.Contains('operations must be an array')) { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-D-3] PASS`（次をすべて確かめる）
- Status: 422
- レスポンスに "operations must be an array" を含む

#### [2-D-4] 未知の op

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"delete","id":1}]}')) -SkipHttpErrorCheck
$j = $r.Content | ConvertFrom-Json; $x = $j.results[0]
"[2-D-4] " + $(if ($r.StatusCode -eq 200 -and $x.success -eq $false -and ($x.errors -join ' ') -match 'unknown op') { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-D-4] PASS`（次をすべて確かめる）
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "unknown op" を含む

#### [2-D-5] 認証なし

Authorization ヘッダなし + 空 operations（`{"operations":[]}`）

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{} -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[]}')) -SkipHttpErrorCheck
"[2-D-5] " + $(if ($r.StatusCode -eq 401) { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-D-5] PASS`（次をすべて確かめる）
- Status: 401（`before_action :require_login` により認証必須）
- 標準 Redmine POST /issues.json も無認証で 401 を返すため、その挙動に揃えている

### 2.E Redmine 本体との等価性

**目的:** bulk_write で作成/更新した Issue が、標準 API (POST /issues.json / PUT /issues/:id.json) で作成/更新した Issue と同一の状態になることを保証する。

#### [2-E-1] create 等価性

**手順:**
1. **A**: 標準 API `POST /issues.json` で subject/description/tracker/status/assigned_to/priority/custom_field_values を指定して作成 → issue_A
2. **B**: bulk_write で同じパラメータで create → issue_B
3. 両 Issue を GET で取得し、比較

**比較対象フィールド:**
- subject, description, tracker_id, status_id, assigned_to_id, priority_id
- custom_field_values（各 CF の値）
- author_id, project_id
- journals（両者とも空、または本 API に notes 指定した場合は片方だけ 1 件のはず）

**実行:**
手順の 1〜3 を、notes を付けない組と、B にだけ notes を付ける組の 2 回行う（subject は組ごとに変え、比べるときは組の中で同じになる）。

```powershell
function Get-Issue($id) { (Invoke-RestMethod -Uri "{BaseUrl}/issues/$id.json?include=journals" -Headers @{ 'X-Redmine-API-Key' = '{ApiKey}' }).issue }
$h = @{ 'X-Redmine-API-Key' = '{WriterKey}' }
function Pair($sfx, $notes) {
    $issue = [ordered]@{ project_id = {ProjectId}; subject = "BulkWrite_E1_$sfx"; description = 'E1 description'; tracker_id = {TrackerId}; status_id = {StatusId}
                         assigned_to_id = {WriterId}; priority_id = {PriorityId}; custom_field_values = @{ '{CfStringId}' = 'E1'; '{CfListId}' = 'B' } }
    # A: 標準 API
    $a = (Invoke-RestMethod -Uri '{BaseUrl}/issues.json' -Method Post -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes((@{ issue = $issue } | ConvertTo-Json -Depth 5 -Compress)))).issue.id
    # B: bulk_write（notes を付けるときは B だけ）
    if ($notes) { $issue.notes = $notes }
    $body = @{ operations = @(@{ op = 'create'; issue = $issue }) } | ConvertTo-Json -Depth 6 -Compress
    $b = ((Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))).Content | ConvertFrom-Json).results[0].issue.id
    $view = { param($i) ($i.subject, $i.description, $i.tracker.id, $i.status.id, $i.assigned_to.id, $i.priority.id, $i.author.id, $i.project.id,
              (@($i.custom_fields | Sort-Object id | ForEach-Object { "$($_.id)=$($_.value)" }) -join ',')) -join '|' }
    $ia = Get-Issue $a; $ib = Get-Issue $b
    [pscustomobject]@{ Same = (& $view $ia) -eq (& $view $ib); A = @($ia.journals).Count; B = @($ib.journals).Count; View = (& $view $ib) }
}
$plain = Pair 'plain' $null
$noted = Pair 'notes' 'E1 notes'
"[2-E-1] " + $(if ($plain.Same -and $plain.A -eq 0 -and $plain.B -eq 0 -and $noted.Same -and $noted.A -eq 0 -and $noted.B -eq 1) { 'PASS' } else { "FAIL: plain=$($plain | ConvertTo-Json -Compress) notes=$($noted | ConvertTo-Json -Compress)" })
```

**期待結果:** `[2-E-1] PASS`（次をすべて確かめる）
- notes 指定なしの場合: 全フィールド一致（journal も 0 件同士）。subject も同じにして比べる
- notes 指定ありの場合: A は notes なし（silent no-op）、B は notes あり → 想定通りの差分

#### [2-E-2] update 等価性

**手順:**
1. 既存 Issue #P と #Q を用意（同じ内容）
2. **A**: `PUT /issues/#P.json` で subject/notes を指定して更新
3. **B**: bulk_write で `#Q` を同じパラメータで update
4. 両 Issue を GET で取得し、比較

**実行:**
#P・#Q は用意で作る同じ内容のチケット（`{IssueP}`・`{IssueQ}`、subject: `BulkWrite_E2_Orig_<印>`）。

```powershell
function Get-Issue($id) { (Invoke-RestMethod -Uri "{BaseUrl}/issues/$id.json?include=journals" -Headers @{ 'X-Redmine-API-Key' = '{ApiKey}' }).issue }
$h = @{ 'X-Redmine-API-Key' = '{WriterKey}' }
$upd = @{ subject = 'BulkWrite_E2_Updated'; notes = 'E2 notes' }
# A: 標準 API で #P を更新
Invoke-WebRequest -Uri '{BaseUrl}/issues/{IssueP}.json' -Method Put -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes((@{ issue = $upd } | ConvertTo-Json -Compress))) | Out-Null
# B: bulk_write で #Q を同じパラメータで更新
$body = @{ operations = @(@{ op = 'update'; id = {IssueQ}; issue = $upd }) } | ConvertTo-Json -Depth 5 -Compress
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.json' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -SkipHttpErrorCheck
$view = { param($i) $i.subject + '|' + ((@($i.journals) | ForEach-Object { $_.notes + ':' + ((@($_.details) | ForEach-Object { "$($_.property)/$($_.name)/$($_.old_value)/$($_.new_value)" }) -join ';') }) -join '#') }
$a = & $view (Get-Issue {IssueP}); $b = & $view (Get-Issue {IssueQ})
"[2-E-2] " + $(if ($r.StatusCode -eq 200 -and $a -eq $b -and $a.StartsWith('BulkWrite_E2_Updated|E2 notes:attr/subject/')) { 'PASS' } else { "FAIL: A=$a B=$b" })
```

**期待結果:** `[2-E-2] PASS`（次をすべて確かめる）
- subject, journals の内容（notes, details）が一致
- updated_on・journal の created_on は微差あり（実行時刻）なので比べない。その他の journal 内容は一致

### 2.F XML 対応

#### [2-F-1] XML リクエスト → XML レスポンス

**リクエスト:**
```http
POST /issues/bulk_write.xml
Content-Type: application/xml

<?xml version="1.0" encoding="UTF-8"?>
<operations type="array">
  <operation>
    <op>create</op>
    <issue>
      <project_id>{ProjectId}</project_id>
      <subject>BulkWrite_2F1_XML</subject>
    </issue>
  </operation>
</operations>
```

**注意**: Rails の XML パーサーは root 要素名を top-level params キーとして使用する。`<params>` の外側ラッパーは不要で、直接 `<operations>` を root にする。

**実行:**
上の XML を `POST /issues/bulk_write.xml`（`Content-Type: application/xml`）で送る。`<project_id>` は用意で作るプロジェクト（`{ProjectId}`）。

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.xml' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}' } -ContentType 'application/xml; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('<?xml version="1.0" encoding="UTF-8"?><operations type="array"><operation><op>create</op><issue><project_id>{ProjectId}</project_id><subject>BulkWrite_2F1_XML</subject></issue></operation></operations>')) -SkipHttpErrorCheck
$x = [xml]$r.Content
"[2-F-1] " + $(if ($r.StatusCode -eq 200 -and ($r.Headers['Content-Type'] -join '') -match 'application/xml' -and @($x.SelectNodes('//result')).Count -eq 1 -and $x.SelectSingleNode('//result/success').InnerText -eq 'true' -and $null -ne $x.SelectSingleNode('//result/issue')) { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-F-1] PASS`（次をすべて確かめる）
- Status: 200
- Content-Type: `application/xml`
- XML レスポンスに `<result>` 要素が 1 個含まれ、`<success>true</success>` と `<issue>` 要素を持つ

#### [2-F-2] JSON リクエスト → XML レスポンス (Accept ヘッダで指定)

**リクエスト:**
```http
POST /issues/bulk_write.xml
Content-Type: application/json
Accept: application/xml

{ "operations": [{ "op": "create", "issue": { "project_id": {ProjectId}, "subject": "..." } }] }
```

**実行:**
JSON の本文を `POST /issues/bulk_write.xml`（`Accept: application/xml`）で送る。

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/issues/bulk_write.xml' -Method Post -Headers @{ 'X-Redmine-API-Key' = '{WriterKey}'; 'Accept' = 'application/xml' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes('{"operations":[{"op":"create","issue":{"project_id":{ProjectId},"subject":"BulkWrite_2F2_JsonToXml"}}]}')) -SkipHttpErrorCheck
$x = [xml]$r.Content
"[2-F-2] " + $(if ($r.StatusCode -eq 200 -and ($r.Headers['Content-Type'] -join '') -match 'application/xml' -and @($x.SelectNodes('//result')).Count -eq 1 -and $x.SelectSingleNode('//result/success').InnerText -eq 'true') { 'PASS' } else { "FAIL: $($r.StatusCode) $($r.Content)" })
```

**期待結果:** `[2-F-2] PASS`（次をすべて確かめる）
- Status: 200
- Content-Type: `application/xml`
- XML 形式のレスポンス（同一構造）

## 3. ブラウザテスト

該当なし（API 専用エンドポイントのため）。

## 網羅性チェック

| 実装ロジック | 対応テスト |
|-------------|-----------|
| operations 型チェック | [2-D-1, 2-D-2, 2-D-3] |
| unknown op | [2-D-4] |
| process_create - project 解決 | [2-A-1, 2-A-6, 2-A-7] |
| process_create - add_issues 権限 | [2-A-8] |
| process_create - init_journal with notes | [2-A-2, 2-A-3] |
| process_create - assigned_to_id: 'me' | [2-A-5] |
| process_create - safe_attributes | [2-A-1, 2-A-4] |
| process_create - tracker default | [2-A-1] |
| process_create - save + call_hook | [2-A-1] |
| process_create - validation error | [2-A-9] |
| process_update - id required | [2-B-3] |
| process_update - Issue.visible.find | [2-B-4] |
| process_update - edit_issues 権限 | [2-B-5] |
| process_update - init_journal + notes | [2-B-2] |
| process_update - assigned_to_id: 'me' | (implicit in 2-B-6 pattern) |
| process_update - replace_none_values_with_blank | [2-B-6] |
| process_update - transaction + save | [2-B-1] |
| Partial success | [2-C-2] |
| 混在シナリオ | [2-C-1] |
| 大量シナリオ (14 件) | [2-C-3] |
| 認証 | [2-D-5] |
| XML 対応 | [2-F-1, 2-F-2] |
| Redmine 本体との差分ゼロ | [2-E-1, 2-E-2] |
