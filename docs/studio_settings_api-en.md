# Studio Settings API

API to manage general settings for Redmine Studio.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /studio_settings.json` | Get settings list |
| `GET /studio_settings/:id.json` | Get setting details |
| `POST /studio_settings.json` | Create setting |
| `POST /studio_settings/versions.json` | Get versions only, in bulk |
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

## Access Control (Visibility)

Visibility is determined by `scope_type`. Login is required for all endpoints. `scope_type` must be one of `global`, `project`, or `user` (any other value returns 422; the match is case-sensitive).

| scope_type | Users who can read | Users who can write (update/delete/assignments/history operations) |
|-----------|--------------------|--------------------------------------------------------------------|
| `global` | All logged-in users | All logged-in users |
| `project` | Members of that project | Members of that project |
| `user` | Users who can see the owner (including the owner) | The owner (the user in `scope_id`) |
| (admin) | All settings (any scope) | All settings (any scope) |

- `GET /studio_settings` (list) returns only visible settings (`project`-scoped settings are excluded for non-members). `user`-scoped settings are visible only to users who can see the owner (following the "Users visibility" of Redmine roles); settings of owners the requester cannot see are not listed (and showing one returns 403). Users who can see the owner can read them in bulk through the list. Settings of locked or not-yet-activated owners can be read only by admins (Redmine shows only active users). Do not put values in a `user`-scoped payload that others must not see (passwords, tokens, etc.).
- Accessing an individual setting, its history, or its user assignments (show/create/update/delete/restore) that the user cannot read or write returns **403 Forbidden**.
- A `project`-scoped setting can only be created by a member of that project (or an admin). Only an admin can change the scope of a setting on update (`scope_type`, and `scope_id` for a `project`-scoped setting); others get 403, because the contents of earlier versions would become visible to the new scope. To change the scope, create the setting again in the new scope. `scope_id` must be the ID of an existing project (a missing or unknown ID returns 422 for an admin and 403 for others). `global` settings can be created by any logged-in user. For the `user` scope, see "Personal settings (user scope)" below.
- `GET /users/:id/studio_settings` is allowed only when `:id` is the requester themselves or an admin (otherwise 403).
- Only active users that the assigner can see (following the "Users visibility" of Redmine roles) can be assigned; groups, the anonymous user, locked users and registered (not yet activated) users cannot. An admin can assign any active user. A user the assigner cannot see is refused with the same 422 as a user that does not exist. A `project`-scoped setting can only be assigned to members of that project (otherwise 422; admins can open any setting, so they can be assigned even if they are not members).
- In assignment responses and lists (`GET /studio_settings/:id/users`, `include=assignments`, `GET /users/:id/studio_settings`, etc.), the `user` of a user the viewer cannot see contains only `id`; `name` is omitted.

### Personal settings (user scope)

A setting each user owns one of per `schema_type`. `scope_id` is the owner's user ID.

| Operation | Behavior |
|-----------|----------|
| Create | If `scope_id` is omitted, the setting belongs to the requester. Only an admin can create one for another user (otherwise 403). The owner must be an existing user (otherwise 422). If a setting with the same owner and `schema_type` already exists, nothing is created and **409 Conflict** returns the existing setting |
| Update | `expected_version` is required (see "Version" below). `scope_type` cannot be changed to or from `user` (422). `scope_id` and `schema_type` are ignored if sent (but a value of the wrong shape returns 422) |
| Delete | Always a hard delete (regardless of `force`). The same `schema_type` can be created again afterwards |
| History | Not recorded (the history list is always empty) |
| User assignments | Not assignable. Replace/add return 422 |
| Owner deletion | When the user is deleted in Redmine, that user's personal settings are hard-deleted too |

### Version

Every setting has a `version`. It is 1 on creation and increases by 1 on every successful write (update, soft delete, restore), even when the content does not change. It is a different value from a history entry's `version` (the history sequence number).

If `PUT /studio_settings/:id` includes `expected_version` inside `studio_setting`, it is compared with the current `version`; if they differ, nothing is written and **409 Conflict** returns the current setting. `expected_version` is required for the `user` scope and optional for the other scopes (when omitted, the write happens without the check).

---

## Settings

### GET /studio_settings

Get a list of settings.

Query parameters:

| Parameter | Description |
|-----------|-------------|
| `ids` | Filter by IDs (comma-separated, e.g. `ids=1,2,3`) |
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
      "version": 1,
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
    "version": 1,
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
    "version": 1,
    "payload": "{\"key\":\"value\"}",
    "created_on": "2026-02-19T...",
    "created_by": { "id": 1, "name": "Admin" },
    "updated_on": "2026-02-19T...",
    "updated_by": { "id": 1, "name": "Admin" },
    "deleted_on": null
  }
}
```

For the `user` scope, if a setting with the same owner and `schema_type` already exists, 409 Conflict is returned. The body is the existing setting (same shape as `GET /studio_settings/:id`, including payload).

---

### PUT /studio_settings/:id

Update a setting.

Request:

```json
{
  "studio_setting": {
    "name": "Updated Setting Name",
    "payload": "{\"updated\":true}",
    "expected_version": 3
  }
}
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `expected_version` | Yes for the `user` scope | The `version` last read. Put it inside `studio_setting` (a value outside it is ignored). A non-integer value returns 422 |

- Only an admin can change the scope (`scope_type`, and `scope_id` for a `project`-scoped setting); others get 403. Sending the current values does not count as a change (a client may send back the whole setting it read)
- If `expected_version` differs from the current `version`, 409 Conflict is returned. The body is the current setting (same shape as `GET /studio_settings/:id`, including payload). The client should reapply its change on top of that content and resend with that `version`
- The 409 body has a different shape from other errors (`{ "errors": [...] }`). If an intermediate server (such as a proxy) replaces the body with something unreadable, read the setting again with `GET /studio_settings/:id`

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
    "version": 4,
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

`user`-scoped settings are always hard-deleted, regardless of `force`.

Settings are also hard-deleted (including soft-deleted ones) without calling this API in the following cases:

- When a user is deleted in Redmine: that user's `user`-scoped settings
- When a project is deleted in Redmine: that project's `project`-scoped settings (including those of subprojects deleted along with it)

Response: 204 No Content

---

### POST /studio_settings/versions

Returns only the `version` of the requester's own personal settings (`own`) and of the settings specified by ID (`ids`), in one call. No payload is returned. Use it to re-read only the changed settings with `GET /studio_settings/:id`.

Request:

```json
{
  "own": ["work_settings"],
  "ids": [12, 34]
}
```

| Parameter | Description |
|-----------|-------------|
| `own` | Array of `schema_type`. Returns the requester's own `user`-scoped settings that are not deleted |
| `ids` | Array of setting IDs (integers). Returns the settings that the requester can read and that are not deleted (any scope) |

- Send `own` and `ids` as arrays. Either one alone is fine. Empty arrays return 200 (an empty result)
- If neither `own` nor `ids` is present, either one is not an array, or `ids` contains a non-integer value, 422 is returned
- A requested item that is not returned can be read as "does not exist (deleted or not readable)"
- The request may be wrapped in `studio_setting_versions` (`{ "studio_setting_versions": { "own": [...], "ids": [...] } }`). XML needs a single outermost element, so wrap it, and add `type="array"` to the arrays (422 without it)

```xml
<studio_setting_versions>
  <own type="array"><schema_type>work_settings</schema_type></own>
  <ids type="array"><id>12</id><id>34</id></ids>
</studio_setting_versions>
```

Response:

```json
{
  "studio_setting_versions": {
    "own": [
      { "id": 5, "schema_type": "work_settings", "version": 3 }
    ],
    "team": [
      { "id": 12, "version": 7 }
    ]
  }
}
```

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

Replace user assignments (deletes the assignments of users not in `user_ids` and creates assignments for new users). Users in `user_ids` who are already assigned are kept as they are, without checking again whether they can be assigned, so the current list (including users who have since been locked, for example) can be sent back as is. The `id`, `assigned_on` and `assigned_by` of kept assignments do not change. If any new user cannot be assigned, nothing changes and 422 is returned (only the reason for the first refused user is returned). `user`-scoped settings cannot be assigned (422).

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

Add a user to the assignment. Returns existing assignment if already exists. A user who cannot be assigned (not visible, not existing, not active, or not a member for a `project`-scoped setting) returns 422. `user`-scoped settings cannot be assigned (422).

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

Get a list of settings assigned to the specified user. Soft-deleted settings and settings the user cannot read (for example, after leaving the project or after the setting's scope changed) are excluded.

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

Manage setting change history. History is automatically created when a setting is created, updated, or deleted (`user`-scoped settings do not record history). A history entry's `version` is the history sequence number, a different value from the setting's `version`.

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
    "version": 5,
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

### 403 Forbidden

Returned when accessing a setting in a scope the user is not allowed to access. A 403 is returned when:

- A non-member of the project accesses (show/create/update/delete/restore/user-assignment) a `project`-scoped setting
- A non-admin tries to change the scope of a setting on update (changing `scope_type`, or moving a `project`-scoped setting to another project)
- Someone other than the owner who is not an admin updates/deletes/restores/assigns users to a `user`-scoped setting, or tries to create one for another user
- `GET /users/:id/studio_settings` is requested by someone other than the user themselves and who is not an admin

### 404 Not Found

Returns standard HTTP 404 status (no response body).

Returns 404 in the following cases:
- Specified setting does not exist
- Specified user does not exist
- Specified assignment does not exist
- Specified history version does not exist

### 409 Conflict

The body is not `{ "errors": [...] }` but the current setting (same shape as `GET /studio_settings/:id`, including payload). Returned when:

- `POST /studio_settings` and a `user`-scoped setting with the same owner and `schema_type` already exists
- `PUT /studio_settings/:id` and `expected_version` differs from the current `version`

### 422 Unprocessable Entity

```json
{ "errors": ["Name cannot be blank", "Schema type cannot be blank", "Scope type cannot be blank"] }
```

```json
{ "errors": ["User does not exist: 99999"] }
```

```json
{ "errors": ["user_ids must be an array"] }
```

Related to the shape and length of the sent values (create, update, delete, restore). All shape errors are listed together. Length and the existence of the project or user are checked once the shape is correct:

| Message | When |
|---------|------|
| `studio_setting is required` | `studio_setting` is missing or empty on create or update |
| `studio_setting must be an object` | `studio_setting` is not an object (a JSON object, or an XML element with child elements), e.g. a string or an array |
| `name must be a string` (same for `schema_type`, `scope_type`, `payload`) | The field is not a string. Send `payload` as a JSON string (an object is not accepted) |
| `scope_id must be an integer` (same for `schema_version`) | The field cannot be read as an integer, or is outside -2147483648 to 2147483647 |
| `version must be an integer` | `version` is missing or cannot be read as an integer on restore |
| `comment must be a string` | `comment` is not a string (also checked on deletes that do not use it: `force=1` and the `user` scope) |
| `comment is too long (maximum is 255 characters)` | `comment` is longer than 255 characters |
| `Name is too long (maximum is 255 characters)` (same for `Schema type`) | `name` or `schema_type` is longer than 255 characters |
| `Scope cannot be blank` | `scope_id` is missing when creating a `project`-scoped setting or when an admin moves one (on create, non-admins get 403) |
| `Scope must be an existing project` | The project of `scope_id` does not exist when creating a `project`-scoped setting or when an admin moves one (on create, non-admins get 403) |
| `Scope must be an existing user` | The user of `scope_id` does not exist for a `user`-scoped setting (groups and the anonymous user are not allowed) |

Messages from model validation (those starting with a field name, such as `Name is too long …`) are returned in the user's language (e.g. in Japanese: 「名称 は255文字以内で入力してください」). The other messages are always in English.

Related to user assignments (`User …` messages come from model validation, so they are returned in the user's language; e.g. in Japanese: 「ユーザー には実在するユーザーを指定してください: 5」):

| Message | When |
|---------|------|
| `user_ids must be an array` | `user_ids` is not an array when replacing |
| `User does not exist: <ID>` | The user to assign does not exist, cannot be seen by the assigner, or is not active (groups, the anonymous user, locked users, registered users) |
| `User is not a member of the project: <ID>` | Assigning a `project`-scoped setting to someone who is not a member of that project |
| `User has already been taken` | The same user is sent twice when replacing |

Related to personal settings and versions:

| Message | When |
|---------|------|
| `expected_version is required` | Updating a `user`-scoped setting without `expected_version` |
| `expected_version must be an integer` | `expected_version` cannot be read as an integer |
| `scope_type cannot be changed to or from user` | Changing `scope_type` to or from `user` |
| `A user setting cannot be assigned to users` | Assigning users to a `user`-scoped setting |
| `own or ids is required` | `POST /studio_settings/versions` without `own` or `ids` |
| `own must be an array of schema_type` | `own` is not an array of strings |
| `ids must be an array of integers` | `ids` is not an array of integers |
