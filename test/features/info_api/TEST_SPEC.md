# Redmine 情報 API テスト仕様書

## 概要

Redmine 環境情報 API 機能のテスト仕様。「管理」＞「情報」画面で表示される情報を API で取得する。

## 環境パラメータ

以下のパラメータは TEST_SPEC.md のパスから自動判定する:

| パラメータ | 判定方法 |
|-----------|----------|
| Container | パス内の `redmine_X.Y.Z` フォルダ名をそのまま使用 |
| BaseUrl | バージョンからポート算出: `3000 + (メジャー × 10) + マイナー` |

**例:** パスが `C:\Docker\redmine_6.1.1\plugins\...` の場合
- Container: `redmine_6.1.1`
- BaseUrl: `http://localhost:3061`（3000 + 60 + 1）

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| Controller | `InfoController` |
| ルーティング | `GET /info.json`, `GET /info.xml` |
| View ファイル | `app/views/info/show.api.rsb` |
| 認証 | 不要（誰でもアクセス可能） |

### レスポンス形式

API は JSON と XML の両方をサポートする。

| 拡張子 | Content-Type |
|--------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

### API レスポンス構造

**GET `/info.json`:**
```json
{
  "info": {
    "redmine_version": "6.1.1.stable",
    "ruby_version": "3.4.8-p72 (2025-12-17) [x86_64-linux]",
    "rails_version": "7.2.3",
    "environment": "production",
    "database_adapter": "SQLite",
    "mailer_queue": "ActiveJob::QueueAdapters::AsyncAdapter",
    "mailer_delivery": "smtp",
    "redmine_theme": "Default",
    "scm": [
      { "name": "Git", "version": "2.47.3" }
    ],
    "plugins": [
      { "id": "redmine_studio_plugin", "version": "1.1.4" }
    ]
  }
}
```

### レスポンスフィールド

| フィールド | 型 | 説明 |
|-----------|-----|------|
| redmine_version | string | Redmine のバージョン |
| ruby_version | string | Ruby のバージョン（プラットフォーム情報含む） |
| rails_version | string | Rails のバージョン |
| environment | string | 実行環境（production, development, test） |
| database_adapter | string | データベースアダプタ名 |
| mailer_queue | string | メールキューアダプタのクラス名 |
| mailer_delivery | string | メール配信方法 |
| redmine_theme | string | UI テーマ（未設定時は "Default"） |
| scm | array | インストール済み SCM の一覧（バージョン取得可能なもののみ） |
| plugins | array | インストール済みプラグインの一覧 |

---

## 1. Runner テスト

**実行方法:**
```bash
docker exec {Container} bash -c "cd /usr/src/redmine && bundle exec rails runner '{code}'"
```

### [1-1] InfoController が定義されている

**確認方法:**
```ruby
puts defined?(InfoController) ? 'PASS' : 'FAIL: InfoController not defined'
```

**期待結果:**
- `InfoController` が定義されている

---

### [1-2] ルーティングが設定されている

**確認方法:**
```ruby
routes = Rails.application.routes.routes
info_route = routes.any? { |r| r.defaults[:controller] == 'info' && r.defaults[:action] == 'show' }
puts info_route ? 'PASS' : 'FAIL: info#show route not found'
```

**期待結果:**
- `info#show` ルートが存在する

---

### [1-3] View ファイルが存在する

**確認方法:**
```ruby
plugin_path = Rails.root.join('plugins', 'redmine_studio_plugin')
view_file = plugin_path.join('app', 'views', 'info', 'show.api.rsb')
puts File.exist?(view_file) ? 'PASS' : 'FAIL: show.api.rsb not found'
```

**期待結果:**
- `app/views/info/show.api.rsb` が存在する

---

### [1-4] gather_info メソッドが正しいキーを返す

**確認方法:**
```ruby
controller = InfoController.new
info = controller.send(:gather_info)
expected_keys = [:redmine_version, :ruby_version, :rails_version, :environment,
                 :database_adapter, :mailer_queue, :mailer_delivery, :redmine_theme,
                 :scm, :plugins]
missing = expected_keys - info.keys
puts missing.empty? ? 'PASS' : "FAIL: Missing keys: #{missing.join(', ')}"
```

**期待結果:**
- 全ての期待キーが存在する

---

### [1-5] scm が配列である

**確認方法:**
```ruby
controller = InfoController.new
info = controller.send(:gather_info)
puts info[:scm].is_a?(Array) ? 'PASS' : 'FAIL: scm is not an Array'
```

**期待結果:**
- `scm` が配列

---

### [1-6] plugins が配列である

**確認方法:**
```ruby
controller = InfoController.new
info = controller.send(:gather_info)
puts info[:plugins].is_a?(Array) ? 'PASS' : 'FAIL: plugins is not an Array'
```

**期待結果:**
- `plugins` が配列

---

### [1-7] plugins に redmine_studio_plugin が含まれる

**確認方法:**
```ruby
controller = InfoController.new
info = controller.send(:gather_info)
studio = info[:plugins].find { |p| p[:id] == 'redmine_studio_plugin' }
puts studio ? 'PASS' : 'FAIL: redmine_studio_plugin not found in plugins'
```

**期待結果:**
- `redmine_studio_plugin` がプラグイン一覧に含まれる

---

### [1-8] redmine_theme が未設定時に "Default" を返す

**確認方法:**
```ruby
# Setting.ui_theme が空の場合のテスト
original = Setting.ui_theme
begin
  Setting.ui_theme = ''
  controller = InfoController.new
  info = controller.send(:gather_info)
  result = info[:redmine_theme] == 'Default'
  puts result ? 'PASS' : "FAIL: Expected 'Default', got '#{info[:redmine_theme]}'"
ensure
  Setting.ui_theme = original
end
```

**期待結果:**
- `ui_theme` が空の場合、`redmine_theme` は `"Default"` を返す

---

## 2. HTTP テスト

**実行方法:**
PowerShell で各エンドポイントにリクエストを送信する。

### [2-1] JSON 形式でアクセス可能

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/info.json' -Method Get
$response.StatusCode
```

**期待結果:**
- ステータスコード 200

---

### [2-2] XML 形式でアクセス可能

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/info.xml' -Method Get
$response.StatusCode
```

**期待結果:**
- ステータスコード 200

---

### [2-3] JSON レスポンスに info オブジェクトが含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/info.json' -Method Get
$response.info -ne $null
```

**期待結果:**
- `info` オブジェクトが存在する

---

### [2-4] redmine_version が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/info.json' -Method Get
$response.info.redmine_version
```

**期待結果:**
- `redmine_version` が空でない文字列

---

### [2-5] ruby_version が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/info.json' -Method Get
$response.info.ruby_version
```

**期待結果:**
- `ruby_version` が空でない文字列

---

### [2-6] rails_version が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/info.json' -Method Get
$response.info.rails_version
```

**期待結果:**
- `rails_version` が空でない文字列

---

### [2-7] environment が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/info.json' -Method Get
$response.info.environment
```

**期待結果:**
- `environment` が `production`, `development`, または `test`

---

### [2-8] database_adapter が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/info.json' -Method Get
$response.info.database_adapter
```

**期待結果:**
- `database_adapter` が空でない文字列

---

### [2-9] mailer_queue が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/info.json' -Method Get
$response.info.mailer_queue
```

**期待結果:**
- `mailer_queue` が空でない文字列

---

### [2-10] mailer_delivery が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/info.json' -Method Get
$response.info.mailer_delivery
```

**期待結果:**
- `mailer_delivery` が空でない文字列

---

### [2-11] redmine_theme が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/info.json' -Method Get
$response.info.redmine_theme
```

**期待結果:**
- `redmine_theme` が空でない文字列（未設定時は "Default"）

---

### [2-12] scm が配列として含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/info.json' -Method Get
$response.info.scm -is [array]
```

**期待結果:**
- `scm` が配列

---

### [2-13] scm の各要素に name と version が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/info.json' -Method Get
$response.info.scm | ForEach-Object { $_.name; $_.version }
```

**期待結果:**
- 各 SCM 要素に `name` と `version` が存在する

---

### [2-14] plugins が配列として含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/info.json' -Method Get
$response.info.plugins -is [array]
```

**期待結果:**
- `plugins` が配列

---

### [2-15] plugins の各要素に id と version が含まれる

**確認方法:**
```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/info.json' -Method Get
$response.info.plugins | ForEach-Object { $_.id; $_.version }
```

**期待結果:**
- 各プラグイン要素に `id` と `version` が存在する

---

### [2-16] XML レスポンスに info タグが含まれる

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/info.xml' -Method Get
$response.Content -match '<info>'
```

**期待結果:**
- レスポンスに `<info>` タグが含まれる

---

### [2-17] XML レスポンスに scm 配列が含まれる

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/info.xml' -Method Get
$response.Content -match '<scm type="array">'
```

**期待結果:**
- レスポンスに `<scm type="array">` が含まれる

---

### [2-18] XML レスポンスに plugins 配列が含まれる

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/info.xml' -Method Get
$response.Content -match '<plugins type="array">'
```

**期待結果:**
- レスポンスに `<plugins type="array">` が含まれる

---

## 3. ブラウザテスト

なし（API のみの機能のため）

---

## テスト実行方法

### Runner テスト・HTTP テスト
Claude が TEST_SPEC.md の仕様に基づいてコマンドを実行し、結果を報告する。
