# Studio Settings API

Redmine Studio の汎用設定を管理する API。

## エンドポイント一覧

| エンドポイント | 説明 |
|---------------|------|
| `GET /studio_settings.json` | 設定一覧の取得 |
| `GET /studio_settings/:id.json` | 設定詳細の取得 |
| `POST /studio_settings.json` | 設定の作成 |
| `POST /studio_settings/versions.json` | 版だけをまとめて取得 |
| `PUT /studio_settings/:id.json` | 設定の更新 |
| `DELETE /studio_settings/:id.json` | 設定の削除 |
| `GET /studio_settings/:id/users.json` | ユーザー割り当て一覧 |
| `PUT /studio_settings/:id/users.json` | ユーザー割り当て置換 |
| `POST /studio_settings/:id/users/:user_id.json` | ユーザー割り当て追加 |
| `DELETE /studio_settings/:id/users/:user_id.json` | ユーザー割り当て削除 |
| `GET /users/:id/studio_settings.json` | ユーザーの設定一覧 |
| `GET /studio_settings/:id/histories.json` | 履歴一覧の取得 |
| `GET /studio_settings/:id/histories/:version.json` | 履歴詳細の取得 |
| `DELETE /studio_settings/:id/histories/:version.json` | 履歴の削除 |
| `POST /studio_settings/:id/restore.json` | 履歴からの復元 |

## レスポンス形式

API は JSON と XML の両方をサポートする。

| 拡張子 | Content-Type |
|--------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

例:
```
GET /studio_settings.json   → JSON 形式で返却
GET /studio_settings.xml    → XML 形式で返却
```

---

## アクセス制御（可視性）

`scope_type` により可視性が決まる。全エンドポイントでログインが必須。`scope_type` は `global`・`project`・`user` のいずれか（それ以外の値は 422。大文字小文字も区別する）。

| scope_type | 読めるユーザー | 書けるユーザー（更新・削除・割り当て・履歴の操作） |
|-----------|---------------|-----------------------------------------------|
| `global` | 全ログインユーザー | 全ログインユーザー |
| `project` | そのプロジェクトのメンバー | そのプロジェクトのメンバー |
| `user` | 持ち主を見られるユーザー（持ち主本人を含む） | 持ち主（`scope_id` のユーザー）本人 |
| （管理者） | すべての設定（scope を問わない） | すべての設定（scope を問わない） |

- `GET /studio_settings`（一覧）は可視な設定のみを返す（`project` スコープで非メンバーのものは含まれない）。`user` スコープの設定は、持ち主を見られる（Redmine のロールの「表示できるユーザー」に従う）ユーザーだけに見え、見られない持ち主の設定は一覧に出ない（1 件取得は 403）。持ち主を見られる人は、一覧でまとめて読める。ロック中・未有効化の持ち主の設定は、管理者だけが読める（Redmine では有効なユーザーしか見られないため）。`user` スコープの payload には、他の人に見られて困る値（パスワード・トークンなど）を入れないこと。
- 個別の設定・履歴・ユーザー割り当てへの操作（取得・作成・更新・削除・復元）で、読めない・書けない設定にアクセスした場合は **403 Forbidden** を返す。
- `project` スコープの設定を作成できるのは、そのプロジェクトのメンバー（または管理者）のみ。範囲（`scope_type`、`project` ならその `scope_id`）を更新で変えられるのは管理者だけ（それ以外は 403。変えると、前の範囲の版の中身が新しい範囲の人に見えるため）。範囲を変えたいときは、新しい範囲で作り直す。`scope_id` は実在するプロジェクトの ID が必須（無い・いない ID は、管理者なら 422、管理者でなければ 403）。`global` は全ログインユーザーが作成できる。`user` スコープは下記「本人の設定（user スコープ）」を参照。
- `GET /users/:id/studio_settings` は、`:id` が自分自身か管理者の場合のみ許可（それ以外は 403）。
- ユーザーを割り当てられるのは、割り当てる人から見える（Redmine のロールの「表示できるユーザー」に従う）有効なユーザーだけ（グループ・匿名・ロック中・未承認は不可）。割り当てる人が管理者なら、有効なユーザーはだれでも割り当てられる。見えないユーザーは、いないユーザーと同じ 422 で断る。`project` スコープの設定は、そのプロジェクトのメンバーにだけ割り当てられる（それ以外は 422。管理者はどの設定も開けるので、メンバーでなくても割り当てられる）。
- 割り当ての返事・一覧（`GET /studio_settings/:id/users`、`include=assignments`、`GET /users/:id/studio_settings` など）では、見る人から見えないユーザーの `user` は `id` だけを返し、`name` を省く。

### 本人の設定（user スコープ）

ユーザーごとに 1 つずつ持つ設定。`scope_id` が持ち主のユーザー ID。

| 操作 | 振る舞い |
|------|----------|
| 作成 | `scope_id` を省くと自分の設定になる。他のユーザーの分を作れるのは管理者だけ（それ以外は 403）。持ち主は実在するユーザーであること（いなければ 422）。同じ持ち主・同じ `schema_type` の設定が既にあれば、作らずに **409 Conflict** で今ある設定を返す |
| 更新 | `expected_version` が必須（下記「版」）。`scope_type` を `user` から／へ変えることはできない（422）。`scope_id` と `schema_type` は送っても無視する（ただし形が違えば 422） |
| 削除 | 常に物理削除（`force` を問わない）。削除後は同じ `schema_type` で作り直せる |
| 履歴 | 残さない（履歴一覧は常に 0 件） |
| ユーザー割り当て | 割り当てない。置換・追加は 422 |
| 持ち主の削除 | Redmine でユーザーを削除すると、そのユーザーの本人の設定も物理削除される |

### 版（version）

すべての設定は `version` を持つ。作成時に 1 で、書き込み（更新・論理削除・復元）が成功するたびに 1 進む（中身が変わらない更新でも進む）。履歴の `version`（履歴の通し番号）とは別の値。

`PUT /studio_settings/:id` で `studio_setting` の中に `expected_version` を添えると、今の `version` と比べ、違えば書き込まずに **409 Conflict** で今の設定を返す。`user` スコープでは `expected_version` が必須、それ以外のスコープでは任意（添えなければ比べずに書き込む）。

---

## 設定

### GET /studio_settings

設定の一覧を取得。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `ids` | ID でフィルタ（カンマ区切り。例: `ids=1,2,3`） |
| `schema_type` | スキーマタイプでフィルタ |
| `scope_type` | スコープタイプでフィルタ |
| `scope_id` | スコープ ID でフィルタ |
| `include_deleted` | `1` で論理削除された設定も含める |
| `include` | `payload` で payload フィールドを含める、`assignments` で割り当てを含める（カンマ区切りで複数指定可） |
| `offset` | 取得開始位置 |
| `limit` | 取得件数（デフォルト: 25、最大: 100） |

レスポンス:

```json
{
  "studio_settings": [
    {
      "id": 1,
      "name": "設定1",
      "schema_type": "review",
      "scope_type": "global",
      "scope_id": null,
      "schema_version": 0,
      "version": 1,
      "created_on": "2026-02-19T...",
      "created_by": { "id": 1, "name": "Admin" },
      "updated_on": "2026-02-19T...",
      "updated_by": { "id": 1, "name": "Admin" },
      "deleted_on": null
    }
  ],
  "total_count": 1,
  "offset": 0,
  "limit": 25
}
```

**注意:** `created_by`, `updated_by`, `deleted_by` は nullable なネストオブジェクト。nil の場合はプロパティ自体が省略される。

---

### GET /studio_settings/:id

設定の詳細を取得。payload を常に含む。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `include` | `assignments` で割り当てを含める |

レスポンス:

```json
{
  "studio_setting": {
    "id": 1,
    "name": "設定1",
    "schema_type": "review",
    "scope_type": "global",
    "scope_id": null,
    "schema_version": 0,
    "version": 1,
    "payload": "{\"key\":\"value\"}",
    "created_on": "2026-02-19T...",
    "created_by": { "id": 1, "name": "Admin" },
    "updated_on": "2026-02-19T...",
    "updated_by": { "id": 1, "name": "Admin" },
    "deleted_on": null
  }
}
```

`include=assignments` を指定した場合:

```json
{
  "studio_setting": {
    "id": 1,
    "name": "設定1",
    "payload": "{\"key\":\"value\"}",
    "assignments": [
      {
        "id": 1,
        "setting_id": 1,
        "user": { "id": 2, "name": "John Doe" },
        "assigned_on": "2026-02-19T...",
        "assigned_by": { "id": 1, "name": "Admin" }
      }
    ]
  }
}
```

---

### POST /studio_settings

設定を作成。

リクエスト:

```json
{
  "studio_setting": {
    "name": "新規設定",
    "schema_type": "review",
    "scope_type": "global",
    "schema_version": 0,
    "payload": "{\"key\":\"value\"}"
  }
}
```

レスポンス (201 Created):

```json
{
  "studio_setting": {
    "id": 1,
    "name": "新規設定",
    "schema_type": "review",
    "scope_type": "global",
    "scope_id": null,
    "schema_version": 0,
    "version": 1,
    "payload": "{\"key\":\"value\"}",
    "created_on": "2026-02-19T...",
    "created_by": { "id": 1, "name": "Admin" },
    "updated_on": "2026-02-19T...",
    "updated_by": { "id": 1, "name": "Admin" },
    "deleted_on": null
  }
}
```

`user` スコープで、同じ持ち主・同じ `schema_type` の設定が既にある場合は 409 Conflict。本文は今ある設定（`GET /studio_settings/:id` と同じ形・payload 込み）。

---

### PUT /studio_settings/:id

設定を更新。

リクエスト:

```json
{
  "studio_setting": {
    "name": "更新後の設定名",
    "payload": "{\"updated\":true}",
    "expected_version": 3
  }
}
```

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `expected_version` | `user` スコープでは ○ | 最後に読んだ `version`。`studio_setting` の中に置く（外に置いたものは見ない）。整数でない値は 422 |

- 範囲（`scope_type`、`project` ならその `scope_id`）を変えられるのは管理者だけ（それ以外は 403）。今と同じ値を送るのは、変えたことにならない（読んだ設定を丸ごと送り返してよい）
- `expected_version` が今の `version` と違う場合は 409 Conflict。本文は今の設定（`GET /studio_settings/:id` と同じ形・payload 込み）。受け取った側は、その内容に変更を重ね直して、その `version` を添えて送り直す
- 409 の本文は他のエラー（`{ "errors": [...] }`）と形が違う。途中の中継サーバーなどで本文が読めない形に差し替わった場合は、`GET /studio_settings/:id` で取り直す

レスポンス:

```json
{
  "studio_setting": {
    "id": 1,
    "name": "更新後の設定名",
    "schema_type": "review",
    "scope_type": "global",
    "scope_id": null,
    "schema_version": 0,
    "version": 4,
    "payload": "{\"updated\":true}",
    "created_on": "2026-02-19T...",
    "created_by": { "id": 1, "name": "Admin" },
    "updated_on": "2026-02-19T...",
    "updated_by": { "id": 1, "name": "Admin" },
    "deleted_on": null
  }
}
```

---

### DELETE /studio_settings/:id

設定を削除。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `force` | `1` で物理削除（デフォルトは論理削除） |

`user` スコープの設定は、`force` を問わず物理削除。

この API を使わなくても、次のときは設定が物理削除される（論理削除したものも含む）:

- Redmine でユーザーを削除したとき: そのユーザーの `user` スコープの設定
- Redmine でプロジェクトを削除したとき: そのプロジェクトの `project` スコープの設定（子プロジェクトが一緒に消えるときは、その分も）

レスポンス: 204 No Content

---

### POST /studio_settings/versions

自分の本人の設定（`own`）と、ID で指定した設定（`ids`）の `version` だけをまとめて返す。payload は返さない。変わった設定だけを `GET /studio_settings/:id` で読み直すために使う。

リクエスト:

```json
{
  "own": ["work_settings"],
  "ids": [12, 34]
}
```

| パラメータ | 説明 |
|-----------|------|
| `own` | `schema_type` の配列。自分の `user` スコープの設定のうち、削除済みでないものを返す |
| `ids` | 設定 ID（整数）の配列。読める・削除済みでない設定を返す（スコープは問わない） |

- `own`・`ids` は配列で送る。どちらか一方だけでもよい。空の配列は 200（空の結果）
- `own` も `ids` も無い・配列でない・`ids` に整数でない値がある場合は 422
- 求めたのに返らないものは「無い（削除された・読めない）」と読んでよい
- リクエストは `studio_setting_versions` で包んでもよい（`{ "studio_setting_versions": { "own": [...], "ids": [...] } }`）。XML は一番外側の要素が 1 つ要るので包んで送り、配列には `type="array"` を付ける（無いと 422）

```xml
<studio_setting_versions>
  <own type="array"><schema_type>work_settings</schema_type></own>
  <ids type="array"><id>12</id><id>34</id></ids>
</studio_setting_versions>
```

レスポンス:

```json
{
  "studio_setting_versions": {
    "own": [
      { "id": 5, "schema_type": "work_settings", "version": 3 }
    ],
    "team": [
      { "id": 12, "version": 7 }
    ]
  }
}
```

---

## ユーザー割り当て

### GET /studio_settings/:id/users

設定に割り当てられたユーザーの一覧を取得。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `offset` | 取得開始位置 |
| `limit` | 取得件数（デフォルト: 25、最大: 100） |

レスポンス:

```json
{
  "studio_setting_assignments": [
    {
      "id": 101,
      "setting_id": 10,
      "user": { "id": 1, "name": "Admin" },
      "assigned_on": "2026-02-19T...",
      "assigned_by": { "id": 5, "name": "Manager" }
    }
  ],
  "total_count": 1,
  "offset": 0,
  "limit": 25
}
```

---

### PUT /studio_settings/:id/users

ユーザー割り当てを置換（`user_ids` に無いユーザーの割り当てを削除し、新しいユーザーの割り当てを作成）。`user_ids` に入っている、既に割り当て済みのユーザーは、そのまま残す（割り当てられる相手かを確かめ直さない。ロック中になった人などを含む今の一覧を、そのまま送り返せる）。残った割り当ての `id`・`assigned_on`・`assigned_by` は前のまま。新しいユーザーに割り当てられない人がいれば、何も変えずに 422（理由は最初に断られた 1 人分だけ返る）。`user` スコープの設定には割り当てられない（422）。

リクエスト:

```json
{
  "user_ids": [1, 2, 3]
}
```

レスポンス:

```json
{
  "studio_setting_assignments": [
    {
      "id": 101,
      "setting_id": 10,
      "user": { "id": 1, "name": "Admin" },
      "assigned_on": "2026-02-19T...",
      "assigned_by": { "id": 5, "name": "Manager" }
    },
    {
      "id": 102,
      "setting_id": 10,
      "user": { "id": 2, "name": "User2" },
      "assigned_on": "2026-02-19T...",
      "assigned_by": { "id": 5, "name": "Manager" }
    }
  ]
}
```

---

### POST /studio_settings/:id/users/:user_id

ユーザーを割り当てに追加（201）。既に割り当て済みなら、何もせず今ある割り当てを返す（200。同じ依頼がほぼ同時に届いた場合も、先に書かれた割り当てを 200 で返す）。割り当てられない相手（見えない・いない・有効でない、`project` スコープでメンバーでない）は 422。`user` スコープの設定には割り当てられない（422）。

レスポンス (201 Created):

```json
{
  "studio_setting_assignment": {
    "id": 104,
    "setting_id": 10,
    "user": { "id": 4, "name": "User4" },
    "assigned_on": "2026-02-19T...",
    "assigned_by": { "id": 5, "name": "Manager" }
  }
}
```

---

### DELETE /studio_settings/:id/users/:user_id

ユーザーの割り当てを削除。

レスポンス: 204 No Content

---

## ユーザーの設定一覧

### GET /users/:id/studio_settings

指定したユーザーに割り当てられた設定の一覧を取得。論理削除された設定と、そのユーザーが読めない設定（割り当てた後にプロジェクトから外れた・設定の範囲が変わったなど）は除外。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `offset` | 取得開始位置 |
| `limit` | 取得件数（デフォルト: 25、最大: 100） |

レスポンス:

```json
{
  "studio_setting_assignments": [
    {
      "id": 101,
      "setting_id": 10,
      "user": { "id": 1, "name": "Admin" },
      "assigned_on": "2026-02-19T...",
      "assigned_by": { "id": 5, "name": "Manager" }
    }
  ],
  "total_count": 1,
  "offset": 0,
  "limit": 25
}
```

---

## 履歴

設定の変更履歴を管理する。設定の作成・更新・削除時に自動的に履歴が作成される（`user` スコープの設定は履歴を残さない）。履歴の `version` は履歴の通し番号で、設定の `version` とは別の値。

### change_type の種類

| change_type | 説明 |
|-------------|------|
| `create` | 新規作成 |
| `update` | 更新 |
| `delete` | 論理削除 |
| `undelete` | 論理削除からの復活 |
| `restore` | 履歴からの復元 |

---

### GET /studio_settings/:id/histories

設定の履歴一覧を取得。新しい順（version DESC）でソートされる。

クエリパラメータ:

| パラメータ | 説明 |
|-----------|------|
| `include` | `payload` で payload フィールドを含める |
| `offset` | 取得開始位置 |
| `limit` | 取得件数（デフォルト: 25、最大: 100） |

レスポンス:

```json
{
  "studio_setting_histories": [
    {
      "id": 3,
      "studio_setting_id": 1,
      "version": 3,
      "name": "設定名",
      "schema_type": "review",
      "scope_type": "global",
      "scope_id": null,
      "schema_version": 1,
      "change_type": "update",
      "restored_from_version": null,
      "comment": "項目を追加",
      "is_current": true,
      "changed_on": "2026-03-04T10:00:00Z",
      "changed_by": { "id": 1, "name": "Admin" }
    },
    {
      "id": 2,
      "studio_setting_id": 1,
      "version": 2,
      "name": "設定名",
      "schema_type": "review",
      "scope_type": "global",
      "scope_id": null,
      "schema_version": 0,
      "change_type": "update",
      "restored_from_version": null,
      "comment": null,
      "is_current": false,
      "changed_on": "2026-03-03T15:00:00Z",
      "changed_by": { "id": 1, "name": "Admin" }
    }
  ],
  "total_count": 3,
  "offset": 0,
  "limit": 25
}
```

`include=payload` を指定した場合、各履歴に `payload` フィールドが追加される。

---

### GET /studio_settings/:id/histories/:version

指定したバージョンの履歴詳細を取得。payload を常に含む。

レスポンス:

```json
{
  "studio_setting_history": {
    "id": 1,
    "studio_setting_id": 1,
    "version": 1,
    "name": "設定名",
    "schema_type": "review",
    "scope_type": "global",
    "scope_id": null,
    "schema_version": 0,
    "payload": "{\"key\":\"value\"}",
    "change_type": "create",
    "restored_from_version": null,
    "comment": "初期作成",
    "is_current": false,
    "changed_on": "2026-03-01T10:00:00Z",
    "changed_by": { "id": 1, "name": "Admin" }
  }
}
```

---

### DELETE /studio_settings/:id/histories/:version

指定したバージョンの履歴を削除（物理削除）。

**制限:** `is_current = true` の履歴（最新履歴）は削除できない。

レスポンス: 204 No Content

エラーレスポンス（最新履歴を削除しようとした場合）:

```json
{ "errors": ["Cannot delete the current version"] }
```

---

### POST /studio_settings/:id/restore

指定したバージョンの履歴から設定を復元。

**復元対象:**
- `payload` と `schema_version` が復元される
- `name` は現在の値を維持（復元されない）

**change_type の判定:**
- 設定が論理削除状態の場合: `undelete`
- それ以外の場合: `restore`

リクエスト:

```json
{
  "version": 1,
  "comment": "v1 に復元"
}
```

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `version` | ○ | 復元元のバージョン番号 |
| `comment` | - | 変更コメント |

レスポンス:

```json
{
  "studio_setting": {
    "id": 1,
    "name": "設定名",
    "schema_type": "review",
    "scope_type": "global",
    "scope_id": null,
    "schema_version": 0,
    "version": 5,
    "payload": "{\"key\":\"value\"}",
    "created_on": "2026-03-01T10:00:00Z",
    "created_by": { "id": 1, "name": "Admin" },
    "updated_on": "2026-03-04T12:00:00Z",
    "updated_by": { "id": 1, "name": "Admin" },
    "deleted_on": null
  }
}
```

エラーレスポンス（最新バージョンに復元しようとした場合）:

```json
{ "errors": ["Cannot restore to the current version"] }
```

---

## エラーレスポンス

### 403 Forbidden

権限のないスコープの設定にアクセスした場合に返す。以下の場合に 403 が返される:

- `project` スコープの設定を、そのプロジェクトの非メンバーが取得・作成・更新・削除・復元・ユーザー割り当て操作した
- 管理者でない人が、更新で設定の範囲を変えようとした（`scope_type` を変える、`project` の設定をほかのプロジェクトへ付け替える）
- `user` スコープの設定を、持ち主以外かつ非管理者が更新・削除・復元・ユーザー割り当て操作した、または他のユーザーの分を作成しようとした
- `GET /users/:id/studio_settings` を、自分以外かつ非管理者が要求した

### 404 Not Found

標準的な HTTP 404 ステータスを返す（レスポンスボディなし）。

以下の場合に 404 が返される:
- 指定された設定が存在しない
- 指定されたユーザーが存在しない
- 指定された割り当てが存在しない
- 指定されたバージョンの履歴が存在しない

### 409 Conflict

本文は `{ "errors": [...] }` ではなく、今の設定（`GET /studio_settings/:id` と同じ形・payload 込み）。以下の場合に返される:

- `POST /studio_settings` で、同じ持ち主・同じ `schema_type` の `user` スコープの設定が既にある
- `PUT /studio_settings/:id` で、`expected_version` が今の `version` と違う

### 422 Unprocessable Entity

```json
{ "errors": ["Name cannot be blank", "Schema type cannot be blank", "Scope type cannot be blank"] }
```

```json
{ "errors": ["User does not exist: 99999"] }
```

```json
{ "errors": ["user_ids must be an array"] }
```

送った値の形と長さに関するもの（作成・更新・削除・復元）。形の誤りは、あればすべて並べて返す。長さと、プロジェクト・ユーザーの実在は、形が正しいときに確かめて返す:

| メッセージ | 発生する場合 |
|-----------|-------------|
| `studio_setting is required` | 作成・更新で `studio_setting` が無い・空 |
| `studio_setting must be an object` | `studio_setting` が項目をまとめたもの（JSON のオブジェクト、子要素を持つ XML の要素）でない（文字列・配列など） |
| `name must be a string`（`schema_type`・`scope_type`・`payload` も同じ） | その項目が文字列でない。`payload` は JSON を文字列にして送る（オブジェクトのままは不可） |
| `scope_id must be an integer`（`schema_version` も同じ） | その項目が整数として読めない、または -2147483648〜2147483647 の外 |
| `version must be an integer` | 復元で `version` が無い・整数として読めない |
| `comment must be a string` | `comment` が文字列でない（`comment` を使わない削除〔`force=1`・`user` スコープ〕でも確かめる） |
| `comment is too long (maximum is 255 characters)` | `comment` が 255 文字を超える |
| `Name is too long (maximum is 255 characters)`（`Schema type` も同じ） | `name`・`schema_type` が 255 文字を超える |
| `Scope cannot be blank` | `project` スコープの作成・管理者の付け替えで `scope_id` が無い（作成で管理者でなければ 403） |
| `Scope must be an existing project` | `project` スコープの作成・管理者の付け替えで、`scope_id` のプロジェクトが無い（作成で管理者でなければ 403） |
| `Scope must be an existing user` | `user` スコープで、`scope_id` のユーザーが無い（グループ・匿名も不可） |

`Name is too long …` など、モデルの検証で出るメッセージ（項目名で始まるもの）は、利用者の言語で返る（例: 日本語なら「名称 は255文字以内で入力してください」）。ほかのメッセージは英語のまま。

ユーザー割り当てに関するもの（`User …` はモデルの検証のメッセージなので、利用者の言語で返る。例: 日本語なら「ユーザー には実在するユーザーを指定してください: 5」）:

| メッセージ | 発生する場合 |
|-----------|-------------|
| `user_ids must be an array` | 置換で `user_ids` が配列でない |
| `User does not exist: <ID>` | 割り当てる相手が、いない・割り当てる人から見えない・有効でない（グループ・匿名・ロック中・未承認） |
| `User is not a member of the project: <ID>` | `project` スコープの設定に、そのプロジェクトのメンバーでない人を割り当てようとした |
| `User has already been taken` | 置換で、同じユーザーを 2 回送った |

本人の設定と版に関するもの:

| メッセージ | 発生する場合 |
|-----------|-------------|
| `expected_version is required` | `user` スコープの更新で `expected_version` が無い |
| `expected_version must be an integer` | `expected_version` が整数として読めない |
| `scope_type cannot be changed to or from user` | `scope_type` を `user` から／へ変えようとした |
| `A user setting cannot be assigned to users` | `user` スコープの設定にユーザーを割り当てようとした |
| `own or ids is required` | `POST /studio_settings/versions` に `own` も `ids` も無い |
| `own must be an array of schema_type` | `own` が文字列の配列でない |
| `ids must be an array of integers` | `ids` が整数の配列でない |
