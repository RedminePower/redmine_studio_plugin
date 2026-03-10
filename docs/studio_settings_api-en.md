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
| `GET /studio_settings/:id/histories.json` | Get history list |
| `GET /studio_settings/:id/histories/:version.json` | Get history details |
| `DELETE /studio_settings/:id/histories/:version.json` | Delete history |
| `POST /studio_settings/:id/restore.json` | Restore from history |

## Authentication

All endpoints require API key authentication.

```
GET /studio_settings.json?key=YOUR_API_KEY
```

## Response Format

The API supports both JSON and XML.

| Extension | Content-Type |
|-----------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

Example:
```
GET /studio_settings.json   → Returns JSON format
GET /studio_settings.xml    → Returns XML format
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
      "deleted_on": null
    }
  ],
  "total_count": 1,
  "offset": 0,
  "limit": 25
}
```

**Note:** `created_by`, `updated_by`, and `deleted_by` are nullable nested objects. When nil, the property is omitted entirely.

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
    "deleted_on": null
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
    "deleted_on": null
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
    "deleted_on": null
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

## History

Manage setting change history. History is automatically created when a setting is created, updated, or deleted.

### change_type Values

| change_type | Description |
|-------------|-------------|
| `create` | New creation |
| `update` | Update |
| `delete` | Soft delete |
| `undelete` | Restore from soft delete |
| `restore` | Restore from history |

---

### GET /studio_settings/:id/histories

Get history list for a setting. Sorted by newest first (version DESC).

Query parameters:

| Parameter | Description |
|-----------|-------------|
| `include` | Set to `payload` to include payload field |
| `offset` | Starting position |
| `limit` | Number of items (default: 25, max: 100) |

Response:

```json
{
  "studio_setting_histories": [
    {
      "id": 3,
      "studio_setting_id": 1,
      "version": 3,
      "name": "Setting Name",
      "schema_type": "review",
      "scope_type": "global",
      "scope_id": null,
      "schema_version": 1,
      "change_type": "update",
      "restored_from_version": null,
      "comment": "Added items",
      "is_current": true,
      "changed_on": "2026-03-04T10:00:00Z",
      "changed_by": { "id": 1, "name": "Admin" }
    },
    {
      "id": 2,
      "studio_setting_id": 1,
      "version": 2,
      "name": "Setting Name",
      "schema_type": "review",
      "scope_type": "global",
      "scope_id": null,
      "schema_version": 0,
      "change_type": "update",
      "restored_from_version": null,
      "comment": null,
      "is_current": false,
      "changed_on": "2026-03-03T15:00:00Z",
      "changed_by": { "id": 1, "name": "Admin" }
    }
  ],
  "total_count": 3,
  "offset": 0,
  "limit": 25
}
```

When `include=payload` is specified, a `payload` field is added to each history entry.

---

### GET /studio_settings/:id/histories/:version

Get history details for the specified version. Always includes payload.

Response:

```json
{
  "studio_setting_history": {
    "id": 1,
    "studio_setting_id": 1,
    "version": 1,
    "name": "Setting Name",
    "schema_type": "review",
    "scope_type": "global",
    "scope_id": null,
    "schema_version": 0,
    "payload": "{\"key\":\"value\"}",
    "change_type": "create",
    "restored_from_version": null,
    "comment": "Initial creation",
    "is_current": false,
    "changed_on": "2026-03-01T10:00:00Z",
    "changed_by": { "id": 1, "name": "Admin" }
  }
}
```

---

### DELETE /studio_settings/:id/histories/:version

Delete the specified version of history (hard delete).

**Restriction:** Cannot delete history with `is_current = true` (current history).

Response: 204 No Content

Error response (when trying to delete current history):

```json
{ "errors": ["Cannot delete the current version"] }
```

---

### POST /studio_settings/:id/restore

Restore setting from the specified history version.

**What gets restored:**
- `payload` and `schema_version` are restored
- `name` retains its current value (not restored)

**change_type determination:**
- If setting is soft-deleted: `undelete`
- Otherwise: `restore`

Request:

```json
{
  "version": 1,
  "comment": "Restore to v1"
}
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `version` | Yes | Version number to restore from |
| `comment` | No | Change comment |

Response:

```json
{
  "studio_setting": {
    "id": 1,
    "name": "Setting Name",
    "schema_type": "review",
    "scope_type": "global",
    "scope_id": null,
    "schema_version": 0,
    "payload": "{\"key\":\"value\"}",
    "created_on": "2026-03-01T10:00:00Z",
    "created_by": { "id": 1, "name": "Admin" },
    "updated_on": "2026-03-04T12:00:00Z",
    "updated_by": { "id": 1, "name": "Admin" },
    "deleted_on": null
  }
}
```

Error response (when trying to restore to current version):

```json
{ "errors": ["Cannot restore to the current version"] }
```

---

## Error Responses

### 404 Not Found

Returns standard HTTP 404 status (no response body).

Returns 404 in the following cases:
- Specified setting does not exist
- Specified user does not exist
- Specified assignment does not exist
- Specified history version does not exist

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
