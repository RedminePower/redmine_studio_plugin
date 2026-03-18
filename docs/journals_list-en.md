# Journals List (Comment History)

Displays comment history in the issue list.

## Overview

Adds a "Comment History" display option to the issue list. When enabled, a table of comments is displayed below each issue row, allowing you to see at a glance who made what comments — useful for tracking review discussions.

This feature works as a block column, just like "Description" and "Last notes", and is available in both the standard Redmine issue list and the `ref_issues` macro.

### Key Features

- Display comment history for each issue in the issue list
- Show status and assignee at each comment's point in time
- Collapse/expand individual comments (with Wiki rendering)
- Sort by column headers (#, Author, Date, Status, Assignee, Notes)
- Double-click on header row to toggle detail expand/collapse
- Right-click context menu for batch expand/collapse
- Respects private notes permission

## How to Use

### Issue List

1. Open "Options" in the issue list
2. Check "Comment History" in the "Display" section
3. Click "Apply"

### ref_issues Macro

In Wiki pages or issue descriptions, specify `journals_list` as a column.

```
{{ref_issues(-p, id, subject, journals_list)}}
```

## Display Content

### Header Row

The following information is displayed in a single row for each comment.

| Item | Content |
|------|---------|
| # | Comment number (click to jump to the comment on the issue detail page) |
| Author | Comment author name (click to jump to the user page) |
| Date | Comment timestamp |
| Status | Issue status at the time of the comment |
| Assignee | Issue assignee at the time of the comment (click to jump to the user page) |
| Notes | First line of the comment (plain text, max 100 characters) |

### Status and Assignee Display Rules

- Each comment row shows the cumulative status and assignee up to and including that journal's attribute changes
- If status or assignee is changed at the same time as the comment, the post-change value is displayed
- Journals without notes (attribute changes only) are not displayed as rows, but their attribute changes are reflected in subsequent comment rows

### Detail View

Click the "Show" button or double-click the header row to display the full comment rendered with Wiki formatting.

- Expanded content is loaded via AJAX on demand, so it does not affect page load speed
- Once expanded, content is cached and subsequent expansions do not send server requests
- Double-click on the header row toggles expand/collapse
- Double-click on the detail area selects text (does not collapse)

### Display Rules

- Journals without notes (e.g., status changes only) are not displayed
- Private notes are hidden from users without the appropriate permission

## Sorting

Click on a column header (#, Author, Date, Status, Assignee, Notes) to sort by that column.

- Each click toggles between ascending and descending order
- Sort direction is indicated by a chevron icon (∧/∨)
- Expanded comments remain expanded after sorting

## Right-click Context Menu

Right-clicking on a comment row in the comment history displays the following menu.

| Menu Item | Action |
|-----------|--------|
| Show detail | Expand the right-clicked comment (shown only when collapsed) |
| Hide detail | Collapse the right-clicked comment (shown only when expanded) |
| Show all details | Expand all comments for the same issue |
| Hide all details | Collapse all comments for the same issue |

Right-clicking on the expanded detail area (Wiki rendered content) also displays the same menu.
