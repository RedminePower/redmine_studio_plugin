# Studio Settings API

Redmine Studio の汎用設定を管理する API。

## エンドポイント一覧

| エンドポイント | 説明 |
|---------------|------|
| `GET /studio_settings.json` | 設定一覧の取得 |
| `GET /studio_settings/:id.json` | 設定詳細の取得 |
| `POST /studio_settings.json` | 設定の作成 |
| `PUT /studio_settings/:id.json` | 設定の更新 |
| `DELETE /studio_settings/:id.json` | 設定の削除 |
| `GET /studio_settings/:id/users.json` | ユーザー割り当て一覧 |
| `PUT /studio_settings/:id/users.json` | ユーザー割り当て置換 |
| `POST /studio_settings/:id/users/:user_id.json` | ユーザー割り当て追加 |
| `DELETE /studio_settings/:id/users/:user_id.json` | ユーザー割り当て削除 |
| `GET /users/:id/studio_settings.json` | ユーザーの設定一覧 |

## 認証

全てのエンドポイントで API キー認証が必要。

```
GET /studio_settings.json?key=YOUR_API_KEY
```

---

## 設定

### GET /studio_settings

設定の一覧を取得。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `schema_type` | スキーマタイプでフィルタ |
| `scope_type` | スコープタイプでフィルタ |
| `scope_id` | スコープ ID でフィルタ |
| `include_deleted` | `1` で論理削除された設定も含める |
| `include` | `payload` で payload フィールドを含める、`assignments` で割り当てを含める（カンマ区切りで複数指定可） |
| `offset` | 取得開始位置 |
| `limit` | 取得件数（デフォルト: 25、最大: 100） |

レスポンス:

```json
{
  "studio_settings": [
    {
      "id": 1,
      "name": "設定1",
      "schema_type": "review",
      "scope_type": "global",
      "scope_id": null,
      "schema_version": 0,
      "created_on": "2026-02-19T...",
      "created_by": { "id": 1, "name": "Admin" },
      "updated_on": "2026-02-19T...",
      "updated_by": { "id": 1, "name": "Admin" },
      "deleted_on": null,
      "deleted_by": null
    }
  ],
  "total_count": 1,
  "offset": 0,
  "limit": 25
}
```

---

### GET /studio_settings/:id

設定の詳細を取得。payload を常に含む。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `include` | `assignments` で割り当てを含める |

レスポンス:

```json
{
  "studio_setting": {
    "id": 1,
    "name": "設定1",
    "schema_type": "review",
    "scope_type": "global",
    "scope_id": null,
    "schema_version": 0,
    "payload": "{\"key\":\"value\"}",
    "created_on": "2026-02-19T...",
    "created_by": { "id": 1, "name": "Admin" },
    "updated_on": "2026-02-19T...",
    "updated_by": { "id": 1, "name": "Admin" },
    "deleted_on": null,
    "deleted_by": null
  }
}
```

`include=assignments` を指定した場合:

```json
{
  "studio_setting": {
    "id": 1,
    "name": "設定1",
    "payload": "{\"key\":\"value\"}",
    "assignments": [
      {
        "id": 1,
        "setting_id": 1,
        "user": { "id": 2, "name": "John Doe" },
        "assigned_on": "2026-02-19T...",
        "assigned_by": { "id": 1, "name": "Admin" }
      }
    ]
  }
}
```

---

### POST /studio_settings

設定を作成。

リクエスト:

```json
{
  "studio_setting": {
    "name": "新規設定",
    "schema_type": "review",
    "scope_type": "global",
    "schema_version": 0,
    "payload": "{\"key\":\"value\"}"
  }
}
```

レスポンス (201 Created):

```json
{
  "studio_setting": {
    "id": 1,
    "name": "新規設定",
    "schema_type": "review",
    "scope_type": "global",
    "scope_id": null,
    "schema_version": 0,
    "payload": "{\"key\":\"value\"}",
    "created_on": "2026-02-19T...",
    "created_by": { "id": 1, "name": "Admin" },
    "updated_on": "2026-02-19T...",
    "updated_by": { "id": 1, "name": "Admin" },
    "deleted_on": null,
    "deleted_by": null
  }
}
```

---

### PUT /studio_settings/:id

設定を更新。

リクエスト:

```json
{
  "studio_setting": {
    "name": "更新後の設定名",
    "payload": "{\"updated\":true}"
  }
}
```

レスポンス:

```json
{
  "studio_setting": {
    "id": 1,
    "name": "更新後の設定名",
    "schema_type": "review",
    "scope_type": "global",
    "scope_id": null,
    "schema_version": 0,
    "payload": "{\"updated\":true}",
    "created_on": "2026-02-19T...",
    "created_by": { "id": 1, "name": "Admin" },
    "updated_on": "2026-02-19T...",
    "updated_by": { "id": 1, "name": "Admin" },
    "deleted_on": null,
    "deleted_by": null
  }
}
```

---

### DELETE /studio_settings/:id

設定を削除。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `force` | `1` で物理削除（デフォルトは論理削除） |

レスポンス: 204 No Content

---

## ユーザー割り当て

### GET /studio_settings/:id/users

設定に割り当てられたユーザーの一覧を取得。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `offset` | 取得開始位置 |
| `limit` | 取得件数（デフォルト: 25、最大: 100） |

レスポンス:

```json
{
  "studio_setting_assignments": [
    {
      "id": 101,
      "setting_id": 10,
      "user": { "id": 1, "name": "Admin" },
      "assigned_on": "2026-02-19T...",
      "assigned_by": { "id": 5, "name": "Manager" }
    }
  ],
  "total_count": 1,
  "offset": 0,
  "limit": 25
}
```

---

### PUT /studio_settings/:id/users

ユーザー割り当てを置換（既存の割り当てを全て削除し、新しい割り当てを作成）。

リクエスト:

```json
{
  "user_ids": [1, 2, 3]
}
```

レスポンス:

```json
{
  "studio_setting_assignments": [
    {
      "id": 101,
      "setting_id": 10,
      "user": { "id": 1, "name": "Admin" },
      "assigned_on": "2026-02-19T...",
      "assigned_by": { "id": 5, "name": "Manager" }
    },
    {
      "id": 102,
      "setting_id": 10,
      "user": { "id": 2, "name": "User2" },
      "assigned_on": "2026-02-19T...",
      "assigned_by": { "id": 5, "name": "Manager" }
    }
  ]
}
```

---

### POST /studio_settings/:id/users/:user_id

ユーザーを割り当てに追加。既に存在する場合は既存の割り当てを返す。

レスポンス (201 Created):

```json
{
  "studio_setting_assignment": {
    "id": 104,
    "setting_id": 10,
    "user": { "id": 4, "name": "User4" },
    "assigned_on": "2026-02-19T...",
    "assigned_by": { "id": 5, "name": "Manager" }
  }
}
```

---

### DELETE /studio_settings/:id/users/:user_id

ユーザーの割り当てを削除。

レスポンス: 204 No Content

---

## ユーザーの設定一覧

### GET /users/:id/studio_settings

指定したユーザーに割り当てられた設定の一覧を取得。論理削除された設定は除外。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `offset` | 取得開始位置 |
| `limit` | 取得件数（デフォルト: 25、最大: 100） |

レスポンス:

```json
{
  "studio_setting_assignments": [
    {
      "id": 101,
      "setting_id": 10,
      "user": { "id": 1, "name": "Admin" },
      "assigned_on": "2026-02-19T...",
      "assigned_by": { "id": 5, "name": "Manager" }
    }
  ],
  "total_count": 1,
  "offset": 0,
  "limit": 25
}
```

---

## エラーレスポンス

### 404 Not Found

```json
{ "error": "Studio setting not found: id=99999" }
```

```json
{ "error": "User not found: id=99999" }
```

```json
{ "error": "Assignment not found: setting_id=10, user_id=99999" }
```

### 422 Unprocessable Entity

```json
{ "errors": ["Name can't be blank", "Schema type can't be blank", "Scope type can't be blank"] }
```

```json
{ "errors": ["User does not exist: 99999"] }
```

```json
{ "errors": ["user_ids must be an array"] }
```
