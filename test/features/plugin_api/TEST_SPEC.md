# プラグイン情報 API テスト仕様書

## 概要

プラグイン情報 API 機能のテスト仕様。この文書から runner_test.rb, http_test.ps1 を再生成できる。

## 環境パラメータ

以下のパラメータは TEST_SPEC.md のパスから自動判定する:

| パラメータ | 判定方法 |
|-----------|----------|
| Container | パス内の `redmine_X.Y.Z` フォルダ名をそのまま使用 |
| BaseUrl | バージョンからポート算出: `3000 + (メジャー × 10) + マイナー` |

固定パラメータ:

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| Username | `admin` | テスト用ログインID |
| Password | `password123` | テスト用パスワード |

**例:** パスが `C:\Docker\redmine_6.1.1\plugins\...` の場合
- Container: `redmine_6.1.1`
- BaseUrl: `http://localhost:3061`（3000 + 60 + 1）

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| Controller | `PluginsController` |
| ルーティング | `GET /plugins.json`, `GET /plugins/:id.json` |
| View ファイル | `app/views/plugins/index.api.rsb`, `app/views/plugins/show.api.rsb` |
| 認証 | API キー必須（未認証で 401 または 302） |

### API レスポンス構造

**一覧取得 (`GET /plugins.json`):**
```json
{
  "plugins": [
    { "id": "plugin_id", "name": "Plugin Name", "version": "1.0.0", "author": "Author" }
  ],
  "total_count": 3
}
```

**単体取得 (`GET /plugins/:id.json`):**
```json
{
  "plugin": {
    "id": "plugin_id",
    "name": "Plugin Name",
    "version": "1.0.0",
    "author": "Author",
    "settings": "{...}"  // 常に含まれる
  }
}
```

---

## 1. rails runner テスト

**実行方法:**
```bash
docker exec {Container} rails runner plugins/redmine_studio_plugin/test/features/plugin_api/runner_test.rb
```

### [1-1] PluginsController が定義されている

**確認方法:**
```ruby
defined?(PluginsController)
```

**期待結果:**
- 定義されている（nil ではない）

---

### [1-2] ルーティングが設定されている

**確認方法:**
```ruby
routes = Rails.application.routes.routes
index_route = routes.any? { |r| r.defaults[:controller] == 'plugins' && r.defaults[:action] == 'index' }
show_route = routes.any? { |r| r.defaults[:controller] == 'plugins' && r.defaults[:action] == 'show' }
```

**期待結果:**
- `index_route` が true
- `show_route` が true

---

### [1-3] View ファイルが存在する

**確認方法:**
```ruby
plugin_path = Rails.root.join('plugins', 'redmine_studio_plugin')
index_view = plugin_path.join('app', 'views', 'plugins', 'index.api.rsb')
show_view = plugin_path.join('app', 'views', 'plugins', 'show.api.rsb')
File.exist?(index_view) && File.exist?(show_view)
```

**期待結果:**
- 両方のファイルが存在する

---

## 2. HTTP テスト

**実行方法:**
```powershell
pwsh -File "...\http_test.ps1" -BaseUrl "http://localhost:3051"
```

**API キーの取得:**
```ruby
User.find_by_login('admin').api_key ||
User.find_by_login('admin').tap { |u| u.api_key = SecureRandom.hex(20); u.save! }.api_key
```

### [2-1] 未認証でアクセス

**確認方法:**
- GET `/plugins.json`（API キーなし）

**期待結果:**
- ステータスコード 401 または 302

---

### [2-2] API キーで認証（JSON）

**確認方法:**
- GET `/plugins.json?key={ApiKey}`

**期待結果:**
- ステータスコード 200

---

### [2-3] API キーで認証（XML）

**確認方法:**
- GET `/plugins.xml?key={ApiKey}`

**期待結果:**
- ステータスコード 200
- レスポンスに `<plugins` が含まれる

---

### [2-4] plugins 配列が返る

**確認方法:**
- GET `/plugins.json?key={ApiKey}` のレスポンス

**期待結果:**
- `response.plugins` が配列

---

### [2-5] total_count がプラグイン数と一致

**確認方法:**
- GET `/plugins.json?key={ApiKey}` のレスポンス

**期待結果:**
- `response.plugins.length == response.total_count`

---

### [2-6] 必須フィールドが存在（id, name, version, author）

**確認方法:**
- GET `/plugins.json?key={ApiKey}` のレスポンス
- 最初のプラグインを検証

**期待結果:**
- `id`, `name`, `version`, `author` が全て存在

---

### [2-7] ?include=settings なし → settings なし

**確認方法:**
- GET `/plugins.json?key={ApiKey}`（include パラメータなし）

**期待結果:**
- 各プラグインに `settings` フィールドが存在しない

---

### [2-8] ?include=settings あり、設定ありプラグイン → JSON 文字列

**確認方法:**
- GET `/plugins.json?key={ApiKey}&include=settings`
- 設定を持つプラグイン（例: `redmine_teams_button`）を検証

**期待結果:**
- `settings` フィールドが存在し、null ではない

---

### [2-9] ?include=settings あり、設定なしプラグイン → null

**確認方法:**
- GET `/plugins.json?key={ApiKey}&include=settings`
- 設定を持たないプラグイン（例: `redmine_studio_plugin`）を検証

**期待結果:**
- `settings` フィールドが存在し、値が null

---

### [2-10] 単体取得（JSON）

**確認方法:**
- GET `/plugins/redmine_studio_plugin.json?key={ApiKey}`

**期待結果:**
- `response.plugin.id` が `"redmine_studio_plugin"`

---

### [2-11] 単体取得（XML）

**確認方法:**
- GET `/plugins/redmine_studio_plugin.xml?key={ApiKey}`

**期待結果:**
- ステータスコード 200
- レスポンスに `<plugin>` が含まれる

---

### [2-12] 単体取得で settings が常に含まれる

**確認方法:**
- GET `/plugins/redmine_studio_plugin.json?key={ApiKey}`

**期待結果:**
- `response.plugin` に `settings` フィールドが存在する

---

### [2-13] 存在しない ID → 404

**確認方法:**
- GET `/plugins/non_existent_plugin.json?key={ApiKey}`

**期待結果:**
- ステータスコード 404

---

### [2-14] settings が有効な JSON 文字列

**確認方法:**
- 設定を持つ任意のプラグインを対象とする（例: `redmine_subtask_list_accordion`）
- GET `/plugins/{plugin_id}.json?key={ApiKey}`
- `response.plugin.settings` を JSON パース

**期待結果:**
- パースが成功する（有効な JSON）
- settings が null の場合も PASS（設定が未構成の状態）

---

### [2-15] settings の内容が DB の値と一致

**確認方法:**
- [2-14] と同じプラグインを対象とする
- API: GET `/plugins/{plugin_id}.json?key={ApiKey}`
- DB: `Setting['plugin_{plugin_id}'].to_json`

**期待結果:**
- API の settings と DB の値が一致

**備考:**
- [2-14] で JSON パースの成功を確認しているため、実質的に [2-14] でカバーされる

---

## 3. ブラウザテスト

なし（API のみの機能のため）

---

## テスト実行方法

### runner テスト・HTTP テスト
Claude が TEST_SPEC.md の仕様に基づいてコマンドを実行し、結果を報告する。

---

## 参考ファイル（保守対象外）

以下は参考実装。TEST_SPEC.md が正とし、Claude が必要に応じて再生成する。

| ファイル | 説明 |
|---------|------|
| runner_test.rb | rails runner テスト参考実装 |
| http_test.ps1 | HTTP テスト参考実装 |
