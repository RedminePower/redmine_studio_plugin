# Rally Count

Adds a "Rally Count" column to the issue list.

## Overview

Displays the number of times an issue's assignee has been changed as "Rally Count". A high rally count may indicate misalignment in requirements or a large number of review comments, serving as a useful metric for analysis.

### Key Features

- Display rally count as an inline column in the issue list
- Sortable by rally count (default: descending)
- Hover over the rally count to see the assignee change history in a tooltip

## How to Use

### Issue List

1. Open "Options" in the issue list
2. Move "Rally Count" from "Available columns" to "Selected columns"
3. Click "Apply"

## Rally Count Rules

- +1 each time the assignee is changed
- No assignee → User = +1 (initial assignment included)
- User → No assignee = +1 (clearing assignee included)
- Setting an assignee at issue creation is not counted (initial state)
- If never changed = 0

## Tooltip

Hover over the rally count to see the assignee change history in a tooltip.

**Example (Rally Count = 3):**
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
