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
| 認証 | ログイン必須（本体の `login_required` 設定に関わらず一律。未認証は 401）。`before_action :require_login`（`accept_api_auth :show` と併用で API キー認証も可） |
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
| custom_fields | array | カスタムフィールド。admin は全件、非 admin は `CustomField.visible`（visible=true の CF＋自分のロールに紐づく role 限定 CF）。`min_length` / `max_length` は本体 API と同じく nil を保持。`possible_values` は `{value, label}` のペア（enumeration/list どちらも対応） |
| users | array | ユーザ一覧。admin は全 active User、非 admin は `User.visible`（自分＋可視プロジェクトのメンバー、または users_visibility='all' ロールで全 active）。匿名ユーザは除外 |
| roles | array | ロール（permissions 込み。文字列配列 `["view_issues", ...]`。本体 roles/:id API と同じ） |
| groups | array | グループ（users 込み）。admin は全 givable、非 admin は `Group.givable.visible`。非 admin のメンバーは可視ユーザ集合と交差（不可視ユーザを漏らさない） |
| project_memberships | dict | `{ project_id => [...] }` ロックユーザを除外 |
| project_versions | dict | `{ project_id => [...] }` 対象ユーザが view_issues 権限を持つプロジェクトのみ版を返す（権限が無ければ空配列。個別 API と同じゲート） |
| project_issue_categories | dict | `{ project_id => [...] }` Active プロジェクトのみ。対象ユーザが manage_categories 権限を持つプロジェクトのみカテゴリを返す（権限が無ければ空配列。個別 API と同じゲート） |
| errors | array | 部分失敗時のメタデータ。成功時は空配列 |

**非 admin ユーザの場合:**
- `custom_fields` は `CustomField.visible` に絞られる（visible=false かつ自分のロールに紐づかない role 限定 CF は出ない）
- `users` は `User.visible` に絞られる（users_visibility='all' ロールを持たない限り、自分＋可視プロジェクトのメンバーのみ）
- `groups` は `Group.givable.visible` に絞られ、各グループのメンバーも可視ユーザ集合と交差される
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
Redmine 7.0 以降はコアの個別 API が include を権限でゲートするため（`issue_categories` /
`issue_custom_fields` は `view_issues`、`time_entry_activities` は `view_time_entries`）、期待値も
同じゲートを掛ける（権限が無いプロジェクトは空配列。6.1 以前は無ゲートで常に返す）。

**確認方法:**
```ruby
admin = User.find(1)
User.current = admin
controller = CacheBundlesController.new
result = controller.send(:fetch_projects, admin)

gate = Redmine::VERSION::MAJOR >= 7 # 7.0 以降のみコアが include を権限でゲートする
ok = true
Project.visible(admin).each do |p|
  row = result.find { |h| h[:id] == p.id }
  next if row.nil?
  cf = row[:issue_custom_fields].map { |x| x[:id] }.sort
  exp_cf = (gate && !admin.allowed_to?(:view_issues, p)) ? [] : p.all_issue_custom_fields.map(&:id).sort
  act = row[:time_entry_activities].map { |x| x[:id] }.sort
  exp_act = (gate && !admin.allowed_to?(:view_time_entries, p)) ? [] : p.activities.map(&:id).sort
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
- 各プロジェクトの `issue_custom_fields` / `time_entry_activities` / `trackers` が個別 API と一致する（is_for_all CF を含み、inactive activity を含まず、trackers は view_issues 可視性で絞られる）。7.0 以降は権限の無いプロジェクトで該当 include が空配列になる

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

### [1-11] fetch_custom_fields は non-admin で CustomField.visible に一致する

非 admin は `CustomField.visible`（visible=true の CF＋自分のロールに紐づく role 限定 CF）に絞る。

**確認方法:**
```ruby
# 可視性が制限された非 admin（全件が見えるユーザだと制限を行使できないため CustomField.visible < 全件 を選ぶ）
non_admin = User.where(admin: false, type: 'User', status: User::STATUS_ACTIVE).detect do |u|
  CustomField.visible(u).count < CustomField.count
end
non_admin ||= User.where(admin: false, type: 'User', status: User::STATUS_ACTIVE).first
unless non_admin
  puts 'SKIP: no non-admin user available'
else
  User.current = non_admin
  controller = CacheBundlesController.new
  result_ids = controller.send(:fetch_custom_fields).map { |h| h[:id] }.sort
  expected_ids = CustomField.visible(non_admin).pluck(:id).sort
  puts result_ids == expected_ids ? 'PASS' : "FAIL: got #{result_ids}, expected #{expected_ids}"
end
```

**期待結果:**
- 非 admin の custom_fields が `CustomField.visible(non_admin)` と id 集合まで一致する（visible=false かつ非該当ロールの CF は出ない）

---

### [1-12] fetch_users は non-admin で User.visible に一致する

非 admin は `User.visible`（自分＋可視プロジェクトのメンバー、または users_visibility='all' ロールで全 active）に絞る。

**確認方法:**
```ruby
total = User.where(type: 'User', status: User::STATUS_ACTIVE).count
non_admin = User.where(admin: false, type: 'User', status: User::STATUS_ACTIVE).detect do |u|
  User.visible(u).where(type: 'User').count < total
end
non_admin ||= User.where(admin: false, type: 'User', status: User::STATUS_ACTIVE).first
unless non_admin
  puts 'SKIP: no non-admin user available'
else
  User.current = non_admin
  controller = CacheBundlesController.new
  result_ids = controller.send(:fetch_users).map { |h| h[:id] }.sort
  expected_ids = User.visible(non_admin).where(type: 'User').pluck(:id).sort
  puts result_ids == expected_ids ? 'PASS' : "FAIL: got #{result_ids.size} ids, expected #{expected_ids.size} (#{(expected_ids - result_ids).inspect} / #{(result_ids - expected_ids).inspect})"
end
```

**期待結果:**
- 非 admin の users が `User.visible(non_admin)`（type='User'）と id 集合まで一致する

---

### [1-13] fetch_groups は non-admin で Group.givable.visible に一致する

非 admin は `Group.givable.visible` に絞り、各グループのメンバーも可視ユーザ集合と交差する。

**確認方法:**
```ruby
non_admin = User.where(admin: false, type: 'User', status: User::STATUS_ACTIVE).detect do |u|
  Group.givable.visible(u).count < Group.givable.count
end
non_admin ||= User.where(admin: false, type: 'User', status: User::STATUS_ACTIVE).first
unless non_admin
  puts 'SKIP: no non-admin user available'
else
  User.current = non_admin
  controller = CacheBundlesController.new
  result = controller.send(:fetch_groups)
  result_ids = result.map { |h| h[:id] }.sort
  expected_ids = Group.givable.visible(non_admin).pluck(:id).sort
  # メンバーが可視ユーザ集合の部分集合であること（不可視ユーザを漏らさない）
  visible_uids = User.visible(non_admin).where(type: 'User').pluck(:id).to_set
  leaked = result.flat_map { |h| h[:users].map { |u| u[:id] } }.reject { |id| visible_uids.include?(id) }
  ok = result_ids == expected_ids && leaked.empty?
  puts ok ? 'PASS' : "FAIL: ids got #{result_ids}/exp #{expected_ids}, leaked_members=#{leaked.inspect}"
end
```

**期待結果:**
- 非 admin の groups が `Group.givable.visible(non_admin)` と id 集合まで一致し、各グループのメンバーが可視ユーザ集合の部分集合（不可視ユーザを漏らさない）

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

### [1-29] fetch_custom_fields は role 限定・不可視 CF を保持ロールの有無で出し分ける

`CustomField.visible` は「visible=true」または「そのユーザのロールに紐づく role 限定 CF」のみ返す。
admin は全件。visible=false かつ特定ロール限定の CF が、保持しない非 admin には出ず、admin には出ることを確認する。

**確認方法:**
```ruby
# visible=false かつ role 限定の CF を対象にする（無ければ SKIP）
gated_cf = CustomField.where(visible: false).detect { |cf| cf.roles.any? }
if gated_cf.nil?
  puts 'SKIP: visible=false かつ role 限定の CF が無い（setup_cache_bundle_equiv_testdata.rb 未投入）'
else
  gated_role_ids = gated_cf.roles.map(&:id)
  # その CF のロールを保持しない非 admin を探す
  non_holder = User.where(admin: false, type: 'User', status: User::STATUS_ACTIVE).detect do |u|
    (u.memberships.flat_map { |m| m.roles.map(&:id) } & gated_role_ids).empty?
  end
  controller = CacheBundlesController.new

  User.current = User.where(admin: true).first
  admin_has = controller.send(:fetch_custom_fields).any? { |h| h[:id] == gated_cf.id }

  if non_holder.nil?
    puts admin_has ? 'PASS (admin only; 非保持ユーザ不在で SKIP)' : "FAIL: admin should see gated CF #{gated_cf.id}"
  else
    User.current = non_holder
    non_holder_has = CacheBundlesController.new.send(:fetch_custom_fields).any? { |h| h[:id] == gated_cf.id }
    ok = admin_has && !non_holder_has
    puts ok ? 'PASS' : "FAIL: admin_has=#{admin_has}, non_holder(#{non_holder.login})_has=#{non_holder_has}"
  end
end
```

**期待結果:**
- admin: role 限定・不可視 CF が含まれる
- ロールを保持しない非 admin: 当該 CF が含まれない（`CustomField.visible` の role 分岐と一致）

---

### [1-30] fetch_users は可視プロジェクト外のユーザを漏らさない

`users_visibility='all'` ロールを持たない非 admin に対し、`User.visible` は「自分＋可視プロジェクトのメンバー」に絞る。
その非 admin と共有プロジェクトを持たないユーザが fetch_users に出ないことを確認する。

**確認方法:**
```ruby
total = User.where(type: 'User', status: User::STATUS_ACTIVE).count
restricted = User.where(admin: false, type: 'User', status: User::STATUS_ACTIVE).detect do |u|
  User.visible(u).where(type: 'User').count < total
end
if restricted.nil?
  puts 'SKIP: 可視性が制限された非 admin が無い（全員 users_visibility=all）'
else
  User.current = restricted
  result_ids = CacheBundlesController.new.send(:fetch_users).map { |h| h[:id] }.to_set
  # コアの可視集合の外にいる active ユーザ（本来見えないはず）
  hidden = User.where(type: 'User', status: User::STATUS_ACTIVE).pluck(:id) - User.visible(restricted).where(type: 'User').pluck(:id)
  leaked = hidden.select { |id| result_ids.include?(id) }
  # 自分は必ず含まれる（self 参照のフォールバック安全性）
  self_ok = result_ids.include?(restricted.id)
  ok = leaked.empty? && self_ok && hidden.any?
  puts ok ? "PASS (restricted=#{restricted.login}, hidden #{hidden.size} 件を非表示)" : "FAIL: leaked=#{leaked.inspect}, self_ok=#{self_ok}, hidden=#{hidden.size}"
end
```

**期待結果:**
- 可視プロジェクト外の active ユーザ（`hidden`）が 1 件以上あり、そのいずれも fetch_users に含まれない
- 自分自身は必ず含まれる

---

### [1-31] fetch_custom_fields のクエリ本数が CF 件数に比例しない（roles/trackers バッチ化）

roles は `preload(:roles)`、trackers は issue CF の id→trackers 辞書で一括取得するため、
CF 件数 N に対して発行クエリが `O(1)`（`1 + 2N` にならない）ことを確認する。

**確認方法:**
```ruby
User.current = User.where(admin: true).first
controller = CacheBundlesController.new
cf_count = CustomField.count

sql_count = 0
counter = ->(_name, _start, _finish, _id, payload) do
  sql_count += 1 unless payload[:name] =~ /SCHEMA|TRANSACTION/ || payload[:sql] =~ /^\s*(BEGIN|COMMIT|RELEASE|SAVEPOINT)/i
end
ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
  controller.send(:fetch_custom_fields)
end

# 上限は「本体集合1 + roles preload1 + issue CF別読み1 + trackers preload1 + enumeration系の余裕」を見て固定値に。
# CF 件数比例（1 + 2N）なら cf_count=10 で 20 本超になるため、それを大きく下回ることを確認。
threshold = 10
puts sql_count <= threshold ? "PASS (queries=#{sql_count} for #{cf_count} CFs)" : "FAIL: queries=#{sql_count} > #{threshold} (CF件数比例の疑い)"
```

**期待結果:**
- 発行クエリ本数が CF 件数に比例せず、固定的な少数（閾値 10 以下）に収まる（旧 `respond_to?(:trackers)`/`roles.any?` の per-CF N+1 が解消されている）

---

### [1-32] fetch_custom_fields は admin で全件＋trackers/roles を返す（回帰）

スコープ化後も admin 経路は全 CF を返し、trackers（issue CF）と roles を正しく直列化することを確認する。

**確認方法:**
```ruby
User.current = User.where(admin: true).first
controller = CacheBundlesController.new
result = controller.send(:fetch_custom_fields)

count_ok = result.size == CustomField.count

# trackers: issue CF で trackers を持つものが正しく出るか
icf = IssueCustomField.joins(:trackers).first
tr_ok = if icf
  row = result.find { |h| h[:id] == icf.id }
  row && row[:trackers].map { |t| t[:id] }.sort == icf.trackers.map(&:id).sort
else
  true
end

# roles: role を持つ CF が正しく出るか
rcf = CustomField.joins(:roles).first
role_ok = if rcf
  row = result.find { |h| h[:id] == rcf.id }
  row && row[:roles].map { |r| r[:id] }.sort == rcf.roles.map(&:id).sort
else
  true
end

puts (count_ok && tr_ok && role_ok) ? 'PASS' : "FAIL: count_ok=#{count_ok}(#{result.size}/#{CustomField.count}) tr_ok=#{tr_ok} role_ok=#{role_ok}"
```

**期待結果:**
- admin では全 CF が返り、trackers を持つ issue CF・roles を持つ CF が個別関連と id 集合まで一致する

---

### [1-33] admin は 3 セクションを全件母集団で返す（メンバー無交差）

admin 経路は users=全 active User、groups=全 givable Group（各グループのメンバーは交差せず全件）、
custom_fields=全 CustomField を返す。非 admin のスコープ絞り込みが admin に漏れていないことを、
件数の完全一致で固定する（[1-27]/[1-32] の補完）。

**確認方法:**
```ruby
User.current = User.where(admin: true).first
c = CacheBundlesController.new

users_full  = c.send(:fetch_users).map { |h| h[:id] }.sort == User.where(type: 'User', status: User::STATUS_ACTIVE).pluck(:id).sort
groups_full = c.send(:fetch_groups).map { |g| g[:id] }.sort == Group.givable.pluck(:id).sort
cf_full     = c.send(:fetch_custom_fields).size == CustomField.count

# admin の各グループのメンバーは交差せず全件（g.users と一致）
g = Group.givable.detect { |x| x.users.any? }
members_full = g.nil? || (c.send(:fetch_groups).find { |h| h[:id] == g.id }[:users].map { |u| u[:id] }.sort == g.users.map(&:id).sort)

puts (users_full && groups_full && cf_full && members_full) ? 'PASS' : "FAIL: users=#{users_full} groups=#{groups_full} cf=#{cf_full} members=#{members_full}"
```

**期待結果:**
- admin の users / groups / custom_fields が全件母集団と一致し、各グループのメンバーも交差されず全件

---

### [1-34] スコープ基準は `User.current`（要求者）であり `target_user` ではない（モード① 維持）

管理者キーで別ユーザ（`user_id=N`）のバンドルを作る運用（モード①）では、users / custom_fields / groups は
**要求者（admin）の権限で全件**返る（`target_user` にスコープしない）。この契約を固定し、将来 `fetch_*` を
`target_user` 基準へ変えたら赤くなるようにする。

**確認方法:**
```ruby
admin = User.where(admin: true).first
# 可視性が制限された非 admin を target にする（target 基準にスコープしていたら件数が減るはず）
total = User.where(type: 'User', status: User::STATUS_ACTIVE).count
target = User.where(admin: false, type: 'User', status: User::STATUS_ACTIVE).detect do |u|
  User.visible(u).where(type: 'User').count < total
end
if target.nil?
  puts 'SKIP: 可視性が制限された非 admin が無い'
else
  # show と同じ経路: 認証済み=admin（User.current）、target_user=制限ユーザ
  User.current = admin
  c = CacheBundlesController.new
  users_cnt  = c.send(:fetch_users).size
  cf_cnt     = c.send(:fetch_custom_fields).size
  groups_cnt = c.send(:fetch_groups).size
  ok = users_cnt == total && cf_cnt == CustomField.count && groups_cnt == Group.givable.count
  puts ok ? "PASS (admin 基準で全件: users=#{users_cnt} cf=#{cf_cnt} groups=#{groups_cnt})" : "FAIL: users=#{users_cnt}/#{total} cf=#{cf_cnt}/#{CustomField.count} groups=#{groups_cnt}/#{Group.givable.count}"
end
```

**期待結果:**
- 制限ユーザが存在する環境で、admin が実行する限り users / custom_fields / groups は全件（`User.current` 基準）。target_user 基準に退行したら件数が減って FAIL する

---

### [1-35] N+1 バッチ化はコアの per-project 版と等価（projects / memberships / versions / issue_categories）

projects の埋め込み（activities / issue_custom_fields / parent）と per-project 3 種を「まとめて 1 クエリ＋group_by/preload」で
畳んだ結果が、コアの per-project メソッド（`Project#activities` / `#all_issue_custom_fields` / `parent.visible?` /
per-pid の `Member`・`Version`・`IssueCategory` ＋各ハッシュ生成ヘルパ）と**完全一致**することを、同一 DB で突き合わせる。
コア側の仕様変更で赤くなる契約テスト（#2797 規律）。

**確認方法:**
```ruby
# admin と、複数プロジェクトの member 非 admin を対象にする
targets = [User.find(1)]
mu = User.where(admin: false, type: 'User', status: User::STATUS_ACTIVE).detect { |u| u.memberships.map(&:project_id).uniq.size >= 2 }
targets << mu if mu

gate = Redmine::VERSION::MAJOR >= 7 # 7.0 以降のみコアが projects の include を権限でゲートする
bad = []
targets.each do |user|
  User.current = user
  c = CacheBundlesController.new
  c.instance_variable_set(:@errors, [])

  # projects: activities / issue_custom_fields / parent の等価
  batched = c.send(:fetch_projects, user)
  Project.visible(user).sorted.each do |p|
    row = batched.find { |h| h[:id] == p.id }
    act = row[:time_entry_activities].map { |x| x[:id] }.sort
    cf  = row[:issue_custom_fields].map { |x| x[:id] }.sort
    par = row[:parent] && row[:parent][:id]
    exp_par = (p.parent && p.parent.visible?(user)) ? p.parent.id : nil
    # 7.0 以降はコアが activities/custom_fields を権限でゲートするため期待値も同じゲートを掛ける
    exp_act = (gate && !user.allowed_to?(:view_time_entries, p)) ? [] : p.activities.map(&:id).sort
    exp_cf  = (gate && !user.allowed_to?(:view_issues, p)) ? [] : p.all_issue_custom_fields.map(&:id).sort
    bad << "proj p=#{p.id}(#{user.login})" if act != exp_act || cf != exp_cf || par != exp_par
  end

  # memberships / versions / issue_categories: バッチ vs per-pid（同一ハッシュ生成ヘルパで突き合わせ）
  pids = c.send(:visible_project_ids, user)
  mb = c.send(:fetch_per_project_memberships, user)
  pids.each do |pid|
    ref = Member.where(project_id: pid).preload(:user, :principal, :roles, :member_roles, :project).map { |m| c.send(:membership_to_hash, m) }.compact
    bad << "memb pid=#{pid}(#{user.login})" if mb[pid.to_s] != ref
  end
  vb = c.send(:fetch_per_project_versions, user)
  Project.where(id: pids).each do |pr|
    next unless user.allowed_to?(:view_issues, pr)
    ref = Version.where(project_id: pr.id).preload(:custom_values, :project).map { |v| c.send(:version_to_hash, v, user) }
    bad << "vers pid=#{pr.id}(#{user.login})" if vb[pr.id.to_s] != ref
  end
  cb = c.send(:fetch_per_project_issue_categories, user)
  Project.where(id: pids, status: Project::STATUS_ACTIVE).each do |pr|
    next unless user.allowed_to?(:manage_categories, pr)
    ref = IssueCategory.where(project_id: pr.id).preload(:assigned_to, :project).map { |cat| c.send(:category_to_hash, cat) }
    bad << "cats pid=#{pr.id}(#{user.login})" if cb[pr.id.to_s] != ref
  end
end
puts bad.empty? ? 'PASS' : "FAIL: #{bad.first(8).inspect}"
```

**期待結果:**
- バッチ版の projects 埋め込み・memberships・versions（CF 値含む）・issue_categories が、コアの per-project 版と完全一致する

---

### [1-35-2] Version の CF 値ありパスがバッチ化後も一致する（preload が可視性を壊さない）

`preload(:custom_values)` で per-version の CF 値 N+1 を畳んでも、`visible_custom_field_values` の可視性判定と値が
崩れないことを、**実際に CF 値を持つ Version**で確認する（両側とも空だと検証にならないため値を行使する）。

**確認方法:**
```ruby
target = nil
Version.all.each do |v|
  next if v.visible_custom_field_values(User.find(1)).reject { |cv| cv.value.blank? }.empty?
  u = v.project.members.map(&:user).find { |m| m.is_a?(User) && m.status == User::STATUS_ACTIVE && m.allowed_to?(:view_issues, v.project) }
  (target = [v, u]; break) if u
end
if target.nil?
  puts 'SKIP: CF 値を持つ Version の member が無い（setup_cache_bundle_equiv_testdata.rb 未投入）'
else
  v, u = target
  User.current = u
  c = CacheBundlesController.new
  c.instance_variable_set(:@errors, [])
  row = c.send(:fetch_per_project_versions, u)[v.project_id.to_s].find { |h| h[:id] == v.id }
  ref = c.send(:version_to_hash, v, u)
  puts (row == ref && row[:custom_fields].present?) ? 'PASS' : "FAIL: batched=#{row&.dig(:custom_fields).inspect} expect=#{ref[:custom_fields].inspect}"
end
```

**期待結果:**
- CF 値を持つ Version の `custom_fields`（`{id, name, value}`）がバッチ化後も個別評価と一致し、空にならない

---

### [1-36] N+1 バッチ化でクエリ本数がプロジェクト／バージョン数に比例しない

memberships はプロジェクト数に依らず一定本数で取得できること（旧 per-project の N+1 が解消）を確認する。
versions/issue_categories は per-project の権限判定（`allowed_to?`）が残るため O(プロジェクト数) だが、
**バージョン件数には比例しない**（per-version の CF 値 N+1 が解消）ことを確認する。

**確認方法:**
```ruby
def cb_count_sql
  n = 0
  cb = ->(_a, _b, _c, _d, p) { n += 1 unless p[:name] =~ /SCHEMA|TRANSACTION/ || p[:sql] =~ /^\s*(BEGIN|COMMIT|RELEASE|SAVEPOINT)/i }
  ActiveSupport::Notifications.subscribed(cb, 'sql.active_record') { yield }
  n
end

# 複数プロジェクトの member を 2 人選び、memberships のクエリ本数がプロジェクト数に依らず一定であること
members = User.where(admin: false, type: 'User', status: User::STATUS_ACTIVE)
              .select { |u| u.memberships.map(&:project_id).uniq.size >= 1 }
              .sort_by { |u| -u.memberships.map(&:project_id).uniq.size }
if members.size < 2
  puts 'SKIP: member ユーザが 2 人未満'
else
  many, few = members.first, members.last
  User.current = many; cm = CacheBundlesController.new; cm.instance_variable_set(:@errors, [])
  User.current = few;  cf = CacheBundlesController.new; cf.instance_variable_set(:@errors, [])
  q_many = cb_count_sql { cm.send(:fetch_per_project_memberships, many) }
  q_few  = cb_count_sql { cf.send(:fetch_per_project_memberships, few) }
  pids_many = many.memberships.map(&:project_id).uniq.size
  pids_few  = few.memberships.map(&:project_id).uniq.size
  # プロジェクト数が違っても membership のクエリ本数は同じ（N+1 でない）
  ok = q_many == q_few
  puts ok ? "PASS (memberships: #{pids_many}proj->#{q_many}q, #{pids_few}proj->#{q_few}q)" : "FAIL: #{pids_many}proj->#{q_many}q vs #{pids_few}proj->#{q_few}q"
end
```

**期待結果:**
- memberships のクエリ本数がプロジェクト数に依存せず一定（per-project の N+1 が解消されている）

---

### [1-37] activities のバッチ化が「上書き除外」分岐を正しく畳む（build_project_activities）

`build_project_activities` は、コア `Project#activities` の「プロジェクト個別の上書き活動があるとき、上書き元の
システム活動を除外する」ロジックを Ruby で再現した**唯一の箇所**。上書きが 0 件だとバッチ版もコア版も
システム活動だけの空一致になり、除外分岐が素通りする（#2779 の空リスト盲点）。上書きデータ
（`setup_cache_bundle_equiv_testdata.rb` が perm-test-2779 に active/inactive の上書きを投入）で
**分岐が実際に発火し、かつコアと一致**することを確認する。

**確認方法:**
```ruby
overridden_pids = TimeEntryActivity.where.not(project_id: nil).pluck(:project_id).uniq
if overridden_pids.empty?
  puts 'SKIP: 活動上書きが無い（setup_cache_bundle_equiv_testdata.rb 未投入）'
else
  User.current = User.find(1)
  c = CacheBundlesController.new
  batched = c.send(:fetch_projects, User.find(1))
  sys_ids = TimeEntryActivity.where(project_id: nil).active.pluck(:id).sort
  bad = []; fired = false
  overridden_pids.each do |pid|
    p = Project.find(pid)
    row = batched.find { |h| h[:id] == pid }
    next if row.nil?
    got = row[:time_entry_activities].map { |x| x[:id] }.sort
    # 7.0 以降はコアが view_time_entries でゲートするため期待値も揃える（上書き PJ はモジュール有効で admin は許可）
    exp = (Redmine::VERSION::MAJOR >= 7 && !User.current.allowed_to?(:view_time_entries, p)) ? [] : p.activities.map(&:id).sort
    bad << "pid=#{pid} got=#{got} exp=#{exp}" if got != exp
    fired = true if got != sys_ids  # system 活動そのままではない＝上書き分岐が効いている
  end
  puts (bad.empty? && fired) ? "PASS (上書き分岐が発火しコア一致: pids=#{overridden_pids.inspect})" : "FAIL: bad=#{bad.inspect} fired=#{fired}"
end
```

**期待結果:**
- 上書きを持つプロジェクトの `time_entry_activities` がコア `Project#activities` と一致し、かつシステム活動そのままではない（除外/置換が効いている）

---

### [1-38] issue_custom_fields のバッチ化が「for_all＋プロジェクト明示紐付け」の結合を正しく畳む（merge_issue_custom_fields）

`merge_issue_custom_fields` は for_all の CF とプロジェクト明示紐付けの CF を結合する。全 CF が is_for_all だと
結合相手が空で union が素通りする。プロジェクト専用 CF（`setup_cache_bundle_equiv_testdata.rb` が perm-test-2779 に
`is_for_all=false` の CF を投入）で**結合が実際に発火し、かつコア `Project#all_issue_custom_fields` と一致**することを確認する。

**確認方法:**
```ruby
proj_only = IssueCustomField.where(is_for_all: false).select { |cf| cf.project_ids.any? }
if proj_only.empty?
  puts 'SKIP: プロジェクト専用 issue CF が無い（setup_cache_bundle_equiv_testdata.rb 未投入）'
else
  User.current = User.find(1)
  c = CacheBundlesController.new
  batched = c.send(:fetch_projects, User.find(1))
  bad = []; fired = false
  proj_only.each do |cf|
    cf.project_ids.each do |pid|
      row = batched.find { |h| h[:id] == pid }
      next if row.nil?
      got = row[:issue_custom_fields].map { |x| x[:id] }.sort
      # 7.0 以降はコアが view_issues でゲートするため期待値も揃える（対象 PJ は admin が view_issues 許可）
      pr = Project.find(pid)
      exp = (Redmine::VERSION::MAJOR >= 7 && !User.current.allowed_to?(:view_issues, pr)) ? [] : pr.all_issue_custom_fields.map(&:id).sort
      bad << "pid=#{pid} got=#{got} exp=#{exp}" if got != exp
      fired = true if got.include?(cf.id)  # for_all でない CF が結合されている
    end
  end
  puts (bad.empty? && fired) ? 'PASS (union 分岐が発火しコア一致)' : "FAIL: bad=#{bad.inspect} fired=#{fired}"
end
```

**期待結果:**
- プロジェクト専用 CF を持つプロジェクトの `issue_custom_fields` がコア `Project#all_issue_custom_fields` と一致し、かつ for_all でない CF が結合されている

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

### [2-20] admin キーで他ユーザのバンドルを作っても users/custom_fields/groups は全件（モード① 維持）

管理者 API キーで別ユーザ（`user_id=N`）のバンドルを取得する運用（モード①）でも、`users` / `custom_fields` /
`groups` は要求者（admin）の権限で全件返る（`target_user` にスコープしない）。自分（`user_id=1`）と他ユーザで
件数が一致することで、スコープ基準が `User.current` であることを固定する。

**前提条件:** admin 以外のユーザ（`{NonAdminUserId}`）が存在すること。

**確認方法:**
```powershell
$self  = (Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id=1' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}).cache_bundle
$other = (Invoke-RestMethod -Uri '{BaseUrl}/cache_bundle.json?user_id={NonAdminUserId}' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}).cache_bundle
($self.users.Count -eq $other.users.Count) -and `
($self.custom_fields.Count -eq $other.custom_fields.Count) -and `
($self.groups.Count -eq $other.groups.Count)
```

**期待結果:**
- admin キーで requester=admin である限り、target を変えても users / custom_fields / groups の件数は変わらない（全件）
- 一方 `project_memberships` / `project_versions` / `project_issue_categories` は target ユーザにスコープされる（別テスト [1-16 系] で担保）

**スキップ条件:**
- 非 admin ユーザが存在しない場合

---

### [2-21] 未認証（匿名）は 401 で拒否される（login_required 無効環境でも）

cache_bundle は全ユーザの氏名・メール・admin フラグ・ロール権限・設定マスタを返すため、匿名アクセスの遮断が特に重要。本体の `login_required` が無効な環境でも、認証情報なしのアクセスは 401 で拒否されること。

**確認方法:**
```powershell
try {
    Invoke-WebRequest -Uri '{BaseUrl}/cache_bundle.json'
} catch {
    $_.Exception.Response.StatusCode.Value__
}
```

**期待結果:**
- ステータスコード 401（本体の `login_required` 設定に関わらず、認証情報なしのアクセスは拒否）

---

## 3. ブラウザテスト

なし（API のみの機能のため）

---

## テスト実行方法

### Runner テスト・HTTP テスト
Claude が TEST_SPEC.md の仕様に基づいてコマンドを実行し、結果を報告する。
