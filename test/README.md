# redmine_studio_plugin テスト

このプラグインのテストはそれぞれの項目の TEST_SPEC.md に基づいて Claude が実行します。

## テスト仕様ファイル

| ファイル | 説明 |
|---------|------|
| `install_task/TEST_SPEC.md` | Install タスクテスト |
| `conflict_detection/TEST_SPEC.md` | 競合プラグイン検出テスト |
| `features/plugin_api/TEST_SPEC.md` | プラグイン情報 API テスト |
| `features/info_api/TEST_SPEC.md` | Redmine 情報 API テスト |
| `features/reply_button/TEST_SPEC.md` | Reply Button テスト |
| `features/teams_button/TEST_SPEC.md` | Teams Button テスト |
| `features/auto_close/TEST_SPEC.md` | Auto Close テスト |
| `features/date_independent/TEST_SPEC.md` | Date Independent テスト |
| `features/wiki_lists/TEST_SPEC.md` | Wiki Lists テスト |
| `features/subtask_list_accordion/TEST_SPEC.md` | Subtask List Accordion テスト |
| `features/studio_settings_api/TEST_SPEC.md` | Studio Settings API テスト |
| `features/journals_list/TEST_SPEC.md` | Journals List（コメント履歴）テスト |
| `features/reply_count/TEST_SPEC.md` | Reply Count（返答回数）テスト |
| `features/children_count/TEST_SPEC.md` | Children Count（子チケット数）テスト |
| `features/wiki_preview_api/TEST_SPEC.md` | Wiki Preview API（Wiki テキスト→HTML 変換）テスト |
| `features/cache_bundle/TEST_SPEC.md` | Cache Bundle API（キャッシュ一括取得）テスト |
| `features/oauth_client_api/TEST_SPEC.md` | OAuth クライアント情報 API・ブラウザサインイン支援（前段 Basic ゲート下のトークン取得パッチ含む）テスト |
| `features/roadmap_display/TEST_SPEC.md` | Roadmap Display（ロードマップのチケット一覧の列・グループ表示）テスト |

## テストの種類

| 種類 | 説明 |
|------|------|
| Runner テスト | Claude が TEST_SPEC.md から Ruby スクリプトを生成・実行 |
| HTTP テスト | Claude が TEST_SPEC.md から PowerShell で API を呼び出し |
| ブラウザテスト | Claude が環境セットアップ後、対話形式でユーザをガイド |

## 環境パラメータ

本テストは Redmine **5.x / 6.x / 7.x** の 3 メジャーバージョンで実施する。どのパッチ版で動かすか、接続先アドレス・ポート・サブディレクトリの有無・コンテナ名・認証情報は**実行環境ごとに異なる**ため、このリポジトリには書かない。各 TEST_SPEC は下記のプレースホルダのみを使い、具体値は実行する環境の設定から注入する。

| プレースホルダ | 意味 |
|---------------|------|
| `{BaseUrl}` | Redmine のベース URL（サブディレクトリ配下ならそれも含む・末尾スラッシュなし） |
| `{Username}` / `{Password}` | 管理者アカウントのログイン / パスワード |
| `{ApiKey}` | 管理者の API キー |
| `{UserApiKey}` | 非管理（限定権限）ユーザの API キー（一部のテストで使用） |
| `{UserId}` | 上記の非管理ユーザのユーザ ID（一部のテストで使用） |
| `{Container}` | Redmine が動いている Docker コンテナ名（Runner テスト・再起動で使用） |
| `{RedmineRoot}` | ホスト側の Redmine フォルダ（`plugins` を含むフォルダ。プラグインの無効化・有効化で使用） |

なお、テスト内で新規作成するユーザのパスワードなど、テスト自身が用意する値は各 TEST_SPEC に記載する（環境からの注入対象ではない）。

### 具体値の置き場所

具体値は `test/env.local.json` に書く。このファイルは `.gitignore` 済みでリポジトリには入らない。キーはプレースホルダ名と同じで、メジャーバージョンごとに値を持つ（5.x・7.x も同じ形で並べる）。

```json
{
  "6.x": {
    "BaseUrl": "...", "Username": "...", "Password": "...", "ApiKey": "...",
    "UserApiKey": "...", "UserId": "...", "Container": "...", "RedmineRoot": "..."
  }
}
```

テストを実行するときは `test/env.local.json` から対象バージョンの値を読み、TEST_SPEC のプレースホルダに当てはめる。`env.local.json` が無い場合や値が足りない場合は、TEST_SPEC やこの README に具体値を書き足すのではなく、実行する人に値を確認する。

### 公開リポジトリとしての注意

このリポジトリは公開されている。接続先・ポート・サブディレクトリ・コンテナ名・パッチ版・認証情報・API キーなど環境固有の値は、ファイル・コミットメッセージ・PR のタイトル/本文のどこにも書かない。PR とプッシュの際に自動チェック（`.github/workflows/public-repo-guard.yml`）が検査する。

## 共通の事前条件

features 配下のテストを実行する前に、統合済みプラグインが存在すれば、無効化する。
無効化した場合、テスト完了後は必ず有効化して元に戻す。

**重要:** `init.rb` だけでなく `lib` フォルダもリネームする必要がある。
`init.rb` のみリネームした場合、Rails のオートロードにより `lib` 配下のパッチが読み込まれ、
旧プラグインの設定キー（`Setting.plugin_redmine_xxx`）を参照してエラーになる。

### テスト前: 無効化

```powershell
$pluginsDir = "{RedmineRoot}\plugins"  # 実行環境から注入
$configPath = "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml"
$configContent = Get-Content $configPath -Raw
$integratedPlugins = [regex]::Matches($configContent, '^\s+-\s+(.+)$', 'Multiline') | ForEach-Object { $_.Groups[1].Value.Trim() }

foreach ($plugin in $integratedPlugins) {
    $pluginPath = "$pluginsDir\$plugin"

    # init.rb → init.rb.bak
    $initPath = "$pluginPath\init.rb"
    if (Test-Path $initPath) {
        Rename-Item -Path $initPath -NewName "init.rb.bak" -Force
        Write-Host "Disabled init.rb: $plugin"
    }

    # lib → lib.bak（オートロード防止）
    $libPath = "$pluginPath\lib"
    if (Test-Path $libPath) {
        Rename-Item -Path $libPath -NewName "lib.bak" -Force
        Write-Host "Disabled lib: $plugin"
    }
}
```

### テスト後: 有効化

```powershell
$pluginsDir = "{RedmineRoot}\plugins"  # 実行環境から注入
$configPath = "$pluginsDir\redmine_studio_plugin\config\integrated_plugins.yml"
$configContent = Get-Content $configPath -Raw
$integratedPlugins = [regex]::Matches($configContent, '^\s+-\s+(.+)$', 'Multiline') | ForEach-Object { $_.Groups[1].Value.Trim() }

foreach ($plugin in $integratedPlugins) {
    $pluginPath = "$pluginsDir\$plugin"

    # init.rb.bak → init.rb
    $initBakPath = "$pluginPath\init.rb.bak"
    if (Test-Path $initBakPath) {
        Rename-Item -Path $initBakPath -NewName "init.rb" -Force
        Write-Host "Enabled init.rb: $plugin"
    }

    # lib.bak → lib
    $libBakPath = "$pluginPath\lib.bak"
    if (Test-Path $libBakPath) {
        Rename-Item -Path $libBakPath -NewName "lib" -Force
        Write-Host "Enabled lib: $plugin"
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
- `info_api のテストを実行してください`
- `reply_button のテストを実行してください`
- `teams_button のテストを実行してください`
- `auto_close のテストを実行してください`
- `date_independent のテストを実行してください`
- `wiki_lists のテストを実行してください`
- `subtask_list_accordion のテストを実行してください`
- `studio_settings_api のテストを実行してください`
- `journals_list のテストを実行してください`
- `reply_count のテストを実行してください`
- `children_count のテストを実行してください`
- `wiki_preview_api のテストを実行してください`
- `cache_bundle のテストを実行してください`
- `oauth_client_api のテストを実行してください`
- `roadmap_display のテストを実行してください`
