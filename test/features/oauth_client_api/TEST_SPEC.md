# OAuth クライアント情報 API テスト仕様書

## 概要

ブラウザサインイン（OAuth2.0 + PKCE）の開始に必要な `client_id` と権限範囲（scopes）を、
認証情報なしで Redmine Studio に伝える窓口 `GET /oauth_client` のテスト仕様。

あわせて、サインイン用 OAuth アプリを Redmine 起動のたびに自己修復登録する仕組み
（`AppRegistrar`）と、権限範囲を定義する `ScopeProvider` を検証する。

さらに、前段 Basic 認証ゲートの裏でトークン取得 `POST /oauth/token` を成立させるための
クライアント資格情報パッチ（`DoorkeeperClientCredentialsPatch`）を検証する。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| Controller | `OauthClientController` |
| ルーティング | `GET /oauth_client.json`, `GET /oauth_client.xml` |
| View ファイル | `app/views/oauth_client/show.api.rsb` |
| 登録処理 | `RedmineStudioPlugin::OauthClient::AppRegistrar`（`init.rb` の `after_initialize` から起動時に呼ぶ） |
| スコープ定義 | `RedmineStudioPlugin::OauthClient::ScopeProvider` |
| クライアント資格情報パッチ | `RedmineStudioPlugin::OauthClient::DoorkeeperClientCredentialsPatch`（`Doorkeeper::OAuth::Client::Credentials` の特異クラスに `prepend`） |
| 認証 | **匿名アクセス可（本体の `login_required` 設定に関わらず到達可能）**。追加 API 中これだけが匿名の例外。`skip_before_action :check_if_login_required` |

### 匿名を許可する理由

サインインを開始する前段では、まだアクセストークンが無い。その状態で `client_id` を取得する必要があるため、
この窓口だけは認証情報なしで到達できるようにする。返すのは `client_id` と `scopes` のみに限定する
（Redmine バージョン・環境情報・プラグイン一覧などは返さない）。

### 3 状態の表現

アプリ側の可否判定は「`client_id` が取れたか」の一点に集約する。

| 状態 | 応答 | アプリの解釈 |
|---|---|---|
| サインイン可能（Redmine 6.1 以上 かつ 登録済み） | `200` `{ "oauth_client": { "client_id": "...", "scopes": [...] } }` | client_id あり → 可能 |
| 対応版プラグインは在るが環境未対応（6.1 未満／未登録） | `200` `{"oauth_client":{}}`（client_id 無し） | 届いたが client_id 無し → プラグイン✅ / Redmine❌ |
| プラグイン未導入・旧版 | `404`（ルート自体が無い） | 窓口が無い → プラグイン❌ |

### レスポンス形式

API は JSON と XML の両方をサポートする。

| 拡張子 | Content-Type |
|--------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

### API レスポンス構造

**GET `/oauth_client.json`（登録済み）:**
```json
{
  "oauth_client": {
    "client_id": "dZ_kPCxn3ilJ7HH36iV3DhLG9e2DX645xCIYGW-lHjc",
    "scopes": ["add_issues", "edit_issues", "view_issues", "..."]
  }
}
```

**GET `/oauth_client.json`（未登録・非対応）:**
```json
{"oauth_client":{}}
```
`oauth_client` ルート要素は常に出力し（XML デシリアライズを壊さないため）、中身（client_id / scopes）は登録済みのときだけ詰める。

### レスポンスフィールド

| フィールド | 型 | 説明 |
|-----------|-----|------|
| client_id | string | サインイン用 OAuth アプリの client_id（Doorkeeper の uid） |
| scopes | array | 要求する権限範囲（Redmine の権限名の配列） |

### 権限範囲（scopes）の方針

| 区分 | 内容 |
|------|------|
| 閲覧系 | `read` フラグの付いた権限を広めに許可。ただし破壊的操作（`close_project` / `delete_project`）は `read` 扱いでも除外 |
| 変更系 | アプリが実際に使う操作のみ（`add_issues` / `edit_issues` / `edit_own_issues` / `add_issue_notes` / `log_time` / `edit_time_entries` / `edit_own_time_entries`） |
| 管理系 | `admin` は絶対に含めない |

トークンに載る権限と利用者本人のロール権限は AND で効くため、ここは「アプリが要求してよい上限」を最小権限で定義する。

### 前段 Basic ゲート下でのトークン取得（クライアント資格情報パッチ）

前段プロキシの Basic 認証を通すため、クライアントは `Authorization: Basic` にゲートの資格情報を載せる。
ところが Doorkeeper はこのヘッダを OAuth クライアント資格情報（`client_id:client_secret`）として解釈する
（`client_credentials_methods` の既定は `from_basic` が `from_params` より優先）。その結果、ゲートの資格情報では
該当クライアントが見つからず `POST /oauth/token` が `invalid_client`（401）で失敗する。

`DoorkeeperClientCredentialsPatch` は `Doorkeeper::OAuth::Client::Credentials.from_basic` を差し替え、
Basic のユーザー名が「登録済み OAuth アプリの uid」でない場合に限りクライアント資格情報として無視して `nil` を返す。
これにより `from_params`（リクエストボディの `client_id`）へフォールバックし、公開クライアント（PKCE）として
トークン取得が成立する。登録済みクライアントの Basic 認証は従来どおり尊重する（`nil` を返さない）。

| 入力 | `from_basic` の戻り | 効果 |
|------|--------------------|------|
| ゲートの資格情報（未登録 uid）の Basic | `nil` | ボディ `client_id` へフォールバック |
| 登録済みアプリ uid の Basic | `[uid, secret]`（従来どおり） | 正規のクライアント認証として尊重 |
| Basic ヘッダ無し | `nil`（従来どおり） | 影響なし |

補足: doorkeeper 5.8.2 では `from_basic` は `[uid, secret]` の配列を返す（`Credentials` 構造体ではない）。
パッチは戻り値の先頭要素（uid）だけを見て判定するため、この差異の影響を受けない。

---

## テストの版適用（Doorkeeper 依存）

サインイン機能は OAuth2 プロバイダ（Doorkeeper）に依存し、Doorkeeper は本体では **Redmine 6.1** で導入された。
そのためテストは版で適用範囲を分ける（実行時に `Redmine::VERSION` で判定し、対象外はスキップする）。

| 区分 | 対象ケース | 適用版 |
|------|-----------|--------|
| 全版共通 | [1-1]〜[1-5] / [1-9] / [2-0] / [2-1] | 全版 |
| Doorkeeper 依存（登録・patch・トークン） | [1-6]〜[1-8] / [1-10]〜[1-14] / [2-2]〜[2-7] | **6.1 以上のみ**（6.1 未満は Doorkeeper 無しでスキップ） |
| Doorkeeper なしの挙動（ロード・degradation） | [1-15]〜[1-16] / [2-8] | **6.1 未満のみ** |

6.1 未満では、init.rb の Doorkeeper patch 適用が `defined?(Doorkeeper::OAuth::Client::Credentials)` でガードされ、
サインイン用 patch ごとスキップされる。プラグイン自体は正常ロードされ、`oauth_client` は空応答を返す。

---

## 1. Runner テスト

**実行方法:**
```bash
docker exec {Container} bash -c "cd /usr/src/redmine && bundle exec rails runner '{code}'"
```

### [1-1] OauthClientController が定義されている

```ruby
puts defined?(OauthClientController) ? 'PASS' : 'FAIL: OauthClientController not defined'
```

**期待結果:** `OauthClientController` が定義されている

---

### [1-2] ルーティングが設定されている

```ruby
ok = Rails.application.routes.routes.any? { |r| r.defaults[:controller] == 'oauth_client' && r.defaults[:action] == 'show' }
puts ok ? 'PASS' : 'FAIL: oauth_client#show route not found'
```

**期待結果:** `oauth_client#show` ルートが存在する

---

### [1-3] View ファイルが存在する

```ruby
plugin_path = Rails.root.join('plugins', 'redmine_studio_plugin')
view_file = plugin_path.join('app', 'views', 'oauth_client', 'show.api.rsb')
puts File.exist?(view_file) ? 'PASS' : 'FAIL: show.api.rsb not found'
```

**期待結果:** `app/views/oauth_client/show.api.rsb` が存在する

---

### [1-4] スコープに admin・破壊的権限が含まれない

```ruby
names = RedmineStudioPlugin::OauthClient::ScopeProvider.scope_names
bad = [:admin, :close_project, :delete_project] & names
puts bad.empty? ? 'PASS' : "FAIL: forbidden scopes present: #{bad.join(', ')}"
```

**期待結果:** `admin` / `close_project` / `delete_project` を含まない

---

### [1-5] スコープに必要な変更系が含まれる

```ruby
names = RedmineStudioPlugin::OauthClient::ScopeProvider.scope_names
required = [:add_issues, :edit_issues, :edit_own_issues, :add_issue_notes,
            :log_time, :edit_time_entries, :edit_own_time_entries, :view_issues]
missing = required - names
puts missing.empty? ? 'PASS' : "FAIL: missing scopes: #{missing.join(', ')}"
```

**期待結果:** 変更系の必須スコープと `view_issues` を含む

---

> **[1-6]〜[1-8] は Doorkeeper 依存（自己修復登録）。6.1 以上のみ実行し、6.1 未満（Doorkeeper なし）ではスキップする。**

### [1-6] 自己修復登録が公開クライアントを作成する

```ruby
Doorkeeper::Application.where(name: 'Redmine Studio').destroy_all
RedmineStudioPlugin::OauthClient::AppRegistrar.ensure_registered
app = Doorkeeper::Application.find_by(name: 'Redmine Studio')
ok = app && app.confidential == false && app.redirect_uri == 'http://127.0.0.1/' && app.uid.present?
puts ok ? 'PASS' : "FAIL: app=#{app.inspect}"
```

**期待結果:** `confidential=false`（公開クライアント）・`redirect_uri=http://127.0.0.1/`・`uid` 付きで登録される

---

### [1-7] 何度呼んでも重複登録しない（冪等）

```ruby
3.times { RedmineStudioPlugin::OauthClient::AppRegistrar.ensure_registered }
count = Doorkeeper::Application.where(name: 'Redmine Studio').count
puts count == 1 ? 'PASS' : "FAIL: count=#{count}"
```

**期待結果:** 登録は常に 1 件（起動のたびに呼んでも増えない）

---

### [1-8] スコープ定義のズレを追従する

```ruby
app = Doorkeeper::Application.find_by(name: 'Redmine Studio')
app.update!(scopes: 'view_issues')
RedmineStudioPlugin::OauthClient::AppRegistrar.ensure_registered
expected = RedmineStudioPlugin::OauthClient::ScopeProvider.scope_names.map(&:to_s).sort
ok = app.reload.scopes.all.sort == expected
puts ok ? 'PASS' : "FAIL: scopes=#{app.scopes.all.sort}"
```

**期待結果:** 登録済みアプリのスコープが定義と食い違っていたら定義に合わせて更新される

---

### [1-9] signin_supported? がバージョンと一致する（全版共通）

```ruby
sup = RedmineStudioPlugin::OauthClient::AppRegistrar.signin_supported?
exp = Redmine::VERSION::MAJOR > 6 || (Redmine::VERSION::MAJOR == 6 && Redmine::VERSION::MINOR >= 1)
puts sup == exp ? 'PASS' : "FAIL: signin_supported?=#{sup} expected=#{exp}"
```

**期待結果:** `signin_supported?` が版と一致する（Redmine 6.1 以上で `true`、6.1 未満で `false`）

---

> **[1-10]〜[1-14] は Doorkeeper 依存（クライアント資格情報 patch）。6.1 以上のみ実行し、6.1 未満（Doorkeeper なし）ではスキップする。**

### [1-10] クライアント資格情報パッチが定義されている

```ruby
puts defined?(RedmineStudioPlugin::OauthClient::DoorkeeperClientCredentialsPatch) ? 'PASS' : 'FAIL: patch not defined'
```

**期待結果:** `DoorkeeperClientCredentialsPatch` が定義されている

---

### [1-11] パッチが Credentials の特異クラスに適用されている

```ruby
ok = Doorkeeper::OAuth::Client::Credentials.singleton_class.ancestors.include?(RedmineStudioPlugin::OauthClient::DoorkeeperClientCredentialsPatch)
puts ok ? 'PASS' : 'FAIL: patch not prepended to Credentials singleton class'
```

**期待結果:** `Doorkeeper::OAuth::Client::Credentials` の特異クラスにパッチが `prepend` されている

---

### [1-12] ゲートの資格情報（未登録 uid）の Basic は無視される

```ruby
require 'base64'
req = Struct.new(:authorization).new('Basic ' + Base64.strict_encode64('user:password'))
creds = Doorkeeper::OAuth::Client::Credentials.from_basic(req)
puts creds.nil? ? 'PASS' : "FAIL: #{creds.inspect}"
```

**期待結果:** 未登録 uid（前段ゲートの資格情報）の Basic では `nil`（＝ボディ `client_id` へフォールバックさせる）

---

### [1-13] 登録済みアプリ uid の Basic は従来どおり尊重される

```ruby
require 'base64'
app = Doorkeeper::Application.find_by(name: 'Redmine Studio')
req = Struct.new(:authorization).new('Basic ' + Base64.strict_encode64("#{app.uid}:sek"))
creds = Doorkeeper::OAuth::Client::Credentials.from_basic(req)
ok = creds && creds.first == app.uid
puts ok ? 'PASS' : "FAIL: #{creds.inspect}"
```

**期待結果:** 登録済み uid の Basic は `nil` にせず、先頭要素が uid の資格情報を返す

---

### [1-14] Basic ヘッダ無しは従来どおり nil

```ruby
req = Struct.new(:authorization).new(nil)
creds = Doorkeeper::OAuth::Client::Credentials.from_basic(req)
puts creds.nil? ? 'PASS' : "FAIL: #{creds.inspect}"
```

**期待結果:** Basic ヘッダが無ければ従来どおり `nil`（パッチによる副作用なし）

---

> **[1-15]〜[1-16] は Doorkeeper なし（6.1 未満）のときのみ実行する。6.1 以上ではスキップする。**

### [1-15] 6.1 未満: Doorkeeper 無しでもプラグインが正常ロードされる（init.rb のガード）

```ruby
if defined?(Doorkeeper)
  puts 'SKIP: 6.1 以上（Doorkeeper あり）'
else
  loaded = (Redmine::Plugin.find(:redmine_studio_plugin) rescue nil)
  patch_defined = defined?(RedmineStudioPlugin::OauthClient::DoorkeeperClientCredentialsPatch)
  puts (loaded && patch_defined) ? 'PASS' : "FAIL: loaded=#{!loaded.nil?} patch_defined=#{!patch_defined.nil?}"
end
```

**期待結果:** Doorkeeper が無くても require は通り（patch モジュールは定義済み）、プラグインは正常ロードされる（init.rb の `prepend` がガードでスキップされ、初期化が中断しない）

---

### [1-16] 6.1 未満: registered_application が nil（available? が false）

```ruby
if defined?(Doorkeeper)
  puts 'SKIP: 6.1 以上（Doorkeeper あり）'
else
  puts RedmineStudioPlugin::OauthClient::AppRegistrar.registered_application.nil? ? 'PASS' : 'FAIL'
end
```

**期待結果:** 6.1 未満（Doorkeeper なし）は `registered_application` が `nil`（`available?` が false）

---

## 2. HTTP テスト

**実行方法:**
PowerShell で各エンドポイントにリクエストを送信する。
本 API は**匿名アクセス可**のため、API キーを付与せずに実行する。

### [2-0] 匿名（認証情報なし）でアクセスできる

```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/oauth_client.json' -Method Get
$response.StatusCode
```

**期待結果:** ステータスコード 200（API キー無しで到達できる）

---

### [2-1] `login_required` を有効にしても匿名で到達できる（唯一の匿名例外）

**確認方法（Runner で ON にし、HTTP で確認し、Runner で元に戻す）:**
```bash
# 1) login_required を ON
docker exec {Container} bash -c "cd /usr/src/redmine && bundle exec rails runner \"Setting.login_required='1'\""
```
```powershell
# 2) 匿名で 200 になること（他の追加 API は 401 になる）
Invoke-WebRequest -Uri '{BaseUrl}/oauth_client.json' -Method Get | Select-Object -Expand StatusCode   # 200 期待
try { Invoke-WebRequest -Uri '{BaseUrl}/info.json' -Method Get } catch { $_.Exception.Response.StatusCode.Value__ }   # 401 期待
```
```bash
# 3) login_required を元に戻す
docker exec {Container} bash -c "cd /usr/src/redmine && bundle exec rails runner \"Setting.login_required='0'\""
```

**期待結果:** `login_required` の ON/OFF に関わらず `/oauth_client` は 200。対照として `/info` は ON で 401

---

> **[2-2]〜[2-7] は Doorkeeper 依存（登録済みアプリ・トークン取得）。6.1 以上のみ実行し、6.1 未満（Doorkeeper なし）ではスキップする。**

### [2-2] JSON に client_id が含まれる（登録済み）

```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/oauth_client.json' -Method Get
$response.oauth_client.client_id
```

**期待結果:** `oauth_client.client_id` が空でない文字列

---

### [2-3] JSON の scopes が配列で admin を含まない

```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/oauth_client.json' -Method Get
$scopes = $response.oauth_client.scopes
($scopes -is [array]) -and (-not ($scopes -contains 'admin'))
```

**期待結果:** `scopes` が配列で、`admin` を含まない

---

### [2-4] XML に oauth_client / client_id が含まれる

```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/oauth_client.xml' -Method Get
($response.Content -match '<oauth_client>') -and ($response.Content -match '<client_id>')
```

**期待結果:** レスポンスに `<oauth_client>` と `<client_id>` が含まれる

---

### [2-5] 未登録時は 200 で空 `{}` を返す

**確認方法（Runner で削除 → HTTP 確認 → Runner で自己修復）:**
```bash
docker exec {Container} bash -c "cd /usr/src/redmine && bundle exec rails runner \"Doorkeeper::Application.where(name: 'Redmine Studio').destroy_all\""
```
```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/oauth_client.json' -Method Get
$response.StatusCode   # 200 期待
$response.Content      # {"oauth_client":{}} 期待（client_id 無し）
```
```bash
docker exec {Container} bash -c "cd /usr/src/redmine && bundle exec rails runner \"RedmineStudioPlugin::OauthClient::AppRegistrar.ensure_registered\""
```

**期待結果:** 未登録（非対応相当）でも 404 ではなく 200 で空オブジェクトを返す。`client_id` は含まれない

---

### [2-6] ゲートの Basic ヘッダ下でもボディ client_id でトークン取得の認証が通る

前段ゲートの `Authorization: Basic` を載せたまま、ボディに公開クライアントの `client_id` を渡す。
パッチにより Basic はクライアント資格情報として無視され、ボディの `client_id` でクライアント認証が成立する。
偽の認可コードを渡すため、`invalid_client`（クライアント認証失敗）ではなく `invalid_grant`（コード不正）で失敗すれば、
クライアント認証が通ったことの証明になる。

```powershell
# 登録済みアプリの uid を取得
$uid = docker exec {Container} bash -c "cd /usr/src/redmine && bundle exec rails runner `"puts Doorkeeper::Application.find_by(name: 'Redmine Studio').uid`"" | Select-Object -Last 1
$uid = $uid.Trim()

$basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('user:password'))
$headers = @{ Authorization = "Basic $basic" }
$body = @{
  grant_type    = 'authorization_code'
  code          = 'bogus-code-not-exist'
  client_id     = $uid
  redirect_uri  = 'http://127.0.0.1/'
  code_verifier = ('a' * 43)
}
try {
  Invoke-RestMethod -Uri '{BaseUrl}/oauth/token' -Method Post -Headers $headers -Body $body
} catch {
  $_.ErrorDetails.Message   # {"error":"invalid_grant",...} 期待
}
```

**期待結果:** レスポンスの `error` が `invalid_grant`（`invalid_client` ではない＝クライアント認証は成立）

---

### [2-7] ボディ client_id が無ければフォールバック先が無く invalid_client

ゲートの Basic のみでボディに `client_id` が無い場合、フォールバック先が無いためクライアント認証は成立しない。
[2-6] の対照として、パッチが「Basic を無条件に通す」ものではないことを確認する。

```powershell
$basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('user:password'))
$headers = @{ Authorization = "Basic $basic" }
$body = @{
  grant_type    = 'authorization_code'
  code          = 'bogus-code-not-exist'
  redirect_uri  = 'http://127.0.0.1/'
  code_verifier = ('a' * 43)
}
try {
  Invoke-RestMethod -Uri '{BaseUrl}/oauth/token' -Method Post -Headers $headers -Body $body
} catch {
  $_.ErrorDetails.Message   # {"error":"invalid_client",...} 期待
}
```

**期待結果:** レスポンスの `error` が `invalid_client`（フォールバックできるボディ `client_id` が無い）

---

> **[2-8] は Doorkeeper なし（6.1 未満）のときのみ実行する。6.1 以上ではスキップする。**

### [2-8] 6.1 未満: 空応答を返す（degradation）

```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/oauth_client.json' -Method Get
$response.StatusCode   # 200 期待
$response.Content      # {"oauth_client":{}} 期待（client_id 無し）
```

**期待結果:** 6.1 未満（Doorkeeper なし）でも 404 ではなく 200 で空オブジェクト `{"oauth_client":{}}` を返す（`client_id` 無し＝アプリは「プラグイン対応・Redmine 非対応」と解釈できる）

---

## 3. ブラウザテスト

なし（API のみの機能のため）

---

## テスト実行方法

### Runner テスト・HTTP テスト
Claude が TEST_SPEC.md の仕様に基づいてコマンドを実行し、結果を報告する。
