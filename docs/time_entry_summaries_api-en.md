# Time Entry Summaries API

Summarizes time entries per "user x spent date x project" and returns a digest for each group.

Redmine Studio keeps time entries locally, asks this API for the digests of the days it shows, and re-fetches time entries only for the groups whose digest differs from the local one. The standard time entry API cannot tell which days changed (updates, deletions, reassignments), so this API is used to detect them.

It is a dedicated controller that inherits the standard `TimelogController`; filtering, visibility and differences between Redmine versions are left to Redmine itself. No log table is kept: the digests are computed from the current time entries on every request.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /time_entry_summaries.json` | Retrieve the summaries (JSON) |
| `GET /time_entry_summaries.xml` | Same as above (XML) |

## Permissions

Authentication is required; anonymous access is rejected with 401. For authenticated users, permissions and visibility are the same as the standard time entry list (`GET /time_entries`): `view_time_entries`. Groups in projects the user cannot see are not returned, and the "own time entries only" visibility applies as is.

## Parameters

The same filters as the standard time entry list are accepted. Unknown parameters are ignored.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `from` | Yes | First spent date (`YYYY-MM-DD`) |
| `to` | Yes | Last spent date (`YYYY-MM-DD`, inclusive) |
| `user_id` | | User ID. Multiple IDs can be separated with `\|` (e.g. `1\|2\|3`). `me` is also accepted |
| `project_id` | | Project ID or identifier |

- The period from `from` to `to` must be 62 days or less (both ends included)
- `user_id` can list up to 100 users
- Saved queries (`query_id`) are not used, because they would replace the period given by `from` / `to`
- Results are not paginated; everything is returned at once

### Errors

422 with `errors` is returned when:

- `from` or `to` is missing, not in `YYYY-MM-DD` form, or not a valid date
- `to` is before `from`
- The period exceeds 62 days
- `user_id` lists more than 100 users

```json
{ "errors": ["the period must be 62 days or less"] }
```

## Response

Only groups with at least one time entry are returned, ordered by `user_id`, `spent_on`, `project_id`.

```json
{
  "time_entry_summaries": [
    { "user_id": 1, "spent_on": "2026-11-10", "project_id": 3, "digest": "6fff726a84540129ba294270c31f5d6b" },
    { "user_id": 1, "spent_on": "2026-11-11", "project_id": 3, "digest": "2b147f24c76845f8e98ef8b7491e6b8c" }
  ]
}
```

```xml
<time_entry_summaries type="array">
  <time_entry_summary>
    <user_id>1</user_id>
    <spent_on>2026-11-10</spent_on>
    <project_id>3</project_id>
    <digest>6fff726a84540129ba294270c31f5d6b</digest>
  </time_entry_summary>
</time_entry_summaries>
```

| Field | Type | Description |
|-------|------|-------------|
| `user_id` | integer | User ID |
| `spent_on` | string | Spent date (`YYYY-MM-DD`) |
| `project_id` | integer | Project ID |
| `digest` | string | Digest of the group. It has no meaning by itself; only compare it for equality |

## How the digest is built

The digest is built from the following values of the time entries in the group (only SUM, COUNT and MAX are used in the database):

- Number of entries
- Total hours (rounded to 2 decimal places)
- Latest updated time
- Sum of issue IDs
- Sum of activity IDs

| Change | Digest |
|--------|--------|
| A time entry is added or deleted | The count changes. When the last entry of a group is deleted, the group is no longer returned |
| A time entry is edited | The updated time changes |
| An issue is deleted and its time entries are reassigned to another issue | The sum of issue IDs changes |
| An activity is deleted and its time entries are reassigned to another activity | The sum of activity IDs changes |
| An issue is moved to another project | The group of the old project changes (or disappears) and the group of the new project changes (or appears) |
| Permissions change and the visible time entries change | The digest is computed from the visible entries, so it changes |

The following changes do not change the digest. Both are rare, and clients are expected to have a way to re-fetch (such as a reload).

- Only comments or custom fields are bulk-updated without changing the updated time
- Issue IDs are swapped so that their sum stays the same

The way the digest is computed may change in later versions. Clients may store digests, but must not interpret their content.

## Performance

No index is added to `time_entries`. With 400,000 time entries, a query for 1 user x 8 days returned in a few tens of milliseconds (Redmine's own index on `user_id` is used).
