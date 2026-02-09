# redmine_studio_plugin

## Overview

This plugin provides features for [Redmine Studio](https://www.redmine-power.com/) (Windows client application provided by Redmine Power).

## Features

- **Reply Button** - Adds a "Reply" button to tickets
- **Teams Button** - Adds a "Teams" button to usernames to start a chat
- **Auto Close** - Automatically closes issues based on conditions
- **Date Independent** - Makes parent issue dates independent from child issues
- **Wiki Lists** - Macros to display wiki pages and issue lists
- **Plugin API** - API to retrieve plugin information (used internally by Redmine Studio)

## Supported Redmine

- V5.x (Tested on V5.1.11)
- V6.x (Tested on V6.1.1)

## Installation

The Redmine installation path varies depending on your environment.
The following instructions use `/var/lib/redmine`.
Please adjust according to your environment.

| Environment | Redmine Path |
|-------------|--------------|
| apt (Debian/Ubuntu) | `/var/lib/redmine` |
| Docker (Official Image) | `/usr/src/redmine` |
| Bitnami | `/opt/bitnami/redmine` |

### 1. Deploy the plugin

Run the following commands in the Redmine plugins folder.

```bash
cd /var/lib/redmine/plugins
git clone https://github.com/RedminePower/redmine_studio_plugin.git
```

### 2. Install

Run the following command. This command removes old plugins, runs DB migration, and registers cron in one step.
Make sure to run this command in the Redmine installation folder.

```bash
cd /var/lib/redmine
bundle exec rake redmine_studio_plugin:install RAILS_ENV=production
```

### 3. Restart Redmine

Restart Redmine to apply the changes.

## Reply Button

A feature that adds a "Reply" button to tickets.

- Clicking the "Reply" button automatically sets the last commenter as the assignee
- If there are no comments, the ticket author is set as the assignee
- Enables email-like exchanges on tickets, convenient for ticket-driven development

### Activation

This feature can be enabled or disabled per project.
The "Reply" button will not appear unless the following settings are configured.

1. Go to project "Settings"
2. In the "Project" tab, check "Reply button" under "Modules" and save

## Teams Button

A feature that adds a "Teams" button next to usernames, allowing you to start a chat with one click.

- Clicking the "Teams" button opens a Teams chat with that user
- The chat is pre-filled with ticket information (title, URL, ticket number)

### Supported Client

- Must be using Office365 (Tested on Windows10, Android)
  - Because the DeepLink function is used to launch Teams

### Activation

This feature can be enabled or disabled per project.
The "Teams" button will not appear unless the following settings are configured.

1. Go to project "Settings"
2. In the "Project" tab, check "Teams button" under "Modules" and save

## Auto Close

A feature that automatically closes issues (status change, assignee change, comment addition) based on conditions.

- Automatically closes parent issues when all child issues are closed
- Periodically closes expired issues (executed via cron daily at 3:00)
- Flexible condition settings including project, tracker, status, and custom fields

### Administration

Rules can be created, edited, and deleted from the "Auto close" menu in the administration panel.

### Manual execution of expired issues

The expired trigger is automatically executed by cron, but you can manually execute it with the following command.

```bash
bundle exec rake redmine_studio_plugin:auto_close:check_expired RAILS_ENV=production
```

## Date Independent

A feature that makes parent issue start dates and due dates independent from child issues.

In Redmine, when the "Derive from child issues" setting is enabled, parent issue dates are automatically calculated from child issues.
This feature allows you to control this behavior based on project and status.

- Make parent issue dates independent for specific projects
- Maintain synchronization for specific statuses (e.g., Closed)

### Administration

Rules can be created, edited, and deleted from the "Date independent" menu in the administration panel.

## Wiki Lists

Provides macros to display issue and page lists on Wiki pages.

### wiki_list macro

Displays a list of wiki pages in table format.

**Basic syntax:** `{{wiki_list(options, columns...)}}`

**Options:**

| Option | Description |
|--------|-------------|
| `-p` | Show only pages in current project |
| `-p=identifier` | Show only pages in specified project |
| `-c` | Show only child pages |
| `-w=width` | Set table width (e.g., `-w=80%`) |

**Columns:**

| Column | Description |
|--------|-------------|
| `+title` | Page title (link) |
| `+alias` | Page alias |
| `+project` | Project name |
| `keyword:` | Extract text after keyword in page |
| `keyword:\delimiter` | Extract text from keyword to delimiter |

**Examples:**
```
{{wiki_list(-p, +title)}}
{{wiki_list(-p, +title, Author:)}}
{{wiki_list(-p, +title, Author:|Manager|150px)}}
```

### issue_name_link macro

Creates a link from issue subject.

**Basic syntax:** `{{issue_name_link(subject)}}` or `{{issue_name_link(subject|display text)}}`

**Examples:**
```
{{issue_name_link(Bug fix)}}
{{issue_name_link(Bug fix|Link text)}}
{{issue_name_link(project-id:Bug fix)}}
```

### ref_issues macro

Displays a list of issues matching conditions.

**Basic syntax:** `{{ref_issues(options, columns...)}}`

**Options:**

| Option | Description |
|--------|-------------|
| `-p` | Current project issues only |
| `-p=identifier` | Specified project issues only |
| `-q=query name` | Use custom query |
| `-i=query ID` | Use custom query ID |
| `-s=keyword` | Search in subject |
| `-d=keyword` | Search in description |
| `-w=keyword` | Search in subject + description |
| `-f:field=value` | Filter condition |
| `-n=count` | Limit display count (max 1000) |
| `-t` | Display subject as plain text |
| `-l` | Display subject as link |
| `-c` | Display count only |
| `-0` | Display nothing if 0 results |

**Examples:**
```
{{ref_issues(-p)}}
{{ref_issues(-q=My Query)}}
{{ref_issues(-f:status=New, -f:tracker=Bug)}}
{{ref_issues(-p, id, subject, status)}}
```

## Plugin API

| Endpoint | Description |
|----------|-------------|
| `GET /plugins.json` | Get plugin list |
| `GET /plugins/:id.json` | Get single plugin information |

## Uninstall

### 1. Run the uninstall command

Removes cron job and rolls back DB migration.

```bash
cd /var/lib/redmine
bundle exec rake redmine_studio_plugin:uninstall RAILS_ENV=production
```

### 2. Remove the plugin

Remove the plugin folder.

```bash
cd /var/lib/redmine/plugins
rm -rf redmine_studio_plugin
```

## License

GPL v2 License
