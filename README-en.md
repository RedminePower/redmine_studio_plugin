# redmine_studio_plugin

## Overview

This plugin provides features for [Redmine Studio](https://www.redmine-power.com/) (Windows client application provided by Redmine Power).

## Features

- API to retrieve information about installed plugins
  - Get plugin list
  - Get single plugin information (including settings)

## Supported Redmine

- V5.x (Tested on V5.1.11)
- V6.x (Tested on V6.1.1)

## Installation

Run the following commands in the Redmine plugins folder and restart Redmine.

```
$ cd /var/lib/redmine/plugins
$ git clone https://github.com/RedminePower/redmine_studio_plugin.git
```

## Usage

### Prerequisites

- Enable "Enable REST web service" in Administration > Settings > API.

### API Endpoints

This plugin provides the following APIs. They are used by Redmine Studio.

| Endpoint | Description |
|----------|-------------|
| `GET /plugins.json` | Get plugin list |
| `GET /plugins/:id.json` | Get single plugin information |

## Uninstall

Remove the plugin folder.

```
$ cd /var/lib/redmine/plugins
$ rm -rf redmine_studio_plugin
```

## License

MIT License
