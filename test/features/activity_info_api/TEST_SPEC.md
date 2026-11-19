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
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
made_projects, made_users, made_roles = [], [], []
cleanup = -> {
  User.current = admin
  made_projects.each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
}
# 親子 3 段のチケット（root → mid → leaf）と、mid の履歴 3 つ（ステータス変更・担当者 なし→author・担当者 author→other）を作る
build = -> {
  s1 = IssueStatus.where(is_closed: false).order(:position).first
  s2 = IssueStatus.where(is_closed: false).where.not(id: s1.id).order(:position).first
  tracker = Tracker.first
  role = Role.create!(name: "AIA_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  made_roles << role
  pr = Project.new(name: "AIA_#{sfx}", identifier: "aia-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  mk_user = ->(name) {
    u = User.new(login: "aia_#{name}_#{sfx}", firstname: 'AIA', lastname: name, mail: "aia_#{name}_#{sfx}@example.com", status: 1)
    u.password = u.password_confirmation = 'password123'
    u.save!
    made_users << u
    u
  }
  author = mk_user.call('author')
  other = mk_user.call('other')
  [author, other].each { |u| Member.create!(principal: u, project: pr, roles: [role]) }
  at = Time.utc(2020, 1, 7, 11)
  mk_issue = ->(name, parent) {
    i = Issue.new(project: pr, tracker: tracker, subject: "AIA_#{name}_#{sfx}", description: "AIA #{name} description",
                  author: author, status: s1, priority: IssuePriority.default || IssuePriority.active.first)
    i.parent_issue_id = parent.id if parent
    i.save!
    i
  }
  root = mk_issue.call('root', nil)
  mid = mk_issue.call('mid', root)
  leaf = mk_issue.call('leaf', mid)
  # 子を作ると親も保存し直されるので、作成日時は 3 つ作ってからまとめて入れる
  Issue.where(id: [root.id, mid.id, leaf.id]).update_all(created_on: at, updated_on: at)
  change = ->(time, notes, attrs) {
    i = Issue.find(mid.id)
    i.init_journal(author, notes)
    i.attributes = attrs
    i.save!
    j = i.journals.order(:id).last
    j.update_columns(created_on: time)
    j
  }
  j_status = change.call(at + 1.hour, nil, { status_id: s2.id })
  j_assign1 = change.call(at + 2.hours, nil, { assigned_to_id: author.id })
  j_assign2 = change.call(at + 3.hours, 'AIA 担当者を替える', { assigned_to_id: other.id })
  { s1: s1, s2: s2, author: author, other: other, root: Issue.find(root.id), mid: Issue.find(mid.id), leaf: Issue.find(leaf.id),
    j_status: j_status, j_assign1: j_assign1, j_assign2: j_assign2 }
}
status_lookup = IssueStatus.all.index_by(&:id)
begin
  d = build.call
  principal_lookup = Principal.all.index_by(&:id)
  controller = ActivityInfosController.new
  issue = d[:mid]
  journals = issue.journals.preload(:details).sort_by(&:created_on)
  restored = controller.send(:restore_status, issue, d[:j_status].created_on, journals, status_lookup, principal_lookup)
  # ステータスを変える前の時点なので、変える前の値に戻る（今の値は s2）
  ok = issue.status_id == d[:s2].id && restored[:status_id] == d[:s1].id
  puts ok ? 'PASS' : "FAIL: Expected status_id=#{d[:s1].id}, got #{restored[:status_id]}"
ensure
  cleanup.call
end
```

**期待結果:**
- `PASS`（ステータスを変える前の時点では、変える前のステータスに復元される）

---

### [1-6] restore_status が担当者を正しく復元する

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
made_projects, made_users, made_roles = [], [], []
cleanup = -> {
  User.current = admin
  made_projects.each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
}
# 親子 3 段のチケット（root → mid → leaf）と、mid の履歴 3 つ（ステータス変更・担当者 なし→author・担当者 author→other）を作る
build = -> {
  s1 = IssueStatus.where(is_closed: false).order(:position).first
  s2 = IssueStatus.where(is_closed: false).where.not(id: s1.id).order(:position).first
  tracker = Tracker.first
  role = Role.create!(name: "AIA_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  made_roles << role
  pr = Project.new(name: "AIA_#{sfx}", identifier: "aia-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  mk_user = ->(name) {
    u = User.new(login: "aia_#{name}_#{sfx}", firstname: 'AIA', lastname: name, mail: "aia_#{name}_#{sfx}@example.com", status: 1)
    u.password = u.password_confirmation = 'password123'
    u.save!
    made_users << u
    u
  }
  author = mk_user.call('author')
  other = mk_user.call('other')
  [author, other].each { |u| Member.create!(principal: u, project: pr, roles: [role]) }
  at = Time.utc(2020, 1, 7, 11)
  mk_issue = ->(name, parent) {
    i = Issue.new(project: pr, tracker: tracker, subject: "AIA_#{name}_#{sfx}", description: "AIA #{name} description",
                  author: author, status: s1, priority: IssuePriority.default || IssuePriority.active.first)
    i.parent_issue_id = parent.id if parent
    i.save!
    i
  }
  root = mk_issue.call('root', nil)
  mid = mk_issue.call('mid', root)
  leaf = mk_issue.call('leaf', mid)
  # 子を作ると親も保存し直されるので、作成日時は 3 つ作ってからまとめて入れる
  Issue.where(id: [root.id, mid.id, leaf.id]).update_all(created_on: at, updated_on: at)
  change = ->(time, notes, attrs) {
    i = Issue.find(mid.id)
    i.init_journal(author, notes)
    i.attributes = attrs
    i.save!
    j = i.journals.order(:id).last
    j.update_columns(created_on: time)
    j
  }
  j_status = change.call(at + 1.hour, nil, { status_id: s2.id })
  j_assign1 = change.call(at + 2.hours, nil, { assigned_to_id: author.id })
  j_assign2 = change.call(at + 3.hours, 'AIA 担当者を替える', { assigned_to_id: other.id })
  { s1: s1, s2: s2, author: author, other: other, root: Issue.find(root.id), mid: Issue.find(mid.id), leaf: Issue.find(leaf.id),
    j_status: j_status, j_assign1: j_assign1, j_assign2: j_assign2 }
}
status_lookup = IssueStatus.all.index_by(&:id)
begin
  d = build.call
  principal_lookup = Principal.all.index_by(&:id)
  controller = ActivityInfosController.new
  issue = d[:mid]
  journals = issue.journals.preload(:details).sort_by(&:created_on)
  restored = controller.send(:restore_status, issue, d[:j_assign2].created_on, journals, status_lookup, principal_lookup)
  # author → other に替える前の時点なので、author に戻る（今の値は other）
  ok = issue.assigned_to_id == d[:other].id && restored[:assigned_to_id] == d[:author].id
  puts ok ? 'PASS' : "FAIL: Expected assigned_to_id=#{d[:author].id}, got #{restored[:assigned_to_id]}"
ensure
  cleanup.call
end
```

**期待結果:**
- `PASS`（担当者を替える前の時点では、替える前の担当者に復元される）

---

### [1-7] build_ticket_tree が正しい階層を返す

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
made_projects, made_users, made_roles = [], [], []
cleanup = -> {
  User.current = admin
  made_projects.each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
}
# 親子 3 段のチケット（root → mid → leaf）と、mid の履歴 3 つ（ステータス変更・担当者 なし→author・担当者 author→other）を作る
build = -> {
  s1 = IssueStatus.where(is_closed: false).order(:position).first
  s2 = IssueStatus.where(is_closed: false).where.not(id: s1.id).order(:position).first
  tracker = Tracker.first
  role = Role.create!(name: "AIA_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  made_roles << role
  pr = Project.new(name: "AIA_#{sfx}", identifier: "aia-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  mk_user = ->(name) {
    u = User.new(login: "aia_#{name}_#{sfx}", firstname: 'AIA', lastname: name, mail: "aia_#{name}_#{sfx}@example.com", status: 1)
    u.password = u.password_confirmation = 'password123'
    u.save!
    made_users << u
    u
  }
  author = mk_user.call('author')
  other = mk_user.call('other')
  [author, other].each { |u| Member.create!(principal: u, project: pr, roles: [role]) }
  at = Time.utc(2020, 1, 7, 11)
  mk_issue = ->(name, parent) {
    i = Issue.new(project: pr, tracker: tracker, subject: "AIA_#{name}_#{sfx}", description: "AIA #{name} description",
                  author: author, status: s1, priority: IssuePriority.default || IssuePriority.active.first)
    i.parent_issue_id = parent.id if parent
    i.save!
    i
  }
  root = mk_issue.call('root', nil)
  mid = mk_issue.call('mid', root)
  leaf = mk_issue.call('leaf', mid)
  # 子を作ると親も保存し直されるので、作成日時は 3 つ作ってからまとめて入れる
  Issue.where(id: [root.id, mid.id, leaf.id]).update_all(created_on: at, updated_on: at)
  change = ->(time, notes, attrs) {
    i = Issue.find(mid.id)
    i.init_journal(author, notes)
    i.attributes = attrs
    i.save!
    j = i.journals.order(:id).last
    j.update_columns(created_on: time)
    j
  }
  j_status = change.call(at + 1.hour, nil, { status_id: s2.id })
  j_assign1 = change.call(at + 2.hours, nil, { assigned_to_id: author.id })
  j_assign2 = change.call(at + 3.hours, 'AIA 担当者を替える', { assigned_to_id: other.id })
  { s1: s1, s2: s2, author: author, other: other, root: Issue.find(root.id), mid: Issue.find(mid.id), leaf: Issue.find(leaf.id),
    j_status: j_status, j_assign1: j_assign1, j_assign2: j_assign2 }
}
status_lookup = IssueStatus.all.index_by(&:id)
begin
  d = build.call
  principal_lookup = Principal.all.index_by(&:id)
  controller = ActivityInfosController.new
  ids = [d[:leaf].id, d[:mid].id, d[:root].id]
  issues_by_id = Issue.where(id: ids).index_by(&:id)
  journals_by_issue = ids.map { |id| [id, issues_by_id[id].journals.preload(:details).sort_by(&:created_on)] }.to_h
  leaf = issues_by_id[d[:leaf].id]
  tree = controller.send(:build_ticket_tree, leaf, leaf.created_on, journals_by_issue, issues_by_id, {}, status_lookup, principal_lookup)
  got = tree.map { |x| x[:id] }
  expect = [d[:root].id, d[:mid].id, d[:leaf].id]
  puts got == expect ? 'PASS' : "FAIL: Expected #{expect}, got #{got}"
ensure
  cleanup.call
end
```

**期待結果:**
- `PASS`（ticket_tree が root → mid → leaf の順＝ルートから順）

---

### [1-8] build_ticket_tree のキャッシュが動作する

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
made_projects, made_users, made_roles = [], [], []
cleanup = -> {
  User.current = admin
  made_projects.each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
}
# 親子 3 段のチケット（root → mid → leaf）と、mid の履歴 3 つ（ステータス変更・担当者 なし→author・担当者 author→other）を作る
build = -> {
  s1 = IssueStatus.where(is_closed: false).order(:position).first
  s2 = IssueStatus.where(is_closed: false).where.not(id: s1.id).order(:position).first
  tracker = Tracker.first
  role = Role.create!(name: "AIA_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  made_roles << role
  pr = Project.new(name: "AIA_#{sfx}", identifier: "aia-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  mk_user = ->(name) {
    u = User.new(login: "aia_#{name}_#{sfx}", firstname: 'AIA', lastname: name, mail: "aia_#{name}_#{sfx}@example.com", status: 1)
    u.password = u.password_confirmation = 'password123'
    u.save!
    made_users << u
    u
  }
  author = mk_user.call('author')
  other = mk_user.call('other')
  [author, other].each { |u| Member.create!(principal: u, project: pr, roles: [role]) }
  at = Time.utc(2020, 1, 7, 11)
  mk_issue = ->(name, parent) {
    i = Issue.new(project: pr, tracker: tracker, subject: "AIA_#{name}_#{sfx}", description: "AIA #{name} description",
                  author: author, status: s1, priority: IssuePriority.default || IssuePriority.active.first)
    i.parent_issue_id = parent.id if parent
    i.save!
    i
  }
  root = mk_issue.call('root', nil)
  mid = mk_issue.call('mid', root)
  leaf = mk_issue.call('leaf', mid)
  # 子を作ると親も保存し直されるので、作成日時は 3 つ作ってからまとめて入れる
  Issue.where(id: [root.id, mid.id, leaf.id]).update_all(created_on: at, updated_on: at)
  change = ->(time, notes, attrs) {
    i = Issue.find(mid.id)
    i.init_journal(author, notes)
    i.attributes = attrs
    i.save!
    j = i.journals.order(:id).last
    j.update_columns(created_on: time)
    j
  }
  j_status = change.call(at + 1.hour, nil, { status_id: s2.id })
  j_assign1 = change.call(at + 2.hours, nil, { assigned_to_id: author.id })
  j_assign2 = change.call(at + 3.hours, 'AIA 担当者を替える', { assigned_to_id: other.id })
  { s1: s1, s2: s2, author: author, other: other, root: Issue.find(root.id), mid: Issue.find(mid.id), leaf: Issue.find(leaf.id),
    j_status: j_status, j_assign1: j_assign1, j_assign2: j_assign2 }
}
status_lookup = IssueStatus.all.index_by(&:id)
begin
  d = build.call
  principal_lookup = Principal.all.index_by(&:id)
  controller = ActivityInfosController.new
  ids = [d[:leaf].id, d[:mid].id, d[:root].id]
  issues_by_id = Issue.where(id: ids).index_by(&:id)
  journals_by_issue = ids.map { |id| [id, issues_by_id[id].journals.preload(:details).sort_by(&:created_on)] }.to_h
  leaf = issues_by_id[d[:leaf].id]
  cache = {}
  tree1 = controller.send(:build_ticket_tree, leaf, leaf.created_on, journals_by_issue, issues_by_id, cache, status_lookup, principal_lookup)
  tree2 = controller.send(:build_ticket_tree, leaf, leaf.created_on, journals_by_issue, issues_by_id, cache, status_lookup, principal_lookup)
  puts tree1.equal?(tree2) ? 'PASS' : 'FAIL: Cache not working (different object returned)'
ensure
  cleanup.call
end
```

**期待結果:**
- 同じ引数で呼び出した場合、同一オブジェクトが返される（キャッシュヒット）

---

### [1-9] Issue 作成イベントでは journal_id が nil になる

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
made_projects, made_users, made_roles = [], [], []
cleanup = -> {
  User.current = admin
  made_projects.each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
}
# 親子 3 段のチケット（root → mid → leaf）と、mid の履歴 3 つ（ステータス変更・担当者 なし→author・担当者 author→other）を作る
build = -> {
  s1 = IssueStatus.where(is_closed: false).order(:position).first
  s2 = IssueStatus.where(is_closed: false).where.not(id: s1.id).order(:position).first
  tracker = Tracker.first
  role = Role.create!(name: "AIA_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  made_roles << role
  pr = Project.new(name: "AIA_#{sfx}", identifier: "aia-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  mk_user = ->(name) {
    u = User.new(login: "aia_#{name}_#{sfx}", firstname: 'AIA', lastname: name, mail: "aia_#{name}_#{sfx}@example.com", status: 1)
    u.password = u.password_confirmation = 'password123'
    u.save!
    made_users << u
    u
  }
  author = mk_user.call('author')
  other = mk_user.call('other')
  [author, other].each { |u| Member.create!(principal: u, project: pr, roles: [role]) }
  at = Time.utc(2020, 1, 7, 11)
  mk_issue = ->(name, parent) {
    i = Issue.new(project: pr, tracker: tracker, subject: "AIA_#{name}_#{sfx}", description: "AIA #{name} description",
                  author: author, status: s1, priority: IssuePriority.default || IssuePriority.active.first)
    i.parent_issue_id = parent.id if parent
    i.save!
    i
  }
  root = mk_issue.call('root', nil)
  mid = mk_issue.call('mid', root)
  leaf = mk_issue.call('leaf', mid)
  # 子を作ると親も保存し直されるので、作成日時は 3 つ作ってからまとめて入れる
  Issue.where(id: [root.id, mid.id, leaf.id]).update_all(created_on: at, updated_on: at)
  change = ->(time, notes, attrs) {
    i = Issue.find(mid.id)
    i.init_journal(author, notes)
    i.attributes = attrs
    i.save!
    j = i.journals.order(:id).last
    j.update_columns(created_on: time)
    j
  }
  j_status = change.call(at + 1.hour, nil, { status_id: s2.id })
  j_assign1 = change.call(at + 2.hours, nil, { assigned_to_id: author.id })
  j_assign2 = change.call(at + 3.hours, 'AIA 担当者を替える', { assigned_to_id: other.id })
  { s1: s1, s2: s2, author: author, other: other, root: Issue.find(root.id), mid: Issue.find(mid.id), leaf: Issue.find(leaf.id),
    j_status: j_status, j_assign1: j_assign1, j_assign2: j_assign2 }
}
status_lookup = IssueStatus.all.index_by(&:id)
begin
  d = build.call
  principal_lookup = Principal.all.index_by(&:id)
  controller = ActivityInfosController.new
  issue = d[:mid]
  issues_by_id = Issue.where(id: [d[:mid].id, d[:root].id]).index_by(&:id)
  info = controller.send(:build_from_issue, issue, {}, issues_by_id, {}, status_lookup, principal_lookup)
  result = info[:journal_id].nil? && info[:journal].nil?
  puts result ? 'PASS' : "FAIL: journal_id=#{info[:journal_id]}, journal=#{info[:journal]}"
ensure
  cleanup.call
end
```

**期待結果:**
- `journal_id` が nil
- `journal` が nil

---

### [1-10] Journal イベントの description は notes を返す

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
made_projects, made_users, made_roles = [], [], []
cleanup = -> {
  User.current = admin
  made_projects.each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
}
# 親子 3 段のチケット（root → mid → leaf）と、mid の履歴 3 つ（ステータス変更・担当者 なし→author・担当者 author→other）を作る
build = -> {
  s1 = IssueStatus.where(is_closed: false).order(:position).first
  s2 = IssueStatus.where(is_closed: false).where.not(id: s1.id).order(:position).first
  tracker = Tracker.first
  role = Role.create!(name: "AIA_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  made_roles << role
  pr = Project.new(name: "AIA_#{sfx}", identifier: "aia-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  mk_user = ->(name) {
    u = User.new(login: "aia_#{name}_#{sfx}", firstname: 'AIA', lastname: name, mail: "aia_#{name}_#{sfx}@example.com", status: 1)
    u.password = u.password_confirmation = 'password123'
    u.save!
    made_users << u
    u
  }
  author = mk_user.call('author')
  other = mk_user.call('other')
  [author, other].each { |u| Member.create!(principal: u, project: pr, roles: [role]) }
  at = Time.utc(2020, 1, 7, 11)
  mk_issue = ->(name, parent) {
    i = Issue.new(project: pr, tracker: tracker, subject: "AIA_#{name}_#{sfx}", description: "AIA #{name} description",
                  author: author, status: s1, priority: IssuePriority.default || IssuePriority.active.first)
    i.parent_issue_id = parent.id if parent
    i.save!
    i
  }
  root = mk_issue.call('root', nil)
  mid = mk_issue.call('mid', root)
  leaf = mk_issue.call('leaf', mid)
  # 子を作ると親も保存し直されるので、作成日時は 3 つ作ってからまとめて入れる
  Issue.where(id: [root.id, mid.id, leaf.id]).update_all(created_on: at, updated_on: at)
  change = ->(time, notes, attrs) {
    i = Issue.find(mid.id)
    i.init_journal(author, notes)
    i.attributes = attrs
    i.save!
    j = i.journals.order(:id).last
    j.update_columns(created_on: time)
    j
  }
  j_status = change.call(at + 1.hour, nil, { status_id: s2.id })
  j_assign1 = change.call(at + 2.hours, nil, { assigned_to_id: author.id })
  j_assign2 = change.call(at + 3.hours, 'AIA 担当者を替える', { assigned_to_id: other.id })
  { s1: s1, s2: s2, author: author, other: other, root: Issue.find(root.id), mid: Issue.find(mid.id), leaf: Issue.find(leaf.id),
    j_status: j_status, j_assign1: j_assign1, j_assign2: j_assign2 }
}
status_lookup = IssueStatus.all.index_by(&:id)
begin
  d = build.call
  principal_lookup = Principal.all.index_by(&:id)
  controller = ActivityInfosController.new
  journal = Journal.find(d[:j_assign2].id)
  issues_by_id = Issue.where(id: [d[:mid].id, d[:root].id]).index_by(&:id)
  info = controller.send(:build_from_journal, journal, {}, issues_by_id, {}, status_lookup, principal_lookup)
  ok = journal.notes.present? && info[:description] == journal.notes
  puts ok ? 'PASS' : "FAIL: Expected '#{journal.notes}', got '#{info[:description]}'"
ensure
  cleanup.call
end
```

**期待結果:**
- `description` が Journal の `notes` と一致する

---

### [1-11] Issue 作成イベントの description は issue.description を返す

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
made_projects, made_users, made_roles = [], [], []
cleanup = -> {
  User.current = admin
  made_projects.each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
}
# 親子 3 段のチケット（root → mid → leaf）と、mid の履歴 3 つ（ステータス変更・担当者 なし→author・担当者 author→other）を作る
build = -> {
  s1 = IssueStatus.where(is_closed: false).order(:position).first
  s2 = IssueStatus.where(is_closed: false).where.not(id: s1.id).order(:position).first
  tracker = Tracker.first
  role = Role.create!(name: "AIA_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  made_roles << role
  pr = Project.new(name: "AIA_#{sfx}", identifier: "aia-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  mk_user = ->(name) {
    u = User.new(login: "aia_#{name}_#{sfx}", firstname: 'AIA', lastname: name, mail: "aia_#{name}_#{sfx}@example.com", status: 1)
    u.password = u.password_confirmation = 'password123'
    u.save!
    made_users << u
    u
  }
  author = mk_user.call('author')
  other = mk_user.call('other')
  [author, other].each { |u| Member.create!(principal: u, project: pr, roles: [role]) }
  at = Time.utc(2020, 1, 7, 11)
  mk_issue = ->(name, parent) {
    i = Issue.new(project: pr, tracker: tracker, subject: "AIA_#{name}_#{sfx}", description: "AIA #{name} description",
                  author: author, status: s1, priority: IssuePriority.default || IssuePriority.active.first)
    i.parent_issue_id = parent.id if parent
    i.save!
    i
  }
  root = mk_issue.call('root', nil)
  mid = mk_issue.call('mid', root)
  leaf = mk_issue.call('leaf', mid)
  # 子を作ると親も保存し直されるので、作成日時は 3 つ作ってからまとめて入れる
  Issue.where(id: [root.id, mid.id, leaf.id]).update_all(created_on: at, updated_on: at)
  change = ->(time, notes, attrs) {
    i = Issue.find(mid.id)
    i.init_journal(author, notes)
    i.attributes = attrs
    i.save!
    j = i.journals.order(:id).last
    j.update_columns(created_on: time)
    j
  }
  j_status = change.call(at + 1.hour, nil, { status_id: s2.id })
  j_assign1 = change.call(at + 2.hours, nil, { assigned_to_id: author.id })
  j_assign2 = change.call(at + 3.hours, 'AIA 担当者を替える', { assigned_to_id: other.id })
  { s1: s1, s2: s2, author: author, other: other, root: Issue.find(root.id), mid: Issue.find(mid.id), leaf: Issue.find(leaf.id),
    j_status: j_status, j_assign1: j_assign1, j_assign2: j_assign2 }
}
status_lookup = IssueStatus.all.index_by(&:id)
begin
  d = build.call
  principal_lookup = Principal.all.index_by(&:id)
  controller = ActivityInfosController.new
  issue = d[:mid]
  issues_by_id = Issue.where(id: [d[:mid].id, d[:root].id]).index_by(&:id)
  info = controller.send(:build_from_issue, issue, {}, issues_by_id, {}, status_lookup, principal_lookup)
  ok = issue.description.present? && info[:description] == issue.description
  puts ok ? 'PASS' : "FAIL: Expected '#{issue.description}', got '#{info[:description]}'"
ensure
  cleanup.call
end
```

**期待結果:**
- `description` が Issue の `description` と一致する

---

### [1-12] 複数の変更がある場合、異なる時点で異なる値に復元される

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
made_projects, made_users, made_roles = [], [], []
cleanup = -> {
  User.current = admin
  made_projects.each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
}
# 親子 3 段のチケット（root → mid → leaf）と、mid の履歴 3 つ（ステータス変更・担当者 なし→author・担当者 author→other）を作る
build = -> {
  s1 = IssueStatus.where(is_closed: false).order(:position).first
  s2 = IssueStatus.where(is_closed: false).where.not(id: s1.id).order(:position).first
  tracker = Tracker.first
  role = Role.create!(name: "AIA_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
  made_roles << role
  pr = Project.new(name: "AIA_#{sfx}", identifier: "aia-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  mk_user = ->(name) {
    u = User.new(login: "aia_#{name}_#{sfx}", firstname: 'AIA', lastname: name, mail: "aia_#{name}_#{sfx}@example.com", status: 1)
    u.password = u.password_confirmation = 'password123'
    u.save!
    made_users << u
    u
  }
  author = mk_user.call('author')
  other = mk_user.call('other')
  [author, other].each { |u| Member.create!(principal: u, project: pr, roles: [role]) }
  at = Time.utc(2020, 1, 7, 11)
  mk_issue = ->(name, parent) {
    i = Issue.new(project: pr, tracker: tracker, subject: "AIA_#{name}_#{sfx}", description: "AIA #{name} description",
                  author: author, status: s1, priority: IssuePriority.default || IssuePriority.active.first)
    i.parent_issue_id = parent.id if parent
    i.save!
    i
  }
  root = mk_issue.call('root', nil)
  mid = mk_issue.call('mid', root)
  leaf = mk_issue.call('leaf', mid)
  # 子を作ると親も保存し直されるので、作成日時は 3 つ作ってからまとめて入れる
  Issue.where(id: [root.id, mid.id, leaf.id]).update_all(created_on: at, updated_on: at)
  change = ->(time, notes, attrs) {
    i = Issue.find(mid.id)
    i.init_journal(author, notes)
    i.attributes = attrs
    i.save!
    j = i.journals.order(:id).last
    j.update_columns(created_on: time)
    j
  }
  j_status = change.call(at + 1.hour, nil, { status_id: s2.id })
  j_assign1 = change.call(at + 2.hours, nil, { assigned_to_id: author.id })
  j_assign2 = change.call(at + 3.hours, 'AIA 担当者を替える', { assigned_to_id: other.id })
  { s1: s1, s2: s2, author: author, other: other, root: Issue.find(root.id), mid: Issue.find(mid.id), leaf: Issue.find(leaf.id),
    j_status: j_status, j_assign1: j_assign1, j_assign2: j_assign2 }
}
status_lookup = IssueStatus.all.index_by(&:id)
begin
  d = build.call
  principal_lookup = Principal.all.index_by(&:id)
  controller = ActivityInfosController.new
  issue = d[:mid]
  journals = issue.journals.preload(:details).sort_by(&:created_on)
  restored1 = controller.send(:restore_status, issue, d[:j_assign1].created_on, journals, status_lookup, principal_lookup)
  restored2 = controller.send(:restore_status, issue, d[:j_assign2].created_on, journals, status_lookup, principal_lookup)
  # 1 回目（なし→author）の時点では 2 つとも戻すので「なし」、2 回目（author→other）の時点では 2 回目だけ戻すので author
  result = restored1[:assigned_to_id].nil? && restored2[:assigned_to_id] == d[:author].id
  puts result ? 'PASS' : "FAIL: target1=#{restored1[:assigned_to_id].inspect}, target2=#{restored2[:assigned_to_id].inspect}"
ensure
  cleanup.call
end
```

**期待結果:**
- `PASS`（1 回目の変更の時点では担当者なし＝両方の変更前、2 回目の変更の時点では author＝1 回目の変更後・2 回目の変更前）

---

### [1-13] 閲覧権限の無い親チケットが ticket_tree から除外される（.visible 是正）

`index` は親チケット階層を `Issue.visible` で絞って取得する。要求ユーザに見えない親（例: 非公開チケットや非メンバーのプロジェクト）が ticket_tree に混ざらないことを確認する。子は見えるが親は見えない状況を作り、`build_ticket_tree` の入力に実装同様 `Issue.visible` を通した辞書を渡すと、親が階層から落ちること（旧挙動＝`.visible` なしでは混入すること）を対比で確認する。

**確認方法:**
```ruby
admin = User.find(1)
User.current = admin
sfx = SecureRandom.hex(3)
pub = nil
u = nil
begin
  # 非管理・非メンバーの閲覧ユーザ（公開プロジェクトの公開チケットのみ可視）
  u = User.new(login: "aia13_viewer_#{sfx}", firstname: 'AIA13', lastname: 'Viewer', mail: "aia13_viewer_#{sfx}@example.com", status: 1)
  u.password = u.password_confirmation = 'password123'
  u.save!
  pub = Project.new(name: "AIA13_Pub_#{sfx}", identifier: "aia13-pub-#{sfx}", is_public: true)
  pub.enabled_module_names = ['issue_tracking']
  pub.trackers = [Tracker.first]
  pub.save!
  tracker = pub.trackers.first
  mk = ->(subject, is_private, parent) {
    i = Issue.new(project: pub, tracker: tracker, subject: "#{subject}_#{sfx}", author: admin, status: IssueStatus.first, priority: IssuePriority.default || IssuePriority.active.first)
    i.is_private = is_private
    i.parent_issue_id = parent.id if parent
    i.save!
    i
  }
  parent = mk.call('AIA13_Parent_Private', true, nil)
  child = mk.call('AIA13_Child_Public', false, parent)

  User.current = u
  controller = ActivityInfosController.new
  ids = [child.id, parent.id]
  status_lookup = IssueStatus.all.index_by(&:id)
  principal_lookup = Principal.all.index_by(&:id)
  # 実装と同じく .visible を通す
  fixed = Issue.visible.where(:id => ids).index_by(&:id)
  tree_fixed = controller.send(:build_ticket_tree, child, child.created_on, {}, fixed, {}, status_lookup, principal_lookup).map { |t| t[:id] }
  # 対比: .visible なし（旧挙動）
  old = Issue.where(:id => ids).index_by(&:id)
  tree_old = controller.send(:build_ticket_tree, child, child.created_on, {}, old, {}, status_lookup, principal_lookup).map { |t| t[:id] }
  ok = ((tree_fixed.include?(parent.id) == false) && tree_fixed.include?(child.id) && tree_old.include?(parent.id))
  puts ok ? 'PASS' : "FAIL: fixed=#{tree_fixed.inspect} old=#{tree_old.inspect}"
ensure
  User.current = admin
  Project.find_by(id: pub.id)&.destroy if pub&.id
  u.destroy if u&.persisted?
end
```

**期待結果:**
- `PASS`（修正後は不可視な親 `AIA13_Parent_Private_…` が ticket_tree から除外され、子のみ残る。旧挙動では親が混入していたことも対比で確認）

---

### [1-14]〜[1-22] の共通コード

[1-14]〜[1-22] は、Redmine の中で API を呼び、その試験の中でだけ組み立ての処理を差し替えて失敗を作る（本番の処理には、試験のための切り替えを入れない）。各試験は、この共通コードのあとに試験の本体を続けて、1 つの `rails runner` で流す（差し替えは、その runner の中だけで効く）。

流し方の注意:
- 引用符を含むので、`rails runner '{code}'` ではなく、コードをファイルにして `rails runner <ファイル>` で流す
- ファイルは、プラグインのフォルダの外（例: コンテナの `/tmp`）に置く。プラグインのフォルダの下に置くと、例外の場所として試験のファイルの行が選ばれ、期待と合わなくなる
- production 環境で流す（クラスを読み直す環境では、差し替えが外れて FAIL になることがある）

```ruby
# [1-14]〜[1-22] の共通コード（各試験はこのあとに本体を続けて 1 つの rails runner で流す）
# 試験のデータ：author が 2020-01-07 にチケットを 3 つ作る（活動 3 件）。終わったら消す
require 'stringio'
admin = User.find(1)
User.current = admin
# 前回の残りを消す
Project.where('identifier LIKE ?', 'ais-%').each(&:destroy)
User.where('login LIKE ?', 'ais_author_%').each(&:destroy)
Role.where('name LIKE ?', 'AIS_%').each(&:destroy)
sfx = SecureRandom.hex(3)
pr = Project.new(name: "AIS_#{sfx}", identifier: "ais-#{sfx}", is_public: false)
pr.enabled_module_names = %w[issue_tracking]
pr.trackers = [Tracker.first]
pr.save!
author = User.new(login: "ais_author_#{sfx}", firstname: 'AIS', lastname: 'author', mail: "ais_author_#{sfx}@example.com", status: 1)
author.password = author.password_confirmation = 'password123'
author.save!
role = Role.create!(name: "AIS_#{sfx}", permissions: [:view_issues, :add_issues], assignable: true)
Member.create!(principal: author, project: pr, roles: [role])
issues = %w[a b c].map do |n|
  Issue.create!(project: pr, tracker: pr.trackers.first, subject: "AIS_#{n}_#{sfx}", author: author,
                status: IssueStatus.first, priority: IssuePriority.default || IssuePriority.active.first)
end
Issue.where(id: issues.map(&:id)).update_all(created_on: Time.utc(2020, 1, 7, 11), updated_on: Time.utc(2020, 1, 7, 11))
cleanup = -> {
  User.current = admin
  Project.find_by(id: pr.id)&.destroy
  author.destroy if User.exists?(author.id)
  role.destroy if Role.exists?(role.id)
}
# Redmine の中で API を呼ぶ（管理者の API キー）。アプリに直接渡すので、サブディレクトリの下で動く環境でもパスは前に何も付けない
call = ->(fmt) {
  s = ActionDispatch::Integration::Session.new(Rails.application)
  s.get "/activity_infos.#{fmt}?user_id=#{author.id}&from=2020-01-07&to=2020-01-07",
        headers: { 'X-Redmine-API-Key' => admin.api_key }
  [s.response.status, s.response.body]
}
# この試験の中だけ、組み立てを差し替える（本番の処理には切り替えを入れない）
fail_on = ->(&blk) {
  ActivityInfosController.prepend(Module.new do
    define_method(:build_activity_info) do |event, *rest|
      instance_exec(event, &blk)
      super(event, *rest)
    end
  end)
}
```

---

### [1-14] 活動 1 件の組み立てに失敗すると、その 1 件を飛ばして残りを返す（JSON）

**確認方法:**（共通コードのあとに続ける）
```ruby
begin
  fail_on.call { |e| raise NoMethodError, 'AIS test' if e.is_a?(Issue) && e.id == issues[1].id }
  status, body = call.call('json')
  j = JSON.parse(body)
  ids = j['activity_infos'].map { |a| a['issue_id'] }
  ok = status == 200 && ids.sort == [issues[0].id, issues[2].id].sort && j['skipped_count'] == 1 &&
       j['skipped_errors'].to_s.match?(/\ANoMethodError \(activity_infos_controller\.rb:\d+\)\z/)
  puts ok ? 'PASS' : "FAIL: status=#{status} ids=#{ids} skipped_count=#{j['skipped_count']} skipped_errors=#{j['skipped_errors']}"
ensure
  cleanup.call
end
```

**期待結果:**
- `PASS`（200 で、失敗させたチケット b を除く 2 件が返り、`skipped_count` が 1、`skipped_errors` が `NoMethodError (activity_infos_controller.rb:行)`）

---

### [1-15] 活動 1 件の組み立てに失敗すると、その 1 件を飛ばして残りを返す（XML）

**確認方法:**（共通コードのあとに続ける）
```ruby
begin
  fail_on.call { |e| raise NoMethodError, 'AIS test' if e.is_a?(Issue) && e.id == issues[1].id }
  status, body = call.call('xml')
  doc = Nokogiri::XML(body)
  root = doc.root
  ids = doc.xpath('/activity_infos/activity_info/issue_id').map { |n| n.text.to_i }
  ok = status == 200 && root.name == 'activity_infos' && ids.sort == [issues[0].id, issues[2].id].sort &&
       root['skipped_count'] == '1' && root['skipped_errors'].to_s.match?(/\ANoMethodError \(activity_infos_controller\.rb:\d+\)\z/)
  puts ok ? 'PASS' : "FAIL: status=#{status} ids=#{ids} skipped_count=#{root && root['skipped_count']} skipped_errors=#{root && root['skipped_errors']}"
ensure
  cleanup.call
end
```

**期待結果:**
- `PASS`（200 で、2 件が返り、`<activity_infos>` の属性に `skipped_count="1"` と `skipped_errors` が付く）

---

### [1-16] 活動 1 件の組み立ての中で「レコードが無い」が出ても、API 全体を 404 にせず、その 1 件を飛ばす

**確認方法:**（共通コードのあとに続ける）
```ruby
begin
  fail_on.call { |e| raise ActiveRecord::RecordNotFound, 'AIS test' if e.is_a?(Issue) && e.id == issues[1].id }
  status, body = call.call('json')
  j = JSON.parse(body)
  ids = (j['activity_infos'] || []).map { |a| a['issue_id'] }
  ok = status == 200 && ids.sort == [issues[0].id, issues[2].id].sort && j['skipped_count'] == 1 &&
       j['skipped_errors'].to_s.match?(/\AActiveRecord::RecordNotFound \(activity_infos_controller\.rb:\d+\)\z/)
  puts ok ? 'PASS' : "FAIL: status=#{status} ids=#{ids} skipped_errors=#{j['skipped_errors']}"
ensure
  cleanup.call
end
```

**期待結果:**
- `PASS`（200 で 2 件が返り、`skipped_errors` が `ActiveRecord::RecordNotFound (…)`）

---

### [1-17] 全件の組み立てに失敗すると、空の一覧ではなく 500 を返し、本文に例外の説明を入れる

**確認方法:**（共通コードのあとに続ける）
```ruby
begin
  fail_on.call { |e| raise NoMethodError, 'AIS test' }
  js, jb = call.call('json')
  xs, xb = call.call('xml')
  jerr = (JSON.parse(jb)['errors'] rescue nil)
  xerr = Nokogiri::XML(xb).xpath('/errors/error').map(&:text)
  pat = /\ANoMethodError \(activity_infos_controller\.rb:\d+\)\z/
  ok = js == 500 && jerr.is_a?(Array) && jerr.size == 2 && !jerr[0].to_s.empty? && jerr[1].match?(pat) &&
       xs == 500 && xerr.size == 2 && !xerr[0].to_s.empty? && xerr[1].match?(pat)
  puts ok ? 'PASS' : "FAIL: json=#{js} #{jerr.inspect} xml=#{xs} #{xerr.inspect}"
ensure
  cleanup.call
end
```

**期待結果:**
- `PASS`（JSON・XML とも 500 で、`errors` に、利用者への案内の文と `NoMethodError (activity_infos_controller.rb:行)` の 2 つ）

---

### [1-18] 活動の一覧を取る所で失敗すると、500 を返し、本文に例外の説明を入れる

**確認方法:**（共通コードのあとに続ける）
```ruby
begin
  Redmine::Activity::Fetcher.prepend(Module.new do
    def events(*args)
      raise RuntimeError, 'AIS test'
    end
  end)
  io = StringIO.new
  old_logger = ActivityInfosController.logger
  ActivityInfosController.logger = Logger.new(io)
  js, jb = call.call('json')
  xs, xb = call.call('xml')
  jerr = (JSON.parse(jb)['errors'] rescue nil)
  xerr = Nokogiri::XML(xb).xpath('/errors/error').map(&:text)
  pat = /\ARuntimeError \(activity_infos_controller\.rb:\d+\)\z/
  logged = io.string.include?("[ActivityInfos] failed: user_id=#{author.id} from=2020-01-07 to=2020-01-07 RuntimeError: AIS test")
  ok = js == 500 && jerr.is_a?(Array) && jerr.size == 2 && !jerr[0].to_s.empty? && jerr[1].match?(pat) &&
       xs == 500 && xerr.size == 2 && !xerr[0].to_s.empty? && xerr[1].match?(pat) && logged
  puts ok ? 'PASS' : "FAIL: json=#{js} #{jerr.inspect} xml=#{xs} #{xerr.inspect} logged=#{logged}"
ensure
  ActivityInfosController.logger = old_logger if old_logger
  cleanup.call
end
```

**期待結果:**
- `PASS`（JSON・XML とも 500 で、`errors` に、案内の文と `RuntimeError (activity_infos_controller.rb:行)` の 2 つ。ログに `[ActivityInfos] failed: user_id=… from=… to=… RuntimeError: …` の行がある）

---

### [1-19] 活動 1 件の組み立ての中でデータベースの例外が出たときは、飛ばさずに 500 を返す

**確認方法:**（共通コードのあとに続ける）
```ruby
begin
  fail_on.call { |e| raise ActiveRecord::StatementInvalid, 'AIS test' if e.is_a?(Issue) && e.id == issues[1].id }
  status, body = call.call('json')
  jerr = (JSON.parse(body)['errors'] rescue nil)
  ok = status == 500 && jerr.is_a?(Array) && jerr.size == 2 &&
       jerr[1].match?(/\AActiveRecord::StatementInvalid \(activity_infos_controller\.rb:\d+\)\z/)
  puts ok ? 'PASS' : "FAIL: status=#{status} errors=#{jerr.inspect}"
ensure
  cleanup.call
end
```

**期待結果:**
- `PASS`（200 で欠けた結果を返さず、500 で `errors` に、案内の文と `ActiveRecord::StatementInvalid (…)` の 2 つ）

---

### [1-20] 書き出しの途中で失敗すると、500 を返し、本文に中の例外の説明を入れる

**確認方法:**（共通コードのあとに続ける）
```ruby
begin
  # 書き出しの途中で失敗させる：1 件の親チケット階層を、配列でない値にする
  target = issues[1].id
  ActivityInfosController.prepend(Module.new do
    define_method(:build_activity_info) do |event, *rest|
      info = super(event, *rest)
      info[:ticket_tree] = nil if info && info[:issue_id] == target
      info
    end
  end)
  js, jb = call.call('json')
  xs, xb = call.call('xml')
  jerr = (JSON.parse(jb)['errors'] rescue nil)
  xerr = Nokogiri::XML(xb).xpath('/errors/error').map(&:text)
  pat = /\ANoMethodError \(index\.api\.rsb:\d+\)\z/
  ok = js == 500 && jerr.is_a?(Array) && jerr.size == 2 && !jerr[0].to_s.empty? && jerr[1].match?(pat) &&
       xs == 500 && xerr.size == 2 && !xerr[0].to_s.empty? && xerr[1].match?(pat)
  puts ok ? 'PASS' : "FAIL: json=#{js} #{jerr.inspect} #{jb[0, 120]} xml=#{xs} #{xerr.inspect}"
ensure
  cleanup.call
end
```

**期待結果:**
- `PASS`（JSON・XML とも 500 で、`errors` に、Rails が包んだ例外ではなく中の `NoMethodError (index.api.rsb:行)` が、案内の文のあとに 1 つ）

---

### [1-21] 飛ばした活動をログに残す（文脈つき。スタックトレースは例外の種類ごとに 1 回）

**確認方法:**（共通コードのあとに続ける）
```ruby
begin
  # 2 件を同じ種類の例外で失敗させ、ログを読む
  fail_ids = [issues[1].id, issues[2].id]
  fail_on.call { |e| raise NoMethodError, 'AIS test' if e.is_a?(Issue) && fail_ids.include?(e.id) }
  io = StringIO.new
  old_logger = ActivityInfosController.logger
  ActivityInfosController.logger = Logger.new(io)
  status, body = call.call('json')
  j = JSON.parse(body)
  log = io.string
  ctx = "user_id=#{author.id} from=2020-01-07 to=2020-01-07"
  has_ctx = fail_ids.all? { |id| log.include?("[ActivityInfos] skipped: #{ctx} Issue##{id} NoMethodError") }
  # スタックトレースは種類ごとに 1 回だけ（index の行は 1 本のスタックトレースに 1 回だけ出る）
  traces = log.lines.count { |l| l.include?('activity_infos_controller.rb:') && l.rstrip.end_with?("index'") }
  # 同じ種類・同じ場所の失敗は、説明を重ねない
  one_desc = j['skipped_count'] == 2 && j['skipped_errors'].to_s.match?(/\ANoMethodError \(activity_infos_controller\.rb:\d+\)\z/)
  ok = status == 200 && has_ctx && traces == 1 && one_desc
  puts ok ? 'PASS' : "FAIL: status=#{status} has_ctx=#{has_ctx} traces=#{traces} skipped=#{j['skipped_count']} #{j['skipped_errors']}\n#{log[0, 600]}"
ensure
  ActivityInfosController.logger = old_logger if old_logger
  cleanup.call
end
```

**期待結果:**
- `PASS`（失敗させた 2 件とも、`[ActivityInfos] skipped: user_id=… from=… to=… Issue#… NoMethodError` の行があり、スタックトレースは 1 回だけ。応答は `skipped_count` が 2 で、`skipped_errors` は説明 1 つ）

---

### [1-22] 種類の違う例外で 2 件を飛ばすと、説明を 2 つつなぎ、スタックトレースも種類ごとに書く

**確認方法:**（共通コードのあとに続ける）
```ruby
begin
  b, c = issues[1].id, issues[2].id
  fail_on.call do |e|
    next unless e.is_a?(Issue)
    raise NoMethodError, 'AIS test' if e.id == b
    raise ArgumentError, 'AIS test' if e.id == c
  end
  io = StringIO.new
  old_logger = ActivityInfosController.logger
  ActivityInfosController.logger = Logger.new(io)
  status, body = call.call('json')
  j = JSON.parse(body)
  descs = j['skipped_errors'].to_s.split(', ')
  classes = descs.map { |d| d[/\A\S+/] }.sort
  traces = io.string.lines.count { |l| l.include?('activity_infos_controller.rb:') && l.rstrip.end_with?("index'") }
  ok = status == 200 && j['activity_infos'].size == 1 && j['skipped_count'] == 2 &&
       classes == %w[ArgumentError NoMethodError] && descs.all? { |d| d.match?(/ \(activity_infos_controller\.rb:\d+\)\z/) } && traces == 2
  puts ok ? 'PASS' : "FAIL: status=#{status} skipped=#{j['skipped_count']} errors=#{j['skipped_errors']} traces=#{traces}"
ensure
  ActivityInfosController.logger = old_logger if old_logger
  cleanup.call
end
```

**期待結果:**
- `PASS`（200 で 1 件が返り、`skipped_count` が 2、`skipped_errors` は `NoMethodError (…)` と `ArgumentError (…)` を `, ` でつないだもの。スタックトレースは 2 本）

---

## 2. HTTP テスト

**実行方法:**
PowerShell で各エンドポイントにリクエストを送信する。API キー認証が必要。

**用意（HTTP テストの前に 1 回）:**
活動を見るためのデータを Runner で作る（前回の残りがあれば先に消す）。
活動する人（author）と、活動のない人（other）を作る。
author は 2020-01-07 に、親子 3 段のチケット（root → mid → leaf）を作り、mid のステータスを変え、mid の担当者を自分にする。
活動として数えられるのは、チケットの作成 3 件とステータスの変更 1 件の 4 件（本体の活動と同じく、コメントもステータスの変更も無い更新は数えない）。
2020-01-10 に、コメントを付けて mid の担当者を other に替える（活動 1 件）。
最後の行の `AuthorId`・`OtherId`・`MidId` を、各試験の `{AuthorId}`・`{OtherId}`・`{MidId}` に入れる。

```ruby
admin = User.find(1)
User.current = admin
# 前回の残りを消す
Project.where('identifier LIKE ?', 'aia-http-%').each(&:destroy)
User.where('login LIKE ?', 'aia_http_%').each(&:destroy)
Role.where('name LIKE ?', 'AIA_HTTP_%').each(&:destroy)
sfx = SecureRandom.hex(3)
s1 = IssueStatus.where(is_closed: false).order(:position).first
s2 = IssueStatus.where(is_closed: false).where.not(id: s1.id).order(:position).first
tracker = Tracker.first
role = Role.create!(name: "AIA_HTTP_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues], assignable: true)
pr = Project.new(name: "AIA_HTTP_#{sfx}", identifier: "aia-http-#{sfx}", is_public: false)
pr.enabled_module_names = %w[issue_tracking]
pr.trackers = [tracker]
pr.save!
mk_user = ->(name) {
  u = User.new(login: "aia_http_#{name}_#{sfx}", firstname: 'AIA', lastname: name, mail: "aia_http_#{name}_#{sfx}@example.com", status: 1)
  u.password = u.password_confirmation = 'password123'
  u.save!
  u
}
author = mk_user.call('author')
other = mk_user.call('other')
[author, other].each { |u| Member.create!(principal: u, project: pr, roles: [role]) }
at = Time.utc(2020, 1, 7, 11)
mk_issue = ->(name, parent) {
  i = Issue.new(project: pr, tracker: tracker, subject: "AIA_HTTP_#{name}_#{sfx}", description: "AIA #{name} description",
                author: author, status: s1, priority: IssuePriority.default || IssuePriority.active.first)
  i.parent_issue_id = parent.id if parent
  i.save!
  i
}
root = mk_issue.call('root', nil)
mid = mk_issue.call('mid', root)
leaf = mk_issue.call('leaf', mid)
# 子を作ると親も保存し直されるので、作成日時は 3 つ作ってからまとめて入れる
Issue.where(id: [root.id, mid.id, leaf.id]).update_all(created_on: at, updated_on: at)
change = ->(time, notes, attrs) {
  i = Issue.find(mid.id)
  i.init_journal(author, notes)
  i.attributes = attrs
  i.save!
  i.journals.order(:id).last.update_columns(created_on: time)
}
change.call(at + 1.hour, nil, { status_id: s2.id })
change.call(at + 2.hours, nil, { assigned_to_id: author.id })
change.call(Time.utc(2020, 1, 10, 12), 'AIA 担当者を替える', { assigned_to_id: other.id })
puts({ AuthorId: author.id, OtherId: other.id, MidId: mid.id }.to_json)
```

**後片付け（HTTP テストのあとに 1 回）:**

```ruby
User.current = User.find(1)
Project.where('identifier LIKE ?', 'aia-http-%').each(&:destroy)
User.where('login LIKE ?', 'aia_http_%').each(&:destroy)
Role.where('name LIKE ?', 'AIA_HTTP_%').each(&:destroy)
puts 'cleaned'
```

### [2-0a] 未認証（匿名）は 401 で拒否される（login_required 無効環境でも）

**確認方法:**
```powershell
try {
  Invoke-WebRequest -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-07'
} catch {
  $_.Exception.Response.StatusCode.Value__
}
```

**期待結果:**
- ステータスコード 401（本体の `login_required` 設定に関わらず、認証情報なしのアクセスは拒否）

---

### [2-1] JSON 形式でアクセス可能

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.StatusCode
```

**期待結果:**
- ステータスコード 200

---

### [2-2] XML 形式でアクセス可能

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/activity_infos.xml?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.StatusCode
```

**期待結果:**
- ステータスコード 200

---

### [2-3] activity_infos 配列が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.activity_infos -is [array]
```

**期待結果:**
- `activity_infos` が配列

---

### [2-4] 日付範囲でフィルタリングされる

**確認方法:**
```powershell
$r1 = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$r2 = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-10&to=2020-01-10' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$r3 = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-10' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$r1.activity_infos.Count -eq 4 -and $r2.activity_infos.Count -eq 1 -and $r3.activity_infos.Count -eq 5
```

**期待結果:**
- `True`（1/7 は 4 件、1/10 は 1 件、1/7〜1/10 は 5 件）

---

### [2-5] 活動がない期間は空配列を返す

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-11&to=2020-01-12' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.activity_infos.Count -eq 0
```

**期待結果:**
- `activity_infos` が空配列

---

### [2-6] activity_info に必須フィールドが含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$info = $response.activity_infos[0]
$info.activity_datetime -ne $null -and $info.issue_id -ne $null -and $info.issue -ne $null -and $info.ticket_tree -ne $null
```

**期待結果:**
- `activity_datetime`, `issue_id`, `issue`, `ticket_tree` が存在する

---

### [2-7] issue に必須フィールドが含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$issue = $response.activity_infos[0].issue
$issue.id -ne $null -and $issue.subject -ne $null -and $issue.tracker -ne $null -and $issue.status -ne $null -and $issue.project -ne $null
```

**期待結果:**
- `id`, `subject`, `tracker`, `status`, `project` が存在する

---

### [2-8] journal に details が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$withJournal = $response.activity_infos | Where-Object { $_.journal -ne $null } | Select-Object -First 1
$withJournal.journal.details -is [array]
```

**期待結果:**
- journal の `details` が配列

---

### [2-9] ticket_tree がルートから順に並んでいる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
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
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-10&to=2020-01-10' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
# 1/10 の mid の活動: 担当者を author → other に替えた
$info = $response.activity_infos | Where-Object { $_.issue_id -eq {MidId} }
# 活動時点（変更前）は author
$info.issue.assigned_to.id -eq {AuthorId}
```

**期待結果:**
- `True`（`assigned_to.id` が author＝変更前の値に復元されている）

---

### [2-11] user_id が未指定だと 422 を返す

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

### [2-12] from が未指定だと 422 を返す

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

### [2-13] to が未指定だと 422 を返す

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

### [2-14] 存在しないユーザーで 404 を返す

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

### [2-15] チケット作成イベントでは journal が省略される

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$creation = $response.activity_infos | Where-Object { $_.journal_id -eq $null } | Select-Object -First 1
$creation -ne $null -and $creation.journal -eq $null
```

**期待結果:**
- `journal_id` が null のイベントが存在し、その `journal` も存在しない

---

### [2-16] assigned_to が null のチケットでは assigned_to が省略される

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
# assigned_to が null のチケットを探す
$noAssignee = $response.activity_infos | Where-Object { $_.issue.assigned_to -eq $null } | Select-Object -First 1
$noAssignee -ne $null
```

**期待結果:**
- `assigned_to` が省略されたチケットが存在する

---

### [2-17] イベントが新しい順（降順）で返される

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
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

### [2-18] user_id によるフィルタリングが動作する

**確認方法:**
```powershell
# 用意で作った author の活動
$r1 = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-10' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
# 用意で作った、活動のない other
$r2 = Invoke-RestMethod -Uri '{BaseUrl}/activity_infos.json?user_id={OtherId}&from=2020-01-07&to=2020-01-10' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$r1.activity_infos.Count -gt 0 -and $r1.activity_infos.Count -ne $r2.activity_infos.Count
```

**期待結果:**
- 異なる user_id で異なる件数が返される

---

### [2-19] XML レスポンスに activity_infos タグが含まれる

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/activity_infos.xml?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.Content -match '<activity_infos'
```

**期待結果:**
- レスポンスに `<activity_infos` タグが含まれる

---

### [2-20] 何も飛ばしていないときは、飛ばしたことを表す属性・キーを出さない

**確認方法:**
```powershell
$json = Invoke-WebRequest -Uri '{BaseUrl}/activity_infos.json?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$xml = Invoke-WebRequest -Uri '{BaseUrl}/activity_infos.xml?user_id={AuthorId}&from=2020-01-07&to=2020-01-07' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$json.StatusCode -eq 200 -and $xml.StatusCode -eq 200 -and $json.Content -notmatch 'skipped_' -and $xml.Content -notmatch 'skipped_'
```

**期待結果:**
- `True`（JSON にも XML にも `skipped_count`・`skipped_errors` が無い）

---

## 3. ブラウザテスト

なし（API のみの機能のため）

---

## テスト実行方法

### Runner テスト・HTTP テスト
Claude が TEST_SPEC.md の仕様に基づいてコマンドを実行し、結果を報告する。
