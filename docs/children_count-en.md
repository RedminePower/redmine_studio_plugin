# Children Count

Adds a "Children Count" column to the issue list.

## Overview

Displays the number of direct child issues for each issue in the list. A high children count indicates issues with many review comments or subtasks. For example, when listing issues with the "Review Meeting" tracker, you can quickly identify reviews with many comments.

### Key Features

- Display children count as an inline column in the issue list
- Sortable by children count (default: descending)
- Click the count to navigate to a list of issues whose parent is the current issue
- Hover over the count to see child issue IDs and subjects in a tooltip

## How to Use

### Issue List

1. Open "Options" in the issue list
2. Move "Children Count" from "Available columns" to "Selected columns"
3. Click "Apply"

### Navigating to Child Issues

When the count is 1 or more, the number becomes a link. Clicking it navigates to the cross-project issue list filtered by the current issue as the parent. This allows you to see all children even when they have been moved to other projects.

When the count is 0, the number is not a link.

## Counting Rules

- Counts only **direct child issues** (does not include grandchildren or deeper descendants)
- Counts only child issues that the current logged-in user has permission to view (children in inaccessible projects are not counted)

## Tooltip

Hover over the children count to see the IDs and subjects of child issues in a tooltip.

**Example (Children Count = 3):**
```
#1234 Spec review comment 1
#1235 Spec review comment 2
#1236 Spec review comment 3
```

- Up to 10 children are displayed. If there are more, the last line shows `...N more`
- Subjects longer than 30 characters are truncated with `...` at the end
- Only child issues visible to the current logged-in user are shown
