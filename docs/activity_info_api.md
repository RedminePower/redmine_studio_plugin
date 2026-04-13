# Activity Info API

Redmine の活動履歴を取得する API。活動時点のチケット状態（ステータス、担当者）に復元した情報を返す。

## エンドポイント一覧

| エンドポイント | 説明 |
|---------------|------|
| `GET /activity_infos.json` | 活動履歴の取得 |

## 認証

API キー認証が必要。

## パラメータ

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `user_id` | int | ○ | 対象ユーザーの ID |
| `from` | date | ○ | 開始日（YYYY-MM-DD） |
| `to` | date | ○ | 終了日（YYYY-MM-DD、inclusive） |

## レスポンス形式

API は JSON と XML の両方をサポートする。

| 拡張子 | Content-Type |
|--------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

例:
```
GET /activity_infos.json?user_id=1&from=2026-04-07&to=2026-04-10   → JSON 形式で返却
GET /activity_infos.xml?user_id=1&from=2026-04-07&to=2026-04-10    → XML 形式で返却
```

---

## 活動履歴の取得

### GET /activity_infos

指定ユーザーの活動履歴を取得する。各活動のチケット状態は活動時点の値に復元される。

レスポンス:

```json
{
  "activity_infos": [
    {
      "activity_datetime": "2026-04-07T01:50:00Z",
      "description": "",
      "issue_id": 786,
      "journal_id": 673,
      "issue": {
        "id": 786,
        "subject": "レビュー依頼: ユーザー管理機能",
        "tracker": { "id": 5, "name": "レビュー依頼" },
        "status": { "id": 1, "name": "新規" },
        "priority": { "id": 2, "name": "通常" },
        "author": { "id": 1, "name": "Redmine Admin" },
        "project": { "id": 15, "name": "Review Test Project" },
        "parent": { "id": 785 },
        "description": "",
        "start_date": null,
        "due_date": null,
        "done_ratio": 0,
        "created_on": "2026-04-07T00:05:00Z",
        "updated_on": "2026-04-07T01:50:00Z"
      },
      "journal": {
        "id": 673,
        "user": { "id": 1, "name": "Redmine Admin" },
        "notes": "",
        "created_on": "2026-04-07T01:50:00Z",
        "private_notes": false,
        "details": [
          {
            "property": "attr",
            "name": "status_id",
            "old_value": "1",
            "new_value": "5"
          }
        ]
      },
      "ticket_tree": [
        {
          "id": 790,
          "subject": "ユーザー管理機能の実装",
          "tracker": { "id": 2, "name": "機能" },
          "status": { "id": 1, "name": "新規" },
          "..."
        },
        {
          "id": 785,
          "subject": "設計レビュー: ユーザー管理機能",
          "..."
        },
        {
          "id": 786,
          "subject": "レビュー依頼: ユーザー管理機能",
          "..."
        }
      ]
    }
  ]
}
```

---

## レスポンスフィールド

### activity_info

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `activity_datetime` | datetime | 活動時刻 |
| `description` | string | 活動の説明文（Journal → notes、Issue 作成 → description） |
| `issue_id` | int | チケット ID |
| `journal_id` | int/null | Journal ID（チケット作成時は null） |
| `issue` | object | 活動時点で復元済みのチケット情報 |
| `journal` | object/省略 | Journal 詳細（チケット作成時は省略） |
| `ticket_tree` | array | 親チケット階層（ルートから順、各チケットも活動時点の状態に復元済み） |

### issue

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `id` | int | チケット ID |
| `subject` | string | 件名 |
| `tracker` | object | トラッカー { id, name } |
| `status` | object | ステータス { id, name }（活動時点の値に復元済み） |
| `priority` | object | 優先度 { id, name } |
| `author` | object | 作成者 { id, name } |
| `assigned_to` | object/省略 | 担当者 { id, name }（活動時点の値に復元済み、null 時は省略） |
| `project` | object | プロジェクト { id, name } |
| `parent` | object/省略 | 親チケット { id }（null 時は省略） |
| `description` | string | チケットの説明文 |
| `start_date` | date/null | 開始日 |
| `due_date` | date/null | 期日 |
| `done_ratio` | int | 進捗率 |
| `created_on` | datetime | 作成日時 |
| `updated_on` | datetime | 更新日時 |

### journal

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `id` | int | Journal ID |
| `user` | object | ユーザー { id, name } |
| `notes` | string | コメント |
| `created_on` | datetime | 作成日時 |
| `private_notes` | bool | プライベートノートか |
| `details` | array | 変更詳細の配列 |

### detail

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `property` | string | プロパティ種別（"attr" など） |
| `name` | string | フィールド名（"status_id", "assigned_to_id" など） |
| `old_value` | string/null | 変更前の値 |
| `new_value` | string/null | 変更後の値 |

---

## エラーレスポンス

| ステータス | 条件 |
|-----------|------|
| 401 | API キー未指定（認証が必要な環境のみ） |
| 404 | 指定した user_id のユーザーが存在しない |
| 422 | 必須パラメータ（user_id, from, to）が未指定 |

### 422 エラー例

```json
{
  "errors": ["user_id is required"]
}
```
