# Reply Count

Adds a "Reply Count" column to the issue list.

## Overview

Displays the number of times an issue's assignee has been changed as "Reply Count". A high reply count may indicate misalignment in requirements or a large number of review comments, serving as a useful metric for analysis.

### Key Features

- Display reply count as an inline column in the issue list
- Sortable by reply count (default: descending)
- Hover over the reply count to see the assignee change history in a tooltip
- Provide a plugin-specific endpoint (`GET /issues_with_extras/:id.json` / `.xml`, `GET /issues_with_extras.json` / `.xml`) that returns responses including the `reply_count` field

### API Response Format

`reply_count` is returned as a nested object with `count` (the reply count) and `items` (the assignee transition). `items` carries the raw source data for display; formatting such as labeling is the client's responsibility.

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

- `items` is ordered as "initial assignee → new assignee of each change" (element count = `count` + 1)
- No assignee is represented as `id: 0, name: ""`; a deleted or invalid user as `id: <original ID>, name: ""`
- Issues with no assignee changes return `count: 0` and `items` containing only the current assignee

## How to Use

### Issue List

1. Open "Options" in the issue list
2. Move "Reply Count" from "Available columns" to "Selected columns"
3. Click "Apply"

## Reply Count Rules

- +1 each time the assignee is changed
- No assignee → User = +1 (initial assignment included)
- User → No assignee = +1 (clearing assignee included)
- Setting an assignee at issue creation is not counted (initial state)
- If never changed = 0

## Tooltip

Hover over the reply count to see the assignee change history in a tooltip.

**Example (Reply Count = 3):**
```
Taro Tanaka
 - Hanako Sato
 - Taro Tanaka
 - (No assignee)
```

- First line (no indent): Initial assignee at issue creation
- Subsequent lines (with ` - `): Assignee change targets
- If no assignee is set, displayed as "(No assignee)"
- Deleted users are displayed as "(No assignee)"
