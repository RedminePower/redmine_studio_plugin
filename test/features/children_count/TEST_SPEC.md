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

チケットを作る試験は、試験の中でプロジェクト（とユーザー・ロール）を作り、終わったら `ensure` で消す。前からあるデータには頼らない。

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
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
made_projects, made_users, made_roles = [], [], []
mk_project = ->(name) {
  pr = Project.new(name: "CC_#{name}_#{sfx}", identifier: "cc-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  pr
}
project = nil
mk_issue = ->(subject, parent = nil, pr = project) {
  Issue.create!(project: pr, tracker: tracker, subject: subject, author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
begin
  project = mk_project.call('main')
  parent = mk_issue.call('CC_1-7_NoChildren')

  puts "count: #{parent.children_count_value}"
ensure
  User.current = admin
  made_projects.reverse_each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
end
```

**期待結果:** `count: 0`

### [1-8] 直下の子チケットが正しくカウントされる

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
made_projects, made_users, made_roles = [], [], []
mk_project = ->(name) {
  pr = Project.new(name: "CC_#{name}_#{sfx}", identifier: "cc-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  pr
}
project = nil
mk_issue = ->(subject, parent = nil, pr = project) {
  Issue.create!(project: pr, tracker: tracker, subject: subject, author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
begin
  project = mk_project.call('main')
  parent = mk_issue.call('CC_1-8_Parent')
  mk_issue.call('CC_1-8_Child1', parent)
  mk_issue.call('CC_1-8_Child2', parent)
  mk_issue.call('CC_1-8_Child3', parent)

  fresh = Issue.find(parent.id)
  puts "count: #{fresh.children_count_value}"
ensure
  User.current = admin
  made_projects.reverse_each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
end
```

**期待結果:** `count: 3`

### [1-9] 孫チケットはカウントに含まれない

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
made_projects, made_users, made_roles = [], [], []
mk_project = ->(name) {
  pr = Project.new(name: "CC_#{name}_#{sfx}", identifier: "cc-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  pr
}
project = nil
mk_issue = ->(subject, parent = nil, pr = project) {
  Issue.create!(project: pr, tracker: tracker, subject: subject, author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
begin
  project = mk_project.call('main')
  parent = mk_issue.call('CC_1-9_Parent')
  child = mk_issue.call('CC_1-9_Child', parent)
  mk_issue.call('CC_1-9_Grandchild', child)

  fresh_parent = Issue.find(parent.id)
  fresh_child = Issue.find(child.id)
  puts "parent_count: #{fresh_parent.children_count_value}"
  puts "child_count: #{fresh_child.children_count_value}"
ensure
  User.current = admin
  made_projects.reverse_each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
end
```

**期待結果:**
- `parent_count: 1`（直下の child のみ）
- `child_count: 1`（直下の grandchild のみ）

### [1-10] ツールチップに ID と件名が出力される

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
made_projects, made_users, made_roles = [], [], []
mk_project = ->(name) {
  pr = Project.new(name: "CC_#{name}_#{sfx}", identifier: "cc-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  pr
}
project = nil
mk_issue = ->(subject, parent = nil, pr = project) {
  Issue.create!(project: pr, tracker: tracker, subject: subject, author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
begin
  project = mk_project.call('main')
  parent = mk_issue.call('CC_1-10_Parent')
  child1 = mk_issue.call('CC_1-10_Child1', parent)
  child2 = mk_issue.call('CC_1-10_Child2', parent)

  fresh = Issue.find(parent.id)
  tooltip = fresh.children_tooltip
  puts "tooltip:"
  puts tooltip
  puts "---"
  puts "contains_child1: #{tooltip.include?("##{child1.id} CC_1-10_Child1")}"
  puts "contains_child2: #{tooltip.include?("##{child2.id} CC_1-10_Child2")}"
ensure
  User.current = admin
  made_projects.reverse_each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
end
```

**期待結果:**
- `contains_child1: true`
- `contains_child2: true`

### [1-11] ツールチップの件数上限（10 件まで表示、超過時は `...他 N 件`）

**確認方法:**
```ruby
# 期待値が日本語のため、直前のケースのロケール（[1-6] が :en に変更）に依存しないよう明示する
I18n.locale = :ja
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
made_projects, made_users, made_roles = [], [], []
mk_project = ->(name) {
  pr = Project.new(name: "CC_#{name}_#{sfx}", identifier: "cc-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  pr
}
project = nil
mk_issue = ->(subject, parent = nil, pr = project) {
  Issue.create!(project: pr, tracker: tracker, subject: subject, author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
begin
  project = mk_project.call('main')
  parent = mk_issue.call('CC_1-11_Parent')

  # 12 件の子チケットを作成
  12.times do |i|
    mk_issue.call("CC_1-11_Child_#{i + 1}", parent)
  end

  fresh = Issue.find(parent.id)
  tooltip = fresh.children_tooltip
  lines = tooltip.split("\n")
  puts "total_lines: #{lines.size}"
  puts "last_line: #{lines.last}"
  puts "count: #{fresh.children_count_value}"
ensure
  User.current = admin
  made_projects.reverse_each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
end
```

**期待結果:**
- `total_lines: 11`（10 件分 + `...他 2 件` の 1 行）
- `last_line: ...他 2 件`
- `count: 12`

### [1-12] ツールチップの件名文字数上限（30 文字、超過時は `...`）

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
made_projects, made_users, made_roles = [], [], []
mk_project = ->(name) {
  pr = Project.new(name: "CC_#{name}_#{sfx}", identifier: "cc-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  pr
}
project = nil
mk_issue = ->(subject, parent = nil, pr = project) {
  Issue.create!(project: pr, tracker: tracker, subject: subject, author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
begin
  project = mk_project.call('main')
  parent = mk_issue.call('CC_1-12_Parent')

  long_subject = 'あ' * 40  # 40 文字
  mk_issue.call(long_subject, parent)

  fresh = Issue.find(parent.id)
  tooltip = fresh.children_tooltip
  puts "tooltip: #{tooltip}"

  expected_truncated = ('あ' * 30) + '...'
  puts "contains_truncated: #{tooltip.include?(expected_truncated)}"
ensure
  User.current = admin
  made_projects.reverse_each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
end
```

**期待結果:**
- `contains_truncated: true`（先頭 30 文字 + `...` で省略されている）

### [1-13] 件名がちょうど 30 文字の場合は省略されない

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
made_projects, made_users, made_roles = [], [], []
mk_project = ->(name) {
  pr = Project.new(name: "CC_#{name}_#{sfx}", identifier: "cc-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  pr
}
project = nil
mk_issue = ->(subject, parent = nil, pr = project) {
  Issue.create!(project: pr, tracker: tracker, subject: subject, author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
begin
  project = mk_project.call('main')
  parent = mk_issue.call('CC_1-13_Parent')

  exact_subject = 'い' * 30  # ちょうど 30 文字
  mk_issue.call(exact_subject, parent)

  fresh = Issue.find(parent.id)
  tooltip = fresh.children_tooltip
  puts "ends_with_dots: #{tooltip.end_with?('...')}"
  puts "contains_exact: #{tooltip.include?(exact_subject)}"
ensure
  User.current = admin
  made_projects.reverse_each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
end
```

**期待結果:**
- `ends_with_dots: false`
- `contains_exact: true`

### [1-14] visibility 適用: 権限のない子はカウントに含まれない

**前提条件:**
- 別プロジェクトに子チケットを作成するため、`Setting.cross_project_subtasks = 'system'` に一時的に設定（`ensure` で元に戻す）

**確認方法:**
```ruby
# 一般ユーザー（guest）がメンバーのプロジェクトに親と子 1 件、メンバーでない非公開プロジェクトに子 1 件を作り、
# guest から見えない子がカウントされないことを確認する
orig_setting = Setting.cross_project_subtasks
Setting.cross_project_subtasks = 'system'
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
made_projects, made_users, made_roles = [], [], []
mk_project = ->(name) {
  pr = Project.new(name: "CC_#{name}_#{sfx}", identifier: "cc-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  pr
}
project = nil
mk_issue = ->(subject, parent = nil, pr = project) {
  Issue.create!(project: pr, tracker: tracker, subject: subject, author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
begin
  project = mk_project.call('main')
  private_proj = mk_project.call('private')

  parent = mk_issue.call('CC_1-14_Parent')
  mk_issue.call('CC_1-14_Visible', parent)
  mk_issue.call('CC_1-14_Hidden', parent, private_proj)

  # guest は project のメンバー（チケットを見られるロール）で、private_proj のメンバーではない
  role = Role.create!(name: "CC_Viewer_#{sfx}", permissions: [:view_issues], issues_visibility: 'all')
  made_roles << role
  guest = User.new(login: "cc_guest_#{sfx}", firstname: 'CC', lastname: 'Guest', mail: "cc_guest_#{sfx}@example.com", status: User::STATUS_ACTIVE)
  guest.password = guest.password_confirmation = SecureRandom.hex(8)
  guest.save!
  made_users << guest
  Member.create!(principal: guest, project: project, roles: [role])

  User.current = guest
  fresh = Issue.find(parent.id)
  count = fresh.children_count_value
  puts "guest_count: #{count}"

  # admin 視点では両方カウントされる
  User.current = admin
  admin_count = Issue.find(parent.id).children_count_value
  puts "admin_count: #{admin_count}"
ensure
  Setting.cross_project_subtasks = orig_setting
  User.current = admin
  made_projects.reverse_each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
end
```

**期待結果:**
- `guest_count: 1`（visible_child のみ）
- `admin_count: 2`（visible_child + hidden_child）

### [1-15] プリロードによる children_count_value の設定確認

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
made_projects, made_users, made_roles = [], [], []
mk_project = ->(name) {
  pr = Project.new(name: "CC_#{name}_#{sfx}", identifier: "cc-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  pr
}
project = nil
mk_issue = ->(subject, parent = nil, pr = project) {
  Issue.create!(project: pr, tracker: tracker, subject: subject, author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
begin
  project = mk_project.call('main')
  parent = mk_issue.call('CC_Parent')
  mk_issue.call('CC_Child1', parent)
  mk_issue.call('CC_Child2', parent)
  mk_issue.call('CC_Single')

  q = IssueQuery.new(name: 'test_1_15', filters: {}, project: project)
  q.column_names = [:id, :subject, :children_count]
  issues = q.issues(limit: 5)

  preloaded = issues.select { |i| i.instance_variable_defined?(:@children_count_value) }
  puts "preloaded: #{preloaded.size}"
  puts "total: #{issues.size}"
ensure
  User.current = admin
  made_projects.reverse_each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
end
```

**期待結果:**
- `preloaded: 4`
- `total: 4`（`preloaded` と `total` が同じ値）

### [1-15b] プリロード時に children_items もセットされる

children_count カラム表示時に children_items (子チケット一覧) が一括プリロードされ、ツールチップは children_items から導出できることを確認する。

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
made_projects, made_users, made_roles = [], [], []
mk_project = ->(name) {
  pr = Project.new(name: "CC_#{name}_#{sfx}", identifier: "cc-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  pr
}
project = nil
mk_issue = ->(subject, parent = nil, pr = project) {
  Issue.create!(project: pr, tracker: tracker, subject: subject, author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
begin
  project = mk_project.call('main')
  parent = mk_issue.call('CC_Parent')
  mk_issue.call('CC_Child1', parent)
  mk_issue.call('CC_Child2', parent)
  mk_issue.call('CC_Single')

  q = IssueQuery.new(name: 'test_1_15b', filters: {}, project: project)
  q.column_names = [:id, :subject, :children_count]
  issues = q.issues(limit: 5)

  with_count = issues.select { |i| i.instance_variable_defined?(:@children_count_value) }
  with_items = issues.select { |i| i.instance_variable_defined?(:@children_items) }
  puts "with_count: #{with_count.size}"
  puts "with_items: #{with_items.size}"
  puts "total: #{issues.size}"
  puts "tooltip_ok: #{issues.all? { |i| i.children_tooltip.is_a?(String) }}"
ensure
  User.current = admin
  made_projects.reverse_each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
end
```

**期待結果:**
- `with_count: 4`、`with_items: 4`、`total: 4`（すべて同じ値。プリロードで両方セット済み）
- `tooltip_ok: true`（children_items から導出したツールチップが文字列で得られる）

### [1-16] ソート実行確認（joins_for_order_statement）

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
made_projects, made_users, made_roles = [], [], []
mk_project = ->(name) {
  pr = Project.new(name: "CC_#{name}_#{sfx}", identifier: "cc-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  pr
}
project = nil
mk_issue = ->(subject, parent = nil, pr = project) {
  Issue.create!(project: pr, tracker: tracker, subject: subject, author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
begin
  project = mk_project.call('main')
  parent = mk_issue.call('CC_Parent')
  mk_issue.call('CC_Child1', parent)
  mk_issue.call('CC_Child2', parent)
  mk_issue.call('CC_Single')

  q = IssueQuery.new(name: 'test_1_16', filters: {}, project: project)
  q.column_names = [:id, :children_count]
  q.sort_criteria = [['children_count', 'desc']]

  # ソート実行でエラーが出ないことを確認
  issues = q.issues(limit: 5)
  puts "sort_ok: true"
  puts "count: #{issues.size}"
  puts "first_is_parent: #{issues.first&.id == parent.id}"
ensure
  User.current = admin
  made_projects.reverse_each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
end
```

**期待結果:**
- `sort_ok: true`（エラーなし）
- `count: 4`
- `first_is_parent: true`（子 2 件の親が先頭）

### [1-16b] ソート結果の順序検証（多い順）

**確認方法:**
```ruby
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
made_projects, made_users, made_roles = [], [], []
mk_project = ->(name) {
  pr = Project.new(name: "CC_#{name}_#{sfx}", identifier: "cc-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  pr
}
project = nil
mk_issue = ->(subject, parent = nil, pr = project) {
  Issue.create!(project: pr, tracker: tracker, subject: subject, author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
begin
  project = mk_project.call('main')
  # 子の数が異なる 3 つの親を作成
  parent_3 = mk_issue.call('CC_1-16b_Parent3')
  3.times { |i| mk_issue.call("CC_1-16b_P3_C#{i + 1}", parent_3) }

  parent_1 = mk_issue.call('CC_1-16b_Parent1')
  mk_issue.call('CC_1-16b_P1_C1', parent_1)

  parent_5 = mk_issue.call('CC_1-16b_Parent5')
  5.times { |i| mk_issue.call("CC_1-16b_P5_C#{i + 1}", parent_5) }

  # desc ソートで取得し、並び順を確認（件名で絞ると、この 3 件だけになる）
  q = IssueQuery.new(name: 'test_1_16b', filters: {}, project: project)
  q.column_names = [:id, :subject, :children_count]
  q.sort_criteria = [['children_count', 'desc']]
  q.add_filter('subject', '~', ['CC_1-16b_Parent'])

  results = q.issues
  ordered_ids = results.map(&:id)
  puts "order: #{ordered_ids.inspect}"

  # parent_5 → parent_3 → parent_1 の順になっていること
  puts "desc_order_ok: #{ordered_ids == [parent_5.id, parent_3.id, parent_1.id]}"
ensure
  User.current = admin
  made_projects.reverse_each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
end
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
# 試験のデータをその場で作る（終わったら消す）
sfx = SecureRandom.hex(3)
admin = User.find(1)
User.current = admin
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
made_projects, made_users, made_roles = [], [], []
mk_project = ->(name) {
  pr = Project.new(name: "CC_#{name}_#{sfx}", identifier: "cc-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = %w[issue_tracking]
  pr.trackers = [tracker]
  pr.save!
  made_projects << pr
  pr
}
project = nil
mk_issue = ->(subject, parent = nil, pr = project) {
  Issue.create!(project: pr, tracker: tracker, subject: subject, author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
begin
  project = mk_project.call('main')
  parent = mk_issue.call('CC_1-18_NoChildren')

  fresh = Issue.find(parent.id)
  puts "tooltip: '#{fresh.children_tooltip}'"
  puts "is_empty: #{fresh.children_tooltip.empty?}"
ensure
  User.current = admin
  made_projects.reverse_each { |pr| Project.find_by(id: pr.id)&.destroy }
  made_users.each { |u| u.destroy if User.exists?(u.id) }
  made_roles.each { |r| r.destroy if Role.exists?(r.id) }
end
```

**期待結果:**
- `is_empty: true`

---

## 2. HTTP テスト

**実行方法:**
PowerShell 7 でチケット一覧（HTML / CSV）を、管理者でログインしたセッションで取得する（画面・CSV は Basic 認証を受け付けないため、各試験の頭でログインする）。
HTTP 例の `{BaseUrl}`・`{Username}`・`{Password}`（管理者）は実行環境から注入する（プレースホルダの契約は `test/README.md`）。
表示の中身を見る試験は、用意で作ったプロジェクト（`/projects/{ProjectIdentifier}/issues`）の一覧に絞って、前からあるチケットに左右されないようにする。

**用意（HTTP テストの前に 1 回）:**
試験に使うデータを Runner で作る（前回の残りがあれば先に消す）。
- 非公開のプロジェクトに、子チケットを 2 件持つ親チケット（`{ParentIssueId}`）と、子のないチケット 1 件

最後の行の値を、各試験の `{ProjectIdentifier}`・`{ParentIssueId}` に入れる。

```ruby
admin = User.find(1)
User.current = admin
# 前回の残りを消す
Project.where('identifier LIKE ?', 'cch-%').order(lft: :desc).each(&:destroy)
sfx = SecureRandom.hex(3)
tracker = Tracker.order(:position).first
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
pr = Project.new(name: "CCH_#{sfx}", identifier: "cch-#{sfx}", is_public: false)
pr.enabled_module_names = %w[issue_tracking]
pr.trackers = [tracker]
pr.save!
mk = ->(name, parent = nil) {
  Issue.create!(project: pr, tracker: tracker, subject: "CCH_#{name}_#{sfx}", author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
parent = mk.call('Parent')
mk.call('Child1', parent)
mk.call('Child2', parent)
mk.call('Single')
puts({ ProjectIdentifier: pr.identifier, ParentIssueId: parent.id }.to_json)
```

**後片付け（HTTP テストのあとに 1 回）:**

```ruby
User.current = User.find(1)
Project.where('identifier LIKE ?', 'cch-%').order(lft: :desc).each(&:destroy)
puts 'cleaned'
```

### [2-1] チケット一覧で children_count カラムを指定して表示できる

**確認方法:**
```powershell
# 管理者でログインしたセッションを作る（画面・CSV は Basic 認証を受け付けず、匿名で開いてしまうため）
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable s -UseBasicParsing
$token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
$body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString('{Username}'))&password=$([uri]::EscapeDataString('{Password}'))"
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count' `
  -WebSession $s -UseBasicParsing
$response.StatusCode
```

**期待結果:** `200`

### [2-2] children_count カラムがチケット一覧のカラムオプションに表示される

**確認方法:**
```powershell
# 管理者でログインしたセッションを作る（画面・CSV は Basic 認証を受け付けず、匿名で開いてしまうため）
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable s -UseBasicParsing
$token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
$body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString('{Username}'))&password=$([uri]::EscapeDataString('{Password}'))"
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1' `
  -WebSession $s -UseBasicParsing
$response.Content -match 'children_count'
```

**期待結果:** `True`

### [2-3] カウント値が 0 のチケットは span でレンダリングされる

用意で作った子のないチケットを使う。

**確認方法:**
```powershell
# 管理者でログインしたセッションを作る（画面・CSV は Basic 認証を受け付けず、匿名で開いてしまうため）
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable s -UseBasicParsing
$token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
$body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString('{Username}'))&password=$([uri]::EscapeDataString('{Password}'))"
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
$response = Invoke-WebRequest -Uri '{BaseUrl}/projects/{ProjectIdentifier}/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:asc' `
  -WebSession $s -UseBasicParsing
$response.Content -match '<span class="children-count">0</span>'
```

**期待結果:** `True`

### [2-4] カウント値が 1 以上のチケットは a タグでリンクされる

用意で作った親チケット（子 2 件）を使う。

**確認方法:**
```powershell
# 管理者でログインしたセッションを作る（画面・CSV は Basic 認証を受け付けず、匿名で開いてしまうため）
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable s -UseBasicParsing
$token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
$body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString('{Username}'))&password=$([uri]::EscapeDataString('{Password}'))"
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
$response = Invoke-WebRequest -Uri '{BaseUrl}/projects/{ProjectIdentifier}/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:desc' `
  -WebSession $s -UseBasicParsing
$response.Content -match 'class="children-count"[^>]*>2</a>'
```

**期待結果:** `True`（親チケットの子チケット数 2 がリンクで出る）

### [2-5] リンク先 URL に parent_id フィルタが含まれる

**確認方法:**
```powershell
# [2-4] と同じリクエスト
# 管理者でログインしたセッションを作る（画面・CSV は Basic 認証を受け付けず、匿名で開いてしまうため）
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable s -UseBasicParsing
$token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
$body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString('{Username}'))&password=$([uri]::EscapeDataString('{Password}'))"
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
$response = Invoke-WebRequest -Uri '{BaseUrl}/projects/{ProjectIdentifier}/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:desc' `
  -WebSession $s -UseBasicParsing
$response.Content -match 'parent_id.*set_filter=1|set_filter=1.*parent_id'
```

**期待結果:** `True`（v=parent_id か f[]=parent_id が URL 内に存在）

### [2-5b] リンク先 URL はクロスプロジェクト（project_id を含まない）

**前提条件:**
- 用意で作ったプロジェクト配下の一覧画面（プロジェクトスコープ）からアクセスする

**確認方法:**
```powershell
# 管理者でログインしたセッションを作る（画面・CSV は Basic 認証を受け付けず、匿名で開いてしまうため）
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable s -UseBasicParsing
$token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
$body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString('{Username}'))&password=$([uri]::EscapeDataString('{Password}'))"
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
$projectId = '{ProjectIdentifier}'

# プロジェクトスコープのチケット一覧を取得
$response = Invoke-WebRequest -Uri "{BaseUrl}/projects/$projectId/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:desc" `
  -WebSession $s -UseBasicParsing

# children-count クラスを持つ link の href を抽出
$links = [regex]::Matches($response.Content, 'href="([^"]+)"[^>]*class="children-count"')
if ($links.Count -eq 0) {
  # class が先・href が後のパターンも試す
  $links = [regex]::Matches($response.Content, 'class="children-count"[^>]*href="([^"]+)"')
}

$hasProjectId = $false
foreach ($link in $links) {
  $href = $link.Groups[1].Value
  # /issues? か /issues/? で始まり、/projects/{id}/issues ではないこと
  if ($href -match '/projects/[^/]+/issues') {
    $hasProjectId = $true
    break
  }
}
Write-Host "matched_links: $($links.Count)"
Write-Host "any_link_has_project_scope: $hasProjectId"
```

**期待結果:**
- `matched_links` が 1 以上（リンクが存在）
- `any_link_has_project_scope: False`（リンク先はすべてクロスプロジェクトの `/issues?...`）

### [2-6] ツールチップ（title 属性）が出力される

**確認方法:**
```powershell
# [2-4] と同じリクエスト
# 管理者でログインしたセッションを作る（画面・CSV は Basic 認証を受け付けず、匿名で開いてしまうため）
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable s -UseBasicParsing
$token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
$body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString('{Username}'))&password=$([uri]::EscapeDataString('{Password}'))"
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
$response = Invoke-WebRequest -Uri '{BaseUrl}/projects/{ProjectIdentifier}/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:desc' `
  -WebSession $s -UseBasicParsing
$response.Content -match 'title=".*#\d+'
```

**期待結果:** `True`

### [2-7] children_count でソートできる（降順）

**確認方法:**
```powershell
# 管理者でログインしたセッションを作る（画面・CSV は Basic 認証を受け付けず、匿名で開いてしまうため）
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable s -UseBasicParsing
$token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
$body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString('{Username}'))&password=$([uri]::EscapeDataString('{Password}'))"
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:desc' `
  -WebSession $s -UseBasicParsing
$response.StatusCode
```

**期待結果:** `200`（エラーなくソートされた一覧が表示）

### [2-8] children_count でソートできる（昇順）

**確認方法:**
```powershell
# 管理者でログインしたセッションを作る（画面・CSV は Basic 認証を受け付けず、匿名で開いてしまうため）
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable s -UseBasicParsing
$token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
$body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString('{Username}'))&password=$([uri]::EscapeDataString('{Password}'))"
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:asc' `
  -WebSession $s -UseBasicParsing
$response.StatusCode
```

**期待結果:** `200`

### [2-9] children_count を含めても CSV エクスポートが成功する

**確認方法:**
```powershell
# 管理者でログインしたセッションを作る（画面・CSV は Basic 認証を受け付けず、匿名で開いてしまうため）
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable s -UseBasicParsing
$token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
$body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString('{Username}'))&password=$([uri]::EscapeDataString('{Password}'))"
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues.csv?set_filter=1&c[]=id&c[]=subject&c[]=children_count' `
  -WebSession $s -UseBasicParsing
$response.StatusCode
# CSV に HTML タグが混入していないことも確認
$response.Content -notmatch '<span|<a '
```

**期待結果:**
- `StatusCode: 200`
- `<span` / `<a ` を含まない（CSV には純粋な数値のみ）

### [2-9b] CSV に数値が正しく出力される

用意で作ったプロジェクトの一覧を、子チケットの多い順に CSV で取る（先頭のデータ行は子 2 件の親チケット）。

**確認方法:**
```powershell
# 管理者でログインしたセッションを作る（画面・CSV は Basic 認証を受け付けず、匿名で開いてしまうため）
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable s -UseBasicParsing
$token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
$body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString('{Username}'))&password=$([uri]::EscapeDataString('{Password}'))"
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
$response = Invoke-WebRequest -Uri '{BaseUrl}/projects/{ProjectIdentifier}/issues.csv?set_filter=1&c[]=id&c[]=subject&c[]=children_count&sort=children_count:desc' `
  -WebSession $s -UseBasicParsing

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
- `last_field: '2'`、`last_field_is_numeric: True`（先頭データ行の children_count 列が純粋な数値）

---

## 3. ブラウザテスト

該当なし（リンク遷移先の表示確認は HTTP テスト [2-4] / [2-5] で URL 構造を検証済み。実際の遷移は標準 Redmine のフィルタ機能のため、プラグイン固有の確認項目はない）。
