# Auto Close

A feature that automatically performs actions on matching issues based on specific triggers.

## Overview

The following two types of triggers are supported:

| Trigger | Behavior |
|---------|----------|
| When all child issues are closed | Executes an action on the parent issue when all of its child issues are closed |
| When due date has passed | Periodically checks for overdue issues and executes actions on those matching the conditions (runs daily at 3:00 via cron) |

Available actions:
- Change status
- Change assignee
- Add comment

### Use Cases

**When all child issues are closed:**
- Break down a parent issue into multiple subtasks and automatically close the parent when all are completed
- Automatically close a release issue when all related feature additions and bug fixes are completed
- Integrate with [Redmine Studio](https://www.redmine-power.com/) review feature to automatically close the review issue when all review requests and issues are resolved

**When due date has passed:**
- Clean up neglected issues - Automatically close overdue issues to keep the issue list clean
- Escalate overdue issues - Change the assignee to a supervisor or administrator to prompt action
- Prevent missed responses - Add reminder comments to overdue issues to alert stakeholders

## Administration Screen

You can create, edit, and delete rules from "Auto Close" in the administration menu.

## Configuration Options

### Basic Settings

| Item | Description |
|------|-------------|
| Title | Set an easily identifiable name for management purposes (required) |
| Enabled | Toggle the rule on/off |
| Project | Select the target projects (multiple selection allowed). If not specified, no project filtering is applied |

### Trigger Settings

| Item | Description |
|------|-------------|
| Trigger type | Select "When all child issues are closed" or "When due date has passed" (required) |
| Tracker | Specify the tracker for target issues. If not specified, no tracker filtering is applied |
| Subject pattern | Specify the issue subject using regular expressions (e.g., `Feature\|Bug`). If not specified, no subject filtering is applied |
| Status | Specify the status for target issues. If not specified, no status filtering is applied |
| Custom field | Filter by a boolean-type custom field. If not specified, no custom field filtering is applied |
| Value | The condition value for the above custom field (checked/unchecked) |

#### Settings specific to overdue trigger

| Item | Description |
|------|-------------|
| Maximum issues to process at once | Upper limit to prevent unintended mass updates (default: 50). If the number of target issues exceeds this value, processing will not be executed |

> **Note:** For the overdue trigger, at least one condition (project, tracker, status, subject pattern, or custom field) must be configured.

### Action Settings

| Item | Description |
|------|-------------|
| Change status | The status to change to when the action is executed |
| Change assignee | The assignee to change to when the action is executed (specify a user directly) |
| Specify by custom field | Get the assignee from a user-type custom field. If a user is specified in "Change assignee", that takes priority |
| Add comment | The comment to add when the action is executed |
| Add to parent issue as well | Also add the comment to the parent issue |

> **Note:** At least one of "Change status", "Change assignee", or "Add comment" must be configured.

#### Settings specific to overdue trigger

| Item | Description |
|------|-------------|
| Execution user | The user who executes the action (recorded in the issue history) |

Execution user options:

| Option | Description |
|--------|-------------|
| Target issue's assignee | Execute as the current assignee of the target issue |
| Target issue's author | Execute as the author of the target issue |
| Parent issue's assignee | Execute as the assignee of the parent issue |
| (Username) | Execute as the specified user |

## Manual Execution of Overdue Issue Check

The overdue trigger runs automatically via cron daily at 3:00, but you can run it manually using the following command:

```bash
bundle exec rake redmine_studio_plugin:auto_close:check_expired RAILS_ENV=production
```

Execution logs are output to `log/auto_close.log` (check `log/production.log` for details).
