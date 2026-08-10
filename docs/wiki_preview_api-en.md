# Wiki Preview API

An API that converts Wiki-formatted text to HTML. It performs the same rendering as Redmine's built-in preview screen and can be used with API key authentication alone.

The conventional approach of automatically logging into the browser with WebView2 to render a preview fails for users who have enabled two-factor authentication (2FA). This API provides preview rendering without any browser login.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `POST /wiki_preview.json` | Convert Wiki text to HTML |

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `text` | string | Yes | The Wiki-formatted text to convert (an empty string is allowed and returns an empty string) |
| `project_id` | int | | Project context. Used to resolve macros, `#123` issue links, and `[[Wiki page]]` links. When omitted, rendering is performed without project-dependent context |

## Rendering

Uses the same `textilizable` helper as Redmine's built-in preview screen. Following the Redmine setting (Textile / Markdown / CommonMark), it expands all of the following:

- Basic markup such as headings, lists, tables, and text decoration
- Macros (`{{toc}}`, `{{collapse}}`, plugin-provided macros, etc.)
- Issue links in the `#123` form
- Wiki links in the `[[Wiki page]]` form

As with Redmine's built-in preview, links are output as relative paths (e.g. `/issues/123`).

## Response Formats

The API supports both JSON and XML.

| Extension | Content-Type |
|-----------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

Example:
```
POST /wiki_preview.json   → returns JSON
POST /wiki_preview.xml    → returns XML
```

---

## Convert Wiki Text to HTML

### POST /wiki_preview

Converts Wiki-formatted text to HTML.

Request:

```json
{
  "text": "h1. Heading\n\n* Item 1\n* Item 2\n\nRelated: #123",
  "project_id": 1
}
```

Response:

```json
{
  "wiki_preview": {
    "html": "<h1>Heading</h1>\n\n<ul>\n<li>Item 1</li>\n<li>Item 2</li>\n</ul>\n\n<p>Related: <a class=\"issue\" href=\"/issues/123\">#123</a></p>",
    "stylesheets": ["/assets/application-33e739e5.css"]
  }
}
```

---

## Response Fields

### wiki_preview

| Field | Type | Description |
|-------|------|-------------|
| `html` | string | The converted HTML |
| `stylesheets` | string[] | URLs (relative paths) of the stylesheets used to display the HTML. Digested asset paths and the current UI theme are already resolved |

### Details on stylesheets

- Follows the same resolution rule as Redmine's own layout: when a theme that provides `application.css` is configured, the theme's URL is returned; otherwise the core `application.css` URL is returned
- Stylesheets are served as static files without authentication, so clients can reference the returned URLs directly with `<link rel="stylesheet">` (no API key or login required)
- URLs are returned as host-relative paths. Resolve them against the Redmine URL on the client side (they can be embedded as-is when using `<base href>`)

---

## Error Responses

| Status | Condition |
|--------|-----------|
| 401 | Not authenticated (login required) |
| 404 | The specified `project_id` does not exist or is not visible |
| 422 | The required parameter `text` is not specified |

### 422 error example

```json
{
  "errors": ["text is required"]
}
```
