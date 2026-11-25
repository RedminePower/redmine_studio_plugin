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
| 閲覧系 | `read` フラグの付いた権限を広めに許可。ただし破壊的操作（`close_project` / `delete_project`）は `read` 扱いでも除外。カテゴリー一覧は閲覧専用権限がコアに無いため `manage_categories` を含める |
| 変更系 | アプリが実際に使う操作のみ（`add_issues` / `edit_issues` / `edit_own_issues` / `manage_subtasks` / `add_issue_notes` / `log_time` / `edit_time_entries` / `edit_own_time_entries`） |
| 先行確保 | アプリの将来機能で使う見込みの権限（`edit_wiki_pages`）。取り消せる操作に限り、`delete_wiki_pages`（履歴ごと消える）は含めない |
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
そのためテストは版で適用範囲を分ける（実行時に Doorkeeper の有無で判定し、対象外は SKIP と出す。Runner は `defined?(Doorkeeper)`、HTTP は用意が出す `HasDoorkeeper` で判定する）。

| 区分 | 対象ケース | 適用版 |
|------|-----------|--------|
| 全版共通 | [1-1]〜[1-5] / [1-9] / [1-10] / [2-0] / [2-1] | 全版 |
| Doorkeeper 依存（登録・patch・トークン） | [1-6]〜[1-8]（[1-7-2]・[1-7-3] を含む） / [1-11]〜[1-14] / [2-2]〜[2-7] / [2-9]〜[2-11] | **6.1 以上のみ**（6.1 未満は Doorkeeper 無しでスキップ） |
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
bad = [:admin, :close_project, :delete_project, :delete_wiki_pages] & names
puts bad.empty? ? 'PASS' : "FAIL: forbidden scopes present: #{bad.join(', ')}"
```

**期待結果:** `admin` / `close_project` / `delete_project` / `delete_wiki_pages` を含まない

---

### [1-5] スコープに必要な変更系が含まれる

```ruby
names = RedmineStudioPlugin::OauthClient::ScopeProvider.scope_names
required = [:add_issues, :edit_issues, :edit_own_issues, :manage_subtasks, :add_issue_notes,
            :log_time, :edit_time_entries, :edit_own_time_entries, :manage_categories,
            :edit_wiki_pages, :view_issues]
missing = required - names
puts missing.empty? ? 'PASS' : "FAIL: missing scopes: #{missing.join(', ')}"
```

**期待結果:** 変更系の必須スコープと `view_issues` を含む

---

> **[1-6]〜[1-8] は Doorkeeper 依存（自己修復登録）。6.1 以上のみ実行し、6.1 未満（Doorkeeper なし）ではスキップする。**

### [1-6] 自己修復登録が公開クライアントを作成する

今あるサインイン用アプリは、消さずに名前を一時的に変えて「未登録」にし、最後に戻す（消すと発行済みのトークンも消え、client_id も変わる）。

```ruby
unless defined?(Doorkeeper)
  puts 'SKIP: 6.1 未満（Doorkeeper なし）'
else
  reg = RedmineStudioPlugin::OauthClient::AppRegistrar
  sfx = SecureRandom.hex(3)
  saved = reg.signin_applications.to_a
  begin
    saved.each { |a| a.update_column(:name, "Redmine Studio saved #{sfx}") }
    reg.ensure_registered
    app = reg.registered_application
    ok = app && saved.none? { |a| a.id == app.id } && app.confidential == false && app.redirect_uri == 'http://127.0.0.1/' && app.uid.present?
    puts ok ? 'PASS' : "FAIL: app=#{app.inspect}"
  ensure
    saved.each { |a| a.update_column(:name, 'Redmine Studio') }
    # 試験で作ったアプリは、いちばん古い元のアプリへまとめて消す（元が無かったときは消すだけ）
    saved.empty? ? reg.signin_applications.delete_all : reg.ensure_registered
  end
end
```

**期待結果:** `confidential=false`（公開クライアント）・`redirect_uri=http://127.0.0.1/`・`uid` 付きで登録される

---

### [1-7] 何度呼んでも重複登録しない（冪等）

```ruby
unless defined?(Doorkeeper)
  puts 'SKIP: 6.1 未満（Doorkeeper なし）'
else
  reg = RedmineStudioPlugin::OauthClient::AppRegistrar
  before = reg.signin_applications.pluck(:id)
  begin
    3.times { reg.ensure_registered }
    count = reg.signin_applications.count
    puts count == 1 ? 'PASS' : "FAIL: count=#{count}"
  ensure
    # 前に無かったときは、この試験で作ったアプリを消す
    reg.signin_applications.delete_all if before.empty?
  end
end
```

**期待結果:** 登録は常に 1 件（起動のたびに呼んでも増えない）

---

### [1-7-2] 同じ名前のアプリが二重になっていたら、いちばん古いものにまとめる

複数のプロセスが同時に起動すると、同じ名前のアプリが二重に登録されることがある。
起動時の登録で、いちばん古いものを残し、ほかのアプリで発行したトークン・認可コードをそれへ付け替えてから、ほかを消す。
まとめる前でも、`registered_application`（`/oauth_client` が返すアプリ）はいちばん古いものを選ぶ。

```ruby
unless defined?(Doorkeeper)
  puts 'SKIP: 6.1 未満（Doorkeeper なし）'
else
  R = RedmineStudioPlugin::OauthClient::AppRegistrar
  A = Doorkeeper::Application
  before = R.signin_applications.pluck(:id)
  begin
    R.ensure_registered
    orig = R.signin_applications.first
    dup1 = A.create!(name: 'Redmine Studio', redirect_uri: 'http://127.0.0.1/', scopes: 'view_issues', confidential: false)
    dup2 = A.create!(name: 'Redmine Studio', redirect_uri: 'http://127.0.0.1/', scopes: 'view_issues', confidential: false)
    user = User.find(1)
    tok = Doorkeeper::AccessToken.create!(application_id: dup2.id, resource_owner_id: user.id, scopes: 'view_issues', expires_in: 7200, use_refresh_token: true)
    grant = Doorkeeper::AccessGrant.create!(application_id: dup1.id, resource_owner_id: user.id, scopes: 'view_issues', expires_in: 600, redirect_uri: 'http://127.0.0.1/')
    picked = R.registered_application
    R.ensure_registered
    apps = A.where(name: 'Redmine Studio').to_a
    ok = picked.id == orig.id && apps.map(&:id) == [orig.id] && tok.reload.application_id == orig.id && grant.reload.application_id == orig.id && R.registered_application.id == orig.id
    puts ok ? 'PASS' : "FAIL: picked=#{picked.id} orig=#{orig.id} apps=#{apps.map(&:id)} tok=#{tok.reload.application_id} grant=#{grant.reload.application_id}"
  ensure
    Doorkeeper::AccessToken.where(id: tok&.id).delete_all
    Doorkeeper::AccessGrant.where(id: grant&.id).delete_all
    # 途中で落ちても、二重のアプリを残さない（前に無かったときは、作ったアプリを消す）
    R.ensure_registered
    R.signin_applications.delete_all if before.empty?
  end
end
```

**期待結果:** まとめる前の `registered_application` がいちばん古いアプリ。まとめた後はそのアプリ 1 件だけが残り、トークン・認可コードがそれに付け替わっている

---

### [1-7-3] 作った直後にほかのプロセスも作っていたらまとめる・管理者が作った同じ名前のアプリは残す

未登録のときに作った直後、同時に起動したほかのプロセスも同じアプリを作っていた場面を、`create!` の差し替えで作る（差し替えは印が立っている間だけ働く）。
同じ名前でもリダイレクト先・confidential の違うアプリ（管理者が画面から作ったもの）は、消さず、正にもしない。
今あるサインイン用アプリは、名前を一時的に変えて「未登録」にし、最後に戻す。

```ruby
unless defined?(Doorkeeper)
  puts 'SKIP: 6.1 未満（Doorkeeper なし）'
else
  R = RedmineStudioPlugin::OauthClient::AppRegistrar
  A = Doorkeeper::Application
  sfx = SecureRandom.hex(3)
  $oauth_173_dup = false
  module OAuth173Stub
    def create!(*args, **kw, &blk)
      app = super
      if $oauth_173_dup
        $oauth_173_dup = false
        super(name: 'Redmine Studio', redirect_uri: 'http://127.0.0.1/', scopes: 'view_issues', confidential: false)
      end
      app
    end
  end
  A.singleton_class.prepend(OAuth173Stub)
  saved = R.signin_applications.to_a
  made = []
  begin
    saved.each { |a| a.update_column(:name, "Redmine Studio saved #{sfx}") }
    admin_app = A.create!(name: 'Redmine Studio', redirect_uri: "https://example.com/cb-#{sfx}", scopes: 'view_issues', confidential: true)
    made << admin_app.id
    $oauth_173_dup = true
    R.ensure_registered
    apps = R.signin_applications.to_a
    made.concat(A.where(name: 'Redmine Studio').pluck(:id))
    puts "dup_made: #{!$oauth_173_dup}"
    puts "merged_to_one: #{apps.size == 1}"
    puts "admin_app_kept: #{A.exists?(admin_app.id) && R.registered_application&.id != admin_app.id}"
  ensure
    $oauth_173_dup = false
    A.where(id: made.uniq).delete_all
    saved.each { |a| a.update_column(:name, 'Redmine Studio') }
    puts "restored: #{R.signin_applications.pluck(:id) == saved.map(&:id)}"
  end
end
```

**期待結果:**
- `dup_made: true`（作った直後にもう 1 つ作られた）
- `merged_to_one: true`（サインイン用アプリが 1 つにまとまった）
- `admin_app_kept: true`（管理者が作った同じ名前のアプリは残り、正にはならない）
- `restored: true`（今あるサインイン用アプリを元に戻した）

---

### [1-8] スコープ定義のズレを追従する

```ruby
unless defined?(Doorkeeper)
  puts 'SKIP: 6.1 未満（Doorkeeper なし）'
else
  reg = RedmineStudioPlugin::OauthClient::AppRegistrar
  before = reg.signin_applications.pluck(:id)
  begin
    reg.ensure_registered
    app = reg.registered_application
    app.update!(scopes: 'view_issues')
    reg.ensure_registered
    expected = RedmineStudioPlugin::OauthClient::ScopeProvider.scope_names.map(&:to_s).sort
    ok = app.reload.scopes.all.sort == expected
    puts ok ? 'PASS' : "FAIL: scopes=#{app.scopes.all.sort}"
  ensure
    reg.ensure_registered  # 途中で落ちても、スコープを定義どおりに戻す
    reg.signin_applications.delete_all if before.empty?
  end
end
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

### [1-10] クライアント資格情報パッチが定義されている（全版共通）

```ruby
puts defined?(RedmineStudioPlugin::OauthClient::DoorkeeperClientCredentialsPatch) ? 'PASS' : 'FAIL: patch not defined'
```

**期待結果:** `DoorkeeperClientCredentialsPatch` が定義されている（モジュールの定義は Doorkeeper が無くても読み込まれる）

---

> **[1-11]〜[1-14] は Doorkeeper 依存（クライアント資格情報 patch）。6.1 以上のみ実行し、6.1 未満（Doorkeeper なし）ではスキップする。**

### [1-11] パッチが Credentials の特異クラスに適用されている

```ruby
unless defined?(Doorkeeper)
  puts 'SKIP: 6.1 未満（Doorkeeper なし）'
else
  ok = Doorkeeper::OAuth::Client::Credentials.singleton_class.ancestors.include?(RedmineStudioPlugin::OauthClient::DoorkeeperClientCredentialsPatch)
  puts ok ? 'PASS' : 'FAIL: patch not prepended to Credentials singleton class'
end
```

**期待結果:** `Doorkeeper::OAuth::Client::Credentials` の特異クラスにパッチが `prepend` されている

---

### [1-12] ゲートの資格情報（未登録 uid）の Basic は無視される

```ruby
unless defined?(Doorkeeper)
  puts 'SKIP: 6.1 未満（Doorkeeper なし）'
else
  require 'base64'
  req = Struct.new(:authorization).new('Basic ' + Base64.strict_encode64('user:password'))
  creds = Doorkeeper::OAuth::Client::Credentials.from_basic(req)
  puts creds.nil? ? 'PASS' : "FAIL: #{creds.inspect}"
end
```

**期待結果:** 未登録 uid（前段ゲートの資格情報）の Basic では `nil`（＝ボディ `client_id` へフォールバックさせる）

---

### [1-13] 登録済みアプリ uid の Basic は従来どおり尊重される

```ruby
unless defined?(Doorkeeper)
  puts 'SKIP: 6.1 未満（Doorkeeper なし）'
else
  require 'base64'
  reg = RedmineStudioPlugin::OauthClient::AppRegistrar
  before = reg.signin_applications.pluck(:id)
  begin
    reg.ensure_registered
    app = reg.registered_application
    req = Struct.new(:authorization).new('Basic ' + Base64.strict_encode64("#{app.uid}:sek"))
    creds = Doorkeeper::OAuth::Client::Credentials.from_basic(req)
    ok = creds && creds.first == app.uid
    puts ok ? 'PASS' : "FAIL: #{creds.inspect}"
  ensure
    reg.signin_applications.delete_all if before.empty?
  end
end
```

**期待結果:** 登録済み uid の Basic は `nil` にせず、先頭要素が uid の資格情報を返す

---

### [1-14] Basic ヘッダ無しは従来どおり nil

```ruby
unless defined?(Doorkeeper)
  puts 'SKIP: 6.1 未満（Doorkeeper なし）'
else
  req = Struct.new(:authorization).new(nil)
  creds = Doorkeeper::OAuth::Client::Credentials.from_basic(req)
  puts creds.nil? ? 'PASS' : "FAIL: #{creds.inspect}"
end
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
[2-6]・[2-9]〜[2-11] が使うデータ（プロジェクト・利用者・ロール・親チケット・カテゴリー・トークン）は、用意でその場で作る（終わったら消す）。

**用意（HTTP テストの前に 1 回）:**
```ruby
# 6.1 未満（Doorkeeper なし）では Token・ClientId は空、HasDoorkeeper は false（Doorkeeper に頼る試験は SKIP と出す）
admin = User.find(1)
User.current = admin
reg = RedmineStudioPlugin::OauthClient::AppRegistrar
# 前回の残りを消す
olds = User.where('login LIKE ?', 'oca_user_%').to_a
Doorkeeper::AccessToken.where(resource_owner_id: olds.map(&:id)).delete_all if defined?(Doorkeeper::AccessToken)
Project.where('identifier LIKE ?', 'oca-%').each(&:destroy)
olds.each(&:destroy)
Role.where('name LIKE ?', 'OCA_Role_%').each(&:destroy)
sfx = SecureRandom.hex(3)
role = Role.create!(name: "OCA_Role_#{sfx}", permissions: [:view_issues, :add_issues, :manage_subtasks, :manage_categories, :view_wiki_pages, :edit_wiki_pages])
pr = Project.new(name: "OCA_#{sfx}", identifier: "oca-#{sfx}", is_public: false)
pr.enabled_module_names = %w[issue_tracking wiki]
pr.trackers = [Tracker.first]
pr.save!
u = User.new(login: "oca_user_#{sfx}", firstname: 'OCA', lastname: 'User', mail: "oca_user_#{sfx}@example.com", status: User::STATUS_ACTIVE)
u.password = u.password_confirmation = "Pw-#{sfx}-x9Z"
u.save!
Member.create!(principal: u, project: pr, roles: [role])
parent = Issue.create!(project: pr, tracker: pr.trackers.first, author: admin, subject: "OCA parent #{sfx}", priority: IssuePriority.default || IssuePriority.first)
cat = pr.issue_categories.create!(name: "oca-cat-#{sfx}")
app = reg.registered_application
token = app ? Doorkeeper::AccessToken.create!(application_id: app.id, resource_owner_id: u.id, scopes: RedmineStudioPlugin::OauthClient::ScopeProvider.scope_string, expires_in: 600).plaintext_token : ''
puts({ ProjectId: pr.identifier, ParentIssueId: parent.id, CategoryName: cat.name, Token: token, ClientId: app&.uid.to_s, HasDoorkeeper: defined?(Doorkeeper) ? 'true' : 'false' }.to_json)
```

**後片付け（HTTP テストのあとに 1 回）:**
```ruby
User.current = User.find(1)
olds = User.where('login LIKE ?', 'oca_user_%').to_a
Doorkeeper::AccessToken.where(resource_owner_id: olds.map(&:id)).delete_all if defined?(Doorkeeper::AccessToken)
Project.where('identifier LIKE ?', 'oca-%').each(&:destroy)
olds.each(&:destroy)
Role.where('name LIKE ?', 'OCA_Role_%').each(&:destroy)
left = Project.where('identifier LIKE ?', 'oca-%').count + User.where('login LIKE ?', 'oca_user_%').count + Role.where('name LIKE ?', 'OCA_Role_%').count
puts left.zero? ? 'cleaned' : "left=#{left}"
```

### [2-0] 匿名（認証情報なし）でアクセスできる

```powershell
$response = Invoke-WebRequest -Uri '{BaseUrl}/oauth_client.json' -Method Get
$response.StatusCode
```

**期待結果:** ステータスコード 200（API キー無しで到達できる）

---

### [2-1] `login_required` を有効にしても匿名で到達できる（唯一の匿名例外）

**確認方法（Runner で ON にし、HTTP で確認し、`finally` で必ず元の値に戻す）:**
```powershell
$Container = '{Container}'
function Rr($code) { docker exec -u redmine -w /usr/src/redmine $Container bundle exec rails runner $code 2>$null | Select-Object -Last 1 }
$orig = Rr 'puts Setting.login_required'
if ($orig -notmatch '^[01]$') { throw "login_required の値が読めない: '$orig'" }
try {
  Rr "Setting.login_required = '1'; puts 'on'" | Out-Null
  # 匿名で 200 になること（他の追加 API は 401 になる）
  $a = (Invoke-WebRequest -Uri '{BaseUrl}/oauth_client.json' -Method Get).StatusCode
  $b = try { (Invoke-WebRequest -Uri '{BaseUrl}/info.json' -Method Get).StatusCode } catch { $_.Exception.Response.StatusCode.Value__ }
  "oauth_client=$a info=$b"
} finally {
  Rr "Setting.login_required = '$orig'; puts 'restored=' + (Setting.login_required == '$orig').to_s"
}
```

**期待結果:** `oauth_client=200 info=401`（`login_required` を ON にしても `/oauth_client` は 200。対照として `/info` は 401）。最後に `restored=true`

---

> **[2-2]〜[2-7] は Doorkeeper 依存（登録済みアプリ・トークン取得）。6.1 以上のみ実行し、6.1 未満（Doorkeeper なし）ではスキップする。**

### [2-2] JSON に client_id が含まれる（登録済み）

```powershell
if ('{HasDoorkeeper}' -notin 'true', 'false') {
  throw 'HasDoorkeeper が true / false でない（用意の出力を確かめる）'
} elseif ('{HasDoorkeeper}' -eq 'false') {
  'SKIP: 6.1 未満（Doorkeeper なし）'
} else {
  $response = Invoke-RestMethod -Uri '{BaseUrl}/oauth_client.json' -Method Get
  $response.oauth_client.client_id
}
```

**期待結果:** `oauth_client.client_id` が空でない文字列

---

### [2-3] JSON の scopes が配列で admin を含まない

```powershell
if ('{HasDoorkeeper}' -notin 'true', 'false') {
  throw 'HasDoorkeeper が true / false でない（用意の出力を確かめる）'
} elseif ('{HasDoorkeeper}' -eq 'false') {
  'SKIP: 6.1 未満（Doorkeeper なし）'
} else {
  $response = Invoke-RestMethod -Uri '{BaseUrl}/oauth_client.json' -Method Get
  $scopes = $response.oauth_client.scopes
  ($scopes -is [array]) -and (-not ($scopes -contains 'admin'))
}
```

**期待結果:** `scopes` が配列で、`admin` を含まない

---

### [2-4] XML に oauth_client / client_id が含まれる

```powershell
if ('{HasDoorkeeper}' -notin 'true', 'false') {
  throw 'HasDoorkeeper が true / false でない（用意の出力を確かめる）'
} elseif ('{HasDoorkeeper}' -eq 'false') {
  'SKIP: 6.1 未満（Doorkeeper なし）'
} else {
  $response = Invoke-WebRequest -Uri '{BaseUrl}/oauth_client.xml' -Method Get
  ($response.Content -match '<oauth_client>') -and ($response.Content -match '<client_id>')
}
```

**期待結果:** レスポンスに `<oauth_client>` と `<client_id>` が含まれる

---

### [2-5] 未登録時は 200 で空 `{}` を返す

**確認方法（Runner で名前を一時的に変えて未登録にする → HTTP 確認 → `finally` で必ず名前を戻す）:**
消すと発行済みのトークンも消え、client_id も変わるので、消さずに名前を変える。
rails runner は起動のたびに自己修復登録が走るため、戻すときに `ensure_registered` で元のアプリ（いちばん古いもの）へまとめる。

```powershell
if ('{HasDoorkeeper}' -notin 'true', 'false') {
  throw 'HasDoorkeeper が true / false でない（用意の出力を確かめる）'
} elseif ('{HasDoorkeeper}' -eq 'false') {
  'SKIP: 6.1 未満（Doorkeeper なし）'
} else {
  $Container = '{Container}'
  function Rr($code) { docker exec -u redmine -w /usr/src/redmine $Container bundle exec rails runner $code 2>$null | Select-Object -Last 1 }
  $sfx = -join (1..6 | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
  $before = Rr 'puts RedmineStudioPlugin::OauthClient::AppRegistrar.signin_applications.pluck(:id).inspect'
  try {
    Rr "RedmineStudioPlugin::OauthClient::AppRegistrar.signin_applications.update_all(name: 'Redmine Studio saved $sfx'); puts 'hidden'" | Out-Null
    $response = Invoke-WebRequest -Uri '{BaseUrl}/oauth_client.json' -Method Get
    "status=$($response.StatusCode) body=$($response.Content)"
  } finally {
    $after = Rr "R = RedmineStudioPlugin::OauthClient::AppRegistrar; Doorkeeper::Application.where(name: 'Redmine Studio saved $sfx').update_all(name: 'Redmine Studio'); R.ensure_registered; puts R.signin_applications.pluck(:id).inspect"
    "restored=$($after -eq $before)"
  }
}
```

**期待結果:** `status=200 body={"oauth_client":{}}`（未登録〔非対応相当〕でも 404 ではなく 200 で空オブジェクト。`client_id` は含まれない）。最後に `restored=True`（元のアプリに戻った）

---

### [2-6] ゲートの Basic ヘッダ下でもボディ client_id でトークン取得の認証が通る

前段ゲートの `Authorization: Basic` を載せたまま、ボディに公開クライアントの `client_id` を渡す。
パッチにより Basic はクライアント資格情報として無視され、ボディの `client_id` でクライアント認証が成立する。
偽の認可コードを渡すため、`invalid_client`（クライアント認証失敗）ではなく `invalid_grant`（コード不正）で失敗すれば、
クライアント認証が通ったことの証明になる。

```powershell
if ('{HasDoorkeeper}' -notin 'true', 'false') {
  throw 'HasDoorkeeper が true / false でない（用意の出力を確かめる）'
} elseif ('{HasDoorkeeper}' -eq 'false') {
  'SKIP: 6.1 未満（Doorkeeper なし）'
} else {
  # 登録済みアプリの uid（用意の ClientId）
  $uid = '{ClientId}'

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
}
```

**期待結果:** レスポンスの `error` が `invalid_grant`（`invalid_client` ではない＝クライアント認証は成立）

---

### [2-7] ボディ client_id が無ければフォールバック先が無く invalid_client

ゲートの Basic のみでボディに `client_id` が無い場合、フォールバック先が無いためクライアント認証は成立しない。
[2-6] の対照として、パッチが「Basic を無条件に通す」ものではないことを確認する。

```powershell
if ('{HasDoorkeeper}' -notin 'true', 'false') {
  throw 'HasDoorkeeper が true / false でない（用意の出力を確かめる）'
} elseif ('{HasDoorkeeper}' -eq 'false') {
  'SKIP: 6.1 未満（Doorkeeper なし）'
} else {
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
}
```

**期待結果:** レスポンスの `error` が `invalid_client`（フォールバックできるボディ `client_id` が無い）

---

> **[2-8] は Doorkeeper なし（6.1 未満）のときのみ実行する。6.1 以上ではスキップする。**

### [2-8] 6.1 未満: 空応答を返す（degradation）

```powershell
if ('{HasDoorkeeper}' -notin 'true', 'false') {
  throw 'HasDoorkeeper が true / false でない（用意の出力を確かめる）'
} elseif ('{HasDoorkeeper}' -eq 'true') {
  'SKIP: 6.1 以上（Doorkeeper あり）'
} else {
  $response = Invoke-WebRequest -Uri '{BaseUrl}/oauth_client.json' -Method Get
  $response.StatusCode   # 200 期待
  $response.Content      # {"oauth_client":{}} 期待（client_id 無し）
}
```

**期待結果:** 6.1 未満（Doorkeeper なし）でも 404 ではなく 200 で空オブジェクト `{"oauth_client":{}}` を返す（`client_id` 無し＝アプリは「プラグイン対応・Redmine 非対応」と解釈できる）

---

> **[2-9]〜[2-11] はスコープ契約テスト（Doorkeeper 依存）。6.1 以上のみ実行し、6.1 未満ではスキップする。**
>
> サインインと同じスコープを載せたアクセストークンを Runner で直作成し、Bearer 認証で
> 「アプリが実際に使う操作」が権限 AND で削られないことを検証する（トークンに無い権限は
> ロールにあっても落とされるため、スコープ定義の不足はこの形でしか検知できない）。
>
> **データ**: 用意で、非公開プロジェクト（`{ProjectId}`・チケットと Wiki のモジュール有効）・親チケット（`{ParentIssueId}`）・
> カテゴリー（`{CategoryName}`）と、`add_issues` / `manage_subtasks` / `manage_categories` / `edit_wiki_pages` を持つ
> ロールでメンバーにした利用者を作り、その利用者にサインインと同じスコープのトークン（`{Token}`）を発行する。
> トークンはハッシュ保存（`hash_token_secrets`）のため、用意で受け取った平文（`plaintext_token`）を使う。

### [2-9] スコープ契約: 親チケットを指定した作成が配下に入る

```powershell
if ('{HasDoorkeeper}' -notin 'true', 'false') {
  throw 'HasDoorkeeper が true / false でない（用意の出力を確かめる）'
} elseif ('{HasDoorkeeper}' -eq 'false') {
  'SKIP: 6.1 未満（Doorkeeper なし）'
} else {
  # 親チケットを指定して作成し、作成結果の parent を確認（作ったチケットは後片付けでプロジェクトごと消える）
  $h = @{ Authorization = 'Bearer {Token}' }
  $body = @{ issue = @{ project_id = '{ProjectId}'; subject = 'scope contract: parent'; parent_issue_id = {ParentIssueId} } } | ConvertTo-Json
  $r = Invoke-RestMethod -Uri '{BaseUrl}/issues.json' -Method Post -Body $body -ContentType 'application/json' -Headers $h
  (Invoke-RestMethod -Uri "{BaseUrl}/issues/$($r.issue.id).json" -Headers $h).issue.parent.id -eq {ParentIssueId}   # True 期待
}
```

**期待結果:** `True`（作成されたチケットの `parent.id` が親チケットの番号。`manage_subtasks` がスコープに無いと、エラーにならず親なしで作成されてしまう）

---

### [2-10] スコープ契約: カテゴリー一覧が取得できる

```powershell
if ('{HasDoorkeeper}' -notin 'true', 'false') {
  throw 'HasDoorkeeper が true / false でない（用意の出力を確かめる）'
} elseif ('{HasDoorkeeper}' -eq 'false') {
  'SKIP: 6.1 未満（Doorkeeper なし）'
} else {
  # カテゴリー一覧 API（コアが manage_categories を要求）を Bearer で取得
  $r = Invoke-RestMethod -Uri '{BaseUrl}/projects/{ProjectId}/issue_categories.json' -Headers @{ Authorization = 'Bearer {Token}' }
  $r.issue_categories.name -contains '{CategoryName}'   # True 期待（スコープ不足だと 403）
}
```

**期待結果:** `True`（200 で用意したカテゴリーを含む一覧が返る。`manage_categories` がスコープに無いと 403 になり、cache_bundle でもカテゴリーが空になる）

---

### [2-11] スコープ契約: Wiki ページの作成・編集ができる（先行確保）

```powershell
if ('{HasDoorkeeper}' -notin 'true', 'false') {
  throw 'HasDoorkeeper が true / false でない（用意の出力を確かめる）'
} elseif ('{HasDoorkeeper}' -eq 'false') {
  'SKIP: 6.1 未満（Doorkeeper なし）'
} else {
  # Wiki ページを Bearer で作成（PUT は新規作成と更新を兼ねる）し、取得して確認（ページは後片付けでプロジェクトごと消える）
  $h = @{ Authorization = 'Bearer {Token}' }
  $body = @{ wiki_page = @{ text = 'scope contract wiki text' } } | ConvertTo-Json
  Invoke-RestMethod -Uri '{BaseUrl}/projects/{ProjectId}/wiki/ScopeContractPage.json' -Method Put -Body $body -ContentType 'application/json' -Headers $h | Out-Null
  (Invoke-RestMethod -Uri '{BaseUrl}/projects/{ProjectId}/wiki/ScopeContractPage.json' -Headers $h).wiki_page.text -eq 'scope contract wiki text'   # True 期待
}
```

**期待結果:** `True`（作成が成功し、取得したページ本文が一致する。`edit_wiki_pages` がスコープに無いと 403。将来の Wiki 書き込み機能のための先行確保が効いていることの確認）

---

## 3. ブラウザテスト

なし（API のみの機能のため）

---

## テスト実行方法

### Runner テスト・HTTP テスト
Claude が TEST_SPEC.md の仕様に基づいてコマンドを実行し、結果を報告する。
