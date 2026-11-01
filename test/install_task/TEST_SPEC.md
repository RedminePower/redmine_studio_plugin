# Install Task テスト仕様書

## 概要

`rake redmine_studio_plugin:install` タスクのテスト仕様。
このタスクは以下の 4 つの処理を一括で行う:

1. 旧プラグインからの設定移行
2. 統合済みプラグインの削除（旧スタンドアロン版）
3. DB マイグレーション
4. cron 登録

本テストでは主に「設定移行」と「統合済みプラグインの削除」機能を検証する。
DB マイグレーションと cron 登録のテストは `features/auto_close/TEST_SPEC.md` の [2-I] セクションを参照。

対象バージョン: 5.x / 6.x / 7.x

## 環境パラメータ

`{Container}`・`{RedmineRoot}` は実行環境から注入する（プレースホルダの契約は `test/README.md`）。
プラグインがコンテナの中にしか無い環境では `{RedmineRoot}` は空になる。その場合は、各フェーズの「コンテナの中で行う」書き方を使う。

## タスクの内部実装

| 項目 | 値 |
|------|-----|
| ファイル | `lib/tasks/install.rake` |
| タスク名 | `redmine_studio_plugin:install` |
| 統合済みプラグイン | `config/integrated_plugins.yml` を参照 |

### 処理フロー

1. ログ出力: `[redmine_studio_plugin] Install task started`
2. [1/4] 旧プラグインからの設定移行
3. [2/4] 統合済みプラグインのフォルダを確認・削除
4. [3/4] DB マイグレーション実行
5. [4/4] cron 登録
6. ログ出力: `[redmine_studio_plugin] Install task completed`

### 出力メッセージ

| 条件 | stdout 出力 |
|------|-------------|
| 設定移行あり | `redmine_subtask_list_accordion: Migrated N setting(s): key1, key2` |
| 設定移行なし | `redmine_subtask_list_accordion: No settings to migrate (not installed or no settings).` |
| 設定移行済み | `redmine_subtask_list_accordion: Settings already migrated or using defaults.` |
| プラグイン削除時 | `Removing {plugin}...` → `{plugin} removed.` |
| プラグインなし | `{plugin} not found (already removed or not installed).` |
| 削除あり | `{N} plugin(s) removed.` |
| 削除なし | `No plugins to remove.` |
| 常に | `=== Install completed ===` → `Please restart Redmine to apply changes.` |

### ログ出力

| 条件 | ログメッセージ |
|------|---------------|
| 開始時 | `[redmine_studio_plugin] Install task started` |
| 設定移行あり | `[redmine_studio_plugin] Migrated subtask_list_accordion settings: key1, key2` |
| 削除あり | `[redmine_studio_plugin] Removed plugins: {plugin1}, {plugin2}` |
| 完了時 | `[redmine_studio_plugin] Install task completed` |

### 設定移行対象

| 旧プラグイン | 旧キー | 新キー |
|-------------|--------|-------|
| redmine_subtask_list_accordion | `enable_server_scripting_mode` | `subtask_list_accordion_enable_server_scripting_mode` |
| redmine_subtask_list_accordion | `expand_all` | `subtask_list_accordion_expand_all` |
| redmine_subtask_list_accordion | `collapsed_trackers` | `subtask_list_accordion_collapsed_trackers` |
| redmine_subtask_list_accordion | `collapsed_tracker_ids` | `subtask_list_accordion_collapsed_tracker_ids` |

---

## テスト実行フロー

Rake タスクは `reenable` / `invoke` で再実行可能なため、コンテナ再起動は不要。Puma も止めない（公式 Docker イメージでは Puma がコンテナの PID 1 なので、止めるとコンテナごと止まる）。

install は流すたびに cron の登録も行う（扱うのは実行した利用者の crontab の、この Redmine の行だけ）。テストの前に crontab を控え、終わったあとに変わっていないことを確かめる。

コンテナの中のコマンドは `-u redmine -w /usr/src/redmine` を付けて `redmine` 利用者で動かす。root で動かすと、ログや plugins の中に root の持ち物のファイルができ、あとで Redmine や cron から書けなくなることがある。

`bash` のブロックは bash で流す（Windows では Git Bash で、`MSYS_NO_PATHCONV=1` を付ける。付けないと `/usr/src/redmine` や `/tmp/...` が Windows のパスに書き換わる）。PowerShell から `sh -c '...'` を渡すと、中の `"` が消えて壊れる。

フェーズ 0 と 3 は、「コンテナの中で行う」か「`{RedmineRoot}` がある環境」のどちらか一方の書き方を最初から最後まで使う（退避先が違うため）。

### フェーズ 0: 事前処理（退避・crontab の控え）

install は統合済みプラグイン（`config/integrated_plugins.yml` に並ぶもの）のフォルダを消す。テストで消されないよう、フォルダがあれば plugins の外へフォルダごと移しておく（`test/README.md` の「共通の事前条件」の init.rb・lib の名前の変更では足りない）。

**コンテナの中で行う:**
```bash
docker exec -u redmine -w /usr/src/redmine {Container} sh -c '
if [ -n "$(ls -A /tmp/install_task_backup 2>/dev/null)" ]; then echo "A backup from a previous run remains. Restore it with phase 3 first."; exit 1; fi
mkdir -p /tmp/install_task_backup
for p in $(sed -n "s/^ *- *//p" plugins/redmine_studio_plugin/config/integrated_plugins.yml | tr -d "\r"); do
  if [ -d "plugins/$p" ]; then mv "plugins/$p" /tmp/install_task_backup/ || exit 1; echo "Moved out: $p"; fi
  if [ -d "plugins/$p" ]; then echo "FAILED: plugins/$p remains"; exit 1; fi
done
crontab -l > /tmp/install_task_crontab_before.txt 2>&1
echo "Phase 0 done"'
```

**`{RedmineRoot}` がある環境（Windows PowerShell）:**
```powershell
$ErrorActionPreference = 'Stop'  # 移せなかったら、そこで止める
$pluginsDir = "{RedmineRoot}\plugins"  # 実行環境から注入（test/README.md）
$backupDir = "{RedmineRoot}\install_task_backup"  # plugins の外
$integratedPlugins = Get-Content "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml" | ForEach-Object { if ($_ -match '^\s+-\s+(.+)$') { $Matches[1].Trim() } }

if ((Test-Path $backupDir) -and (Get-ChildItem $backupDir)) { throw "A backup from a previous run remains. Restore it with phase 3 first." }
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
foreach ($plugin in $integratedPlugins) {
    if (Test-Path "$pluginsDir\$plugin") {
        Move-Item -Path "$pluginsDir\$plugin" -Destination $backupDir
        Write-Host "Moved out: $plugin"
    }
}
```
crontab は Redmine が動いている機械で `crontab -l` を流して控える。

**期待結果:** `Phase 0 done` が出る（PowerShell は止まらずに終わる）。統合済みプラグインのフォルダが plugins の中に 1 つも無い（もともと無ければ何も移さない）。移せなかったときは `FAILED` などで止まるので、先へ進まない

### フェーズ 1: Runner テスト（[1-1]・[1-2]・[2-1]〜[2-8]）

[1-1]・[1-2]・[2-1]〜[2-8] を順に並べた 1 本の Ruby スクリプトを作り、先頭に「Runner スクリプトの共通部分」を置く。リポジトリにスクリプトは置かない（この仕様書から作る）。

スクリプトはファイルにしてコンテナにコピーして流す。`rails runner '...'` にコードを直接渡すと、`!` や引用符の扱いで壊れやすい。

```bash
docker cp install_task_test.rb {Container}:/tmp/install_task_test.rb
docker exec -u redmine -w /usr/src/redmine {Container} bundle exec rails runner /tmp/install_task_test.rb
```

- `SQLite3::BusyException`（database is locked）が出たときは、少し待って流し直す

### フェーズ 2: ログの確認（[1-3]）

[1-3] に書いた手順で、Runner スクリプトとは別に行う。

### フェーズ 3: 事後処理（復元・crontab の確認）

1. 統合済みプラグインのダミーが残っていれば（[1-2] が失敗したときだけ）plugins の外へ移し、フェーズ 0 で退避したフォルダを戻す。フェーズ 0 のあと plugins にある統合済みプラグインのフォルダは、テストで作ったダミーだけ
2. crontab がフェーズ 0 の控えと同じことを確かめる

**コンテナの中で行う:**
```bash
docker exec -u redmine -w /usr/src/redmine {Container} sh -c '
leftover=/tmp/install_task_leftover_$(date +%Y%m%d%H%M%S)
for p in $(sed -n "s/^ *- *//p" plugins/redmine_studio_plugin/config/integrated_plugins.yml | tr -d "\r"); do
  if [ -d "plugins/$p" ]; then mkdir -p "$leftover" && mv "plugins/$p" "$leftover/" || exit 1; echo "Moved leftover dummy: $p"; fi
  if [ -d "/tmp/install_task_backup/$p" ]; then mv "/tmp/install_task_backup/$p" plugins/ || exit 1; echo "Restored: $p"; fi
done
crontab -l 2>&1 | diff /tmp/install_task_crontab_before.txt - && echo "crontab unchanged"'
```

**`{RedmineRoot}` がある環境（Windows PowerShell）:**
```powershell
$ErrorActionPreference = 'Stop'  # 移せなかったら、そこで止める
$pluginsDir = "{RedmineRoot}\plugins"  # 実行環境から注入（test/README.md）
$backupDir = "{RedmineRoot}\install_task_backup"
$leftoverDir = "{RedmineRoot}\install_task_leftover_$(Get-Date -Format yyyyMMddHHmmss)"
$integratedPlugins = Get-Content "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml" | ForEach-Object { if ($_ -match '^\s+-\s+(.+)$') { $Matches[1].Trim() } }

foreach ($plugin in $integratedPlugins) {
    if (Test-Path "$pluginsDir\$plugin") {  # フェーズ 0 のあとにあるのは、テストで作ったダミーだけ
        New-Item -ItemType Directory -Path $leftoverDir -Force | Out-Null
        Move-Item -Path "$pluginsDir\$plugin" -Destination $leftoverDir
        Write-Host "Moved leftover dummy: $plugin"
    }
    if (Test-Path "$backupDir\$plugin") {
        Move-Item -Path "$backupDir\$plugin" -Destination $pluginsDir
        Write-Host "Restored: $plugin"
    }
}
```
crontab は Redmine が動いている機械で `crontab -l` を流し、フェーズ 0 の控えと比べる。

**期待結果:**
- フェーズ 0 で移したフォルダが plugins に戻っている
- `crontab unchanged` が出る。違っていたら差分を報告し、控えに戻す。控えが crontab の行なら `crontab /tmp/install_task_crontab_before.txt`、控えが `no crontab for ...`（crontab が無かった）なら `crontab -r` で戻す。控えのエラー文をそのまま `crontab` に渡さない
- crontab コマンドが無い環境では、控えも今も同じエラー文になる。その場合は crontab の比較は対象外とする

---

## Runner スクリプトの共通部分

フェーズ 1 のスクリプトの先頭に置く。各テストの「確認方法」はこの関数と定数を使う。

```ruby
require 'rake'
require 'stringio'
Rails.application.load_tasks  # rails runner では rake のタスクが読み込まれていないため

PLUGINS_DIR = Rails.root.join('plugins')
INTEGRATED_PLUGINS = YAML.load_file(PLUGINS_DIR.join('redmine_studio_plugin', 'config', 'integrated_plugins.yml'))['integrated_plugins'] || []

# テスト前の設定を控える（[2-8] で戻す）。[1-1] の install より前に控えるので、旧設定が残っている環境でも戻せる
SUBTASK_KEYS = %w[enable_server_scripting_mode expand_all collapsed_trackers collapsed_tracker_ids].map { |key| "subtask_list_accordion_#{key}" }
ORIGINAL_SUBTASK_SETTINGS = (Setting.plugin_redmine_studio_plugin || {}).slice(*SUBTASK_KEYS)
ORIGINAL_LEGACY_VALUE = Setting.find_by(name: 'plugin_redmine_subtask_list_accordion')&.[](:value)

# ブロックの中で puts された文字列を返す
def capture_stdout
  original = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = original
end

# install を流し直し、出力を返す（redmine:plugins:migrate も install の中で呼ばれるため reenable する）
def run_install
  Rake::Task['redmine_studio_plugin:install'].reenable
  Rake::Task['redmine:plugins:migrate'].reenable
  capture_stdout { Rake::Task['redmine_studio_plugin:install'].invoke }
end

# 旧プラグインの設定を DB に直接書く。
# 旧プラグインが入っていない環境では、Setting.create! と Setting.plugin_redmine_subtask_list_accordion= は
# 設定名の検査で使えない（Name is not included in the list。7.x では NoMethodError）。
# install は旧設定を DB のレコードから直接読むので、旧プラグインを消したあとに旧設定だけが残る場面と同じになる。
def write_legacy_setting(text)
  Setting.where(name: 'plugin_redmine_subtask_list_accordion').destroy_all
  Setting.new(name: 'plugin_redmine_subtask_list_accordion', value: text).save!(validate: false)
end
```

---

## 1. 統合済みプラグインの削除テスト

### [1-1] 統合済みプラグインが存在しない場合 → エラーなくスキップ

**事前条件:**
- 統合済みプラグインのフォルダが存在しない（フェーズ 0 で plugins の外へ移してある）

**確認方法:**
```ruby
# フォルダが無いことを確かめる（あればスクリプトはここで止まる。フェーズ 0 からやり直す。ここでは消さない）
existing = INTEGRATED_PLUGINS.select { |plugin| File.directory?(PLUGINS_DIR.join(plugin)) }
raise "[1-1] 統合済みプラグインのフォルダがある: #{existing.join(', ')}" if existing.any?

# タスク実行（エラーが発生しないこと）
output = run_install
puts "[1-1] No plugins to remove: #{output.include?('No plugins to remove.')}"
puts "[1-1] Install completed: #{output.include?('=== Install completed ===')}"
```

**期待結果:**
- 例外が発生しない
- 出力がすべて `true`

---

### [1-2] 統合済みプラグインが存在する場合 → 削除される

**事前条件:**
- [1-1] のあと（統合済みプラグインのフォルダが存在しない）

**確認方法:**
```ruby
# ダミーフォルダ作成（init.rb 付き）
INTEGRATED_PLUGINS.each do |plugin|
  FileUtils.mkdir_p(PLUGINS_DIR.join(plugin))
  FileUtils.touch(PLUGINS_DIR.join(plugin, 'init.rb'))
end

# タスク実行
output = run_install

# 確認
puts "[1-2] all removed: #{INTEGRATED_PLUGINS.none? { |plugin| File.directory?(PLUGINS_DIR.join(plugin)) }}"
puts "[1-2] removed count: #{output.include?("#{INTEGRATED_PLUGINS.size} plugin(s) removed.")}"
```

**期待結果:**
- 出力がすべて `true`（各ダミーフォルダが削除され、出力に `{統合済みプラグイン数} plugin(s) removed.` が含まれる）

---

### [1-3] ログに実行記録が残る

フェーズ 2 で、Runner スクリプトとは別に行う。ログの出先は環境で違うので、先に確かめる。

```bash
docker exec {Container} printenv RAILS_LOG_TO_STDOUT
```

**値が出る場合（Docker の公式イメージは `true`）:** Redmine の `config/environments/production.rb` は、この変数が空でなければログを標準出力に出す（`log/production.log` には残らない）。rake を流した出力に、開始・完了の 2 行が出ることを確かめる。

```bash
docker exec -u redmine -w /usr/src/redmine {Container} sh -c 'bundle exec rake redmine_studio_plugin:install 2>&1 | grep -F "[redmine_studio_plugin] Install task"'
```

**何も出ない場合（変数が無い・ログをファイルに書く環境）:** 次の Ruby を「Runner スクリプトの共通部分」の後ろに置いて流す。

```ruby
log_file = Rails.root.join('log', "#{Rails.env}.log")
log_size_before = File.size(log_file)

run_install

new_log = File.open(log_file) { |f| f.seek(log_size_before); f.read }
puts "[1-3] started: #{new_log.include?('[redmine_studio_plugin] Install task started')}"
puts "[1-3] completed: #{new_log.include?('[redmine_studio_plugin] Install task completed')}"
```

**期待結果:**
- ログに `[redmine_studio_plugin] Install task started` が含まれる
- ログに `[redmine_studio_plugin] Install task completed` が含まれる

---

## 2. 設定移行テスト

### [2-1] subtask_list_accordion: 旧プラグインの設定がない場合 → スキップ

**事前条件:**
- DB に `plugin_redmine_subtask_list_accordion` のレコードが存在しない

**確認方法:**
```ruby
# 旧設定をクリア（存在する場合）
Setting.where(name: 'plugin_redmine_subtask_list_accordion').destroy_all

# タスク実行
output = run_install
puts "[2-1] No settings to migrate: #{output.include?('No settings to migrate')}"
```

**期待結果:**
- 出力が `true`（出力に `No settings to migrate` が含まれる）
- エラーが発生しない

---

### [2-2] subtask_list_accordion: 旧プラグインの設定がある場合 → 移行される

**事前条件:**
- DB に旧プラグインの設定値が存在する

**確認方法:**
```ruby
# 旧設定を作成
legacy_settings = {
  'enable_server_scripting_mode' => false,
  'expand_all' => true,
  'collapsed_trackers' => 'test',
  'collapsed_tracker_ids' => ['1', '2']
}
write_legacy_setting(legacy_settings.to_yaml)

# 新設定から対象キーを削除（移行をテストするため）
new_settings = (Setting.plugin_redmine_studio_plugin || {}).dup
new_settings.delete('subtask_list_accordion_enable_server_scripting_mode')
new_settings.delete('subtask_list_accordion_expand_all')
new_settings.delete('subtask_list_accordion_collapsed_trackers')
new_settings.delete('subtask_list_accordion_collapsed_tracker_ids')
Setting.plugin_redmine_studio_plugin = new_settings

# タスク実行
output = run_install

# 確認
new_settings = Setting.plugin_redmine_studio_plugin
puts "[2-2] enable_server_scripting_mode: #{new_settings['subtask_list_accordion_enable_server_scripting_mode'] == false}"
puts "[2-2] expand_all: #{new_settings['subtask_list_accordion_expand_all'] == true}"
puts "[2-2] collapsed_trackers: #{new_settings['subtask_list_accordion_collapsed_trackers'] == 'test'}"
puts "[2-2] collapsed_tracker_ids: #{new_settings['subtask_list_accordion_collapsed_tracker_ids'] == ['1', '2']}"
puts "[2-2] Migrated 4: #{output.include?('Migrated 4 setting(s)')}"
```

**期待結果:**
- 出力がすべて `true`（各設定値が正しく移行され、出力に `Migrated 4 setting(s)` が含まれる）

---

### [2-3] subtask_list_accordion: 既に移行済みの場合 → 上書きしない

**事前条件:**
- DB に旧プラグインの設定値が存在する
- `Setting.plugin_redmine_studio_plugin` に既に同じキーの設定が存在する

**確認方法:**
```ruby
# 旧設定を作成（移行元の値）
legacy_settings = {
  'enable_server_scripting_mode' => false,
  'expand_all' => true
}
write_legacy_setting(legacy_settings.to_yaml)

# 新設定に既に値を設定（既存の値）
new_settings = (Setting.plugin_redmine_studio_plugin || {}).dup
new_settings['subtask_list_accordion_enable_server_scripting_mode'] = true  # 旧設定と異なる値
new_settings['subtask_list_accordion_expand_all'] = false  # 旧設定と異なる値
Setting.plugin_redmine_studio_plugin = new_settings

# タスク実行
output = run_install

# 確認（既存の値が維持されていること）
new_settings = Setting.plugin_redmine_studio_plugin
puts "[2-3] enable_server_scripting_mode preserved: #{new_settings['subtask_list_accordion_enable_server_scripting_mode'] == true}"
puts "[2-3] expand_all preserved: #{new_settings['subtask_list_accordion_expand_all'] == false}"
puts "[2-3] already migrated: #{output.include?('Settings already migrated or using defaults')}"
```

**期待結果:**
- 出力がすべて `true`（既存の設定値が上書きされず、出力に `Settings already migrated or using defaults` が含まれる）

---

### [2-4] subtask_list_accordion: 一部のキーのみ存在する場合 → 存在するキーのみ移行

**事前条件:**
- DB の旧プラグインの設定に一部のキーのみ存在する

**確認方法:**
```ruby
# 旧設定を作成（一部のキーのみ）
legacy_settings = {
  'enable_server_scripting_mode' => false
  # expand_all, collapsed_tracker_ids は未設定
}
write_legacy_setting(legacy_settings.to_yaml)

# 新設定から対象キーを削除
new_settings = (Setting.plugin_redmine_studio_plugin || {}).dup
new_settings.delete('subtask_list_accordion_enable_server_scripting_mode')
new_settings.delete('subtask_list_accordion_expand_all')
new_settings.delete('subtask_list_accordion_collapsed_tracker_ids')
Setting.plugin_redmine_studio_plugin = new_settings

# タスク実行
run_install

# 確認
new_settings = Setting.plugin_redmine_studio_plugin
puts "[2-4] enable_server_scripting_mode migrated: #{new_settings['subtask_list_accordion_enable_server_scripting_mode'] == false}"
puts "[2-4] expand_all not migrated: #{new_settings['subtask_list_accordion_expand_all'].nil?}"
```

**期待結果:**
- 出力がすべて `true`（存在するキー `enable_server_scripting_mode` のみ移行され、存在しないキー `expand_all` 等は nil のまま）
- エラーが発生しない

---

### [2-5] subtask_list_accordion: 空の値（nil, 空文字, 空配列）の場合 → 正しく移行

**事前条件:**
- DB の旧プラグインの設定に空の値が含まれる

**確認方法:**
```ruby
# 旧設定を作成（空の値を含む）
legacy_settings = {
  'enable_server_scripting_mode' => nil,
  'expand_all' => false,
  'collapsed_trackers' => '',
  'collapsed_tracker_ids' => []
}
write_legacy_setting(legacy_settings.to_yaml)

# 新設定から対象キーを削除
new_settings = (Setting.plugin_redmine_studio_plugin || {}).dup
new_settings.delete('subtask_list_accordion_enable_server_scripting_mode')
new_settings.delete('subtask_list_accordion_expand_all')
new_settings.delete('subtask_list_accordion_collapsed_trackers')
new_settings.delete('subtask_list_accordion_collapsed_tracker_ids')
Setting.plugin_redmine_studio_plugin = new_settings

# タスク実行
run_install

# 確認
new_settings = Setting.plugin_redmine_studio_plugin
puts "[2-5] enable_server_scripting_mode: #{new_settings.key?('subtask_list_accordion_enable_server_scripting_mode') && new_settings['subtask_list_accordion_enable_server_scripting_mode'].nil?}"
puts "[2-5] expand_all: #{new_settings['subtask_list_accordion_expand_all'] == false}"
puts "[2-5] collapsed_trackers: #{new_settings['subtask_list_accordion_collapsed_trackers'] == ''}"
puts "[2-5] collapsed_tracker_ids: #{new_settings['subtask_list_accordion_collapsed_tracker_ids'] == []}"
```

**期待結果:**
- 出力がすべて `true`（空の値 nil・空文字・空配列・false も正しく移行される）
- エラーが発生しない

---

### [2-6] subtask_list_accordion: 不正な YAML の場合 → エラーにならずスキップ

**事前条件:**
- `Setting` テーブルに不正な YAML が直接格納されている

**確認方法:**
```ruby
# 不正な YAML を直接 DB に書き込み
write_legacy_setting("invalid: yaml: ::\n  broken")

# タスク実行（例外が発生しないこと）
begin
  output = run_install
  puts "[2-6] No exception raised: true"
  puts "[2-6] No settings to migrate: #{output.include?('No settings to migrate')}"
rescue => e
  puts "[2-6] No exception raised: false (#{e.message})"
end
```

**期待結果:**
- 出力がすべて `true`（例外が発生せず、出力に `No settings to migrate` が含まれる）

---

### [2-7] subtask_list_accordion: 旧プラグイン削除後も DB から移行可能

**背景:**
旧プラグインが削除されると `Setting.plugin_redmine_subtask_list_accordion` メソッドは使えない（`available_settings` を参照するため）。
しかし DB レコードは残っているため、`Setting.find_by` + `[:value]` で直接読み取る必要がある。

**事前条件:**
- 旧プラグインのフォルダが存在しない（削除済み）
- DB に `plugin_redmine_subtask_list_accordion` のレコードが存在する

**確認方法:**
```ruby
# 旧プラグインフォルダが存在しないことを確認
legacy_plugin_path = Rails.root.join('plugins', 'redmine_subtask_list_accordion')
puts "[2-7] Legacy plugin absent: #{!File.directory?(legacy_plugin_path)}"

# DB に直接レコードを作成（YAML 形式）
legacy_settings = {
  'enable_server_scripting_mode' => false,
  'expand_all' => true
}
write_legacy_setting(legacy_settings.to_yaml)

# 新設定から対象キーを削除
new_settings = (Setting.plugin_redmine_studio_plugin || {}).dup
new_settings.delete('subtask_list_accordion_enable_server_scripting_mode')
new_settings.delete('subtask_list_accordion_expand_all')
Setting.plugin_redmine_studio_plugin = new_settings

# タスク実行
run_install

# 確認
new_settings = Setting.plugin_redmine_studio_plugin
puts "[2-7] enable_server_scripting_mode: #{new_settings['subtask_list_accordion_enable_server_scripting_mode'] == false}"
puts "[2-7] expand_all: #{new_settings['subtask_list_accordion_expand_all'] == true}"
```

**期待結果:**
- 出力がすべて `true`（旧プラグインが削除されていても、DB から設定を読み取って移行できる）

---

### [2-8] 後処理: テスト前の設定に戻す

「Runner スクリプトの共通部分」で控えた値に戻す。

**確認方法:**
```ruby
# 旧設定をテスト前に戻す（無かったら消すだけ）
Setting.where(name: 'plugin_redmine_subtask_list_accordion').destroy_all
write_legacy_setting(ORIGINAL_LEGACY_VALUE) if ORIGINAL_LEGACY_VALUE

# 新設定の対象キーをテスト前に戻す（無かったキーは消す）
new_settings = (Setting.plugin_redmine_studio_plugin || {}).dup
SUBTASK_KEYS.each do |key|
  if ORIGINAL_SUBTASK_SETTINGS.key?(key)
    new_settings[key] = ORIGINAL_SUBTASK_SETTINGS[key]
  else
    new_settings.delete(key)
  end
end
Setting.plugin_redmine_studio_plugin = new_settings

restored = Setting.plugin_redmine_studio_plugin.slice(*SUBTASK_KEYS) == ORIGINAL_SUBTASK_SETTINGS &&
           Setting.find_by(name: 'plugin_redmine_subtask_list_accordion')&.[](:value) == ORIGINAL_LEGACY_VALUE
puts "[2-8] restored: #{restored}"
```

**期待結果:** 出力が `true`

---

## テスト実行上の注意

### タスクの再実行

Rake タスクは一度実行すると「実行済み」としてマークされるため、
テストで複数回実行する場合は `reenable` を呼ぶ必要がある（「Runner スクリプトの共通部分」の `run_install`）。
`redmine:plugins:migrate` も `reenable` が必要（install タスク内で呼び出されるため）。

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいて以下の順序でテストを実行する:

1. フェーズ 0: 統合済みプラグインのフォルダを plugins の外へ移し、crontab を控える
2. フェーズ 1: Runner スクリプト（共通部分＋[1-1]・[1-2]・[2-1]〜[2-8]）を流す
3. フェーズ 2: ログの確認（[1-3]）
4. フェーズ 3: 移したフォルダを戻し、crontab が控えと同じことを確かめる
