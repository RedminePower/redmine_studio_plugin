# redmine_studio_plugin テスト

このプラグインのテストはそれぞれの項目の TEST_SPEC.md に基づいて Claude が実行します。

## テスト仕様ファイル

| ファイル | 説明 |
|---------|------|
| `install_task/TEST_SPEC.md` | Install タスクテスト |
| `conflict_detection/TEST_SPEC.md` | 競合プラグイン検出テスト |
| `features/plugin_api/TEST_SPEC.md` | プラグイン情報 API テスト |
| `features/reply_button/TEST_SPEC.md` | Reply Button テスト |
| `features/teams_button/TEST_SPEC.md` | Teams Button テスト |
| `features/auto_close/TEST_SPEC.md` | Auto Close テスト |
| `features/date_independent/TEST_SPEC.md` | Date Independent テスト |

## テストの種類

| 種類 | 説明 |
|------|------|
| Runner テスト | Claude が TEST_SPEC.md から Ruby スクリプトを生成・実行 |
| HTTP テスト | Claude が TEST_SPEC.md から PowerShell で API を呼び出し |
| ブラウザテスト | Claude が環境セットアップ後、対話形式でユーザをガイド |

## 環境パラメータ

| パラメータ | 判定方法 |
|-----------|----------|
| Container | TEST_SPEC.md のパスから自動判定（例: `redmine_5.1.11`） |
| BaseUrl | バージョンからポート算出（`3000 + メジャー×10 + マイナー`） |

## 共通の事前条件

features 配下のテストを実行する前に、統合済みプラグインが存在すれば、無効化する。
無効化した場合、テスト完了後は必ず有効化して元に戻す。

### テスト前: 無効化（init.rb → init.rb.bak）

```powershell
$pluginsDir = "C:\Docker\redmine_X.Y.Z\plugins"  # 環境に合わせて変更
$configPath = "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml"
$configContent = Get-Content $configPath -Raw
$integratedPlugins = [regex]::Matches($configContent, '^\s+-\s+(.+)$', 'Multiline') | ForEach-Object { $_.Groups[1].Value.Trim() }

foreach ($plugin in $integratedPlugins) {
    $initPath = "$pluginsDir\$plugin\init.rb"
    if (Test-Path $initPath) {
        Rename-Item -Path $initPath -NewName "init.rb.bak" -Force
        Write-Host "Disabled: $plugin"
    }
}
```

### テスト後: 有効化（init.rb.bak → init.rb）

```powershell
$pluginsDir = "C:\Docker\redmine_X.Y.Z\plugins"  # 環境に合わせて変更
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

## テストの実行方法

Claude に以下のように依頼してください:

**全テスト実行:**
- `全てのテストを実行してください`
- `テストを実行してください`

**個別実行:**
- `install_task のテストを実行してください`
- `conflict_detection のテストを実行してください`
- `plugin_api のテストを実行してください`
- `reply_button のテストを実行してください`
- `teams_button のテストを実行してください`
- `auto_close のテストを実行してください`
- `date_independent のテストを実行してください`
