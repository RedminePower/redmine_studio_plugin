# Status Background テスト仕様書

## 概要

redmine_studio_plugin の Status Background 機能のテスト仕様。

チケットの詳細画面で、説明などの枠（`div.issue`）の背景を、ステータスに合わせた色にする機能をテストする。何も設定しなければ、終了扱いのステータスだけ薄いグレーになる。

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
| 背景色を変える | `status_background_enabled` | `'true'` / `'false'`。キーが無いとき（この機能より前に設定を保存した環境）は有効として扱う |
| ステータスごとの背景色 | `status_background_colors` | ステータス ID → `''`（変えない）/ 候補の色（`#f2f2f2` `#e8f1fb` `#e9f5e9` `#fbeaea`）/ `'custom'`。ID が無いときは、終了扱いなら `#f2f2f2`、それ以外は変えない |
| 指定した色 | `status_background_custom_colors` | ステータス ID → `#rrggbb`。`'custom'` を選んだときだけ使う |

候補にない値・`#rrggbb` の形でない値は使わない（CSS に入れない）。

---

## テスト実行フロー

### フェーズ 0: Puma 停止

```bash
docker exec {Container} bash -c "kill $(cat /usr/src/redmine/tmp/pids/server.pid)"
```

### フェーズ 1: Runner テスト

- [1-1] 〜 [1-9] を1つのスクリプトにまとめて実行する。DB は書き換えない（設定はハッシュで渡す）

### フェーズ 2: コンテナ再起動

```bash
docker restart {Container}
```

### フェーズ 3: HTTP テスト・ブラウザテスト

- [2-1] 〜 [2-3] を実行する。終了扱いのステータスのチケットと、そうでないチケットを1件ずつ使う（無ければ作る）
- [3-1] 〜 [3-4] をブラウザで確認する

---

## 1. Runner テスト

共通の準備:

```ruby
B = RedmineStudioPlugin::StatusBackground::StyleBuilder
open_status = IssueStatus.new(name: 'open'); open_status.id = 901; open_status.is_closed = false
closed_status = IssueStatus.new(name: 'closed'); closed_status.id = 902; closed_status.is_closed = true
statuses = [open_status, closed_status]
```

### [1-1] フック登録確認

```ruby
puts Redmine::Hook.hook_listeners(:view_layouts_base_html_head).map(&:class).map(&:name).include?('RedmineStudioPlugin::StatusBackground::Hooks')
```

**期待結果:** `true`

### [1-2] 初期値の確認

```ruby
defaults = Redmine::Plugin.find(:redmine_studio_plugin).settings[:default]
puts defaults['status_background_enabled'] == true
puts defaults['status_background_colors'] == {}
puts defaults['status_background_custom_colors'] == {}
```

**期待結果:** すべて `true`

### [1-3] 何も設定しないと、終了扱いだけ薄いグレー

```ruby
puts B.css({ 'status_background_enabled' => true }, statuses)
```

**期待結果:** `div.issue.details.status-902 { background-color: #f2f2f2; border-color: #d5d5d5; }` の1行だけ（status-901 は出ない）

### [1-4] 設定の項目が無い環境でも有効になる

この機能より前に設定を保存した環境では、`status_background_enabled` のキーが無い。

```ruby
puts B.enabled?({ 'subtask_list_accordion_expand_all' => false })
puts B.css({ 'subtask_list_accordion_expand_all' => false }, statuses).include?('status-902')
```

**期待結果:** すべて `true`

### [1-5] 無効にすると CSS を出さない

```ruby
puts B.css({ 'status_background_enabled' => 'false' }, statuses).empty?
```

**期待結果:** `true`

### [1-6] 候補の色と「変えない」

```ruby
settings = { 'status_background_enabled' => 'true',
             'status_background_colors' => { '901' => '#e8f1fb', '902' => '' } }
puts B.css(settings, statuses)
```

**期待結果:** `div.issue.details.status-901 { background-color: #e8f1fb; border-color: #ccd4dd; }` の1行だけ（終了扱いでも「変えない」なら出ない）

### [1-7] 色を指定

```ruby
settings = { 'status_background_enabled' => 'true',
             'status_background_colors' => { '902' => 'custom' },
             'status_background_custom_colors' => { '902' => '#FFE8CC' } }
puts B.color_for(settings, closed_status)
```

**期待結果:** `#ffe8cc`

### [1-8] 形の正しくない値は使わない

```ruby
settings = { 'status_background_enabled' => 'true',
             'status_background_colors' => { '901' => 'red; } body { display: none', '902' => 'custom' },
             'status_background_custom_colors' => { '902' => 'red' } }
puts B.color_for(settings, open_status).inspect
puts B.color_for(settings, closed_status)
puts B.css(settings, statuses).include?('body')
```

**期待結果:** `nil`、`#f2f2f2`（指定した色が正しくないときは薄いグレー）、`false`

### [1-9] 設定画面の選択肢の初期値

```ruby
puts B.choice_for({}, open_status).inspect
puts B.choice_for({}, closed_status)
puts B.custom_color_for({}, closed_status)
```

**期待結果:** `""`、`#f2f2f2`、`#f2f2f2`

---

## 2. HTTP テスト

事前に、管理者でログインしたセッションを作る（ログイン画面の `authenticity_token` を取り、`{Username}` / `{Password}` で POST する）。以下の `$session` はそのセッション。

### [2-1] 終了扱いのチケットの詳細画面に CSS が入る

```powershell
$html = (Invoke-WebRequest -Uri '{BaseUrl}/issues/{終了扱いのチケットID}' -WebSession $session -UseBasicParsing).Content
$html -match 'div\.issue\.details\.status-\d+ \{ background-color: #f2f2f2;'
```

**期待結果:** `True`。`div.issue` に `closed` と `status-{ID}` のクラスが付いている

### [2-2] チケット一覧には CSS を入れない

```powershell
$html = (Invoke-WebRequest -Uri '{BaseUrl}/issues' -WebSession $session -UseBasicParsing).Content
$html -match 'div\.issue\.details\.status-'
```

**期待結果:** `False`

### [2-3] 設定画面に項目が出る

```powershell
$html = (Invoke-WebRequest -Uri '{BaseUrl}/settings/plugin/redmine_studio_plugin' -WebSession $session -UseBasicParsing).Content
$html -match 'id="status_background_settings"'
$html -match 'settings\[status_background_colors\]\[\d+\]'
$html -match 'id="sla_expand_all_checkbox"'
```

**期待結果:** すべて `True`（子チケット一覧アコーディオンの設定も同じ画面に残っている）

---

## 3. ブラウザテスト

### [3-1] 入れただけで、終了したチケットが薄いグレーになる

設定を一度も変えていない状態で、終了扱いのチケットと、そうでないチケットの詳細画面を開く。

**期待結果:** 終了扱いのチケットは枠の背景が薄いグレー・枠線が少し濃いグレー。そうでないチケットは元の色のまま。文字の色は変わらない

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

**期待結果:** 詳細画面の背景が、戻したステータスの色（何も設定していなければ元の色）になる
