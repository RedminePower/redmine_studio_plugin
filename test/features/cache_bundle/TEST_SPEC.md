# Cache Bundle API テスト仕様書

## 概要

Cache Bundle API 機能のテスト仕様。Redmine Studio (Windows クライアント) のキャッシュ更新を 1 リクエストで完結させるエンドポイント。
13 セクション分の情報（markup_lang、projects、trackers、issue_statuses、issue_priorities、time_entry_activities、queries、custom_fields、users、roles、groups、project_memberships、project_versions、project_issue_categories）をひとまとめに返す。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| Controller | `CacheBundlesController` |
| ルーティング | `GET /cache_bundle` |
| View ファイル | なし（コントローラから `render plain:` で JSON を直接出力） |
| 認証 | API キー必須（`accept_api_auth :show`） |
| レスポンス形式 | JSON のみ（XML 非対応） |

### パラメータ

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| user_id | int | × | 対象ユーザの ID（省略時は認証済みユーザ）。非 admin は自分以外を指定不可。 |

### gzip 圧縮

リクエストヘッダの `Accept-Encoding: gzip` を含む場合、レスポンスを `ActiveSupport::Gzip.compress` で圧縮し `Content-Encoding: gzip` と `Vary: Accept-Encoding` を付与して返す。
含まない場合は非圧縮の JSON を返す。

### API レスポンス構造

**GET `/cache_bundle?user_id=1`:**

```json
{
  "cache_bundle": {
    "markup_lang": "common_mark",
    "projects": [
      {
        "id": 1, "name": "...", "identifier": "...",
        "description": "...", "homepage": "...",
        "status": 1, "is_public": true, "inherit_members": false,
        "created_on": "...", "updated_on": "...",
        "trackers": [{ "id": 1, "name": "..." }],
        "enabled_modules": [{ "id": 1, "name": "..." }],
        "issue_categories": [{ "id": 1, "name": "..." }],
        "time_entry_activities": [{ "id": 1, "name": "..." }],
        "issue_custom_fields": [{ "id": 1, "name": "..." }],
        "parent": { "id": 0, "name": "..." }
      }
    ],
    "trackers": [{ "id": 1, "name": "...", "default_status": { "id": 1, "name": "..." } }],
    "issue_statuses": [{ "id": 1, "name": "...", "is_closed": false }],
    "issue_priorities": [{ "id": 1, "name": "...", "is_default": true }],
    "time_entry_activities": [{ "id": 1, "name": "...", "is_default": true }],
    "queries": [{ "id": 1, "name": "...", "is_public": true, "project_id": 1 }],
    "custom_fields": [
      {
        "id": 1, "name": "...", "customized_type": "issue",
        "field_format": "string", "regexp": "", "min_length": 0, "max_length": 0,
        "is_required": false, "is_filter": false, "searchable": false,
        "multiple": false, "default_value": "", "visible": true,
        "possible_values": [{ "value": "..." }],
        "trackers": [{ "id": 1, "name": "..." }],
        "roles": [{ "id": 1, "name": "..." }]
      }
    ],
    "users": [
      {
        "id": 1, "login": "admin", "firstname": "...", "lastname": "...",
        "mail": "...", "created_on": "...", "last_login_on": "...",
        "status": 1, "admin": true
      }
    ],
    "roles": [
      {
        "id": 1, "name": "...",
        "assignable": true, "issues_visibility": "default",
        "time_entries_visibility": "all", "users_visibility": "all",
        "permissions": [{ "info": "view_issues" }]
      }
    ],
    "groups": [{ "id": 1, "name": "...", "users": [{ "id": 1, "name": "..." }] }],
    "project_memberships": {
      "1": [
        { "id": 1, "project": { "id": 1, "name": "..." },
          "roles": [{ "id": 1, "name": "...", "inherited": false }],
          "user": { "id": 1, "name": "..." } }
      ]
    },
    "project_versions": {
      "1": [
        { "id": 1, "project": { "id": 1, "name": "..." },
          "name": "...", "description": "...", "status": "open", "sharing": "none",
          "created_on": "...", "updated_on": "...", "due_date": "...", "wiki_page_title": "..." }
      ]
    },
    "project_issue_categories": {
      "1": [
        { "id": 1, "project": { "id": 1, "name": "..." }, "name": "...",
          "assigned_to": { "id": 1, "name": "..." } }
      ]
    },
    "errors": [
      { "section": "...", "code": 500, "message": "..." }
    ]
  }
}
```

### レスポンスフィールド

**cache_bundle ルート:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| markup_lang | string | テキスト書式（textile, common_mark など） |
| projects | array | 全プロジェクト（status=1,5,9 すべて） |
| trackers | array | トラッカー |
| issue_statuses | array | チケットステータス |
| issue_priorities | array | 優先度（active のみ） |
| time_entry_activities | array | 作業分類（active のみ） |
| queries | array | カスタムクエリ（user に対する visible） |
| custom_fields | array | カスタムフィールド（admin のみ取得） |
| users | array | ユーザ一覧（admin のみ取得） |
| roles | array | ロール（permissions 込み） |
| groups | array | グループ（admin のみ取得、users 込み） |
| project_memberships | dict | `{ project_id => [...] }` ロックユーザを除外 |
| project_versions | dict | `{ project_id => [...] }` |
| project_issue_categories | dict | `{ project_id => [...] }` Active プロジェクトのみ |
| errors | array | 部分失敗時のメタデータ。成功時は空配列 |

**非 admin ユーザの場合:**
- `custom_fields` / `users` / `groups` は空配列で返る
- `project_memberships` / `project_versions` / `project_issue_categories` は対象ユーザが member となっているプロジェクトのみ

---

## 1. Runner テスト

**実行方法:**
```bash
docker exec {Container} bash -c "cd /usr/src/redmine && bundle exec rails runner '{code}'"
```

### [1-1] CacheBundlesController が定義されている

**確認方法:**
```ruby
puts defined?(CacheBundlesController) ? 'PASS' : 'FAIL: CacheBundlesController not defined'
```

**期待結果:**
- `CacheBundlesController` が定義されている

---

### [1-2] ルーティングが設定されている

**確認方法:**
```ruby
routes = Rails.application.routes.routes
route = routes.any? { |r| r.defaults[:controller] == 'cache_bundles' && r.defaults[:action] == 'show' }
puts route ? 'PASS' : 'FAIL: cache_bundles#show route not found'
```

**期待結果:**
- `cache_bundles#show` ルートが存在する

---

### [1-3] accept_api_auth が設定されている

**確認方法:**
```ruby
result = CacheBundlesController.accept_api_auth_actions.include?(:show)
puts result ? 'PASS' : 'FAIL: accept_api_auth not set for :show'
```

**期待結果:**
- `show` アクションで API キー認証が有効

---

### [1-4] resolve_target_user が user_id 省略時に User.current を返す

**確認方法:**
```ruby
User.current = User.find(1)
controller = CacheBundlesController.new
controller.params = ActionController::Parameters.new({})
result = controller.send(:resolve_target_user)
puts result&.id == 1 ? 'PASS' : "FAIL: Expected user_id=1, got #{result&.id.inspect}"
```

**期待結果:**
- `User.current`（admin）が返される

---

### [1-5] resolve_target_user が user_id 指定時にそのユーザを返す（admin）

**確認方法:**
```ruby
User.current = User.find(1)  # admin
target = User.where(type: 'User').where.not(id: 1).first
unless target
  puts 'SKIP: no non-admin user available'
else
  controller = CacheBundlesController.new
  controller.params = ActionController::Parameters.new(user_id: target.id.to_s)
  result = controller.send(:resolve_target_user)
  puts result&.id == target.id ? 'PASS' : "FAIL: Expected user_id=#{target.id}, got #{result&.id.inspect}"
end
```

**期待結果:**
- 指定された user_id のユーザが返される

---

### [1-6] fetch_markup_lang が Setting.text_formatting を返す

**確認方法:**
```ruby
controller = CacheBundlesController.new
expected = Setting.text_formatting
result = controller.send(:fetch_markup_lang)
puts result == expected ? 'PASS' : "FAIL: Expected '#{expected}', got '#{result}'"
```

**期待結果:**
- `Setting.text_formatting` の値（"common_mark" や "textile"）が返される

---

### [1-7] fetch_projects が全 status のプロジェクトを返す

**確認方法:**
```ruby
controller = CacheBundlesController.new
result = controller.send(:fetch_projects)
expected_count = Project.where(status: [Project::STATUS_ACTIVE, Project::STATUS_CLOSED, Project::STATUS_ARCHIVED]).count
puts result.size == expected_count ? 'PASS' : "FAIL: Expected #{expected_count}, got #{result.size}"
```

**期待結果:**
- 全 status（active=1, closed=5, archived=9）のプロジェクトが取得される

---

### [1-8] fetch_projects が必須フィールドを含む

**確認方法:**
```ruby
controller = CacheBundlesController.new
result = controller.send(:fetch_projects)
sample = result.first
required = [:id, :name, :identifier, :status, :is_public, :trackers, :enabled_modules, :issue_categories, :time_entry_activities, :issue_custom_fields]
missing = required - sample.keys
puts missing.empty? ? 'PASS' : "FAIL: Missing keys: #{missing.join(', ')}"
```

**期待結果:**
- projects の各要素に必須キーが含まれる

---

### [1-9] fetch_issue_statuses が sorted 順を返す

**確認方法:**
```ruby
controller = CacheBundlesController.new
result = controller.send(:fetch_issue_statuses)
ids = result.map { |s| s[:id] }
expected_ids = IssueStatus.sorted.pluck(:id)
puts ids == expected_ids ? 'PASS' : "FAIL: Order mismatch. Got #{ids}, expected #{expected_ids}"
```

**期待結果:**
- `IssueStatus.sorted` と同じ順序

---

### [1-10] fetch_issue_priorities が active のみを返す

**確認方法:**
```ruby
controller = CacheBundlesController.new
result = controller.send(:fetch_issue_priorities)
expected_count = IssuePriority.active.count
puts result.size == expected_count ? 'PASS' : "FAIL: Expected #{expected_count}, got #{result.size}"
```

**期待結果:**
- active な優先度のみ取得される

---

### [1-11] fetch_custom_fields は non-admin で空配列を返す

**確認方法:**
```ruby
non_admin = User.where(admin: false, type: 'User').first
unless non_admin
  puts 'SKIP: no non-admin user available'
else
  User.current = non_admin
  controller = CacheBundlesController.new
  result = controller.send(:fetch_custom_fields)
  puts result == [] ? 'PASS' : "FAIL: Expected [], got #{result.size} items"
end
```

**期待結果:**
- 非 admin ユーザでは空配列を返す

---

### [1-12] fetch_users は non-admin で空配列を返す

**確認方法:**
```ruby
non_admin = User.where(admin: false, type: 'User').first
unless non_admin
  puts 'SKIP: no non-admin user available'
else
  User.current = non_admin
  controller = CacheBundlesController.new
  result = controller.send(:fetch_users)
  puts result == [] ? 'PASS' : "FAIL: Expected [], got #{result.size} items"
end
```

**期待結果:**
- 非 admin ユーザでは空配列を返す

---

### [1-13] fetch_groups は non-admin で空配列を返す

**確認方法:**
```ruby
non_admin = User.where(admin: false, type: 'User').first
unless non_admin
  puts 'SKIP: no non-admin user available'
else
  User.current = non_admin
  controller = CacheBundlesController.new
  result = controller.send(:fetch_groups)
  puts result == [] ? 'PASS' : "FAIL: Expected [], got #{result.size} items"
end
```

**期待結果:**
- 非 admin ユーザでは空配列を返す

---

### [1-14] fetch_roles が permissions を含む

**確認方法:**
```ruby
controller = CacheBundlesController.new
result = controller.send(:fetch_roles)
sample = result.find { |r| r[:permissions].is_a?(Array) && r[:permissions].any? }
puts sample ? 'PASS' : 'FAIL: No role with permissions found'
```

**期待結果:**
- permissions を含むロールが少なくとも 1 つ存在する

---

### [1-15] visible_project_ids が user の membership を返す

**確認方法:**
```ruby
user = User.find(1)
controller = CacheBundlesController.new
result = controller.send(:visible_project_ids, user)
expected = user.memberships.map(&:project_id).uniq
puts result.sort == expected.sort ? 'PASS' : "FAIL: Got #{result}, expected #{expected}"
```

**期待結果:**
- user の memberships から取れる project_id の一覧と一致

---

### [1-16] fetch_per_project_memberships がロックユーザを除外する

**確認方法:**
```ruby
# 任意のプロジェクトを admin で取得し、構造のみ確認（ロックユーザがあっても無くても落ちないこと）
admin = User.find(1)
User.current = admin
controller = CacheBundlesController.new
controller.instance_variable_set(:@errors, [])
result = controller.send(:fetch_per_project_memberships, admin)
ok = result.is_a?(Hash) && result.values.all? do |members|
  members.is_a?(Array) && members.none? do |m|
    m.key?(:user) && User.find_by(id: m[:user][:id])&.status == User::STATUS_LOCKED
  end
end
puts ok ? 'PASS' : 'FAIL: locked users found in memberships'
```

**期待結果:**
- 返ってきた membership の `user` にロックユーザが含まれない

---

### [1-17] fetch_per_project_issue_categories は Active プロジェクトのみが対象

**確認方法:**
```ruby
admin = User.find(1)
User.current = admin
controller = CacheBundlesController.new
controller.instance_variable_set(:@errors, [])
result = controller.send(:fetch_per_project_issue_categories, admin)
non_active_ids = Project.where.not(status: Project::STATUS_ACTIVE).pluck(:id).map(&:to_s)
intersect = result.keys & non_active_ids
puts intersect.empty? ? 'PASS' : "FAIL: non-active project IDs found: #{intersect}"
```

**期待結果:**
- Active 以外のプロジェクト ID は project_issue_categories のキーに含まれない

---

### [1-18] with_error_handling が例外を補足し errors に記録する

**確認方法:**
```ruby
controller = CacheBundlesController.new
controller.instance_variable_set(:@errors, [])
result = controller.send(:with_error_handling, 'test_section') { raise 'boom' }
errors = controller.instance_variable_get(:@errors)
ok = result == [] && errors.size == 1 && errors[0][:section] == 'test_section' && errors[0][:code] == 500
puts ok ? 'PASS' : "FAIL: result=#{result.inspect}, errors=#{errors.inspect}"
```

**期待結果:**
- 失敗セクションは空配列で返り、errors にメタ情報が記録される

---

### [1-19] with_error_handling で markup_lang 失敗時は nil を返す

**確認方法:**
```ruby
controller = CacheBundlesController.new
controller.instance_variable_set(:@errors, [])
result = controller.send(:with_error_handling, 'markup_lang') { raise 'boom' }
puts result.nil? ? 'PASS' : "FAIL: Expected nil, got #{result.inspect}"
```

**期待結果:**
- markup_lang セクションは失敗時に nil を返す（空配列ではない）

---

## 2. HTTP テスト

**実行方法:**
PowerShell で各エンドポイントにリクエストを送信する。API キー認証が必要。

### 共通

- `{BaseUrl}` = `http://localhost:3061/redmine_61`
- `{ApiKey}` = `4897d6e90c0af122a4f3b2652796b465f0c26278`（admin の API キー）

---

### [2-1] JSON 形式でアクセス可能（200）

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.StatusCode
```

**期待結果:**
- ステータスコード 200

---

### [2-2] 拡張子なしでも 200 を返す

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/cache_bundle?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.StatusCode
```

**期待結果:**
- ステータスコード 200

---

### [2-3] Content-Type が application/json

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.Headers['Content-Type']
```

**期待結果:**
- `application/json` を含む

---

### [2-4] cache_bundle オブジェクトが含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.cache_bundle -ne $null
```

**期待結果:**
- `cache_bundle` オブジェクトが存在する

---

### [2-5] 必須セクションがすべて含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$bundle = $response.cache_bundle
$required = @('markup_lang','projects','trackers','issue_statuses','issue_priorities','time_entry_activities','queries','custom_fields','users','roles','groups','project_memberships','project_versions','project_issue_categories','errors')
$missing = $required | Where-Object { -not ($bundle.PSObject.Properties.Name -contains $_) }
$missing.Count -eq 0
```

**期待結果:**
- 必須キー（15 項目）がすべて含まれる

---

### [2-6] 成功時 errors が空配列

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.cache_bundle.errors.Count -eq 0
```

**期待結果:**
- `errors` が空配列

---

### [2-7] markup_lang が文字列

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.cache_bundle.markup_lang -is [string] -and $response.cache_bundle.markup_lang.Length -gt 0
```

**期待結果:**
- `markup_lang` が空でない文字列

---

### [2-8] projects が配列で 1 件以上

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.cache_bundle.projects.Count -gt 0
```

**期待結果:**
- `projects` に 1 件以上のプロジェクト

---

### [2-9] projects の要素に必須キーが含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$p = $response.cache_bundle.projects[0]
$p.id -ne $null -and $p.name -ne $null -and $p.identifier -ne $null -and $p.trackers -ne $null -and $p.enabled_modules -ne $null
```

**期待結果:**
- projects[0] に id/name/identifier/trackers/enabled_modules が存在する

---

### [2-10] custom_fields が admin で 1 件以上返る

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.cache_bundle.custom_fields.Count -gt 0
```

**期待結果:**
- admin で実行した場合、custom_fields に 1 件以上

---

### [2-11] users が admin で 1 件以上返る

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.cache_bundle.users.Count -gt 0
```

**期待結果:**
- admin で実行した場合、users に 1 件以上

---

### [2-12] roles に permissions が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$withPerms = $response.cache_bundle.roles | Where-Object { $_.permissions.Count -gt 0 } | Select-Object -First 1
$withPerms -ne $null
```

**期待結果:**
- permissions を含むロールが存在する

---

### [2-13] project_memberships が project_id をキーとする辞書

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$mems = $response.cache_bundle.project_memberships
$keysAreInt = $mems.PSObject.Properties.Name | ForEach-Object { [int]::TryParse($_, [ref]$null) }
($keysAreInt -notcontains $false)
```

**期待結果:**
- すべてのキーが整数文字列としてパース可能

---

### [2-14] project_versions が project_id をキーとする辞書

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$vers = $response.cache_bundle.project_versions
$keysAreInt = $vers.PSObject.Properties.Name | ForEach-Object { [int]::TryParse($_, [ref]$null) }
($keysAreInt -notcontains $false)
```

**期待結果:**
- すべてのキーが整数文字列としてパース可能

---

### [2-15] project_issue_categories が project_id をキーとする辞書

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$cats = $response.cache_bundle.project_issue_categories
$keysAreInt = $cats.PSObject.Properties.Name | ForEach-Object { [int]::TryParse($_, [ref]$null) }
($keysAreInt -notcontains $false)
```

**期待結果:**
- すべてのキーが整数文字列としてパース可能

---

### [2-16] gzip 圧縮レスポンスが返る

**確認方法:**
```powershell
# Invoke-WebRequest -Headers で Accept-Encoding を明示的に指定すると AutomaticDecompression と衝突する。
# .NET HttpWebRequest を直接使う。
$req = [System.Net.HttpWebRequest]::Create('{BaseUrl}/cache_bundle.json?user_id=1')
$req.Method = 'GET'
$req.Headers['X-Redmine-API-Key'] = '{ApiKey}'
$req.Headers['Accept-Encoding'] = 'gzip'
$req.AutomaticDecompression = [System.Net.DecompressionMethods]::None
$res = $req.GetResponse()
$enc = $res.Headers['Content-Encoding']
$res.Close()
$enc
```

**期待結果:**
- `Content-Encoding: gzip` が含まれる

---

### [2-17] 未認証でアクセスすると 401 を返す

**前提条件:** Redmine の「認証が必要」設定が有効であること。

**確認方法:**
```powershell
try {
    Invoke-WebRequest -Uri '{BaseUrl}/cache_bundle.json?user_id=1'
} catch {
    $_.Exception.Response.StatusCode
}
```

**期待結果:**
- ステータスコード 401 Unauthorized

---

### [2-18] 存在しない user_id で 422 を返す

**確認方法:**
```powershell
try {
    Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=99999' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
} catch {
    $_.Exception.Response.StatusCode
}
```

**期待結果:**
- ステータスコード 422 Unprocessable Entity（`render_api_errors` の挙動）

---

### [2-19] 非 admin が他ユーザの user_id を指定すると 422 を返す

**前提条件:** admin 以外のユーザ（例: id=2）が存在し、その API キーが取得できること。

**確認方法:**
```powershell
$nonAdminKey = '{NonAdminApiKey}'  # admin 以外のユーザの API キー
try {
    Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'=$nonAdminKey}
} catch {
    $_.Exception.Response.StatusCode
}
```

**期待結果:**
- ステータスコード 422 Unprocessable Entity

**スキップ条件:**
- 非 admin ユーザの API キーが取得できない場合

---

### [2-20] user_id 省略時は認証済みユーザがターゲットになる

**確認方法:**
```powershell
# admin の API キーで user_id 省略 → 200 が返る
$response = Invoke-WebRequest -Uri '{BaseUrl}/cache_bundle.json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.StatusCode
```

**期待結果:**
- ステータスコード 200

---

## 3. ブラウザテスト

なし（API のみの機能のため）

---

## テスト実行方法

### Runner テスト・HTTP テスト
Claude が TEST_SPEC.md の仕様に基づいてコマンドを実行し、結果を報告する。
