# Studio Settings API テスト仕様書

## 概要

Redmine Studio の汎用設定を Redmine サーバー側に保存・取得するための API 機能のテスト仕様。

**主な機能:**
- 汎用設定の CRUD 操作
- 論理削除 / 物理削除のサポート（プロジェクトを削除すると、その範囲の設定も物理削除）
- ユーザーへの設定割り当て管理
- 本人の設定（`scope_type = user`。1 人に 1 種類 1 つ・本人と admin だけが書ける・履歴なし・削除は物理削除・利用者を削除すると一緒に消える）
- 版（`version`）による書き込みの衝突検出と、版だけを返すエンドポイント（`versions`）
- 送った値の形と長さの検証（形の違う値・長すぎる値・実在しないプロジェクトを、何が悪いかの分かる 422 で断る）

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| モデル | `StudioSetting`, `StudioSettingAssignment`, `StudioSettingHistory` |
| DBテーブル | `studio_settings`, `studio_setting_assignments`, `studio_setting_histories` |
| コントローラ | `StudioSettingsController`, `StudioSettingUsersController`, `UserStudioSettingsController`, `StudioSettingHistoriesController` |
| パッチ | `User` に `RedmineStudioPlugin::StudioSettings::UserPatch`（利用者の削除のあとに本人の設定を消す）、`Project` に `RedmineStudioPlugin::StudioSettings::ProjectPatch`（プロジェクトの削除のあとにその範囲の設定を消す） |
| 認証 | API キー必須（未認証で 401） |

### API エンドポイント

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/studio_settings.json` | 設定一覧取得 |
| GET | `/studio_settings/:id.json` | 設定詳細取得 |
| POST | `/studio_settings.json` | 設定作成 |
| POST | `/studio_settings/versions.json` | 本人の設定（`own`: schema_type の配列）と id で頼んだ設定（`ids`: id の配列）の版だけを返す |
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
    "version": 1,
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

**version:** 作成時 1、書き込み（更新・論理削除・復元）が成功するたびに 1 進む（すべてのスコープ。中身が同じ PUT でも進む）。履歴の `version`（履歴の通し番号）とは別物。
PUT の `studio_setting` の中に `expected_version` を添えると、今の版と違えば 409 で今の設定（payload 込み）を返す。`studio_setting` の外に置いたものは見ない。
数として読めない `expected_version`（`"1.0"`・`"abc"`・`true` など）は、スコープを問わず 422（`expected_version must be an integer`）。
user スコープでは `expected_version` が必須（無ければ 422 `expected_version is required`）。

**scope_type:** `global`・`project`・`user` のどれか（それ以外は 422。大文字小文字も区別する）。

**user スコープ（本人の設定）:**

| 操作 | 振る舞い |
|------|----------|
| 作成 | `scope_id` を省くと自分。他人の分を作れるのは admin だけ（403）。持ち主は実在の利用者（いなければ 422）。同じ持ち主・同じ schema_type が既にあれば 409 で今ある設定を返す |
| 取得 | ログインしていれば誰でも読める（一覧でもまとめて読める） |
| 更新・削除・履歴の操作 | 本人と admin だけ（403） |
| 割り当て | 一覧は誰でも読める。置換・追加は本人と admin 以外は 403、本人と admin でも 422（本人の設定は人に割り当てない）。削除は本人と admin 以外は 403 |
| 更新 | `scope_type` の user への／からの付け替えは 422（`scope_type cannot be changed to or from user`）。`scope_id` と `schema_type` は送っても無視する |
| 削除 | 常に物理削除（以後 404）。同じ schema_type で作り直せる |
| 履歴 | 残さない |

**版だけの取得（POST /studio_settings/versions）:**
```json
// リクエスト
{ "own": ["work_settings"], "ids": [12, 34] }
// レスポンス
{
  "studio_setting_versions": {
    "own":  [ { "id": 5, "schema_type": "work_settings", "version": 3 } ],
    "team": [ { "id": 12, "version": 7, "updated_on": "2026-..." } ]
  }
}
```
- `own` は自分の本人の設定（削除済みでないもの）だけ。`team` は `ids` で頼んだうち、見える・削除済みでない設定（スコープは問わない。user スコープも返す）
- 求めたのに返らないものは「無い」。payload は返さない
- `own`・`ids` は配列で送る。どちらも無いとき・配列でないとき・`ids` に整数でない値があるときは 422（読めない依頼を 200 の空で返さない）。明示の空配列は 200
- リクエストは `studio_setting_versions` で包んでもよい（XML は一番外側の要素が 1 つ要るので、包んで送る。JSON はどちらでも可）。XML の配列には `type="array"` が要る（無いと 422）

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

### フェーズ 0: Runner テストの流し方

Puma は止めずに、動かしたまま Runner テストを流す。公式 Docker イメージでは Puma がコンテナの PID 1 なので、止めるとコンテナごと止まり、`docker exec` が使えなくなる。

各バッチの Ruby スクリプトはファイルにしてコンテナにコピーし、`redmine` 利用者で実行する。`bash -c "... rails runner '...'"` の形でコードを直接渡すと、`!` や引用符の扱いで壊れやすい。

```bash
docker cp batch1.rb {Container}:/tmp/studio_settings_api_batch1.rb
docker exec -u redmine -w /usr/src/redmine {Container} bundle exec rails runner /tmp/studio_settings_api_batch1.rb
```

- `bash` のブロックは bash で流す（Windows では Git Bash で、`MSYS_NO_PATHCONV=1` を付ける。付けないと `/usr/src/redmine` や `/tmp/...` が Windows のパスに書き換わる）
- `-u redmine` を付けずに root で動かすと、ログや `files` の中に root の持ち物のファイルができ、あとで Redmine から書けなくなることがある。root が要る手順だけ `-u` を付けずに行う
- `SQLite3::BusyException`（database is locked）が出たときは、少し待ってそのバッチを流し直す

### フェーズ 1: Runner テスト（バッチ 1-4）

プラグインの登録状態と、設定・履歴・可視性の動きを確認する。

- バッチ 1: [1-1] ～ [1-12] を1つのスクリプトにまとめて実行（設定・割り当て基本機能）
- バッチ 2: [1-13] ～ [1-29] を1つのスクリプトにまとめて実行（履歴機能）
- バッチ 3: [1-30] ～ [1-35] を1つのスクリプトにまとめて実行（可視性・属性名の翻訳）
- バッチ 4: [1-36] ～ [1-49] を1つのスクリプトにまとめて実行（本人の設定と版、利用者・プロジェクトの削除の後片付け、入力の検証）

### フェーズ 2: HTTP テスト

API の動作を確認する。コンテナの再起動は要らない。Runner テストで変えるのは DB の中身だけで、Puma はリクエストのたびに DB を読む。

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

# scope_type は global / project / user のどれか（大文字小文字も区別する）
rs = StudioSetting.new(name: 'Test', schema_type: 'review', scope_type: 'USER', scope_id: 1, schema_version: 0)
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
- 全て `true` が出力される（10回）

**備考:**
- バリデーションエラーメッセージはロケールにより異なる（"can't be blank" / "cannot be blank"）
- エラーの存在確認には `.any?` を使用する

### [1-10] StudioSettingAssignment バリデーション確認

**確認方法:**
```ruby
# テスト用設定を作成
admin = User.find_by_login('{Username}')
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
admin = User.find_by_login('{Username}')
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
admin = User.find_by_login('{Username}')
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
admin = User.find_by_login('{Username}')
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
admin = User.find_by_login('{Username}')
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
admin = User.find_by_login('{Username}')
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
admin = User.find_by_login('{Username}')
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
admin = User.find_by_login('{Username}')
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
admin = User.find_by_login('{Username}')
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
admin = User.find_by_login('{Username}')
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
admin = User.find_by_login('{Username}')
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
admin = User.find_by_login('{Username}')
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

### [1-26] current_history_version メソッド確認（履歴の最新の通し番号）

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
User.current = admin
setting = StudioSetting.create(name: 'CurrentVersionTest', schema_type: 'review', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)

# 履歴なしの場合は 0
puts setting.current_history_version == 0

# 履歴作成後
setting.create_history('create', admin)
puts setting.current_history_version == 1

setting.payload = '{"v2": true}'
setting.save
setting.create_history('update', admin)
puts setting.current_history_version == 2

# クリーンアップ
setting.destroy
```

**期待結果:**
- `true` が出力される（3回）

### [1-27] change_type の inclusion バリデーション確認

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
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

## 1B. 可視性（Runner テスト）

`StudioSetting.visible` scope / `visible?` を検証する。global は全ログインユーザーに可視、project スコープは当該プロジェクトのメンバーのみ、admin は全件。**バッチ 3**（[1-30]〜[1-35]）としてまとめて実行し、[1-30] が前提データを作る。

### [1-30] 可視性テストデータ整備（前提）

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
User.current = admin
role = Role.givable.first

# ユーザー（冪等・アクティブ化）
member = User.find_by_login('vis_member') || User.new(login: 'vis_member', firstname: 'Vis', lastname: 'Member', mail: 'vis_member@example.com')
member.password, member.password_confirmation = 'password123', 'password123' if member.new_record?
member.status = User::STATUS_ACTIVE
member.save

nonmember = User.find_by_login('vis_nonmember') || User.new(login: 'vis_nonmember', firstname: 'Vis', lastname: 'NonMember', mail: 'vis_nonmember@example.com')
nonmember.password, nonmember.password_confirmation = 'password123', 'password123' if nonmember.new_record?
nonmember.status = User::STATUS_ACTIVE
nonmember.save

# プロジェクト（冪等）
proj_a = Project.find_by_identifier('vis-proj-a') || Project.create(name: 'Vis Proj A', identifier: 'vis-proj-a')
proj_b = Project.find_by_identifier('vis-proj-b') || Project.create(name: 'Vis Proj B', identifier: 'vis-proj-b')

# メンバーシップ（vis_member を proj_a のみに）
unless member.member_of?(proj_a)
  m = Member.new(user_id: member.id, project_id: proj_a.id)
  m.roles = [role]
  m.save
end

# 設定（冪等・global / proj_a / proj_b）
def upsert_setting(name, scope_type, scope_id, admin)
  s = StudioSetting.find_by(name: name) || StudioSetting.new(name: name, schema_type: 'work', schema_version: 0, created_by: admin)
  s.scope_type = scope_type
  s.scope_id = scope_id
  s.updated_by = admin
  s.save
  s
end
g = upsert_setting('Vis_Global', 'global', nil, admin)
sa = upsert_setting('Vis_ProjA', 'project', proj_a.id, admin)
sb = upsert_setting('Vis_ProjB', 'project', proj_b.id, admin)

puts member.reload.member_of?(proj_a)
puts (nonmember.reload.member_of?(proj_a) == false)
puts [g, sa, sb].all?(&:persisted?)
puts "member_key=#{member.api_key}"
puts "nonmember_key=#{nonmember.api_key}"
puts "proj_a=#{proj_a.id} proj_b=#{proj_b.id} member_id=#{member.id}"
```

**期待結果:**
- `true` が 3 回出力される（member は proj_a 所属／nonmember は非所属／設定 3 件が永続化）
- `member_key` / `nonmember_key` / `proj_a` / `proj_b` / `member_id` が出力される（HTTP テストで使用）

### [1-31] visible scope: admin は全件

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
names = StudioSetting.visible(admin).pluck(:name)
puts names.include?('Vis_Global')
puts names.include?('Vis_ProjA')
puts names.include?('Vis_ProjB')
```

**期待結果:**
- `true` が 3 回（admin は他プロジェクトの設定も見える）

### [1-32] visible scope: 非メンバーは global のみ（project 設定は除外）

**確認方法:**
```ruby
nonmember = User.find_by_login('vis_nonmember')
names = StudioSetting.visible(nonmember).pluck(:name)
puts names.include?('Vis_Global')
puts (names.include?('Vis_ProjA') == false)
puts (names.include?('Vis_ProjB') == false)
```

**期待結果:**
- `true` が 3 回（global は可視・非所属 project 2 件は除外＝除外が効いたことを確認）

### [1-33] visible scope: メンバーは自分の project を含み他 project は除外

**確認方法:**
```ruby
member = User.find_by_login('vis_member')
names = StudioSetting.visible(member).pluck(:name)
puts names.include?('Vis_Global')
puts names.include?('Vis_ProjA')
puts (names.include?('Vis_ProjB') == false)
```

**期待結果:**
- `true` が 3 回（global＋所属 proj_a は可視・非所属 proj_b は除外）

### [1-34] visible? 単体判定

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
member = User.find_by_login('vis_member')
nonmember = User.find_by_login('vis_nonmember')
g = StudioSetting.find_by(name: 'Vis_Global')
sa = StudioSetting.find_by(name: 'Vis_ProjA')

puts g.visible?(nonmember)
puts sa.visible?(member)
puts (sa.visible?(nonmember) == false)
puts sa.visible?(admin)
```

**期待結果:**
- `true` が 4 回（global は非メンバーも true／project はメンバー・admin が true・非メンバーは false）

### [1-35] 属性名の翻訳確認

バリデーションエラーメッセージ（`render_validation_errors` → `full_messages`）の属性名は `human_attribute_name` で解決される。
モデルは `ActiveRecord::Base` 直接継承のため Redmine の `field_*` 探索（Redmine 6.x では `ApplicationRecord` にある）を通らず、
Rails 標準の `activerecord.attributes.<モデル>.*` キーで翻訳する（locale: `studio_settings_ja.yml` / `studio_settings_en.yml`）。
本テストはロケールを明示して翻訳値を確認する（意図が翻訳確認のため、ロケール固定は正当）。

**確認方法:**
```ruby
ja_expected = {
  StudioSetting => { name: '名称', schema_type: 'スキーマ種別', scope_type: 'スコープ種別', schema_version: 'スキーマバージョン' },
  StudioSettingAssignment => { setting_id: '設定', user_id: 'ユーザー', assigned_by_id: '割り当て実行者' },
  StudioSettingHistory => { name: '名称', version: 'バージョン', change_type: '変更種別', changed_by_id: '変更者' },
}
ja_ok = I18n.with_locale(:ja) do
  ja_expected.all? { |klass, attrs| attrs.all? { |attr, label| klass.human_attribute_name(attr) == label } }
end
en_ok = I18n.with_locale(:en) do
  StudioSetting.human_attribute_name(:schema_type) == 'Schema type' &&
    StudioSettingAssignment.human_attribute_name(:user_id) == 'User'
end
puts ja_ok
puts en_ok
```

**期待結果:** `true` が 2 回出力される

---

## 1C. 本人の設定と版・入力の検証（Runner テスト）

user スコープ（本人の設定）と版（`version`）、利用者・プロジェクトを削除したときの後片付け、入力の検証（長さ・プロジェクトの実在・comment）を、モデルと DB で確かめる。**バッチ 4**（[1-36]〜[1-49]）としてまとめて実行する。バッチ 3（[1-30]）が作る `vis_member` / `vis_nonmember` を使うので、バッチ 3 の後に流す。各テストは `schema_type` に毎回違う値（`SecureRandom.hex`）を使い、最後に作ったデータを消すので、何度流してもよい。

### [1-36] studio_settings の version / owner_id 列

**確認方法:**
```ruby
cols = ActiveRecord::Base.connection.columns(:studio_settings).index_by(&:name)
puts cols['version'].present?
puts cols['version']&.null == false
puts cols['version']&.default.to_s == '1'
puts cols['owner_id'].present?
puts cols['owner_id']&.null == true
```

**期待結果:**
- `true` が 5 回（version は NOT NULL・既定値 1、owner_id は NULL 可）

### [1-37] (schema_type, owner_id) の一意インデックス

**確認方法:**
```ruby
idx = ActiveRecord::Base.connection.indexes(:studio_settings).find { |i| i.columns == %w[schema_type owner_id] }
puts idx.present?
puts idx&.unique == true
# 持ち主のある行だけに効く条件付きの索引（MySQL は条件を持てないので条件なし。MySQL は NULL どうしを重ならないとみなすので同じ働き）
if ActiveRecord::Base.connection.adapter_name =~ /mysql/i
  puts idx&.where.blank?
else
  puts idx&.where.to_s.include?('owner_id IS NOT NULL')
end
```

**期待結果:**
- `true` が 3 回

### [1-38] user スコープのバリデーションと持ち主

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
member = User.find_by_login('vis_member')
User.current = admin
t = "rt_user_#{SecureRandom.hex(4)}"
attrs = { name: 'p', schema_type: t, scope_type: 'user', schema_version: 0, created_by: admin, updated_by: admin }

# scope_id（持ち主）必須
s = StudioSetting.new(attrs)
puts s.valid? == false
puts s.errors[:scope_id].any?

# 保存すると owner_id = scope_id、版は 1
s.scope_id = admin.id
puts s.save
puts s.owner_id == admin.id
puts s.version == 1

# 同じ持ち主・同じ schema_type は 2 つ目を作れない
dup = StudioSetting.new(attrs.merge(scope_id: admin.id))
puts dup.valid? == false
puts dup.errors[:schema_type].any?

# 持ち主が違えば同じ schema_type でも作れる
other = StudioSetting.new(attrs.merge(scope_id: member.id))
puts other.save

# user 以外は owner_id を持たず、同じ schema_type をいくつでも作れる
g1 = StudioSetting.create(attrs.merge(scope_type: 'global'))
g2 = StudioSetting.create(attrs.merge(scope_type: 'global'))
puts g1.persisted? && g2.persisted?
puts g1.owner_id.nil? && g2.owner_id.nil?

[s, other, g1, g2].each { |x| x.destroy if x.persisted? }
```

**期待結果:**
- `true` が 10 回

### [1-39] 版は書き込みのたびに進む（全スコープ）

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
User.current = admin
t = "rt_ver_#{SecureRandom.hex(4)}"
u = StudioSetting.create!(name: 'p', schema_type: t, scope_type: 'user', scope_id: admin.id, schema_version: 0, created_by: admin, updated_by: admin)
g = StudioSetting.create!(name: 'g', schema_type: t, scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)
puts u.version == 1 && g.version == 1

u.update!(payload: '{"a":1}')
g.update!(payload: '{"a":1}')
puts u.reload.version == 2
puts g.reload.version == 2

u.update!(payload: '{"a":2}')
puts u.reload.version == 3

[u, g].each(&:destroy)
```

**期待結果:**
- `true` が 4 回

### [1-40] user スコープの visible? / editable?

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
member = User.find_by_login('vis_member')
nonmember = User.find_by_login('vis_nonmember')
User.current = admin
t = "rt_perm_#{SecureRandom.hex(4)}"
s = StudioSetting.create!(name: 'p', schema_type: t, scope_type: 'user', scope_id: member.id, schema_version: 0, created_by: member, updated_by: member)

# 読むのはログインしていれば誰でも
puts s.visible?(member)
puts s.visible?(nonmember)
puts s.visible?(User.anonymous) == false
puts StudioSetting.visible(nonmember).where(id: s.id).exists?

# 書けるのは本人と admin だけ
puts s.editable?(member)
puts s.editable?(admin)
puts s.editable?(nonmember) == false
puts s.editable?(User.anonymous) == false

s.destroy
```

**期待結果:**
- `true` が 8 回

### [1-41] user スコープは履歴を残さない

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
User.current = admin
t = "rt_hist_#{SecureRandom.hex(4)}"
u = StudioSetting.create!(name: 'p', schema_type: t, scope_type: 'user', scope_id: admin.id, schema_version: 0, created_by: admin, updated_by: admin)
u.create_history('create', admin)
puts u.histories.count == 0

g = StudioSetting.create!(name: 'g', schema_type: t, scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)
g.create_history('create', admin)
puts g.histories.count == 1

[u, g].each(&:destroy)
```

**期待結果:**
- `true` が 2 回（user は 0 件、global は従来どおり 1 件）

### [1-42] DB の一意インデックスはバリデーションを通さなくても重複を断る

2 台の端末が同時に初回保存したとき、検証をすり抜けても DB が止めることを確かめる。

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
User.current = admin
t = "rt_uniq_#{SecureRandom.hex(4)}"
attrs = { name: 'p', schema_type: t, scope_type: 'user', scope_id: admin.id, schema_version: 0, created_by: admin, updated_by: admin }
first = StudioSetting.create!(attrs)

raised = false
begin
  # 検証を飛ばす（validate: false は before_validation も飛ばすので、owner_id は自分で入れる。
  # 2 台がどちらも検証を通った後に保存する状況にそろえる）
  dup = StudioSetting.new(attrs)
  dup.owner_id = admin.id
  dup.save(validate: false)
rescue ActiveRecord::RecordNotUnique
  raised = true
end
puts raised
puts StudioSetting.where(schema_type: t).count == 1

StudioSetting.where(schema_type: t).destroy_all
```

**期待結果:**
- `true` が 2 回

### [1-43] versions のルーティング

**確認方法:**
```ruby
r = Rails.application.routes.recognize_path('/studio_settings/versions', method: :post)
puts r[:controller] == 'studio_settings' && r[:action] == 'versions'
# versions は POST だけ。GET は versions に向かない（show の :id = 'versions' として扱われ、404 になる）
r2 = Rails.application.routes.recognize_path('/studio_settings/versions', method: :get) rescue nil
puts r2.nil? || r2[:action] != 'versions'
```

**期待結果:**
- `true` が 2 回

### [1-44] 本人の設定は範囲・持ち主・種類を変えられない（モデル）

コントローラーを通らない書き込み（runner・復元など）でも守られることを確かめる。

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
member = User.find_by_login('vis_member')
User.current = admin
t = "rt_immut_#{SecureRandom.hex(4)}"
u = StudioSetting.create!(name: 'p', schema_type: t, scope_type: 'user', scope_id: admin.id, schema_version: 0, created_by: admin, updated_by: admin)
g = StudioSetting.create!(name: 'g', schema_type: t, scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)

# user → global、global → user は断る
u.scope_type = 'global'
puts u.save == false
u.reload
g.scope_type = 'user'
g.scope_id = admin.id
puts g.save == false
g.reload

# 本人の設定の持ち主・種類は変えられない
u.scope_id = member.id
puts u.save == false
u.reload
u.schema_type = "#{t}_x"
puts u.save == false
u.reload

# ほかの範囲どうしの付け替えは従来どおりできる
g.scope_type = 'project'
g.scope_id = Project.first.id
puts g.save
puts u.reload.version == 1

[u, g].each(&:destroy)
```

**期待結果:**
- `true` が 6 回

### [1-45] 本人の設定の持ち主は実在の利用者

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
User.current = admin
t = "rt_owner_#{SecureRandom.hex(4)}"
attrs = { name: 'p', schema_type: t, scope_type: 'user', schema_version: 0, created_by: admin, updated_by: admin }

# いない ID・匿名・グループは持ち主にできない
puts StudioSetting.new(attrs.merge(scope_id: 999_999)).valid? == false
puts StudioSetting.new(attrs.merge(scope_id: User.anonymous.id)).valid? == false
group = Group.first
puts group.nil? || StudioSetting.new(attrs.merge(scope_id: group.id)).valid? == false

# 実在の利用者なら作れる
s = StudioSetting.new(attrs.merge(scope_id: admin.id))
puts s.save
s.destroy
```

**期待結果:**
- `true` が 4 回（グループが無い環境では 3 つ目は確かめずに `true`）

### [1-46] 論理削除・復元も版を進め、履歴を同じ取引の中で作る

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
User.current = admin
t = "rt_lock_#{SecureRandom.hex(4)}"
g = StudioSetting.create!(name: 'g', schema_type: t, scope_type: 'global', schema_version: 0, payload: '{"a":1}', created_by: admin, updated_by: admin)
g.create_history('create', admin)
puts g.version == 1

# 論理削除：版が 2、履歴が 2 件（delete）
puts g.soft_delete(admin)
puts g.reload.version == 2
puts g.histories.count == 2 && g.histories.find_by(is_current: true).change_type == 'delete'

# 復元：版が 3、履歴が 3 件（undelete）、削除の印が消える
puts g.restore_from_version(1, admin)
puts g.reload.version == 3
puts g.deleted_on.nil?
puts g.histories.count == 3 && g.histories.find_by(is_current: true).change_type == 'undelete'
puts g.current_history_version == 3

g.destroy
```

**期待結果:**
- `true` が 9 回

### [1-47] 利用者を削除すると、その人の本人の設定も消える

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
User.current = admin
t = "rt_userdel_#{SecureRandom.hex(4)}"
mk = ->(login) {
  u = User.new(firstname: 'Del', lastname: login, mail: "#{login}@example.invalid")
  u.login = login
  u.password = u.password_confirmation = 'Passw0rd!Passw0rd!'
  u.save!
  u
}
gone = mk.call("#{t}_a")
stay = mk.call("#{t}_b")
attrs = { name: 'p', schema_type: t, schema_version: 0 }
mine  = StudioSetting.create!(attrs.merge(scope_type: 'user', scope_id: gone.id, created_by: gone, updated_by: gone))
other = StudioSetting.create!(attrs.merge(scope_type: 'user', scope_id: stay.id, created_by: stay, updated_by: stay))
team  = StudioSetting.create!(attrs.merge(scope_type: 'global', created_by: gone, updated_by: gone))
team.assignments.create!(user_id: stay.id, assigned_by: admin)

gone.destroy

# 消した人の本人の設定だけが消え、ほかの人の本人の設定・チームの設定とその割り当ては残る
puts !StudioSetting.exists?(mine.id)
puts StudioSetting.exists?(other.id)
puts StudioSetting.exists?(team.id) && team.reload.deleted_on.nil?
puts team.assignments.count == 1

StudioSetting.where(schema_type: t).destroy_all
stay.destroy
```

**期待結果:**
- `true` が 4 回

### [1-48] プロジェクトを削除すると、そのプロジェクトの範囲の設定も消える

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
User.current = admin
t = "rt_projdel_#{SecureRandom.hex(4)}"
parent = Project.create!(name: "#{t}_p", identifier: "#{t}-p".tr('_', '-'))
child  = Project.create!(name: "#{t}_c", identifier: "#{t}-c".tr('_', '-'), parent_id: parent.id)
keep   = Project.create!(name: "#{t}_k", identifier: "#{t}-k".tr('_', '-'))
attrs = { name: 'p', schema_type: t, schema_version: 0, scope_type: 'project', created_by: admin, updated_by: admin }
on_parent = StudioSetting.create!(attrs.merge(scope_id: parent.id))
on_parent.assignments.create!(user_id: admin.id, assigned_by: admin)
on_child  = StudioSetting.create!(attrs.merge(scope_id: child.id))
on_child.soft_delete(admin)
on_keep   = StudioSetting.create!(attrs.merge(scope_id: keep.id))
team      = StudioSetting.create!(attrs.merge(scope_type: 'global', scope_id: nil))

parent.destroy

# 消したプロジェクト（子プロジェクトと、論理削除したものを含む）の設定と割り当てが消え、ほかのプロジェクト・チームの設定は残る
puts !StudioSetting.exists?(on_parent.id) && !StudioSettingAssignment.exists?(setting_id: on_parent.id)
puts !Project.exists?(child.id) && !StudioSetting.exists?(on_child.id)
puts StudioSetting.exists?(on_keep.id)
puts StudioSetting.exists?(team.id)

StudioSetting.where(schema_type: t).destroy_all
keep.destroy
```

**期待結果:**
- `true` が 4 回

### [1-49] 入力の検証（長さ・プロジェクトの実在・comment）と、何が悪いかのメッセージ

**確認方法:**
```ruby
admin = User.find_by_login('{Username}')
User.current = admin
t = "rt_valid_#{SecureRandom.hex(4)}"
attrs = { name: 'n', schema_type: t, scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin }
msgs = ->(s, locale) { I18n.with_locale(locale) { s.valid?; s.errors.full_messages } }

# name・schema_type は 255 文字まで（どの DB でも検証で断る）
long = StudioSetting.new(attrs.merge(name: 'x' * 256, schema_type: 'x' * 256))
puts msgs.call(long, :en) == ['Name is too long (maximum is 255 characters)', 'Schema type is too long (maximum is 255 characters)']
t255 = t + 'z' * (255 - t.length)
puts StudioSetting.new(attrs.merge(name: 'y' * 255, schema_type: t255)).valid?

# project スコープは実在するプロジェクトに付ける
no_id = StudioSetting.new(attrs.merge(scope_type: 'project'))
ghost = StudioSetting.new(attrs.merge(scope_type: 'project', scope_id: 999_999))
puts msgs.call(no_id, :en) == ['Scope cannot be blank']
puts msgs.call(ghost, :en) == ['Scope must be an existing project']
puts msgs.call(ghost, :ja) == ['スコープ には実在するプロジェクトを指定してください']

# user スコープの持ち主がいないときも、何が悪いかが分かる
ghost_user = StudioSetting.new(attrs.merge(scope_type: 'user', scope_id: 999_999))
puts msgs.call(ghost_user, :en) == ['Scope must be an existing user']

# 付け替えでは確かめるが、プロジェクトを変えない更新は、前からある行もそのまま通す
proj = Project.first
s = StudioSetting.create!(attrs.merge(scope_type: 'project', scope_id: proj.id))
s.scope_id = 999_999
puts I18n.with_locale(:en) { s.save == false && s.errors.full_messages == ['Scope must be an existing project'] }
s.reload
s.update_column(:scope_id, 999_998)   # 前からある「プロジェクトの無い行」を作る
s.reload
s.name = 'renamed'
puts s.save

# 範囲を project へ変えるときも確かめる
g = StudioSetting.create!(attrs)
g.update_column(:scope_id, 999_998)
g.reload
g.scope_type = 'project'
puts I18n.with_locale(:en) { g.save == false && g.errors.full_messages == ['Scope must be an existing project'] }

# 前からある行（scope_id の無い project の行・256 文字の名前の行）も、論理削除できる
old_blank = StudioSetting.create!(attrs)
old_blank.update_columns(scope_type: 'project', scope_id: nil)
old_long = StudioSetting.create!(attrs)
old_long.update_columns(name: 'x' * 256)
puts old_blank.reload.soft_delete(admin) && old_long.reload.soft_delete(admin)

# コメントの形と長さ
puts StudioSettingHistory.comment_errors(nil) == [] && StudioSettingHistory.comment_errors('c' * 255) == []
puts StudioSettingHistory.comment_errors({ 'a' => 1 }) == ['comment must be a string']
puts StudioSettingHistory.comment_errors('c' * 256) == ['comment is too long (maximum is 255 characters)']

StudioSetting.where(schema_type: [t, t255]).destroy_all
```

**期待結果:**
- `true` が 13 回

---

## 2. HTTP テスト

### 事前準備

**API キーの取得:**
```ruby
User.find_by_login('{Username}').api_key ||
User.find_by_login('{Username}').tap { |u| u.api_key = SecureRandom.hex(20); u.save! }.api_key
```

**テストデータのクリーンアップ:**
```ruby
# テスト開始前に実行
StudioSettingAssignment.delete_all
StudioSetting.delete_all
```

---

### [2-1] 認証テスト

#### [2-1-1] API キーで認証 → 200

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method GET
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

$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
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

$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
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

$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json" -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).errors
```

**期待結果:**
- ステータスコード 422
- errors が 1 件以上（name 未指定でバリデーションが発火。本文はロケールにより異なるため件数のみ確認。対象フィールドの属性名確認は Runner 側で実施）

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

$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json" -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).errors
```

**期待結果:**
- ステータスコード 422
- errors が 1 件以上（scope_type 未指定でバリデーションが発火。本文はロケールにより異なるため件数のみ確認。対象フィールドの属性名確認は Runner 側で実施）

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

$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json" -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).errors
```

**期待結果:**
- ステータスコード 422
- errors が 1 件以上（schema_type 未指定でバリデーションが発火。本文はロケールにより異なるため件数のみ確認。対象フィールドの属性名確認は Runner 側で実施）

#### [2-2-5] 設定取得（GET 単体）

**確認方法:**
```powershell
# [2-2-1] で作成した ID を使用
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$SettingId.json?key=$ApiKey" -Method GET
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
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/99999.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
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

$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$SettingId.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"
$response
```

**期待結果:**
- `name` が `StudioSettings_Test_Updated`
- `payload` が `{"updated":true}`
- `updated_on` が更新されている

#### [2-2-8] 設定削除（論理削除: DELETE）

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$SettingId.json?key=$ApiKey" -Method DELETE
$response.StatusCode

# 削除後に取得して確認
$check = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$SettingId.json?key=$ApiKey" -Method GET
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
$created = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$deleteId = $created.studio_setting.id

# 物理削除
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$deleteId.json?key=$ApiKey&force=1" -Method DELETE
$response.StatusCode

# 削除後に取得 → 404
$check = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$deleteId.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
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

$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/99999.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json" -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-2-11] 設定削除（存在しない ID）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/99999.json?key=$ApiKey" -Method DELETE -SkipHttpErrorCheck
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

$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json" -SkipHttpErrorCheck
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
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method GET
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
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body1 -ContentType "application/json"
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body2 -ContentType "application/json"

# フィルタ
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey&scope_type=global" -Method GET
$response.studio_settings | Where-Object { $_.scope_type -ne "global" }
```

**期待結果:**
- 全て `scope_type` が `global` のレコードのみ
- `project` のレコードは含まれない

#### [2-3-3] scope_id フィルタ

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey&scope_type=project&scope_id=1" -Method GET
$response.studio_settings | Where-Object { $_.scope_id -ne 1 }
```

**期待結果:**
- 全て `scope_id` が `1` のレコードのみ

#### [2-3-4] include_deleted フィルタ

**確認方法:**
```powershell
# 論理削除されたレコードがある状態で
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey&include_deleted=1" -Method GET
$deleted = $response.studio_settings | Where-Object { $_.deleted_on -ne $null }
$deleted.Count
```

**期待結果:**
- 論理削除されたレコードも含まれる

#### [2-3-5] include=payload

**確認方法:**
```powershell
# payload なし
$withoutPayload = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method GET
$withoutPayload.studio_settings[0].PSObject.Properties.Name -contains "payload"

# payload あり
$withPayload = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey&include=payload" -Method GET
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
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body1 -ContentType "application/json"
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body2 -ContentType "application/json"

# フィルタ
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey&schema_type=review" -Method GET
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
$setting = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.studio_setting.id

# ユーザーを割り当て
Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$settingId/users/1.json?key=$ApiKey" -Method POST

# include=assignments なし
$without = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId.json?key=$ApiKey" -Method GET
$without.studio_setting.PSObject.Properties.Name -contains "assignments"

# include=assignments あり
$with = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId.json?key=$ApiKey&include=assignments" -Method GET
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
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body1 -ContentType "application/json"
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body2 -ContentType "application/json"
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body3 -ContentType "application/json"

# offset=1 で取得（schema_type でフィルタして確認しやすくする）
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey&schema_type=pagination_test&offset=1" -Method GET
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
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey&schema_type=pagination_test&limit=2" -Method GET
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
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey&schema_type=pagination_test&offset=1&limit=1" -Method GET
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
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey&limit=200" -Method GET
$response.limit
```

**期待結果:**
- `limit` が 100（最大値に制限される）

#### [2-3-12] ページネーション: limit=0 の場合

**確認方法:**
```powershell
# limit=0 で取得
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey&limit=0" -Method GET
$response.limit
```

**期待結果:**
- `limit` が 25（デフォルト値にフォールバック）

#### [2-3-13] ページネーション: offset が総件数を超える場合

**確認方法:**
```powershell
# offset=1000（総件数より大きい）で取得
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey&schema_type=pagination_test&offset=1000" -Method GET
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
$setting = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.studio_setting.id

$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId/users.json?key=$ApiKey" -Method GET
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

$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$settingId/users/$adminId.json?key=$ApiKey" -Method POST
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
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$settingId/users/$adminId.json?key=$ApiKey" -Method POST
$response.StatusCode
```

**期待結果:**
- ステータスコード 200（既存を返す）
- 新規作成されない（同じ ID が返る）

#### [2-4-4] ユーザー一覧（追加後）

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId/users.json?key=$ApiKey" -Method GET
$response.studio_setting_assignments.Count
$response.total_count
```

**期待結果:**
- `studio_setting_assignments` に 1件のレコードが返る
- `total_count` が 1

#### [2-4-5] ユーザー削除（DELETE）

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$settingId/users/$adminId.json?key=$ApiKey" -Method DELETE
$response.StatusCode

# 確認
$check = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId/users.json?key=$ApiKey" -Method GET
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
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$settingId/users/99999.json?key=$ApiKey" -Method DELETE -SkipHttpErrorCheck
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

$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"
$response.studio_setting_assignments.Count
```

**期待結果:**
- `studio_setting_assignments` に指定したユーザーのみが割り当てられている
- 以前の割り当ては削除されている

#### [2-4-8] ユーザー置換（空配列で全削除）

**確認方法:**
```powershell
$body = @{ user_ids = @() } | ConvertTo-Json -Depth 2

$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"
$response.studio_setting_assignments.Count

# 確認
$check = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId/users.json?key=$ApiKey" -Method GET
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
$setting = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.studio_setting.id

# 複数ユーザーを一括設定
# ※ 環境に存在するユーザー ID を使用（例: admin=1, 他ユーザー=5 など）
# ※ ID 2 が存在しない環境もあるため、事前に確認が必要
$body = @{ user_ids = @(1, 5) } | ConvertTo-Json -Depth 2

$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"
$response.studio_setting_assignments.Count

# 確認
$check = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId/users.json?key=$ApiKey" -Method GET
$check.total_count
```

**期待結果:**
- `studio_setting_assignments` に 2件の割り当てが返る
- 指定した両方のユーザーが割り当てられている

#### [2-4-10] ユーザー追加（存在しないユーザー）→ 422

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$settingId/users/99999.json?key=$ApiKey" -Method POST -SkipHttpErrorCheck
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
$setting = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.studio_setting.id

# ユーザーを割り当て
Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$settingId/users/1.json?key=$ApiKey" -Method POST

# 割り当て確認
$before = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId/users.json?key=$ApiKey" -Method GET
$before.total_count  # 1

# 設定を物理削除
Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$settingId.json?key=$ApiKey&force=1" -Method DELETE

# 設定が削除されていることを確認
$check = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$settingId.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
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
$setting = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.studio_setting.id

# 複数ユーザーを割り当て（環境に存在するユーザー ID を使用）
$body = @{ user_ids = @(1, 5) } | ConvertTo-Json -Depth 2
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"

# limit=1 で取得
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId/users.json?key=$ApiKey&limit=1" -Method GET
$response.studio_setting_assignments.Count
$response.limit
$response.total_count

# offset=1, limit=1 で取得
$response2 = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$settingId/users.json?key=$ApiKey&offset=1&limit=1" -Method GET
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
$setting = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.studio_setting.id

Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$settingId/users/1.json?key=$ApiKey" -Method POST

# 一覧取得
$response = Invoke-RestMethod -Uri "{BaseUrl}/users/1/studio_settings.json?key=$ApiKey" -Method GET
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
Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$settingId.json?key=$ApiKey" -Method DELETE

# 一覧取得
$response = Invoke-RestMethod -Uri "{BaseUrl}/users/1/studio_settings.json?key=$ApiKey" -Method GET
$response.studio_setting_assignments | Where-Object { $_.setting_id -eq $settingId }
```

**期待結果:**
- 論理削除された設定は含まれない

#### [2-5-3] ユーザーの設定一覧（存在しないユーザー）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "{BaseUrl}/users/99999/studio_settings.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
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
$setting1 = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body1 -ContentType "application/json"
$setting2 = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body2 -ContentType "application/json"

Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$($setting1.studio_setting.id)/users/1.json?key=$ApiKey" -Method POST
Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$($setting2.studio_setting.id)/users/1.json?key=$ApiKey" -Method POST

# limit=1 で取得
$response = Invoke-RestMethod -Uri "{BaseUrl}/users/1/studio_settings.json?key=$ApiKey&limit=1" -Method GET
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
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/99999/users.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-6-2] ユーザー置換（存在しないユーザー ID）→ 422

**確認方法:**
```powershell
$body = @{ user_ids = @(99999) } | ConvertTo-Json -Depth 2

$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json" -SkipHttpErrorCheck
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
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings.xml?key=$ApiKey" -Method GET
$response.StatusCode
$response.Content.StartsWith("<?xml")
```

**期待結果:**
- ステータスコード 200
- レスポンスが XML 形式（`<?xml` で開始）

#### [2-7-2] 設定単体取得（XML 形式）

**確認方法:**
```powershell
# [2-2-1] で作成した ID を使用
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$SettingId.xml?key=$ApiKey" -Method GET
$response.StatusCode
$response.Content -match "<studio_setting>"
$response.Content -match "<version>"
```

**期待結果:**
- ステータスコード 200
- `<studio_setting>` 要素が含まれる
- `<version>` 要素が含まれる

#### [2-7-3] 存在しない ID（XML 形式）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/99999.xml?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-7-4] ユーザー割り当て一括置換（XML リクエストボディ）

XML 形式のリクエストボディが Rails の params として解析され、割り当てが作成されることを確認する。

**確認方法:**
```powershell
# テスト用の設定を作成
$body = @{ studio_setting = @{ name = "XML_Replace_Test"; schema_type = "test"; scope_type = "global"; schema_version = 1; payload = "{}" } } | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$xmlTestId = $setting.studio_setting.id

# XML ボディで置換
$xmlBody = '<user_ids type="array"><user_id>1</user_id></user_ids>'
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$xmlTestId/users.xml?key=$ApiKey" -Method PUT -Body $xmlBody -ContentType "application/xml"
$response.StatusCode
$response.Content -match "<studio_setting_assignment>"

# 後片付け
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$xmlTestId.json?key=$ApiKey" -Method DELETE
```

**期待結果:**
- ステータスコード 200
- レスポンスに `<studio_setting_assignment>` 要素が含まれる（XML ボディの user_ids が解析され、割り当てが 1 件作成される）

#### [2-7-5] 割り当て込み単体取得（XML 形式）の要素名

include=assignments でネストされる割り当ての XML 要素名が、単体エンドポイントと同じ `studio_setting_assignment` であることを確認する（redmine-net-api の XmlRoot と一致させる）。

**確認方法:**
```powershell
# テスト用の設定を作成し、ユーザーを割り当てる
$body = @{ studio_setting = @{ name = "XML_Include_Test"; schema_type = "test"; scope_type = "global"; schema_version = 1; payload = "{}" } } | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$xmlTestId = $setting.studio_setting.id
$replaceBody = @{ user_ids = @(1) } | ConvertTo-Json -Depth 2
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$xmlTestId/users.json?key=$ApiKey" -Method PUT -Body $replaceBody -ContentType "application/json"

# include=assignments 付きで XML 取得
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$xmlTestId.xml?key=$ApiKey&include=assignments" -Method GET
$response.StatusCode
$response.Content -match "<assignments type=`"array`"><studio_setting_assignment>"

# 後片付け
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$xmlTestId.json?key=$ApiKey" -Method DELETE
```

**期待結果:**
- ステータスコード 200
- ネストされた割り当ての要素名が `<studio_setting_assignment>`（`<assignment>` ではない）

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

$setting = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$historyTestSettingId = $setting.studio_setting.id

# 更新して履歴を増やす（version 2）
$body2 = @{
    studio_setting = @{
        payload = '{"version": 2}'
        schema_version = 1
    }
} | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId.json?key=$ApiKey" -Method PUT -Body $body2 -ContentType "application/json"

# さらに更新（version 3）
$body3 = @{
    studio_setting = @{
        payload = '{"version": 3}'
    }
} | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId.json?key=$ApiKey" -Method PUT -Body $body3 -ContentType "application/json"
```

#### [2-8-1] 履歴一覧取得

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
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
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$response.studio_setting_histories[0].version  # 最新
$response.studio_setting_histories[-1].version  # 最古
```

**期待結果:**
- 最初の要素が最新バージョン（version 3）
- 最後の要素が最古バージョン（version 1）

#### [2-8-3] 履歴一覧に含まれるフィールド確認

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
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
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey&include=payload" -Method GET
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
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey&limit=2" -Method GET
$response.studio_setting_histories.Count
$response.limit
$response.total_count

# offset=1, limit=1 で取得
$response2 = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey&offset=1&limit=1" -Method GET
$response2.studio_setting_histories.Count
$response2.offset
```

**期待結果:**
- 1回目: `studio_setting_histories` が 2件、`limit` が 2、`total_count` が 3
- 2回目: `studio_setting_histories` が 1件、`offset` が 1

#### [2-8-6] 履歴詳細取得

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories/1.json?key=$ApiKey" -Method GET
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
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories/99999.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-8-8] 履歴一覧取得（存在しない設定）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/99999/histories.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-8-9] change_type の確認（create）

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories/1.json?key=$ApiKey" -Method GET
$response.studio_setting_history.change_type
```

**期待結果:**
- `create` が返る

#### [2-8-10] change_type の確認（update）

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories/2.json?key=$ApiKey" -Method GET
$response.studio_setting_history.change_type
```

**期待結果:**
- `update` が返る

#### [2-8-11] is_current フラグの確認

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
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
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/restore.json?key=$ApiKey&version=1" -Method POST
$response.studio_setting
$response.studio_setting.schema_version  # 0 に戻る
```

**期待結果:**
- `studio_setting` オブジェクトが返る（更新後の設定）
- `schema_version` が 0（version 1 の値に復元）

#### [2-9-2] 復元後の履歴確認（change_type = restore）

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
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
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/restore.json?key=$ApiKey&version=2&comment=Restore%20to%20v2" -Method POST

# 履歴を確認
$histories = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$histories.studio_setting_histories[0].comment
```

**期待結果:**
- 最新履歴の `comment` が `Restore to v2`

#### [2-9-4] 現在のバージョンに復元 → 422 エラー

**確認方法:**
```powershell
# 最新バージョンを取得
$histories = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$currentVersion = ($histories.studio_setting_histories | Where-Object { $_.is_current -eq $true }).version

# 現在のバージョンに復元を試みる
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/restore.json?key=$ApiKey&version=$currentVersion" -Method POST -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).errors
```

**期待結果:**
- ステータスコード 422（Redmine 標準の `render_api_errors` を使用しているため。docs の記載とも一致）
- errors に "Cannot restore to the current version" を含む

#### [2-9-5] 存在しないバージョンに復元 → 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/restore.json?key=$ApiKey&version=99999" -Method POST -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-9-6] 存在しない設定に復元 → 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/99999/restore.json?key=$ApiKey&version=1" -Method POST -SkipHttpErrorCheck
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
$setting = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$deleteTestId = $setting.studio_setting.id

# 論理削除
Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$deleteTestId.json?key=$ApiKey" -Method DELETE

# 履歴を確認
$histories = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$deleteTestId/histories.json?key=$ApiKey" -Method GET
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
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$deleteTestId/histories.json?key=$ApiKey" -Method GET
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
$response = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$deleteTestId/restore.json?key=$ApiKey&version=1" -Method POST
$response.studio_setting.deleted_on  # null になっているはず

# 履歴を確認
$histories = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$deleteTestId/histories.json?key=$ApiKey" -Method GET
$latestHistory = $histories.studio_setting_histories[0]
$latestHistory.change_type
$latestHistory.restored_from_version
```

**期待結果:**
- 設定の `deleted_on` が null（復活している）
- 最新履歴の `change_type` が `undelete`
- `restored_from_version` が 1

#### [2-10-4] 論理削除された設定の更新（deleted_on は更新 API で変更不可）

`deleted_on` は Strong Parameters（`studio_setting_params`）で受け付けないため、更新 API 経由での復活（undelete）はできない。
復活（undelete）は restore API に一本化されている（[2-10-3]。論理削除は payload を変更しないため、削除直前のバージョンに restore すれば内容そのままで復活できる）。

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
$setting = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$undeleteTestId = $setting.studio_setting.id

# 論理削除
Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$undeleteTestId.json?key=$ApiKey" -Method DELETE

# deleted_on = null を指定して更新（無視されることを確認する）
$body2 = @{
    studio_setting = @{
        deleted_on = $null
        payload = '{"restored": true}'
    }
} | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$undeleteTestId.json?key=$ApiKey" -Method PUT -Body $body2 -ContentType "application/json"

# 設定と履歴を確認
$updated = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$undeleteTestId.json?key=$ApiKey" -Method GET
$updated.studio_setting.deleted_on  # null にならない（論理削除されたまま）
$histories = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$undeleteTestId/histories.json?key=$ApiKey" -Method GET
$latestHistory = $histories.studio_setting_histories[0]
$latestHistory.change_type
```

**期待結果:**
- `deleted_on` は null にならない（論理削除されたまま。deleted_on は更新 API で変更できない）
- 最新履歴の `change_type` が `update`（undelete にはならない）

---

### [2-11] 履歴削除テスト

#### [2-11-1] 過去バージョンの履歴削除

**確認方法:**
```powershell
# 削除前の履歴件数を確認
$before = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$beforeCount = $before.total_count

# version 1 の履歴を削除
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories/1.json?key=$ApiKey" -Method DELETE
$response.StatusCode

# 削除後の履歴件数を確認
$after = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$after.total_count
```

**期待結果:**
- ステータスコード 204
- 履歴件数が 1件減少

#### [2-11-2] 現在バージョンの履歴削除 → 422 エラー

**確認方法:**
```powershell
# 現在のバージョン（is_current: true）を取得
$histories = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories.json?key=$ApiKey" -Method GET
$currentVersion = ($histories.studio_setting_histories | Where-Object { $_.is_current -eq $true }).version

# 現在のバージョンを削除しようとする
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories/$currentVersion.json?key=$ApiKey" -Method DELETE -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).errors
```

**期待結果:**
- ステータスコード 422（Redmine 標準の `render_api_errors` を使用しているため。docs の記載とも一致）
- errors に "Cannot delete the current version" を含む

#### [2-11-3] 存在しないバージョンの履歴削除 → 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$historyTestSettingId/histories/99999.json?key=$ApiKey" -Method DELETE -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 404

#### [2-11-4] 存在しない設定の履歴削除 → 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/99999/histories/1.json?key=$ApiKey" -Method DELETE -SkipHttpErrorCheck
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
$setting = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$cascadeTestId = $setting.studio_setting.id

# 履歴があることを確認
$histories = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$cascadeTestId/histories.json?key=$ApiKey" -Method GET
$histories.total_count  # 1

# 物理削除
Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$cascadeTestId.json?key=$ApiKey&force=1" -Method DELETE

# 設定が 404 になることを確認
$check = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$cascadeTestId.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$check.StatusCode

# 履歴も 404 になることを確認
$historyCheck = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$cascadeTestId/histories.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
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
$setting = Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$xmlTestId = $setting.studio_setting.id

$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$xmlTestId/histories.xml?key=$ApiKey" -Method GET
$response.StatusCode
$response.Content.StartsWith("<?xml")
```

**期待結果:**
- ステータスコード 200
- レスポンスが XML 形式

#### [2-13-2] 履歴詳細取得（XML 形式）

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$xmlTestId/histories/1.xml?key=$ApiKey" -Method GET
$response.StatusCode
$response.Content -match "<studio_setting_history>"
```

**期待結果:**
- ステータスコード 200
- `<studio_setting_history>` 要素が含まれる

---

## 2B. 可視性（HTTP テスト）

コントローラの認可を、メンバー / 非メンバー / admin の各 API キーで検証する。前提データは Runner [1-30] が作成し、`member_key` / `nonmember_key` / `proj_a` / `proj_b` / `member_id` を出力する。実行前にそれらと admin の api_key を変数へ入れる。

### 事前準備

```powershell
$AdminKey = "<{Username} の api_key>"
$MemberKey = "<vis_member の api_key（[1-30] 出力）>"
$NonMemberKey = "<vis_nonmember の api_key（[1-30] 出力）>"
$ProjA = <proj_a（[1-30] 出力）>
$ProjB = <proj_b（[1-30] 出力）>
$MemberId = <member_id（[1-30] 出力）>

# ProjA スコープ設定の ID を admin で取得
# （PowerShell の変数名は大文字小文字を区別しないので、$ProjA と重ならない名前にする）
$projASetting = (Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$AdminKey&scope_type=project&scope_id=$ProjA" -Method GET).studio_settings | Where-Object { $_.name -eq 'Vis_ProjA' }
$projASettingId = $projASetting.id
```

### [2-14] 一覧：非メンバーは global のみ（project 設定は除外）

**確認方法:**
```powershell
$names = (Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$NonMemberKey&limit=100" -Method GET).studio_settings.name
$names -contains 'Vis_Global'
$names -contains 'Vis_ProjA'
$names -contains 'Vis_ProjB'
```

**期待結果:**
- `Vis_Global` を含む（True）
- `Vis_ProjA` を含まない（False）／`Vis_ProjB` を含まない（False）

### [2-15] 一覧：メンバーは global＋所属 project（非所属は除外）

**確認方法:**
```powershell
$names = (Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$MemberKey&limit=100" -Method GET).studio_settings.name
$names -contains 'Vis_Global'
$names -contains 'Vis_ProjA'
$names -contains 'Vis_ProjB'
```

**期待結果:**
- `Vis_Global`（True）／`Vis_ProjA`（True）／`Vis_ProjB`（False）

### [2-16] 一覧：admin は全件

**確認方法:**
```powershell
$names = (Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$AdminKey&limit=100" -Method GET).studio_settings.name
$names -contains 'Vis_ProjA'
$names -contains 'Vis_ProjB'
```

**期待結果:**
- `Vis_ProjA`（True）／`Vis_ProjB`（True）

### [2-17] 単体取得：非メンバー → 403／メンバー → 200

**確認方法:**
```powershell
(Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$projASettingId.json?key=$NonMemberKey" -Method GET -SkipHttpErrorCheck).StatusCode
(Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$projASettingId.json?key=$MemberKey" -Method GET -SkipHttpErrorCheck).StatusCode
```

**期待結果:**
- 非メンバー: 403／メンバー: 200

### [2-18] 更新：非メンバーが ProjA → 403

**確認方法:**
```powershell
$body = @{ studio_setting = @{ payload = '{"x":1}' } } | ConvertTo-Json -Depth 3
(Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$projASettingId.json?key=$NonMemberKey" -Method PUT -Body $body -ContentType "application/json" -SkipHttpErrorCheck).StatusCode
```

**期待結果:**
- 403（設定は変更されない）

### [2-19] 削除：非メンバーが ProjA → 403

**確認方法:**
```powershell
(Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$projASettingId.json?key=$NonMemberKey" -Method DELETE -SkipHttpErrorCheck).StatusCode
```

**期待結果:**
- 403（設定は削除されない）

### [2-20] 作成：project 非メンバー → 403／メンバー → 201／global は誰でも → 201

**確認方法:**
```powershell
# 非メンバーが ProjA の project 設定を作成 → 403
$bodyProj = @{ studio_setting = @{ name = "Vis_Create_NonMember"; schema_type = "work"; scope_type = "project"; scope_id = $ProjA; schema_version = 0 } } | ConvertTo-Json -Depth 3
(Invoke-WebRequest -Uri "{BaseUrl}/studio_settings.json?key=$NonMemberKey" -Method POST -Body $bodyProj -ContentType "application/json" -SkipHttpErrorCheck).StatusCode

# メンバーが ProjA の project 設定を作成 → 201
$bodyProjM = @{ studio_setting = @{ name = "Vis_Create_Member"; schema_type = "work"; scope_type = "project"; scope_id = $ProjA; schema_version = 0 } } | ConvertTo-Json -Depth 3
(Invoke-WebRequest -Uri "{BaseUrl}/studio_settings.json?key=$MemberKey" -Method POST -Body $bodyProjM -ContentType "application/json" -SkipHttpErrorCheck).StatusCode

# 非メンバーが global 設定を作成 → 201（global は誰でも可）
$bodyGlobal = @{ studio_setting = @{ name = "Vis_Create_Global"; schema_type = "work"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
(Invoke-WebRequest -Uri "{BaseUrl}/studio_settings.json?key=$NonMemberKey" -Method POST -Body $bodyGlobal -ContentType "application/json" -SkipHttpErrorCheck).StatusCode
```

**期待結果:**
- 非メンバーの project 作成: 403／メンバーの project 作成: 201／非メンバーの global 作成: 201

### [2-21] 履歴・復元：非メンバーが ProjA → 403

**確認方法:**
```powershell
(Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$projASettingId/histories.json?key=$NonMemberKey" -Method GET -SkipHttpErrorCheck).StatusCode
$body = @{ version = 1 } | ConvertTo-Json
(Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$projASettingId/restore.json?key=$NonMemberKey" -Method POST -Body $body -ContentType "application/json" -SkipHttpErrorCheck).StatusCode
```

**期待結果:**
- 履歴一覧: 403／復元: 403

### [2-22] 割り当て：非メンバーが ProjA → 403

**確認方法:**
```powershell
(Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$projASettingId/users.json?key=$NonMemberKey" -Method GET -SkipHttpErrorCheck).StatusCode
(Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$projASettingId/users/$MemberId.json?key=$NonMemberKey" -Method POST -SkipHttpErrorCheck).StatusCode
```

**期待結果:**
- 割り当て一覧: 403／割り当て追加: 403

### [2-23] /users/:id/studio_settings：自分 or admin のみ

**確認方法:**
```powershell
# 非メンバーが member の一覧を要求 → 403
(Invoke-WebRequest -Uri "{BaseUrl}/users/$MemberId/studio_settings.json?key=$NonMemberKey" -Method GET -SkipHttpErrorCheck).StatusCode
# member が自分の一覧を要求 → 200
(Invoke-WebRequest -Uri "{BaseUrl}/users/$MemberId/studio_settings.json?key=$MemberKey" -Method GET -SkipHttpErrorCheck).StatusCode
# admin が member の一覧を要求 → 200
(Invoke-WebRequest -Uri "{BaseUrl}/users/$MemberId/studio_settings.json?key=$AdminKey" -Method GET -SkipHttpErrorCheck).StatusCode
```

**期待結果:**
- 非メンバー（他人分）: 403／本人: 200／admin: 200

### [2-23b] 更新：範囲を変えられるのは admin だけ → それ以外は 403

範囲（`scope_type`、project ならその `scope_id`）を変えると、前の範囲の版の中身が新しい範囲の人に見えるので、admin 以外は断る。今と同じ値を送るのは、変えたことにならない。

**確認方法:**
```powershell
if (-not $ProjB -or $ProjB -eq $ProjA) { throw '事前準備の $ProjB（[1-30] の proj_b）が入っていない' }
function New-SettingId($key, $s) { $b = @{ studio_setting = $s } | ConvertTo-Json -Depth 3; (Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$key" -Method POST -Body $b -ContentType "application/json").studio_setting.id }
function Put-Status($key, $id, $s) { $b = @{ studio_setting = $s } | ConvertTo-Json -Depth 3; (Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$id.json?key=$key" -Method PUT -Body $b -ContentType "application/json" -SkipHttpErrorCheck).StatusCode }
$rp = New-SettingId $MemberKey @{ name = 'Vis_Scope_Proj'; schema_type = 'work'; scope_type = 'project'; scope_id = $ProjA; schema_version = 0 }
$rg = New-SettingId $MemberKey @{ name = 'Vis_Scope_Global'; schema_type = 'work'; scope_type = 'global'; schema_version = 0 }

# メンバーが範囲を変える → 403（所属しないプロジェクト・いないプロジェクト・global へ・global から所属するプロジェクトへ・scope_id 無しで project へ）
Put-Status $MemberKey $rp @{ scope_id = $ProjB }
Put-Status $MemberKey $rp @{ scope_id = 999999 }
Put-Status $MemberKey $rp @{ scope_type = 'global' }
Put-Status $MemberKey $rg @{ scope_type = 'project'; scope_id = $ProjA }
Put-Status $MemberKey $rg @{ scope_type = 'project' }

# 断ったときは何も変わらない
$s1 = (Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$rp.json?key=$AdminKey").studio_setting
$s2 = (Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$rg.json?key=$AdminKey").studio_setting
"$($s1.scope_type)/$($s1.scope_id -eq $ProjA) v$($s1.version) $($s2.scope_type) v$($s2.version)"

# 今と同じ範囲を送る更新は通る。admin は範囲を変えられる
Put-Status $MemberKey $rp @{ scope_type = 'project'; scope_id = $ProjA; payload = '{"x":1}' }
Put-Status $AdminKey $rp @{ scope_id = $ProjB }
Put-Status $AdminKey $rg @{ scope_type = 'project'; scope_id = $ProjA }
$s1 = (Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$rp.json?key=$AdminKey").studio_setting
$s2 = (Invoke-RestMethod -Uri "{BaseUrl}/studio_settings/$rg.json?key=$AdminKey").studio_setting
"$($s1.scope_type)/$($s1.scope_id -eq $ProjB) $($s2.scope_type)/$($s2.scope_id -eq $ProjA)"

# 後片付け
"cleanup: " + (@($rp, $rg | ForEach-Object { (Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$_.json?key=$AdminKey&force=1" -Method DELETE -SkipHttpErrorCheck).StatusCode }) -join ',')
```

**期待結果:**
- `403` が 5 回
- `project/True v1 global v1`（範囲は変わっていない・版も進んでいない）
- `200` が 3 回
- `project/True project/True`（admin の付け替えは効いている）
- `cleanup: 204,204`

---

## 2C. 本人の設定と版（HTTP テスト）

本人の設定（user スコープ）の作成・更新・削除、版による衝突検出、`versions` エンドポイント、`ids` フィルタを確かめる。2B と同じ API キー（admin / vis_member / vis_nonmember）を使う。番号順に流す（前のテストで作った ID・版を後で使う）。

2B の変数（`$AdminKey`・`$MemberKey`・`$NonMemberKey`・`$MemberId`・`$projASettingId`）をそのまま使う。2C だけを新しいシェルで流すときは、先に 2B の事前準備を流す。

2C は、ほかの HTTP テストと違い、最後（[2-40]）に作った設定を消す（同じ schema_type での作り直しを何度でも確かめられるように）。

### 事前準備

```powershell
# 2B の変数が無ければ止める（空のまま流すと、見えない設定の項目が素通りする）
foreach ($n in 'AdminKey', 'MemberKey', 'NonMemberKey', 'MemberId', 'projASettingId') {
    if (-not (Get-Variable -Name $n -ValueOnly -ErrorAction SilentlyContinue)) { throw "2B の事前準備を先に流す（$n が空）" }
}
$AdminId = (Invoke-RestMethod -Uri "{BaseUrl}/users/current.json?key=$AdminKey").user.id
$T = "test_personal_" + (Get-Random)   # 本人の設定の schema_type（実行ごとに変える）

# $args は PowerShell の自動変数なので使わない
function Send-Json($key, $method, $path, $body) {
    $req = @{ Uri = "{BaseUrl}$path"; Method = $method; Headers = @{ 'X-Redmine-API-Key' = $key }; ContentType = 'application/json'; SkipHttpErrorCheck = $true }
    if ($null -ne $body) { $req.Body = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 5 -Compress)) }
    $r = Invoke-WebRequest @req
    [pscustomobject]@{ Status = [int]$r.StatusCode; Json = $(if ($r.Content) { $r.Content | ConvertFrom-Json } else { $null }); Raw = $r.Content }
}
```

### [2-24] 本人の設定の作成（持ち主を省く）→ 201

**確認方法:**
```powershell
$r = Send-Json $AdminKey POST '/studio_settings.json' @{ studio_setting = @{ name = 'p'; schema_type = $T; scope_type = 'user'; payload = '{"a":1}'; schema_version = 1 } }
$PersonalId = $r.Json.studio_setting.id
$r.Status; $r.Json.studio_setting.scope_id; $r.Json.studio_setting.version
```

**期待結果:**
- 201／`scope_id` が `$AdminId`（省くと自分）／`version` が 1

### [2-25] 同じ種類をもう 1 つ作る → 409（今ある設定を返す）

**確認方法:**
```powershell
$r = Send-Json $AdminKey POST '/studio_settings.json' @{ studio_setting = @{ name = 'p2'; schema_type = $T; scope_type = 'user'; payload = '{"a":2}'; schema_version = 1 } }
$r.Status; $r.Json.studio_setting.id; $r.Json.studio_setting.version; $r.Json.studio_setting.payload
```

**期待結果:**
- 409／`id` が `$PersonalId`／`version` が 1／`payload` が `{"a":1}`（後から送った中身で上書きしない）

### [2-26] 更新：expected_version が無い・読めない → 422

**確認方法:**
```powershell
# 無い
$r = Send-Json $AdminKey PUT "/studio_settings/$PersonalId.json" @{ studio_setting = @{ payload = '{"a":3}' } }
$r.Status; $r.Json.errors
# studio_setting の外に置いたものは見ない（無いのと同じ）
$r = Send-Json $AdminKey PUT "/studio_settings/$PersonalId.json" @{ studio_setting = @{ payload = '{"a":3}' }; expected_version = 1 }
$r.Status; $r.Json.errors
# 数として読めない
foreach ($bad in @('1.0', 'abc', $true)) {
    $r = Send-Json $AdminKey PUT "/studio_settings/$PersonalId.json" @{ studio_setting = @{ payload = '{"a":3}'; expected_version = $bad } }
    "$bad -> $($r.Status) $($r.Json.errors)"
}
(Send-Json $AdminKey GET "/studio_settings/$PersonalId.json" $null).Json.studio_setting.version
```

**期待結果:**
- 無い: 422・`expected_version is required`
- 外に置いた: 422・`expected_version is required`
- 読めない（`1.0`・`abc`・`True`）: いずれも 422・`expected_version must be an integer`
- 取り直した `version` は 1 のまま

### [2-27] 更新：今の版を添える → 200・版が進む

**確認方法:**
```powershell
$r = Send-Json $AdminKey PUT "/studio_settings/$PersonalId.json" @{ studio_setting = @{ payload = '{"a":4}'; expected_version = 1 } }
$r.Status; $r.Json.studio_setting.version; $r.Json.studio_setting.payload
```

**期待結果:**
- 200／`version` が 2／`payload` が `{"a":4}`

### [2-28] 更新：古い版 → 409（今の設定を返し、書き込まない）

**確認方法:**
```powershell
$r = Send-Json $AdminKey PUT "/studio_settings/$PersonalId.json" @{ studio_setting = @{ payload = '{"a":5}'; expected_version = 1 } }
$g = Send-Json $AdminKey GET "/studio_settings/$PersonalId.json" $null
$r.Status; $r.Json.studio_setting.version; $r.Json.studio_setting.payload; $g.Json.studio_setting.payload
```

**期待結果:**
- 409／返った `version` が 2・`payload` が `{"a":4}`（重ね直すための今の中身）／取り直しても `{"a":4}` のまま

### [2-29] 更新：持ち主・種類は送っても変わらない

**確認方法:**
```powershell
$r = Send-Json $AdminKey PUT "/studio_settings/$PersonalId.json" @{ studio_setting = @{ payload = '{"a":6}'; scope_id = $MemberId; schema_type = "$T`_moved"; expected_version = 2 } }
$r.Status; $r.Json.studio_setting.version; $r.Json.studio_setting.scope_id; $r.Json.studio_setting.schema_type; $r.Json.studio_setting.payload
```

**期待結果:**
- 200／`version` が 3／`scope_id` は `$AdminId` のまま／`schema_type` は `$T` のまま／`payload` は `{"a":6}`（中身だけ書き換わる）

### [2-30] 本人の設定は履歴を残さない

**確認方法:**
```powershell
$r = Send-Json $AdminKey GET "/studio_settings/$PersonalId/histories.json" $null
$r.Status; $r.Json.total_count
```

**期待結果:**
- 200／`total_count` が 0

### [2-31] 他の利用者は読めるが書けない

**確認方法:**
```powershell
(Send-Json $MemberKey GET "/studio_settings/$PersonalId.json" $null).Status
(Send-Json $MemberKey PUT "/studio_settings/$PersonalId.json" @{ studio_setting = @{ payload = 'x'; expected_version = 3 } }).Status
(Send-Json $MemberKey DELETE "/studio_settings/$PersonalId.json" $null).Status
(Send-Json $MemberKey POST '/studio_settings.json' @{ studio_setting = @{ name = 'x'; schema_type = "$T`_b"; scope_type = 'user'; scope_id = $AdminId; payload = '{}'; schema_version = 1 } }).Status
(Send-Json $AdminKey GET "/studio_settings/$PersonalId.json" $null).Json.studio_setting.version
```

**期待結果:**
- 取得: 200／更新: 403／削除: 403／他人（admin）の分の作成: 403
- admin で取り直した `version` は 3 のまま（書き込まれていない）

### [2-31b] 本人の設定の履歴・割り当ての操作

本人の設定に履歴は無く、割り当ても付けない。操作できない人は 403、操作できる人（本人・admin）でも中身が無いので 404／422 になることを両側から確かめる。

**確認方法:**
```powershell
$ops = [ordered]@{
    'restore'      = @('POST',   "/studio_settings/$PersonalId/restore.json?version=1", $null)
    'history_del'  = @('DELETE', "/studio_settings/$PersonalId/histories/1.json", $null)
    'users_list'   = @('GET',    "/studio_settings/$PersonalId/users.json", $null)
    'users_put'    = @('PUT',    "/studio_settings/$PersonalId/users.json", @{ user_ids = @($MemberId) })
    'users_add'    = @('POST',   "/studio_settings/$PersonalId/users/$MemberId.json", $null)
    'users_remove' = @('DELETE', "/studio_settings/$PersonalId/users/$MemberId.json", $null)
}
foreach ($k in $ops.Keys) {
    $o = $ops[$k]
    $m = Send-Json $MemberKey $o[0] $o[1] $o[2]
    $a = Send-Json $AdminKey $o[0] $o[1] $o[2]
    "$k member=$($m.Status) admin=$($a.Status) $($a.Json.errors)"
}
(Send-Json $AdminKey GET "/studio_settings/$PersonalId/users.json" $null).Json.total_count
(Send-Json $AdminKey GET "/studio_settings/$PersonalId.json" $null).Json.studio_setting.version
```

**期待結果:**

| 操作 | member（持ち主でない） | admin |
|------|------|------|
| `restore` | 403 | 404（履歴が無い） |
| `history_del` | 403 | 404（履歴が無い） |
| `users_list` | 200 | 200 |
| `users_put` | 403 | 422・`A user setting cannot be assigned to users` |
| `users_add` | 403 | 422・`A user setting cannot be assigned to users` |
| `users_remove` | 403 | 404（割り当てが無い） |

- 割り当ての件数は 0／`version` は 3 のまま

### [2-32] 持ち主が違えば同じ種類を作れる・admin は他人の分も書ける

**確認方法:**
```powershell
$r = Send-Json $MemberKey POST '/studio_settings.json' @{ studio_setting = @{ name = 'mine'; schema_type = $T; scope_type = 'user'; payload = '{"u":1}'; schema_version = 1 } }
$MemberPersonalId = $r.Json.studio_setting.id
$r.Status; $r.Json.studio_setting.scope_id
(Send-Json $AdminKey PUT "/studio_settings/$MemberPersonalId.json" @{ studio_setting = @{ payload = '{"u":"admin"}'; expected_version = 1 } }).Status
```

**期待結果:**
- 作成: 201・`scope_id` が `$MemberId`
- admin の更新: 200

### [2-32b] admin は他人の分を作れる・持ち主は実在の利用者

**確認方法:**
```powershell
$r = Send-Json $AdminKey POST '/studio_settings.json' @{ studio_setting = @{ name = 'for member'; schema_type = "$T`_formember"; scope_type = 'user'; scope_id = $MemberId; payload = '{}'; schema_version = 1 } }
$ForMemberId = $r.Json.studio_setting.id
$r.Status; $r.Json.studio_setting.scope_id
# 作ってもらった本人は書ける
(Send-Json $MemberKey PUT "/studio_settings/$ForMemberId.json" @{ studio_setting = @{ payload = '{"m":1}'; expected_version = 1 } }).Status
# いない利用者の分は作れない
$r = Send-Json $AdminKey POST '/studio_settings.json' @{ studio_setting = @{ name = 'ghost'; schema_type = "$T`_ghost"; scope_type = 'user'; scope_id = 999999; payload = '{}'; schema_version = 1 } }
$r.Status; @($r.Json.errors).Count
```

**期待結果:**
- admin が member の分を作る: 201・`scope_id` が `$MemberId`
- member の更新: 200
- いない利用者（999999）: 422・errors が 1 件以上（文言はロケールで変わるので件数で見る）

### [2-33] user 以外の設定の版（expected_version は任意）

**確認方法:**
```powershell
$r = Send-Json $AdminKey POST '/studio_settings.json' @{ studio_setting = @{ name = 'team'; schema_type = "test_team_$(Get-Random)"; scope_type = 'global'; payload = '{}'; schema_version = 1 } }
$TeamId = $r.Json.studio_setting.id
$r.Status; $r.Json.studio_setting.version
$r = Send-Json $AdminKey PUT "/studio_settings/$TeamId.json" @{ studio_setting = @{ payload = '{"t":1}' } }
$r.Status; $r.Json.studio_setting.version
(Send-Json $AdminKey PUT "/studio_settings/$TeamId.json" @{ studio_setting = @{ payload = '{"t":2}'; expected_version = 1 } }).Status
$r = Send-Json $AdminKey PUT "/studio_settings/$TeamId.json" @{ studio_setting = @{ payload = '{"t":3}'; expected_version = 'abc' } }
$r.Status; $r.Json.errors
(Send-Json $AdminKey GET "/studio_settings/$TeamId/histories.json" $null).Json.total_count
```

**期待結果:**
- 作成: 201・`version` 1
- 版なしの更新: 200・`version` 2（従来どおり版なしで書ける）
- 古い版を添えた更新: 409（添えたときは確かめる）
- 読めない版を添えた更新: 422・`expected_version must be an integer`（user 以外でも黙って上書きしない）
- 履歴の件数: 2（作成＋更新。409・422 の分は増えない）

### [2-34] スコープの付け替え：user への／からは 422、決まった値以外も 422

**確認方法:**
```powershell
# global → user（scope_id も付けて、持ち主の必須の検証ではなく付け替えの禁止で断られることを見る）
$r = Send-Json $AdminKey PUT "/studio_settings/$TeamId.json" @{ studio_setting = @{ scope_type = 'user'; scope_id = $AdminId } }
$r.Status; $r.Json.errors
# user → global
$r = Send-Json $AdminKey PUT "/studio_settings/$PersonalId.json" @{ studio_setting = @{ scope_type = 'global'; expected_version = 3 } }
$r.Status; $r.Json.errors
# 大文字の USER は決まった値でない
$r = Send-Json $AdminKey PUT "/studio_settings/$TeamId.json" @{ studio_setting = @{ scope_type = 'USER'; scope_id = $AdminId } }
$r.Status; @($r.Json.errors).Count
$tg = (Send-Json $AdminKey GET "/studio_settings/$TeamId.json" $null).Json.studio_setting
$pg = (Send-Json $AdminKey GET "/studio_settings/$PersonalId.json" $null).Json.studio_setting
$tg.scope_type; $tg.version; $pg.scope_type; $pg.version
```

**期待結果:**
- global → user: 422・`scope_type cannot be changed to or from user`
- user → global: 422・`scope_type cannot be changed to or from user`
- `USER`: 422・errors が 1 件以上（文言はロケールで変わるので件数で見る）
- 取り直すと、チームの設定は `global`・`version` 2 のまま、本人の設定は `user`・`version` 3 のまま

### [2-35] versions：本人の設定と、id で頼んだ設定の版だけを返す

**確認方法:**
```powershell
# 論理削除した設定（ids に入れても返らないことを見る）
$d = Send-Json $AdminKey POST '/studio_settings.json' @{ studio_setting = @{ name = 'deleted'; schema_type = "test_team_$(Get-Random)"; scope_type = 'global'; payload = '{}'; schema_version = 1 } }
$DeletedTeamId = $d.Json.studio_setting.id
(Send-Json $AdminKey DELETE "/studio_settings/$DeletedTeamId.json" $null).Status

$r = Send-Json $AdminKey POST '/studio_settings/versions.json' @{ own = @($T, 'no_such_type'); ids = @($TeamId, 999999, $MemberPersonalId, $DeletedTeamId) }
$own = @($r.Json.studio_setting_versions.own); $team = @($r.Json.studio_setting_versions.team)
$r.Status
$own.Count; $own[0].id; $own[0].schema_type; $own[0].version
$team.Count; ($team.id | Sort-Object) -join ','
($team | Where-Object id -eq $TeamId).version; ($team | Where-Object id -eq $MemberPersonalId).version
# updated_on は単体取得と同じ文字列（ConvertFrom-Json は日時に変えるので、生の本文で比べる）
$g = Send-Json $AdminKey GET "/studio_settings/$TeamId.json" $null
$vu = [regex]::Match($r.Raw, "`"id`":$TeamId,`"version`":\d+,`"updated_on`":`"([^`"]+)`"").Groups[1].Value
$gu = [regex]::Match($g.Raw, "`"updated_on`":`"([^`"]+)`"").Groups[1].Value
($vu -ne '') -and ($vu -eq $gu)
$r.Raw -match 'payload'
```

**期待結果:**
- 論理削除: 204
- versions: 200
- `own` は 1 件（`$PersonalId`・`$T`・版 3）。無い種類・他人（member）の同じ種類は返らない
- `team` は 2 件（`$MemberPersonalId` と `$TeamId`。小さい順）。無い id・論理削除した id は返らない。本人の設定でも `ids` で頼めば返る
- `team` の版は `$TeamId` が 2、`$MemberPersonalId` が 2
- `updated_on` が単体取得と同じ（True）
- `payload` を含まない（False）

### [2-35b] versions：読めない依頼は 422、明示の空は 200、包んでもよい

**確認方法:**
```powershell
$cases = [ordered]@{
    'empty_object'  = @{}
    'empty_arrays'  = @{ own = @(); ids = @() }
    'ids_string'    = @{ ids = "$TeamId,$MemberPersonalId" }
    'ids_not_int'   = @{ ids = @('abc') }
    'own_hash'      = @{ own = @{ schema_type = $T } }
}
foreach ($k in $cases.Keys) {
    $c = Send-Json $AdminKey POST '/studio_settings/versions.json' $cases[$k]
    "$k -> $($c.Status) own=$(@($c.Json.studio_setting_versions.own).Count) team=$(@($c.Json.studio_setting_versions.team).Count) $($c.Json.errors)"
}
# Content-Type を付けない（JSON として読まれない）
(Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/versions.json" -Method POST -Headers @{ 'X-Redmine-API-Key' = $AdminKey } -Body "{`"own`":[`"$T`"]}" -SkipHttpErrorCheck).StatusCode
# studio_setting_versions で包んだ JSON
$w = Send-Json $AdminKey POST '/studio_settings/versions.json' @{ studio_setting_versions = @{ own = @($T); ids = @($TeamId) } }
$w.Status; @($w.Json.studio_setting_versions.own).id; @($w.Json.studio_setting_versions.team).id
```

**期待結果:**
- `empty_object`: 422・`own or ids is required`
- `empty_arrays`: 200・`own` 0 件・`team` 0 件
- `ids_string`: 422・`ids must be an array of integers`
- `ids_not_int`: 422・`ids must be an array of integers`
- `own_hash`: 422・`own must be an array of schema_type`
- Content-Type なし: 422
- 包んだ JSON: 200・`own` が `$PersonalId`・`team` が `$TeamId`

### [2-36] versions：見えない設定は返さない・ログインが要る

**確認方法:**
```powershell
# 2B の ProjA 設定（$projASettingId）は非メンバーには見えない。本人の設定（$PersonalId）はログインしていれば誰でも見える
$r = Send-Json $NonMemberKey POST '/studio_settings/versions.json' @{ ids = @($projASettingId, $TeamId, $PersonalId) }
$r.Status; (@($r.Json.studio_setting_versions.team).id | Sort-Object) -join ','
(Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/versions.json" -Method POST -ContentType 'application/json' -Body '{"own":["x"]}' -SkipHttpErrorCheck).StatusCode
```

**期待結果:**
- 非メンバー: 200・`team` は `$PersonalId` と `$TeamId` の 2 件（小さい順。`$projASettingId` は返らない）
- API キーなし: 401

### [2-37] 一覧の ids フィルタ

**確認方法:**
```powershell
$r = Send-Json $AdminKey GET "/studio_settings.json?ids=$PersonalId,$TeamId&include=payload" $null
$r.Json.total_count
@($r.Json.studio_settings | Where-Object { $null -ne $_.payload }).Count
@($r.Json.studio_settings | Where-Object { $_.version -gt 0 }).Count
```

**期待結果:**
- `total_count` が 2／payload ありが 2 件／`version` ありが 2 件

### [2-38] XML：レスポンスとリクエストボディ

**確認方法:**
```powershell
$h = @{ 'X-Redmine-API-Key' = $AdminKey }
$TX = "test_personal_xml_" + (Get-Random)
$TX2 = "$TX`_2"
function Send-Xml($method, $path, $body) {
    Invoke-WebRequest -Uri "{BaseUrl}$path" -Method $method -Headers $h -ContentType 'application/xml' -SkipHttpErrorCheck -Body $body
}

# 作成（XML 本文）。2 件作る
$c = Send-Xml POST '/studio_settings.xml' "<studio_setting><name>p</name><schema_type>$TX</schema_type><scope_type>user</scope_type><schema_version>1</schema_version><payload>{}</payload></studio_setting>"
$cx = [xml]$c.Content
$c.StatusCode; $cx.studio_setting.version
$xid = $cx.studio_setting.id
$c2 = Send-Xml POST '/studio_settings.xml' "<studio_setting><name>p2</name><schema_type>$TX2</schema_type><scope_type>user</scope_type><schema_version>1</schema_version><payload>{}</payload></studio_setting>"
$xid2 = ([xml]$c2.Content).studio_setting.id
$c2.StatusCode

# 更新（XML 本文・expected_version は studio_setting の中）
$u = Send-Xml PUT "/studio_settings/$xid.xml" "<studio_setting><payload>{`"x`":1}</payload><expected_version>1</expected_version></studio_setting>"
$u.StatusCode; ([xml]$u.Content).studio_setting.version

# 古い版（XML）→ 409・XML で今の設定
$u2 = Send-Xml PUT "/studio_settings/$xid.xml" "<studio_setting><payload>{`"x`":2}</payload><expected_version>1</expected_version></studio_setting>"
$u2.StatusCode; ([xml]$u2.Content).studio_setting.version

# versions（XML 本文。一番外側を studio_setting_versions で包む）。2 件ずつ
$v = Send-Xml POST '/studio_settings/versions.xml' ("<studio_setting_versions>" +
  "<own type=`"array`"><schema_type>$TX</schema_type><schema_type>$TX2</schema_type></own>" +
  "<ids type=`"array`"><id>$TeamId</id><id>$MemberPersonalId</id></ids></studio_setting_versions>")
$vx = [xml]$v.Content
$v.StatusCode
$vo = @($vx.studio_setting_versions.own.studio_setting); $vt = @($vx.studio_setting_versions.team.studio_setting)
$vo.Count; ($vo | Where-Object id -eq $xid).version
$vt.Count; ($vt.id | Sort-Object) -join ','

# type="array" なしは配列として読めないので 422
(Send-Xml POST '/studio_settings/versions.xml' "<studio_setting_versions><own><schema_type>$TX</schema_type><schema_type>$TX2</schema_type></own></studio_setting_versions>").StatusCode
(Send-Xml POST '/studio_settings/versions.xml' "<studio_setting_versions><ids><id>$TeamId</id></ids></studio_setting_versions>").StatusCode

"cleanup: " + ((Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$xid.xml" -Method DELETE -Headers $h -SkipHttpErrorCheck).StatusCode, (Invoke-WebRequest -Uri "{BaseUrl}/studio_settings/$xid2.xml" -Method DELETE -Headers $h -SkipHttpErrorCheck).StatusCode -join ',')
```

**期待結果:**
- 作成: 201・`<version>` が 1、2 件目も 201
- 更新: 200・`<version>` が 2
- 古い版: 409・`<version>` が 2
- versions: 200・ルート要素 `studio_setting_versions`、`own` の要素名 `studio_setting` が 2 件（`$xid` は版 2）、`team` の要素名 `studio_setting` が 2 件（`$MemberPersonalId` と `$TeamId`。小さい順）
- `type="array"` なしの `own`・`ids`: どちらも 422
- 後片付け: `204,204`

### [2-39] 端末が同時に初回保存 → 1 つだけ作られ、ほかは 409

6 本を同時に送り、3 回くり返す。

**確認方法:**
```powershell
foreach ($round in 1..3) {
    $TR = "test_personal_race_" + (Get-Random)
    $body = @{ studio_setting = @{ name = 'p'; schema_type = $TR; scope_type = 'user'; payload = '{}'; schema_version = 1 } } | ConvertTo-Json -Depth 3
    $codes = 1..6 | ForEach-Object -Parallel {
        (Invoke-WebRequest -Uri "{BaseUrl}/studio_settings.json" -Method POST -Headers @{ 'X-Redmine-API-Key' = $using:AdminKey } -ContentType 'application/json' -Body $using:body -SkipHttpErrorCheck).StatusCode
    } -ThrottleLimit 6
    $list = (Send-Json $AdminKey GET "/studio_settings.json?schema_type=$TR&scope_type=user" $null).Json
    $n201 = @($codes | Where-Object { $_ -eq 201 }).Count
    $n409 = @($codes | Where-Object { $_ -eq 409 }).Count
    $n500 = @($codes | Where-Object { $_ -ge 500 }).Count
    "round $round : 201=$n201 409=$n409 5xx=$n500 rows=$($list.total_count)"
    foreach ($s in $list.studio_settings) { Send-Json $AdminKey DELETE "/studio_settings/$($s.id).json" $null | Out-Null }
}
```

**期待結果:**
- 3 回とも `201=1 409=5 5xx=0 rows=1`

**備考:**
- 同時に送っても、後の要求はたいてい作成前の確認で 409 になる。データベースの重複禁止で断られたときの救済の分岐（`RecordNotUnique` を 409 にする）を通ったかは、この項目では分からない。データベースが重複を断ることは [1-42] が受け持つ
- SQLite は書き込みを 1 本ずつしか通さないので、待ちきれずに 500（`SQLite3::BusyException`）になることがある。そのときは少し待って流し直す（MySQL・PostgreSQL では起きない見込み）

### [2-40] 本人の設定の削除は物理削除・作り直せる

**確認方法:**
```powershell
(Send-Json $AdminKey DELETE "/studio_settings/$PersonalId.json" $null).Status
# 単体取得は論理削除した設定も返す（200）ので、404 なら物理削除と分かる
(Send-Json $AdminKey GET "/studio_settings/$PersonalId.json" $null).Status
@((Send-Json $AdminKey POST '/studio_settings/versions.json' @{ own = @($T) }).Json.studio_setting_versions.own).Count
$r = Send-Json $AdminKey POST '/studio_settings.json' @{ studio_setting = @{ name = 'p'; schema_type = $T; scope_type = 'user'; payload = '{}'; schema_version = 1 } }
$r.Status; $r.Json.studio_setting.version

# 後片付け（2C で作った分を消す）
"cleanup: " + (@(
    (Send-Json $AdminKey DELETE "/studio_settings/$($r.Json.studio_setting.id).json" $null).Status
    (Send-Json $MemberKey DELETE "/studio_settings/$MemberPersonalId.json" $null).Status
    (Send-Json $MemberKey DELETE "/studio_settings/$ForMemberId.json" $null).Status
    (Send-Json $AdminKey DELETE "/studio_settings/$TeamId.json?force=1" $null).Status
    (Send-Json $AdminKey DELETE "/studio_settings/$DeletedTeamId.json?force=1" $null).Status
) -join ',')
```

**期待結果:**
- 削除: 204／取得: 404／versions の `own`: 0 件
- 作り直し: 201・`version` 1
- 後片付け: `204,204,204,204,204`（本人の設定は持ち主の member が自分で消す）

---

## 2D. 送った値の形と長さ（HTTP テスト）

形の違う値・長すぎる値を、500 や黙った取りこぼしにせず、何が悪いかの分かる 422 で断ることを確かめる。admin の API キーだけを使う。2D だけで流せる（ほかの節の変数を使わない）。作った設定は最後（[2-47]）に消す。

コントローラーが返すメッセージ（`... must be a string` など）は常に英語なので、文言まで確かめる。モデルの検証のメッセージ（`Name is too long ...` など）は利用者の言語で返るので、ここでは 422 と件数だけを確かめ、文言は Runner の [1-49] で確かめる。

### 事前準備

```powershell
$AdminKey = '{ApiKey}'
$T = "test_input_" + (Get-Random)   # この節で作る設定の schema_type（実行ごとに変える）
$ProjectId = (Invoke-RestMethod -Uri "{BaseUrl}/projects.json?key=$AdminKey&limit=1").projects[0].id

# 本文をそのまま送る（形の違う JSON・XML を送るため）。$args は PowerShell の自動変数なので使わない
function Send-Raw($method, $path, $body, $ct = 'application/json') {
    $req = @{ Uri = "{BaseUrl}$path"; Method = $method; Headers = @{ 'X-Redmine-API-Key' = $AdminKey }; ContentType = $ct; SkipHttpErrorCheck = $true }
    if ($null -ne $body) { $req.Body = [Text.Encoding]::UTF8.GetBytes($body) }
    $r = Invoke-WebRequest @req
    $json = $null
    if ($ct -eq 'application/json' -and $r.Content) { $json = $r.Content | ConvertFrom-Json }
    [pscustomobject]@{ Status = [int]$r.StatusCode; Json = $json; Raw = [string]$r.Content }
}
function Send-Json($method, $path, $obj) { Send-Raw $method $path ($obj | ConvertTo-Json -Depth 5 -Compress) }
function Errs($r) { ($r.Json.errors) -join ' | ' }

# 更新・削除・復元に使う設定（版を 2 にして、履歴の 1 へ戻せるようにする）
$base = Send-Json POST '/studio_settings.json' @{ studio_setting = @{ name = 'n'; schema_type = $T; scope_type = 'global'; payload = '{}'; schema_version = 0 } }
$InputId = $base.Json.studio_setting.id
$Created = [Collections.Generic.List[int]]::new()   # この節で作った設定の id（[2-47] で消す）
$Created.Add($InputId)
(Send-Json PUT "/studio_settings/$InputId.json" @{ studio_setting = @{ name = 'n2' } }).Status
```

**期待結果:** `200`（`$InputId` が入っている）

### [2-41] studio_setting が無い・空・項目をまとめたものでない → 422

**確認方法:**
```powershell
Errs (Send-Raw POST '/studio_settings.json' '{"x":1}')
Errs (Send-Raw POST '/studio_settings.json' '{"studio_setting":{}}')
Errs (Send-Raw POST '/studio_settings.json' '{"studio_setting":"abc"}')
Errs (Send-Raw POST '/studio_settings.json' '{"studio_setting":[1,2]}')
Errs (Send-Raw PUT "/studio_settings/$InputId.json" '{"studio_setting":"abc"}')
(Send-Raw POST '/studio_settings.json' '{"studio_setting":"abc"}').Status
```

**期待結果:**
- `studio_setting is required` が 2 回
- `studio_setting must be an object` が 3 回
- `422`

### [2-42] 文字列で受ける項目が文字列でない → 422（悪い所をすべて返し、何も作らない）

**確認方法:**
```powershell
$r = Send-Raw POST '/studio_settings.json' ('{"studio_setting":{"name":{"a":1},"schema_type":"' + $T + '_s","scope_type":"global","schema_version":0,"payload":{"a":1}}}')
$r.Status; Errs $r
Errs (Send-Raw POST '/studio_settings.json' ('{"studio_setting":{"name":"n","schema_type":"' + $T + '_s","scope_type":"global","schema_version":0,"payload":5}}'))
Errs (Send-Raw POST '/studio_settings.json' ('{"studio_setting":{"name":"n","schema_type":["' + $T + '"],"scope_type":true,"schema_version":0}}'))
@((Invoke-RestMethod -Uri "{BaseUrl}/studio_settings.json?key=$AdminKey&schema_type=${T}_s").studio_settings).Count
```

**期待結果:**
- `422` と `name must be a string | payload must be a string`
- `payload must be a string`
- `schema_type must be a string | scope_type must be a string`
- `0`（どれも作られていない。`payload` がオブジェクトでも、中身を捨てて作ることはしない）

### [2-43] 整数で受ける項目が整数として読めない・範囲の外 → 422

**確認方法:**
```powershell
Errs (Send-Raw POST '/studio_settings.json' ('{"studio_setting":{"name":"n","schema_type":"' + $T + '_i","scope_type":"project","scope_id":"abc","schema_version":0}}'))
Errs (Send-Raw POST '/studio_settings.json' ('{"studio_setting":{"name":"n","schema_type":"' + $T + '_i","scope_type":"global","schema_version":1.5}}'))
Errs (Send-Raw POST '/studio_settings.json' ('{"studio_setting":{"name":"n","schema_type":"' + $T + '_i","scope_type":"global","schema_version":{"a":1}}}'))
Errs (Send-Raw POST '/studio_settings.json' ('{"studio_setting":{"name":"n","schema_type":"' + $T + '_i","scope_type":"global","schema_version":99999999999}}'))
# 数の文字列・空は受ける（XML では数も文字列で届く）
$ok = Send-Raw POST '/studio_settings.json' ('{"studio_setting":{"name":"n","schema_type":"' + $T + '_i","scope_type":"global","scope_id":"","schema_version":"2"}}')
$ok.Status; $ok.Json.studio_setting.schema_version
$Created.Add($ok.Json.studio_setting.id)
```

**期待結果:**
- `scope_id must be an integer`
- `schema_version must be an integer` が 3 回（小数・オブジェクト・整数の列に入らない数）
- `201`・`2`

### [2-44] name・schema_type が 255 文字を超える → 422（255 文字までは作れる）

SQLite は列の長さを見ないので、DB に任せず検証で 422 にしていることを、どの DB でも確かめる。

**確認方法:**
```powershell
$long = 'x' * 256
$r = Send-Json POST '/studio_settings.json' @{ studio_setting = @{ name = $long; schema_type = $long; scope_type = 'global'; schema_version = 0 } }
$r.Status; @($r.Json.errors).Count
$r = Send-Json POST '/studio_settings.json' @{ studio_setting = @{ name = ('y' * 255); schema_type = "${T}_l".PadRight(255, 'z'); scope_type = 'global'; schema_version = 0 } }
$r.Status; "$($r.Json.studio_setting.name.Length) $($r.Json.studio_setting.schema_type.Length)"
$Created.Add($r.Json.studio_setting.id)
```

**期待結果:**
- `422`・`2`（name と schema_type の 2 件）
- `201`・`255 255`

### [2-45] comment・version の形と長さ（更新・削除・復元）→ 422

**確認方法:**
```powershell
Errs (Send-Json PUT "/studio_settings/$InputId.json" @{ studio_setting = @{ name = 'n3'; comment = @{ a = 1 } } })
Errs (Send-Json PUT "/studio_settings/$InputId.json" @{ studio_setting = @{ name = 'n3'; comment = ('c' * 256) } })
(Send-Json PUT "/studio_settings/$InputId.json" @{ studio_setting = @{ name = 'n3'; comment = ('c' * 255) } }).Status
Errs (Send-Raw DELETE "/studio_settings/$InputId.json?comment=$('c' * 256)" $null)
Errs (Send-Raw DELETE "/studio_settings/$InputId.json?comment[a]=1" $null)
Errs (Send-Raw POST "/studio_settings/$InputId/restore.json?version=3&comment[a]=1" $null)
Errs (Send-Raw POST "/studio_settings/$InputId/restore.json?version=1&comment=$('c' * 256)" $null)
Errs (Send-Raw POST "/studio_settings/$InputId/restore.json?version[a]=1" $null)
# 断ったときは何も変わらない（消えていない・版は 3 のまま）
$s = (Send-Raw GET "/studio_settings/$InputId.json" $null).Json.studio_setting
"$($null -eq $s.deleted_on) v$($s.version)"
```

**期待結果:**
- `comment must be a string`
- `comment is too long (maximum is 255 characters)`
- `200`
- `comment is too long (maximum is 255 characters)`
- `comment must be a string`
- `comment must be a string`（版 3 は今の版だが、今の版と同じかを確かめるより先に返す）
- `comment is too long (maximum is 255 characters)`
- `version must be an integer`
- `True v3`

### [2-46] project スコープは実在するプロジェクトに付ける → 422

**確認方法:**
```powershell
$p = @{ name = 'n'; scope_type = 'project'; schema_version = 0 }
$r1 = Send-Json POST '/studio_settings.json' @{ studio_setting = $p + @{ schema_type = "${T}_p1" } }
$r2 = Send-Json POST '/studio_settings.json' @{ studio_setting = $p + @{ schema_type = "${T}_p2"; scope_id = 0 } }
$r3 = Send-Json POST '/studio_settings.json' @{ studio_setting = $p + @{ schema_type = "${T}_p3"; scope_id = 999999 } }
"$($r1.Status)/$(@($r1.Json.errors).Count) $($r2.Status)/$(@($r2.Json.errors).Count) $($r3.Status)/$(@($r3.Json.errors).Count)"
$ok = Send-Json POST '/studio_settings.json' @{ studio_setting = $p + @{ schema_type = "${T}_p4"; scope_id = $ProjectId } }
$ok.Status
$ProjSettingId = $ok.Json.studio_setting.id
$Created.Add($ProjSettingId)
# いないプロジェクトへの付け替えも断る
$u = Send-Json PUT "/studio_settings/$ProjSettingId.json" @{ studio_setting = @{ scope_id = 999999 } }
"$($u.Status)/$(@($u.Json.errors).Count)"
# 範囲を project へ変えるときも、scope_id のプロジェクトを確かめる
$g = Send-Json POST '/studio_settings.json' @{ studio_setting = @{ name = 'n'; schema_type = "${T}_g"; scope_type = 'global'; scope_id = 999999; schema_version = 0 } }
$g.Status
$Created.Add($g.Json.studio_setting.id)
$u = Send-Json PUT "/studio_settings/$($g.Json.studio_setting.id).json" @{ studio_setting = @{ scope_type = 'project' } }
"$($u.Status)/$(@($u.Json.errors).Count)"
```

**期待結果:**
- `422/1 422/1 422/1`（`scope_id` が無い・0・いない ID）
- `201`
- `422/1`
- `201`
- `422/1`

### [2-47] XML でも同じに断る・後片付け

**確認方法:**
```powershell
$x = Send-Raw POST '/studio_settings.xml' "<studio_setting><name>n</name><schema_type>${T}_x</schema_type><scope_type>global</scope_type><schema_version>0</schema_version><payload><a>1</a></payload></studio_setting>" 'application/xml'
$x.Status; "$($x.Raw -match '<error>payload must be a string</error>') $([regex]::Matches($x.Raw, '<error>').Count)"

# 後片付け（この節で作った分を消す）
"cleanup: " + (@($Created | ForEach-Object { (Send-Raw DELETE "/studio_settings/$_.json?force=1" $null).Status }) -join ',')
```

**期待結果:**
- `422`・`True 1`
- 後片付け: `204` が 5 回（`$T`・`${T}_i`・`${T}_l`…・`${T}_p4`・`${T}_g`）

---

## 3. ブラウザテスト

なし（API のみの機能のため）

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいて以下の順序でテストを実行する:

1. フェーズ 0: Runner テストの流し方を確かめる（Puma は止めない）
2. フェーズ 1: Runner テスト実行
   - バッチ 1: [1-1]～[1-12] 基本機能（12件）
   - バッチ 2: [1-13]～[1-29] 履歴機能（17件）
   - バッチ 3: [1-30]～[1-35] 可視性（Runner）・属性名の翻訳。[1-30] が前提データを作成し member_key / nonmember_key / proj_a / proj_b / member_id を出力する
   - バッチ 4: [1-36]～[1-49] 本人の設定と版、削除の後片付け、入力の検証（Runner）。バッチ 3 の後に流す
3. フェーズ 2: HTTP テスト実行
   - [2-1]～[2-7]: 基本機能
   - [2-8]～[2-13]: 履歴機能
   - [2-14]～[2-23b]: 可視性（HTTP）。[2-1] の前の事前準備で設定をすべて消すため、[1-30] で作った設定も消えている。[2-14] の前にバッチ 3 をもう一度流し、その出力キー / ID を事前準備に設定してから実行する
   - [2-24]～[2-40]: 本人の設定と版（HTTP）。2B の変数（`$projASettingId` を含む）をそのまま使うので、2B の続きで流す（2C の事前準備は、2B の変数が空なら止まる）
   - [2-41]～[2-47]: 送った値の形と長さ（HTTP）。admin の API キーだけで、単独で流せる

### Runner テスト実行時の注意事項

- バッチごとに 1 つのスクリプトにまとめ、各テストの結果を `[1-1] OK` / `[1-1] NG: <理由>` の形で出す。1 つのテストが例外で止まっても、後続のテストは流れるように、テストごとに `begin`〜`rescue` で囲む
- スクリプトはファイルにして渡す（フェーズ 0）。bash の引数に Ruby のコードを直接書くと、`!` が履歴展開されたり引用符がずれたりする
- SQLite のロックエラーが出たときは、少し待ってそのバッチを流し直す（フェーズ 0）
- [1-30] で作るユーザー・プロジェクトは消さずに残す。作り方は冪等（あれば使い、無ければ作る）なので、何度流してもよい。設定は [2-1] の前の事前準備で消えるので、[2-14] の前にバッチ 3 を流し直す

### HTTP テスト実行時の注意事項

- API キーは事前に取得しておく
- テストの順序依存性に注意（作成 → 取得 → 更新 → 削除）
- テストデータは削除せず残す（後から確認可能）。ただし 2C は [2-40]、2D は [2-47] で作った分を消す（各節の冒頭を参照）
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
