# Activity Info API

API to retrieve Redmine activity history. Returns issue state (status, assignee) restored to the point in time of each activity.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /activity_infos.json` | Retrieve activity history |

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

## When Activities Cannot Be Built

If building a single activity raises an exception, only that activity is skipped and the rest are returned (200). Only when something was skipped, the list carries the following values (attributes of `<activity_infos>` in XML, keys at the same level as `activity_infos` in JSON).

| Field | Type | Description |
|-------|------|-------------|
| `skipped_count` | int | Number of skipped activities |
| `skipped_errors` | string | Descriptions of the skipped exceptions, "ClassName (file:line)", in order of occurrence, without duplicates, joined with `, ` |

The description does not include the exception message. The location is the first backtrace line inside the plugin (or the first line if there is none).

```json
{
  "activity_infos": [ ... ],
  "skipped_count": 1,
  "skipped_errors": "NoMethodError (activity_infos_controller.rb:212)"
}
```

```xml
<activity_infos type="array" skipped_count="1" skipped_errors="NoMethodError (activity_infos_controller.rb:212)">
  ...
</activity_infos>
```

In the following cases, 500 is returned. `errors` contains two entries in this order: a guidance message for the user (in the user's language) and the exception description.

- Fetching or bulk-loading the activities fails
- There is at least one activity and building all of them fails
- A database exception (`ActiveRecord::StatementInvalid`, `ActiveRecord::ConnectionNotEstablished` and their subclasses) or a timeout (`Timeout::Error`) occurs
- Rendering the response fails

In every case, the exception and its context (user_id, from, to, activity type and ID) are written to the Redmine log. The backtrace is written only for the first exception of each class per request.

---

## Error Responses

| Status | Condition |
|--------|-----------|
| 401 | Not authenticated (login required) |
| 404 | Specified user_id does not exist |
| 422 | Required parameter (user_id, from, to) is missing |
| 500 | Activities could not be built (see "When Activities Cannot Be Built" above) |

### 500 Error Example

```json
{
  "errors": [
    "Redmine could not build the activities. Please try again later, and if the problem persists, contact your Redmine administrator (the cause is recorded in the Redmine log).",
    "NoMethodError (activity_infos_controller.rb:212)"
  ]
}
```

```xml
<errors type="array">
  <error>Redmine could not build the activities. ...</error>
  <error>NoMethodError (activity_infos_controller.rb:212)</error>
</errors>
```

### 422 Error Example

```json
{
  "errors": ["user_id is required"]
}
```
