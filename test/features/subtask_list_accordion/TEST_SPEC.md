# Subtask List Accordion テスト仕様書

## 概要

Subtask List Accordion 機能のテスト仕様。チケットのサブタスク一覧にアコーディオン機能を追加する。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| フッククラス | `RedmineStudioPlugin::SubtaskListAccordion::Hooks` |
| パッチ | `IssuesHelperPatch`, `UserPreferencePatch` |
| 設定キー | `subtask_list_accordion_enable_server_scripting_mode`, `subtask_list_accordion_expand_all`, `subtask_list_accordion_collapsed_tracker_ids` |
| View パーシャル | `issues/subtask_list_accordion/_partial.html.erb` |
| コンテキストメニュー | `context_menus/subtask_list_accordion/_menu.html.erb` |
| 個人設定パーシャル | `my/subtask_list_accordion/_preferences.erb` |
| 設定パーシャル | `settings/subtask_list_accordion/_settings.html.erb` |

---

## 1. Runner テスト

### [1-1] フッククラス定義確認

**確認方法:**
```ruby
puts defined?(RedmineStudioPlugin::SubtaskListAccordion::Hooks)
```

**期待結果:** `constant` が出力される

### [1-2] IssuesHelper パッチ適用確認

**確認方法:**
```ruby
puts IssuesController._helpers.included_modules.include?(RedmineStudioPlugin::SubtaskListAccordion::IssuesHelperPatch)
```

**期待結果:** `true` が出力される

### [1-3] UserPreference パッチ適用確認

**確認方法:**
```ruby
puts UserPreference.included_modules.include?(RedmineStudioPlugin::SubtaskListAccordion::UserPreferencePatch)
```

**期待結果:** `true` が出力される

### [1-4] フック登録確認（チケット画面）

**確認方法:**
```ruby
hooks = Redmine::Hook.hook_listeners(:view_issues_show_description_bottom)
puts hooks.any? { |h| h.is_a?(RedmineStudioPlugin::SubtaskListAccordion::Hooks) }
```

**期待結果:** `true` が出力される

### [1-5] フック登録確認（個人設定）

**確認方法:**
```ruby
hooks = Redmine::Hook.hook_listeners(:view_my_account_preferences)
puts hooks.any? { |h| h.is_a?(RedmineStudioPlugin::SubtaskListAccordion::Hooks) }
```

**期待結果:** `true` が出力される

### [1-6] View ファイル存在確認

**確認方法:**
```ruby
files = [
  'app/views/issues/subtask_list_accordion/_partial.html.erb',
  'app/views/context_menus/subtask_list_accordion/_menu.html.erb',
  'app/views/my/subtask_list_accordion/_preferences.erb',
  'app/views/settings/subtask_list_accordion/_settings.html.erb'
]
files.each do |f|
  path = Rails.root.join('plugins', 'redmine_studio_plugin', f)
  puts "#{f}: #{File.exist?(path)}"
end
```

**期待結果:** すべて `true`

### [1-7] JavaScript ファイル存在確認

**確認方法:**
```ruby
files = [
  'assets/javascripts/subtask_list_accordion.js',
  'assets/javascripts/subtask_list_accordion_client.js'
]
files.each do |f|
  path = Rails.root.join('plugins', 'redmine_studio_plugin', f)
  puts "#{f}: #{File.exist?(path)}"
end
```

**期待結果:** すべて `true`

### [1-8] プラグイン設定のデフォルト値確認

**確認方法:**
```ruby
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
defaults = plugin.settings[:default]
puts "subtask_list_accordion_enable_server_scripting_mode: #{defaults['subtask_list_accordion_enable_server_scripting_mode']}"
puts "subtask_list_accordion_expand_all: #{defaults['subtask_list_accordion_expand_all']}"
puts "subtask_list_accordion_collapsed_tracker_ids: #{defaults['subtask_list_accordion_collapsed_tracker_ids'].inspect}"
```

**期待結果:**
- `subtask_list_accordion_enable_server_scripting_mode: true`
- `subtask_list_accordion_expand_all: false`
- `subtask_list_accordion_collapsed_tracker_ids: []`

---

## 2. HTTP テスト

**実行方法:**
PowerShell 7 で画面（HTML）を取得して確かめる。画面は API キーでは開けないため、各試験の頭でログインしたセッションを作る。
`{BaseUrl}`・`{Username}`・`{Password}`（管理者）・`{Container}` は実行環境から注入する（プレースホルダの契約は `test/README.md`）。
設定（プラグインの設定・関連チケットの表示設定）を変える試験は、`{Container}` の Runner で設定を変え、`finally` で元の値に戻す。

**用意（HTTP テストの前に 1 回）:**
試験に使うデータを Runner で作る（前回の残りがあれば先に消す）。
- 非公開のプロジェクト（トラッカー 3 つ）と、そのメンバーの非管理ユーザー（パスワードはその場で作る）
- アコーディオンで描かれる親チケット（子 3 件。トラッカーは 1 つ目・2 つ目・3 つ目。1 つ目の子に孫 1 件）
- コアのまま描かれる親チケット（子 2 件、孫なし）

最後の行の値を、各試験の `{UserLogin}`・`{UserPassword}`・`{ParentId}`・`{Child1Id}`・`{Child2Id}`・`{Child3Id}`・`{GrandchildId}`・`{CoreParentId}`・`{Tracker1Id}`・`{Tracker2Id}` に入れる。

```ruby
admin = User.find(1)
User.current = admin
# 前回の残りを消す
Project.where('identifier LIKE ?', 'sla-%').order(lft: :desc).each(&:destroy)
User.where('login LIKE ?', 'sla_%').each(&:destroy)
Role.where('name LIKE ?', 'SLA_%').each(&:destroy)
sfx = SecureRandom.hex(3)
pw = SecureRandom.hex(8)
t1, t2, t3 = Tracker.order(:position).first(3)
status = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.active.first
role = Role.create!(name: "SLA_#{sfx}", permissions: [:view_issues, :add_issues, :edit_issues, :manage_subtasks])
pr = Project.new(name: "SLA_#{sfx}", identifier: "sla-#{sfx}", is_public: false)
pr.enabled_module_names = %w[issue_tracking]
pr.trackers = [t1, t2, t3]
pr.save!
user = User.new(login: "sla_user_#{sfx}", firstname: 'SLA', lastname: 'User', mail: "sla_user_#{sfx}@example.com", status: User::STATUS_ACTIVE)
user.password = user.password_confirmation = pw
user.save!
Member.create!(principal: user, project: pr, roles: [role])
mk = ->(name, tracker, parent = nil) {
  Issue.create!(project: pr, tracker: tracker, subject: "SLA_#{name}_#{sfx}", author: admin, status: status, priority: priority, parent_issue_id: parent&.id)
}
parent = mk.call('Parent', t1)
c1 = mk.call('Child1', t1, parent)
c2 = mk.call('Child2', t2, parent)
c3 = mk.call('Child3', t3, parent)
g = mk.call('Grandchild', t1, c1)
core = mk.call('CoreParent', t1)
mk.call('CoreChild1', t2, core)
mk.call('CoreChild2', t3, core)
puts({ UserLogin: user.login, UserPassword: pw, ParentId: parent.id, Child1Id: c1.id, Child2Id: c2.id, Child3Id: c3.id,
       GrandchildId: g.id, CoreParentId: core.id, Tracker1Id: t1.id, Tracker2Id: t2.id }.to_json)
```

**後片付け（HTTP テストのあとに 1 回）:**

```ruby
User.current = User.find(1)
Project.where('identifier LIKE ?', 'sla-%').order(lft: :desc).each(&:destroy)
User.where('login LIKE ?', 'sla_%').each(&:destroy)
Role.where('name LIKE ?', 'SLA_%').each(&:destroy)
puts 'cleaned'
```

各試験で使う部品（試験ごとに同じものを書く）:
- `Login`: ログイン画面の `authenticity_token` を取り、ログインしたセッションを返す
- `RowClass`: 子チケット一覧の `<tr id="issue-N">` が `collapse` / `expand` のどちらのクラスを持つかを返す（行が無ければ `none`）
- `Rails`: `{Container}` で Runner のコードを 1 行流す（何も返らなければ 3 回までやり直す）
- `SetSla`: プラグインの設定を変える。試験の頭で元の値（`$orig`）を覚え、`finally` で戻す

※ Redmine 6.0 以降は JavaScript のファイル名に digest が付く（`subtask_list_accordion-1a2b3c4d.js`）ため、ファイル名は `(-[0-9a-f]+)?\.js` で照合する。

### [2-1] チケット画面にアコーディオン用クラスが出力される

孫チケットを持つ親チケット（`{ParentId}`）にだけアコーディオンが付き、孫の無い親チケット（`{CoreParentId}`）には付かない。

**確認方法:**
```powershell
$BaseUrl = '{BaseUrl}'
function Login($login, $password) {
    $s = $null
    $page = Invoke-WebRequest -Uri "$BaseUrl/login" -SessionVariable s -UseBasicParsing
    $token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
    $body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString($login))&password=$([uri]::EscapeDataString($password))"
    Invoke-WebRequest -Uri "$BaseUrl/login" -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
    $s
}
$s = Login '{UserLogin}' '{UserPassword}'
$acc = (Invoke-WebRequest -Uri "$BaseUrl/issues/{ParentId}" -WebSession $s -UseBasicParsing).Content
$core = (Invoke-WebRequest -Uri "$BaseUrl/issues/{CoreParentId}" -WebSession $s -UseBasicParsing).Content
"accordion: $($acc -match 'accordion_control') core: $($core -match 'accordion_control')"
```

**期待結果:** `accordion: True core: False`

### [2-2] サーバーモード時に JavaScript が読み込まれる

**確認方法:**
```powershell
$BaseUrl = '{BaseUrl}'
$Container = '{Container}'
function Login($login, $password) {
    $s = $null
    $page = Invoke-WebRequest -Uri "$BaseUrl/login" -SessionVariable s -UseBasicParsing
    $token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
    $body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString($login))&password=$([uri]::EscapeDataString($password))"
    Invoke-WebRequest -Uri "$BaseUrl/login" -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
    $s
}
# 何も返らなかったとき（DB が使用中で落ちたときなど）は 3 回までやり直す
function Rails([string]$code) {
    for ($n = 0; $n -lt 3; $n++) {
        $r = docker exec -u redmine -w /usr/src/redmine $Container bundle exec rails runner $code 2>$null | Select-Object -Last 1
        if ($r) { return $r }
    }
}
$keys = '%w[subtask_list_accordion_enable_server_scripting_mode subtask_list_accordion_expand_all subtask_list_accordion_collapsed_tracker_ids]'
function SetSla([string]$assign) { Rails "s = Setting.plugin_redmine_studio_plugin.dup; $assign; Setting.plugin_redmine_studio_plugin = s; puts 'set'" | Out-Null }
$orig = Rails "puts [Setting.plugin_redmine_studio_plugin.slice(*$keys).to_json].pack('m0')"
if (-not $orig) { throw '設定を読めなかった' }
try {
    SetSla "s['subtask_list_accordion_enable_server_scripting_mode'] = true"
    $s = Login '{UserLogin}' '{UserPassword}'
    $html = (Invoke-WebRequest -Uri "$BaseUrl/issues/{ParentId}" -WebSession $s -UseBasicParsing).Content
    "server_js: $($html -match 'subtask_list_accordion(-[0-9a-f]+)?\.js') client_js: $($html -match 'subtask_list_accordion_client(-[0-9a-f]+)?\.js')"
} finally {
    Rails "o = JSON.parse('$orig'.unpack1('m0')); s = Setting.plugin_redmine_studio_plugin.dup; $keys.each { |k| if o.key?(k) then s[k] = o[k] else s.delete(k) end }; Setting.plugin_redmine_studio_plugin = s; puts 'restored'"
}
```

**期待結果:**
- `server_js: True client_js: False`（サーバーモード有効時）
- 最後に `restored`

### [2-3] コンテキストメニューにアコーディオン項目が含まれる

チケット画面かどうかは `back_url` の `/issues/{ID}` で判定するため、`back_url` を渡す。チケット画面以外（`back_url=/issues`）では出ない。

**確認方法:**
```powershell
$BaseUrl = '{BaseUrl}'
function Login($login, $password) {
    $s = $null
    $page = Invoke-WebRequest -Uri "$BaseUrl/login" -SessionVariable s -UseBasicParsing
    $token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
    $body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString($login))&password=$([uri]::EscapeDataString($password))"
    Invoke-WebRequest -Uri "$BaseUrl/login" -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
    $s
}
$s = Login '{UserLogin}' '{UserPassword}'
$onIssue = (Invoke-WebRequest -Uri "$BaseUrl/issues/context_menu?ids[]={Child1Id}&back_url=/issues/{ParentId}" -WebSession $s -UseBasicParsing).Content
$onList = (Invoke-WebRequest -Uri "$BaseUrl/issues/context_menu?ids[]={Child1Id}&back_url=/issues" -WebSession $s -UseBasicParsing).Content
"issue_page: $($onIssue -match 'selectedTreeOpen') list_page: $($onList -match 'selectedTreeOpen')"
```

**期待結果:** `issue_page: True list_page: False`

### [2-4] 管理画面でプラグイン設定が表示される

**確認方法:**
```powershell
$BaseUrl = '{BaseUrl}'
function Login($login, $password) {
    $s = $null
    $page = Invoke-WebRequest -Uri "$BaseUrl/login" -SessionVariable s -UseBasicParsing
    $token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
    $body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString($login))&password=$([uri]::EscapeDataString($password))"
    Invoke-WebRequest -Uri "$BaseUrl/login" -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
    $s
}
$s = Login '{Username}' '{Password}'
$response = Invoke-WebRequest -Uri "$BaseUrl/settings/plugin/redmine_studio_plugin" -WebSession $s -UseBasicParsing -MaximumRedirection 0 -SkipHttpErrorCheck
$response.StatusCode
```

**期待結果:** `200`

### [2-5] プラグイン設定画面のフォーム要素確認

**確認方法:**
```powershell
$BaseUrl = '{BaseUrl}'
function Login($login, $password) {
    $s = $null
    $page = Invoke-WebRequest -Uri "$BaseUrl/login" -SessionVariable s -UseBasicParsing
    $token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
    $body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString($login))&password=$([uri]::EscapeDataString($password))"
    Invoke-WebRequest -Uri "$BaseUrl/login" -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
    $s
}
$s = Login '{Username}' '{Password}'
$html = (Invoke-WebRequest -Uri "$BaseUrl/settings/plugin/redmine_studio_plugin" -WebSession $s -UseBasicParsing).Content
# サーバースクリプトモード設定・デフォルト展開設定・収縮させるトラッカー設定（複数選択リスト）
"server_mode: $($html -match 'subtask_list_accordion_enable_server_scripting_mode')"
"expand_all: $($html -match 'subtask_list_accordion_expand_all')"
"collapsed_trackers: $($html -match 'subtask_list_accordion_collapsed_tracker_ids')"
```

**期待結果:** すべて `True`

### [2-6] 個人設定画面のフォーム要素確認

**確認方法:**
```powershell
$BaseUrl = '{BaseUrl}'
function Login($login, $password) {
    $s = $null
    $page = Invoke-WebRequest -Uri "$BaseUrl/login" -SessionVariable s -UseBasicParsing
    $token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
    $body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString($login))&password=$([uri]::EscapeDataString($password))"
    Invoke-WebRequest -Uri "$BaseUrl/login" -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
    $s
}
$s = Login '{UserLogin}' '{UserPassword}'
$response = Invoke-WebRequest -Uri "$BaseUrl/my/account" -WebSession $s -UseBasicParsing
$response.Content -match 'subtasks_default_expand_limit_upper'
```

**期待結果:** `True`

### [2-7] 収縮させるトラッカー設定の動作確認

`subtask_list_accordion_expand_all` を `true` にしたうえで、`subtask_list_accordion_collapsed_tracker_ids` を次の 3 とおりに変え、親チケット（`{ParentId}`）の子チケット行のクラスを見る。

- テストケース A: 空
- テストケース B: 1 件（1 つ目のトラッカー `{Tracker1Id}`。子 1 がこのトラッカー）
- テストケース C: 複数件（1 つ目・2 つ目のトラッカー。子 1・子 2 がこのトラッカー）

**確認方法:**
```powershell
$BaseUrl = '{BaseUrl}'
$Container = '{Container}'
function Login($login, $password) {
    $s = $null
    $page = Invoke-WebRequest -Uri "$BaseUrl/login" -SessionVariable s -UseBasicParsing
    $token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
    $body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString($login))&password=$([uri]::EscapeDataString($password))"
    Invoke-WebRequest -Uri "$BaseUrl/login" -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
    $s
}
function RowClass($html, $id) {
    # 6.0 以降は id="issue-N"、5.x は class の中の issue-N で行を見分ける
    $tag = [regex]::Match($html, "<tr [^>]*\bissue-$id\b[^>]*>").Value
    if ($tag -match 'class="[^"]*\bcollapse\b') { 'collapse' } elseif ($tag -match 'class="[^"]*\bexpand\b') { 'expand' } else { 'none' }
}
# 何も返らなかったとき（DB が使用中で落ちたときなど）は 3 回までやり直す
function Rails([string]$code) {
    for ($n = 0; $n -lt 3; $n++) {
        $r = docker exec -u redmine -w /usr/src/redmine $Container bundle exec rails runner $code 2>$null | Select-Object -Last 1
        if ($r) { return $r }
    }
}
$keys = '%w[subtask_list_accordion_enable_server_scripting_mode subtask_list_accordion_expand_all subtask_list_accordion_collapsed_tracker_ids]'
function SetSla([string]$assign) { Rails "s = Setting.plugin_redmine_studio_plugin.dup; $assign; Setting.plugin_redmine_studio_plugin = s; puts 'set'" | Out-Null }
$orig = Rails "puts [Setting.plugin_redmine_studio_plugin.slice(*$keys).to_json].pack('m0')"
if (-not $orig) { throw '設定を読めなかった' }
try {
    $s = Login '{UserLogin}' '{UserPassword}'
    function Rows() {
        $html = (Invoke-WebRequest -Uri "$BaseUrl/issues/{ParentId}" -WebSession $s -UseBasicParsing).Content
        "child1=$(RowClass $html {Child1Id}) child2=$(RowClass $html {Child2Id}) child3=$(RowClass $html {Child3Id})"
    }
    $base = "s['subtask_list_accordion_enable_server_scripting_mode'] = true; s['subtask_list_accordion_expand_all'] = true"
    SetSla "$base; s['subtask_list_accordion_collapsed_tracker_ids'] = []"
    "A: $(Rows)"
    SetSla "$base; s['subtask_list_accordion_collapsed_tracker_ids'] = ['{Tracker1Id}']"
    "B: $(Rows)"
    SetSla "$base; s['subtask_list_accordion_collapsed_tracker_ids'] = ['{Tracker1Id}', '{Tracker2Id}']"
    "C: $(Rows)"
} finally {
    Rails "o = JSON.parse('$orig'.unpack1('m0')); s = Setting.plugin_redmine_studio_plugin.dup; $keys.each { |k| if o.key?(k) then s[k] = o[k] else s.delete(k) end }; Setting.plugin_redmine_studio_plugin = s; puts 'restored'"
}
```

**期待結果:**
- `A: child1=expand child2=expand child3=expand`（収縮対象なし）
- `B: child1=collapse child2=expand child3=expand`（対象トラッカーの子だけ `collapse`、対象外は `expand`）
- `C: child1=collapse child2=collapse child3=expand`（指定した複数のトラッカーの子がすべて `collapse`、対象外は `expand`）
- 最後に `restored`

### [2-8] デフォルト展開設定の動作確認

親チケット（`{ParentId}`）の子孫は 4 件（子 3 件＋孫 1 件）。次の 4 とおりで、子チケット（子 1）の行のクラスを見る。
ユーザー設定 `subtasks_default_expand_limit_upper` は、用意で作ったユーザーのものを変える（後片付けでユーザーごと消える）。

- テストケース A: `expand_all=true`、`collapsed_tracker_ids` は空
- テストケース B: `expand_all=false`、上限 100（子孫の数が上限以下）
- テストケース C: `expand_all=false`、上限 1（子孫の数が上限超過）
- テストケース D: `expand_all=false`、上限 0

**確認方法:**
```powershell
$BaseUrl = '{BaseUrl}'
$Container = '{Container}'
function Login($login, $password) {
    $s = $null
    $page = Invoke-WebRequest -Uri "$BaseUrl/login" -SessionVariable s -UseBasicParsing
    $token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
    $body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString($login))&password=$([uri]::EscapeDataString($password))"
    Invoke-WebRequest -Uri "$BaseUrl/login" -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
    $s
}
function RowClass($html, $id) {
    # 6.0 以降は id="issue-N"、5.x は class の中の issue-N で行を見分ける
    $tag = [regex]::Match($html, "<tr [^>]*\bissue-$id\b[^>]*>").Value
    if ($tag -match 'class="[^"]*\bcollapse\b') { 'collapse' } elseif ($tag -match 'class="[^"]*\bexpand\b') { 'expand' } else { 'none' }
}
# 何も返らなかったとき（DB が使用中で落ちたときなど）は 3 回までやり直す
function Rails([string]$code) {
    for ($n = 0; $n -lt 3; $n++) {
        $r = docker exec -u redmine -w /usr/src/redmine $Container bundle exec rails runner $code 2>$null | Select-Object -Last 1
        if ($r) { return $r }
    }
}
$keys = '%w[subtask_list_accordion_enable_server_scripting_mode subtask_list_accordion_expand_all subtask_list_accordion_collapsed_tracker_ids]'
function SetSla([string]$assign) { Rails "s = Setting.plugin_redmine_studio_plugin.dup; $assign; Setting.plugin_redmine_studio_plugin = s; puts 'set'" | Out-Null }
function SetLimit([int]$n) { Rails "p = User.find_by!(login: '{UserLogin}').pref; p.subtasks_default_expand_limit_upper = $n; p.save!; puts 'set'" | Out-Null }
$orig = Rails "puts [Setting.plugin_redmine_studio_plugin.slice(*$keys).to_json].pack('m0')"
if (-not $orig) { throw '設定を読めなかった' }
try {
    $s = Login '{UserLogin}' '{UserPassword}'
    function Child1() { RowClass (Invoke-WebRequest -Uri "$BaseUrl/issues/{ParentId}" -WebSession $s -UseBasicParsing).Content {Child1Id} }
    $server = "s['subtask_list_accordion_enable_server_scripting_mode'] = true"
    SetSla "$server; s['subtask_list_accordion_expand_all'] = true; s['subtask_list_accordion_collapsed_tracker_ids'] = []"
    "A: $(Child1)"
    SetSla "$server; s['subtask_list_accordion_expand_all'] = false"
    SetLimit 100
    "B: $(Child1)"
    SetLimit 1
    "C: $(Child1)"
    SetLimit 0
    "D: $(Child1)"
} finally {
    Rails "o = JSON.parse('$orig'.unpack1('m0')); s = Setting.plugin_redmine_studio_plugin.dup; $keys.each { |k| if o.key?(k) then s[k] = o[k] else s.delete(k) end }; Setting.plugin_redmine_studio_plugin = s; puts 'restored'"
}
```

**期待結果:**
- `A: expand`（すべての子チケットが `expand`）
- `B: expand`（子孫の数が上限以下）
- `C: collapse`（子孫の数が上限超過）
- `D: collapse`（上限 0 のため、子チケットが 1 件以上あれば常に折りたたみ）
- 最後に `restored`

### [2-9] サーバーモード無効時の動作確認

**確認方法:**
```powershell
$BaseUrl = '{BaseUrl}'
$Container = '{Container}'
function Login($login, $password) {
    $s = $null
    $page = Invoke-WebRequest -Uri "$BaseUrl/login" -SessionVariable s -UseBasicParsing
    $token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
    $body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString($login))&password=$([uri]::EscapeDataString($password))"
    Invoke-WebRequest -Uri "$BaseUrl/login" -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
    $s
}
# 何も返らなかったとき（DB が使用中で落ちたときなど）は 3 回までやり直す
function Rails([string]$code) {
    for ($n = 0; $n -lt 3; $n++) {
        $r = docker exec -u redmine -w /usr/src/redmine $Container bundle exec rails runner $code 2>$null | Select-Object -Last 1
        if ($r) { return $r }
    }
}
$keys = '%w[subtask_list_accordion_enable_server_scripting_mode subtask_list_accordion_expand_all subtask_list_accordion_collapsed_tracker_ids]'
function SetSla([string]$assign) { Rails "s = Setting.plugin_redmine_studio_plugin.dup; $assign; Setting.plugin_redmine_studio_plugin = s; puts 'set'" | Out-Null }
$orig = Rails "puts [Setting.plugin_redmine_studio_plugin.slice(*$keys).to_json].pack('m0')"
if (-not $orig) { throw '設定を読めなかった' }
try {
    SetSla "s['subtask_list_accordion_enable_server_scripting_mode'] = false"
    $s = Login '{UserLogin}' '{UserPassword}'
    $html = (Invoke-WebRequest -Uri "$BaseUrl/issues/{ParentId}" -WebSession $s -UseBasicParsing).Content
    # クライアントモードの JS が読み込まれ、サーバーモード用の JS は読み込まれない
    "client_js: $($html -match 'subtask_list_accordion_client(-[0-9a-f]+)?\.js') server_js: $($html -match 'subtask_list_accordion(-[0-9a-f]+)?\.js')"
} finally {
    Rails "o = JSON.parse('$orig'.unpack1('m0')); s = Setting.plugin_redmine_studio_plugin.dup; $keys.each { |k| if o.key?(k) then s[k] = o[k] else s.delete(k) end }; Setting.plugin_redmine_studio_plugin = s; puts 'restored'"
}
```

**期待結果:**
- `client_js: True server_js: False`
- 最後に `restored`

### [2-10] 子チケット一覧がコアの表示設定に追随する

アコーディオンの一覧はコアの描画（`render_descendants_tree`）を後加工して出力するため、
列・ヘッダ行・ボタン列は常にコアと一致する。サーバーモードを有効にして、次の 3 つを確かめる。

- テストケース B: 列構成がコア描画と一致する。孫ありの親チケット（`{ParentId}`、アコーディオン描画）と子のみの親チケット（`{CoreParentId}`、コア描画）の子チケット一覧（`#issue_tree` 内）の td クラスの種類を比べる
- テストケース C: アコーディオン属性（`cs` / `ce` / `rank`・`treearrow`）が付く
- テストケース A: 表示設定の反映（Redmine 6.0 以降のみ）。関連チケット一覧の表示設定（ヘッダ行あり・列は status / priority / assigned_to）に変えると、ヘッダ行と設定どおりの列が出る。設定は `finally` で元の値に戻す

**確認方法:**
```powershell
$BaseUrl = '{BaseUrl}'
$Container = '{Container}'
function Login($login, $password) {
    $s = $null
    $page = Invoke-WebRequest -Uri "$BaseUrl/login" -SessionVariable s -UseBasicParsing
    $token = [regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
    $body = "authenticity_token=$([uri]::EscapeDataString([Net.WebUtility]::HtmlDecode($token)))&username=$([uri]::EscapeDataString($login))&password=$([uri]::EscapeDataString($password))"
    Invoke-WebRequest -Uri "$BaseUrl/login" -Method Post -Body $body -WebSession $s -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' | Out-Null
    $s
}
# 何も返らなかったとき（DB が使用中で落ちたときなど）は 3 回までやり直す
function Rails([string]$code) {
    for ($n = 0; $n -lt 3; $n++) {
        $r = docker exec -u redmine -w /usr/src/redmine $Container bundle exec rails runner $code 2>$null | Select-Object -Last 1
        if ($r) { return $r }
    }
}
$keys = '%w[subtask_list_accordion_enable_server_scripting_mode subtask_list_accordion_expand_all subtask_list_accordion_collapsed_tracker_ids]'
function SetSla([string]$assign) { Rails "s = Setting.plugin_redmine_studio_plugin.dup; $assign; Setting.plugin_redmine_studio_plugin = s; puts 'set'" | Out-Null }
$orig = Rails "puts [Setting.plugin_redmine_studio_plugin.slice(*$keys).to_json].pack('m0')"
if (-not $orig) { throw '設定を読めなかった' }
# 関連チケット一覧の表示設定（Redmine 6.0 以降だけにある。無い版は none）
$origCore = Rails "puts Setting.respond_to?(:related_issues_default_columns) ? [{ h: Setting.display_related_issues_table_headers, c: Setting.related_issues_default_columns }.to_json].pack('m0') : 'none'"
try {
    SetSla "s['subtask_list_accordion_enable_server_scripting_mode'] = true"
    $s = Login '{UserLogin}' '{UserPassword}'
    function Page($id) { (Invoke-WebRequest -Uri "$BaseUrl/issues/$id" -WebSession $s -UseBasicParsing).Content }
    # 子チケット一覧（#issue_tree の form の中）の td class の種類
    function TreeCols($html) {
        $i = $html.IndexOf('id="issue_tree"'); $j = $html.IndexOf('</form>', $i)
        [regex]::Matches($html.Substring($i, $j - $i), '<td class="([^"]*)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    }
    $acc = Page {ParentId}
    $accCols = TreeCols $acc
    $coreCols = TreeCols (Page {CoreParentId})
    "B: same_columns=$($null -eq (Compare-Object $accCols $coreCols)) columns=$($accCols -join ',')"
    "C: attrs=$($acc -match ' cs="\d+" ce="\d+" rank="\d+"') treearrow=$($acc -match 'span class="treearrow"')"
    if ($origCore -eq 'none') {
        'A: SKIP（Redmine 6.0 より前）'
    } else {
        Rails "Setting.display_related_issues_table_headers = 1; Setting.related_issues_default_columns = %w[status priority assigned_to]; puts 'set'" | Out-Null
        $html = Page {ParentId}
        "A: thead=$($html -match 'thead class="related-issues"') priority=$($html -match 'td class="priority')"
    }
} finally {
    if ($origCore -and $origCore -ne 'none') {
        Rails "o = JSON.parse('$origCore'.unpack1('m0')); Setting.display_related_issues_table_headers = o['h']; Setting.related_issues_default_columns = o['c']; puts 'restored'"
    }
    Rails "o = JSON.parse('$orig'.unpack1('m0')); s = Setting.plugin_redmine_studio_plugin.dup; $keys.each { |k| if o.key?(k) then s[k] = o[k] else s.delete(k) end }; Setting.plugin_redmine_studio_plugin = s; puts 'restored'"
}
```

**期待結果:**
- `B: same_columns=True`（差分なし。Redmine 5.x では両者とも start_date / due_date 列を含む固定列）
- `C: attrs=True treearrow=True`
- `A: thead=True priority=True`（Redmine 6.0 以降。5.x は `A: SKIP`）
- 最後に `restored`（6.0 以降は 2 行）

---

## 3. ブラウザテスト

### セットアップデータ

**チケット構造:**

| チケット | 親チケット | subject |
|---------|-----------|---------|
| 親1 | - | SLA_BrowserTest_Parent1 |
| 子1-1 | 親1 | SLA_BrowserTest_Child1-1 |
| 子1-2 | 親1 | SLA_BrowserTest_Child1-2 |
| 孫1-1-1 | 子1-1 | SLA_BrowserTest_Grandchild1-1-1 |

### [3-1] アコーディオン展開/折りたたみ操作

**手順:**
1. admin でログイン
2. 親チケット1を開く
3. 子チケット1-1 の左にある矢印アイコンをクリック

**確認1:** 孫チケット1-1-1 が非表示になる

4. 再度矢印アイコンをクリック

**確認2:** 孫チケット1-1-1 が表示される

5. 「すべて展開」リンクをクリック

**確認3:** すべてのサブタスク（子1-1, 子1-2, 孫1-1-1）が表示される

6. 「すべて収縮」リンクをクリック

**確認4:** 孫チケットが非表示になる（子チケットは表示されたまま）

### [3-2] コンテキストメニューからの展開/折りたたみ

**手順:**
1. admin でログイン
2. 親チケット1を開く
3. サブタスク一覧で子チケット1-1 のチェックボックスにチェックを入れる
4. 子チケット1-1 を右クリック
5. 「この階層をすべて展開」をクリック

**確認1:** 子チケット1-1 配下のすべてのチケット（孫1-1-1）が展開される

6. 再度子チケット1-1 を右クリック
7. 「このツリーを収縮」をクリック

**確認2:** 子チケット1-1 配下のチケット（孫1-1-1）が非表示になる
