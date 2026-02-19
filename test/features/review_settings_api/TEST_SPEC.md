# Review Settings API テスト仕様書

## 概要

Redmine Studio のレビュー設定を Redmine サーバー側に保存・取得するための API 機能のテスト仕様。

**主な機能:**
- レビュー設定の CRUD 操作
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
| モデル | `ReviewSetting`, `ReviewSettingAssignment` |
| DBテーブル | `review_settings`, `review_setting_assignments` |
| コントローラ | `ReviewSettingsController`, `ReviewSettingUsersController`, `UserReviewSettingsController` |
| 認証 | API キー必須（未認証で 401） |

### API エンドポイント

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/review_settings.json` | 設定一覧取得 |
| GET | `/review_settings/:id.json` | 設定詳細取得 |
| POST | `/review_settings.json` | 設定作成 |
| PUT | `/review_settings/:id.json` | 設定更新 |
| DELETE | `/review_settings/:id.json` | 設定削除（論理/物理） |
| GET | `/review_settings/:id/users.json` | ユーザー割り当て一覧 |
| PUT | `/review_settings/:id/users.json` | ユーザー割り当て置換 |
| POST | `/review_settings/:id/users/:user_id.json` | ユーザー割り当て追加 |
| DELETE | `/review_settings/:id/users/:user_id.json` | ユーザー割り当て削除 |
| GET | `/users/:id/review_settings.json` | ユーザーの設定一覧 |

### API リクエスト/レスポンス構造

**PUT /review_settings/:id/users リクエストボディ:**
```json
[1, 2, 3]
```
※ ユーザー ID の配列を直接送信

**設定一覧・ユーザー割り当て一覧:**
```json
[
  { "id": 1, "name": "...", ... },
  { "id": 2, "name": "...", ... }
]
```

**設定単体:**
```json
{
  "id": 1,
  "name": "設定名",
  "scope_type": "global",
  "scope_id": null,
  "schema_version": 0,
  "payload": "{...}",
  "created_on": "2026-02-19T...",
  "created_by_id": 1,
  "updated_on": "2026-02-19T...",
  "updated_by_id": 1,
  "deleted_on": null,
  "deleted_by_id": null
}
```

**削除時:** HTTP 204 No Content（ボディなし）

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

### [1-1] ReviewSetting モデル確認

**確認方法:**
```ruby
puts defined?(ReviewSetting)
puts ReviewSetting.ancestors.include?(ActiveRecord::Base)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-2] ReviewSettingAssignment モデル確認

**確認方法:**
```ruby
puts defined?(ReviewSettingAssignment)
puts ReviewSettingAssignment.ancestors.include?(ActiveRecord::Base)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-3] review_settings テーブル確認

**確認方法:**
```ruby
columns = ActiveRecord::Base.connection.columns(:review_settings).map(&:name)
expected = %w[id name scope_type scope_id payload schema_version created_on created_by_id updated_on updated_by_id deleted_on deleted_by_id]
puts (expected - columns).empty?
```

**期待結果:**
- `true` が出力される

### [1-4] review_setting_assignments テーブル確認

**確認方法:**
```ruby
columns = ActiveRecord::Base.connection.columns(:review_setting_assignments).map(&:name)
expected = %w[id setting_id user_id assigned_on assigned_by_id]
puts (expected - columns).empty?
```

**期待結果:**
- `true` が出力される

### [1-5] ReviewSettingsController 確認

**確認方法:**
```ruby
puts defined?(ReviewSettingsController)
puts ReviewSettingsController.ancestors.include?(ApplicationController)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-6] ReviewSettingUsersController 確認

**確認方法:**
```ruby
puts defined?(ReviewSettingUsersController)
puts ReviewSettingUsersController.ancestors.include?(ApplicationController)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-7] UserReviewSettingsController 確認

**確認方法:**
```ruby
puts defined?(UserReviewSettingsController)
puts UserReviewSettingsController.ancestors.include?(ApplicationController)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-8] ルーティング確認

**確認方法:**
```ruby
routes = [
  { path: '/review_settings', method: :get, expected: { controller: 'review_settings', action: 'index' } },
  { path: '/review_settings/1', method: :get, expected: { controller: 'review_settings', action: 'show', id: '1' } },
  { path: '/review_settings', method: :post, expected: { controller: 'review_settings', action: 'create' } },
  { path: '/review_settings/1', method: :put, expected: { controller: 'review_settings', action: 'update', id: '1' } },
  { path: '/review_settings/1', method: :delete, expected: { controller: 'review_settings', action: 'destroy', id: '1' } },
  { path: '/review_settings/1/users', method: :get, expected: { controller: 'review_setting_users', action: 'index', id: '1' } },
  { path: '/review_settings/1/users', method: :put, expected: { controller: 'review_setting_users', action: 'replace', id: '1' } },
  { path: '/review_settings/1/users/2', method: :post, expected: { controller: 'review_setting_users', action: 'add', id: '1', user_id: '2' } },
  { path: '/review_settings/1/users/2', method: :delete, expected: { controller: 'review_setting_users', action: 'remove', id: '1', user_id: '2' } },
  { path: '/users/1/review_settings', method: :get, expected: { controller: 'user_review_settings', action: 'index', id: '1' } },
]

results = routes.map do |r|
  recognized = Rails.application.routes.recognize_path(r[:path], method: r[:method])
  r[:expected].all? { |k, v| recognized[k].to_s == v.to_s }
end

puts results.all?
```

**期待結果:**
- `true` が出力される

### [1-9] ReviewSetting バリデーション確認

**確認方法:**
```ruby
# name 必須
rs = ReviewSetting.new(scope_type: 'global', schema_version: 0)
rs.created_by = User.current
rs.updated_by = User.current
puts rs.valid? == false
puts rs.errors[:name].include?("can't be blank")

# scope_type 必須
rs = ReviewSetting.new(name: 'Test', schema_version: 0)
rs.created_by = User.current
rs.updated_by = User.current
puts rs.valid? == false
puts rs.errors[:scope_type].include?("can't be blank")

# schema_version >= 0
rs = ReviewSetting.new(name: 'Test', scope_type: 'global', schema_version: -1)
rs.created_by = User.current
rs.updated_by = User.current
puts rs.valid? == false

# schema_version は整数のみ
rs = ReviewSetting.new(name: 'Test', scope_type: 'global', schema_version: 1.5)
rs.created_by = User.current
rs.updated_by = User.current
puts rs.valid? == false
```

**期待結果:**
- 全て `true` が出力される（6回）

### [1-10] ReviewSettingAssignment バリデーション確認

**確認方法:**
```ruby
# テスト用設定を作成
admin = User.find_by_login('admin')
User.current = admin
setting = ReviewSetting.create(name: 'ValidationTest', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)

# 正常ケース
assignment = ReviewSettingAssignment.new(setting: setting, user: admin, assigned_by: admin)
puts assignment.valid?

# uniqueness 制約（同一 setting_id + user_id）
assignment.save
dup = ReviewSettingAssignment.new(setting: setting, user: admin, assigned_by: admin)
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
setting = ReviewSetting.create(name: 'SoftDeleteTest', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)

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
setting = ReviewSetting.create(name: 'DependentTest', scope_type: 'global', schema_version: 0, created_by: admin, updated_by: admin)
assignment = ReviewSettingAssignment.create(setting: setting, user: admin, assigned_by: admin)
assignment_id = assignment.id

puts ReviewSettingAssignment.exists?(assignment_id)

setting.destroy

puts ReviewSettingAssignment.exists?(assignment_id) == false
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
ReviewSettingAssignment.delete_all
ReviewSetting.delete_all
```

---

### [2-1] 認証テスト

#### [2-1-1] 未認証でアクセス → 401

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings.json" -Method GET -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 401

#### [2-1-2] API キーで認証 → 200

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method GET
```

**期待結果:**
- エラーなく完了（配列が返る）

---

### [2-2] 設定の CRUD テスト

#### [2-2-1] 設定作成（POST）

**確認方法:**
```powershell
$body = @{
    review_setting = @{
        name = "ReviewSettings_Test_Create"
        scope_type = "global"
        schema_version = 0
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$response
```

**期待結果:**
- `id` が返る（数値）
- `name` が `ReviewSettings_Test_Create`
- `scope_type` が `global`
- `schema_version` が `0`
- `created_by_id` が admin のユーザー ID
- `payload` が含まれる（null または空）

#### [2-2-2] 設定作成（payload あり）

**確認方法:**
```powershell
$body = @{
    review_setting = @{
        name = "ReviewSettings_Test_WithPayload"
        scope_type = "project"
        scope_id = 1
        schema_version = 1
        payload = '{"key":"value"}'
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
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
    review_setting = @{
        scope_type = "global"
        schema_version = 0
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json" -SkipHttpErrorCheck
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
    review_setting = @{
        name = "Test"
        schema_version = 0
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json" -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 422
- errors に "Scope type can't be blank" を含む

#### [2-2-5] 設定取得（GET 単体）

**確認方法:**
```powershell
# [2-2-1] で作成した ID を使用
$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings/$SettingId.json?key=$ApiKey" -Method GET
$response
```

**期待結果:**
- `id` が指定した ID と一致
- `payload` が含まれる（show は常に payload を含む）

#### [2-2-6] 設定取得（存在しない ID）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/99999.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).error
```

**期待結果:**
- ステータスコード 404
- error に "Review setting not found: id=99999" を含む

#### [2-2-7] 設定更新（PUT）

**確認方法:**
```powershell
$body = @{
    review_setting = @{
        name = "ReviewSettings_Test_Updated"
        payload = '{"updated":true}'
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings/$SettingId.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"
$response
```

**期待結果:**
- `name` が `ReviewSettings_Test_Updated`
- `payload` が `{"updated":true}`
- `updated_on` が更新されている

#### [2-2-8] 設定削除（論理削除: DELETE）

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$SettingId.json?key=$ApiKey" -Method DELETE
$response.StatusCode

# 削除後に取得して確認
$check = Invoke-RestMethod -Uri "http://localhost:3061/review_settings/$SettingId.json?key=$ApiKey" -Method GET
$check.deleted_on
```

**期待結果:**
- ステータスコード 204
- `deleted_on` が null でない（日時が設定されている）
- `deleted_by_id` が admin のユーザー ID

#### [2-2-9] 設定削除（物理削除: DELETE + force=1）

**確認方法:**
```powershell
# 新規作成
$body = @{
    review_setting = @{
        name = "ReviewSettings_Test_ForceDelete"
        scope_type = "global"
        schema_version = 0
    }
} | ConvertTo-Json -Depth 3
$created = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$deleteId = $created.id

# 物理削除
$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$deleteId.json?key=$ApiKey&force=1" -Method DELETE
$response.StatusCode

# 削除後に取得 → 404
$check = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$deleteId.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$check.StatusCode
```

**期待結果:**
- 削除のステータスコード 204
- 取得のステータスコード 404（レコードが存在しない）

#### [2-2-10] 設定更新（存在しない ID）→ 404

**確認方法:**
```powershell
$body = @{
    review_setting = @{
        name = "NonExistent"
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/99999.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json" -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).error
```

**期待結果:**
- ステータスコード 404
- error に "Review setting not found: id=99999" を含む

#### [2-2-11] 設定削除（存在しない ID）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/99999.json?key=$ApiKey" -Method DELETE -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).error
```

**期待結果:**
- ステータスコード 404
- error に "Review setting not found: id=99999" を含む

#### [2-2-12] 設定作成（バリデーションエラー: schema_version 負の数）→ 422

**確認方法:**
```powershell
$body = @{
    review_setting = @{
        name = "Test"
        scope_type = "global"
        schema_version = -1
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json" -SkipHttpErrorCheck
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
$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method GET
$response.GetType().Name  # Object[] であることを確認
$response.Count
```

**期待結果:**
- 配列が返る
- 論理削除されていないレコードのみ含まれる

#### [2-3-2] scope_type フィルタ

**確認方法:**
```powershell
# テストデータ作成
$body1 = @{ review_setting = @{ name = "Filter_Global"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$body2 = @{ review_setting = @{ name = "Filter_Project"; scope_type = "project"; scope_id = 1; schema_version = 0 } } | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method POST -Body $body1 -ContentType "application/json"
Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method POST -Body $body2 -ContentType "application/json"

# フィルタ
$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey&scope_type=global" -Method GET
$response | Where-Object { $_.scope_type -ne "global" }
```

**期待結果:**
- 全て `scope_type` が `global` のレコードのみ
- `project` のレコードは含まれない

#### [2-3-3] scope_id フィルタ

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey&scope_type=project&scope_id=1" -Method GET
$response | Where-Object { $_.scope_id -ne 1 }
```

**期待結果:**
- 全て `scope_id` が `1` のレコードのみ

#### [2-3-4] include_deleted フィルタ

**確認方法:**
```powershell
# 論理削除されたレコードがある状態で
$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey&include_deleted=1" -Method GET
$deleted = $response | Where-Object { $_.deleted_on -ne $null }
$deleted.Count
```

**期待結果:**
- 論理削除されたレコードも含まれる

#### [2-3-5] include=payload

**確認方法:**
```powershell
# payload なし
$withoutPayload = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method GET
$withoutPayload[0].PSObject.Properties.Name -contains "payload"

# payload あり
$withPayload = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey&include=payload" -Method GET
$withPayload[0].PSObject.Properties.Name -contains "payload"
```

**期待結果:**
- `include=payload` なし: payload フィールドが含まれない
- `include=payload` あり: payload フィールドが含まれる

---

### [2-4] ユーザー割り当てテスト

#### [2-4-1] ユーザー一覧取得（GET）

**確認方法:**
```powershell
# テスト用設定を作成
$body = @{ review_setting = @{ name = "UserAssignment_Test"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.id

$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings/$settingId/users.json?key=$ApiKey" -Method GET
$response.GetType().Name
```

**期待結果:**
- 配列が返る（空配列）

#### [2-4-2] ユーザー追加（POST）

**確認方法:**
```powershell
# admin ユーザーの ID を取得（通常 1）
$adminId = 1

$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$settingId/users/$adminId.json?key=$ApiKey" -Method POST
$response.StatusCode
($response.Content | ConvertFrom-Json)
```

**期待結果:**
- ステータスコード 201
- `setting_id` が設定 ID と一致
- `user_id` が admin の ID と一致
- `assigned_by_id` が admin の ID と一致

#### [2-4-3] ユーザー追加（重複）

**確認方法:**
```powershell
# 同じユーザーを再度追加
$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$settingId/users/$adminId.json?key=$ApiKey" -Method POST
$response.StatusCode
```

**期待結果:**
- ステータスコード 200（既存を返す）
- 新規作成されない（同じ ID が返る）

#### [2-4-4] ユーザー一覧（追加後）

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings/$settingId/users.json?key=$ApiKey" -Method GET
$response.Count
```

**期待結果:**
- 1件のレコードが返る

#### [2-4-5] ユーザー削除（DELETE）

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$settingId/users/$adminId.json?key=$ApiKey" -Method DELETE
$response.StatusCode

# 確認
$check = Invoke-RestMethod -Uri "http://localhost:3061/review_settings/$settingId/users.json?key=$ApiKey" -Method GET
$check.Count
```

**期待結果:**
- ステータスコード 204
- 削除後の一覧は空配列

#### [2-4-6] ユーザー削除（存在しない）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$settingId/users/99999.json?key=$ApiKey" -Method DELETE -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).error
```

**期待結果:**
- ステータスコード 404
- error に "Assignment not found: setting_id=..., user_id=99999" を含む

#### [2-4-7] ユーザー置換（PUT）

**確認方法:**
```powershell
# テスト用ユーザー作成
$user1Id = 1  # admin

$body = @($user1Id) | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"
$response.Count
```

**期待結果:**
- 指定したユーザーのみが割り当てられている
- 以前の割り当ては削除されている

#### [2-4-8] ユーザー置換（空配列で全削除）

**確認方法:**
```powershell
$body = "[]"

$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"
$response.Count

# 確認
$check = Invoke-RestMethod -Uri "http://localhost:3061/review_settings/$settingId/users.json?key=$ApiKey" -Method GET
$check.Count
```

**期待結果:**
- 空配列が返る
- 全ての割り当てが削除されている

#### [2-4-9] ユーザー置換（複数ユーザー）

**確認方法:**
```powershell
# テスト用設定を作成
$body = @{ review_setting = @{ name = "MultiUserTest"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.id

# 複数ユーザーを一括設定（admin=1 と他のユーザー）
# ※ 環境に存在するユーザー ID を使用
$body = @(1, 2) | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:3061/review_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json"
$response.Count

# 確認
$check = Invoke-RestMethod -Uri "http://localhost:3061/review_settings/$settingId/users.json?key=$ApiKey" -Method GET
$check.Count
```

**期待結果:**
- 2件の割り当てが返る
- 指定した両方のユーザーが割り当てられている

#### [2-4-10] ユーザー追加（存在しないユーザー）→ 422

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$settingId/users/99999.json?key=$ApiKey" -Method POST -SkipHttpErrorCheck
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
$body = @{ review_setting = @{ name = "DependentDestroyTest"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.id

# ユーザーを割り当て
Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$settingId/users/1.json?key=$ApiKey" -Method POST

# 割り当て確認
$before = Invoke-RestMethod -Uri "http://localhost:3061/review_settings/$settingId/users.json?key=$ApiKey" -Method GET
$before.Count  # 1

# 設定を物理削除
Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$settingId.json?key=$ApiKey&force=1" -Method DELETE

# 設定が削除されていることを確認
$check = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$settingId.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$check.StatusCode  # 404
```

**期待結果:**
- 設定削除前: 1件の割り当てが存在
- 設定削除後: 設定が 404（assignments も連動して削除されている）

**備考:**
- `dependent: :destroy` により、親レコード削除時に子レコードも削除される
- HTTP API では直接 assignments の存在確認ができないため、Runner テスト [1-12] で詳細を確認

---

### [2-5] ユーザーの設定一覧テスト

#### [2-5-1] ユーザーの設定一覧取得

**確認方法:**
```powershell
# ユーザーに設定を割り当て
$body = @{ review_setting = @{ name = "UserSettings_Test"; scope_type = "global"; schema_version = 0 } } | ConvertTo-Json -Depth 3
$setting = Invoke-RestMethod -Uri "http://localhost:3061/review_settings.json?key=$ApiKey" -Method POST -Body $body -ContentType "application/json"
$settingId = $setting.id

Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$settingId/users/1.json?key=$ApiKey" -Method POST

# 一覧取得
$response = Invoke-RestMethod -Uri "http://localhost:3061/users/1/review_settings.json?key=$ApiKey" -Method GET
$response.GetType().Name
$response | Where-Object { $_.setting_id -eq $settingId }
```

**期待結果:**
- 配列が返る
- 割り当てた設定が含まれる

#### [2-5-2] ユーザーの設定一覧（論理削除された設定は除外）

**確認方法:**
```powershell
# 設定を論理削除
Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$settingId.json?key=$ApiKey" -Method DELETE

# 一覧取得
$response = Invoke-RestMethod -Uri "http://localhost:3061/users/1/review_settings.json?key=$ApiKey" -Method GET
$response | Where-Object { $_.setting_id -eq $settingId }
```

**期待結果:**
- 論理削除された設定は含まれない

#### [2-5-3] ユーザーの設定一覧（存在しないユーザー）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/users/99999/review_settings.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).error
```

**期待結果:**
- ステータスコード 404
- error に "User not found: id=99999" を含む

---

### [2-6] エラーハンドリングテスト

#### [2-6-1] 設定の users エンドポイント（存在しない設定）→ 404

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/99999/users.json?key=$ApiKey" -Method GET -SkipHttpErrorCheck
$response.StatusCode
($response.Content | ConvertFrom-Json).error
```

**期待結果:**
- ステータスコード 404
- error に "Review setting not found: id=99999" を含む

#### [2-6-2] ユーザー置換（存在しないユーザー ID）→ 422

**確認方法:**
```powershell
$body = @(99999) | ConvertTo-Json

$response = Invoke-WebRequest -Uri "http://localhost:3061/review_settings/$settingId/users.json?key=$ApiKey" -Method PUT -Body $body -ContentType "application/json" -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:**
- ステータスコード 422
- errors にバリデーションエラーメッセージを含む

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
