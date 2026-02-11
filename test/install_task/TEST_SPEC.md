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

## 環境パラメータ

以下のパラメータは TEST_SPEC.md のパスから自動判定する:

| パラメータ | 判定方法 |
|-----------|----------|
| Container | パス内の `redmine_X.Y.Z` フォルダ名をそのまま使用 |

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

Rake タスクは `reenable` / `invoke` で再実行可能なため、コンテナ再起動は不要。

### フェーズ 1: 事前処理（退避）

既存の統合済みプラグインを無効化する（init.rb をリネーム）。

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "C:\Docker\redmine_X.Y.Z"  # TEST_SPEC.md のパスから判定
$pluginsDir = "$redmineRoot\plugins"

# 統合済みプラグインリストを config/integrated_plugins.yml から取得
$configPath = "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml"
$configContent = Get-Content $configPath -Raw
$integratedPlugins = [regex]::Matches($configContent, '^\s+-\s+(.+)$', 'Multiline') | ForEach-Object { $_.Groups[1].Value.Trim() }

# 統合済みプラグインを無効化（init.rb → init.rb.bak）
foreach ($plugin in $integratedPlugins) {
    $initPath = "$pluginsDir\$plugin\init.rb"
    if (Test-Path $initPath) {
        Rename-Item -Path $initPath -NewName "init.rb.bak" -Force
        Write-Host "Disabled: $plugin"
    }
}
```

### フェーズ 2: 削除対象なしテスト

1. [1-1] を実行（統合済みプラグインなし → エラーなくスキップ）

### フェーズ 3: 削除対象ありテスト

1. ダミーの統合済みプラグインを作成

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "C:\Docker\redmine_X.Y.Z"  # TEST_SPEC.md のパスから判定
$pluginsDir = "$redmineRoot\plugins"

# 統合済みプラグインリストを config/integrated_plugins.yml から取得
$configPath = "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml"
$configContent = Get-Content $configPath -Raw
$integratedPlugins = [regex]::Matches($configContent, '^\s+-\s+(.+)$', 'Multiline') | ForEach-Object { $_.Groups[1].Value.Trim() }

foreach ($plugin in $integratedPlugins) {
    $pluginPath = "$pluginsDir\$plugin"
    if (Test-Path $pluginPath) {
        Remove-Item -Path $pluginPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $pluginPath | Out-Null
    New-Item -ItemType File -Path "$pluginPath\init.rb" -Force | Out-Null
    Write-Host "Created dummy: $plugin"
}
```

2. [1-2], [1-3] を実行（統合済みプラグインあり → 削除される、ログ確認）

### フェーズ 4: 事後処理（復元）

1. ダミーフォルダを削除（タスク実行で削除済みのはずだが念のため）

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "C:\Docker\redmine_X.Y.Z"  # TEST_SPEC.md のパスから判定
$pluginsDir = "$redmineRoot\plugins"

# 統合済みプラグインリストを config/integrated_plugins.yml から取得
$configPath = "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml"
$configContent = Get-Content $configPath -Raw
$integratedPlugins = [regex]::Matches($configContent, '^\s+-\s+(.+)$', 'Multiline') | ForEach-Object { $_.Groups[1].Value.Trim() }

foreach ($plugin in $integratedPlugins) {
    $pluginPath = "$pluginsDir\$plugin"
    if (Test-Path $pluginPath) {
        Remove-Item -Path $pluginPath -Recurse -Force
        Write-Host "Removed dummy: $plugin"
    }
}
```

2. 退避したプラグインを有効化（init.rb.bak → init.rb）

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "C:\Docker\redmine_X.Y.Z"  # TEST_SPEC.md のパスから判定
$pluginsDir = "$redmineRoot\plugins"

# 統合済みプラグインリストを config/integrated_plugins.yml から取得
$configPath = "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml"
$configContent = Get-Content $configPath -Raw
$integratedPlugins = [regex]::Matches($configContent, '^\s+-\s+(.+)$', 'Multiline') | ForEach-Object { $_.Groups[1].Value.Trim() }

foreach ($plugin in $integratedPlugins) {
    $initBakPath = "$pluginsDir\$plugin\init.rb.bak"
    if (Test-Path $initBakPath) {
        Rename-Item -Path $initBakPath -NewName "init.rb" -Force
        Write-Host "Enabled: $plugin"
    }
}
```

---

## 1. rails runner テスト

**実行方法:**
```bash
docker exec {Container} rails runner plugins/redmine_studio_plugin/test/install_task/runner_test.rb
```

### [1-1] 統合済みプラグインが存在しない場合 → エラーなくスキップ

**事前条件:**
- 統合済みプラグイン（`config/integrated_plugins.yml` 参照）のフォルダが存在しない

**確認方法:**
```ruby
plugins_dir = Rails.root.join('plugins')
config_path = Rails.root.join('plugins', 'redmine_studio_plugin', 'config', 'integrated_plugins.yml')
config = YAML.load_file(config_path)
integrated_plugins = config['integrated_plugins'] || []

# フォルダがないことを確認
integrated_plugins.each do |plugin|
  plugin_path = plugins_dir.join(plugin)
  FileUtils.rm_rf(plugin_path) if File.directory?(plugin_path)
end

# タスク実行（エラーが発生しないこと）
Rake::Task['redmine_studio_plugin:install'].reenable
Rake::Task['redmine:plugins:migrate'].reenable
Rake::Task['redmine_studio_plugin:install'].invoke
```

**期待結果:**
- 例外が発生しない
- タスクが正常に完了する
- 出力に `No plugins to remove.` が含まれる

---

### [1-2] 統合済みプラグインが存在する場合 → 削除される

**事前条件:**
- 統合済みプラグインのダミーフォルダを作成（`init.rb` 付き）

**確認方法:**
```ruby
plugins_dir = Rails.root.join('plugins')
config_path = Rails.root.join('plugins', 'redmine_studio_plugin', 'config', 'integrated_plugins.yml')
config = YAML.load_file(config_path)
integrated_plugins = config['integrated_plugins'] || []

# ダミーフォルダ作成
integrated_plugins.each do |plugin|
  plugin_path = plugins_dir.join(plugin)
  FileUtils.mkdir_p(plugin_path)
  FileUtils.touch(plugin_path.join('init.rb'))
end

# タスク実行
Rake::Task['redmine_studio_plugin:install'].reenable
Rake::Task['redmine:plugins:migrate'].reenable
Rake::Task['redmine_studio_plugin:install'].invoke

# 確認
results = integrated_plugins.map do |plugin|
  plugin_path = plugins_dir.join(plugin)
  (File.directory?(plugin_path) == false)
end
results.all?
```

**期待結果:**
- 各プラグインフォルダが削除されている（`File.directory?(plugin_path)` が false）
- 出力に `{統合済みプラグイン数} plugin(s) removed.` が含まれる

---

### [1-3] ログに実行記録が残る

**確認方法（ファイルログの場合）:**
```ruby
# ログファイルのパス
log_file = Rails.root.join('log', "#{Rails.env}.log")

# 実行前のログサイズを記録
log_size_before = File.size(log_file)

# タスク実行
Rake::Task['redmine_studio_plugin:install'].reenable
Rake::Task['redmine:plugins:migrate'].reenable
Rake::Task['redmine_studio_plugin:install'].invoke

# ログの新規部分を読み取り
File.open(log_file) do |f|
  f.seek(log_size_before)
  new_log = f.read
  new_log.include?('[redmine_studio_plugin] Install task started') &&
  new_log.include?('[redmine_studio_plugin] Install task completed')
end
```

**Docker 環境での確認方法:**

Docker 環境ではログがファイルではなく stdout に出力される場合がある。
その場合、タスク実行時のコンソール出力で以下のログを目視確認する:

```
I, [2026-02-05T...] INFO -- : [redmine_studio_plugin] Install task started
I, [2026-02-05T...] INFO -- : [redmine_studio_plugin] Install task completed
```

**期待結果:**
- ログに `[redmine_studio_plugin] Install task started` が含まれる
- ログに `[redmine_studio_plugin] Install task completed` が含まれる

---

## 2. 設定移行テスト

### [2-1] subtask_list_accordion: 旧プラグインの設定がない場合 → スキップ

**事前条件:**
- `Setting.plugin_redmine_subtask_list_accordion` が存在しない、または空

**確認方法:**
```ruby
# 旧設定をクリア（存在する場合）
begin
  Setting.where(name: 'plugin_redmine_subtask_list_accordion').destroy_all
rescue
  # 設定が存在しない場合は無視
end

# タスク実行
Rake::Task['redmine_studio_plugin:install'].reenable
Rake::Task['redmine:plugins:migrate'].reenable

# 出力をキャプチャ
output = capture_stdout { Rake::Task['redmine_studio_plugin:install'].invoke }
puts output.include?('No settings to migrate')
```

**期待結果:**
- 出力に `No settings to migrate` が含まれる
- エラーが発生しない

---

### [2-2] subtask_list_accordion: 旧プラグインの設定がある場合 → 移行される

**事前条件:**
- `Setting.plugin_redmine_subtask_list_accordion` に設定値が存在する

**確認方法:**
```ruby
# 旧設定を作成
legacy_settings = {
  'enable_server_scripting_mode' => false,
  'expand_all' => true,
  'collapsed_trackers' => 'test',
  'collapsed_tracker_ids' => ['1', '2']
}
Setting.plugin_redmine_subtask_list_accordion = legacy_settings

# 新設定から対象キーを削除（移行をテストするため）
new_settings = Setting.plugin_redmine_studio_plugin || {}
new_settings.delete('subtask_list_accordion_enable_server_scripting_mode')
new_settings.delete('subtask_list_accordion_expand_all')
new_settings.delete('subtask_list_accordion_collapsed_trackers')
new_settings.delete('subtask_list_accordion_collapsed_tracker_ids')
Setting.plugin_redmine_studio_plugin = new_settings

# タスク実行
Rake::Task['redmine_studio_plugin:install'].reenable
Rake::Task['redmine:plugins:migrate'].reenable
Rake::Task['redmine_studio_plugin:install'].invoke

# 確認
new_settings = Setting.plugin_redmine_studio_plugin
puts "enable_server_scripting_mode: #{new_settings['subtask_list_accordion_enable_server_scripting_mode'] == false}"
puts "expand_all: #{new_settings['subtask_list_accordion_expand_all'] == true}"
puts "collapsed_trackers: #{new_settings['subtask_list_accordion_collapsed_trackers'] == 'test'}"
puts "collapsed_tracker_ids: #{new_settings['subtask_list_accordion_collapsed_tracker_ids'] == ['1', '2']}"
```

**期待結果:**
- 各設定値が正しく移行される（すべて `true`）
- 出力に `Migrated 4 setting(s)` が含まれる

---

### [2-3] subtask_list_accordion: 既に移行済みの場合 → 上書きしない

**事前条件:**
- `Setting.plugin_redmine_subtask_list_accordion` に設定値が存在する
- `Setting.plugin_redmine_studio_plugin` に既に同じキーの設定が存在する

**確認方法:**
```ruby
# 旧設定を作成（移行元の値）
legacy_settings = {
  'enable_server_scripting_mode' => false,
  'expand_all' => true
}
Setting.plugin_redmine_subtask_list_accordion = legacy_settings

# 新設定に既に値を設定（既存の値）
new_settings = Setting.plugin_redmine_studio_plugin || {}
new_settings['subtask_list_accordion_enable_server_scripting_mode'] = true  # 旧設定と異なる値
new_settings['subtask_list_accordion_expand_all'] = false  # 旧設定と異なる値
Setting.plugin_redmine_studio_plugin = new_settings

# タスク実行
Rake::Task['redmine_studio_plugin:install'].reenable
Rake::Task['redmine:plugins:migrate'].reenable
Rake::Task['redmine_studio_plugin:install'].invoke

# 確認（既存の値が維持されていること）
new_settings = Setting.plugin_redmine_studio_plugin
puts "enable_server_scripting_mode preserved: #{new_settings['subtask_list_accordion_enable_server_scripting_mode'] == true}"
puts "expand_all preserved: #{new_settings['subtask_list_accordion_expand_all'] == false}"
```

**期待結果:**
- 既存の設定値が上書きされない（既存の値が維持される）
- 出力に `Settings already migrated or using defaults` が含まれる

---

### [2-4] 後処理: テスト用設定のクリーンアップ

**確認方法:**
```ruby
# 旧設定を削除
begin
  Setting.where(name: 'plugin_redmine_subtask_list_accordion').destroy_all
rescue
  # 設定が存在しない場合は無視
end

# 新設定をデフォルトに戻す
new_settings = Setting.plugin_redmine_studio_plugin || {}
new_settings['subtask_list_accordion_enable_server_scripting_mode'] = true
new_settings['subtask_list_accordion_expand_all'] = false
new_settings['subtask_list_accordion_collapsed_trackers'] = ''
new_settings['subtask_list_accordion_collapsed_tracker_ids'] = []
Setting.plugin_redmine_studio_plugin = new_settings

puts "Cleanup completed"
```

**期待結果:** `Cleanup completed` が出力される

---

## テスト実行上の注意

### タスクの再実行

Rake タスクは一度実行すると「実行済み」としてマークされるため、
テストで複数回実行する場合は `reenable` を呼ぶ必要がある:

```ruby
Rake::Task['redmine_studio_plugin:install'].reenable
Rake::Task['redmine:plugins:migrate'].reenable
Rake::Task['redmine_studio_plugin:install'].invoke
```

`redmine:plugins:migrate` も `reenable` が必要（install タスク内で呼び出されるため）。

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいて以下の順序でテストを実行する:

1. フェーズ 1: 既存の統合済みプラグインを無効化（init.rb → init.rb.bak）
2. フェーズ 2: 削除対象なしテスト実行
3. フェーズ 3: ダミープラグイン作成 → 削除対象ありテスト実行
4. フェーズ 4: クリーンアップ・有効化（init.rb.bak → init.rb）
