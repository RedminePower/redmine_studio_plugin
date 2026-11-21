# Info API

API to retrieve Redmine environment information. Provides the same information displayed on the "Administration" > "Information" page via API.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /info.json` | Get Redmine environment information |

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
    ],
    "app_server": {
      "name": "puma",
      "capacity": 5
    },
    "log_level": "info"
  }
}
```

`app_server` and `log_level` are returned only to system administrators (for other users, the fields are not returned at all).

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
| `app_server` | object | The running application server (system administrators only) |
| `log_level` | string / null | The log level (`debug`, `info`, `warn`, `error`, `fatal` or `unknown`). `null` if it cannot be taken (system administrators only). With `warn` or higher, the per-request lines (Started, Completed) are not written to the log |

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

### app_server (system administrators only)

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | `puma`, `passenger`, `thin`, `unicorn`, `webrick` or `unknown`. Decided from the request's `SERVER_SOFTWARE` and constants that exist only when running on that server |
| `capacity` | integer / null | The number of requests that can be processed at the same time. For Puma, from the settings (number of workers x max threads), or from `Puma.stats` if the settings cannot be read. `null` when unknown (Thin, Passenger, Unicorn, WEBrick, etc.) |

Fields that cannot be taken are `null`; `/info` itself does not fail.
