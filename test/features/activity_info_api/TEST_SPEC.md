# Activity Info API テスト仕様書

## 概要

Activity Info API 機能のテスト仕様。活動履歴を JSON/XML API で取得する。
チケットの状態（ステータス、担当者）は活動時点の値に復元済みで返される。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| Controller | `ActivityInfosController` |
| ルーティング | `GET /activity_infos.json`, `GET /activity_infos.xml` |
| View ファイル | `app/views/activity_infos/index.api.rsb` |
| 認証 | API キー必須（未認証で 401） |

### パラメータ

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| user_id | int | ○ | 対象ユーザーの ID |
| from | date | ○ | 開始日（YYYY-MM-DD） |
| to | date | ○ | 終了日（YYYY-MM-DD、inclusive） |

### レスポンス形式

API は JSON と XML の両方をサポートする。

| 拡張子 | Content-Type |
|--------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

### API レスポンス構造

**GET `/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-07`:**
```json
{
  "activity_infos": [
    {
      "activity_datetime": "2026-04-07T01:50:00Z",
      "description": "",
      "issue_id": 786,
      "journal_id": 673,
      "issue": {
        "id": 786,
        "subject": "レビュー依頼: ユーザー管理機能",
        "tracker": { "id": 5, "name": "レビュー依頼" },
        "status": { "id": 5, "name": "終了" },
        "priority": { "id": 2, "name": "通常" },
        "author": { "id": 1, "name": "Redmine Admin" },
        "project": { "id": 15, "name": "Review Test Project" },
        "parent": { "id": 785 },
        "description": "",
        "start_date": null,
        "due_date": null,
        "done_ratio": 0,
        "created_on": "2026-04-07T00:05:00Z",
        "updated_on": "2026-04-07T01:50:00Z"
      },
      "journal": {
        "id": 673,
        "user": { "id": 1, "name": "Redmine Admin" },
        "notes": "",
        "created_on": "2026-04-07T01:50:00Z",
        "private_notes": false,
        "details": [
          {
            "property": "attr",
            "name": "status_id",
            "old_value": "1",
            "new_value": "5"
          }
        ]
      },
      "ticket_tree": [
        {
          "id": 790,
          "subject": "ユーザー管理機能の実装",
          "tracker": { "id": 2, "name": "機能" },
          "status": { "id": 1, "name": "新規" },
          "..."
        },
        {
          "id": 785,
          "subject": "設計レビュー: ユーザー管理機能",
          "..."
        },
        {
          "id": 786,
          "subject": "レビュー依頼: ユーザー管理機能",
          "..."
        }
      ]
    }
  ]
}
```

### レスポンスフィールド

**activity_info:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| activity_datetime | datetime | 活動時刻 |
| description | string | 活動の説明文（Journal → notes、Issue → description） |
| issue_id | int | チケット ID |
| journal_id | int/null | Journal ID（チケット作成時は null） |
| issue | object | 活動時点で復元済みのチケット情報 |
| journal | object/省略 | Journal 詳細（チケット作成時は省略） |
| ticket_tree | array | 親チケット階層（ルートから順、各チケットも活動時点の状態） |

**issue（activity_info 内）:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | int | チケット ID |
| subject | string | 件名 |
| tracker | object | トラッカー { id, name } |
| status | object | ステータス { id, name }（活動時点の値） |
| priority | object | 優先度 { id, name } |
| author | object | 作成者 { id, name } |
| assigned_to | object/省略 | 担当者 { id, name }（活動時点の値、null 時は省略） |
| project | object | プロジェクト { id, name } |
| parent | object/省略 | 親チケット { id }（null 時は省略） |
| description | string | チケットの説明 |
| start_date | date/null | 開始日 |
| due_date | date/null | 期日 |
| done_ratio | int | 進捗率 |
| created_on | datetime | 作成日時 |
| updated_on | datetime | 更新日時 |

**journal（activity_info 内）:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | int | Journal ID |
| user | object | ユーザー { id, name } |
| notes | string | コメント |
| created_on | datetime | 作成日時 |
| private_notes | bool | プライベートノートか |
| details | array | 変更詳細の配列 |

**detail（journal 内）:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| property | string | プロパティ種別（"attr" など） |
| name | string | フィールド名（"status_id", "assigned_to_id" など） |
| old_value | string/null | 変更前の値 |
| new_value | string/null | 変更後の値 |

---

## 1. Runner テスト

**実行方法:**
```bash
docker exec {Container} bash -c "cd /usr/src/redmine && bundle exec rails runner '{code}'"
```

### [1-1] ActivityInfosController が定義されている

**確認方法:**
```ruby
puts defined?(ActivityInfosController) ? 'PASS' : 'FAIL: ActivityInfosController not defined'
```

**期待結果:**
- `ActivityInfosController` が定義されている

---

### [1-2] ルーティングが設定されている

**確認方法:**
```ruby
routes = Rails.application.routes.routes
route = routes.any? { |r| r.defaults[:controller] == 'activity_infos' && r.defaults[:action] == 'index' }
puts route ? 'PASS' : 'FAIL: activity_infos#index route not found'
```

**期待結果:**
- `activity_infos#index` ルートが存在する

---

### [1-3] View ファイルが存在する

**確認方法:**
```ruby
plugin_path = Rails.root.join('plugins', 'redmine_studio_plugin')
view_file = plugin_path.join('app', 'views', 'activity_infos', 'index.api.rsb')
puts File.exist?(view_file) ? 'PASS' : 'FAIL: index.api.rsb not found'
```

**期待結果:**
- `app/views/activity_infos/index.api.rsb` が存在する

---

### [1-4] accept_api_auth が設定されている

**確認方法:**
```ruby
result = ActivityInfosController.accept_api_auth_actions.include?(:index)
puts result ? 'PASS' : 'FAIL: accept_api_auth not set for :index'
```

**期待結果:**
- `index` アクションで API キー認証が有効

---

### [1-5] restore_status がステータスを正しく復元する

**確認方法:**
```ruby
# #788: 現在の status_id=5(終了), journal#684 で 1→2 に変更 (04/07 01:25)
issue = Issue.find(788)
controller = ActivityInfosController.new
journals = issue.journals.preload(:details).sort_by(&:created_on)
target = Journal.find(684).created_on
status_lookup = IssueStatus.all.index_by(&:id)
principal_lookup = Principal.all.index_by(&:id)
restored = controller.send(:restore_status, issue, target, journals, status_lookup, principal_lookup)
# target 時点では status_id=1→2 に変更される前なので、復元値は 1
puts restored[:status_id] == 1 ? 'PASS' : "FAIL: Expected status_id=1, got #{restored[:status_id]}"
```

**期待結果:**
- `status_id` が `1`（新規）に復元される

---

### [1-6] restore_status が担当者を正しく復元する

**確認方法:**
```ruby
# #785: 現在の assigned_to_id=22, journal#686 で 1→22 に変更 (04/10 11:53)
issue = Issue.find(785)
controller = ActivityInfosController.new
journals = issue.journals.preload(:details).sort_by(&:created_on)
target = Journal.find(686).created_on
status_lookup = IssueStatus.all.index_by(&:id)
principal_lookup = Principal.all.index_by(&:id)
restored = controller.send(:restore_status, issue, target, journals, status_lookup, principal_lookup)
# target 時点では 1→22 に変更される前なので、復元値は 1
puts restored[:assigned_to_id] == 1 ? 'PASS' : "FAIL: Expected assigned_to_id=1, got #{restored[:assigned_to_id]}"
```

**期待結果:**
- `assigned_to_id` が `1` に復元される

---

### [1-7] build_ticket_tree が正しい階層を返す

**確認方法:**
```ruby
# #787(指摘) → #785(開催) → #790(機能)
issue_ids = [787, 785, 790]
issues_by_id = Issue.where(:id => issue_ids).index_by(&:id)
journals_by_issue = {}
issue_ids.each do |id|
  journals_by_issue[id] = issues_by_id[id].journals.preload(:details).sort_by(&:created_on)
end
status_lookup = IssueStatus.all.index_by(&:id)
principal_lookup = Principal.all.index_by(&:id)
controller = ActivityInfosController.new
tree = controller.send(:build_ticket_tree, issues_by_id[787], issues_by_id[787].created_on, journals_by_issue, issues_by_id, {}, status_lookup, principal_lookup)
ids = tree.map { |t| t[:id] }
puts ids == [790, 785, 787] ? 'PASS' : "FAIL: Expected [790, 785, 787], got #{ids}"
```

**期待結果:**
- ticket_tree が `[790, 785, 787]`（ルートから順）

---

### [1-8] build_ticket_tree のキャッシュが動作する

**確認方法:**
```ruby
issue_ids = [787, 785, 790]
issues_by_id = Issue.where(:id => issue_ids).index_by(&:id)
journals_by_issue = {}
issue_ids.each do |id|
  journals_by_issue[id] = issues_by_id[id].journals.preload(:details).sort_by(&:created_on)
end
status_lookup = IssueStatus.all.index_by(&:id)
principal_lookup = Principal.all.index_by(&:id)
controller = ActivityInfosController.new
cache = {}
tree1 = controller.send(:build_ticket_tree, issues_by_id[787], issues_by_id[787].created_on, journals_by_issue, issues_by_id, cache, status_lookup, principal_lookup)
tree2 = controller.send(:build_ticket_tree, issues_by_id[787], issues_by_id[787].created_on, journals_by_issue, issues_by_id, cache, status_lookup, principal_lookup)
puts tree1.equal?(tree2) ? 'PASS' : 'FAIL: Cache not working (different object returned)'
```

**期待結果:**
- 同じ引数で呼び出した場合、同一オブジェクトが返される（キャッシュヒット）

---

### [1-9] Issue 作成イベントでは journal_id が nil になる

**確認方法:**
```ruby
issue = Issue.find(785)
controller = ActivityInfosController.new
status_lookup = IssueStatus.all.index_by(&:id)
principal_lookup = Principal.all.index_by(&:id)
issues_by_id = Issue.where(:id => [785, 790]).index_by(&:id)
info = controller.send(:build_from_issue, issue, {}, issues_by_id, {}, status_lookup, principal_lookup)
result = info[:journal_id].nil? && info[:journal].nil?
puts result ? 'PASS' : "FAIL: journal_id=#{info[:journal_id]}, journal=#{info[:journal]}"
```

**期待結果:**
- `journal_id` が nil
- `journal` が nil

---

### [1-10] Journal イベントの description は notes を返す

**確認方法:**
```ruby
# journal#686 は notes="コメント付きで担当者を変更"
journal = Journal.find(686)
controller = ActivityInfosController.new
status_lookup = IssueStatus.all.index_by(&:id)
principal_lookup = Principal.all.index_by(&:id)
issues_by_id = Issue.where(:id => [785, 790]).index_by(&:id)
info = controller.send(:build_from_journal, journal, {}, issues_by_id, {}, status_lookup, principal_lookup)
puts info[:description] == journal.notes ? 'PASS' : "FAIL: Expected '#{journal.notes}', got '#{info[:description]}'"
```

**期待結果:**
- `description` が Journal の `notes` と一致する

---

### [1-11] Issue 作成イベントの description は issue.description を返す

**確認方法:**
```ruby
issue = Issue.find(785)
controller = ActivityInfosController.new
status_lookup = IssueStatus.all.index_by(&:id)
principal_lookup = Principal.all.index_by(&:id)
issues_by_id = Issue.where(:id => [785, 790]).index_by(&:id)
info = controller.send(:build_from_issue, issue, {}, issues_by_id, {}, status_lookup, principal_lookup)
puts info[:description] == issue.description ? 'PASS' : "FAIL: Expected '#{issue.description}', got '#{info[:description]}'"
```

**期待結果:**
- `description` が Issue の `description` と一致する

---

### [1-12] 複数の変更がある場合、異なる時点で異なる値に復元される

**確認方法:**
```ruby
# #785: journal#685 で assigned_to nil→1 (11:53:12), journal#686 で assigned_to 1→22 (11:53:32)
issue = Issue.find(785)
controller = ActivityInfosController.new
journals = issue.journals.preload(:details).sort_by(&:created_on)
status_lookup = IssueStatus.all.index_by(&:id)
principal_lookup = Principal.all.index_by(&:id)
target1 = Journal.find(685).created_on  # nil→1 の変更時点
target2 = Journal.find(686).created_on  # 1→22 の変更時点
restored1 = controller.send(:restore_status, issue, target1, journals, status_lookup, principal_lookup)
restored2 = controller.send(:restore_status, issue, target2, journals, status_lookup, principal_lookup)
# target1 時点では nil→1 と 1→22 の両方が逆適用されるので nil
# target2 時点では 1→22 のみ逆適用されるので 1
result = restored1[:assigned_to_id].nil? && restored2[:assigned_to_id] == 1
puts result ? 'PASS' : "FAIL: target1=#{restored1[:assigned_to_id].inspect}, target2=#{restored2[:assigned_to_id].inspect}"
```

**期待結果:**
- target1 時点の `assigned_to_id` が nil（両方の変更前）
- target2 時点の `assigned_to_id` が `1`（2番目の変更前、1番目の変更後）

---

## 2. HTTP テスト

**実行方法:**
PowerShell で各エンドポイントにリクエストを送信する。API キー認証が必要。

### [2-1] JSON 形式でアクセス可能

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.StatusCode
```

**期待結果:**
- ステータスコード 200

---

### [2-2] XML 形式でアクセス可能

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/activity_infos.xml?user_id=1&from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.StatusCode
```

**期待結果:**
- ステータスコード 200

---

### [2-3] activity_infos 配列が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.activity_infos -is [array]
```

**期待結果:**
- `activity_infos` が配列

---

### [2-4] 日付範囲でフィルタリングされる

**確認方法:**
```powershell
$r1 = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$r2 = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-10&to=2026-04-10' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$r3 = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-10' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$r1.activity_infos.Count + $r2.activity_infos.Count -eq $r3.activity_infos.Count
```

**期待結果:**
- 4/7 の件数 + 4/10 の件数 = 4/7〜4/10 の件数

---

### [2-5] 活動がない期間は空配列を返す

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-11&to=2026-04-12' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.activity_infos.Count -eq 0
```

**期待結果:**
- `activity_infos` が空配列

---

### [2-6] activity_info に必須フィールドが含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$info = $response.activity_infos[0]
$info.activity_datetime -ne $null -and $info.issue_id -ne $null -and $info.issue -ne $null -and $info.ticket_tree -ne $null
```

**期待結果:**
- `activity_datetime`, `issue_id`, `issue`, `ticket_tree` が存在する

---

### [2-7] issue に必須フィールドが含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$issue = $response.activity_infos[0].issue
$issue.id -ne $null -and $issue.subject -ne $null -and $issue.tracker -ne $null -and $issue.status -ne $null -and $issue.project -ne $null
```

**期待結果:**
- `id`, `subject`, `tracker`, `status`, `project` が存在する

---

### [2-8] journal に details が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$withJournal = $response.activity_infos | Where-Object { $_.journal -ne $null } | Select-Object -First 1
$withJournal.journal.details -is [array]
```

**期待結果:**
- journal の `details` が配列

---

### [2-9] ticket_tree がルートから順に並んでいる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
# 親を持たないチケット（ルート）の活動を探す
$withTree = $response.activity_infos | Where-Object { $_.ticket_tree.Count -ge 2 } | Select-Object -First 1
$first = $withTree.ticket_tree[0]
$first.parent -eq $null  # ルートは parent を持たない
```

**期待結果:**
- ticket_tree の最初の要素は parent を持たない（ルートチケット）

---

### [2-10] ステータスが活動時点の値に復元されている

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-10&to=2026-04-10' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
# 4/10 の #785 の活動: journal#686 で assigned_to_id を 1→22 に変更
$info = $response.activity_infos | Where-Object { $_.issue_id -eq 785 }
# 活動時点（変更前）は assigned_to_id=1
$info.issue.assigned_to.id -eq 1
```

**期待結果:**
- `assigned_to.id` が `1`（変更前の値に復元されている）

---

### [2-11] 未認証でアクセスすると 401 を返す

**前提条件:** Redmine の「認証が必要」設定が有効であること。匿名アクセスが許可されている環境ではスキップ。

**確認方法:**
```powershell
try {
    Invoke-WebRequest -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-07'
} catch {
    $_.Exception.Response.StatusCode
}
```

**期待結果:**
- ステータスコード 401 Unauthorized

---

### [2-12] user_id が未指定だと 422 を返す

**確認方法:**
```powershell
try {
    Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
} catch {
    $_.Exception.Response.StatusCode
}
```

**期待結果:**
- ステータスコード 422 Unprocessable Entity

---

### [2-13] from が未指定だと 422 を返す

**確認方法:**
```powershell
try {
    Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
} catch {
    $_.Exception.Response.StatusCode
}
```

**期待結果:**
- ステータスコード 422 Unprocessable Entity

---

### [2-14] to が未指定だと 422 を返す

**確認方法:**
```powershell
try {
    Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
} catch {
    $_.Exception.Response.StatusCode
}
```

**期待結果:**
- ステータスコード 422 Unprocessable Entity

---

### [2-15] 存在しないユーザーで 404 を返す

**確認方法:**
```powershell
try {
    Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=99999&from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
} catch {
    $_.Exception.Response.StatusCode
}
```

**期待結果:**
- ステータスコード 404 Not Found

---

### [2-16] チケット作成イベントでは journal が省略される

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$creation = $response.activity_infos | Where-Object { $_.journal_id -eq $null } | Select-Object -First 1
$creation -ne $null -and $creation.journal -eq $null
```

**期待結果:**
- `journal_id` が null のイベントが存在し、その `journal` も存在しない

---

### [2-17] assigned_to が null のチケットでは assigned_to が省略される

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
# assigned_to が null のチケットを探す
$noAssignee = $response.activity_infos | Where-Object { $_.issue.assigned_to -eq $null } | Select-Object -First 1
$noAssignee -ne $null
```

**期待結果:**
- `assigned_to` が省略されたチケットが存在する

---

### [2-18] イベントが新しい順（降順）で返される

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$dates = $response.activity_infos | ForEach-Object { [datetime]$_.activity_datetime }
$sorted = $true
for ($i = 0; $i -lt $dates.Count - 1; $i++) {
    if ($dates[$i] -lt $dates[$i + 1]) { $sorted = $false; break }
}
$sorted
```

**期待結果:**
- `activity_datetime` が降順に並んでいる

---

### [2-19] user_id によるフィルタリングが動作する

**確認方法:**
```powershell
# user_id=1 (admin) の活動
$r1 = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-10' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
# 活動がないユーザー（テスト環境に存在する別ユーザー）
$r2 = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id=5&from=2026-04-07&to=2026-04-10' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$r1.activity_infos.Count -gt 0 -and $r1.activity_infos.Count -ne $r2.activity_infos.Count
```

**期待結果:**
- 異なる user_id で異なる件数が返される

---

### [2-20] XML レスポンスに activity_infos タグが含まれる（旧 [2-16]）

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/activity_infos.xml?user_id=1&from=2026-04-07&to=2026-04-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.Content -match '<activity_infos'
```

**期待結果:**
- レスポンスに `<activity_infos` タグが含まれる

---

## 3. ブラウザテスト

なし（API のみの機能のため）

---

## テスト実行方法

### Runner テスト・HTTP テスト
Claude が TEST_SPEC.md の仕様に基づいてコマンドを実行し、結果を報告する。
