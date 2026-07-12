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
    "issue_priorities": [{ "id": 1, "name": "...", "active": true, "is_default": true }],
    "time_entry_activities": [{ "id": 1, "name": "...", "active": true, "is_default": true }],
    "queries": [{ "id": 1, "name": "...", "is_public": true, "project_id": 1 }],
    "custom_fields": [
      {
        "id": 1, "name": "...", "customized_type": "issue",
        "field_format": "string", "regexp": "", "min_length": null, "max_length": null,
        "is_required": false, "is_filter": false, "searchable": false,
        "multiple": false, "default_value": "", "visible": true,
        "possible_values": [{ "value": "1", "label": "選択肢A" }],
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
        "permissions": ["view_issues", "add_issues"]
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
| projects | array | target_user が可視できるプロジェクト（`Project.visible(target_user)`。SQL レベルで status IN (1, 5) が強制されるため Archived=9 は含まれない） |
| trackers | array | トラッカー |
| issue_statuses | array | チケットステータス |
| issue_priorities | array | 優先度（`IssuePriority.shared.sorted`。inactive も含む。個別 API と同じ）。要素に `active` キーあり |
| time_entry_activities | array | 作業分類（`TimeEntryActivity.shared.sorted`。inactive も含む。個別 API と同じ）。要素に `active` キーあり |
| queries | array | カスタムクエリ（user に対する visible）。`is_public` は VISIBILITY_PUBLIC のみ true（ロール限定は false） |
| custom_fields | array | カスタムフィールド（admin のみ取得）。`min_length` / `max_length` は本体 API と同じく nil を保持。`possible_values` は `{value, label}` のペア（enumeration/list どちらも対応） |
| users | array | ユーザ一覧（admin のみ取得。active な User のみ。個別 API の既定挙動と同じ） |
| roles | array | ロール（permissions 込み。文字列配列 `["view_issues", ...]`。本体 roles/:id API と同じ） |
| groups | array | グループ（admin のみ取得、users 込み） |
| project_memberships | dict | `{ project_id => [...] }` ロックユーザを除外 |
| project_versions | dict | `{ project_id => [...] }` 対象ユーザが view_issues 権限を持つプロジェクトのみ版を返す（権限が無ければ空配列。個別 API と同じゲート） |
| project_issue_categories | dict | `{ project_id => [...] }` Active プロジェクトのみ。対象ユーザが manage_categories 権限を持つプロジェクトのみカテゴリを返す（権限が無ければ空配列。個別 API と同じゲート） |
| errors | array | 部分失敗時のメタデータ。成功時は空配列 |

**非 admin ユーザの場合:**
- `custom_fields` / `users` / `groups` は空配列で返る
- `project_memberships` / `project_versions` / `project_issue_categories` は対象ユーザが member となっているプロジェクトのみ
- `project_versions` はさらに view_issues 権限を持つプロジェクトのみ（権限が無いプロジェクトは空配列）
- `project_issue_categories` はさらに manage_categories 権限を持つプロジェクトのみ（権限が無いプロジェクトは空配列）

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

### [1-7] fetch_projects が target_user 可視のプロジェクトを返す（Project.visible スコープ）

**確認方法:**
```ruby
admin = User.find(1)
User.current = admin
controller = CacheBundlesController.new
result = controller.send(:fetch_projects, admin)
expected_count = Project.visible(admin).count
puts result.size == expected_count ? 'PASS' : "FAIL: Expected #{expected_count}, got #{result.size}"
```

**期待結果:**
- `Project.visible(target_user)` と同じ件数が取得される（個別 API と同等の可視性スコープ）

---

### [1-8] fetch_projects が必須フィールドを含む

**確認方法:**
```ruby
admin = User.find(1)
User.current = admin
controller = CacheBundlesController.new
result = controller.send(:fetch_projects, admin)
sample = result.first
required = [:id, :name, :identifier, :status, :is_public, :trackers, :enabled_modules, :issue_categories, :time_entry_activities, :issue_custom_fields]
missing = required - sample.keys
puts missing.empty? ? 'PASS' : "FAIL: Missing keys: #{missing.join(', ')}"
```

**期待結果:**
- projects の各要素に必須キーが含まれる

---

### [1-8-2] fetch_projects の埋め込み includes が個別 API (render_api_includes) と一致する

`issue_custom_fields` は `all_issue_custom_fields`（is_for_all 込み）、`time_entry_activities` は
`activities`（アクティブのみ）、`trackers` は `rolled_up_trackers(false).visible(対象ユーザ)` と揃える。

**確認方法:**
```ruby
admin = User.find(1)
User.current = admin
controller = CacheBundlesController.new
result = controller.send(:fetch_projects, admin)

ok = true
Project.visible(admin).each do |p|
  row = result.find { |h| h[:id] == p.id }
  next if row.nil?
  cf = row[:issue_custom_fields].map { |x| x[:id] }.sort
  exp_cf = p.all_issue_custom_fields.map(&:id).sort
  act = row[:time_entry_activities].map { |x| x[:id] }.sort
  exp_act = p.activities.map(&:id).sort
  tr = row[:trackers].map { |x| x[:id] }.sort
  exp_tr = p.rolled_up_trackers(false).visible(admin).map(&:id).sort
  if cf != exp_cf || act != exp_act || tr != exp_tr
    ok = false
    puts "FAIL project=#{p.id} cf=#{cf}/#{exp_cf} act=#{act}/#{exp_act} tr=#{tr}/#{exp_tr}"
  end
end
puts ok ? 'PASS' : 'FAIL: 埋め込み includes が render_api_includes と不一致'
```

**期待結果:**
- 各プロジェクトの `issue_custom_fields` / `time_entry_activities` / `trackers` が個別 API と一致する（is_for_all CF を含み、inactive activity を含まず、trackers は view_issues 可視性で絞られる）

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

### [1-10] fetch_issue_priorities が shared.sorted（inactive 含む）を返す

**確認方法:**
```ruby
controller = CacheBundlesController.new
result = controller.send(:fetch_issue_priorities)
expected_count = IssuePriority.shared.count
puts result.size == expected_count ? 'PASS' : "FAIL: Expected #{expected_count}, got #{result.size}"
```

**期待結果:**
- `IssuePriority.shared`（inactive 含む）と同じ件数（個別 enumerations API と同等）

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

### [1-13-2] fetch_groups はビルトイングループを除外する

個別 API (GET /groups.json) は builtin=1 指定時以外ビルトイングループ（Anonymous / Non member）を除外する。
cache_bundle も `Group.givable` に揃える。

**確認方法:**
```ruby
User.current = User.where(admin: true).first
controller = CacheBundlesController.new
result = controller.send(:fetch_groups)
ids = result.map { |g| g[:id] }
builtin_ids = Group.where.not(type: 'Group').pluck(:id)
overlap = ids & builtin_ids
puts overlap.empty? ? 'PASS' : "FAIL: builtin group(s) included: #{overlap}"
```

**期待結果:**
- 返却されるグループにビルトイングループ（type != 'Group'）が含まれない

---

### [1-14] fetch_roles の permissions が文字列配列である

**確認方法:**
```ruby
controller = CacheBundlesController.new
result = controller.send(:fetch_roles)
sample = result.find { |r| r[:permissions].is_a?(Array) && r[:permissions].any? }
if sample.nil?
  puts 'FAIL: No role with permissions found'
else
  all_strings = sample[:permissions].all? { |p| p.is_a?(String) }
  puts all_strings ? 'PASS' : "FAIL: permissions contain non-string values: #{sample[:permissions].map(&:class).uniq.inspect}"
end
```

**期待結果:**
- permissions を含むロールが存在し、各 permission が文字列（例: `"view_issues"`）である（本体 roles/:id API と同じ形式）

---

### [1-14-2] fetch_roles はビルトインロールを除外する

個別 API (GET /roles.json) はビルトインロール（Non member / Anonymous）を除外する（`Role.givable`）。
cache_bundle も揃える。

**確認方法:**
```ruby
controller = CacheBundlesController.new
result = controller.send(:fetch_roles)
ids = result.map { |r| r[:id] }
builtin_ids = Role.where.not(builtin: 0).pluck(:id)
overlap = ids & builtin_ids
puts overlap.empty? ? 'PASS' : "FAIL: builtin role(s) included: #{overlap}"
```

**期待結果:**
- 返却されるロールにビルトインロール（builtin != 0）が含まれない

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

### [1-16-2] fetch_per_project_versions は view_issues 権限で出し分ける

個別 API (GET /projects/:id/versions.json) はコアで view_issues 権限を要求する（versions#index は view_issues 配下）。
cache_bundle でも対象ユーザが権限を持たないプロジェクトは空配列で返す（過剰露出の是正）。

**確認方法:**
```ruby
controller = CacheBundlesController.new
controller.instance_variable_set(:@errors, [])

# 版を持つプロジェクトの中から、view_issues を「持つ member」と「持たない member」を探す
target = nil
Project.where(status: Project::STATUS_ACTIVE).each do |p|
  next if Version.where(project_id: p.id).empty?
  members = p.members.map(&:user).select { |u| u.is_a?(User) && u.status == User::STATUS_ACTIVE }
  with_perm    = members.find { |u|  u.allowed_to?(:view_issues, p) }
  without_perm = members.find { |u| !u.allowed_to?(:view_issues, p) }
  if with_perm && without_perm
    target = [p, with_perm, without_perm]; break
  end
end

if target.nil?
  puts 'SKIP: view_issues 権限の有無で分かれる member を持つプロジェクトが無い'
else
  p, with_perm, without_perm = target
  res_with    = controller.send(:fetch_per_project_versions, with_perm)
  res_without = controller.send(:fetch_per_project_versions, without_perm)
  ok = res_with[p.id.to_s].present? && res_without[p.id.to_s] == []
  puts ok ? 'PASS' : "FAIL: with=#{res_with[p.id.to_s].inspect} without=#{res_without[p.id.to_s].inspect}"
end
```

**期待結果:**
- view_issues を持つユーザ: 当該プロジェクトの版が全件返る
- view_issues を持たないユーザ: 当該プロジェクトは空配列（キーは存在する）

---

### [1-16-3] fetch_per_project_versions は Version のカスタムフィールド値を出力する

個別 API (GET /projects/:id/versions.json) は `render_api_custom_values` で対象ユーザに可視な
Version のカスタムフィールド値を返す。cache_bundle でも同じ値を同じ形（単一値はスカラー、複数値は
配列＋`multiple`）で返し、個別経路と cache_bundle 経路の CacheBundle を完全一致させる。

**確認方法:**
```ruby
controller = CacheBundlesController.new
controller.instance_variable_set(:@errors, [])

# 可視な CF 値を持つ Version と、その版が見えるユーザを探す
target = nil
Version.all.each do |v|
  next if v.visible_custom_field_values.reject { |cv| cv.value.blank? }.empty?
  u = v.project.members.map(&:user).find { |m| m.is_a?(User) && m.allowed_to?(:view_issues, v.project) }
  (target = [v, u]; break) if u
end

if target.nil?
  puts 'SKIP: 可視な CF 値を持つ Version が無い（setup_cache_bundle_equiv_testdata.rb 未投入）'
else
  v, u = target
  res = controller.send(:fetch_per_project_versions, u)
  row = res[v.project_id.to_s].find { |r| r[:id] == v.id }
  ok  = row[:custom_fields].present? && row[:custom_fields].all? { |cf| cf.key?(:id) && cf.key?(:name) && cf.key?(:value) }
  puts ok ? 'PASS' : "FAIL: #{row[:custom_fields].inspect}"
end
```

**期待結果:**
- CF 値を持つ Version の行に `custom_fields` が含まれ、各要素が `{id, name, value}`（複数値時は `multiple: true` と value 配列）である
- CF 値が無い Version は `custom_fields` キーを持たない（個別 API の `unless custom_values.empty?` と同じ）

---

### [1-16-4] fetch_projects は対象ユーザに不可視な親を出力しない（parent 可視性ゲート）

個別 API (projects/index.api.rsb) は `parent.visible?` のときだけ `parent` を出力する。
cache_bundle でも対象ユーザに不可視な親（private な親等）の名前を漏らさないよう可視性でゲートする。

**確認方法:**
```ruby
controller = CacheBundlesController.new

# 親が「見えるユーザ」と「見えないユーザ」で出し分くプロジェクトを探す
target = nil
Project.where.not(parent_id: nil).each do |c|
  members = c.members.map(&:user).select { |m| m.is_a?(User) }
  seer   = members.find { |m|  c.parent.visible?(m) }
  hidden = members.find { |m| !c.parent.visible?(m) }
  (target = [c, seer, hidden]; break) if seer && hidden
end

if target.nil?
  puts 'SKIP: 親可視性が分かれる member を持つ子プロジェクトが無い（setup_cache_bundle_equiv_testdata.rb 未投入）'
else
  c, seer, hidden = target
  row_seer   = controller.send(:fetch_projects, seer).find   { |r| r[:id] == c.id }
  row_hidden = controller.send(:fetch_projects, hidden).find { |r| r[:id] == c.id }
  ok = row_seer[:parent].present? && !row_hidden.key?(:parent)
  puts ok ? 'PASS' : "FAIL: seer=#{row_seer[:parent].inspect} hidden=#{row_hidden[:parent].inspect}"
end
```

**期待結果:**
- 親が可視なユーザ: 子プロジェクトの行に `parent` が含まれる
- 親が不可視なユーザ: 子プロジェクトの行に `parent` キーが含まれない（親名を漏らさない）

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

### [1-17-2] fetch_per_project_issue_categories は manage_categories 権限で出し分ける

個別 API (GET /projects/:id/issue_categories.json) はコアで manage_categories 権限を要求するため、
cache_bundle でも対象ユーザが権限を持たないプロジェクトは空配列で返す（過剰露出の是正）。

**確認方法:**
```ruby
controller = CacheBundlesController.new
controller.instance_variable_set(:@errors, [])

# カテゴリを持つ Active プロジェクトの中から、manage_categories を「持つ member」と「持たない member」を探す
target = nil
Project.where(status: Project::STATUS_ACTIVE).each do |p|
  next if IssueCategory.where(project_id: p.id).empty?
  members = p.members.map(&:user).select { |u| u.is_a?(User) && u.status == User::STATUS_ACTIVE }
  with_perm    = members.find { |u|  u.allowed_to?(:manage_categories, p) }
  without_perm = members.find { |u| !u.allowed_to?(:manage_categories, p) }
  if with_perm && without_perm
    target = [p, with_perm, without_perm]; break
  end
end

if target.nil?
  puts 'SKIP: manage_categories 権限の有無で分かれる member を持つプロジェクトが無い'
else
  p, with_perm, without_perm = target
  res_with    = controller.send(:fetch_per_project_issue_categories, with_perm)
  res_without = controller.send(:fetch_per_project_issue_categories, without_perm)
  ok = res_with[p.id.to_s].present? && res_without[p.id.to_s] == []
  puts ok ? 'PASS' : "FAIL: with=#{res_with[p.id.to_s].inspect} without=#{res_without[p.id.to_s].inspect}"
end
```

**期待結果:**
- manage_categories を持つユーザ: 当該プロジェクトのカテゴリが全件返る
- manage_categories を持たないユーザ: 当該プロジェクトは空配列（キーは存在する）

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

### [1-20] fetch_projects で Archived プロジェクトが含まれない

**確認方法:**
```ruby
# Archived プロジェクトが 1 件以上あることを前提にテスト。無ければテスト用に 1 件作る。
archived = Project.where(status: Project::STATUS_ARCHIVED).first
unless archived
  p = Project.new(name: 'CacheBundle_1-20_Archived', identifier: "cbtest_1_20_#{Time.now.to_i}")
  p.save(validate: false)
  p.update_column(:status, Project::STATUS_ARCHIVED)
  archived = p
end

admin = User.find(1)
User.current = admin
controller = CacheBundlesController.new
result = controller.send(:fetch_projects, admin)
archived_ids_in_result = result.map { |h| h[:id] } & Project.where(status: Project::STATUS_ARCHIVED).pluck(:id)
puts archived_ids_in_result.empty? ? 'PASS' : "FAIL: Archived project IDs found: #{archived_ids_in_result}"
```

**期待結果:**
- レスポンスに status=9 (Archived) のプロジェクトが含まれない（`Project.visible` が SQL レベルで status IN (1, 5) を強制する）

---

### [1-21] fetch_issue_priorities に active キーが含まれる

**確認方法:**
```ruby
controller = CacheBundlesController.new
result = controller.send(:fetch_issue_priorities)
sample = result.first
puts sample.key?(:active) ? 'PASS' : "FAIL: :active key missing. keys=#{sample.keys.inspect}"
```

**期待結果:**
- 各要素に `active` キーが存在する（本体 enumerations API と同じ）

---

### [1-22] fetch_time_entry_activities が shared.sorted（inactive 含む）を返す

**確認方法:**
```ruby
controller = CacheBundlesController.new
result = controller.send(:fetch_time_entry_activities)
expected_count = TimeEntryActivity.shared.count
puts result.size == expected_count ? 'PASS' : "FAIL: Expected #{expected_count}, got #{result.size}"
```

**期待結果:**
- `TimeEntryActivity.shared`（inactive 含む）と同じ件数

---

### [1-23] fetch_time_entry_activities に active キーが含まれる

**確認方法:**
```ruby
controller = CacheBundlesController.new
result = controller.send(:fetch_time_entry_activities)
sample = result.first
puts sample.key?(:active) ? 'PASS' : "FAIL: :active key missing. keys=#{sample.keys.inspect}"
```

**期待結果:**
- 各要素に `active` キーが存在する

---

### [1-24] fetch_queries の is_public は VISIBILITY_PUBLIC のみ true

**確認方法:**
```ruby
admin = User.find(1)
User.current = admin
controller = CacheBundlesController.new
result = controller.send(:fetch_queries, admin)

# 期待: 元 IssueQuery.visible の各 query について、visibility == PUBLIC のときのみ is_public=true
mismatches = []
IssueQuery.visible(admin).each do |q|
  h = result.find { |x| x[:id] == q.id }
  next unless h
  expected = (q.visibility == IssueQuery::VISIBILITY_PUBLIC)
  actual = h[:is_public]
  mismatches << { id: q.id, name: q.name, visibility: q.visibility, expected: expected, actual: actual } if expected != actual
end
puts mismatches.empty? ? 'PASS' : "FAIL: is_public mismatch: #{mismatches.inspect}"
```

**期待結果:**
- 全 query について `is_public == (visibility == VISIBILITY_PUBLIC)`（VISIBILITY_ROLES / PRIVATE は false）

---

### [1-25] fetch_custom_fields の min_length / max_length が nil を保持する

**確認方法:**
```ruby
admin = User.find(1)
User.current = admin
controller = CacheBundlesController.new
result = controller.send(:fetch_custom_fields)

# テスト対象: min_length と max_length が nil のカスタムフィールド
nil_length_cfs = CustomField.where(min_length: nil, max_length: nil).limit(3).to_a
if nil_length_cfs.empty?
  puts 'SKIP: no custom field with nil min_length/max_length'
else
  problems = []
  nil_length_cfs.each do |cf|
    h = result.find { |x| x[:id] == cf.id }
    problems << { id: cf.id, min_length: h[:min_length], max_length: h[:max_length] } if h && (h[:min_length] != nil || h[:max_length] != nil)
  end
  puts problems.empty? ? 'PASS' : "FAIL: nil should be preserved (not 0): #{problems.inspect}"
end
```

**期待結果:**
- min_length / max_length が nil の CustomField は、レスポンスでも nil を保持する（本体 custom_fields API と同じ挙動。`|| 0` 変換をしない）

---

### [1-26] fetch_custom_fields の possible_values に value と label が含まれる

**確認方法:**
```ruby
admin = User.find(1)
User.current = admin
controller = CacheBundlesController.new
result = controller.send(:fetch_custom_fields)

# possible_values を持つ CF の最初の 1 件で確認
cf_with_values = result.find { |h| h[:possible_values].is_a?(Array) && h[:possible_values].any? }
if cf_with_values.nil?
  puts 'SKIP: no custom field with possible_values'
else
  sample = cf_with_values[:possible_values].first
  ok = sample.key?(:value) && sample.key?(:label)
  puts ok ? 'PASS' : "FAIL: possible_values entry missing :value or :label. sample=#{sample.inspect}"
end
```

**期待結果:**
- possible_values の各要素に `value` と `label` の両方のキーが存在する（enumeration/list どちらも対応する本体 API 準拠形式）

---

### [1-27] fetch_users は active なユーザのみを返す

**確認方法:**
```ruby
admin = User.find(1)
User.current = admin
controller = CacheBundlesController.new
result = controller.send(:fetch_users)

# Locked (status=3) や Registered (status=2) のユーザが含まれないこと
non_active_ids = User.where(type: 'User').where.not(status: User::STATUS_ACTIVE).pluck(:id)
result_ids = result.map { |u| u[:id] }
leaked = result_ids & non_active_ids
puts leaked.empty? ? 'PASS' : "FAIL: non-active user IDs leaked: #{leaked}"
```

**期待結果:**
- レスポンスに含まれる user がすべて active（status=1）である（個別 users API の既定挙動と同じ）

---

### [1-28] fetch_roles の permissions が文字列配列（形式検証・詳細）

**確認方法:**
```ruby
controller = CacheBundlesController.new
result = controller.send(:fetch_roles)

# すべてのロールの permissions を検査
bad_roles = result.reject { |r| r[:permissions].is_a?(Array) && r[:permissions].all? { |p| p.is_a?(String) } }
puts bad_roles.empty? ? 'PASS' : "FAIL: bad permissions in roles: #{bad_roles.map { |r| { id: r[:id], name: r[:name], permissions: r[:permissions] } }.inspect}"
```

**期待結果:**
- すべてのロールの `permissions` が「文字列の配列」である（`{info: '...'}` 形式ではない）

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

### [2-12] roles の permissions が文字列配列である

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$withPerms = $response.cache_bundle.roles | Where-Object { $_.permissions.Count -gt 0 } | Select-Object -First 1
if ($null -eq $withPerms) { $false } else {
  # 各要素が string であることを検証（旧形式の {info: '...'} オブジェクトでは PSCustomObject になる）
  $allStrings = ($withPerms.permissions | ForEach-Object { $_ -is [string] }) -notcontains $false
  $allStrings
}
```

**期待結果:**
- permissions を含むロールが存在し、各 permission が文字列（例: `"view_issues"`）である（旧形式 `{info: '...'}` ではないこと）

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

### [2-17] 存在しない user_id で 422 を返す

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

### [2-18] 非 admin が他ユーザの user_id を指定すると 422 を返す

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

### [2-19] user_id 省略時は認証済みユーザがターゲットになる

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
