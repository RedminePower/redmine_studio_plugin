# Plugin API

Redmine にインストールされているプラグインの情報を取得する API。

## エンドポイント一覧

| エンドポイント | 説明 |
|---------------|------|
| `GET /plugins.json` | プラグイン一覧の取得 |
| `GET /plugins/:id.json` | 単体プラグイン情報の取得 |

## 認証

全てのエンドポイントで API キー認証が必要。

```
GET /plugins.json?key=YOUR_API_KEY
```

---

## プラグイン一覧

### GET /plugins

プラグインの一覧を取得。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `include` | `settings` でプラグイン設定を含める |
| `offset` | 取得開始位置 |
| `limit` | 取得件数（デフォルト: 25、最大: 100） |

レスポンス:

```json
{
  "plugins": [
    {
      "id": "redmine_studio_plugin",
      "name": "Redmine Studio plugin",
      "description": "Provides features for Redmine Studio...",
      "version": "1.0.0",
      "author": "Redmine Power",
      "author_url": "https://www.redmine-power.com/",
      "url": "https://github.com/RedminePower/redmine_studio_plugin"
    }
  ],
  "total_count": 1,
  "offset": 0,
  "limit": 25
}
```

`include=settings` を指定した場合:

```json
{
  "plugins": [
    {
      "id": "redmine_studio_plugin",
      "name": "Redmine Studio plugin",
      "version": "1.0.0",
      "author": "Redmine Power",
      "settings": "{\"key\":\"value\"}"
    }
  ],
  "total_count": 1,
  "offset": 0,
  "limit": 25
}
```

※ 設定を持たないプラグインの場合、`settings` は `null` になる

---

## プラグイン詳細

### GET /plugins/:id

指定したプラグインの詳細を取得。`settings` を常に含む。

レスポンス:

```json
{
  "plugin": {
    "id": "redmine_studio_plugin",
    "name": "Redmine Studio plugin",
    "description": "Provides features for Redmine Studio...",
    "version": "1.0.0",
    "author": "Redmine Power",
    "author_url": "https://www.redmine-power.com/",
    "url": "https://github.com/RedminePower/redmine_studio_plugin",
    "settings": "{\"key\":\"value\"}"
  }
}
```

---

## エラーレスポンス

### 404 Not Found

```json
{ "error": "Plugin not found: id=non_existent_plugin" }
```
