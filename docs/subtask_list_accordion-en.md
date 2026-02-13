# Subtask List Accordion

Adds accordion (collapse/expand) functionality to the subtask list on issues.

## Overview

Redmine's subtask list becomes difficult to navigate when the hierarchy gets deep.
This feature converts the subtask list into an accordion format that can be collapsed and expanded, allowing you to display only the parts you need even with complex issue structures.

### Key Features

- Collapse/expand each level of the subtask list
- "Expand All" and "Collapse All" links at the top of the subtask list
- Right-click context menu for quick operations

### Activation Conditions

The accordion feature is only enabled when grandchild issues (children of child issues) exist.
If there are only direct child issues, the standard subtask list is displayed.

## Plugin Settings

Configure from the Admin menu under "Plugins" > "Redmine Studio Plugin".

| Setting | Default Value | Description |
|---------|---------------|-------------|
| Enable server-side processing mode | Enabled | Mode that generates the subtask list HTML on the server side |
| Expand all child issues by default | Disabled | Whether to expand all child issues on initial display |
| Trackers to collapse | None | Issues with specified trackers will be collapsed by default |

### Server-side Processing Mode vs Client-side Processing Mode

This feature has two operation modes.

| Mode | Characteristics |
|------|-----------------|
| Server-side Processing Mode | Generates subtask list HTML on the server side. Fast display even with many grandchild issues |
| Client-side Processing Mode | Processes Redmine's standard subtask list with JavaScript. Higher compatibility with other plugins |

**Mode Selection Guidelines:**

- **Server-side Processing Mode (Recommended)**: When not using other plugins that modify the subtask list
- **Client-side Processing Mode**: When using plugins that customize the subtask list, such as `subtask_list_columns`

### Trackers to Collapse

This setting is only available when "Expand all child issues by default" is enabled.

Issues with specified trackers will be displayed collapsed by default, regardless of the expand all setting.
This allows you to collapse specific trackers (e.g., Task, Bug) while keeping important trackers (e.g., Feature, Milestone) expanded.

## User Settings

Each user can configure these settings from "My account".

| Setting | Default Value | Description |
|---------|---------------|-------------|
| Maximum child issues for auto-expanding tree | 0 | Automatically expand the tree when the number of child issues is at or below this value |

> **Note:** If "Expand all child issues by default" is enabled in plugin settings, this user setting is ignored.

### Behavior Examples

- **Limit: 0** - Always displayed collapsed
- **Limit: 10** - Expanded if 10 or fewer child issues, collapsed if 11 or more
- **Limit: 999** - Almost always displayed expanded

## How to Use

### Links at the Top of the Subtask List

The following links are displayed at the top of the subtask list.

| Link | Action |
|------|--------|
| Expand All | Expand all child issues |
| Collapse All | Collapse all child issues, showing only direct children |

### Right-click Context Menu

Right-clicking on an issue in the subtask list displays the following menu.

| Menu Item | Action |
|-----------|--------|
| Expand this tree | Expand all issues under the selected issue |
| Collapse this tree | Collapse all issues under the selected issue |
| Expand all at this level | Expand all issues at the same level as the selected issue |

### Collapse/Expand Operations

Click the arrow on the left side of each issue to collapse/expand its child issues.

- **▶ (Right arrow)**: Click to expand
- **▼ (Down arrow)**: Click to collapse
