# Cache Bundle API

Redmine Studio（Windows クライアント）のキャッシュ更新を 1 リクエストで完結させるためのバンドル取得 API。
複数の Redmine リソース（Projects / Trackers / Users / per-project Memberships など）を一括で取得して返す。

## エンドポイント一覧

| エンドポイント | 説明 |
|---------------|------|
| `GET /cache_bundle.json` | キャッシュバンドルの取得 |

## 権限

リクエスト時に使用する API キーの権限により、`users` / `custom_fields` / `groups` の 3 セクションに含まれる範囲が変わる:

- **admin 権限あり**: すべてのユーザ・カスタムフィールド・グループを返す
- **admin 権限なし**: その利用者が Redmine 上で見られる範囲だけを返す（Redmine の画面で見えるのと同じ範囲。見えるものが無ければ空になる）

管理者 API キーを持たない利用者でも、自分の権限の範囲でキャッシュを作れるようにするための挙動。

## パラメータ

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `user_id` | int | × | スコープ解決対象ユーザの ID。省略時は API キーのユーザ自身（`User.current`）。<br>非 admin ユーザは自分以外の `user_id` を指定できない |

`user_id` は per-project セクション（`project_memberships` / `project_versions` / `project_issue_categories`）の対象プロジェクト ID 集合をサーバ側で解決するために使う。
master API キーで叩く運用では、対象アプリ利用者の `user_id` を明示する必要がある（`User.current` が master ユーザになるため）。

## レスポンス形式

JSON のみサポート。XML はサポートしない（バンドル内の `project_memberships` などの Dict 形式が XML の標準パターンに馴染まないため）。

`Accept-Encoding: gzip` がリクエストヘッダに含まれていればレスポンスは gzip 圧縮して返す（`Content-Encoding: gzip`）。Apache の `mod_deflate` 設定に依存しない。

### レスポンス概形

```json
{
  "cache_bundle": {
    "markup_lang": "textile",
    "projects":                 [ ... ],
    "trackers":                 [ ... ],
    "issue_statuses":           [ ... ],
    "issue_priorities":         [ ... ],
    "time_entry_activities":    [ ... ],
    "queries":                  [ ... ],
    "custom_fields":            [ ... ],
    "users":                    [ ... ],
    "roles":                    [ ... ],
    "groups":                   [ ... ],
    "project_memberships":      { "207": [...], "208": [...] },
    "project_versions":         { "207": [...], "208": [...] },
    "project_issue_categories": { "207": [...] },
    "errors":                   [ ... ]
  }
}
```

ルートは固定で `cache_bundle` のキー 1 つだけ。各セクションの中身は Redmine 標準 API の対応リソースとほぼ同じフォーマット。

## 各セクションの仕様

| セクション | 中身 | 補足 |
|---|---|---|
| `markup_lang` | string | `Setting.text_formatting` の値（`textile` / `common_mark` 等） |
| `projects` | Project の配列 | 対象ユーザが Redmine 上で見られるプロジェクトのみ（アーカイブ済みは含まない。個別 projects API と同じ範囲）。各プロジェクトに `trackers` / `enabled_modules` / `issue_categories` / `time_entry_activities` / `issue_custom_fields` を含み、内容は個別 projects API の include と揃える（トラッカーは対象ユーザがチケットを見られるもの、作業分類はアクティブなもの、カスタムフィールドは全プロジェクト共通のものも含む）。Redmine 7.0 以降は個別 projects API がこれらの include を権限でゲートするため揃える（`issue_categories` / `issue_custom_fields` は **`view_issues`** 権限、`time_entry_activities` は **`view_time_entries`** 権限＝time_tracking モジュール有効かつ権限。権限が無いプロジェクトは空配列。6.1 以前はゲートが無く常に返す）。`parent`（親プロジェクト）は対象ユーザに**見える親のみ**出力する（見えない非公開の親の名前を漏らさない） |
| `trackers` | Tracker の配列 | `default_status` 含む |
| `issue_statuses` | IssueStatus の配列 | `is_closed` 含む |
| `issue_priorities` | IssuePriority の配列 | inactive 含む全件（個別 enumerations API と同じ）。`active` / `is_default` 含む |
| `time_entry_activities` | TimeEntryActivity の配列 | inactive 含む全件（個別 enumerations API と同じ）。`active` / `is_default` 含む |
| `queries` | Query の配列 | caller の可視範囲。`is_public` は visibility が public のクエリのみ true（本体 queries API と同じ） |
| `custom_fields` | CustomField の配列 | admin は全件、非 admin は本人が見られるカスタムフィールドのみ（全員に公開されているもの＋本人のロールに割り当てられたもの）。`min_length` / `max_length` は未設定なら null（本体 custom_fields API と同じ）。`possible_values` は `{value, label}` のペア |
| `users` | User の配列 | admin は全 active ユーザ、非 admin は本人が見られるユーザのみ（本人＋同じプロジェクトのメンバー。ロール設定によっては全 active ユーザ）。匿名ユーザは除外。`status` は個別 API (GET /users.json) が一覧に含める **Redmine 6.1 以降**でのみ出力する（6.1 未満の一覧 API は status を返さないため揃える） |
| `roles` | Role の配列 | givable（builtin=0）のみ。ビルトインロール（Non member / Anonymous）は含まない（個別 API `GET /roles.json` と同じ）。各 Role の `permissions` を文字列配列で含む（本体 roles/:id API と同じ形式。リスト取得 + 詳細取得の N+1 をサーバ側で吸収） |
| `groups` | Group の配列 | admin は全グループ、非 admin は本人が見られるグループのみ。通常のグループ（type='Group'）のみでビルトイングループ（Anonymous / Non member）は含まない（個別 API `GET /groups.json` と同じ）。各 Group の `users` を含む（非 admin では、本人が見られるユーザだけに絞る） |
| `project_memberships` | `{ project_id => [Membership...] }` | 対象ユーザが member となっているプロジェクトについて取得。ロックユーザの membership は除外 |
| `project_versions` | `{ project_id => [Version...] }` | 対象ユーザが member となっているプロジェクト。さらに対象ユーザが **`view_issues` 権限**を持つプロジェクトのみ版を返す（個別 API `GET /projects/:id/versions.json` と同じゲート。権限が無いプロジェクトは空配列）。各 Version は対象ユーザに可視な **カスタムフィールド値**（`custom_fields`）を含む（個別 API の `render_api_custom_values` と同じ。単一値はスカラー、複数値は配列＋`multiple`） |
| `project_issue_categories` | `{ project_id => [IssueCategory...] }` | 対象ユーザが member となっている **Active** プロジェクトのみ。さらに対象ユーザが **`manage_categories` 権限**を持つプロジェクトのみカテゴリを返す（個別 API `GET /projects/:id/issue_categories.json` と同じゲート。権限が無いプロジェクトは空配列） |
| `errors` | `{ section, code, message }` の配列 | 部分失敗のメタデータ。空配列なら全成功 |

### 各セクションが返すフィールド

各セクションのオブジェクトが返す主なフィールドは以下の通り（詳細は上の「各セクションの仕様」を参照）。

- Redmine 標準 API の対応リソースを基本としつつ、用途に合わせて一部の項目を調整している。
- 値が無い項目は省略される場合がある。
- ユーザーのロールや権限により、一部のセクションやフィールドが本人の見える範囲に絞られる。
  - 例: `projects` の `parent`、`groups` の `users`、`project_versions` の `custom_fields`

| セクション | 返すフィールド |
|---|---|
| `projects` | `id` / `name` / `identifier` / `description` / `homepage` / `status` / `is_public` / `inherit_members` / `created_on` / `updated_on` / `trackers[]` / `enabled_modules[]` / `issue_categories[]` / `time_entry_activities[]` / `issue_custom_fields[]` / `parent` |
| `trackers` | `id` / `name` / `default_status` / `description` |
| `issue_statuses` | `id` / `name` / `is_closed` |
| `issue_priorities` | `id` / `name` / `active` / `is_default` |
| `time_entry_activities` | `id` / `name` / `active` / `is_default` |
| `queries` | `id` / `name` / `is_public` / `project_id` |
| `custom_fields` | `id` / `name` / `customized_type` / `field_format` / `regexp` / `min_length` / `max_length` / `is_required` / `is_filter` / `searchable` / `multiple` / `default_value` / `visible` / `possible_values[]` / `trackers[]` / `roles[]` |
| `users` | `id` / `login` / `firstname` / `lastname` / `mail` / `created_on` / `updated_on` / `last_login_on` / `passwd_changed_on` / `status`（Redmine 6.1 以降のみ） / `admin` / `twofa_scheme` |
| `roles` | `id` / `name` / `assignable` / `issues_visibility` / `time_entries_visibility` / `users_visibility` / `permissions[]` |
| `groups` | `id` / `name` / `users[]`（各 `id` / `name`） |
| `project_memberships` の各要素 | `id` / `project` / `roles[]`（`inherited` 含む）/ `user` または `group` |
| `project_versions` の各要素 | `id` / `project` / `name` / `description` / `status` / `sharing` / `created_on` / `updated_on` / `due_date` / `wiki_page_title` / `custom_fields[]` |
| `project_issue_categories` の各要素 | `id` / `project` / `name` / `assigned_to` |

### 並び順

各配列は個別に取得した場合と**同じ並び順**で返す（cache_bundle は個別 API で取得した場合と同一の内容・並び順になるよう揃えている）。

## 部分失敗時の挙動

セクション単位で例外を catch し、そのセクションを空配列で埋めつつ `errors` 配列にエントリを追加する。HTTP ステータスは常に 200 を返す（クライアント側でフォールバックして N+1 個別 API 取得に戻ってしまうのを避けるため）。

例:
```json
{
  "cache_bundle": {
    "projects": [...],
    "project_memberships": {
      "207": [],
      "208": []
    },
    "errors": [
      { "section": "project_memberships", "code": 500, "message": "ActiveRecord::StatementInvalid: ..." }
    ]
  }
}
```

致命的エラー（HTTP 500 など、リクエストそのものが失敗した場合）はクライアント側で個別 API フローへフォールバックする想定。
