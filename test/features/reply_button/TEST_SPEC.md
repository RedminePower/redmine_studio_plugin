# Reply Button テスト仕様書

## 概要

Reply Button 機能のテスト仕様。この文書から runner_test.rb, http_test.ps1, browser_setup_all.rb, browser_test.md を再生成できる。

## 環境パラメータ

以下のパラメータは TEST_SPEC.md のパスから自動判定する:

| パラメータ | 判定方法 |
|-----------|----------|
| Container | パス内の `redmine_X.Y.Z` フォルダ名をそのまま使用 |
| BaseUrl | バージョンからポート算出: `3000 + (メジャー × 10) + マイナー` |

固定パラメータ:

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| Username | `admin` | テスト用ログインID |
| Password | `password123` | テスト用パスワード |
| TestProject | `test-plugin` | テスト用プロジェクト識別子 |

**例:** パスが `C:\Docker\redmine_6.1.1\plugins\...` の場合
- Container: `redmine_6.1.1`
- BaseUrl: `http://localhost:3061`（3000 + 60 + 1）

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| モジュール名 | `:reply_button` |
| Hooks クラス | `RedmineStudioPlugin::ReplyButton::Hooks` |
| View ファイル | `app/views/issues/reply_button/_reply.html.erb` |
| 競合プラグイン | `redmine_reply_button`（plugins/ 直下に init.rb があれば競合） |
| HTML 出力パターン | `icon-reply` |
| JS 出力パターン | `showAndScrollTo`, `var reverseOrder = true/false` |

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

1. [2-1] ～ [2-5] を実行

### フェーズ 4: ブラウザテスト

1. セットアップスクリプトを実行
2. [3-1] ～ [3-6] を対話形式で実行

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

## 1. rails runner テスト

**実行方法:**
```bash
docker exec {Container} rails runner plugins/redmine_studio_plugin/test/features/reply_button/runner_test.rb
```

### [1-1] reply_button モジュールが登録されている

**確認方法:**
```ruby
permissions = Redmine::AccessControl.permissions.select { |p| p.project_module == :reply_button }
```

**期待結果:**
- `permissions.any?` が true

---

### [1-2] Hooks クラスが定義されている

**確認方法:**
```ruby
defined?(RedmineStudioPlugin::ReplyButton::Hooks)
```

**期待結果:**
- 定義されている（nil ではない）

---

### [1-3] View ファイルが存在する

**確認方法:**
```ruby
view_path = Rails.root.join('plugins', 'redmine_studio_plugin', 'app', 'views', 'issues', 'reply_button', '_reply.html.erb')
File.exist?(view_path)
```

**期待結果:**
- ファイルが存在する

---

### [1-4] 元プラグインで有効だったプロジェクト → 設定が引き継がれている

**確認方法:**
```ruby
project = Project.find_by_identifier('test-plugin')
project.module_enabled?(:reply_button)
```

**期待結果:**
- モジュールが有効

**スキップ条件:**
- test-plugin プロジェクトが存在しない場合

---

## 2. HTTP テスト

**実行方法:**
```powershell
pwsh -File "...\http_test.ps1" -BaseUrl "http://localhost:3051"
```

**認証方法:**
1. `/login` ページから CSRF トークンを取得（`csrf-token" content="([^"]+)"` パターン）
2. POST `/login` でセッション確立

### [2-1] モジュール有効のチケット画面 → icon-reply が HTML に存在

**テスト対象チケットの取得:**
```ruby
Issue.joins(:project)
     .joins('INNER JOIN enabled_modules ON enabled_modules.project_id = projects.id')
     .where(enabled_modules: { name: 'reply_button' })
     .first
```

**確認方法:**
- GET `/issues/{id}` のレスポンス HTML

**期待結果:**
- HTML に `icon-reply` が含まれる

---

### [2-2] モジュール無効のチケット画面 → icon-reply が存在しない

**テスト対象チケットの取得:**
```ruby
Issue.joins(:project)
     .where.not(projects: { id: EnabledModule.where(name: 'reply_button').select(:project_id) })
     .first
```

**確認方法:**
- GET `/issues/{id}` のレスポンス HTML

**期待結果:**
- HTML に `icon-reply` が含まれない

---

### [2-3] JavaScript ファイルが読み込まれている

**確認方法:**
- GET `/issues/{id}` のレスポンス HTML（モジュール有効プロジェクト）

**期待結果:**
- HTML に `icon-reply` と `showAndScrollTo` の両方が含まれる

---

### [2-4] コメント逆順設定 ON → reverseOrder = true が出力

**事前設定:**
```ruby
User.find_by_login('admin').pref.update(comments_sorting: 'desc')
```

**確認方法:**
- セッション認証でログイン後、GET `/issues/{id}` のレスポンス HTML を取得

**期待結果:**
- HTML に `var reverseOrder = true` が含まれる

**備考:**
- API キー認証ではユーザー設定（comments_sorting）が適用されないため、セッション認証が必須

---

### [2-5] コメント逆順設定 OFF → reverseOrder = false が出力

**事前設定:**
```ruby
User.find_by_login('admin').pref.update(comments_sorting: 'asc')
```

**確認方法:**
- セッション認証でログイン後、GET `/issues/{id}` のレスポンス HTML を取得

**期待結果:**
- HTML に `var reverseOrder = false` が含まれる

**備考:**
- API キー認証ではユーザー設定（comments_sorting）が適用されないため、セッション認証が必須

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

### 前提条件

- admin ユーザーが存在すること（ログイン: admin / パスワード: password123）
- test-plugin プロジェクトが存在し、reply_button モジュールが有効であること

### 初期設定

セットアップ開始時に以下を実行:
- admin のコメント表示順を「古い順」(`asc`) にリセット

### セットアップで作成するユーザー

| login | firstname | lastname | 状態 | パスワード |
|-------|-----------|----------|------|-----------|
| test_active | Test | ActiveUser | ACTIVE | password123 |
| test_author | Test | Author | ACTIVE | password123 |
| test_author2 | Test | Author2 | ACTIVE | password123 |
| test_locked | Test | LockedUser | LOCKED | password123 |
| test_assignee | Test | Assignee | ACTIVE | password123 |
| test_commenter | Test | Commenter | ACTIVE | password123 |

※ 全ユーザーを test-plugin プロジェクトにメンバー追加（ロール: Manager または最初の非ビルトインロール）

### セットアップで作成するチケット

| テスト | subject | 作成者 | 担当者 | コメント投稿者 | コメント内容 |
|--------|---------|--------|--------|---------------|-------------|
| 3-1 | [3-1] Reply ボタンテスト用チケット | admin | - | - | - |
| 3-2 | [3-2] コメント付きチケット（アクティブユーザー） | admin | - | test_active | テストコメント |
| 3-3 | [3-3] コメントなしチケット | test_author | - | - | - |
| 3-4 | [3-4] ロックユーザーコメントチケット | test_author2 | - | test_locked | ロックユーザーからのコメント |
| 3-5 | [3-5] 担当者設定済みチケット | admin | test_assignee | - | - |
| 3-6 | [3-6] コメント逆順テストチケット | admin | - | test_commenter, admin | コメント1, コメント2 |

### セットアップ出力形式

JSON 形式で各テストの情報を出力:
```json
{
  "success": true,
  "results": {
    "3-1": { "issue_id": 123, "url": "/issues/123" },
    "3-2": { "issue_id": 124, "url": "/issues/124", "last_commenter": "Test ActiveUser" },
    ...
  }
}
```

---

### [3-1] Reply クリック → ノート入力欄が開く

**セットアップ:**
- チケットを作成（作成者: admin）

**手順:**
1. チケット画面を開く
2. 「返答」ボタンをクリック

**期待結果:**
- ノート入力欄が表示される
- 入力欄にフォーカスが当たる

---

### [3-2] Reply クリック → 最新コメント投稿者が担当者に設定

**セットアップ:**
- チケットを作成（作成者: admin）
- test_active ユーザーからコメントを追加

**手順:**
1. チケット画面を開く
2. 「返答」ボタンをクリック

**期待結果:**
- 担当者欄に「Test ActiveUser」が設定される

---

### [3-3] コメントなし → チケット作成者が担当者に設定

**セットアップ:**
- チケットを作成（作成者: test_author）
- コメントなし

**手順:**
1. チケット画面を開く
2. 「返答」ボタンをクリック

**期待結果:**
- 担当者欄に「Test Author」が設定される

---

### [3-4] 最新コメント投稿者が非アクティブ → チケット作成者にフォールバック

**セットアップ:**
- チケットを作成（作成者: test_author2）
- test_locked（LOCKED 状態）ユーザーからコメントを追加

**手順:**
1. チケット画面を開く
2. 「返答」ボタンをクリック

**期待結果:**
- 担当者欄に「Test Author2」が設定される
- （Test LockedUser は非アクティブのため選択されない）

---

### [3-5] Edit クリック → 現在の担当者が担当者欄に設定

**セットアップ:**
- チケットを作成（作成者: admin）
- 担当者に test_assignee を設定

**手順:**
1. チケット画面を開く
2. 「編集」ボタンをクリック（※返答ではない）

**期待結果:**
- 担当者欄に「Test Assignee」が設定される

---

### [3-6] コメント逆順設定 ON → 編集エリアが履歴の先頭に移動

**セットアップ:**
- チケットを作成（作成者: admin）
- コメントを2件追加
- ※設定変更は手順で実施（セットアップでは `asc` のまま）

**手順:**
1. チケット画面を開く
2. 編集エリアが履歴セクションの**末尾**（下部）にあることを確認
3. 個人設定を開く
4. コメントの表示順を「新しい順」に変更して保存
5. チケット画面を再度開く

**期待結果:**
- 編集エリア（ノート入力欄）が履歴セクションの**先頭**（上部）に表示される

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいて以下の順序でテストを実行する:

1. フェーズ 1: 競合プラグインを退避 → コンテナ再起動
2. フェーズ 2: Runner テスト実行
3. フェーズ 3: HTTP テスト実行
4. フェーズ 4: ブラウザテスト実行
5. フェーズ 5: 競合プラグインを復元（ブラウザテスト完了またはキャンセル時）

## 参考ファイル（保守対象外）

以下は参考実装。TEST_SPEC.md が正とし、Claude が必要に応じて再生成する。

| ファイル | 説明 |
|---------|------|
| runner_test.rb | rails runner テスト参考実装 |
| http_test.ps1 | HTTP テスト参考実装 |
| browser_setup_all.rb | ブラウザテスト環境セットアップ参考実装 |
