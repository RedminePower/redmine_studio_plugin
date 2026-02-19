# Review Settings API

Redmine Studio のレビュー設定を管理する API。

## エンドポイント一覧

| エンドポイント | 説明 |
|---------------|------|
| `GET /review_settings.json` | 設定一覧の取得 |
| `GET /review_settings/:id.json` | 設定詳細の取得 |
| `POST /review_settings.json` | 設定の作成 |
| `PUT /review_settings/:id.json` | 設定の更新 |
| `DELETE /review_settings/:id.json` | 設定の削除 |
| `GET /review_settings/:id/users.json` | ユーザー割り当て一覧 |
| `PUT /review_settings/:id/users.json` | ユーザー割り当て置換 |
| `POST /review_settings/:id/users/:user_id.json` | ユーザー割り当て追加 |
| `DELETE /review_settings/:id/users/:user_id.json` | ユーザー割り当て削除 |
| `GET /users/:id/review_settings.json` | ユーザーの設定一覧 |

## 認証

全てのエンドポイントで API キー認証が必要。

```
GET /review_settings.json?key=YOUR_API_KEY
```

---

## レビュー設定

### GET /review_settings

設定の一覧を取得。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `scope_type` | スコープタイプでフィルタ |
| `scope_id` | スコープ ID でフィルタ |
| `include_deleted` | `1` で論理削除された設定も含める |
| `include` | `payload` で payload フィールドを含める |

レスポンス:

```json
[
  { "id": 1, "name": "設定1", "scope_type": "global", "scope_id": null, "schema_version": 0, "created_on": "2026-02-19T...", "created_by_id": 1, "updated_on": "2026-02-19T...", "updated_by_id": 1, "deleted_on": null, "deleted_by_id": null },
  { "id": 2, "name": "設定2", "scope_type": "project", "scope_id": 1, "schema_version": 1, "created_on": "2026-02-19T...", "created_by_id": 1, "updated_on": "2026-02-19T...", "updated_by_id": 1, "deleted_on": null, "deleted_by_id": null }
]
```

---

### GET /review_settings/:id

設定の詳細を取得。payload を常に含む。

レスポンス:

```json
{
  "id": 1,
  "name": "設定1",
  "scope_type": "global",
  "scope_id": null,
  "schema_version": 0,
  "payload": "{\"key\":\"value\"}",
  "created_on": "2026-02-19T...",
  "created_by_id": 1,
  "updated_on": "2026-02-19T...",
  "updated_by_id": 1,
  "deleted_on": null,
  "deleted_by_id": null
}
```

---

### POST /review_settings

設定を作成。

リクエスト:

```json
{
  "review_setting": {
    "name": "新規設定",
    "scope_type": "global",
    "schema_version": 0,
    "payload": "{\"key\":\"value\"}"
  }
}
```

レスポンス (201 Created):

```json
{
  "id": 1,
  "name": "新規設定",
  "scope_type": "global",
  "scope_id": null,
  "schema_version": 0,
  "payload": "{\"key\":\"value\"}",
  "created_on": "2026-02-19T...",
  "created_by_id": 1,
  "updated_on": "2026-02-19T...",
  "updated_by_id": 1,
  "deleted_on": null,
  "deleted_by_id": null
}
```

---

### PUT /review_settings/:id

設定を更新。

リクエスト:

```json
{
  "review_setting": {
    "name": "更新後の設定名",
    "payload": "{\"updated\":true}"
  }
}
```

レスポンス:

```json
{
  "id": 1,
  "name": "更新後の設定名",
  "scope_type": "global",
  "scope_id": null,
  "schema_version": 0,
  "payload": "{\"updated\":true}",
  "created_on": "2026-02-19T...",
  "created_by_id": 1,
  "updated_on": "2026-02-19T...",
  "updated_by_id": 1,
  "deleted_on": null,
  "deleted_by_id": null
}
```

---

### DELETE /review_settings/:id

設定を削除。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `force` | `1` で物理削除（デフォルトは論理削除） |

レスポンス: 204 No Content

---

## ユーザー割り当て

### GET /review_settings/:id/users

設定に割り当てられたユーザーの一覧を取得。

レスポンス:

```json
[
  { "id": 101, "setting_id": 10, "user_id": 1, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 },
  { "id": 102, "setting_id": 10, "user_id": 2, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 },
  { "id": 103, "setting_id": 10, "user_id": 3, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 }
]
```

---

### PUT /review_settings/:id/users

ユーザー割り当てを置換（既存の割り当てを全て削除し、新しい割り当てを作成）。

リクエスト:

```json
[1, 2, 3]
```

レスポンス:

```json
[
  { "id": 101, "setting_id": 10, "user_id": 1, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 },
  { "id": 102, "setting_id": 10, "user_id": 2, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 },
  { "id": 103, "setting_id": 10, "user_id": 3, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 }
]
```

---

### POST /review_settings/:id/users/:user_id

ユーザーを割り当てに追加。既に存在する場合は既存の割り当てを返す。

レスポンス (201 Created):

```json
{ "id": 104, "setting_id": 10, "user_id": 4, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 }
```

---

### DELETE /review_settings/:id/users/:user_id

ユーザーの割り当てを削除。

レスポンス: 204 No Content

---

## ユーザーの設定一覧

### GET /users/:id/review_settings

指定したユーザーに割り当てられた設定の一覧を取得。論理削除された設定は除外。

レスポンス:

```json
[
  { "id": 101, "setting_id": 10, "user_id": 1, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 },
  { "id": 105, "setting_id": 15, "user_id": 1, "assigned_on": "2026-02-19T...", "assigned_by_id": 3 }
]
```

---

## エラーレスポンス

### 404 Not Found

```json
{ "error": "Review setting not found: id=99999" }
```

```json
{ "error": "User not found: id=99999" }
```

```json
{ "error": "Assignment not found: setting_id=10, user_id=99999" }
```

### 422 Unprocessable Entity

```json
{ "errors": ["Name can't be blank", "Scope type can't be blank"] }
```

```json
{ "errors": ["User does not exist: 99999"] }
```

```json
{ "errors": ["Request body must be an array of user IDs"] }
```
