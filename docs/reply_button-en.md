# Reply Button

Adds a "Reply" button to issues.

<img src="images/reply_button_01.png" width="700">

## Overview

This feature adds a "Reply" button to the issue screen, allowing users to communicate on issues as naturally as replying to emails.

| Action | Behavior |
|--------|----------|
| Click "Reply" button | The last comment author is automatically set as the assignee |
| No comments exist | The issue author is set as the assignee |

### Use Cases

- **Issue-driven development** - Continue discussions quickly without manually changing assignees
- **Support inquiries** - Enable smooth communication between inquirers and support staff
- **Review feedback** - Efficiently respond to reviewers' comments

## Enabling the Feature

This feature can be enabled or disabled per project.
The "Reply" button will not appear unless you configure the following settings.

1. Open the project "Settings"
2. In the "Project" tab, check "Reply button" under "Modules" and save

## Behavior Specification

Assignee assignment logic when the "Reply" button is clicked:

| Condition | User Set as Assignee |
|-----------|---------------------|
| Last updater is another user | Last updater |
| Last updater is yourself | Searches backwards for the first other user |
| All updaters are yourself | Yourself |
| Issue has no comments | Issue author |

### When the Last Comment Is Your Own

When the last updater is yourself, the reply button searches backwards through previous updates and sets the most recent other user as assignee. This allows you to correctly reassign the issue even if you forgot to change the assignee after commenting.

### Difference from Edit Button

| Button | Assignee Behavior |
|--------|-------------------|
| Reply | Changes to the last comment author (or issue author) |
| Edit | Keeps the current assignee |
