# 競合プラグイン検出テスト仕様書

## 概要

redmine_studio_plugin が統合する各機能と、元となるプラグインとの競合検出テスト。
競合プラグインが存在する場合、該当機能は無効化され、警告メッセージが表示される。

## 環境パラメータ

以下のパラメータは TEST_SPEC.md のパスから自動判定する:

| パラメータ | 判定方法 |
|-----------|----------|
| Container | パス内の `redmine_X.Y.Z` フォルダ名をそのまま使用 |

## 競合検出の仕様

競合対象のプラグインは `config/integrated_plugins.yml` から取得する。
いずれかのプラグインフォルダ内に `init.rb` が存在する場合、競合として検出される。
フォルダのみ存在し `init.rb` がない場合は競合とみなさない。

## 競合検出時の動作

1. プラグインの description に `WARNING:` を含む警告メッセージを追加
2. 該当機能のモジュールを登録しない（権限が追加されない）

---

## テスト実行フロー

競合検出はプラグイン読み込み時（Rails 起動時）に行われるため、フェーズ間でコンテナの再起動が必要。

### フェーズ 1: 事前処理（退避）

既存の競合プラグインを退避する。

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "C:\Docker\redmine_X.Y.Z"  # TEST_SPEC.md のパスから判定
$pluginsDir = "$redmineRoot\plugins"
$backupDir = "$redmineRoot\test_backup"

# 競合プラグインリストを config/integrated_plugins.yml から取得
$configPath = "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml"
$configContent = Get-Content $configPath -Raw
$conflictingPlugins = [regex]::Matches($configContent, '^\s+-\s+(.+)$', 'Multiline') | ForEach-Object { $_.Groups[1].Value.Trim() }

# バックアップフォルダ作成
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

# 競合プラグインを退避
foreach ($plugin in $conflictingPlugins) {
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

### フェーズ 2: 競合なしテスト

1. コンテナを再起動
2. [1-1], [2-1] を実行（競合プラグインなし → 警告なし、モジュール登録あり）

### フェーズ 3: 競合ありテスト

1. ダミーの競合プラグインを作成

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "C:\Docker\redmine_X.Y.Z"  # TEST_SPEC.md のパスから判定
$pluginsDir = "$redmineRoot\plugins"

# 競合プラグインリストを config/integrated_plugins.yml から取得
$configPath = "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml"
$configContent = Get-Content $configPath -Raw
$conflictingPlugins = [regex]::Matches($configContent, '^\s+-\s+(.+)$', 'Multiline') | ForEach-Object { $_.Groups[1].Value.Trim() }

foreach ($plugin in $conflictingPlugins) {
    $pluginPath = "$pluginsDir\$plugin"
    if (-not (Test-Path $pluginPath)) {
        New-Item -ItemType Directory -Path $pluginPath | Out-Null
    }
    New-Item -ItemType File -Path "$pluginPath\init.rb" -Force | Out-Null
    Write-Host "Created dummy: $plugin"
}
```

2. コンテナを再起動
3. [1-2], [2-2] を実行（競合プラグインあり → 警告表示、モジュール登録なし）

### フェーズ 4: 空フォルダテスト

1. ダミーの init.rb を削除（フォルダは残す）

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "C:\Docker\redmine_X.Y.Z"  # TEST_SPEC.md のパスから判定
$pluginsDir = "$redmineRoot\plugins"

# 競合プラグインリストを config/integrated_plugins.yml から取得
$configPath = "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml"
$configContent = Get-Content $configPath -Raw
$conflictingPlugins = [regex]::Matches($configContent, '^\s+-\s+(.+)$', 'Multiline') | ForEach-Object { $_.Groups[1].Value.Trim() }

foreach ($plugin in $conflictingPlugins) {
    $initPath = "$pluginsDir\$plugin\init.rb"
    if (Test-Path $initPath) {
        Remove-Item -Path $initPath -Force
        Write-Host "Removed init.rb: $plugin"
    }
}
```

2. コンテナを再起動
3. [1-3], [2-3] を実行（空フォルダのみ → 競合とみなさない）

### フェーズ 5: 事後処理（復元）

1. ダミーフォルダを削除

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "C:\Docker\redmine_X.Y.Z"  # TEST_SPEC.md のパスから判定
$pluginsDir = "$redmineRoot\plugins"

# 競合プラグインリストを config/integrated_plugins.yml から取得
$configPath = "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml"
$configContent = Get-Content $configPath -Raw
$conflictingPlugins = [regex]::Matches($configContent, '^\s+-\s+(.+)$', 'Multiline') | ForEach-Object { $_.Groups[1].Value.Trim() }

foreach ($plugin in $conflictingPlugins) {
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

# 競合プラグインリストを config/integrated_plugins.yml から取得
$configPath = "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml"
$configContent = Get-Content $configPath -Raw
$conflictingPlugins = [regex]::Matches($configContent, '^\s+-\s+(.+)$', 'Multiline') | ForEach-Object { $_.Groups[1].Value.Trim() }

foreach ($plugin in $conflictingPlugins) {
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

3. コンテナを再起動（元の状態に戻す）

---

## 1. rails runner テスト

### Reply Button の競合検出

#### [1-1] 競合プラグインなし → 警告なし、モジュール登録あり

**確認方法:**
```ruby
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
has_warning = plugin.description.include?("WARNING")
permissions = Redmine::AccessControl.permissions.select { |p| p.project_module == :reply_button }
```

**期待結果:**
- `has_warning` が false
- `permissions.any?` が true

---

#### [1-2] 競合プラグインあり → 警告表示、モジュール登録なし

**確認方法:**
```ruby
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
has_warning = plugin.description.include?("WARNING")
permissions = Redmine::AccessControl.permissions.select { |p| p.project_module == :reply_button }
```

**期待結果:**
- `has_warning` が true
- `permissions.empty?` が true

---

#### [1-3] 空フォルダのみ（init.rb なし）→ 競合とみなさない

**確認方法:**
```ruby
plugins_dir = Rails.root.join('plugins')
folder_exists = File.directory?(plugins_dir.join('redmine_reply_button'))
init_exists = File.exist?(plugins_dir.join('redmine_reply_button', 'init.rb'))
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
has_warning = plugin.description.include?("WARNING")
```

**期待結果:**
- `folder_exists` が true
- `init_exists` が false
- `has_warning` が false

---

### Teams Button の競合検出

#### [2-1] 競合プラグインなし → 警告なし、モジュール登録あり

**確認方法:**
```ruby
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
has_warning = plugin.description.include?("WARNING")
permissions = Redmine::AccessControl.permissions.select { |p| p.project_module == :teams_button }
```

**期待結果:**
- `has_warning` が false
- `permissions.any?` が true

---

#### [2-2] 競合プラグインあり → 警告表示、モジュール登録なし

**確認方法:**
```ruby
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
has_warning = plugin.description.include?("WARNING")
permissions = Redmine::AccessControl.permissions.select { |p| p.project_module == :teams_button }
```

**期待結果:**
- `has_warning` が true
- `permissions.empty?` が true

---

#### [2-3] 空フォルダのみ（init.rb なし）→ 競合とみなさない

**確認方法:**
```ruby
plugins_dir = Rails.root.join('plugins')
folder_exists = File.directory?(plugins_dir.join('redmine_teams_button'))
init_exists = File.exist?(plugins_dir.join('redmine_teams_button', 'init.rb'))
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
has_warning = plugin.description.include?("WARNING")
```

**期待結果:**
- `folder_exists` が true
- `init_exists` が false
- `has_warning` が false

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいて以下の順序でテストを実行する:

1. フェーズ 1: 既存の競合プラグインを退避
2. フェーズ 2: コンテナ再起動 → 競合なしテスト実行
3. フェーズ 3: ダミー競合プラグイン作成 → コンテナ再起動 → 競合ありテスト実行
4. フェーズ 4: init.rb 削除 → コンテナ再起動 → 空フォルダテスト実行
5. フェーズ 5: クリーンアップ・復元 → コンテナ再起動
