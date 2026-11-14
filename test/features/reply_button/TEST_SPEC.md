# Reply Button テスト仕様書

## 概要

Reply Button 機能のテスト仕様。この文書から runner_test.rb, http_test.ps1, browser_setup_all.rb, browser_test.md を再生成できる。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| モジュール名 | `:reply_button` |
| Hooks クラス | `RedmineStudioPlugin::ReplyButton::Hooks` |
| View ファイル | `app/views/issues/reply_button/_reply.html.erb` |
| 競合プラグイン | `redmine_reply_button`（plugins/ 直下に init.rb があれば競合） |
| HTML 出力パターン | `rsp-icon-reply` |
| JS 出力パターン | `rspShowAndScrollTo`, `var reverseOrder = true/false` |

---

## テスト実行フロー

### フェーズ 1: 事前処理（退避）

競合プラグインが存在する場合、テスト前に**すべて**退避する。
（redmine_studio_plugin は競合プラグインが1つでも存在すると警告が出るため）

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "{RedmineRoot}"  # 実行環境から注入（test/README.md）
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

1. 2 章の用意を流し、[2-1] ～ [2-5] を実行し、後片付けを流す（データはその場で作って消す）

### フェーズ 4: ブラウザテスト

1. セットアップスクリプトを実行
2. [3-1] ～ [3-8] を対話形式で実行

### フェーズ 5: 事後処理（復元）

**復元タイミング:**
- ブラウザテストが完了した時点
- ブラウザテストがキャンセルされた時点

**Windows PowerShell で実行:**
```powershell
$redmineRoot = "{RedmineRoot}"  # 実行環境から注入（test/README.md）
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
puts permissions.any? ? 'PASS' : 'FAIL'
```

**期待結果:**
- `permissions.any?` が true（`PASS`）

---

### [1-2] Hooks クラスが定義されている

**確認方法:**
```ruby
puts defined?(RedmineStudioPlugin::ReplyButton::Hooks) ? 'PASS' : 'FAIL'
```

**期待結果:**
- 定義されている（nil ではない。`PASS`）

---

### [1-3] View ファイルが存在する

**確認方法:**
```ruby
view_path = Rails.root.join('plugins', 'redmine_studio_plugin', 'app', 'views', 'issues', 'reply_button', '_reply.html.erb')
puts File.exist?(view_path) ? 'PASS' : 'FAIL'
```

**期待結果:**
- ファイルが存在する（`PASS`）

---

### [1-4] 元プラグインで有効だったプロジェクト → 設定が引き継がれている

元プラグインとモジュール名（`reply_button`）が同じなので、元プラグインで有効にしたプロジェクトの記録（`enabled_modules` の行）がそのまま効く。
元プラグインが残す記録と同じ行をその場で作ったプロジェクトに直接入れ、有効として読まれることを確かめる（終わったら消す）。

**確認方法:**
```ruby
User.current = User.find(1)
sfx = SecureRandom.hex(3)
project = nil
begin
  project = Project.new(name: "RB14_#{sfx}", identifier: "rb14-#{sfx}", is_public: false)
  project.enabled_module_names = %w[issue_tracking]
  project.save!
  # 元プラグインが残す記録と同じ形（モジュール名だけの行）を直接入れる
  EnabledModule.insert_all([{ project_id: project.id, name: 'reply_button' }])
  registered = Redmine::AccessControl.available_project_modules.include?(:reply_button)
  ok = registered && Project.find(project.id).module_enabled?(:reply_button)
  puts ok ? 'PASS' : "FAIL: registered=#{registered} enabled=#{Project.find(project.id).module_enabled?(:reply_button).inspect}"
ensure
  Project.find_by(id: project.id)&.destroy if project&.id
end
```

**期待結果:**
- `PASS`（モジュール `reply_button` が登録されていて、元プラグインの記録を持つプロジェクトで有効として読まれる）

---

## 2. HTTP テスト

**実行方法:** 下の用意で、reply_button が有効なプロジェクトと無効なプロジェクトにチケットを 1 つずつ作り、コメントの並び順が「新しい順」と「古い順」の利用者を 1 人ずつ作る（終わったら後片付けで消す）。
各試験は、用意で作った利用者でセッション認証（下の認証方法）してチケット画面の HTML を取る。用意の JSON の名前（`{OnIssueId}` など）を各試験のブロックに入れて流す。

**認証方法:**
1. `/login` ページから CSRF トークンを取得（`csrf-token" content="([^"]+)"` パターン）
2. POST `/login` でセッション確立

**用意（HTTP テストの前に 1 回）:**

```ruby
Project.where('identifier LIKE ?', 'rb-spec-%').order(id: :desc).each(&:destroy)
User.where('login LIKE ?', 'rb_spec_%').each(&:destroy)
Role.where('name LIKE ?', 'RB_Spec_%').each(&:destroy)
sfx = SecureRandom.hex(3)
admin = User.find(1)
tracker = Tracker.sorted.first
# 編集欄（Reply ボタンを出すところ）が出るように、注記の追加と編集の権限を持たせる
role = Role.create!(name: "RB_Spec_Role_#{sfx}", permissions: [:view_issues, :add_issue_notes, :edit_issues])
pw = "Pw-#{sfx}-x9Z"
mk_user = ->(sorting) {
  u = User.new(login: "rb_spec_#{sorting}_#{sfx}", firstname: 'RB', lastname: sorting, mail: "rb_spec_#{sorting}_#{sfx}@example.com", status: User::STATUS_ACTIVE)
  u.password = u.password_confirmation = pw
  u.save!
  u.pref.comments_sorting = sorting
  u.pref.save!
  u
}
asc = mk_user.call('asc')
desc = mk_user.call('desc')
mk_issue = ->(name, modules) {
  prj = Project.new(name: "RB_Spec_#{name}_#{sfx}", identifier: "rb-spec-#{name}-#{sfx}", is_public: false)
  prj.enabled_module_names = modules
  prj.trackers = [tracker]
  prj.save!
  [asc, desc].each { |u| Member.create!(principal: u, project: prj, roles: [role]) }
  Issue.create!(project: prj, tracker: tracker, subject: "RB_Spec_#{name}_#{sfx}", author: admin)
}
on = mk_issue.call('on', %w[issue_tracking reply_button])
off = mk_issue.call('off', %w[issue_tracking])
puts({ OnIssueId: on.id, OffIssueId: off.id, AscLogin: asc.login, DescLogin: desc.login, UserPassword: pw }.to_json)
```

**後片付け（HTTP テストのあとに 1 回）:**

```ruby
Project.where('identifier LIKE ?', 'rb-spec-%').order(id: :desc).each(&:destroy)
User.where('login LIKE ?', 'rb_spec_%').each(&:destroy)
Role.where('name LIKE ?', 'RB_Spec_%').each(&:destroy)
puts 'cleanup: ok'
```

### [2-1] モジュール有効のチケット画面 → rsp-icon-reply が HTML に存在

**確認方法:** reply_button が有効なプロジェクトのチケット（`{OnIssueId}`）の画面の HTML

```powershell
$p = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable ws
$tok = [regex]::Match($p.Content, 'csrf-token" content="([^"]+)"').Groups[1].Value
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -WebSession $ws -Body @{ authenticity_token = $tok; username = '{AscLogin}'; password = '{UserPassword}' } | Out-Null
$html = (Invoke-WebRequest -Uri '{BaseUrl}/issues/{OnIssueId}' -WebSession $ws).Content
"[2-1] " + $(if ($html.Contains('rsp-icon-reply')) { 'PASS' } else { 'FAIL' })
```

**期待結果:**
- `[2-1] PASS`（HTML に `rsp-icon-reply` が含まれる）

---

### [2-2] モジュール無効のチケット画面 → rsp-icon-reply が存在しない

**確認方法:** reply_button が無効なプロジェクトのチケット（`{OffIssueId}`）の画面の HTML。編集欄が出ていることも確かめる（出ていないと、ボタンが無いことを確かめられない）

```powershell
$p = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable ws
$tok = [regex]::Match($p.Content, 'csrf-token" content="([^"]+)"').Groups[1].Value
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -WebSession $ws -Body @{ authenticity_token = $tok; username = '{AscLogin}'; password = '{UserPassword}' } | Out-Null
$html = (Invoke-WebRequest -Uri '{BaseUrl}/issues/{OffIssueId}' -WebSession $ws).Content
"[2-2] " + $(if ($html.Contains('id="issue_notes"') -and -not $html.Contains('rsp-icon-reply')) { 'PASS' } else { 'FAIL' })
```

**期待結果:**
- `[2-2] PASS`（編集欄はあり、HTML に `rsp-icon-reply` が含まれない）

---

### [2-3] JavaScript ファイルが読み込まれている

**確認方法:** モジュール有効プロジェクトのチケット（`{OnIssueId}`）の画面の HTML

```powershell
$p = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable ws
$tok = [regex]::Match($p.Content, 'csrf-token" content="([^"]+)"').Groups[1].Value
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -WebSession $ws -Body @{ authenticity_token = $tok; username = '{AscLogin}'; password = '{UserPassword}' } | Out-Null
$html = (Invoke-WebRequest -Uri '{BaseUrl}/issues/{OnIssueId}' -WebSession $ws).Content
# プラグインが出す script ブロック（rsp-icon-reply を含む <script> 要素）だけを見る
$own = @([regex]::Matches($html, '(?s)<script[^>]*>.*?</script>') | Where-Object { $_.Value.Contains('rsp-icon-reply') } | ForEach-Object { $_.Value })
# コアの showAndScrollTo の裸呼び出し（rsp の付かない呼び出し）が無いこと
$bare = @($own | Where-Object { $_ -cmatch '(?<![A-Za-z])showAndScrollTo\(' }).Count
"[2-3] " + $(if ($own.Count -gt 0 -and $html.Contains('rspShowAndScrollTo') -and $bare -eq 0) { 'PASS' } else { "FAIL: blocks=$($own.Count) bare=$bare" })
```

**期待結果:**
- `[2-3] PASS`
  - HTML に `rsp-icon-reply` と `rspShowAndScrollTo` の両方が含まれる
  - プラグインが出力する script ブロック（`rsp-icon-reply` を含む `<script>` 要素）内に、コア関数 `showAndScrollTo` の裸呼び出し（`rsp` プレフィックスなし）が含まれない
  - ※ ページ全体にはコア自身の「編集」リンク（`onclick="showAndScrollTo(...)"`）が含まれるため、確認はプラグインの script ブロックにスコープする

---

### [2-4] コメント逆順設定 ON → reverseOrder = true が出力

**確認方法:** コメントの並び順が「新しい順」（`comments_sorting: 'desc'`）の利用者（`{DescLogin}`）でセッション認証し、`{OnIssueId}` の画面の HTML を取る

```powershell
$p = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable ws
$tok = [regex]::Match($p.Content, 'csrf-token" content="([^"]+)"').Groups[1].Value
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -WebSession $ws -Body @{ authenticity_token = $tok; username = '{DescLogin}'; password = '{UserPassword}' } | Out-Null
$html = (Invoke-WebRequest -Uri '{BaseUrl}/issues/{OnIssueId}' -WebSession $ws).Content
"[2-4] " + $(if ($html.Contains('var reverseOrder = true')) { 'PASS' } else { 'FAIL' })
```

**期待結果:**
- `[2-4] PASS`（HTML に `var reverseOrder = true` が含まれる）

**備考:**
- API キー認証ではユーザー設定（comments_sorting）が適用されないため、セッション認証が必須
- 並び順は用意で作った利用者に持たせるので、ほかの利用者の設定は変えない

---

### [2-5] コメント逆順設定 OFF → reverseOrder = false が出力

**確認方法:** コメントの並び順が「古い順」（`comments_sorting: 'asc'`）の利用者（`{AscLogin}`）でセッション認証し、`{OnIssueId}` の画面の HTML を取る

```powershell
$p = Invoke-WebRequest -Uri '{BaseUrl}/login' -SessionVariable ws
$tok = [regex]::Match($p.Content, 'csrf-token" content="([^"]+)"').Groups[1].Value
Invoke-WebRequest -Uri '{BaseUrl}/login' -Method Post -WebSession $ws -Body @{ authenticity_token = $tok; username = '{AscLogin}'; password = '{UserPassword}' } | Out-Null
$html = (Invoke-WebRequest -Uri '{BaseUrl}/issues/{OnIssueId}' -WebSession $ws).Content
"[2-5] " + $(if ($html.Contains('var reverseOrder = false')) { 'PASS' } else { 'FAIL' })
```

**期待結果:**
- `[2-5] PASS`（HTML に `var reverseOrder = false` が含まれる）

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

- 管理者ユーザーが存在すること（ログイン情報は実行環境から注入。契約は `test/README.md`）
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
| 3-5 | [3-5] 自分スキップテスト | admin | - | test_active, admin, admin | コメント1, コメント2, コメント3 |
| 3-6 | [3-6] 全コメントが自分テスト | test_author | - | admin, admin | コメント1, コメント2 |
| 3-7 | [3-7] 担当者設定済みチケット | admin | test_assignee | - | - |
| 3-8 | [3-8] コメント逆順テストチケット | admin | - | test_commenter, admin | コメント1, コメント2 |

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

### [3-5] 最終コメントが自分 → 自分をスキップして前の他ユーザーが担当者に設定

**セットアップ:**
- チケットを作成（作成者: admin）
- test_active ユーザーからコメントを追加
- admin（自分）からコメントを2件追加

**手順:**
1. admin でログイン
2. チケット画面を開く
3. 「返答」ボタンをクリック

**期待結果:**
- 担当者欄に「Test ActiveUser」が設定される
- （admin の2件のコメントをスキップして、test_active のコメントが選択される）

---

### [3-6] 全コメントが自分 → 自分が担当者に設定

**セットアップ:**
- チケットを作成（作成者: test_author）
- admin（自分）からコメントを2件追加

**手順:**
1. admin でログイン
2. チケット画面を開く
3. 「返答」ボタンをクリック

**期待結果:**
- 担当者欄に「Redmine Admin」が設定される
- （他ユーザーのコメントがないため、自分のまま）

---

### [3-7] Edit クリック → 現在の担当者が担当者欄に設定（旧 [3-5]）

**セットアップ:**
- チケットを作成（作成者: admin）
- 担当者に test_assignee を設定

**手順:**
1. チケット画面を開く
2. 「編集」ボタンをクリック（※返答ではない）

**期待結果:**
- 担当者欄に「Test Assignee」が設定される

---

### [3-8] コメント逆順設定 ON → 編集エリアが履歴の先頭に移動（旧 [3-6]）

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
