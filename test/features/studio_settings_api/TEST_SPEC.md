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
| モデル | `StudioSetting`, `StudioSettingAssignment` |
| DBテーブル | `studio_settings`, `studio_setting_assignments` |
| コントローラ | `StudioSettingsController`, `StudioSettingUsersController`, `UserStudioSettingsController` |
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

### レスポンス形式

API は JSON と XML の両方をサポートする。

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

### フェーズ 1: 登録確認テスト（バッチ 1）

プラグインの登録状態を確認する。

- バッチ 1: [1-1] ～ [1-12] を1つのスクリプトにまとめて実行

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

## 3. ブラウザテスト

なし（API のみの機能のため）

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいて以下の順序でテストを実行する:

1. フェーズ 0: Puma 停止（SQLite ロック回避）
2. フェーズ 1: 登録確認テスト実行（バッチ 1）
3. フェーズ 2: コンテナ再起動（HTTP テストに備える）
4. フェーズ 3: HTTP テスト実行

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

### レスポンス形式

- 一覧取得: `{ "<リソース名>": [...], "total_count": N, "offset": N, "limit": N }`
- 単体取得/作成/更新: `{ "<リソース名>": {...} }`
- 関連オブジェクト: `{ "id": N, "name": "..." }` 形式（ID のみではない）
- PUT /studio_settings/:id/users のリクエスト: `{ "user_ids": [1, 2, 3] }`
