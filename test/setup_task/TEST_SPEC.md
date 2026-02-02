# Setup Task テスト仕様書

## 概要

`rake redmine_studio_plugin:setup` タスクのテスト仕様。
このタスクはプラグインインストール後に実行され、統合済みプラグインの削除を行う。

## 環境パラメータ

以下のパラメータは TEST_SPEC.md のパスから自動判定する:

| パラメータ | 判定方法 |
|-----------|----------|
| Container | パス内の `redmine_X.Y.Z` フォルダ名をそのまま使用 |

## タスクの内部実装

| 項目 | 値 |
|------|-----|
| ファイル | `lib/tasks/setup.rake` |
| タスク名 | `redmine_studio_plugin:setup` |
| 統合済みプラグイン | `redmine_reply_button`, `redmine_teams_button` |

### 処理フロー

1. ログ出力: `[redmine_studio_plugin] Setup task started`
2. 統合済みプラグインのフォルダを確認
3. 存在すれば削除、なければスキップ
4. 結果をログ出力
5. ログ出力: `[redmine_studio_plugin] Setup task completed`

### 出力メッセージ

| 条件 | stdout 出力 |
|------|-------------|
| プラグイン削除時 | `Removing {plugin}...` → `{plugin} removed.` |
| プラグインなし | `{plugin} not found (already removed or not installed).` |
| 削除あり | `{N} plugin(s) removed.` |
| 削除なし | `No plugins to remove.` |
| 常に | `Setup completed. Please restart Redmine to apply changes.` |

### ログ出力

| 条件 | ログメッセージ |
|------|---------------|
| 開始時 | `[redmine_studio_plugin] Setup task started` |
| 削除あり | `[redmine_studio_plugin] Removed plugins: {plugin1}, {plugin2}` |
| 削除なし | `[redmine_studio_plugin] No plugins to remove` |
| 完了時 | `[redmine_studio_plugin] Setup task completed` |

---

## テスト実行フロー

Rake タスクは `reenable` / `invoke` で再実行可能なため、コンテナ再起動は不要。

### フェーズ 1: 事前処理（退避）

既存の統合済みプラグインを退避する。

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "C:\Docker\redmine_X.Y.Z"  # TEST_SPEC.md のパスから判定
$pluginsDir = "$redmineRoot\plugins"
$backupDir = "$redmineRoot\test_backup"
$integratedPlugins = @("redmine_reply_button", "redmine_teams_button")

# バックアップフォルダ作成
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

# 統合済みプラグインを退避
foreach ($plugin in $integratedPlugins) {
    $pluginPath = "$pluginsDir\$plugin"
    $backupPath = "$backupDir\$plugin"
    if (Test-Path $pluginPath) {
        $items = Get-ChildItem -Path $pluginPath -Force
        if ($items.Count -gt 0) {
            Move-Item -Path $pluginPath -Destination $backupPath -Force
            Write-Host "Backed up: $plugin"
        } else {
            # 空フォルダは削除
            Remove-Item -Path $pluginPath -Force
            Write-Host "Removed empty folder: $plugin"
        }
    }
}
```

**注意:** 空フォルダは退避対象外とする。

### フェーズ 2: 削除対象なしテスト

1. [1-1] を実行（統合済みプラグインなし → エラーなくスキップ）

### フェーズ 3: 削除対象ありテスト

1. ダミーの統合済みプラグインを作成

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "C:\Docker\redmine_X.Y.Z"  # TEST_SPEC.md のパスから判定
$pluginsDir = "$redmineRoot\plugins"
$integratedPlugins = @("redmine_reply_button", "redmine_teams_button")

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
$integratedPlugins = @("redmine_reply_button", "redmine_teams_button")

foreach ($plugin in $integratedPlugins) {
    $pluginPath = "$pluginsDir\$plugin"
    if (Test-Path $pluginPath) {
        Remove-Item -Path $pluginPath -Recurse -Force
        Write-Host "Removed dummy: $plugin"
    }
}
```

2. 退避したプラグインを復元

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "C:\Docker\redmine_X.Y.Z"  # TEST_SPEC.md のパスから判定
$pluginsDir = "$redmineRoot\plugins"
$backupDir = "$redmineRoot\test_backup"
$integratedPlugins = @("redmine_reply_button", "redmine_teams_button")

foreach ($plugin in $integratedPlugins) {
    $pluginPath = "$pluginsDir\$plugin"
    $backupPath = "$backupDir\$plugin"
    if (Test-Path $backupPath) {
        Move-Item -Path $backupPath -Destination $pluginPath -Force
        Write-Host "Restored: $plugin"
    }
}

# バックアップフォルダ削除
if (Test-Path $backupDir) {
    Remove-Item -Path $backupDir -Recurse -Force
}
```

---

## 1. rails runner テスト

**実行方法:**
```bash
docker exec {Container} rails runner plugins/redmine_studio_plugin/test/setup_task/runner_test.rb
```

### [1-1] 統合済みプラグインが存在しない場合 → エラーなくスキップ

**事前条件:**
- `plugins/redmine_reply_button/` フォルダが存在しない
- `plugins/redmine_teams_button/` フォルダが存在しない

**確認方法:**
```ruby
plugins_dir = Rails.root.join('plugins')
integrated_plugins = ['redmine_reply_button', 'redmine_teams_button']

# フォルダがないことを確認
integrated_plugins.each do |plugin|
  plugin_path = plugins_dir.join(plugin)
  FileUtils.rm_rf(plugin_path) if File.directory?(plugin_path)
end

# タスク実行（エラーが発生しないこと）
Rake::Task['redmine_studio_plugin:setup'].reenable
Rake::Task['redmine_studio_plugin:setup'].invoke
```

**期待結果:**
- 例外が発生しない
- タスクが正常に完了する
- 出力に `No plugins to remove.` が含まれる

---

### [1-2] 統合済みプラグインが存在する場合 → 削除される

**事前条件:**
- `plugins/redmine_reply_button/` フォルダを作成（ダミー）
- `plugins/redmine_teams_button/` フォルダを作成（ダミー）

**確認方法:**
```ruby
plugins_dir = Rails.root.join('plugins')
integrated_plugins = ['redmine_reply_button', 'redmine_teams_button']

# ダミーフォルダ作成
integrated_plugins.each do |plugin|
  plugin_path = plugins_dir.join(plugin)
  FileUtils.mkdir_p(plugin_path)
  FileUtils.touch(plugin_path.join('init.rb'))
end

# タスク実行
Rake::Task['redmine_studio_plugin:setup'].reenable
Rake::Task['redmine_studio_plugin:setup'].invoke

# 確認
results = integrated_plugins.map do |plugin|
  plugin_path = plugins_dir.join(plugin)
  !File.directory?(plugin_path)
end
results.all?
```

**期待結果:**
- 各プラグインフォルダが削除されている（`File.directory?(plugin_path)` が false）
- 出力に `2 plugin(s) removed.` が含まれる

---

### [1-3] ログに実行記録が残る

**確認方法（ファイルログの場合）:**
```ruby
# ログファイルのパス
log_file = Rails.root.join('log', "#{Rails.env}.log")

# 実行前のログサイズを記録
log_size_before = File.size(log_file)

# タスク実行
Rake::Task['redmine_studio_plugin:setup'].reenable
Rake::Task['redmine_studio_plugin:setup'].invoke

# ログの新規部分を読み取り
File.open(log_file) do |f|
  f.seek(log_size_before)
  new_log = f.read
  new_log.include?('[redmine_studio_plugin] Setup task started') &&
  new_log.include?('[redmine_studio_plugin] Setup task completed')
end
```

**Docker 環境での確認方法:**

Docker 環境ではログがファイルではなく stdout に出力される場合がある。
その場合、タスク実行時のコンソール出力で以下のログを目視確認する:

```
I, [2026-02-01T...] INFO -- : [redmine_studio_plugin] Setup task started
I, [2026-02-01T...] INFO -- : [redmine_studio_plugin] Setup task completed
```

**期待結果:**
- ログに `[redmine_studio_plugin] Setup task started` が含まれる
- ログに `[redmine_studio_plugin] Setup task completed` が含まれる

---

## テスト実行上の注意

### タスクの再実行

Rake タスクは一度実行すると「実行済み」としてマークされるため、
テストで複数回実行する場合は `reenable` を呼ぶ必要がある:

```ruby
Rake::Task['redmine_studio_plugin:setup'].reenable
Rake::Task['redmine_studio_plugin:setup'].invoke
```

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいて以下の順序でテストを実行する:

1. フェーズ 1: 既存の統合済みプラグインを退避
2. フェーズ 2: 削除対象なしテスト実行
3. フェーズ 3: ダミープラグイン作成 → 削除対象ありテスト実行
4. フェーズ 4: クリーンアップ・復元
