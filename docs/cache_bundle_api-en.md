# Cache Bundle API

A bundle retrieval API that completes the cache update of Redmine Studio (Windows client) in a single request.
Returns multiple Redmine resources (Projects / Trackers / Users / per-project Memberships, etc.) at once.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /cache_bundle.json` | Retrieve the cache bundle |

## Permissions

The range of the `users` / `custom_fields` / `groups` sections varies depending on the privileges of the API key used:

- **With admin privilege**: Returns all users, custom fields, and groups
- **Without admin privilege**: Returns only what that user can see in Redmine (the same range they see in the Redmine UI; empty if there is nothing they can see)

This lets users without an administrator API key build the cache within their own permission range.

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
| `projects` | Array of Project | Only projects the target user can see in Redmine (archived projects are excluded — same range as the individual projects API). Each project includes `trackers` / `enabled_modules` / `issue_categories` / `time_entry_activities` / `issue_custom_fields`, matching the individual projects API includes (trackers the target user can see issues for, active time-entry activities, and custom fields including those shared with all projects). Since Redmine 7.0 the individual projects API gates these includes by permission, so this matches it (`issue_categories` / `issue_custom_fields` require **`view_issues`**, `time_entry_activities` requires **`view_time_entries`** — i.e. the time_tracking module enabled and permitted; projects without the permission get an empty array. Redmine 6.1 and earlier have no such gate and always return them). `parent` is emitted **only when the parent is visible to the target user** (so the name of an invisible private parent is not leaked) |
| `trackers` | Array of Tracker | Includes `default_status` |
| `issue_statuses` | Array of IssueStatus | Includes `is_closed` |
| `issue_priorities` | Array of IssuePriority | All entries including inactive ones (same as the individual enumerations API). Includes `active` / `is_default` |
| `time_entry_activities` | Array of TimeEntryActivity | All entries including inactive ones (same as the individual enumerations API). Includes `active` / `is_default` |
| `queries` | Array of Query | Caller's visibility scope. `is_public` is true only for queries with public visibility (same as the core queries API) |
| `custom_fields` | Array of CustomField | All for admin; for non-admin, only the custom fields the user can see (those shared with everyone plus those assigned to the user's roles). `min_length` / `max_length` are null when unset (same as the core custom_fields API). `possible_values` are `{value, label}` pairs |
| `users` | Array of User | All active users for admin; for non-admin, only the users the user can see (self plus members of the same projects; may be all active users depending on role settings). Anonymous users are excluded. `status` is emitted only on **Redmine 6.1+**, where the individual API (GET /users.json) includes it in the list (Redmine before 6.1 does not return status in the list API, so this matches it) |
| `roles` | Array of Role | Only givable roles (builtin=0); builtin roles (Non member / Anonymous) are excluded (same as the individual API `GET /roles.json`). Includes `permissions` of each Role as an array of strings (same format as the core roles/:id API; absorbing the list-then-details N+1 on the server side) |
| `groups` | Array of Group | All groups for admin; for non-admin, only the groups the user can see. Regular groups only (type='Group'); builtin groups (Anonymous / Non member) are excluded (same as the individual API `GET /groups.json`). Includes `users` of each Group (for non-admin, limited to the users the requester can see) |
| `project_memberships` | `{ project_id => [Membership...] }` | Retrieved for projects where the target user is a member. Locked-user memberships are excluded |
| `project_versions` | `{ project_id => [Version...] }` | Projects where the target user is a member, and further only projects where the target user has the **`view_issues`** permission (same gate as the individual API `GET /projects/:id/versions.json`; projects without the permission return an empty array). Each Version includes its **custom field values** visible to the target user (`custom_fields`), matching the individual API `render_api_custom_values` (scalar for single value, array + `multiple` for multi-value) |
| `project_issue_categories` | `{ project_id => [IssueCategory...] }` | Only **Active** projects where the target user is a member, and further only projects where the target user has the **`manage_categories`** permission (same gate as the individual API `GET /projects/:id/issue_categories.json`; projects without the permission return an empty array) |
| `errors` | Array of `{ section, code, message }` | Partial failure metadata. Empty array means full success |

### Fields returned per section

The main fields returned by each section's objects are as follows (see "Section Specifications" above for details).

- Each section is based on the corresponding Redmine standard API resource, with some fields adjusted for our use.
- Fields with no value may be omitted.
- Depending on the user's roles and permissions, some sections and fields are limited to what the requester can see.
  - Examples: `parent` of `projects`, `users` of `groups`, `custom_fields` of `project_versions`

| Section | Returned fields |
|---|---|
| `projects` | `id` / `name` / `identifier` / `description` / `homepage` / `status` / `is_public` / `inherit_members` / `created_on` / `updated_on` / `trackers[]` / `enabled_modules[]` / `issue_categories[]` / `time_entry_activities[]` / `issue_custom_fields[]` / `parent` |
| `trackers` | `id` / `name` / `default_status` / `description` |
| `issue_statuses` | `id` / `name` / `is_closed` |
| `issue_priorities` | `id` / `name` / `active` / `is_default` |
| `time_entry_activities` | `id` / `name` / `active` / `is_default` |
| `queries` | `id` / `name` / `is_public` / `project_id` |
| `custom_fields` | `id` / `name` / `customized_type` / `field_format` / `regexp` / `min_length` / `max_length` / `is_required` / `is_filter` / `searchable` / `multiple` / `default_value` / `visible` / `possible_values[]` / `trackers[]` / `roles[]` |
| `users` | `id` / `login` / `firstname` / `lastname` / `mail` / `created_on` / `updated_on` / `last_login_on` / `passwd_changed_on` / `status` (Redmine 6.1+ only) / `admin` / `twofa_scheme` |
| `roles` | `id` / `name` / `assignable` / `issues_visibility` / `time_entries_visibility` / `users_visibility` / `permissions[]` |
| `groups` | `id` / `name` / `users[]` (each `id` / `name`) |
| Each `project_memberships` element | `id` / `project` / `roles[]` (incl. `inherited`) / `user` or `group` |
| Each `project_versions` element | `id` / `project` / `name` / `description` / `status` / `sharing` / `created_on` / `updated_on` / `due_date` / `wiki_page_title` / `custom_fields[]` |
| Each `project_issue_categories` element | `id` / `project` / `name` / `assigned_to` |

### Ordering

Each array is returned in the **same order** as when fetched individually — cache_bundle yields the same content and ordering as the individual API.

## Partial Failure Behavior

Exceptions are caught per section, filling that section with an empty array and adding an entry to the `errors` array. HTTP status is always 200 (to avoid the client falling back to the N+1 individual API fetches).

Example:
```json
{
  "cache_bundle": {
    "projects": [...],
    "project_memberships": {
      "207": [],
      "208": []
    },
    "errors": [
      { "section": "project_memberships", "code": 500, "message": "ActiveRecord::StatementInvalid: ..." }
    ]
  }
}
```

Fatal errors (e.g., HTTP 500 where the request itself fails) are expected to be handled on the client side by falling back to the individual API flow.
