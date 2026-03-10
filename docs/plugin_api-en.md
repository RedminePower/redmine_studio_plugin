# Plugin API

API to retrieve information about plugins installed in Redmine.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /plugins.json` | Get plugin list |
| `GET /plugins/:id.json` | Get single plugin information |

## Authentication

All endpoints require API key authentication.

```
GET /plugins.json?key=YOUR_API_KEY
```

## Response Format

The API supports both JSON and XML.

| Extension | Content-Type |
|-----------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

Example:
```
GET /plugins.json   → Returns JSON format
GET /plugins.xml    → Returns XML format
```

---

## Plugin List

### GET /plugins

Get a list of plugins.

Query parameters:

| Parameter | Description |
|-----------|-------------|
| `include` | Set to `settings` to include plugin settings |
| `offset` | Starting position |
| `limit` | Number of items (default: 25, max: 100) |

Response:

```json
{
  "plugins": [
    {
      "id": "redmine_studio_plugin",
      "name": "Redmine Studio plugin",
      "description": "Provides features for Redmine Studio...",
      "version": "1.0.0",
      "author": "Redmine Power",
      "author_url": "https://www.redmine-power.com/",
      "url": "https://github.com/RedminePower/redmine_studio_plugin"
    }
  ],
  "total_count": 1,
  "offset": 0,
  "limit": 25
}
```

With `include=settings`:

```json
{
  "plugins": [
    {
      "id": "redmine_studio_plugin",
      "name": "Redmine Studio plugin",
      "version": "1.0.0",
      "author": "Redmine Power",
      "settings": "{\"key\":\"value\"}"
    }
  ],
  "total_count": 1,
  "offset": 0,
  "limit": 25
}
```

Note: For plugins without settings, the `settings` property is omitted

---

## Plugin Details

### GET /plugins/:id

Get details of a specific plugin. Includes `settings` if the plugin is configurable.

Response:

```json
{
  "plugin": {
    "id": "redmine_studio_plugin",
    "name": "Redmine Studio plugin",
    "description": "Provides features for Redmine Studio...",
    "version": "1.0.0",
    "author": "Redmine Power",
    "author_url": "https://www.redmine-power.com/",
    "url": "https://github.com/RedminePower/redmine_studio_plugin",
    "settings": "{\"key\":\"value\"}"
  }
}
```

---

## Error Responses

### 404 Not Found

Returns standard HTTP 404 status (no response body).

Returns 404 in the following cases:
- Specified plugin does not exist
