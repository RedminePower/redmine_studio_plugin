# Server Logs API

API that returns the list of files directly under the Redmine log folder (`log`) and a given byte range of a file.

It is a general-purpose API that only reads logs and returns them. Filtering and aggregation are done by the caller. Even a log of several GB can be read to the end without large responses, by reading it in ranges one after another.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /server_logs.json` | The list of log files and the name of the file Redmine is writing now |
| `GET /server_logs/content.json` | A byte range of a file. On success, the bytes are returned as they are, not as JSON (JSON only on failure) |

Only JSON is supported (no XML).

## Permissions

Only system administrators can use this API.

| Status | When |
|--------|------|
| 401 | No API key or an invalid one (regardless of the `login_required` setting) |
| 403 | Not a system administrator |

On failure, the body is always `{"errors":["…"]}`.

```json
{ "errors": ["administrator required"] }
```

## Files that can be read

Only the files directly under the log folder that appear in the list can be read. Files outside the log folder cannot be read.

The log folder is the folder of the Rails log setting (`config.paths['log']`), resolved to its real location (if the log folder itself is a symbolic link, its target). It is decided the first time it is used after Redmine starts.

The following are not listed and cannot be read:

- Subfolders (and the files in them)
- Symbolic links
- Anything that is not a regular file (named pipes, etc.)
- Files with two or more hard links
- Files the user running Redmine cannot read (e.g. a `.gz` that logrotate created readable only by root)
- Names that are not UTF-8, that contain `/`, `\`, `:` or NUL, or that start with `.`

---

## GET /server_logs.json

The list of readable files directly under the log folder (sorted by name).

```json
{
  "server_logs": {
    "log_file": "production.log",
    "files": [
      { "name": "production.log", "size": 5368709120, "updated_on": "2026-11-21T09:12:03+09:00", "fingerprint": "4096:9f2c…e1" },
      { "name": "production.log.1", "size": 10955669504, "updated_on": "2026-11-14T03:00:01+09:00", "fingerprint": "4096:41ab…7c" },
      { "name": "production.log.2.gz", "size": 1181116006, "updated_on": "2026-11-07T03:00:02+09:00", "fingerprint": "4096:c0d3…88", "compressed": true }
    ]
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `log_file` | string / null | The name of the file the Redmine logger is writing now. `null` when the logger does not write to a file (standard output, syslog, etc.) or writes to a file outside the log folder |
| `files` | array | The list of files. Empty when the log folder does not exist or cannot be read |

### files array

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | The file name (without the folder) |
| `size` | integer | The size in bytes. For a compressed file, the compressed size |
| `updated_on` | string | When it was last written (server time, with the time zone offset) |
| `fingerprint` | string / null | The fingerprint of the file (see "Fingerprint" below). `null` when a compressed file is broken and it cannot be taken |
| `compressed` | boolean | `true` for a gzip-compressed file (the name ends with `.gz` and the file starts with the gzip header). Omitted otherwise |

### Fingerprint

The form is `number of bytes:their SHA-256 (lowercase hex)`. The bytes are the first 4096 bytes of the file (the whole file if it is smaller).

- For a compressed file, the fingerprint is taken from the decompressed start. Even if the file is compressed right after rotation, the fingerprint stays the same as the original file
- An empty file has `"0:"`

Use it to find a file whose name changed by rotation, and to check that the file was not replaced while reading.

---

## GET /server_logs/content.json

Returns the given byte range of the given file as it is (a compressed file is returned as compressed bytes).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `name` | ○ | Must exactly match a `name` in the list (case-insensitive on Windows servers) |
| `offset` | ○ | The position to start reading (bytes, an integer of 0 or more) |
| `length` | | The amount to read (bytes, an integer of 1 or more). 16 MB if omitted. It may be shortened by the limits below |
| `fingerprint` | | The fingerprint from the list (do not pass it when it was `null` in the list). When given, the fingerprint of the current file is taken again over the same number of bytes and compared. If they differ, 409 is returned. 409 is also returned when the current file is shorter than that number of bytes |

### Limits of one response

Reading stops when either of the following is reached:

- About 1 MB to send (after compression)
- 16 MB read

The response can be shorter than requested, so read the rest by moving `offset`.

### Response (success)

- Status 200. The body is the bytes of the range (`Content-Type: application/octet-stream`)
- If the request's `Accept-Encoding` contains `gzip` (not with `q=0`) and the file is not compressed, the body is gzip-compressed (`Content-Encoding: gzip`). A compressed file is not compressed again
- When `offset` is the size of the file or more, 200 with an empty body

| Header | Description |
|--------|-------------|
| `X-Server-Log-Size` | The current size of the opened file (bytes) |
| `X-Server-Log-Length` | The amount returned (bytes before compression) |
| `Cache-Control` | `no-store` (logs are not kept by proxies on the way) |

The end of the file is reached when `offset + X-Server-Log-Length >= X-Server-Log-Size` (do not judge the end only because fewer bytes than requested were returned).

### Response (failure)

| Status | When |
|--------|------|
| 401 | No API key or an invalid one |
| 403 | Not a system administrator |
| 404 | `name` is not in the list (not listed, removed, or outside the log folder). It can be told apart from the 404 of an older plugin without this API by whether the body is JSON |
| 409 | `fingerprint` differs from the current file. The header `X-Server-Log-Size` has the current size and `fingerprint` in the body has the current fingerprint |
| 422 | `name` is missing, `offset` or `length` is not an integer, is negative, or (`length`) is 0, or `fingerprint` has a wrong form (including a number of bytes over 4096) |
| 429 | Two reads are already running. The header `Retry-After: 2` (seconds). Wait that many seconds and try again |

```json
{ "errors": ["fingerprint does not match the current file"], "fingerprint": "4096:41ab…7c" }
```

### Number of concurrent reads

Up to 2 reads at the same time per server. They are counted with lock files (`redmine_studio_plugin_server_logs_read_0.lock` and `_1.lock`) in the Redmine `tmp` folder, across processes and threads. If a process dies, its lock is released.

- With several servers, up to 2 on each
- If `tmp` is on NFS, the count may not work
- If `tmp` cannot be written, reads are not counted (a warning is written to the Redmine log once)

A lock is held only while one read runs. To keep the load on the server low, callers should read one range at a time.

---

## Example

1. Get the list with `GET /server_logs.json`. Files whose names start with `log_file` are the Redmine log and its rotated files
2. Call `GET /server_logs/content.json?name=production.log.1&offset=0&fingerprint=…` with `Accept-Encoding: gzip`
3. Add `X-Server-Log-Length` to `offset` and repeat until `offset >= X-Server-Log-Size`
4. On 409, look at the list again with the current `fingerprint` in the body (the file was replaced by rotation). On 429, wait for the seconds in `Retry-After`

Requests to this API are also written to the Redmine log (their path contains `/server_logs`).

## Not provided

- Deleting or writing logs (read only)
- Logs in subfolders
- Searching or aggregating on the server
