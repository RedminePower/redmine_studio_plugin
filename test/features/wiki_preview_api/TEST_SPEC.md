# Wiki Preview API テスト仕様書

## 概要

Wiki Preview API 機能のテスト仕様。Wiki 記法のテキストを HTML に変換する。
Redmine 本体のプレビュー画面と同じ `textilizable` を使用し、基本記法に加えてマクロ・
`#123` チケットリンク・`[[Wiki ページ]]` リンクも展開する。

## 環境パラメータ

| パラメータ | 判定方法 | 本環境（redmine_6.1.1） |
|-----------|----------|------------------------|
| Container | TEST_SPEC.md のパスから自動判定 | `redmine_6.1.1` |
| BaseUrl | `3000 + メジャー×10 + マイナー` | `http://localhost:3061` |

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| Controller | `WikiPreviewsController` |
| ルーティング | `POST /wiki_preview.json`, `POST /wiki_preview.xml` |
| View ファイル | `app/views/wiki_previews/create.api.rsb` |
| 認証 | API キー必須（未認証で 401） |
| レンダリング | `view_context.textilizable(text, :project => project)` |
| フォーマット固定 | textilizable 実行中だけ `lookup_context.formats = [:html]`（ensure で復元）。マクロが描画する HTML パーシャル（`issues/_list` 等）を解決するため。固定しないと JSON/XML 応答の format で `Missing partial` になる |

### パラメータ

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| text | string | ○ | 変換する Wiki 記法のテキスト（空文字も可） |
| project_id | int | | マクロ・`#123`・`[[Wiki]]` リンク解決用のプロジェクトコンテキスト（任意） |

### レスポンス形式

API は JSON と XML の両方をサポートする。

| 拡張子 | Content-Type |
|--------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

### API レスポンス構造

**POST `/wiki_preview.json`**（body: `{ "text": "h1. 見出し", "project_id": 1 }`）:
```json
{
  "wiki_preview": {
    "html": "<h1>見出し</h1>"
  }
}
```

### レスポンスフィールド

**wiki_preview:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| html | string | 変換後の HTML |

### エラーレスポンス

| ステータス | 条件 |
|-----------|------|
| 401 | API キー未指定（認証が必要な環境のみ） |
| 404 | 指定した project_id のプロジェクトが存在しない、または閲覧権限がない |
| 422 | 必須パラメータ text が未指定 |

---

## テスト前提条件

- features 配下の共通事前条件（統合プラグインの無効化）に従う。詳細は `test/README.md`。
- HTTP テストの一部はテキスト変換結果を検証する。`#NNN` チケットリンクの確認には
  **閲覧可能なチケットが 1 件以上存在すること**が前提（既定では `#1` と `project_id=1` を使用。
  環境に存在するチケット ID／プロジェクト ID に合わせて調整する）。
- `ref_issues` マクロ展開（[2-12]）には **`redmine_studio_plugin` が有効**で、対象プロジェクト
  （既定 `test-plugin`）に**チケットと wiki モジュール**があること。
- 可視性 404（[2-15]）の検証には、以下のインフラデータを作成する（命名 `wikipreview_*`／再利用・削除しない）。
  Runner で作成する（`rails runner`）:

  ```ruby
  # 非 admin ユーザー（API キー付き）
  login = 'wikipreview_user'
  user = User.find_by(login: login) || begin
    u = User.new(login: login, firstname: 'WikiPreview', lastname: 'Tester', mail: 'wikipreview_tester@example.com')
    u.admin = false; u.status = User::STATUS_ACTIVE
    u.password = 'password123'; u.password_confirmation = 'password123'
    u.must_change_passwd = false; u.save; u
  end
  token = Token.find_by(user_id: user.id, action: 'api') || Token.create(user: user, action: 'api')
  # 非公開プロジェクト（user は非メンバー → 閲覧不可）
  proj = Project.find_by(identifier: 'wikipreview-private') ||
         Project.create(name: 'WikiPreview Private', identifier: 'wikipreview-private', is_public: false)
  puts "API_KEY=#{token.value}"            # 非 admin ユーザーの API キー
  puts "PRIVATE_PROJECT_ID=#{proj.id}"     # 閲覧不可プロジェクト ID
  ```

---

## 1. Runner テスト

**実行方法:**
```bash
docker exec {Container} bash -c "cd /usr/src/redmine && bundle exec rails runner '{code}'"
```

6 件以上のため、1 スクリプトにまとめてバッチ実行する（各テストを begin/rescue で隔離）。

### [1-1] WikiPreviewsController が定義されている

**確認方法:**
```ruby
puts defined?(WikiPreviewsController) ? 'PASS' : 'FAIL: WikiPreviewsController not defined'
```

**期待結果:**
- `WikiPreviewsController` が定義されている

---

### [1-2] ルーティングが設定されている

**確認方法:**
```ruby
# verb の型は Rails バージョン差があるため defaults で判定（wiki_previews ルートは1本のみ）
route = Rails.application.routes.routes.any? do |r|
  r.defaults[:controller] == 'wiki_previews' && r.defaults[:action] == 'create'
end
puts route ? 'PASS' : 'FAIL: wiki_previews#create route not found'
```

**期待結果:**
- `wiki_previews#create` ルートが存在する

---

### [1-3] View ファイルが存在する

**確認方法:**
```ruby
plugin_path = Rails.root.join('plugins', 'redmine_studio_plugin')
view_file = plugin_path.join('app', 'views', 'wiki_previews', 'create.api.rsb')
puts File.exist?(view_file) ? 'PASS' : 'FAIL: create.api.rsb not found'
```

**期待結果:**
- `app/views/wiki_previews/create.api.rsb` が存在する

---

### [1-4] accept_api_auth が設定されている

**確認方法:**
```ruby
result = WikiPreviewsController.accept_api_auth_actions.include?(:create)
puts result ? 'PASS' : 'FAIL: accept_api_auth not set for :create'
```

**期待結果:**
- `create` アクションで API キー認証が有効

---

### [1-5] 基本記法がサーバ書式設定で HTML 化される

`textilizable` のリンク/URL 展開はリクエストコンテキストを要するため runner では検証しない
（HTTP テストでカバー）。ここでは基本記法のフォーマッタ選択（`Setting.text_formatting` 追従）を確認する。

**確認方法:**
```ruby
fmt = Setting.text_formatting
# textile は "h1." 記法、markdown/common_mark は "# " 記法で見出しになる
sample = (fmt == 'textile') ? 'h1. Heading' : '# Heading'
html = Redmine::WikiFormatting.to_html(fmt, sample)
puts html.include?('<h1') ? "PASS (fmt=#{fmt})" : "FAIL: <h1> not found (fmt=#{fmt}): #{html.inspect}"
```

**期待結果:**
- 出力に `<h1` が含まれる（サーバの書式設定に従って基本記法が HTML 化される）

> 補足: マクロ・`#123` リンク・`[[Wiki]]` リンクの展開と空文字の挙動は、実リクエストを通る
> HTTP テスト（[2-4]〜[2-8]）で検証する。

---

## 2. HTTP テスト

**実行方法:**
PowerShell で各エンドポイントに POST リクエストを送信する。API キー認証が必要。
JSON ボディは `ConvertTo-Json` で生成し、`-ContentType 'application/json'` を指定する。

### [2-1] JSON 形式でアクセス可能

**確認方法:**
```powershell
$body = @{ text = 'h1. Test'; project_id = 1 } | ConvertTo-Json
$response = Invoke-WebRequest -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.StatusCode
```

**期待結果:**
- ステータスコード 200

---

### [2-2] XML 形式でアクセス可能

**確認方法:**
```powershell
$body = @{ text = 'h1. Test'; project_id = 1 } | ConvertTo-Json
$response = Invoke-WebRequest -Uri '{BaseUrl}/wiki_preview.xml' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.StatusCode
```

**期待結果:**
- ステータスコード 200

---

### [2-3] wiki_preview.html フィールドが含まれる

**確認方法:**
```powershell
$body = @{ text = 'h1. Test'; project_id = 1 } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.wiki_preview.html -ne $null
```

**期待結果:**
- `wiki_preview.html` が存在する

---

### [2-4] 基本記法（見出し）が HTML 化される

> 記法はサーバの書式設定に合わせる（本環境は common_mark のため `# 見出し`。textile 環境なら `h1. 見出し`）。

**確認方法:**
```powershell
$body = @{ text = '# Heading'; project_id = 1 } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.wiki_preview.html -match '<h1'
```

**期待結果:**
- HTML に `<h1` が含まれる（見出しアンカー付きで `<h1 ...>` となるため `<h1` で判定）

---

### [2-5] リスト記法が HTML 化される

**確認方法:**
```powershell
$body = @{ text = "* Item 1`n* Item 2"; project_id = 1 } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.wiki_preview.html -match '<li>'
```

**期待結果:**
- HTML に `<li>` が含まれる

---

### [2-6] project コンテキストでチケットリンクが展開される

**前提条件:** 閲覧可能なチケットが存在すること（既定 `#1`／`project_id=1`。環境に合わせて調整）。

**確認方法:**
```powershell
$body = @{ text = 'ref #1'; project_id = 1 } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.wiki_preview.html -match 'class="issue'
```

**期待結果:**
- `#1` が `<a class="issue" ...>` リンクに展開される

---

### [2-7] 空文字テキストは空の HTML を返す

**確認方法:**
```powershell
$body = @{ text = ''; project_id = 1 } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.wiki_preview.html -eq ''
```

**期待結果:**
- `html` が空文字（ステータス 200）

---

### [2-8] project_id なしでもレンダリングできる

**確認方法:**
```powershell
$body = @{ text = '# Heading' } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.wiki_preview.html -match '<h1'
```

**期待結果:**
- project_id 未指定でも基本記法が HTML 化される（`<h1` が含まれる）

---

### [2-9] text が未指定だと 422 を返す

**確認方法:**
```powershell
$body = @{ project_id = 1 } | ConvertTo-Json
try {
    Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
} catch {
    $_.Exception.Response.StatusCode
}
```

**期待結果:**
- ステータスコード 422 Unprocessable Entity

---

### [2-10] 存在しない project_id で 404 を返す

**確認方法:**
```powershell
$body = @{ text = 'h1. Test'; project_id = 999999 } | ConvertTo-Json
try {
    Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
} catch {
    $_.Exception.Response.StatusCode
}
```

**期待結果:**
- ステータスコード 404 Not Found

---

### [2-11] XML レスポンスに wiki_preview / html タグが含まれる

**確認方法:**
```powershell
$body = @{ text = 'h1. Test'; project_id = 1 } | ConvertTo-Json
$response = Invoke-WebRequest -Uri '{BaseUrl}/wiki_preview.xml' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
($response.Content -match '<wiki_preview>') -and ($response.Content -match '<html>')
```

**期待結果:**
- レスポンスに `<wiki_preview>` と `<html>` タグが含まれる

---

### [2-12] ref_issues マクロが展開される（HTML パーシャル描画）

`ref_issues` は内部で `issues/_list` パーシャルを描画する。format 固定が効いていれば
マクロが展開され、効いていないと `Missing partial` のエラー表示になる。

**前提条件:** `redmine_studio_plugin` 有効・対象プロジェクト（`test-plugin`）にチケットあり。

**確認方法:**
```powershell
$body = @{ text = '{{ref_issues(-p=test-plugin, -n=3, id, subject)}}'; project_id = 1 } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
($response.wiki_preview.html -match '/issues/') -and ($response.wiki_preview.html -notmatch 'Error executing')
```

**期待結果:**
- チケット一覧が展開され `/issues/` リンクを含む（`Error executing` を含まない）

---

### [2-13] Wiki リンク `[[ページ]]` が展開される

**前提条件:** 対象プロジェクト（`project_id=1`）に wiki モジュールが有効。

**確認方法:**
```powershell
$body = @{ text = '[[TestLink]]'; project_id = 1 } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.wiki_preview.html -match 'class="wiki-page'
```

**期待結果:**
- `[[TestLink]]` が `<a ... class="wiki-page ...">` に展開される（存在しないページは `wiki-page new`）

---

### [2-14] 非 admin ユーザーの API キーでも利用できる

**前提条件:** テスト前提条件の `wikipreview_user`（非 admin・API キー）を作成済み。

**確認方法:**
```powershell
# {UserApiKey} = wikipreview_user の API キー
$body = @{ text = '# Hi' } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{UserApiKey}'}
$response.wiki_preview.html -match '<h1'
```

**期待結果:**
- 非 admin トークンでも 200・正常にレンダリングされる（トークン有効性の確認）

---

### [2-15] 閲覧権限のないプロジェクトを指定すると 404（可視性）

`Project.visible.find` により、存在しても閲覧不可なプロジェクトは 404 になることを確認する。
（[2-10] は「存在しない ID」、本ケースは「存在するが閲覧不可」を検証）

**前提条件:** テスト前提条件の `wikipreview_user`（非 admin）と非公開 `wikipreview-private`
（`{PrivateProjectId}`）を作成済み。`wikipreview_user` は当該プロジェクトの非メンバー。

**確認方法:**
```powershell
# {UserApiKey} = wikipreview_user の API キー、{PrivateProjectId} = wikipreview-private の ID
$body = @{ text = '# Hi'; project_id = {PrivateProjectId} } | ConvertTo-Json
try {
    Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{UserApiKey}'}
} catch {
    $_.Exception.Response.StatusCode
}
```

**期待結果:**
- ステータスコード 404 Not Found（admin の API キーで同じ project_id を叩くと 200 になる＝存在はする）

---

## 3. ブラウザテスト

なし（API のみの機能のため）

---

## テスト実行方法

### Runner テスト・HTTP テスト
Claude が TEST_SPEC.md の仕様に基づいてコマンドを実行し、結果を報告する。
