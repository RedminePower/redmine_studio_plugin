# redmine_studio_plugin

## Overview

This plugin provides features for [Redmine Studio](https://www.redmine-power.com/) (Windows client application provided by Redmine Power).

### Prerequisites

Enable "Enable REST web service" in "Administration" → "Settings" → "API".

## Features

- **Reply Button** - Adds a "Reply" button to tickets
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

### 2. Setup

Run the following command. This will remove integrated plugins.

```bash
cd /path/to/redmine
bundle exec rake redmine_studio_plugin:setup RAILS_ENV=production
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

## Plugin API

| Endpoint | Description |
|----------|-------------|
| `GET /plugins.json` | Get plugin list |
| `GET /plugins/:id.json` | Get single plugin information |

## Uninstall

Remove the plugin folder.

```bash
cd /path/to/redmine/plugins
rm -rf redmine_studio_plugin
```

## License

MIT License
