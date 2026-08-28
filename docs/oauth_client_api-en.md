# OAuth Client API

An API that returns the `client_id` and scopes required to start browser sign-in
(OAuth 2.0 + PKCE), without any authentication. Redmine Studio uses it to decide
availability at startup and to begin sign-in.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /oauth_client.json` | Get the `client_id` / `scopes` for sign-in |

## Authentication

**This API is accessible anonymously (without authentication),** regardless of the
"Authentication required" setting of Redmine itself.

Among the APIs added by the Redmine Studio plugin, this is the only one that allows
anonymous access. Before sign-in starts there is no access token yet, and the
`client_id` must be obtained in that state. The response is limited to `client_id`
and `scopes` only.

## Response formats

The API supports both JSON and XML.

| Extension | Content-Type |
|-----------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

---

## Sign-in client information

### GET /oauth_client

Returns the `client_id` of the sign-in OAuth application and the requested `scopes`.

**Registered (Redmine 6.1 or later, sign-in available):**

```json
{
  "oauth_client": {
    "client_id": "dZ_kPCxn3ilJ7HH36iV3DhLG9e2DX645xCIYGW-lHjc",
    "scopes": [
      "add_issues",
      "edit_issues",
      "view_issues",
      "view_time_entries",
      "log_time"
    ]
  }
}
```

**Not registered (e.g. Redmine older than 6.1, sign-in not available):**

```json
{"oauth_client":{}}
```

The `oauth_client` root is always returned; `client_id` / `scopes` are included only when registered.

---

## Response fields

| Field | Type | Description |
|-------|------|-------------|
| `client_id` | string | The client_id of the sign-in OAuth application |
| `scopes` | array | Requested scopes (an array of Redmine permission names) |

---

## Three response patterns

| State | Response |
|---|---|
| Sign-in available (Redmine 6.1+ and registered) | `200` `{ "oauth_client": { "client_id": "...", "scopes": [...] } }` |
| Supported plugin present but environment unsupported (older than 6.1 / not registered) | `200` `{"oauth_client":{}}` (no `client_id`) |
| Plugin not installed / old version | `404` (the API itself does not exist) |

Whether a `client_id` is returned matches whether sign-in is available.

---

## Self-healing registration of the sign-in OAuth application

The OAuth application (public client) used for sign-in is registered automatically
every time Redmine starts.

- Registers it if not yet registered (so it eventually reconciles even when the plugin
  is installed first and Redmine is upgraded to 6.1 later)
- Registers it as a public client without a secret (`confidential=false`), because such
  a client cannot be created from the Redmine admin UI
- The redirect target is loopback (`http://127.0.0.1/`); the actual port used may differ
- Scopes are defined by the policy below, and the registration follows the definition when it changes

### Scope policy

| Category | Content |
|----------|---------|
| Read | Read permissions granted broadly (destructive operations excluded) |
| Write | Only the operations the app actually uses (create/update issues and notes; create/update/delete time entries) |
| Admin | Admin permission is never included |

Because the scopes on the token and the user's own permissions are combined with AND,
information the user cannot see in Redmine remains invisible even after signing in.

---

## Token retrieval behind a front HTTP Basic gate

Browser sign-in's token retrieval (`POST /oauth/token`) is made to work even when an
HTTP Basic authentication gate (a reverse proxy in front of Redmine) is present.

To pass the front gate, the client puts the gate credentials in the `Authorization: Basic`
header. However, standard Doorkeeper interprets this header as the OAuth client's
credentials (`client_id:client_secret`), so the gate credentials fail to match any client
and token retrieval fails with `invalid_client`.

This plugin treats the `Authorization: Basic` header as client credentials only when its
username is the `client_id` (uid) of a registered OAuth application. As a result the gate
credentials are ignored, the client is identified by the `client_id` in the request body
(a public client), and token retrieval succeeds.

- No effect on the normal configuration without a front gate (unchanged when there is no Basic header)
- Legitimate client Basic authentication using a registered app's `client_id` is still honored
- No customer-side proxy configuration (such as excluding specific paths from Basic auth) is required
- On Redmine without Doorkeeper (the OAuth2 provider, i.e. before 6.1) the sign-in feature does not apply, so this patch is skipped; the plugin still loads normally
