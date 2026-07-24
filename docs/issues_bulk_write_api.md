# Issues Bulk Write API

複数の Issue の作成/更新を 1 リクエストで完結させるための API。

Redmine 標準の `POST /issues.json` は以下 2 つの制約があり、大量の Issue を扱うクライアント（例: Redmine Studio のチケット表編集「一括追加」）で認証・セッション・DB 接続のオーバヘッドが N 倍になる問題があった。本 API はこれを解消する。

**制約 1**: 1 リクエストあたり 1 Issue のみ  
**制約 2**: `notes`（コメント）を送っても silent no-op で無視される（`init_journal` が呼ばれないため）

## エンドポイント

| エンドポイント | 説明 |
|---------------|------|
| `POST /issues/bulk_write.json` | 複数 Issue の作成/更新（JSON レスポンス） |
| `POST /issues/bulk_write.xml` | 同上（XML レスポンス） |

## 認証

API キー認証が必要。`before_action :require_login` により無認証時は 401 を返す（Redmine 標準 POST /issues.json の挙動に揃えている）。

各 operation の権限は Redmine 標準に従う:
- **create**: `User.current.allowed_to?(:add_issues, project, global: true)`
- **update**: 対象 Issue の Project に対して `edit_issues` 相当（`{controller: 'issues', action: 'update'}` の allowed_to?）

権限が無い operation は個別に失敗するが、他の operation は影響を受けない（Partial success）。

## リクエスト形式

### JSON

```json
{
  "operations": [
    {
      "op": "create",
      "issue": {
        "project_id": 1,
        "tracker_id": 2,
        "subject": "新規チケット",
        "description": "説明",
        "assigned_to_id": 5,
        "custom_field_values": { "3": "value1" },
        "notes": "初期コメント（任意）"
      }
    },
    {
      "op": "update",
      "id": 123,
      "issue": {
        "subject": "更新後の題名",
        "notes": "更新コメント"
      }
    }
  ]
}
```

### XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<operations type="array">
  <operation>
    <op>create</op>
    <issue>
      <project_id>1</project_id>
      <subject>新規チケット</subject>
    </issue>
  </operation>
  <operation>
    <op>update</op>
    <id>123</id>
    <issue>
      <subject>更新後の題名</subject>
      <notes>更新コメント</notes>
    </issue>
  </operation>
</operations>
```

**注意**: Rails の XML パーサーは root 要素名を top-level params キーとして使用するため、`<operations>` を root にする（`<params>` の外側ラッパーは不要）。

## リクエストパラメータ

### 共通: `operations` 配列

各要素は以下のプロパティを持つ。

| プロパティ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `op` | string | ○ | `"create"` または `"update"` |
| `id` | int | update のみ ○ | update 対象の Issue id |
| `issue` | object | ○ | Issue の属性ハッシュ |

### `issue` オブジェクト

Redmine 標準の `POST /issues.json` / `PUT /issues/:id.json` と同じ属性を受け付ける。加えて `notes` を **create でも update でも** サポートする（Redmine 標準では notes は update でのみ動作）。

| 属性 | 説明 |
|------|------|
| `project_id` | int または identifier 文字列。create の場合は必須 |
| `tracker_id` | int。省略時は allowed_target_trackers の先頭 |
| `status_id` | int。省略時は default status |
| `subject`, `description`, `priority_id`, `assigned_to_id`, `category_id`, `fixed_version_id`, `parent_issue_id`, `start_date`, `due_date`, `done_ratio`, `estimated_hours`, `is_private` | 標準 Issue 属性 |
| `custom_field_values` | ハッシュ `{ "<cf_id>": "value" }` |
| `notes` | string。create/update 共に journal（コメント履歴）として記録 |
| `assigned_to_id: "me"` | 特別扱い: 認証ユーザーの id に自動置換 |
| `<attr>: "none"` (update のみ) | Redmine 標準の `replace_none_values_with_blank` により空値にリセット |

## レスポンス形式

### JSON

```json
{
  "results": [
    {
      "index": 0,
      "op": "create",
      "success": true,
      "issue": {
        "id": 100,
        "project": { "id": 1, "name": "..." },
        "tracker": { "id": 2, "name": "..." },
        "status": { "id": 1, "name": "...", "is_closed": false },
        "priority": { "id": 4, "name": "..." },
        "author": { "id": 5, "name": "..." },
        "assigned_to": { "id": 5, "name": "..." },
        "subject": "...",
        "description": "...",
        "start_date": "2026-07-23",
        "due_date": null,
        "done_ratio": 0,
        "is_private": false,
        "estimated_hours": null,
        "total_estimated_hours": null,
        "spent_hours": 0.0,
        "total_spent_hours": 0.0,
        "custom_fields": [ { "id": 3, "name": "...", "value": "value1" } ],
        "created_on": "2026-07-23T10:00:00Z",
        "updated_on": "2026-07-23T10:00:00Z",
        "closed_on": null
      }
    },
    {
      "index": 1,
      "op": "update",
      "success": true,
      "issue": {
        "id": 123,
        "subject": "更新後の題名",
        "updated_on": "2026-07-23T10:00:01Z"
      }
    },
    {
      "index": 2,
      "op": "create",
      "success": false,
      "errors": ["Subject cannot be blank"]
    }
  ]
}
```

**注意**: update 成功時も create 成功時と同じ構造で更新後の Issue 全フィールドが返される。標準 Redmine の `PUT /issues/:id.json` は 204 No Content で body を返さないため、この点は本 API 独自の挙動（呼び出し側で更新後の状態を再取得する必要が無くなる利便性を優先）。

### レスポンスプロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `index` | int | リクエストの operations 配列内での位置 |
| `op` | string | `"create"` または `"update"` |
| `success` | bool | 成功時 true、失敗時 false |
| `issue` | object | 成功時のみ。作成/更新後の Issue の内容（Redmine 標準 `GET /issues/:id.json` と同じフィールド）。update 成功時も同じ構造で返る |
| `errors` | string[] | 失敗時のみ。エラーメッセージの配列 |

## トランザクション境界

**Partial success**: 各 operation は独立したトランザクションで実行される。1 件が失敗しても他の operation は commit される。

Redmine 標準の `bulk_update` と同じ挙動。全 rollback が必要な場合、クライアント側で失敗 operation を検知してロールバック処理を実装する。

## エラー

### リクエスト全体のエラー（422）

以下は request 全体を拒否する。ステータス 422、`{ "errors": ["<msg>"] }` を返す。

| 条件 | メッセージ |
|------|-----------|
| `operations` が配列でない | `operations must be an array` |
| `operations` が空配列 | `operations must not be empty` |

### 認証エラー（401）

- `X-Redmine-API-Key` または Basic 認証が無い / 不正な場合、Redmine 標準の 401 を返す（`before_action :require_login`）。

### 各 operation のエラー（レスポンス内 `errors`）

| 条件 | メッセージ例 |
|------|------------|
| 未知の `op` | `unknown op: "delete"` |
| create: `project_id` 無し / 不正 | `project not found or not visible` |
| create: `add_issues` 権限無し | `forbidden: add_issues permission required` |
| create: tracker が無い | `no tracker allowed for new issue in project` |
| create: default status が無い | `no default issue status` |
| update: `id` 無し | `id is required for update` |
| update: Issue が見つからない / 不可視 | `issue 12345 not found or not visible` |
| update: `edit_issues` 権限無し | `forbidden: edit_issues permission required for issue 12345` |
| update: stale object（同時編集） | `stale object: issue 12345 was modified by another user` |
| バリデーションエラー | Issue の `errors.full_messages`（例: `Subject cannot be blank`） |

## パフォーマンス

14 件の create を bulk_write で実行した実測: **約 0.8 秒**（比較: 従来の逐次 API 呼び出しで約 90 秒）

## クライアント側の使い方（redmine-net-api）

Redmine Studio では `RedmineManager.BulkWrite(operations)` メソッドから呼び出す。詳細は redmine-net-api のドキュメント参照。
