# Issues With Extras API

Redmine 標準の Issue 取得 API（`GET /issues/:id`・`GET /issues`）と同じレスポンスに、Redmine Studio が表示に使う追加フィールドを含めて返す専用エンドポイント。

Redmine Studio のチケット表編集では「返答回数」「子チケット数」「最終更新者」「最新コメント」を一覧に表示する。これらは標準 API では取得できない（HTML 一覧カラムとしてしか存在しない、あるいは個別取得が必要）ため、本 API でまとめて返すことで、一覧取得 1 回で表示に必要な情報が揃うようにしている（チケットごとの追加取得＝N+1 を回避）。

標準の `IssuesController` を継承した専用コントローラで、view のみ差し替えている。**Redmine 本体の `issues/*.api.rsb` は override しない**ため、他プラグインと共存でき、標準 `/issues` エンドポイントには一切影響しない。

## エンドポイント

| エンドポイント | 説明 |
|---------------|------|
| `GET /issues_with_extras/:id.json` | 単一 Issue の取得（JSON） |
| `GET /issues_with_extras/:id.xml` | 同上（XML） |
| `GET /issues_with_extras.json` | Issue 一覧の取得（JSON） |
| `GET /issues_with_extras.xml` | 同上（XML） |

filter・pagination・`include=` などのクエリパラメータは、標準 `IssuesController` を継承しているため `/issues` と同一に動作する。

## 認証

標準 `IssuesController` と同じく `accept_api_auth :index, :show` を継承する。認証の要求条件・権限（`view_issues`）は標準 `/issues` と一致し、標準が返せる状況では本エンドポイントも返り、標準が 401 を返す状況では本エンドポイントも 401 を返す。

## 追加されるフィールド

標準 Issue レスポンスに以下の 4 フィールドを追加する。

| フィールド | 型 | 由来 | 説明 |
|-----------|-----|------|------|
| `reply_count` | object | プラグイン（Reply Count 機能） | 担当者の変更回数と遷移 |
| `children_count` | object | プラグイン（Children Count 機能） | 直下の子チケット数と一覧 |
| `last_updated_by` | object | Redmine 標準カラム | 最終更新者 |
| `last_notes` | string | Redmine 標準カラム | 最新コメント本文 |

`last_updated_by` / `last_notes` は Redmine 本体の一覧カラム（`Issue#last_updated_by` / `Issue#last_notes`、プリロード `load_visible_last_updated_by` / `load_visible_last_notes`）をそのまま利用する。標準 API のレスポンスには含まれないが、機能自体は Redmine 標準のものであり、プラグインでの再実装はしていない。

### `reply_count`

```json
"reply_count": {
  "count": 3,
  "items": [
    { "id": 2, "name": "田中 太郎" },
    { "id": 3, "name": "佐藤 花子" },
    { "id": 2, "name": "田中 太郎" },
    { "id": 0, "name": "" }
  ]
}
```

- `count`: 担当者が切り替えられた回数
- `items`: 担当者の遷移（「初期担当者 → 変更ごとの新担当者」の順、要素数 = `count` + 1）。担当者なしは `id: 0, name: ""`、削除済み等の無効ユーザーは `id: 元のID, name: ""`。変更履歴がないチケットは `count: 0`、`items` は現在の担当者 1 件
- 整形（ラベル化・省略）はクライアント側の責務

### `children_count`

```json
"children_count": {
  "count": 12,
  "items": [
    { "id": 101, "name": "子チケットの件名" }
  ]
}
```

- `count`: 直下の子チケット数（visible スコープ適用）
- `items`: 子チケットの `{ id, name=件名 }` 配列。先頭 10 件まで（`count` が 10 超でも `items` は 10 件）

### `last_updated_by`

```json
"last_updated_by": { "id": 5, "name": "田中 太郎" }
```

- 可視ジャーナルのうち最新の更新者（`{ id, name }`）
- 更新履歴が無い、または最新ジャーナルの投稿者が実在しない場合は **プロパティごと省略**する（標準 Redmine API の nullable ネストと同じ扱い）

### `last_notes`

```json
"last_notes": "最新のコメント本文"
```

- 可視の最新コメント本文
- コメントが 1 件も無い場合は空文字 `""`（単純文字列のため常に出力）

## レスポンス例（JSON, show）

標準 `GET /issues/:id.json` の全フィールドに加えて上記 4 フィールドを含む。

```json
{
  "issue": {
    "id": 1222,
    "project": { "id": 23, "name": "..." },
    "subject": "...",
    "...": "（標準フィールドは /issues/:id.json と同一）",
    "reply_count": { "count": 0, "items": [ { "id": 0, "name": "" } ] },
    "children_count": { "count": 2, "items": [ { "id": 1223, "name": "..." } ] },
    "last_updated_by": { "id": 1, "name": "Redmine Admin" },
    "last_notes": "最新のコメント本文"
  }
}
```

## レスポンス例（XML, show）

```xml
<issue>
  <id>1222</id>
  <!-- 標準フィールドは /issues/:id.xml と同一 -->
  <reply_count><count>0</count><items type="array"><item id="0" name=""/></items></reply_count>
  <children_count><count>2</count><items type="array"><item id="1223" name="..."/></items></children_count>
  <last_updated_by id="1" name="Redmine Admin"/>
  <last_notes>最新のコメント本文</last_notes>
</issue>
```

`last_updated_by` は `author` / `assigned_to` と同じ `id` / `name` 属性形式。

## 標準エンドポイントとの関係

- `issues_with_extras/*.api.rsb` は Redmine 本体の `issues/*.api.rsb` を写し取ったコピーに 4 フィールドを追加したもの。本体 view は override しないため、標準 `GET /issues` は 4 フィールドを返さない（副作用ゼロ）。
- 本体 view の更新には追従が必要（TEST_SPEC の等価性テストで差分を検知する）。

## クライアント側の使い方（redmine-net-api）

Redmine Studio では `GetIssuesWithExtrasAsync`（一覧）/ `GetIssueWithExtrasAsync`（単一）から呼び出す。詳細は redmine-net-api のドキュメント参照。
