# Studio Settings API テスト仕様書

## 概要

Redmine Studio の汎用設定を Redmine サーバー側に保存・取得するための API 機能のテスト仕様。

**主な機能:**
- 汎用設定の CRUD 操作
- 論理削除 / 物理削除のサポート
- ユーザーへの設定割り当て管理

## 環境パラメータ

パスから自動判定:
- `redmine_5.1.11` → コンテナ名: `redmine_5.1.11`, ポート: `3051`
- `redmine_6.1.1` → コンテナ名: `redmine_6.1.1`, ポート: `3061`

固定パラメータ:

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| Username | `admin` | テスト用ログインID |
| Password | `password123` | テスト用パスワード |

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| モデル | `StudioSetting`, `StudioSettingAssignment`, `StudioSettingHistory` |
| DBテーブル | `studio_settings`, `studio_setting_assignments`, `studio_setting_histories` |
| コントローラ | `StudioSettingsController`, `StudioSettingUsersController`, `UserStudioSettingsController`, `StudioSettingHistoriesController` |
| 認証 | API キー必須（未認証で 401） |

### API エンドポイント

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/studio_settings.json` | 設定一覧取得 |
| GET | `/studio_settings/:id.json` | 設定詳細取得 |
| POST | `/studio_settings.json` | 設定作成 |
| PUT | `/studio_settings/:id.json` | 設定更新 |
| DELETE | `/studio_settings/:id.json` | 設定削除（論理/物理） |
| GET | `/studio_settings/:id/users.json` | ユーザー割り当て一覧 |
| PUT | `/studio_settings/:id/users.json` | ユーザー割り当て置換 |
| POST | `/studio_settings/:id/users/:user_id.json` | ユーザー割り当て追加 |
| DELETE | `/studio_settings/:id/users/:user_id.json` | ユーザー割り当て削除 |
| GET | `/users/:id/studio_settings.json` | ユーザーの設定一覧 |
| GET | `/studio_settings/:id/histories.json` | 履歴一覧取得 |
| GET | `/studio_settings/:id/histories/:version.json` | 履歴詳細取得 |
| POST | `/studio_settings/:id/restore.json` | 履歴から復元 |
| DELETE | `/studio_settings/:id/histories/:version.json` | 履歴削除 |

### レスポンス形式

API は JSON と XML の両方をサポートする。
すべてのエンドポイントで `.api.rsb` ビューを使用しており、
Redmine 標準の形式切り替え機構により両形式に対応している。

テストは JSON 形式で実施する（XML は同じビューから生成されるため）。

| 拡張子 | Content-Type |
|--------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

**エラーレスポンス:**
- 404 Not Found: 標準的な 404 ステータスを返す（ボディなし）
- 422 Unprocessable Entity: `{ "errors": [...] }` 形式でエラー内容を返す

### API リクエスト/レスポンス構造

**PUT /studio_settings/:id/users リクエストボディ:**
```json
{ "user_ids": [1, 2, 3] }
```

**設定一覧:**
```json
{
  "studio_settings": [
    { "id": 1, "name": "...", ... },
    { "id": 2, "name": "...", ... }
  ],
  "total_count": 2,
  "offset": 0,
  "limit": 25
}
```

**設定単体:**
```json
{
  "studio_setting": {
    "id": 1,
    "name": "設定名",
    "schema_type": "review",
    "scope_type": "global",
    "scope_id": null,
    "schema_version": 0,
    "payload": "{...}",
    "created_on": "2026-02-19T...",
    "created_by": { "id": 1, "name": "Admin" },
    "updated_on": "2026-02-19T...",
    "updated_by": { "id": 1, "name": "Admin" },
    "deleted_on": null
  }
}
```

**注意:** `created_by`, `updated_by`, `deleted_by` は nullable なネストオブジェクト。
nil の場合はプロパティ自体が省略される（`"deleted_by": null` ではなく、プロパティが存在しない）。

**ユーザー割り当て一覧:**
```json
{
  "studio_setting_assignments": [
    { "id": 1, "setting_id": 1, "user": { "id": 1, "name": "Admin" }, "assigned_on": "...", "assigned_by": { "id": 1, "name": "Admin" } }
  ],
  "total_count": 1,
  "offset": 0,
  "limit": 25
}
```

**ユーザー割り当て単体（作成時）:**
```json
{
  "studio_setting_assignment": {
    "id": 1,
    "setting_id": 1,
    "user": { "id": 2, "name": "John" },
    "assigned_on": "...",
    "assigned_by": { "id": 1, "name": "Admin" }
  }
}
```

**削除時:** HTTP 204 No Content（ボディなし）

**履歴一覧:**
```json
{
  "studio_setting_histories": [
    {
      "id": 3,
      "studio_setting_id": 1,
      "version": 3,
      "name": "設定名",
      "schema_type": "review",
      "scope_type": "project",
      "scope_id": 1,
      "schema_version": 2,
      "change_type": "update",
      "restored_from_version": null,
      "comment": "変更コメント",
      "is_current": true,
      "changed_on": "2026-03-03T15:00:00Z",
      "changed_by": { "id": 1, "name": "Admin" }
    }
  ],
  "total_count": 3,
  "offset": 0,
  "limit": 25
}
```

**履歴単体（詳細）:**
```json
{
  "studio_setting_history": {
    "id": 3,
    "studio_setting_id": 1,
    "version": 3,
    "name": "設定名",
    "schema_type": "review",
    "scope_type": "project",
    "scope_id": 1,
    "schema_version": 2,
    "change_type": "update",
    "restored_from_version": null,
    "comment": "変更コメント",
    "is_current": true,
    "changed_on": "2026-03-03T15:00:00Z",
    "changed_by": { "id": 1, "name": "Admin" },
    "payload": "{...}"
  }
}
```

**change_type の種類:**

| change_type | 説明 | restored_from_version |
|-------------|------|----------------------|
| `create` | 新規作成 | null |
| `update` | 更新 | null |
| `delete` | 論理削除 | null |
| `undelete` | 論理削除からの復活 | null または 復元元バージョン |
| `restore` | 履歴からの復元（削除状態でない場合） | 復元元バージョン |

**include パラメータ:**
- `include=payload` - payload フィールドを含める（一覧取得時）
- `include=assignments` - assignments フィールドを含める（設定取得時）
- `include=payload,assignments` - 複数指定可能

---

## テスト実行フロー

### フェーズ 0: Puma 停止

SQLite ロック競合を回避するため、Runner テスト実行前に Puma を停止する。

```bash
docker exec redmine_6.1.1 bash -c "kill $(cat /usr/src/redmine/tmp/pids/server.pid)"
```

### フェーズ 1: 登録確認テスト（バッチ 1-2）

プラグインの登録状態を確認する。

- バッチ 1: [1-1] ～ [1-12] を1つのスクリプトにまとめて実行（設定・割り当て基本機能）
- バッチ 2: [1-13] ～ [1-29] を1つのスクリプトにまとめて実行（履歴機能）

### フェーズ 2: コンテナ再起動

HTTP テストに備え、コンテナを再起動して Puma を復帰させる。

```bash
docker restart redmine_6.1.1
```

### フェーズ 3: HTTP テスト

API の動作を確認する。

---

## 1. 登録確認テスト（Runner テスト）

### [1-1] StudioSetting モデル確認

**確認方法:**
```ruby
puts defined?(StudioSetting)
puts StudioSetting.ancestors.include?(ActiveRecord::Base)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-2] StudioSettingAssignment モデル確認

**確認方法:**
```ruby
puts defined?(StudioSettingAssignment)
puts StudioSettingAssignment.ancestors.include?(ActiveRecord::Base)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-3] studio_settings テーブル確認

**確認方法:**
```ruby
columns = ActiveRecord::Base.connection.columns(:studio_settings).map(&:name)
expected = %w[id name schema_type scope_type scope_id payload schema_version created_on created_by_id updated_on updated_by_id deleted_on deleted_by_id]
puts (expected - columns).empty?
```

**期待結果:**
- `true` が出力される

### [1-4] studio_setting_assignments テーブル確認

**確認方法:**
```ruby
columns = ActiveRecord::Base.connection.columns(:studio_setting_assignments).map(&:name)
expected = %w[id setting_id user_id assigned_on assigned_by_id]
puts (expected - columns).empty?
```

**期待結果:**
- `true` が出力される

### [1-5] StudioSettingsController 確認

**確認方法:**
```ruby
puts defined?(StudioSettingsController)
puts StudioSettingsController.ancestors.include?(ApplicationController)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-6] StudioSettingUsersController 確認

**確認方法:**
```ruby
puts defined?(StudioSettingUsersController)
puts StudioSettingUsersController.ancestors.include?(ApplicationController)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-7] UserStudioSettingsController 確認

**確認方法:**
```ruby
puts defined?(UserStudioSettingsController)
puts UserStudioSettingsController.ancestors.include?(ApplicationController)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-8] ルーティング確認

**確認方法:**
```ruby
routes = [
  { path: '/studio_settings', method: :get, expected: { controller: 'studio_settings', action: 'index' } },
  { path: '/studio_settings/1', method: :get, expected: { controller: 'studio_settings', action: 'show', id: '1' } },
  { path: '/studio_settings', method: :post, expected: { controller: 'studio_settings', action: 'create' } },
  { path: '/studio_settings/1', method: :put, expected: { controller: 'studio_settings', action: 'update', id: '1' } },
  { path: '/studio_settings/1', method: :delete, expected: { controller: 'studio_settings', action: 'destroy', id: '1' } },
  { path: '/studio_settings/1/users', method: :get, expected: { controller: 'studio_setting_users', action: 'index', id: '1' } },
  { path: '/studio_settings/1/users', method: :put, expected: { controller: 'studio_setting_users', action: 'replace', id: '1' } },
  { path: '/studio_settings/1/users/2', method: :post, expected: { controller: 'studio_setting_users', action: 'add', id: '1', user_id: '2' } },
  { path: '/studio_settings/1/users/2', method: :delete, expected: { controller: 'studio_setting_users', action: 'remove', id: '1', user_id: '2' } },
  { path: '/users/1/studio_settings', method: :get, expected: { controller: 'user_studio_settings', action: 'index', id: '1' } },
]

results = routes.map do |r|
  recognized = Rails.application.routes.recognize_path(r[:path], method: r[:method])
  r[:expected].all? { |k, v| recognized[k].to_s == v.to_s }
end

puts results.all?
```

**期待結果:**
- `true` が出力される

### [1-9] StudioSetting バリデーション確認

**確認方法:**
```ruby
# name 必須
rs = StudioSetting.new(schema_type: 'review', scope_type: 'global', schema_version: 0)
rs.created_by = User.current
rs.updated_by = User.current
puts rs.valid? == false
puts rs.errors[:name].any?  # ロケールによりメッセージが異なるため .any? で確認

# schema_type 必須
rs = StudioSetting.new(name: 'Test', scope_type: 'global', schema_version: 0)
rs.created_by = User.current
rs.updated_by = User.current
puts rs.valid? == false
puts rs.errors[:schema_type].any?

# scope_type 必須
rs = StudioSetting.new(name: 'Test', schema_type: 'review', schema_version: 0)
rs.created_by = User.current
rs.updated_by = User.current
puts rs.valid? == false
puts rs.errors[:scope_type].any?

# schema_version >= 0
rs = StudioSetting.new(name: 'Test', schema_type: 'review', scope_type: 'global', schema_version: -1)
rs.created_by = User.current
rs.updated_by = User.current
puts rs.valid? == false

# schema_version は整数のみ
rs = StudioSetting.new(name: 'Test', schema_type: 'review', scope_type: 'global', schema_version: 1.5)
rs.created_by = User.current
rs.updated_by = User.current
puts rs.valid? == false
```

**期待結果:**
- 全て `true` が出力される（8回）

**備考:**
- バリデーションエラーメッセージはロケールにより異なる（"can't be blank" / "cannot be blank"）
- エラーの存在確認には `.any?` を使用する

### [1-10] StudioSettingAssignment バリデーション確認

**確認方法:**
```ruby
# テスト用設定を作成
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'ValidationTest', schema_type: 'review', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)

# 正常ケース
assignment = StudioSettingAssignment.new(setting: setting, user: admin, assigned_by: admin)
puts assignment.valid?

# uniqueness 制約（同一 setting_id + user_id）
assignment.save
dup = StudioSettingAssignment.new(setting: setting, user: admin, assigned_by: admin)
puts dup.valid? == false
puts dup.errors[:user_id].any?

# クリーンアップ
setting.destroy
```

**期待結果:**
- `true` が出力される（3回）

### [1-11] soft_delete メソッド確認

**確認方法:**
```ruby
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'SoftDeleteTest', schema_type: 'review', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)

puts setting.deleted? == false
puts setting.deleted_on.nil?

setting.soft_delete(admin)

puts setting.deleted?
puts setting.deleted_on.present?
puts setting.deleted_by_id == admin.id

# クリーンアップ
setting.destroy
```

**期待結果:**
- `true` が出力される（5回）

### [1-12] dependent: :destroy 確認

**確認方法:**
```ruby
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'DependentTest', schema_type: 'review', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)
assignment = StudioSettingAssignment.create(setting: setting, user: admin, assigned_by: admin)
assignment_id = assignment.id

puts StudioSettingAssignment.exists?(assignment_id)

setting.destroy

puts StudioSettingAssignment.exists?(assignment_id) == false
```

**期待結果:**
- `true` が出力される（2回）

### [1-13] StudioSettingHistory モデル確認

**確認方法:**
```ruby
puts defined?(StudioSettingHistory)
puts StudioSettingHistory.ancestors.include?(ActiveRecord::Base)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-14] studio_setting_histories テーブル確認

**確認方法:**
```ruby
columns = ActiveRecord::Base.connection.columns(:studio_setting_histories).map(&:name)
expected = %w[id studio_setting_id name schema_type scope_type scope_id payload schema_version version change_type restored_from_version comment is_current changed_on changed_by_id]
puts (expected - columns).empty?
```

**期待結果:**
- `true` が出力される

### [1-15] StudioSettingHistoriesController 確認

**確認方法:**
```ruby
puts defined?(StudioSettingHistoriesController)
puts StudioSettingHistoriesController.ancestors.include?(ApplicationController)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-16] 履歴ルーティング確認

**確認方法:**
```ruby
routes = [
  { path: '/studio_settings/1/histories', method: :get, expected: { controller: 'studio_setting_histories', action: 'index', studio_setting_id: '1' } },
  { path: '/studio_settings/1/histories/1', method: :get, expected: { controller: 'studio_setting_histories', action: 'show', studio_setting_id: '1', version: '1' } },
  { path: '/studio_settings/1/histories/1', method: :delete, expected: { controller: 'studio_setting_histories', action: 'destroy', studio_setting_id: '1', version: '1' } },
  { path: '/studio_settings/1/restore', method: :post, expected: { controller: 'studio_setting_histories', action: 'restore', id: '1' } },
]

results = routes.map do |r|
  recognized = Rails.application.routes.recognize_path(r[:path], method: r[:method])
  r[:expected].all? { |k, v| recognized[k].to_s == v.to_s }
end

puts results.all?
```

**期待結果:**
- `true` が出力される

### [1-17] create_history メソッド確認

**確認方法:**
```ruby
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'HistoryTest', schema_type: 'review', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)
setting.create_history('create', admin, comment: 'Initial creation')

history = setting.histories.last
puts history.present?
puts history.version == 1
puts history.change_type == 'create'
puts history.is_current == true
puts history.comment == 'Initial creation'
puts history.changed_by_id == admin.id

# クリーンアップ
setting.destroy
```

**期待結果:**
- `true` が出力される（6回）

### [1-18] is_current フラグ管理確認

**確認方法:**
```ruby
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'IsCurrentTest', schema_type: 'review', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)
setting.create_history('create', admin)

# version 1 が is_current
puts setting.histories.find_by(version: 1).is_current == true

# 2回目の履歴作成
setting.payload = '{"updated": true}'
setting.save
setting.create_history('update', admin)

# version 2 が is_current、version 1 は false
puts setting.histories.find_by(version: 1).is_current == false
puts setting.histories.find_by(version: 2).is_current == true

# is_current: true は常に1件のみ
puts setting.histories.where(is_current: true).count == 1

# クリーンアップ
setting.destroy
```

**期待結果:**
- `true` が出力される（4回）

### [1-19] restore_from_version メソッド確認

**確認方法:**
```ruby
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'RestoreTest', schema_type: 'review', scope_type: 'global', schema_version: 0, payload: '{"v1": true}', created_by: admin, updated_by: admin)
setting.create_history('create', admin)

# 更新
setting.payload = '{"v2": true}'
setting.schema_version = 1
setting.save
setting.create_history('update', admin)

# version 1 に復元
result = setting.restore_from_version(1, admin, comment: 'Restore to v1')

puts result == true
puts setting.payload == '{"v1": true}'
puts setting.schema_version == 0

# 復元後の履歴を確認
restore_history = setting.histories.find_by(version: 3)
puts restore_history.change_type == 'restore'
puts restore_history.restored_from_version == 1
puts restore_history.comment == 'Restore to v1'

# クリーンアップ
setting.destroy
```

**期待結果:**
- `true` が出力される（6回）

### [1-20] restore 時に name は復元されないことの確認

**確認方法:**
```ruby
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'OriginalName', schema_type: 'review', scope_type: 'global', schema_version: 0, payload: '{"v1": true}', created_by: admin, updated_by: admin)
setting.create_history('create', admin)

# 名前と payload を更新
setting.name = 'UpdatedName'
setting.payload = '{"v2": true}'
setting.save
setting.create_history('update', admin)

# version 1 に復元
setting.restore_from_version(1, admin)

# payload は v1 に戻るが、name は UpdatedName のまま
puts setting.payload == '{"v1": true}'
puts setting.name == 'UpdatedName'

# クリーンアップ
setting.destroy
```

**期待結果:**
- `true` が出力される（2回）

### [1-21] 履歴の CASCADE 削除確認

**確認方法:**
```ruby
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'CascadeTest', schema_type: 'review', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)
setting.create_history('create', admin)

history_id = setting.histories.last.id
puts StudioSettingHistory.exists?(history_id)

setting.destroy

puts StudioSettingHistory.exists?(history_id) == false
```

**期待結果:**
- `true` が出力される（2回）

### [1-22] StudioSettingHistory バリデーション確認

**確認方法:**
```ruby
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'ValidationTest2', schema_type: 'review', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)

# 正常ケース
history = StudioSettingHistory.new(
  studio_setting: setting,
  name: 'Test',
  schema_type: 'review',
  scope_type: 'global',
  schema_version: 0,
  version: 1,
  change_type: 'create',
  is_current: true,
  changed_on: Time.current,
  changed_by: admin
)
puts history.valid?

# change_type 必須
history2 = StudioSettingHistory.new(
  studio_setting: setting,
  name: 'Test',
  schema_type: 'review',
  scope_type: 'global',
  schema_version: 0,
  version: 2,
  is_current: false,
  changed_on: Time.current,
  changed_by: admin
)
puts history2.valid? == false
puts history2.errors[:change_type].any?

# クリーンアップ
setting.destroy
```

**期待結果:**
- `true` が出力される（3回）

### [1-23] deletable? メソッド確認

**確認方法:**
```ruby
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'DeletableTest', schema_type: 'review', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)
setting.create_history('create', admin)
setting.payload = '{"v2": true}'
setting.save
setting.create_history('update', admin)

history1 = setting.histories.find_by(version: 1)
history2 = setting.histories.find_by(version: 2)

# version 1 (is_current: false) は削除可能
puts history1.deletable? == true

# version 2 (is_current: true) は削除不可
puts history2.deletable? == false

# クリーンアップ
setting.destroy
```

**期待結果:**
- `true` が出力される（2回）

### [1-24] version の一意性制約確認

**確認方法:**
```ruby
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'UniqueVersionTest', schema_type: 'review', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)
setting.create_history('create', admin)

# 同じ version で履歴を作成しようとする
dup_history = StudioSettingHistory.new(
  studio_setting: setting,
  name: 'Test',
  schema_type: 'review',
  scope_type: 'global',
  schema_version: 0,
  version: 1,  # 既に存在する version
  change_type: 'update',
  is_current: false,
  changed_on: Time.current,
  changed_by: admin
)
puts dup_history.valid? == false
puts dup_history.errors[:version].any?

# クリーンアップ
setting.destroy
```

**期待結果:**
- `true` が出力される（2回）

### [1-25] ordered スコープ確認

**確認方法:**
```ruby
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'OrderedScopeTest', schema_type: 'review', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)
setting.create_history('create', admin)
setting.payload = '{"v2": true}'
setting.save
setting.create_history('update', admin)
setting.payload = '{"v3": true}'
setting.save
setting.create_history('update', admin)

# ordered スコープで取得
ordered = setting.histories.ordered
puts ordered.first.version == 3  # 最新が先頭
puts ordered.last.version == 1   # 最古が末尾

# クリーンアップ
setting.destroy
```

**期待結果:**
- `true` が出力される（2回）

### [1-26] current_version メソッド確認

**確認方法:**
```ruby
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'CurrentVersionTest', schema_type: 'review', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)

# 履歴なしの場合は 0
puts setting.current_version == 0

# 履歴作成後
setting.create_history('create', admin)
puts setting.current_version == 1

setting.payload = '{"v2": true}'
setting.save
setting.create_history('update', admin)
puts setting.current_version == 2

# クリーンアップ
setting.destroy
```

**期待結果:**
- `true` が出力される（3回）

### [1-27] change_type の inclusion バリデーション確認

**確認方法:**
```ruby
admin = User.find_by_login('admin')
User.current = admin
setting = StudioSetting.create(name: 'ChangeTypeValidationTest', schema_type: 'review', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)

# 有効な change_type
%w[create update delete undelete restore].each do |ct|
  history = StudioSettingHistory.new(
    studio_setting: setting,
    name: 'Test',
    schema_type: 'review',
    scope_type: 'global',
    schema_version: 0,
    version: 99,
    change_type: ct,
    is_current: false,
    changed_on: Time.current,
    changed_by: admin
  )
  puts history.errors[:change_type].empty? || history.valid?
end

# 無効な change_type
invalid_history = StudioSettingHistory.new(
  studio_setting: setting,
  name: 'Test',
  schema_type: 'review',
  scope_type: 'global',
  schema_version: 0,
  version: 100,
  change_type: 'invalid_type',
  is_current: false,
  changed_on: Time.current,
  changed_by: admin
)
puts invalid_history.valid? == false
puts invalid_history.errors[:change_type].any?

# クリーンアップ
setting.destroy
```

**期待結果:**
- `true` が出力される（7回: 有効5回 + 無効2回）

### [1-28] studio_setting_histories テーブルのインデックス確認

**確認方法:**
```ruby
indexes = ActiveRecord::Base.connection.indexes(:studio_setting_histories)

# studio_setting_id のインデックス
puts indexes.any? { |i| i.columns == ['studio_setting_id'] }

# [studio_setting_id, version] の一意インデックス
unique_idx = indexes.find { |i| i.columns == ['studio_setting_id', 'version'] }
puts unique_idx.present?
puts unique_idx&.unique == true

# [studio_setting_id, is_current] のインデックス
puts indexes.any? { |i| i.columns == ['studio_setting_id', 'is_current'] }
```

**期待結果:**
- `true` が出力される（4回）

### [1-29] 外部キー制約（CASCADE 削除）の確認

**確認方法:**
```ruby
foreign_keys = ActiveRecord::Base.connection.foreign_keys(:studio_setting_histories)
fk = foreign_keys.find { |fk| fk.to_table == 'studio_settings' }

puts fk.present?
puts fk&.column == 'studio_setting_id'
puts fk&.on_delete == :cascade
```

**期待結果:**
- `true` が出力される（3回）

---

## 2. HTTP テスト

### 事前準備

**API キーの取得:**
```ruby
User.find_by_login('admin').api_key ||
User.find_by_login('admin').tap { |u| u.api_key = SecureRandom.hex(20); u.save! }.api_key
```

**テストデータのクリーンアップ:**
```ruby
# テスト開始前に実行
StudioSettingAssignment.delete_all
StudioSetting.delete_all
```

---

### [2-1] 認証テスト

#### [2-1-1] 未認証でアクセス → 401

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings.json" -Method GET -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 401

#### [2-1-2] API キーで認証 → 200

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method GET
$response.studio_settings
$response.total_count
```

**期待結果:**
- エラーなく完了
- `studio_settings` 配列が返る
- `total_count`, `offset`, `limit` が含まれる

---

### [2-2] 設定の CRUD テスト

#### [2-2-1] 設定作成（POST）

**確認方法:**
```powershell
$body = @{
    studio_setting = @{
        name = "StudioSettings_Test_Create"
        schema_type = "review"
        scope_type = "global"
        schema_version = 0
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$response.studio_setting
```

**期待結果:**
- `studio_setting` オブジェクトが返る
- `studio_setting.id` が返る（数値）
- `studio_setting.name` が `StudioSettings_Test_Create`
- `studio_setting.schema_type` が `review`
- `studio_setting.scope_type` が `global`
- `studio_setting.schema_version` が `0`
- `studio_setting.created_by` が `{ id: N, name: "..." }` 形式
- `studio_setting.payload` が含まれる（null または空）

#### [2-2-2] 設定作成（payload あり）

**確認方法:**
```powershell
$body = @{
    studio_setting = @{
        name = "StudioSettings_Test_WithPayload"
        schema_type = "review"
        scope_type = "project"
        scope_id = 1
        schema_version = 1
        payload = '{"key":"value"}'
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$response
```

**期待結果:**
- `payload` が `{"key":"value"}`
- `scope_id` が `1`
- `schema_version` が `1`

#### [2-2-3] 設定作成（バリデーションエラー: name なし）

**確認方法:**
```powershell
$body = @{
    studio_setting = @{
        schema_type = "review"
        scope_type = "global"
        schema_version = 0
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json" -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).errors
```

**期待結果:**
- ステータスコード 422
- errors に "Name can't be blank" を含む

#### [2-2-4] 設定作成（バリデーションエラー: scope_type なし）

**確認方法:**
```powershell
$body = @{
    studio_setting = @{
        name = "Test"
        schema_type = "review"
        schema_version = 0
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json" -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 422
- errors に "Scope type can't be blank" を含む

#### [2-2-4b] 設定作成（バリデーションエラー: schema_type なし）

**確認方法:**
```powershell
$body = @{
    studio_setting = @{
        name = "Test"
        scope_type = "global"
        schema_version = 0
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json" -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).errors
```

**期待結果:**
- ステータスコード 422
- errors に "Schema type can't be blank" を含む

#### [2-2-5] 設定取得（GET 単体）

**確認方法:**
```powershell
# [2-2-1] で作成した ID を使用
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$SettingId.json?key=$ApiKey" -Method GET
$response.studio_setting
```

**期待結果:**
- `studio_setting` オブジェクトが返る
- `studio_setting.id` が指定した ID と一致
- `studio_setting.payload` が含まれる（show は常に payload を含む）
- `studio_setting.created_by`, `studio_setting.updated_by` が `{ id, name }` 形式

#### [2-2-6] 設定取得（存在しない ID）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/99999.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-2-7] 設定更新（PUT）

**確認方法:**
```powershell
$body = @{
    studio_setting = @{
        name = "StudioSettings_Test_Updated"
        payload = '{"updated":true}'
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$SettingId.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"
$response
```

**期待結果:**
- `name` が `StudioSettings_Test_Updated`
- `payload` が `{"updated":true}`
- `updated_on` が更新されている

#### [2-2-8] 設定削除（論理削除: DELETE）

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$SettingId.json?key=$ApiKey" -Method DELETE
$response.StatusCode

# 削除後に取得して確認
$check = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$SettingId.json?key=$ApiKey" -Method GET
$check.studio_setting.deleted_on
$check.studio_setting.deleted_by
```

**期待結果:**
- ステータスコード 204
- `studio_setting.deleted_on` が null でない（日時が設定されている）
- `studio_setting.deleted_by` が `{ id, name }` 形式

#### [2-2-9] 設定削除（物理削除: DELETE + force=1）

**確認方法:**
```powershell
# 新規作成
$body = @{
    studio_setting = @{
        name = "StudioSettings_Test_ForceDelete"
        schema_type = "review"
        scope_type = "global"
        schema_version = 0
    }
} | ConvertTo-Json -Depth 3
$created = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$deleteId = $created.id

# 物理削除
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$deleteId.json?key=$ApiKey&force=1" -Method DELETE
$response.StatusCode

# 削除後に取得 → 404
$check = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$deleteId.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$check.StatusCode
```

**期待結果:**
- 削除のステータスコード 204
- 取得のステータスコード 404（レコードが存在しない）

#### [2-2-10] 設定更新（存在しない ID）→ 404

**確認方法:**
```powershell
$body = @{
    studio_setting = @{
        name = "NonExistent"
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/99999.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json" -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-2-11] 設定削除（存在しない ID）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/99999.json?key=$ApiKey" -Method DELETE -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-2-12] 設定作成（バリデーションエラー: schema_version 負の数）→ 422

**確認方法:**
```powershell
$body = @{
    studio_setting = @{
        name = "Test"
        schema_type = "review"
        scope_type = "global"
        schema_version = -1
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json" -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).errors
```

**期待結果:**
- ステータスコード 422
- errors に schema_version のバリデーションエラーを含む

---

### [2-3] 設定一覧のフィルタテスト

#### [2-3-1] 一覧取得（フィルタなし）

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method GET
$response.studio_settings.GetType().Name  # Object[] であることを確認
$response.studio_settings.Count
$response.total_count
```

**期待結果:**
- `studio_settings` 配列が返る
- `total_count`, `offset`, `limit` が含まれる
- 論理削除されていないレコードのみ含まれる

#### [2-3-2] scope_type フィルタ

**確認方法:**
```powershell
# テストデータ作成
$body1 = @{ studio_setting = @{ name = "Filter_Global"; schema_type = "review"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$body2 = @{ studio_setting = @{ name = "Filter_Project"; schema_type = "review"; scope_type = "project"; scope_id = 1; schema_version = 0 } } | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body1 -ContentType "application/json"
Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body2 -ContentType "application/json"

# フィルタ
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey&scope_type=global" -Method GET
$response.studio_settings | Where-Object { $_.scope_type -ne "global" }
```

**期待結果:**
- 全て `scope_type` が `global` のレコードのみ
- `project` のレコードは含まれない

#### [2-3-3] scope_id フィルタ

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey&scope_type=project&scope_id=1" -Method GET
$response.studio_settings | Where-Object { $_.scope_id -ne 1 }
```

**期待結果:**
- 全て `scope_id` が `1` のレコードのみ

#### [2-3-4] include_deleted フィルタ

**確認方法:**
```powershell
# 論理削除されたレコードがある状態で
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey&include_deleted=1" -Method GET
$deleted = $response.studio_settings | Where-Object { $_.deleted_on -ne $null }
$deleted.Count
```

**期待結果:**
- 論理削除されたレコードも含まれる

#### [2-3-5] include=payload

**確認方法:**
```powershell
# payload なし
$withoutPayload = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method GET
$withoutPayload.studio_settings[0].PSObject.Properties.Name -contains "payload"

# payload あり
$withPayload = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey&include=payload" -Method GET
$withPayload.studio_settings[0].PSObject.Properties.Name -contains "payload"
```

**期待結果:**
- `include=payload` なし: payload フィールドが含まれない
- `include=payload` あり: payload フィールドが含まれる

#### [2-3-6] schema_type フィルタ

**確認方法:**
```powershell
# テストデータ作成（異なる schema_type）
$body1 = @{ studio_setting = @{ name = "Filter_Review"; schema_type = "review"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$body2 = @{ studio_setting = @{ name = "Filter_Workflow"; schema_type = "workflow"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body1 -ContentType "application/json"
Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body2 -ContentType "application/json"

# フィルタ
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey&schema_type=review" -Method GET
$response.studio_settings | Where-Object { $_.schema_type -ne "review" }
```

**期待結果:**
- 全て `schema_type` が `review` のレコードのみ
- `workflow` のレコードは含まれない

#### [2-3-7] include=assignments（単体取得）

**確認方法:**
```powershell
# テスト用設定を作成し、ユーザーを割り当て
$body = @{ studio_setting = @{ name = "Include_Assignments_Test"; schema_type = "review"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.studio_setting.id

# ユーザーを割り当て
Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$settingId/users/1.json?key=$ApiKey" -Method POST

# include=assignments なし
$without = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId.json?key=$ApiKey" -Method GET
$without.studio_setting.PSObject.Properties.Name -contains "assignments"

# include=assignments あり
$with = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId.json?key=$ApiKey&include=assignments" -Method GET
$with.studio_setting.assignments.Count
```

**期待結果:**
- `include=assignments` なし: assignments フィールドが含まれない
- `include=assignments` あり: assignments 配列が含まれる（1件）

#### [2-3-8] ページネーション: offset

**確認方法:**
```powershell
# テストデータを3件作成
$body1 = @{ studio_setting = @{ name = "Pagination_1"; schema_type = "pagination_test"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$body2 = @{ studio_setting = @{ name = "Pagination_2"; schema_type = "pagination_test"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$body3 = @{ studio_setting = @{ name = "Pagination_3"; schema_type = "pagination_test"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body1 -ContentType "application/json"
Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body2 -ContentType "application/json"
Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body3 -ContentType "application/json"

# offset=1 で取得（schema_type でフィルタして確認しやすくする）
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey&schema_type=pagination_test&offset=1" -Method GET
$response.studio_settings.Count
$response.offset
$response.total_count
```

**期待結果:**
- `offset` が 1
- `total_count` が 3（全件数）
- `studio_settings` の件数が 2（offset=1 で1件スキップ）

#### [2-3-9] ページネーション: limit

**確認方法:**
```powershell
# limit=2 で取得
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey&schema_type=pagination_test&limit=2" -Method GET
$response.studio_settings.Count
$response.limit
$response.total_count
```

**期待結果:**
- `limit` が 2
- `studio_settings` の件数が 2
- `total_count` が 3（全件数、limit の影響を受けない）

#### [2-3-10] ページネーション: offset と limit の組み合わせ

**確認方法:**
```powershell
# offset=1, limit=1 で取得
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey&schema_type=pagination_test&offset=1&limit=1" -Method GET
$response.studio_settings.Count
$response.offset
$response.limit
$response.total_count
```

**期待結果:**
- `offset` が 1
- `limit` が 1
- `studio_settings` の件数が 1
- `total_count` が 3

#### [2-3-11] ページネーション: limit 最大値（100）

**確認方法:**
```powershell
# limit=200（最大値を超える）で取得
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey&limit=200" -Method GET
$response.limit
```

**期待結果:**
- `limit` が 100（最大値に制限される）

#### [2-3-12] ページネーション: limit=0 の場合

**確認方法:**
```powershell
# limit=0 で取得
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey&limit=0" -Method GET
$response.limit
```

**期待結果:**
- `limit` が 25（デフォルト値にフォールバック）

#### [2-3-13] ページネーション: offset が総件数を超える場合

**確認方法:**
```powershell
# offset=1000（総件数より大きい）で取得
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey&schema_type=pagination_test&offset=1000" -Method GET
$response.studio_settings.Count
$response.total_count
```

**期待結果:**
- `studio_settings` が空配列
- `total_count` が 3（全件数は変わらない）

---

### [2-4] ユーザー割り当てテスト

#### [2-4-1] ユーザー一覧取得（GET）

**確認方法:**
```powershell
# テスト用設定を作成
$body = @{ studio_setting = @{ name = "UserAssignment_Test"; schema_type = "review"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.studio_setting.id

$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId/users.json?key=$ApiKey" -Method GET
$response.studio_setting_assignments.GetType().Name
$response.total_count
```

**期待結果:**
- `studio_setting_assignments` 配列が返る（空配列）
- `total_count`, `offset`, `limit` が含まれる

#### [2-4-2] ユーザー追加（POST）

**確認方法:**
```powershell
# admin ユーザーの ID を取得（通常 1）
$adminId = 1

$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$settingId/users/$adminId.json?key=$ApiKey" -Method POST
$response.StatusCode
$assignment = ($response.Content | ConvertFrom-Json).studio_setting_assignment
$assignment
```

**期待結果:**
- ステータスコード 201
- `studio_setting_assignment` オブジェクトが返る
- `setting_id` が設定 ID と一致
- `user` が `{ id, name }` 形式
- `assigned_by` が `{ id, name }` 形式

#### [2-4-3] ユーザー追加（重複）

**確認方法:**
```powershell
# 同じユーザーを再度追加
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$settingId/users/$adminId.json?key=$ApiKey" -Method POST
$response.StatusCode
```

**期待結果:**
- ステータスコード 200（既存を返す）
- 新規作成されない（同じ ID が返る）

#### [2-4-4] ユーザー一覧（追加後）

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId/users.json?key=$ApiKey" -Method GET
$response.studio_setting_assignments.Count
$response.total_count
```

**期待結果:**
- `studio_setting_assignments` に 1件のレコードが返る
- `total_count` が 1

#### [2-4-5] ユーザー削除（DELETE）

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$settingId/users/$adminId.json?key=$ApiKey" -Method DELETE
$response.StatusCode

# 確認
$check = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId/users.json?key=$ApiKey" -Method GET
$check.studio_setting_assignments.Count
$check.total_count
```

**期待結果:**
- ステータスコード 204
- 削除後の `studio_setting_assignments` は空配列
- `total_count` が 0

#### [2-4-6] ユーザー削除（存在しない）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$settingId/users/99999.json?key=$ApiKey" -Method DELETE -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-4-7] ユーザー置換（PUT）

**確認方法:**
```powershell
# テスト用ユーザー作成
$user1Id = 1  # admin

$body = @{ user_ids = @(1) } | ConvertTo-Json -Depth 2

$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"
$response.studio_setting_assignments.Count
```

**期待結果:**
- `studio_setting_assignments` に指定したユーザーのみが割り当てられている
- 以前の割り当ては削除されている

#### [2-4-8] ユーザー置換（空配列で全削除）

**確認方法:**
```powershell
$body = @{ user_ids = @() } | ConvertTo-Json -Depth 2

$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"
$response.studio_setting_assignments.Count

# 確認
$check = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId/users.json?key=$ApiKey" -Method GET
$check.total_count
```

**期待結果:**
- `studio_setting_assignments` が空配列
- 全ての割り当てが削除されている

#### [2-4-9] ユーザー置換（複数ユーザー）

**確認方法:**
```powershell
# テスト用設定を作成
$body = @{ studio_setting = @{ name = "MultiUserTest"; schema_type = "review"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.studio_setting.id

# 複数ユーザーを一括設定
# ※ 環境に存在するユーザー ID を使用（例: admin=1, 他ユーザー=5 など）
# ※ ID 2 が存在しない環境もあるため、事前に確認が必要
$body = @{ user_ids = @(1, 5) } | ConvertTo-Json -Depth 2

$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"
$response.studio_setting_assignments.Count

# 確認
$check = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId/users.json?key=$ApiKey" -Method GET
$check.total_count
```

**期待結果:**
- `studio_setting_assignments` に 2件の割り当てが返る
- 指定した両方のユーザーが割り当てられている

#### [2-4-10] ユーザー追加（存在しないユーザー）→ 422

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$settingId/users/99999.json?key=$ApiKey" -Method POST -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).errors
```

**期待結果:**
- ステータスコード 422
- errors にバリデーションエラーメッセージを含む

#### [2-4-11] 設定物理削除後の assignments 確認

**確認方法:**
```powershell
# テスト用設定を作成
$body = @{ studio_setting = @{ name = "DependentDestroyTest"; schema_type = "review"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.studio_setting.id

# ユーザーを割り当て
Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$settingId/users/1.json?key=$ApiKey" -Method POST

# 割り当て確認
$before = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId/users.json?key=$ApiKey" -Method GET
$before.total_count  # 1

# 設定を物理削除
Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$settingId.json?key=$ApiKey&force=1" -Method DELETE

# 設定が削除されていることを確認
$check = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$settingId.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$check.StatusCode  # 404
```

**期待結果:**
- 設定削除前: `total_count` が 1
- 設定削除後: 設定が 404（assignments も連動して削除されている）

**備考:**
- `dependent: :destroy` により、親レコード削除時に子レコードも削除される
- HTTP API では直接 assignments の存在確認ができないため、Runner テスト [1-12] で詳細を確認

#### [2-4-12] ユーザー割り当て一覧のページネーション

**確認方法:**
```powershell
# テスト用設定を作成
$body = @{ studio_setting = @{ name = "AssignmentPaginationTest"; schema_type = "review"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.studio_setting.id

# 複数ユーザーを割り当て（環境に存在するユーザー ID を使用）
$body = @{ user_ids = @(1, 5) } | ConvertTo-Json -Depth 2
Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"

# limit=1 で取得
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId/users.json?key=$ApiKey&limit=1" -Method GET
$response.studio_setting_assignments.Count
$response.limit
$response.total_count

# offset=1, limit=1 で取得
$response2 = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$settingId/users.json?key=$ApiKey&offset=1&limit=1" -Method GET
$response2.studio_setting_assignments.Count
$response2.offset
```

**期待結果:**
- 1回目: `studio_setting_assignments` が 1件、`limit` が 1、`total_count` が 2
- 2回目: `studio_setting_assignments` が 1件、`offset` が 1

---

### [2-5] ユーザーの設定一覧テスト

#### [2-5-1] ユーザーの設定一覧取得

**確認方法:**
```powershell
# ユーザーに設定を割り当て
$body = @{ studio_setting = @{ name = "UserSettings_Test"; schema_type = "review"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.studio_setting.id

Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$settingId/users/1.json?key=$ApiKey" -Method POST

# 一覧取得
$response = Invoke-RestMethod -Uri "http://localhost:3061/users/1/studio_settings.json?key=$ApiKey" -Method GET
$response.studio_setting_assignments.GetType().Name
$response.studio_setting_assignments | Where-Object { $_.setting_id -eq $settingId }
```

**期待結果:**
- `studio_setting_assignments` 配列が返る
- `total_count`, `offset`, `limit` が含まれる
- 割り当てた設定が含まれる

#### [2-5-2] ユーザーの設定一覧（論理削除された設定は除外）

**確認方法:**
```powershell
# 設定を論理削除
Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$settingId.json?key=$ApiKey" -Method DELETE

# 一覧取得
$response = Invoke-RestMethod -Uri "http://localhost:3061/users/1/studio_settings.json?key=$ApiKey" -Method GET
$response.studio_setting_assignments | Where-Object { $_.setting_id -eq $settingId }
```

**期待結果:**
- 論理削除された設定は含まれない

#### [2-5-3] ユーザーの設定一覧（存在しないユーザー）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/users/99999/studio_settings.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-5-4] ユーザーの設定一覧のページネーション

**確認方法:**
```powershell
# テスト用設定を2件作成し、ユーザーに割り当て
$body1 = @{ studio_setting = @{ name = "UserSettingsPagination_1"; schema_type = "review"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$body2 = @{ studio_setting = @{ name = "UserSettingsPagination_2"; schema_type = "review"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$setting1 = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body1 -ContentType "application/json"
$setting2 = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body2 -ContentType "application/json"

Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$($setting1.studio_setting.id)/users/1.json?key=$ApiKey" -Method POST
Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$($setting2.studio_setting.id)/users/1.json?key=$ApiKey" -Method POST

# limit=1 で取得
$response = Invoke-RestMethod -Uri "http://localhost:3061/users/1/studio_settings.json?key=$ApiKey&limit=1" -Method GET
$response.studio_setting_assignments.Count
$response.limit
$response.total_count
```

**期待結果:**
- `studio_setting_assignments` が 1件
- `limit` が 1
- `total_count` が 2以上（他のテストで割り当てたものも含む可能性あり）

---

### [2-6] エラーハンドリングテスト

#### [2-6-1] 設定の users エンドポイント（存在しない設定）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/99999/users.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-6-2] ユーザー置換（存在しないユーザー ID）→ 422

**確認方法:**
```powershell
$body = @{ user_ids = @(99999) } | ConvertTo-Json -Depth 2

$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json" -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 422
- errors にバリデーションエラーメッセージを含む

---

### [2-7] XML 形式テスト

#### [2-7-1] 設定一覧取得（XML 形式）

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings.xml?key=$ApiKey" -Method GET
$response.StatusCode
$response.Content.StartsWith("<?xml")
```

**期待結果:**
- ステータスコード 200
- レスポンスが XML 形式（`<?xml` で開始）

#### [2-7-2] 設定単体取得（XML 形式）

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/21.xml?key=$ApiKey" -Method GET
$response.StatusCode
$response.Content -match "<studio_setting>"
```

**期待結果:**
- ステータスコード 200
- `<studio_setting>` 要素が含まれる

#### [2-7-3] 存在しない ID（XML 形式）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/99999.xml?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

---

### [2-8] 履歴 API テスト

#### 事前準備（履歴テスト用）

履歴テストを実行する前に、テスト用の設定と履歴を作成する:

```powershell
# 設定を作成
$body = @{
    studio_setting = @{
        name = "History_Test_Setting"
        schema_type = "review"
        scope_type = "global"
        schema_version = 0
        payload = '{"version": 1}'
    }
} | ConvertTo-Json -Depth 3

$setting = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$historyTestSettingId = $setting.studio_setting.id

# 更新して履歴を増やす（version 2）
$body2 = @{
    studio_setting = @{
        payload = '{"version": 2}'
        schema_version = 1
    }
} | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId.json?key=$ApiKey" -Method PUT -Body $body2 -ContentType "application/json"

# さらに更新（version 3）
$body3 = @{
    studio_setting = @{
        payload = '{"version": 3}'
    }
} | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId.json?key=$ApiKey" -Method PUT -Body $body3 -ContentType "application/json"
```

#### [2-8-1] 履歴一覧取得

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$response.studio_setting_histories.GetType().Name
$response.studio_setting_histories.Count
$response.total_count
$response.offset
$response.limit
```

**期待結果:**
- `studio_setting_histories` 配列が返る
- 履歴が 3件（create, update, update）
- `total_count`, `offset`, `limit` が含まれる

#### [2-8-2] 履歴一覧のソート順（version DESC）

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$response.studio_setting_histories[0].version  # 最新
$response.studio_setting_histories[-1].version  # 最古
```

**期待結果:**
- 最初の要素が最新バージョン（version 3）
- 最後の要素が最古バージョン（version 1）

#### [2-8-3] 履歴一覧に含まれるフィールド確認

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$history = $response.studio_setting_histories[0]
$history.PSObject.Properties.Name -contains "id"
$history.PSObject.Properties.Name -contains "studio_setting_id"
$history.PSObject.Properties.Name -contains "version"
$history.PSObject.Properties.Name -contains "name"
$history.PSObject.Properties.Name -contains "schema_type"
$history.PSObject.Properties.Name -contains "change_type"
$history.PSObject.Properties.Name -contains "is_current"
$history.PSObject.Properties.Name -contains "changed_on"
$history.PSObject.Properties.Name -contains "changed_by"
$history.PSObject.Properties.Name -contains "payload"  # デフォルトでは含まれない
```

**期待結果:**
- `id`, `studio_setting_id`, `version`, `name`, `schema_type`, `change_type`, `is_current`, `changed_on`, `changed_by` が含まれる
- `payload` は含まれない（デフォルト）

#### [2-8-4] 履歴一覧（include=payload）

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey&include=payload" -Method GET
$response.studio_setting_histories[0].PSObject.Properties.Name -contains "payload"
$response.studio_setting_histories[0].payload
```

**期待結果:**
- `payload` フィールドが含まれる
- payload の内容が正しい

#### [2-8-5] 履歴一覧のページネーション

**確認方法:**
```powershell
# limit=2 で取得
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey&limit=2" -Method GET
$response.studio_setting_histories.Count
$response.limit
$response.total_count

# offset=1, limit=1 で取得
$response2 = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey&offset=1&limit=1" -Method GET
$response2.studio_setting_histories.Count
$response2.offset
```

**期待結果:**
- 1回目: `studio_setting_histories` が 2件、`limit` が 2、`total_count` が 3
- 2回目: `studio_setting_histories` が 1件、`offset` が 1

#### [2-8-6] 履歴詳細取得

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories/1.json?key=$ApiKey" -Method GET
$response.studio_setting_history
$response.studio_setting_history.version
$response.studio_setting_history.change_type
$response.studio_setting_history.PSObject.Properties.Name -contains "payload"
```

**期待結果:**
- `studio_setting_history` オブジェクトが返る
- `version` が 1
- `change_type` が `create`
- `payload` が含まれる（詳細は常に payload を含む）

#### [2-8-7] 履歴詳細取得（存在しないバージョン）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories/99999.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-8-8] 履歴一覧取得（存在しない設定）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/99999/histories.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-8-9] change_type の確認（create）

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories/1.json?key=$ApiKey" -Method GET
$response.studio_setting_history.change_type
```

**期待結果:**
- `create` が返る

#### [2-8-10] change_type の確認（update）

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories/2.json?key=$ApiKey" -Method GET
$response.studio_setting_history.change_type
```

**期待結果:**
- `update` が返る

#### [2-8-11] is_current フラグの確認

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$currentCount = ($response.studio_setting_histories | Where-Object { $_.is_current -eq $true }).Count
$latestHistory = $response.studio_setting_histories | Where-Object { $_.is_current -eq $true }
$latestHistory.version
```

**期待結果:**
- `is_current: true` の履歴は 1件のみ
- 最新バージョン（version 3）が `is_current: true`

---

### [2-9] 履歴からの復元テスト

#### [2-9-1] 履歴からの復元（POST /restore）

**確認方法:**
```powershell
# version 1 に復元
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/restore.json?key=$ApiKey&version=1" -Method POST
$response.studio_setting
$response.studio_setting.schema_version  # 0 に戻る
```

**期待結果:**
- `studio_setting` オブジェクトが返る（更新後の設定）
- `schema_version` が 0（version 1 の値に復元）

#### [2-9-2] 復元後の履歴確認（change_type = restore）

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$latestHistory = $response.studio_setting_histories[0]
$latestHistory.version
$latestHistory.change_type
$latestHistory.restored_from_version
```

**期待結果:**
- 最新履歴の `version` が 4
- `change_type` が `restore`
- `restored_from_version` が 1

#### [2-9-3] 復元でコメントを指定

**確認方法:**
```powershell
# version 2 に復元（コメント付き）
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/restore.json?key=$ApiKey&version=2&comment=Restore%20to%20v2" -Method POST

# 履歴を確認
$histories = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$histories.studio_setting_histories[0].comment
```

**期待結果:**
- 最新履歴の `comment` が `Restore to v2`

#### [2-9-4] 現在のバージョンに復元 → 400 エラー

**確認方法:**
```powershell
# 最新バージョンを取得
$histories = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$currentVersion = ($histories.studio_setting_histories | Where-Object { $_.is_current -eq $true }).version

# 現在のバージョンに復元を試みる
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/restore.json?key=$ApiKey&version=$currentVersion" -Method POST -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).errors
```

**期待結果:**
- ステータスコード 400
- errors に "Cannot restore to the current version" を含む

#### [2-9-5] 存在しないバージョンに復元 → 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/restore.json?key=$ApiKey&version=99999" -Method POST -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-9-6] 存在しない設定に復元 → 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/99999/restore.json?key=$ApiKey&version=1" -Method POST -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

---

### [2-10] 論理削除と履歴テスト

#### [2-10-1] 論理削除時の履歴確認（change_type = delete）

**確認方法:**
```powershell
# 新しいテスト用設定を作成
$body = @{
    studio_setting = @{
        name = "Delete_History_Test"
        schema_type = "review"
        scope_type = "global"
        schema_version = 0
        payload = '{"test": true}'
    }
} | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$deleteTestId = $setting.studio_setting.id

# 論理削除
Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$deleteTestId.json?key=$ApiKey" -Method DELETE

# 履歴を確認
$histories = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$deleteTestId/histories.json?key=$ApiKey" -Method GET
$deleteHistory = $histories.studio_setting_histories | Where-Object { $_.change_type -eq 'delete' }
$deleteHistory.version
$deleteHistory.change_type
```

**期待結果:**
- `change_type` が `delete` の履歴が存在
- version が 2（create の次）

#### [2-10-2] 論理削除された設定の履歴取得（可能）

**確認方法:**
```powershell
# 論理削除後も履歴を取得可能
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$deleteTestId/histories.json?key=$ApiKey" -Method GET
$response.studio_setting_histories.Count
$response.total_count
```

**期待結果:**
- 履歴が取得できる（2件: create, delete）
- `total_count` が 2

#### [2-10-3] 論理削除された設定からの復元（change_type = undelete）

**確認方法:**
```powershell
# version 1 に復元（削除状態から復活）
$response = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$deleteTestId/restore.json?key=$ApiKey&version=1" -Method POST
$response.studio_setting.deleted_on  # null になっているはず

# 履歴を確認
$histories = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$deleteTestId/histories.json?key=$ApiKey" -Method GET
$latestHistory = $histories.studio_setting_histories[0]
$latestHistory.change_type
$latestHistory.restored_from_version
```

**期待結果:**
- 設定の `deleted_on` が null（復活している）
- 最新履歴の `change_type` が `undelete`
- `restored_from_version` が 1

#### [2-10-4] 更新による undelete（change_type = undelete）

**確認方法:**
```powershell
# 新しいテスト用設定を作成して論理削除
$body = @{
    studio_setting = @{
        name = "Undelete_Update_Test"
        schema_type = "review"
        scope_type = "global"
        schema_version = 0
    }
} | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$undeleteTestId = $setting.studio_setting.id

# 論理削除
Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$undeleteTestId.json?key=$ApiKey" -Method DELETE

# 更新で復活（deleted_on を null に）
$body2 = @{
    studio_setting = @{
        deleted_on = $null
        payload = '{"restored": true}'
    }
} | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$undeleteTestId.json?key=$ApiKey" -Method PUT -Body $body2 -ContentType "application/json"

# 履歴を確認
$histories = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$undeleteTestId/histories.json?key=$ApiKey" -Method GET
$latestHistory = $histories.studio_setting_histories[0]
$latestHistory.change_type
$latestHistory.restored_from_version  # null（restore ではないので）
```

**期待結果:**
- 最新履歴の `change_type` が `undelete`
- `restored_from_version` が null（update API 経由の復活なので）

---

### [2-11] 履歴削除テスト

#### [2-11-1] 過去バージョンの履歴削除

**確認方法:**
```powershell
# 削除前の履歴件数を確認
$before = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$beforeCount = $before.total_count

# version 1 の履歴を削除
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories/1.json?key=$ApiKey" -Method DELETE
$response.StatusCode

# 削除後の履歴件数を確認
$after = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$after.total_count
```

**期待結果:**
- ステータスコード 204
- 履歴件数が 1件減少

#### [2-11-2] 現在バージョンの履歴削除 → 400 エラー

**確認方法:**
```powershell
# 現在のバージョン（is_current: true）を取得
$histories = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$currentVersion = ($histories.studio_setting_histories | Where-Object { $_.is_current -eq $true }).version

# 現在のバージョンを削除しようとする
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories/$currentVersion.json?key=$ApiKey" -Method DELETE -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).errors
```

**期待結果:**
- ステータスコード 400
- errors に "Cannot delete the current version" を含む

#### [2-11-3] 存在しないバージョンの履歴削除 → 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$historyTestSettingId/histories/99999.json?key=$ApiKey" -Method DELETE -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-11-4] 存在しない設定の履歴削除 → 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/99999/histories/1.json?key=$ApiKey" -Method DELETE -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

---

### [2-12] 物理削除と履歴の CASCADE 削除

#### [2-12-1] 物理削除時に履歴も削除される

**確認方法:**
```powershell
# 新しいテスト用設定を作成
$body = @{
    studio_setting = @{
        name = "Cascade_Delete_Test"
        schema_type = "review"
        scope_type = "global"
        schema_version = 0
    }
} | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$cascadeTestId = $setting.studio_setting.id

# 履歴があることを確認
$histories = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings/$cascadeTestId/histories.json?key=$ApiKey" -Method GET
$histories.total_count  # 1

# 物理削除
Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$cascadeTestId.json?key=$ApiKey&force=1" -Method DELETE

# 設定が 404 になることを確認
$check = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$cascadeTestId.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$check.StatusCode

# 履歴も 404 になることを確認
$historyCheck = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$cascadeTestId/histories.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$historyCheck.StatusCode
```

**期待結果:**
- 削除前: 履歴が 1件存在
- 物理削除後: 設定が 404
- 物理削除後: 履歴一覧も 404（設定が存在しないため）

---

### [2-13] 履歴 API の XML 形式テスト

#### [2-13-1] 履歴一覧取得（XML 形式）

**確認方法:**
```powershell
# テスト用設定を作成
$body = @{
    studio_setting = @{
        name = "XML_History_Test"
        schema_type = "review"
        scope_type = "global"
        schema_version = 0
    }
} | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$xmlTestId = $setting.studio_setting.id

$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$xmlTestId/histories.xml?key=$ApiKey" -Method GET
$response.StatusCode
$response.Content.StartsWith("<?xml")
```

**期待結果:**
- ステータスコード 200
- レスポンスが XML 形式

#### [2-13-2] 履歴詳細取得（XML 形式）

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/studio_settings/$xmlTestId/histories/1.xml?key=$ApiKey" -Method GET
$response.StatusCode
$response.Content -match "<studio_setting_history>"
```

**期待結果:**
- ステータスコード 200
- `<studio_setting_history>` 要素が含まれる

---

## 3. ブラウザテスト

なし（API のみの機能のため）

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいて以下の順序でテストを実行する:

1. フェーズ 0: Puma 停止（SQLite ロック回避）
2. フェーズ 1: 登録確認テスト実行
   - バッチ 1: [1-1]～[1-12] 基本機能（12件）
   - バッチ 2: [1-13]～[1-29] 履歴機能（17件）
3. フェーズ 2: コンテナ再起動（HTTP テストに備える）
4. フェーズ 3: HTTP テスト実行
   - [2-1]～[2-7]: 基本機能
   - [2-8]～[2-13]: 履歴機能

### Runner テスト実行時の注意事項

- バッチ実行のガイドラインは CLAUDE.md の「Runner テストのバッチ実行」を参照
- SQLite ロック回避は CLAUDE.md の「SQLite ロック競合の回避」を参照
- bash 経由での `!` エスケープ問題は CLAUDE.md の「Runner テスト」セクションを参照

### HTTP テスト実行時の注意事項

- API キーは事前に取得しておく
- テストの順序依存性に注意（作成 → 取得 → 更新 → 削除）
- テストデータは削除せず残す（後から確認可能）
- ユーザー ID はテスト環境に存在するものを使用する（ID 2 が存在しない場合がある）
- PowerShell での型チェック: JSON の数値は `Int64` として解釈されるため、`-is [int]` は False になる。数値チェックには `-gt 0` や `-is [int64]` を使用する

### 履歴 API テスト実行時の注意事項

- [2-8] 以降の履歴テストは、[2-8] の事前準備を先に実行すること
- 履歴テストは順序依存性があるため、番号順に実行すること
- `$historyTestSettingId` 変数は履歴テスト全体で共有する
- 履歴削除テスト [2-11] は履歴を削除するため、他のテストの後に実行すること
- CASCADE 削除テスト [2-12] は新しい設定を作成するため、他のテストに影響しない

### レスポンス形式

- 一覧取得: `{ "<リソース名>": [...], "total_count": N, "offset": N, "limit": N }`
- 単体取得/作成/更新: `{ "<リソース名>": {...} }`
- 関連オブジェクト: `{ "id": N, "name": "..." }` 形式（ID のみではない）
- PUT /studio_settings/:id/users のリクエスト: `{ "user_ids": [1, 2, 3] }`
- 履歴一覧: `{ "studio_setting_histories": [...], "total_count": N, "offset": N, "limit": N }`
- 履歴詳細: `{ "studio_setting_history": {...} }` （payload を含む）
- restore 成功時: `{ "studio_setting": {...} }` （更新後の設定を返す）
- 履歴削除成功時: HTTP 204 No Content
