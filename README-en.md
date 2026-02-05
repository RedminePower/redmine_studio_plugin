# redmine_studio_plugin

## Overview

This plugin provides features for [Redmine Studio](https://www.redmine-power.com/) (Windows client application provided by Redmine Power).

### Prerequisites

Enable "Enable REST web service" in "Administration" → "Settings" → "API".

## Features

- **Reply Button** - Adds a "Reply" button to tickets
- **Teams Button** - Adds a "Teams" button to usernames to start a chat
- **Auto Close** - Automatically closes issues based on conditions
- **Plugin API** - API to retrieve plugin information (used internally by Redmine Studio)

## Supported Redmine

- V5.x (Tested on V5.1.11)
- V6.x (Tested on V6.1.1)

## Installation

### 1. Deploy the plugin

Run the following commands in the Redmine plugins folder.

```bash
cd /path/to/redmine/plugins
git clone https://github.com/RedminePower/redmine_studio_plugin.git
```

### 2. Install

Run the following command. This command removes old plugins, runs DB migration, and registers cron in one step.

```bash
cd /path/to/redmine
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

## Plugin API

| Endpoint | Description |
|----------|-------------|
| `GET /plugins.json` | Get plugin list |
| `GET /plugins/:id.json` | Get single plugin information |

## Uninstall

### 1. Run the uninstall command

Removes cron job and rolls back DB migration.

```bash
cd /path/to/redmine
bundle exec rake redmine_studio_plugin:uninstall RAILS_ENV=production
```

### 2. Remove the plugin

Remove the plugin folder.

```bash
cd /path/to/redmine/plugins
rm -rf redmine_studio_plugin
```

## License

MIT License
