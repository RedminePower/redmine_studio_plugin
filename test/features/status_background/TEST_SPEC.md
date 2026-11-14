# Status Background テスト仕様書

## 概要

redmine_studio_plugin の Status Background 機能のテスト仕様。

チケットの詳細画面で、説明などの枠（`div.issue`）の背景を、ステータスに合わせた色にする機能をテストする。入れただけでは何も変わらず（初期値は無効）、管理者が有効にすると、色を選んでいなければ終了扱いのステータスだけ薄いグレーになる。

対象バージョン: 5.x / 6.x / 7.x

接続先・認証情報・コンテナ名は実行環境から注入する（プレースホルダの契約は `test/README.md`）。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| 設定画面 | 管理 → プラグイン → Redmine Studio plugin の設定（`settings/status_background/_settings`） |
| フック | `view_layouts_base_html_head`（チケット詳細画面だけ `<style>` を入れる） |
| CSS を作る処理 | `RedmineStudioPlugin::StatusBackground::StyleBuilder` |
| 当てる先 | `div.issue.details.status-{ステータスID}`（Redmine がチケット詳細の枠に付けるクラス） |

---

## 設定項目一覧

| 項目 | 設定キー | 値 |
|------|----------|-----|
| 背景色を変える | `status_background_enabled` | `'true'` / `'false'`。初期値は無効。キーが無いとき（この機能より前に設定を保存した環境）も無効として扱う |
| ステータスごとの背景色 | `status_background_colors` | ステータス ID → `''`（変えない）/ 候補の色（`#f2f2f2` `#e8f1fb` `#e9f5e9` `#fbeaea`）/ `'custom'`。ID が無いときは、終了扱いなら `#f2f2f2`、それ以外は変えない |
| 指定した色 | `status_background_custom_colors` | ステータス ID → `#rrggbb`。`'custom'` を選んだときだけ使う |

候補にない値・`#rrggbb` の形でない値は使わない（CSS に入れない）。

---

## テスト実行フロー

### フェーズ 0: Runner テストの流し方

Puma は止めずに、動かしたまま Runner テストを流す。公式 Docker イメージでは Puma がコンテナの PID 1 なので、止めるとコンテナごと止まり、`docker exec` が使えなくなる。

各バッチの Ruby スクリプトはファイルにしてコンテナにコピーし、`redmine` 利用者で実行する。`bash -c "... rails runner '...'"` の形でコードを直接渡すと、`!` や引用符の扱いで壊れやすい。

```bash
docker cp batch1.rb {Container}:/tmp/status_background_batch1.rb
docker exec -u redmine -w /usr/src/redmine {Container} bundle exec rails runner /tmp/status_background_batch1.rb
```

- `bash` のブロックは bash で流す（Windows では Git Bash で、`MSYS_NO_PATHCONV=1` を付ける。付けないと `/usr/src/redmine` や `/tmp/...` が Windows のパスに書き換わる）
- `-u redmine` を付けずに root で動かすと、ログや `files` の中に root の持ち物のファイルができ、あとで Redmine から書けなくなることがある。root が要る手順だけ `-u` を付けずに行う
- `SQLite3::BusyException`（database is locked）が出たときは、少し待ってそのバッチを流し直す

### フェーズ 1: Runner テスト

- [1-1] 〜 [1-9] を1つのスクリプトにまとめて実行する。DB は書き換えない（設定はハッシュで渡す）

### フェーズ 2: ブラウザテスト（初期状態と有効化）

コンテナの再起動は要らない（Runner テストは DB を書き換えない）。

- [3-1] をブラウザで確認する。終了扱いのステータスのチケットと、そうでないチケットを1件ずつ使う（無ければ作る）
- テストの前の「背景色を変える」の状態を控えておく

### フェーズ 3: HTTP テスト

- [2-1] 〜 [2-3] を実行する。用意で「背景色を変える」を有効にし、後片付けで元に戻す（[3-1] の状態に頼らない）

### フェーズ 4: ブラウザテスト（色の選択・無効化・再オープン）

- [3-2] 〜 [3-4] をブラウザで確認する
- 終わったら、「背景色を変える」と色の選択をテストの前の状態に戻す

---

## 1. Runner テスト

[1-3] 〜 [1-9] は、各試験の頭で、試験用のステータス（ID 901 の終了扱いでないもの・ID 902 の終了扱いのもの。DB には保存しない）を作る。

### [1-1] フック登録確認

```ruby
puts Redmine::Hook.hook_listeners(:view_layouts_base_html_head).map(&:class).map(&:name).include?('RedmineStudioPlugin::StatusBackground::Hooks')
```

**期待結果:** `true`

### [1-2] 初期値の確認

```ruby
defaults = Redmine::Plugin.find(:redmine_studio_plugin).settings[:default]
puts defaults['status_background_enabled'] == false
puts defaults['status_background_colors'] == {}
puts defaults['status_background_custom_colors'] == {}
```

**期待結果:** すべて `true`

### [1-3] 有効にして色を選んでいないと、終了扱いだけ薄いグレー

```ruby
# 試験用のステータス（DB には保存しない）
b = RedmineStudioPlugin::StatusBackground::StyleBuilder
open_status = IssueStatus.new(name: 'open'); open_status.id = 901; open_status.is_closed = false
closed_status = IssueStatus.new(name: 'closed'); closed_status.id = 902; closed_status.is_closed = true
statuses = [open_status, closed_status]
puts b.css({ 'status_background_enabled' => 'true' }, statuses)
```

**期待結果:** `div.issue.details.status-902 { background-color: #f2f2f2; border-color: #d5d5d5; }` の1行だけ（status-901 は出ない）

### [1-4] 初期値と、設定の項目が無い環境では無効

この機能より前に設定を保存した環境では、`status_background_enabled` のキーが無い。入れただけ・上げただけで全員の画面が変わらないよう、どちらも無効にする。

```ruby
# 試験用のステータス（DB には保存しない）
b = RedmineStudioPlugin::StatusBackground::StyleBuilder
open_status = IssueStatus.new(name: 'open'); open_status.id = 901; open_status.is_closed = false
closed_status = IssueStatus.new(name: 'closed'); closed_status.id = 902; closed_status.is_closed = true
statuses = [open_status, closed_status]
puts b.enabled?({ 'status_background_enabled' => false })
puts b.enabled?({ 'subtask_list_accordion_expand_all' => false })
puts b.css({ 'subtask_list_accordion_expand_all' => false }, statuses).empty?
```

**期待結果:** `false`、`false`、`true`

### [1-5] 無効にすると CSS を出さない

```ruby
# 試験用のステータス（DB には保存しない）
b = RedmineStudioPlugin::StatusBackground::StyleBuilder
open_status = IssueStatus.new(name: 'open'); open_status.id = 901; open_status.is_closed = false
closed_status = IssueStatus.new(name: 'closed'); closed_status.id = 902; closed_status.is_closed = true
statuses = [open_status, closed_status]
puts b.css({ 'status_background_enabled' => 'false' }, statuses).empty?
```

**期待結果:** `true`

### [1-6] 候補の色と「変えない」

```ruby
# 試験用のステータス（DB には保存しない）
b = RedmineStudioPlugin::StatusBackground::StyleBuilder
open_status = IssueStatus.new(name: 'open'); open_status.id = 901; open_status.is_closed = false
closed_status = IssueStatus.new(name: 'closed'); closed_status.id = 902; closed_status.is_closed = true
statuses = [open_status, closed_status]
settings = { 'status_background_enabled' => 'true',
             'status_background_colors' => { '901' => '#e8f1fb', '902' => '' } }
puts b.css(settings, statuses)
```

**期待結果:** `div.issue.details.status-901 { background-color: #e8f1fb; border-color: #ccd4dd; }` の1行だけ（終了扱いでも「変えない」なら出ない）

### [1-7] 色を指定

```ruby
# 試験用のステータス（DB には保存しない）
b = RedmineStudioPlugin::StatusBackground::StyleBuilder
open_status = IssueStatus.new(name: 'open'); open_status.id = 901; open_status.is_closed = false
closed_status = IssueStatus.new(name: 'closed'); closed_status.id = 902; closed_status.is_closed = true
statuses = [open_status, closed_status]
settings = { 'status_background_enabled' => 'true',
             'status_background_colors' => { '902' => 'custom' },
             'status_background_custom_colors' => { '902' => '#FFE8CC' } }
puts b.color_for(settings, closed_status)
```

**期待結果:** `#ffe8cc`

### [1-8] 形の正しくない値は使わない

```ruby
# 試験用のステータス（DB には保存しない）
b = RedmineStudioPlugin::StatusBackground::StyleBuilder
open_status = IssueStatus.new(name: 'open'); open_status.id = 901; open_status.is_closed = false
closed_status = IssueStatus.new(name: 'closed'); closed_status.id = 902; closed_status.is_closed = true
statuses = [open_status, closed_status]
settings = { 'status_background_enabled' => 'true',
             'status_background_colors' => { '901' => 'red; } body { display: none', '902' => 'custom' },
             'status_background_custom_colors' => { '902' => 'red' } }
puts b.color_for(settings, open_status).inspect
puts b.color_for(settings, closed_status)
puts b.css(settings, statuses).include?('body')
```

**期待結果:** `nil`、`#f2f2f2`（指定した色が正しくないときは薄いグレー）、`false`

### [1-9] 設定画面の選択肢の初期値

```ruby
# 試験用のステータス（DB には保存しない）
b = RedmineStudioPlugin::StatusBackground::StyleBuilder
open_status = IssueStatus.new(name: 'open'); open_status.id = 901; open_status.is_closed = false
closed_status = IssueStatus.new(name: 'closed'); closed_status.id = 902; closed_status.is_closed = true
statuses = [open_status, closed_status]
puts b.choice_for({}, open_status).inspect
puts b.choice_for({}, closed_status)
puts b.custom_color_for({}, closed_status)
```

**期待結果:** `""`、`#f2f2f2`、`#f2f2f2`

---

## 2. HTTP テスト

**実行方法:** 各ブロックを PowerShell で流す。各ブロックの頭で、管理者でログインしたセッション（`$session`）を作る（ログイン画面の `authenticity_token` を取り、`{Username}` / `{Password}` で POST する）。

**用意（HTTP テストの前に 1 回）:**
終了扱いのステータスのチケットを Runner で作り、「背景色を変える」を有効にする（前回の残りがあれば、先に設定を戻してから消す）。
そのステータスの色の選択は外して、初期の色（薄いグレー）にする。変える前の設定は、作ったプロジェクトの説明に控えておき、後片付けで戻す。
最後の行の `ClosedIssueId`・`ClosedStatusId` を、各試験の `{ClosedIssueId}`・`{ClosedStatusId}` に入れる。

```ruby
admin = User.find(1)
User.current = admin
keys = %w[status_background_enabled status_background_colors]
# 前回の残りがあれば、いちばん古いものに控えた設定に戻してから消す
left = Project.where('identifier LIKE ?', 'sb-http-%').order(:id).to_a
if left.any?
  s = Setting.plugin_redmine_studio_plugin.to_h.dup
  JSON.parse(left.first.description).each { |k, v| v.nil? ? s.delete(k) : s[k] = v }
  Setting.plugin_redmine_studio_plugin = s
  left.each(&:destroy)
end
current = Setting.plugin_redmine_studio_plugin.to_h
saved = keys.to_h { |k| [k, current.key?(k) ? current[k] : nil] }
sfx = SecureRandom.hex(3)
closed = IssueStatus.where(is_closed: true).order(:position).first
pr = Project.new(name: "SB_HTTP_#{sfx}", identifier: "sb-http-#{sfx}", description: saved.to_json)
pr.enabled_module_names = %w[issue_tracking]
pr.trackers = [Tracker.first]
pr.save!
issue = Issue.create!(project: pr, tracker: pr.trackers.first, subject: "SB_HTTP_closed_#{sfx}", author: admin)
# ワークフローに左右されないよう、ステータスは直接書く
Issue.where(id: issue.id).update_all(status_id: closed.id)
s = Setting.plugin_redmine_studio_plugin.to_h.dup
colors = (s['status_background_colors'] || {}).to_h.dup
colors.delete(closed.id.to_s)
s['status_background_enabled'] = 'true'
s['status_background_colors'] = colors
Setting.plugin_redmine_studio_plugin = s
puts({ ClosedIssueId: issue.id, ClosedStatusId: closed.id }.to_json)
```

**後片付け（HTTP テストのあとに 1 回）:**
設定を、用意で控えた値に戻してから消す（ほかの項目は今の値のまま）。

```ruby
User.current = User.find(1)
left = Project.where('identifier LIKE ?', 'sb-http-%').order(:id).to_a
if left.any?
  s = Setting.plugin_redmine_studio_plugin.to_h.dup
  JSON.parse(left.first.description).each { |k, v| v.nil? ? s.delete(k) : s[k] = v }
  Setting.plugin_redmine_studio_plugin = s
  left.each(&:destroy)
end
puts Project.where('identifier LIKE ?', 'sb-http-%').count
```

**期待結果（後片付け）:** `0`。「背景色を変える」と色の選択が、用意の前の値に戻っている

### [2-1] 終了扱いのチケットの詳細画面に CSS が入る

```powershell
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable session -UseBasicParsing
$token = [Net.WebUtility]::HtmlDecode([regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value)
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -WebSession $session -UseBasicParsing `
  -Body @{ authenticity_token = $token; username = '{Username}'; password = '{Password}' } | Out-Null
$html = (Invoke-WebRequest -Uri '{BaseUrl}/issues/{ClosedIssueId}' -WebSession $session -UseBasicParsing).Content
$html -match 'div\.issue\.details\.status-{ClosedStatusId} \{ background-color: #f2f2f2;'
$html -match '<div class="issue [^"]*\bstatus-{ClosedStatusId}\b[^"]*\bclosed\b[^"]*\bdetails\b'
```

**期待結果:** 両方 `True`。`div.issue` に `closed` と `status-{ClosedStatusId}` のクラスが付いている

### [2-2] チケット一覧には CSS を入れない

```powershell
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable session -UseBasicParsing
$token = [Net.WebUtility]::HtmlDecode([regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value)
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -WebSession $session -UseBasicParsing `
  -Body @{ authenticity_token = $token; username = '{Username}'; password = '{Password}' } | Out-Null
$html = (Invoke-WebRequest -Uri '{BaseUrl}/issues' -WebSession $session -UseBasicParsing).Content
$html -match 'div\.issue\.details\.status-'
```

**期待結果:** `False`

### [2-3] 設定画面に項目が出る

```powershell
$page = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable session -UseBasicParsing
$token = [Net.WebUtility]::HtmlDecode([regex]::Match($page.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value)
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -WebSession $session -UseBasicParsing `
  -Body @{ authenticity_token = $token; username = '{Username}'; password = '{Password}' } | Out-Null
$html = (Invoke-WebRequest -Uri '{BaseUrl}/settings/plugin/redmine_studio_plugin' -WebSession $session -UseBasicParsing).Content
$html -match 'id="status_background_settings"'
$html -match 'settings\[status_background_colors\]\[\d+\]'
$html -match 'id="sla_expand_all_checkbox"'
```

**期待結果:** すべて `True`（子チケット一覧アコーディオンの設定も同じ画面に残っている）

---

## 3. ブラウザテスト

### [3-1] 入れただけでは変わらず、有効にすると終了したチケットが薄いグレーになる

1. 背景色の設定を一度も保存していない状態で、終了扱いのチケットの詳細画面を開く
2. 設定画面を開く
3. 「背景色を変える」にチェックを入れて「適用」を押す
4. 終了扱いのチケットと、そうでないチケットの詳細画面を開く

**期待結果:**
- 1: 元の色のまま
- 2: 「背景色を変える」にチェックが入っておらず、色の表が薄く表示されている。終了扱いのステータスは「薄いグレー」、それ以外は「(変えない)」が選ばれている
- 4: 終了扱いのチケットは枠の背景が薄いグレー・枠線が少し濃いグレー。そうでないチケットは元の色のまま。文字の色は変わらない

### [3-2] 設定画面で色を選ぶ

設定画面で、終了扱いでないステータスに「薄い青」、終了扱いのステータスに「色を指定」を選び、色を選んで「適用」を押す。

**期待結果:**
- 「色を指定」を選んだ行だけ、色を選ぶ欄が出る。左の色見本が選んだ色に変わる
- 保存後に画面を開き直しても、選んだ値が残っている
- 各ステータスのチケットの詳細画面が、選んだ色になる

### [3-3] 無効にする

「背景色を変える」のチェックを外して「適用」を押す。

**期待結果:**
- チェックを外すと、色の表が薄く表示される
- すべてのチケットの詳細画面が元の色に戻る
- もう一度チェックを入れて保存すると、前に選んだ色に戻る（無効の間も色の選択は保存されている）

### [3-4] 再オープン

終了扱いのチケットを、終了扱いでないステータスに戻す。

**期待結果:** 詳細画面の背景が、戻したステータスの色（色を選んでいなければ元の色）になる
