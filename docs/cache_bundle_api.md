# Cache Bundle API

Redmine Studio（Windows クライアント）のキャッシュ更新を 1 リクエストで完結させるためのバンドル取得 API。
複数の Redmine リソース（Projects / Trackers / Users / per-project Memberships など）を一括で取得して返す。

## エンドポイント一覧

| エンドポイント | 説明 |
|---------------|------|
| `GET /cache_bundle.json` | キャッシュバンドルの取得 |

## 認証

API キー認証が必要。

リクエスト時に使用する API キーの権限により、レスポンスに含まれる内容が変わる:

- **admin 権限あり**: `users` / `custom_fields` / `groups` を含むフルレスポンス
- **admin 権限なし**: 上記 3 セクションは空配列で返る（その他は通常通り）

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
| `projects` | Project の配列 | 対象ユーザが可視できるプロジェクトのみ（`Project.visible` 相当。`Archived` は含まない。個別 projects API と同じスコープ）。`trackers` / `enabled_modules` / `issue_categories` / `time_entry_activities` / `issue_custom_fields` を含む |
| `trackers` | Tracker の配列 | `default_status` 含む |
| `issue_statuses` | IssueStatus の配列 | `is_closed` 含む |
| `issue_priorities` | IssuePriority の配列 | inactive 含む全件（個別 enumerations API と同じ）。`active` / `is_default` 含む |
| `time_entry_activities` | TimeEntryActivity の配列 | inactive 含む全件（個別 enumerations API と同じ）。`active` / `is_default` 含む |
| `queries` | Query の配列 | caller の可視範囲。`is_public` は visibility が public のクエリのみ true（本体 queries API と同じ） |
| `custom_fields` | CustomField の配列 | **admin 権限が必要**。権限がない場合は空配列。`min_length` / `max_length` は未設定なら null（本体 custom_fields API と同じ）。`possible_values` は `{value, label}` のペア |
| `users` | User の配列 | **admin 権限が必要**。active なユーザのみ（個別 users API の既定挙動と同じ） |
| `roles` | Role の配列 | givable（builtin=0）のみ。ビルトインロール（Non member / Anonymous）は含まない（個別 API `GET /roles.json` と同じ・#2779）。各 Role の `permissions` を文字列配列で含む（本体 roles/:id API と同じ形式。リスト取得 + 詳細取得の N+1 をサーバ側で吸収） |
| `groups` | Group の配列 | **admin 権限が必要**。givable（type='Group'）のみ。ビルトイングループ（Anonymous / Non member）は含まない（個別 API `GET /groups.json` と同じ・#2779）。各 Group の `users` を含む |
| `project_memberships` | `{ project_id => [Membership...] }` | 対象ユーザが member となっているプロジェクトについて取得。ロックユーザの membership は除外 |
| `project_versions` | `{ project_id => [Version...] }` | 対象ユーザが member となっているプロジェクト。さらに対象ユーザが **`view_issues` 権限**を持つプロジェクトのみ版を返す（個別 API `GET /projects/:id/versions.json` と同じゲート。権限が無いプロジェクトは空配列・#2779） |
| `project_issue_categories` | `{ project_id => [IssueCategory...] }` | 対象ユーザが member となっている **Active** プロジェクトのみ。さらに対象ユーザが **`manage_categories` 権限**を持つプロジェクトのみカテゴリを返す（個別 API `GET /projects/:id/issue_categories.json` と同じゲート。権限が無いプロジェクトは空配列） |
| `errors` | `{ section, project_id?, code, message }` の配列 | 部分失敗のメタデータ。空配列なら全成功 |

## 部分失敗時の挙動

セクション単位 / プロジェクト単位で例外を catch し、空配列で埋めつつ `errors` 配列にエントリを追加する。HTTP ステータスは常に 200 を返す（クライアント側でフォールバックして N+1 個別 API 取得に戻ってしまうのを避けるため）。

例:
```json
{
  "cache_bundle": {
    "projects": [...],
    "project_memberships": {
      "207": [...],
      "208": []
    },
    "errors": [
      { "section": "project_memberships", "project_id": 208, "code": 500, "message": "ActiveRecord::StatementInvalid: ..." }
    ]
  }
}
```

致命的エラー（HTTP 500 など、リクエストそのものが失敗した場合）はクライアント側で個別 API フローへフォールバックする想定。

## バージョン

このエンドポイントは redmine_studio_plugin **1.6.0** で追加された。Redmine Studio 側は `redmine_studio_plugin >= 1.6.0` であることを `Plugin API` で確認してから本エンドポイントを呼び出す。

## クライアント側の使用例

Redmine Studio の C# クライアント（redmine-net-api）から呼び出すコード例:

```csharp
var prm = new NameValueCollection { { RedmineKeys.USER_ID, "42" } };
var bundle = await masterServiceAsync.GetCacheBundleAsync(prm);
```

`GetCacheBundleAsync` の戻り値の `CacheBundle` インスタンスを `CacheService.applyCacheBundle()` で `Data.*` に流し込む。
