# Info API

Redmine の環境情報を取得する API。「管理」＞「情報」画面で表示される情報を API で取得できる。

## エンドポイント一覧

| エンドポイント | 説明 |
|---------------|------|
| `GET /info.json` | Redmine 環境情報の取得 |

## 認証

認証不要。誰でもアクセス可能。

## レスポンス形式

API は JSON と XML の両方をサポートする。

| 拡張子 | Content-Type |
|--------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

例:
```
GET /info.json   → JSON 形式で返却
GET /info.xml    → XML 形式で返却
```

---

## 環境情報

### GET /info

Redmine の環境情報を取得。

レスポンス:

```json
{
  "info": {
    "redmine_version": "6.1.1.stable",
    "ruby_version": "3.4.8-p72 (2025-12-17) [x86_64-linux]",
    "rails_version": "7.2.3",
    "environment": "production",
    "database_adapter": "SQLite",
    "mailer_queue": "ActiveJob::QueueAdapters::AsyncAdapter",
    "mailer_delivery": "smtp",
    "redmine_theme": "Default",
    "text_formatting": "common_mark",
    "scm": [
      {
        "name": "Git",
        "version": "2.47.3"
      },
      {
        "name": "Subversion",
        "version": "1.14.5"
      }
    ],
    "plugins": [
      {
        "id": "redmine_studio_plugin",
        "version": "1.1.4"
      }
    ]
  }
}
```

---

## レスポンスフィールド

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `redmine_version` | string | Redmine のバージョン |
| `ruby_version` | string | Ruby のバージョン（プラットフォーム情報含む） |
| `rails_version` | string | Rails のバージョン |
| `environment` | string | 実行環境（production, development, test） |
| `database_adapter` | string | データベースアダプタ名（SQLite, MySQL, PostgreSQL など） |
| `mailer_queue` | string | メールキューアダプタのクラス名 |
| `mailer_delivery` | string | メール配信方法（smtp, sendmail など） |
| `redmine_theme` | string | UI テーマ（未設定時は "Default"） |
| `text_formatting` | string | テキスト書式（textile, common_mark など） |
| `scm` | array | インストール済み SCM の一覧 |
| `plugins` | array | インストール済みプラグインの一覧 |

### scm 配列

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `name` | string | SCM の名前（Git, Subversion, Mercurial, Bazaar） |
| `version` | string | SCM のバージョン |

※ バージョンが取得できた SCM のみ含まれる

### plugins 配列

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `id` | string | プラグイン ID |
| `version` | string | プラグインのバージョン |
