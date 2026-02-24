# Studio Settings API

API to manage general settings for Redmine Studio.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /studio_settings.json` | Get settings list |
| `GET /studio_settings/:id.json` | Get setting details |
| `POST /studio_settings.json` | Create setting |
| `PUT /studio_settings/:id.json` | Update setting |
| `DELETE /studio_settings/:id.json` | Delete setting |
| `GET /studio_settings/:id/users.json` | Get user assignments |
| `PUT /studio_settings/:id/users.json` | Replace user assignments |
| `POST /studio_settings/:id/users/:user_id.json` | Add user assignment |
| `DELETE /studio_settings/:id/users/:user_id.json` | Remove user assignment |
| `GET /users/:id/studio_settings.json` | Get user's settings |

## Authentication

All endpoints require API key authentication.

```
GET /studio_settings.json?key=YOUR_API_KEY
```

---

## Settings

### GET /studio_settings

Get a list of settings.

Query parameters:

| Parameter | Description |
|-----------|-------------|
| `schema_type` | Filter by schema type |
| `scope_type` | Filter by scope type |
| `scope_id` | Filter by scope ID |
| `include_deleted` | Set to `1` to include soft-deleted settings |
| `include` | Set to `payload` to include payload field, `assignments` to include assignments (comma-separated for multiple) |
| `offset` | Starting position |
| `limit` | Number of items (default: 25, max: 100) |

Response:

```json
{
  "studio_settings": [
    {
      "id": 1,
      "name": "Setting 1",
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

Get setting details. Always includes payload.

Query parameters:

| Parameter | Description |
|-----------|-------------|
| `include` | Set to `assignments` to include assignments |

Response:

```json
{
  "studio_setting": {
    "id": 1,
    "name": "Setting 1",
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

With `include=assignments`:

```json
{
  "studio_setting": {
    "id": 1,
    "name": "Setting 1",
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

Create a setting.

Request:

```json
{
  "studio_setting": {
    "name": "New Setting",
    "schema_type": "review",
    "scope_type": "global",
    "schema_version": 0,
    "payload": "{\"key\":\"value\"}"
  }
}
```

Response (201 Created):

```json
{
  "studio_setting": {
    "id": 1,
    "name": "New Setting",
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

Update a setting.

Request:

```json
{
  "studio_setting": {
    "name": "Updated Setting Name",
    "payload": "{\"updated\":true}"
  }
}
```

Response:

```json
{
  "studio_setting": {
    "id": 1,
    "name": "Updated Setting Name",
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

Delete a setting.

Query parameters:

| Parameter | Description |
|-----------|-------------|
| `force` | Set to `1` for hard delete (default is soft delete) |

Response: 204 No Content

---

## User Assignments

### GET /studio_settings/:id/users

Get a list of users assigned to the setting.

Query parameters:

| Parameter | Description |
|-----------|-------------|
| `offset` | Starting position |
| `limit` | Number of items (default: 25, max: 100) |

Response:

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

Replace user assignments (deletes all existing assignments and creates new ones).

Request:

```json
{
  "user_ids": [1, 2, 3]
}
```

Response:

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

Add a user to the assignment. Returns existing assignment if already exists.

Response (201 Created):

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

Remove a user from the assignment.

Response: 204 No Content

---

## User's Settings

### GET /users/:id/studio_settings

Get a list of settings assigned to the specified user. Soft-deleted settings are excluded.

Query parameters:

| Parameter | Description |
|-----------|-------------|
| `offset` | Starting position |
| `limit` | Number of items (default: 25, max: 100) |

Response:

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

## Error Responses

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
