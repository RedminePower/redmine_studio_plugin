# Info API

API to retrieve Redmine environment information. Provides the same information displayed on the "Administration" > "Information" page via API.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /info.json` | Get Redmine environment information |

## Authentication

No authentication required. Accessible by anyone.

## Response Format

The API supports both JSON and XML.

| Extension | Content-Type |
|-----------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

Example:
```
GET /info.json   → Returns JSON format
GET /info.xml    → Returns XML format
```

---

## Environment Information

### GET /info

Get Redmine environment information.

Response:

```json
{
  "info": {
    "redmine_version": "6.1.1.stable",
    "ruby_version": "3.4.8-p72 (2025-12-17) [x86_64-linux]",
    "rails_version": "7.2.3",
    "environment": "production",
    "database_adapter": "SQLite",
    "mailer_queue": "ActiveJob::QueueAdapters::AsyncAdapter",
    "mailer_delivery": "smtp",
    "redmine_theme": "Default",
    "text_formatting": "common_mark",
    "scm": [
      {
        "name": "Git",
        "version": "2.47.3"
      },
      {
        "name": "Subversion",
        "version": "1.14.5"
      }
    ],
    "plugins": [
      {
        "id": "redmine_studio_plugin",
        "version": "1.1.4"
      }
    ]
  }
}
```

---

## Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `redmine_version` | string | Redmine version |
| `ruby_version` | string | Ruby version (including platform information) |
| `rails_version` | string | Rails version |
| `environment` | string | Execution environment (production, development, test) |
| `database_adapter` | string | Database adapter name (SQLite, MySQL, PostgreSQL, etc.) |
| `mailer_queue` | string | Mail queue adapter class name |
| `mailer_delivery` | string | Mail delivery method (smtp, sendmail, etc.) |
| `redmine_theme` | string | UI theme ("Default" if not set) |
| `text_formatting` | string | Text formatting (textile, common_mark, etc.) |
| `scm` | array | List of installed SCMs |
| `plugins` | array | List of installed plugins |

### scm Array

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | SCM name (Git, Subversion, Mercurial, Bazaar) |
| `version` | string | SCM version |

Note: Only SCMs with retrievable version information are included

### plugins Array

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Plugin ID |
| `version` | string | Plugin version |
