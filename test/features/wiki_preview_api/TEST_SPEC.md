# Wiki Preview API テスト仕様書

## 概要

Wiki Preview API 機能のテスト仕様。Wiki 記法のテキストを HTML に変換する。
Redmine 本体のプレビュー画面と同じ `textilizable` を使用し、基本記法に加えてマクロ・
`#123` チケットリンク・`[[Wiki ページ]]` リンクも展開する。

## 環境パラメータ

以降の HTTP 例の `{BaseUrl}`・`{ApiKey}`（管理者）・`{UserApiKey}`（限定ユーザ）は実行環境から注入する（プレースホルダの契約は `test/README.md`）。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| Controller | `WikiPreviewsController` |
| ルーティング | `POST /wiki_preview.json`, `POST /wiki_preview.xml` |
| View ファイル | `app/views/wiki_previews/create.api.rsb` |
| 認証 | ログイン必須（本体の `login_required` 設定に関わらず一律。未認証は 401）。`before_action :require_login`（`accept_api_auth :create` と併用で API キー認証も可） |
| レンダリング | `@project` に指定のプロジェクトを入れてから `view_context.textilizable(text, :project => @project)`。マクロ（`ref_issues` の `-p`・`[current_project_id]` など）はビューの `@project` を「このページのプロジェクト」として使うため、Wiki の画面と同じく設定する |
| プロジェクトの利用記録 | `skip_after_action :record_project_usage`。プレビューでは「最近使ったプロジェクト」の並びを変えない |
| フォーマット固定 | textilizable 実行中だけ `lookup_context.formats = [:html]`（ensure で復元）。マクロが描画する HTML パーシャル（`issues/_list` 等）を解決するため。固定しないと JSON/XML 応答の format で `Missing partial` になる |
| スタイルシート解決 | `stylesheet_urls` が表示用 CSS の URL を返す。Redmine 本体のレイアウトと同じ規則（`application.css` を持つテーマが設定されていればテーマ側、なければコアの `application.css`）で `view_context.stylesheet_path` により解決する |

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
    "html": "<h1>見出し</h1>",
    "stylesheets": ["/assets/application-33e739e5.css"]
  }
}
```

### レスポンスフィールド

**wiki_preview:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| html | string | 変換後の HTML |
| stylesheets | string[] | 表示用スタイルシートの URL（相対パス、ダイジェスト・テーマ解決済み） |

### エラーレスポンス

| ステータス | 条件 |
|-----------|------|
| 401 | API キー未指定（認証が必要な環境のみ） |
| 404 | 指定した project_id のプロジェクトが存在しない、または閲覧権限がない |
| 422 | 必須パラメータ text が未指定 |

---

## テスト前提条件

- features 配下の共通事前条件（統合プラグインの無効化）に従う。詳細は `test/README.md`。
- HTTP テストで使うデータ（プロジェクト・チケット・非 admin ユーザーなど）は、「2. HTTP テスト」の用意で作り、後片付けで消す。
  前からある Redmine のデータには頼らない。

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

### [1-6] 利用可能なテーマが存在する（[2-17] の前提確認）

**確認方法:**
```ruby
themes = Redmine::Themes.themes.map(&:id)
puts themes.any? ? "PASS (themes=#{themes.inspect}, current=#{Setting.ui_theme.inspect})" : 'FAIL: no themes available'
```

**期待結果:**
- テーマが 1 件以上存在する（標準では `alternate` / `classic`）。[2-17] ではこのいずれかを使用する
- 現在のテーマ設定値も記録し、[2-17] の復元で使用する

---

## 2. HTTP テスト

**実行方法:**
PowerShell で各エンドポイントに POST リクエストを送信する。API キー認証が必要。
JSON ボディは `ConvertTo-Json` で生成し、`-ContentType 'application/json'` を指定する。

**用意（HTTP テストの前に 1 回）:**
試験に使うデータを Runner で作る（前回の残りがあれば先に消す）。
- このページのプロジェクト（チケット 2 件・wiki あり）と、その外のプロジェクト（チケット 1 件）
- 非 admin ユーザー（API キー付き）と、その人がメンバーでない非公開プロジェクト

最後の行の値を、各試験の `{ProjectId}`・`{ProjectIdentifier}`・`{IssueId}`・`{UserApiKey}`・`{PrivateProjectId}` に入れる。

```ruby
admin = User.find(1)
User.current = admin
# 前回の残りを消す
Project.where('identifier LIKE ?', 'wpv-%').order(lft: :desc).each(&:destroy)
User.where('login LIKE ?', 'wpv_%').each(&:destroy)
sfx = SecureRandom.hex(3)
tracker = Tracker.first
mk_project = ->(name, modules) {
  pr = Project.new(name: "WPV_#{name}_#{sfx}", identifier: "wpv-#{name}-#{sfx}", is_public: false)
  pr.enabled_module_names = modules
  pr.trackers = [tracker]
  pr.save!
  pr
}
mk_issue = ->(pr, subject) {
  Issue.create!(project: pr, tracker: tracker, subject: "WPV_#{subject}_#{sfx}", author: admin,
                status: IssueStatus.first, priority: IssuePriority.default || IssuePriority.active.first)
}
page = mk_project.call('page', %w[issue_tracking wiki])
issue = mk_issue.call(page, 'a')
mk_issue.call(page, 'b')
other = mk_project.call('other', %w[issue_tracking])
mk_issue.call(other, 'c')
private_project = mk_project.call('private', %w[issue_tracking])
user = User.new(login: "wpv_user_#{sfx}", firstname: 'WPV', lastname: 'User', mail: "wpv_user_#{sfx}@example.com", status: User::STATUS_ACTIVE)
user.password = user.password_confirmation = 'password123'
user.save!
token = Token.create!(user: user, action: 'api')
puts({ ProjectId: page.id, ProjectIdentifier: page.identifier, IssueId: issue.id, UserApiKey: token.value, PrivateProjectId: private_project.id }.to_json)
```

**後片付け（HTTP テストのあとに 1 回）:**

```ruby
User.current = User.find(1)
Project.where('identifier LIKE ?', 'wpv-%').order(lft: :desc).each(&:destroy)
User.where('login LIKE ?', 'wpv_%').each(&:destroy)
puts 'cleaned'
```

### [2-0a] 未認証（匿名）は 401 で拒否される（login_required 無効環境でも）

**確認方法:**
```powershell
$body = @{ text = 'h1. Test' } | ConvertTo-Json
try {
  Invoke-WebRequest -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json'
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
$body = @{ text = 'h1. Test'; project_id = {ProjectId} } | ConvertTo-Json
$response = Invoke-WebRequest -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.StatusCode
```

**期待結果:**
- ステータスコード 200

---

### [2-2] XML 形式でアクセス可能

**確認方法:**
```powershell
$body = @{ text = 'h1. Test'; project_id = {ProjectId} } | ConvertTo-Json
$response = Invoke-WebRequest -Uri '{BaseUrl}/wiki_preview.xml' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.StatusCode
```

**期待結果:**
- ステータスコード 200

---

### [2-3] wiki_preview.html フィールドが含まれる

**確認方法:**
```powershell
$body = @{ text = 'h1. Test'; project_id = {ProjectId} } | ConvertTo-Json
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
$body = @{ text = '# Heading'; project_id = {ProjectId} } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.wiki_preview.html -match '<h1'
```

**期待結果:**
- HTML に `<h1` が含まれる（見出しアンカー付きで `<h1 ...>` となるため `<h1` で判定）

---

### [2-5] リスト記法が HTML 化される

**確認方法:**
```powershell
$body = @{ text = "* Item 1`n* Item 2"; project_id = {ProjectId} } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.wiki_preview.html -match '<li>'
```

**期待結果:**
- HTML に `<li>` が含まれる

---

### [2-6] project コンテキストでチケットリンクが展開される

**前提条件:** 用意で作ったチケット（`{IssueId}`）とプロジェクト（`{ProjectId}`）を使う。

**確認方法:**
```powershell
$body = @{ text = 'ref #{IssueId}'; project_id = {ProjectId} } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.wiki_preview.html -match 'class="issue'
```

**期待結果:**
- `#{IssueId}` が `<a class="issue" ...>` リンクに展開される

---

### [2-7] 空文字テキストは空の HTML を返す

**確認方法:**
```powershell
$body = @{ text = ''; project_id = {ProjectId} } | ConvertTo-Json
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
$body = @{ project_id = {ProjectId} } | ConvertTo-Json
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
$body = @{ text = 'h1. Test'; project_id = {ProjectId} } | ConvertTo-Json
$response = Invoke-WebRequest -Uri '{BaseUrl}/wiki_preview.xml' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
($response.Content -match '<wiki_preview>') -and ($response.Content -match '<html>')
```

**期待結果:**
- レスポンスに `<wiki_preview>` と `<html>` タグが含まれる

---

### [2-12] ref_issues マクロが展開される（HTML パーシャル描画）

`ref_issues` は内部で `issues/_list` パーシャルを描画する。format 固定が効いていれば
マクロが展開され、効いていないと `Missing partial` のエラー表示になる。

**前提条件:** `redmine_studio_plugin` 有効・用意で作ったプロジェクト（`{ProjectIdentifier}`）にチケットあり。

**確認方法:**
```powershell
$body = @{ text = '{{ref_issues(-p={ProjectIdentifier}, -n=3, id, subject)}}'; project_id = {ProjectId} } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
($response.wiki_preview.html -match '/issues/') -and ($response.wiki_preview.html -notmatch 'Error executing')
```

**期待結果:**
- チケット一覧が展開され `/issues/` リンクを含む（`Error executing` を含まない）

---

### [2-13] Wiki リンク `[[ページ]]` が展開される

**前提条件:** 用意で作ったプロジェクト（`{ProjectId}`）に wiki モジュールが有効。

**確認方法:**
```powershell
$body = @{ text = '[[TestLink]]'; project_id = {ProjectId} } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.wiki_preview.html -match 'class="wiki-page'
```

**期待結果:**
- `[[TestLink]]` が `<a ... class="wiki-page ...">` に展開される（存在しないページは `wiki-page new`）

---

### [2-14] 非 admin ユーザーの API キーでも利用できる

**前提条件:** 用意で作った非 admin ユーザー（API キー `{UserApiKey}`）を使う。

**確認方法:**
```powershell
# {UserApiKey} = 用意で作った非 admin ユーザーの API キー
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

**前提条件:** 用意で作った非 admin ユーザー（`{UserApiKey}`）と非公開プロジェクト（`{PrivateProjectId}`）を使う。
そのユーザーは当該プロジェクトの非メンバー。

**確認方法:**
```powershell
# {UserApiKey} = 用意で作った非 admin ユーザーの API キー、{PrivateProjectId} = 用意で作った非公開プロジェクトの ID
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

### [2-16] stylesheets フィールドにコア CSS の URL が含まれる

**前提条件:** UI テーマが未設定（既定）であること。

**確認方法:**
```powershell
$body = @{ text = '* item' } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
($response.wiki_preview.stylesheets.Count -ge 1) -and ($response.wiki_preview.stylesheets[0] -match 'application[^/]*\.css')
```

**期待結果:**
- `stylesheets` が 1 件以上の配列で、`application*.css`（ダイジェスト付き可）の URL を含む

---

### [2-17] テーマ設定時はテーマの CSS URL を返す

**確認方法:**
Runner でテーマを設定 → HTTP で確認 → Runner で復元する。

```bash
# 1. テーマを設定（環境に存在するテーマ ID を使用。[1-6] 参照）
docker exec {Container} bash -c "cd /usr/src/redmine && bundle exec rails runner 'Setting.ui_theme = %(classic)'"
```

```powershell
# 2. stylesheets がテーマのパスを含むことを確認
$body = @{ text = '* item' } | ConvertTo-Json
$response = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
$response.wiki_preview.stylesheets[0] -match 'themes/classic'
```

```bash
# 3. テーマを復元（元の値に戻す。既定は空文字）
docker exec {Container} bash -c "cd /usr/src/redmine && bundle exec rails runner 'Setting.ui_theme = %()'"
```

**期待結果:**
- 手順 2 で `stylesheets[0]` に `themes/classic` が含まれる
- 復元後は [2-16] と同じくコア CSS の URL に戻る

---

### [2-18] XML レスポンスに stylesheets 配列が含まれる

**確認方法:**
```powershell
$body = @{ text = '* item' } | ConvertTo-Json
$response = Invoke-WebRequest -Uri '{BaseUrl}/wiki_preview.xml' -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
($response.Content -match '<stylesheets type="array">') -and ($response.Content -match '<stylesheet>[^<]*application[^<]*\.css[^<]*</stylesheet>')
```

**期待結果:**
- `<stylesheets type="array">` 配下に `<stylesheet>` 要素として CSS の URL が含まれる
- URL の形式は環境により異なる（Redmine 6.x はダイジェスト付き `application-xxxx.css`、5.x はクエリ付き `application.css?タイムスタンプ`）ため、`.css` の後のクエリ文字列を許容して判定する

---

### [2-19] プロジェクト名なしの `-p` が project_id のプロジェクトに絞られる

Wiki に貼ったときの `{{ref_issues(-p)}}` は、貼ったページのプロジェクトに絞られる。プレビューでも
`project_id` のプロジェクトを「このページのプロジェクト」として同じ結果になることを確認する。

**前提条件:** 用意で作ったプロジェクト（`{ProjectId}`）と、その外のプロジェクトのチケットを使う（外にチケットが無いと、絞り込みの有無で件数が変わらず判定できない）。

**確認方法:**
```powershell
$h = @{'X-Redmine-API-Key'='{ApiKey}'}
$count = {
  param($text)
  $body = @{ text = $text; project_id = {ProjectId} } | ConvertTo-Json
  $r = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers $h
  $r.wiki_preview.html -replace '<[^>]+>', '' -replace '\s', ''
}
$current = & $count '{{ref_issues(-p, -c)}}'
$named   = & $count '{{ref_issues(-p={ProjectIdentifier}, -c)}}'
"current=$current named=$named"
($current -match '^\d+$') -and ($current -eq $named)
```

**期待結果:**
- `-p`（プロジェクト名なし）の件数が `-p={ProjectIdentifier}` の件数（2）と同じ（すべてのプロジェクトの件数にならない）

---

### [2-20] `[current_project_id]` が project_id のプロジェクトの番号になる

**前提条件:** [2-19] と同じ。

**確認方法:**
```powershell
$h = @{'X-Redmine-API-Key'='{ApiKey}'}
$body = @{ text = '{{ref_issues(-f:project_id=[current_project_id], -c)}}'; project_id = {ProjectId} } | ConvertTo-Json
$r = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers $h
$current = $r.wiki_preview.html -replace '<[^>]+>', '' -replace '\s', ''
$body = @{ text = '{{ref_issues(-f:project_id={ProjectId}, -c)}}'; project_id = {ProjectId} } | ConvertTo-Json
$r = Invoke-RestMethod -Uri '{BaseUrl}/wiki_preview.json' -Method Post -Body $body -ContentType 'application/json' -Headers $h
$named = $r.wiki_preview.html -replace '<[^>]+>', '' -replace '\s', ''
"current=$current named=$named"
($current -match '^\d+$') -and ($current -eq $named)
```

**期待結果:**
- エラー（`Error executing`）にならず、件数がプロジェクトの番号をじかに書いた `-f:project_id={ProjectId}` の件数と同じ（`-p` と違い、子プロジェクトのチケットは含まない）

---

## 3. ブラウザテスト

なし（API のみの機能のため）

---

## テスト実行方法

### Runner テスト・HTTP テスト
Claude が TEST_SPEC.md の仕様に基づいてコマンドを実行し、結果を報告する。
