# Journals List

Displays comment history in the issue list.

## Overview

Adds a "Journals" display option to the issue list. When enabled, a table of comments is displayed below each issue row, allowing you to see at a glance who made what comments — useful for tracking review discussions.

This feature works as a block column, just like "Description" and "Last notes", and is available in both the standard Redmine issue list and the `ref_issues` macro.

### Key Features

- Display comment history for each issue in the issue list
- Collapse/expand individual comments (with Wiki rendering)
- Sort by column headers (#, Author, Date, Notes)
- Right-click context menu for batch expand/collapse
- Respects private notes permission

## How to Use

### Issue List

1. Open "Options" in the issue list
2. Check "Journals" in the "Display" section
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
| Notes | First line of the comment (plain text, max 100 characters) |

### Detail View

Click the "Show" button to display the full comment rendered with Wiki formatting.

- Expanded content is loaded via AJAX on demand, so it does not affect page load speed
- Once expanded, content is cached and subsequent expansions do not send server requests

### Display Rules

- Journals without notes (e.g., status changes only) are not displayed
- Private notes are hidden from users without the appropriate permission

## Sorting

Click on a column header (#, Author, Date, Notes) to sort by that column.

- Each click toggles between ascending and descending order
- Sort direction is indicated by a chevron icon (∧/∨)
- Expanded comments remain expanded after sorting

## Right-click Context Menu

Right-clicking on a comment row in the journals list displays the following menu.

| Menu Item | Action |
|-----------|--------|
| Show detail | Expand the right-clicked comment (shown only when collapsed) |
| Hide detail | Collapse the right-clicked comment (shown only when expanded) |
| Show all details | Expand all comments for the same issue |
| Hide all details | Collapse all comments for the same issue |

Right-clicking on the expanded detail area (Wiki rendered content) also displays the same menu.
