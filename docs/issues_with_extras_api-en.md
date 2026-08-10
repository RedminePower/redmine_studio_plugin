# Issues With Extras API

A dedicated endpoint that returns the same response as Redmine's standard issue read API (`GET /issues/:id` / `GET /issues`), plus the extra fields that Redmine Studio needs for display.

Redmine Studio's Ticket Editor shows "reply count", "children count", "last updated by", "last notes", and "spent hours by user" in the issue list. These cannot be obtained from the standard API (they exist only as HTML list columns, or require a per-issue fetch). This API returns them together so that a single list request provides everything needed for display, avoiding a per-issue extra fetch (N+1).

It uses a dedicated controller that inherits from the standard `IssuesController`, replacing only the view. **Redmine core's `issues/*.api.rsb` is never overridden**, so it coexists with other plugins and has zero impact on the standard `/issues` endpoint.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /issues_with_extras/:id.json` | Retrieve a single issue (JSON) |
| `GET /issues_with_extras/:id.xml` | Same (XML) |
| `GET /issues_with_extras.json` | Retrieve an issue list (JSON) |
| `GET /issues_with_extras.xml` | Same (XML) |

Query parameters such as filters, pagination, and `include=` behave identically to `/issues` because the controller inherits the standard `IssuesController`.

## Permissions

For authenticated users, permissions follow the standard `/issues` (`view_issues`; inherits `accept_api_auth :index, :show`). Authentication is required and anonymous requests are rejected with 401 (stricter than the standard `/issues`).

## Added Fields

The following 5 fields are added to the standard issue response.

| Field | Type | Source | Description |
|-------|------|--------|-------------|
| `reply_count` | object | Plugin (Reply Count feature) | Number of assignee changes and the transitions |
| `children_count` | object | Plugin (Children Count feature) | Number of direct child issues and the list |
| `last_updated_by` | object | Redmine standard column | Last updater |
| `last_notes` | string | Redmine standard column | Latest comment text |
| `spent_hours_by_user` | array | Plugin (Spent Hours By User feature) | Spent hours per assignee |

`last_updated_by` / `last_notes` reuse Redmine core's list columns as-is (`Issue#last_updated_by` / `Issue#last_notes`, with preloads `load_visible_last_updated_by` / `load_visible_last_notes`). They are not part of the standard API response, but the feature itself is standard Redmine and is not reimplemented in the plugin.

### `reply_count`

```json
"reply_count": {
  "count": 3,
  "items": [
    { "id": 2, "name": "Taro Tanaka" },
    { "id": 3, "name": "Hanako Sato" },
    { "id": 2, "name": "Taro Tanaka" },
    { "id": 0, "name": "" }
  ]
}
```

- `count`: number of times the assignee was changed
- `items`: assignee transitions (initial assignee → new assignee at each change; element count = `count` + 1). No assignee is `id: 0, name: ""`; a deleted/invalid user is `id: <original id>, name: ""`. An issue with no change history has `count: 0` and a single `items` entry for the current assignee
- Formatting (labeling, truncation) is the client's responsibility

### `children_count`

```json
"children_count": {
  "count": 12,
  "items": [
    { "id": 101, "name": "Child issue subject" }
  ]
}
```

- `count`: number of direct child issues (visible scope applied)
- `items`: array of children as `{ id, name = subject }`, up to the first 10 (even if `count` exceeds 10, `items` is capped at 10)

### `last_updated_by`

```json
"last_updated_by": { "id": 5, "name": "Taro Tanaka" }
```

- The most recent updater among visible journals (`{ id, name }`)
- **Omitted entirely** when there is no update history, or when the latest journal's author no longer exists (same handling as standard Redmine's nullable nested objects)

### `last_notes`

```json
"last_notes": "Latest comment text"
```

- The latest visible comment text
- An empty string `""` when there are no comments (always emitted, as it is a plain string)

### `spent_hours_by_user`

```json
"spent_hours_by_user": [
  { "user_id": 1, "hours": 8.0 },
  { "user_id": 5, "hours": 2.0 }
]
```

- Spent hours for the issue **and its descendants** (subtree), aggregated per user (assignee). Each element is `{ user_id, hours }`
- The aggregation scope is the same subtree as Redmine core's `total_spent_hours` (nested set: same `root_id`, `lft`/`rgt` containment). Therefore the sum of `hours` equals `total_spent_hours`
- Only visible time entries are included (`TimeEntry.visible`). Because of this self-guard, no extra `view_time_entries` permission gate is applied and the field is always emitted; a user without permission sees no time entries, so the array is empty
- An empty array `[]` when there are no time entries (always emitted)
- The app (Ticket Editor) looks up hours from this array whenever the assignee is switched, avoiding a per-issue spent-hours refetch (N+1)

## Response Example (JSON, show)

Includes all fields of the standard `GET /issues/:id.json` plus the 5 fields above.

```json
{
  "issue": {
    "id": 1222,
    "project": { "id": 23, "name": "..." },
    "subject": "...",
    "...": "(standard fields are identical to /issues/:id.json)",
    "reply_count": { "count": 0, "items": [ { "id": 0, "name": "" } ] },
    "children_count": { "count": 2, "items": [ { "id": 1223, "name": "..." } ] },
    "last_updated_by": { "id": 1, "name": "Redmine Admin" },
    "last_notes": "Latest comment text",
    "spent_hours_by_user": [ { "user_id": 1, "hours": 8.0 } ]
  }
}
```

## Response Example (XML, show)

```xml
<issue>
  <id>1222</id>
  <!-- standard fields are identical to /issues/:id.xml -->
  <reply_count><count>0</count><items type="array"><item id="0" name=""/></items></reply_count>
  <children_count><count>2</count><items type="array"><item id="1223" name="..."/></items></children_count>
  <last_updated_by id="1" name="Redmine Admin"/>
  <last_notes>Latest comment text</last_notes>
  <spent_hours_by_user type="array"><item user_id="1" hours="8.0"/></spent_hours_by_user>
</issue>
```

`last_updated_by` uses the same `id` / `name` attribute format as `author` / `assigned_to`. Each `item` of `spent_hours_by_user` has `user_id` / `hours` attributes.

## Relationship to the Standard Endpoint

- `issues_with_extras/*.api.rsb` is a copy of Redmine core's `issues/*.api.rsb` with the 5 fields added. Because the core view is not overridden, the standard `GET /issues` does not return these fields (zero side effects).
- Updates to the core view must be followed here (the equivalence test in TEST_SPEC detects any drift).

## Client Usage (redmine-net-api)

Redmine Studio calls this via `GetIssuesWithExtrasAsync` (list) / `GetIssueWithExtrasAsync` (single). See the redmine-net-api documentation for details.
