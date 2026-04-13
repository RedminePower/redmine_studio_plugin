# Activity Info API

API to retrieve Redmine activity history. Returns issue state (status, assignee) restored to the point in time of each activity.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /activity_infos.json` | Retrieve activity history |

## Authentication

API key authentication is required.

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `user_id` | int | Yes | Target user ID |
| `from` | date | Yes | Start date (YYYY-MM-DD) |
| `to` | date | Yes | End date (YYYY-MM-DD, inclusive) |

## Response Format

The API supports both JSON and XML.

| Extension | Content-Type |
|-----------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

Example:
```
GET /activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-10   → JSON format
GET /activity_infos.xml?user_id=1&from=2026-04-07&to=2026-04-10    → XML format
```

---

## Retrieve Activity History

### GET /activity_infos

Retrieves the activity history for the specified user. The issue state for each activity is restored to the values at the time of the activity.

Response:

```json
{
  "activity_infos": [
    {
      "activity_datetime": "2026-04-07T01:50:00Z",
      "description": "",
      "issue_id": 786,
      "journal_id": 673,
      "issue": {
        "id": 786,
        "subject": "Review request: User management feature",
        "tracker": { "id": 5, "name": "Review Request" },
        "status": { "id": 1, "name": "New" },
        "priority": { "id": 2, "name": "Normal" },
        "author": { "id": 1, "name": "Redmine Admin" },
        "project": { "id": 15, "name": "Review Test Project" },
        "parent": { "id": 785 },
        "description": "",
        "start_date": null,
        "due_date": null,
        "done_ratio": 0,
        "created_on": "2026-04-07T00:05:00Z",
        "updated_on": "2026-04-07T01:50:00Z"
      },
      "journal": {
        "id": 673,
        "user": { "id": 1, "name": "Redmine Admin" },
        "notes": "",
        "created_on": "2026-04-07T01:50:00Z",
        "private_notes": false,
        "details": [
          {
            "property": "attr",
            "name": "status_id",
            "old_value": "1",
            "new_value": "5"
          }
        ]
      },
      "ticket_tree": [
        {
          "id": 790,
          "subject": "User management feature implementation",
          "tracker": { "id": 2, "name": "Feature" },
          "status": { "id": 1, "name": "New" },
          "..."
        },
        {
          "id": 785,
          "subject": "Design review: User management feature",
          "..."
        },
        {
          "id": 786,
          "subject": "Review request: User management feature",
          "..."
        }
      ]
    }
  ]
}
```

---

## Response Fields

### activity_info

| Field | Type | Description |
|-------|------|-------------|
| `activity_datetime` | datetime | Activity timestamp |
| `description` | string | Activity description (Journal → notes, Issue creation → description) |
| `issue_id` | int | Issue ID |
| `journal_id` | int/null | Journal ID (null for issue creation events) |
| `issue` | object | Issue information restored to the activity timestamp |
| `journal` | object/omitted | Journal details (omitted for issue creation events) |
| `ticket_tree` | array | Parent issue hierarchy (root to leaf, each issue restored to the activity timestamp) |

### issue

| Field | Type | Description |
|-------|------|-------------|
| `id` | int | Issue ID |
| `subject` | string | Subject |
| `tracker` | object | Tracker { id, name } |
| `status` | object | Status { id, name } (restored to the activity timestamp) |
| `priority` | object | Priority { id, name } |
| `author` | object | Author { id, name } |
| `assigned_to` | object/omitted | Assignee { id, name } (restored to the activity timestamp, omitted when null) |
| `project` | object | Project { id, name } |
| `parent` | object/omitted | Parent issue { id } (omitted when null) |
| `description` | string | Issue description |
| `start_date` | date/null | Start date |
| `due_date` | date/null | Due date |
| `done_ratio` | int | Done ratio |
| `created_on` | datetime | Created on |
| `updated_on` | datetime | Updated on |

### journal

| Field | Type | Description |
|-------|------|-------------|
| `id` | int | Journal ID |
| `user` | object | User { id, name } |
| `notes` | string | Comment text |
| `created_on` | datetime | Created on |
| `private_notes` | bool | Whether private notes |
| `details` | array | Array of change details |

### detail

| Field | Type | Description |
|-------|------|-------------|
| `property` | string | Property type (e.g. "attr") |
| `name` | string | Field name (e.g. "status_id", "assigned_to_id") |
| `old_value` | string/null | Value before change |
| `new_value` | string/null | Value after change |

---

## Error Responses

| Status | Condition |
|--------|-----------|
| 401 | API key not provided (in environments requiring authentication) |
| 404 | Specified user_id does not exist |
| 422 | Required parameter (user_id, from, to) is missing |

### 422 Error Example

```json
{
  "errors": ["user_id is required"]
}
```
