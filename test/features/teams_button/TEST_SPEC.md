# Teams Button テスト仕様書

## 概要

redmine_studio_plugin の Teams Button 機能のテスト仕様。チケット画面のユーザー名に Teams ボタンを追加し、クリックで Teams チャットを起動する機能。

## 環境パラメータ

パスから自動判定:
- `redmine_5.1.11` → コンテナ名: `redmine_5.1.11`, ポート: `3051`
- `redmine_6.1.1` → コンテナ名: `redmine_6.1.1`, ポート: `3061`

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| コントローラ | `TeamsButtonController` |
| エンドポイント | `GET /teams_button/user_email/:id` |
| フッククラス | `RedmineStudioPlugin::TeamsButton::Hooks` |
| プロジェクトモジュール | `:teams_button` |
| ビューパーシャル | `issues/teams_button/_teams_button.html.erb` |
| 競合プラグイン | `redmine_teams_button`（plugins/ 直下に init.rb があれば競合） |

---

## テスト実行フロー

### フェーズ 1: 事前処理（退避）

競合プラグインが存在する場合、テスト前に**すべて**退避する。
（redmine_studio_plugin は競合プラグインが1つでも存在すると警告が出るため）

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
        }
    }
}
```

**注意:** 退避後はコンテナの再起動が必要（競合検出は Rails 起動時に行われるため）。

### フェーズ 2: Runner テスト

1. [1-1] ～ [1-4] を実行

### フェーズ 3: HTTP テスト

1. [2-1] ～ [2-3] を実行

### フェーズ 4: ブラウザテスト

1. セットアップスクリプトを実行
2. [3-1] ～ [3-4] を対話形式で実行

### フェーズ 5: 事後処理（復元）

**復元タイミング:**
- ブラウザテストが完了した時点
- ブラウザテストがキャンセルされた時点

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "C:\Docker\redmine_X.Y.Z"  # TEST_SPEC.md のパスから判定
$pluginsDir = "$redmineRoot\plugins"
$backupDir = "$redmineRoot\test_backup"

# 競合プラグインリストを config/integrated_plugins.yml から取得
$configPath = "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml"
$configContent = Get-Content $configPath -Raw
$conflictingPlugins = [regex]::Matches($configContent, '^\s+-\s+(.+)$', 'Multiline') | ForEach-Object { $_.Groups[1].Value.Trim() }

# 競合プラグインを復元
foreach ($plugin in $conflictingPlugins) {
    $pluginPath = "$pluginsDir\$plugin"
    $backupPath = "$backupDir\$plugin"
    if (Test-Path $backupPath) {
        if (Test-Path $pluginPath) {
            Remove-Item -Path $pluginPath -Recurse -Force
        }
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

## 1. Runner テスト

### [1-1] プロジェクトモジュール登録確認

**確認方法:**
```ruby
permissions = Redmine::AccessControl.permissions.select { |p| p.project_module == :teams_button }
puts permissions.any?
```

**期待結果:** `true` が出力される

### [1-2] ルーティング確認

**確認方法:**
```ruby
route = Rails.application.routes.recognize_path('/teams_button/user_email/1', method: :get)
puts route[:controller]
puts route[:action]
```

**期待結果:**
- controller: `teams_button`
- action: `user_email`

### [1-3] コントローラ確認

**確認方法:**
```ruby
puts defined?(TeamsButtonController)
puts TeamsButtonController.ancestors.include?(ApplicationController)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-4] フック登録確認

**確認方法:**
```ruby
hooks = Redmine::Hook.hook_listeners(:view_issues_edit_notes_bottom)
puts hooks.any? { |h| h.is_a?(RedmineStudioPlugin::TeamsButton::Hooks) }
```

**期待結果:** `true` が出力される

---

## 2. HTTP テスト

### [2-1] メールアドレス取得（正常系）

**確認方法:**
```powershell
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$loginResponse = Invoke-WebRequest -Uri "http://localhost:3051/login" -SessionVariable session
$token = [regex]::Match($loginResponse.Content, 'name="authenticity_token" value="([^"]+)"').Groups[1].Value
Invoke-WebRequest -Uri "http://localhost:3051/login" -Method POST -Body @{username="admin"; password="password123"; authenticity_token=$token} -WebSession $session
$response = Invoke-RestMethod -Uri "http://localhost:3051/teams_button/user_email/1" -WebSession $session
$response.email
```

**期待結果:** admin ユーザーのメールアドレスが返される

### [2-2] 存在しないユーザー

**確認方法:**
```powershell
# 上記セッションを使用
$response = Invoke-RestMethod -Uri "http://localhost:3051/teams_button/user_email/99999" -WebSession $session
$response.email -eq $null
```

**期待結果:** `True`（email が null）

### [2-3] 未ログイン状態でのアクセス

**確認方法:**
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:3051/teams_button/user_email/1" -MaximumRedirection 0 -ErrorAction SilentlyContinue
$response.StatusCode
```

**期待結果:** 302（ログインページへリダイレクト）

---

## 3. ブラウザテスト

### 実行フロー

ブラウザテストは以下の流れで実行する：

1. **一括環境セットアップ**（待ち時間はここで発生）
   - Claude が TEST_SPEC.md の仕様を読み、セットアップスクリプトを生成
   - 生成したスクリプトを `rails runner` で実行
   - 各テスト用チケットの URL を取得

2. **対話形式でテスト実行**（待ち時間なし）
   - Claude が各テストの URL と手順を提示
   - ユーザーがブラウザで確認
   - ユーザーが結果（PASS/FAIL）を回答
   - 次のテストへ進む

3. **テスト終了時に復元**
   - すべてのテストが完了、またはキャンセルされた時点で競合プラグインを復元

### セットアップデータ

**プロジェクト:**

| 識別子 | 名前 | Teams button モジュール |
|--------|------|------------------------|
| teams-test | Teams Button テスト | 有効 |
| teams-disabled | Teams Button 無効 | 無効 |

**グループ:**

| 名前 |
|------|
| TestGroup |

**ユーザー:**

| login | firstname | lastname | パスワード |
|-------|-----------|----------|-----------|
| testuser | Test | User | password123 |

**チケット:**

| テストID | プロジェクト | subject | 担当者 |
|----------|-------------|---------|--------|
| [3-1], [3-3] | teams-test | Teams有効テスト | testuser |
| [3-2] | teams-disabled | Teams無効テスト | testuser |
| [3-4] | teams-test | グループ担当テスト | TestGroup |

### [3-1] モジュール有効時の表示

**手順:**
1. admin でログイン
2. 「Teams有効テスト」チケットを開く

**確認:** ユーザー名の横に Teams アイコンが表示される

### [3-2] モジュール無効時の表示

**手順:**
1. admin でログイン
2. 「Teams無効テスト」チケットを開く

**確認:** Teams アイコンが表示されない

### [3-3] Teams URL の生成

**手順:**
1. admin でログイン
2. 「Teams有効テスト」チケットを開く
3. Teams アイコンをクリック

**確認:** 新しいウィンドウ/タブが開き、URL に以下が含まれる:
- `teams.microsoft.com`
- `users=` にメールアドレス
- `message=` にチケット情報

### [3-4] グループ担当者の場合

**手順:**
1. admin でログイン
2. 「グループ担当テスト」チケットを開く

**確認:** グループ名の横に Teams アイコンが表示されない

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいて以下の順序でテストを実行する:

1. フェーズ 1: 競合プラグインを退避 → コンテナ再起動
2. フェーズ 2: Runner テスト実行
3. フェーズ 3: HTTP テスト実行
4. フェーズ 4: ブラウザテスト実行
5. フェーズ 5: 競合プラグインを復元（ブラウザテスト完了またはキャンセル時）
