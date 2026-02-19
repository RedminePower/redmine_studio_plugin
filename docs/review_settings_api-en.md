# Review Settings API

API to manage review settings for Redmine Studio.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /review_settings.json` | Get settings list |
| `GET /review_settings/:id.json` | Get setting details |
| `POST /review_settings.json` | Create setting |
| `PUT /review_settings/:id.json` | Update setting |
| `DELETE /review_settings/:id.json` | Delete setting |
| `GET /review_settings/:id/users.json` | Get user assignments |
| `PUT /review_settings/:id/users.json` | Replace user assignments |
| `POST /review_settings/:id/users/:user_id.json` | Add user assignment |
| `DELETE /review_settings/:id/users/:user_id.json` | Remove user assignment |
| `GET /users/:id/review_settings.json` | Get user's settings |

## Authentication

All endpoints require API key authentication.

```
GET /review_settings.json?key=YOUR_API_KEY
```

---

## Review Settings

### GET /review_settings

Get a list of settings.

Query parameters:

| Parameter | Description |
|-----------|-------------|
| `scope_type` | Filter by scope type |
| `scope_id` | Filter by scope ID |
| `include_deleted` | Set to `1` to include soft-deleted settings |
| `include` | Set to `payload` to include the payload field |

Response:

```json
[
  { "id": 1, "name": "Setting 1", "scope_type": "global", "scope_id": null, "schema_version": 0, "created_on": "2026-02-19T...", "created_by_id": 1, "updated_on": "2026-02-19T...", "updated_by_id": 1, "deleted_on": null, "deleted_by_id": null },
  { "id": 2, "name": "Setting 2", "scope_type": "project", "scope_id": 1, "schema_version": 1, "created_on": "2026-02-19T...", "created_by_id": 1, "updated_on": "2026-02-19T...", "updated_by_id": 1, "deleted_on": null, "deleted_by_id": null }
]
```

---

### GET /review_settings/:id

Get setting details. Always includes payload.

Response:

```json
{
  "id": 1,
  "name": "Setting 1",
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

Create a setting.

Request:

```json
{
  "review_setting": {
    "name": "New Setting",
    "scope_type": "global",
    "schema_version": 0,
    "payload": "{\"key\":\"value\"}"
  }
}
```

Response (201 Created):

```json
{
  "id": 1,
  "name": "New Setting",
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

Update a setting.

Request:

```json
{
  "review_setting": {
    "name": "Updated Setting Name",
    "payload": "{\"updated\":true}"
  }
}
```

Response:

```json
{
  "id": 1,
  "name": "Updated Setting Name",
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

Delete a setting.

Query parameters:

| Parameter | Description |
|-----------|-------------|
| `force` | Set to `1` for hard delete (default is soft delete) |

Response: 204 No Content

---

## User Assignments

### GET /review_settings/:id/users

Get a list of users assigned to the setting.

Response:

```json
[
  { "id": 101, "setting_id": 10, "user_id": 1, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 },
  { "id": 102, "setting_id": 10, "user_id": 2, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 },
  { "id": 103, "setting_id": 10, "user_id": 3, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 }
]
```

---

### PUT /review_settings/:id/users

Replace user assignments (deletes all existing assignments and creates new ones).

Request:

```json
[1, 2, 3]
```

Response:

```json
[
  { "id": 101, "setting_id": 10, "user_id": 1, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 },
  { "id": 102, "setting_id": 10, "user_id": 2, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 },
  { "id": 103, "setting_id": 10, "user_id": 3, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 }
]
```

---

### POST /review_settings/:id/users/:user_id

Add a user to the assignment. Returns existing assignment if already exists.

Response (201 Created):

```json
{ "id": 104, "setting_id": 10, "user_id": 4, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 }
```

---

### DELETE /review_settings/:id/users/:user_id

Remove a user from the assignment.

Response: 204 No Content

---

## User's Settings

### GET /users/:id/review_settings

Get a list of settings assigned to the specified user. Soft-deleted settings are excluded.

Response:

```json
[
  { "id": 101, "setting_id": 10, "user_id": 1, "assigned_on": "2026-02-19T...", "assigned_by_id": 5 },
  { "id": 105, "setting_id": 15, "user_id": 1, "assigned_on": "2026-02-19T...", "assigned_by_id": 3 }
]
```

---

## Error Responses

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
