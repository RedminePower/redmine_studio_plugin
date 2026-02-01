# redmine_studio_plugin テスト

このプラグインのテストはそれぞれの項目の TEST_SPEC.md に基づいて Claude が実行します。

## テスト仕様ファイル

| ファイル | 説明 |
|---------|------|
| `setup_task/TEST_SPEC.md` | Setup タスクテスト |
| `conflict_detection/TEST_SPEC.md` | 競合プラグイン検出テスト |
| `features/plugin_api/TEST_SPEC.md` | プラグイン情報 API テスト |
| `features/reply_button/TEST_SPEC.md` | Reply Button テスト |

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

## テストの実行方法

Claude に以下のように依頼してください:

**全テスト実行:**
- `全てのテストを実行してください`
- `テストを実行してください`

**個別実行:**
- `setup_task のテストを実行してください`
- `conflict_detection のテストを実行してください`
- `plugin_api のテストを実行してください`
- `reply_button のテストを実行してください`
