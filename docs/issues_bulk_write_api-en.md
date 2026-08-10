# Issues Bulk Write API

An API for creating/updating multiple issues in a single request.

Redmine's standard `POST /issues.json` has two limitations that cause N× overhead for clients handling many issues (e.g., Redmine Studio's "Bulk Add" in the Ticket Editor). This API solves both.

**Limitation 1**: One issue per request  
**Limitation 2**: `notes` in the create request are silently ignored (init_journal is not called)

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `POST /issues/bulk_write.json` | Create/update multiple issues (JSON response) |
| `POST /issues/bulk_write.xml` | Same (XML response) |

## Permissions

Per-operation permissions follow Redmine standards:
- **create**: `User.current.allowed_to?(:add_issues, project, global: true)`
- **update**: `edit_issues`-equivalent on the target issue's project

Operations that lack permission fail individually without affecting others (Partial success).

## Request Format

### JSON

```json
{
  "operations": [
    {
      "op": "create",
      "issue": {
        "project_id": 1,
        "tracker_id": 2,
        "subject": "New ticket",
        "description": "Details",
        "assigned_to_id": 5,
        "custom_field_values": { "3": "value1" },
        "notes": "Initial comment (optional)"
      }
    },
    {
      "op": "update",
      "id": 123,
      "issue": {
        "subject": "Updated title",
        "notes": "Update comment"
      }
    }
  ]
}
```

### XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<operations type="array">
  <operation>
    <op>create</op>
    <issue>
      <project_id>1</project_id>
      <subject>New ticket</subject>
    </issue>
  </operation>
</operations>
```

**Note**: Rails' XML parser uses the root element name as the top-level params key. Use `<operations>` as the root directly (no `<params>` wrapper needed).

## Request Parameters

### Common: `operations` array

Each element has:

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `op` | string | Yes | `"create"` or `"update"` |
| `id` | int | Yes for update | Target Issue id |
| `issue` | object | Yes | Issue attributes hash |

### `issue` object

Accepts the same attributes as standard `POST /issues.json` / `PUT /issues/:id.json`. Additionally, `notes` is supported **on both create and update** (Redmine standard only supports notes on update).

| Attribute | Description |
|-----------|-------------|
| `project_id` | int or identifier string. Required for create |
| `tracker_id` | int. Defaults to the first of allowed_target_trackers |
| `status_id` | int. Defaults to the default status |
| `subject`, `description`, `priority_id`, `assigned_to_id`, `category_id`, `fixed_version_id`, `parent_issue_id`, `start_date`, `due_date`, `done_ratio`, `estimated_hours`, `is_private` | Standard Issue attributes |
| `custom_field_values` | Hash `{ "<cf_id>": "value" }` |
| `notes` | string. Recorded as a journal entry (comment) for both create and update |
| `assigned_to_id: "me"` | Special: automatically replaced with the authenticated user's id |
| `<attr>: "none"` (update only) | Reset to blank via Redmine's standard `replace_none_values_with_blank` |

## Response Format

### JSON

```json
{
  "results": [
    {
      "index": 0,
      "op": "create",
      "success": true,
      "issue": {
        "id": 100,
        "project": { "id": 1, "name": "..." },
        "tracker": { "id": 2, "name": "..." },
        "status": { "id": 1, "name": "...", "is_closed": false },
        "priority": { "id": 4, "name": "..." },
        "author": { "id": 5, "name": "..." },
        "assigned_to": { "id": 5, "name": "..." },
        "subject": "...",
        "description": "...",
        "start_date": "2026-07-23",
        "due_date": null,
        "done_ratio": 0,
        "is_private": false,
        "estimated_hours": null,
        "total_estimated_hours": null,
        "spent_hours": 0.0,
        "total_spent_hours": 0.0,
        "custom_fields": [ { "id": 3, "name": "...", "value": "value1" } ],
        "created_on": "2026-07-23T10:00:00Z",
        "updated_on": "2026-07-23T10:00:00Z",
        "closed_on": null
      }
    },
    {
      "index": 1,
      "op": "update",
      "success": true,
      "issue": {
        "id": 123,
        "subject": "Updated title",
        "updated_on": "2026-07-23T10:00:01Z"
      }
    },
    {
      "index": 2,
      "op": "create",
      "success": false,
      "errors": ["Subject cannot be blank"]
    }
  ]
}
```

**Note**: On update success, the full updated Issue is returned in the same structure as create success. Standard Redmine's `PUT /issues/:id.json` returns 204 No Content, so this is an intentional divergence to save the client from re-fetching the updated state.

### Response Properties

| Property | Type | Description |
|----------|------|-------------|
| `index` | int | Position in the request's operations array |
| `op` | string | `"create"` or `"update"` |
| `success` | bool | True on success, false on failure |
| `issue` | object | Present on success only. The created/updated issue (same fields as `GET /issues/:id.json`). Also returned on update success in the same structure |
| `errors` | string[] | Present on failure only. Array of error messages |

## Transaction Boundary

**Partial success**: Each operation runs in its own transaction. When one fails, the others are still committed.

Same behavior as Redmine's standard `bulk_update`. If all-or-nothing is required, the client must detect failed operations and implement rollback logic.

## Errors

### Request-level errors (422)

The following reject the entire request. Returns status 422 with `{ "errors": ["<msg>"] }`.

| Condition | Message |
|-----------|---------|
| `operations` is not an array | `operations must be an array` |
| `operations` is empty | `operations must not be empty` |

### Authentication errors (401)

- Missing / invalid `X-Redmine-API-Key` or Basic auth returns the standard Redmine 401 (via `before_action :require_login`).

### Per-operation errors (in response `errors`)

| Condition | Example message |
|-----------|-----------------|
| Unknown `op` | `unknown op: "delete"` |
| create: missing/invalid `project_id` | `project not found or not visible` |
| create: no `add_issues` permission | `forbidden: add_issues permission required` |
| create: no allowed tracker | `no tracker allowed for new issue in project` |
| create: no default status | `no default issue status` |
| update: missing `id` | `id is required for update` |
| update: Issue not found / not visible | `issue 12345 not found or not visible` |
| update: no `edit_issues` permission | `forbidden: edit_issues permission required for issue 12345` |
| update: stale object (concurrent edit) | `stale object: issue 12345 was modified by another user` |
| Validation error | Issue's `errors.full_messages` (e.g., `Subject cannot be blank`) |

## Performance

Measured: **~0.8 seconds** to create 14 issues via bulk_write (vs ~90 seconds with sequential API calls).

## Client Usage (redmine-net-api)

Redmine Studio calls this via `RedmineManager.BulkWrite(operations)`. See the redmine-net-api documentation for details.
