# Cache Bundle API

A bundle retrieval API that completes the cache update of Redmine Studio (Windows client) in a single request.
Returns multiple Redmine resources (Projects / Trackers / Users / per-project Memberships, etc.) at once.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /cache_bundle.json` | Retrieve the cache bundle |

## Authentication

API key authentication is required.

The content of the response varies depending on the privileges of the API key used:

- **With admin privilege**: Full response including `users` / `custom_fields` / `groups`
- **Without admin privilege**: The above 3 sections are returned as empty arrays (others are returned normally)

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `user_id` | int | No | Target user ID for scope resolution. Defaults to the API key user (`User.current`).<br>Non-admin users cannot specify a `user_id` other than their own |

`user_id` is used to resolve the project ID set for the per-project sections (`project_memberships` / `project_versions` / `project_issue_categories`) on the server side.
When called with a master API key, the target application user's `user_id` must be specified explicitly (since `User.current` becomes the master user).

## Response Format

JSON only. XML is not supported (the dict-shaped sections such as `project_memberships` do not fit the XML standard pattern).

If `Accept-Encoding: gzip` is included in the request header, the response is gzip-compressed (`Content-Encoding: gzip`). This does not depend on Apache's `mod_deflate` configuration.

### Response Shape

```json
{
  "cache_bundle": {
    "markup_lang": "textile",
    "projects":                 [ ... ],
    "trackers":                 [ ... ],
    "issue_statuses":           [ ... ],
    "issue_priorities":         [ ... ],
    "time_entry_activities":    [ ... ],
    "queries":                  [ ... ],
    "custom_fields":            [ ... ],
    "users":                    [ ... ],
    "roles":                    [ ... ],
    "groups":                   [ ... ],
    "project_memberships":      { "207": [...], "208": [...] },
    "project_versions":         { "207": [...], "208": [...] },
    "project_issue_categories": { "207": [...] },
    "errors":                   [ ... ]
  }
}
```

The root has a single fixed key `cache_bundle`. Each section's content follows roughly the same format as the corresponding Redmine standard API resource.

## Section Specifications

| Section | Content | Notes |
|---|---|---|
| `markup_lang` | string | Value of `Setting.text_formatting` (`textile` / `common_mark`, etc.) |
| `projects` | Array of Project | Only projects visible to the target user (equivalent to `Project.visible`; `Archived` is not included — same scope as the individual projects API). Includes `trackers` / `enabled_modules` / `issue_categories` / `time_entry_activities` / `issue_custom_fields` |
| `trackers` | Array of Tracker | Includes `default_status` |
| `issue_statuses` | Array of IssueStatus | Includes `is_closed` |
| `issue_priorities` | Array of IssuePriority | All entries including inactive ones (same as the individual enumerations API). Includes `active` / `is_default` |
| `time_entry_activities` | Array of TimeEntryActivity | All entries including inactive ones (same as the individual enumerations API). Includes `active` / `is_default` |
| `queries` | Array of Query | Caller's visibility scope. `is_public` is true only for queries with public visibility (same as the core queries API) |
| `custom_fields` | Array of CustomField | **Admin privilege required**. Empty array if not authorized. `min_length` / `max_length` are null when unset (same as the core custom_fields API). `possible_values` are `{value, label}` pairs |
| `users` | Array of User | **Admin privilege required**. Active users only (same as the default behavior of the individual users API) |
| `roles` | Array of Role | Includes `permissions` of each Role as an array of strings (same format as the core roles/:id API; absorbing the list-then-details N+1 on the server side) |
| `groups` | Array of Group | **Admin privilege required**. Includes `users` of each Group |
| `project_memberships` | `{ project_id => [Membership...] }` | Retrieved for projects where the target user is a member. Locked-user memberships are excluded |
| `project_versions` | `{ project_id => [Version...] }` | Projects where the target user is a member |
| `project_issue_categories` | `{ project_id => [IssueCategory...] }` | Only **Active** projects where the target user is a member |
| `errors` | Array of `{ section, project_id?, code, message }` | Partial failure metadata. Empty array means full success |

## Partial Failure Behavior

Exceptions are caught per section / per project, filled with empty arrays, and entries are added to the `errors` array. HTTP status is always 200 (to avoid the client falling back to the N+1 individual API fetches).

Example:
```json
{
  "cache_bundle": {
    "projects": [...],
    "project_memberships": {
      "207": [...],
      "208": []
    },
    "errors": [
      { "section": "project_memberships", "project_id": 208, "code": 500, "message": "ActiveRecord::StatementInvalid: ..." }
    ]
  }
}
```

Fatal errors (e.g., HTTP 500 where the request itself fails) are expected to be handled on the client side by falling back to the individual API flow.

## Version

This endpoint was added in redmine_studio_plugin **1.6.0**. Redmine Studio side confirms via the `Plugin API` that `redmine_studio_plugin >= 1.6.0` before calling this endpoint.

## Client-Side Usage Example

Example code calling from the C# client (redmine-net-api) of Redmine Studio:

```csharp
var prm = new NameValueCollection { { RedmineKeys.USER_ID, "42" } };
var bundle = await masterServiceAsync.GetCacheBundleAsync(prm);
```

The returned `CacheBundle` instance from `GetCacheBundleAsync` is poured into `Data.*` by `CacheService.applyCacheBundle()`.
