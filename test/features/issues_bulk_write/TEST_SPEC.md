# Issues Bulk Write API テスト仕様書

## 概要

`POST /issues/bulk_write` のテスト仕様。複数の Issue の作成/更新を 1 リクエストで完結させるエンドポイント。

Redmine 本体の POST /issues.json は notes をサポートせず、また 1 リクエスト = 1 Issue のため、大量作成/更新のシナリオで認証・セッション・DB 接続のオーバヘッドが N 倍になる問題を解消するために追加された。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| Controller | `IssuesBulkWriteController` |
| ファイル | `app/controllers/issues_bulk_write_controller.rb` |
| ルーティング | `POST /issues/bulk_write` |
| View ファイル | `app/views/issues_bulk_write/create.api.rsb` |
| 認証 | API キー必須（`accept_api_auth :create`） |
| レスポンス形式 | JSON / XML 両対応 |

### リクエスト

```json
{
  "operations": [
    { "op": "create", "issue": { "project_id": 1, "tracker_id": 2, "subject": "...", "notes": "..." } },
    { "op": "update", "id": 123, "issue": { "subject": "...", "notes": "..." } }
  ]
}
```

### レスポンス (200)

```json
{
  "results": [
    { "index": 0, "op": "create", "success": true, "issue": { "id": 100, ... } },
    { "index": 1, "op": "update", "success": false, "errors": ["Subject cannot be blank"] }
  ]
}
```

### Redmine 本体との差分

| 項目 | 本体 | bulk_write |
|------|------|-----------|
| `notes` on create | silent no-op (init_journal 未呼び出し) | init_journal で明示処理、journal に載る |
| Response | 単一 issue | operations 配列に対応した results 配列 |
| Partial success | N/A (1 issue のみ) | 各 op 独立、成功/失敗を個別に返す |
| 権限チェック | `authorize` before_action | 明示的な `User.current.allowed_to?` |
| 主要処理 | 標準 `IssuesController#create/#update` | 上記を踏襲、time_entry/attachments 未サポート |

### 未サポート機能 (v1)

- `time_entry`（1 API 呼び出しで時間記録も同時作成）
- `attachments` / `uploads`
- `copy_from`（Issue コピー）
- `include=xxx` パラメータ（response の追加フィールド）

## 環境パラメータ

| パラメータ | 値 |
|-----------|-----|
| Docker コンテナ | `redmine_6.1.1_dev` |
| ポート | 3061 |
| Redmine URL | http://localhost:3061 |
| 管理者 | admin / password123 (`REDMINE_DOCKER.md` に準拠) |

## テスト前提条件

### インフラデータ（初回のみ作成）

| データ | 用途 |
|-------|------|
| プロジェクト `bulkwrite-test-project` (id: 動的取得) | テスト用プロジェクト |
| トラッカー: Redmine 標準 (`Bug`, `Feature`, `Support`) | 既存を使用 |
| カスタムフィールド `BulkWrite_CF_String` (issue, string) | Redmine 標準 CF |
| カスタムフィールド `BulkWrite_CF_List` (issue, list, values: ["A", "B", "C"]) | list 型 CF |
| ユーザー `bulkwrite_writer` (member: role=Manager) | 権限あり |
| ユーザー `bulkwrite_viewer` (member: role=Reporter, add_issues なし) | 権限なし |

セットアップは Runner スクリプトで冪等に投入する（TEST_SPEC 実行前に整備）。

## 1. Runner テスト

### [1-1] コントローラクラスの存在確認

**確認方法:**
```ruby
IssuesBulkWriteController.instance_method(:create).source_location
```

**期待結果:**
- 定義元パスが `plugins/redmine_studio_plugin/app/controllers/issues_bulk_write_controller.rb` を含む

### [1-2] ルーティングの登録確認

**確認方法:**
```ruby
Rails.application.routes.recognize_path('/issues/bulk_write', method: :post)
```

**期待結果:**
- `{controller: "issues_bulk_write", action: "create"}` が返る

### [1-3] View ファイルの存在確認

**確認方法:**
```ruby
File.exist?('/usr/src/redmine/plugins/redmine_studio_plugin/app/views/issues_bulk_write/create.api.rsb')
```

**期待結果:**
- true

## 2. HTTP テスト

### 2.A create 系

#### [2-A-1] 単一 create (最小構成)

**リクエスト:**
```http
POST /issues/bulk_write
Content-Type: application/json
Authorization: Basic (bulkwrite_writer)

{
  "operations": [
    { "op": "create", "issue": { "project_id": <project_id>, "subject": "BulkWrite_2A1_Simple" } }
  ]
}
```

**期待結果:**
- Status: 200
- `results[0].success == true`
- `results[0].op == "create"`
- `results[0].issue.id` が数値で存在
- `results[0].issue.subject == "BulkWrite_2A1_Simple"`
- `results[0].issue.tracker.id` が正常に設定されている（デフォルト tracker）
- `results[0].issue.status.id` が正常に設定されている（デフォルト status）
- `results[0].issue.author.id` が bulkwrite_writer の ID

#### [2-A-2] create with notes

**リクエスト:**
```json
{
  "operations": [
    { "op": "create", "issue": { "project_id": <project_id>, "subject": "BulkWrite_2A2_Notes", "notes": "初期コメント" } }
  ]
}
```

**期待結果:**
- Status: 200
- `results[0].success == true`
- 作成された Issue に **journal が 1 件存在**し、notes が「初期コメント」
- 検証は Runner で `Issue.find(id).journals.count == 1 && journals.first.notes == "初期コメント"`

#### [2-A-3] create with notes (空文字)

**リクエスト:**
```json
{
  "operations": [
    { "op": "create", "issue": { "project_id": <project_id>, "subject": "BulkWrite_2A3_EmptyNotes", "notes": "" } }
  ]
}
```

**期待結果:**
- Status: 200
- `results[0].success == true`
- 作成された Issue に **journal が 0 件**（空 notes は保存されない、本体の journal.rb line 105 と整合）

#### [2-A-4] create with custom fields

**リクエスト:**
```json
{
  "operations": [
    { "op": "create", "issue": {
      "project_id": <project_id>,
      "subject": "BulkWrite_2A4_CF",
      "custom_field_values": { "<cf_string_id>": "CFValue1", "<cf_list_id>": "A" }
    }}
  ]
}
```

**期待結果:**
- Status: 200
- `results[0].success == true`
- `results[0].issue.custom_fields` に 2 個のエントリが含まれる（値: "CFValue1", "A"）

#### [2-A-5] create with assigned_to_id: "me"

**リクエスト:**
```json
{
  "operations": [
    { "op": "create", "issue": { "project_id": <project_id>, "subject": "BulkWrite_2A5_Me", "assigned_to_id": "me" } }
  ]
}
```

**期待結果:**
- Status: 200
- `results[0].success == true`
- `results[0].issue.assigned_to.id == <bulkwrite_writer の user id>`（"me" → current user への変換）

#### [2-A-6] create: project_id 未指定

**リクエスト:**
```json
{ "operations": [{ "op": "create", "issue": { "subject": "No Project" } }] }
```

**期待結果:**
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "project not found or not visible" を含む

#### [2-A-7] create: 存在しない project_id

**リクエスト:**
```json
{ "operations": [{ "op": "create", "issue": { "project_id": 99999, "subject": "Ghost" } }] }
```

**期待結果:**
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "project not found or not visible" を含む

#### [2-A-8] create: 権限なし (Reporter で add_issues 不可)

**リクエスト:**
```http
Authorization: Basic (bulkwrite_viewer)  ← Reporter ロール、add_issues なし

{
  "operations": [
    { "op": "create", "issue": { "project_id": <project_id>, "subject": "BulkWrite_2A8_NoPerm" } }
  ]
}
```

**期待結果:**
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "forbidden" または "add_issues permission" を含む

#### [2-A-9] create: validation error (subject 空)

**リクエスト:**
```json
{
  "operations": [
    { "op": "create", "issue": { "project_id": <project_id>, "subject": "" } }
  ]
}
```

**期待結果:**
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "Subject" で始まるメッセージを含む（ロケール非依存: 属性名のみ確認）

### 2.B update 系

#### [2-B-1] 単一 update (subject 変更)

**セットアップ:** 既存 Issue #X (subject: "Original") を作成

**リクエスト:**
```json
{
  "operations": [
    { "op": "update", "id": <X>, "issue": { "subject": "BulkWrite_2B1_Updated" } }
  ]
}
```

**期待結果:**
- Status: 200
- `results[0].success == true`
- Issue #X の subject が "BulkWrite_2B1_Updated" に変更されている
- journal が 1 件追加され、subject の変更履歴を含む（notes は空）

#### [2-B-2] update with notes

**セットアップ:** 既存 Issue #Y

**リクエスト:**
```json
{
  "operations": [
    { "op": "update", "id": <Y>, "issue": { "notes": "コメント追加" } }
  ]
}
```

**期待結果:**
- Status: 200
- `results[0].success == true`
- Issue #Y に journal が 1 件追加され、notes が「コメント追加」

#### [2-B-3] update: id 未指定

**リクエスト:**
```json
{ "operations": [{ "op": "update", "issue": { "subject": "no id" } }] }
```

**期待結果:**
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "id is required" を含む

#### [2-B-4] update: 存在しない id

**リクエスト:**
```json
{ "operations": [{ "op": "update", "id": 99999, "issue": { "subject": "Ghost" } }] }
```

**期待結果:**
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "not found" を含む

#### [2-B-5] update: 権限なし (viewer で edit_issues 不可)

**リクエスト（viewer で）:**
```json
{ "operations": [{ "op": "update", "id": <X>, "issue": { "subject": "no perm" } }] }
```

**期待結果:**
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "forbidden" を含む

#### [2-B-6] update: replace_none_values_with_blank

**セットアップ:** Issue #Z（assigned_to 設定済）

**リクエスト:**
```json
{
  "operations": [
    { "op": "update", "id": <Z>, "issue": { "assigned_to_id": "none" } }
  ]
}
```

**期待結果:**
- Status: 200
- `results[0].success == true`
- Issue #Z の assigned_to が nil にクリアされている

### 2.C 混在

#### [2-C-1] create + update 混在

**セットアップ:** 既存 Issue #W

**リクエスト:**
```json
{
  "operations": [
    { "op": "create", "issue": { "project_id": <project_id>, "subject": "BulkWrite_2C1_New" } },
    { "op": "update", "id": <W>, "issue": { "subject": "BulkWrite_2C1_Updated" } }
  ]
}
```

**期待結果:**
- Status: 200
- `results.length == 2`
- `results[0].success == true`, `results[0].op == "create"`
- `results[1].success == true`, `results[1].op == "update"`
- 両 Issue が期待通り DB に反映

#### [2-C-2] Partial success (成功 + 失敗)

**リクエスト:**
```json
{
  "operations": [
    { "op": "create", "issue": { "project_id": <project_id>, "subject": "Good" } },
    { "op": "create", "issue": { "project_id": 99999, "subject": "Bad" } },
    { "op": "create", "issue": { "project_id": <project_id>, "subject": "Good2" } }
  ]
}
```

**期待結果:**
- Status: 200
- `results.length == 3`
- `results[0].success == true`
- `results[1].success == false`（project not found）
- `results[2].success == true`
- 成功した 2 件は DB に存在（部分成功: 失敗による全 rollback ではない）

#### [2-C-3] 14 件 create（実運用想定）

**リクエスト:** 14 件の create operations（東京エレクトロン報告と同シナリオ）

**期待結果:**
- Status: 200
- `results.length == 14`
- 全て `success == true`
- 14 件が DB に作成されている
- レスポンス時間の目安: 5 秒以内（本 API 導入の主目的の確認）

### 2.D エラー入力

#### [2-D-1] operations が空配列

**リクエスト:**
```json
{ "operations": [] }
```

**期待結果:**
- Status: 422
- レスポンスに "operations must not be empty" を含む

#### [2-D-2] operations が配列でない

**リクエスト:**
```json
{ "operations": "not an array" }
```

**期待結果:**
- Status: 422
- レスポンスに "operations must be an array" を含む

#### [2-D-3] operations 未指定

**リクエスト:**
```json
{ }
```

**期待結果:**
- Status: 422
- レスポンスに "operations must be an array" を含む

#### [2-D-4] 未知の op

**リクエスト:**
```json
{ "operations": [{ "op": "delete", "id": 1 }] }
```

**期待結果:**
- Status: 200
- `results[0].success == false`
- `results[0].errors` に "unknown op" を含む

#### [2-D-5] 認証なし

**リクエスト:** Authorization ヘッダなし + 空 operations（`{"operations":[]}`）

**期待結果:**
- Status: 401（`before_action :require_login` により認証必須）
- 標準 Redmine POST /issues.json も無認証で 401 を返すため、その挙動に揃えている

### 2.E Redmine 本体との等価性

**目的:** bulk_write で作成/更新した Issue が、標準 API (POST /issues.json / PUT /issues/:id.json) で作成/更新した Issue と同一の状態になることを保証する。

#### [2-E-1] create 等価性

**手順:**
1. **A**: 標準 API `POST /issues.json` で subject/description/tracker/status/assigned_to/priority/custom_field_values を指定して作成 → issue_A
2. **B**: bulk_write で同じパラメータで create → issue_B
3. 両 Issue を GET で取得し、比較

**比較対象フィールド:**
- subject, description, tracker_id, status_id, assigned_to_id, priority_id
- custom_field_values（各 CF の値）
- author_id, project_id
- journals（両者とも空、または本 API に notes 指定した場合は片方だけ 1 件のはず）

**期待結果:**
- notes 指定なしの場合: 全フィールド一致（journal も 0 件同士）
- notes 指定ありの場合: A は notes なし（silent no-op）、B は notes あり → 想定通りの差分

#### [2-E-2] update 等価性

**手順:**
1. 既存 Issue #P と #Q を用意（同じ内容）
2. **A**: `PUT /issues/#P.json` で subject/notes を指定して更新
3. **B**: bulk_write で `#Q` を同じパラメータで update
4. 両 Issue を GET で取得し、比較

**期待結果:**
- subject, updated_on, journals の内容（notes, details）が一致
- journal の created_on は微差あり（実行時刻）、その他の journal 内容は一致

### 2.F XML 対応

#### [2-F-1] XML リクエスト → XML レスポンス

**リクエスト:**
```http
POST /issues/bulk_write.xml
Content-Type: application/xml

<?xml version="1.0" encoding="UTF-8"?>
<operations type="array">
  <operation>
    <op>create</op>
    <issue>
      <project_id>1</project_id>
      <subject>BulkWrite_2F1_XML</subject>
    </issue>
  </operation>
</operations>
```

**注意**: Rails の XML パーサーは root 要素名を top-level params キーとして使用する。`<params>` の外側ラッパーは不要で、直接 `<operations>` を root にする。

**期待結果:**
- Status: 200
- Content-Type: `application/xml`
- XML レスポンスに `<result>` 要素が 1 個含まれ、`<success>true</success>` と `<issue>` 要素を持つ

#### [2-F-2] JSON リクエスト → XML レスポンス (Accept ヘッダで指定)

**リクエスト:**
```http
POST /issues/bulk_write.xml
Content-Type: application/json
Accept: application/xml

{ "operations": [{ "op": "create", "issue": { "project_id": 1, "subject": "..." } }] }
```

**期待結果:**
- Status: 200
- Content-Type: `application/xml`
- XML 形式のレスポンス（同一構造）

## 3. ブラウザテスト

該当なし（API 専用エンドポイントのため）。

## 網羅性チェック

| 実装ロジック | 対応テスト |
|-------------|-----------|
| operations 型チェック | [2-D-1, 2-D-2, 2-D-3] |
| unknown op | [2-D-4] |
| process_create - project 解決 | [2-A-1, 2-A-6, 2-A-7] |
| process_create - add_issues 権限 | [2-A-8] |
| process_create - init_journal with notes | [2-A-2, 2-A-3] |
| process_create - assigned_to_id: 'me' | [2-A-5] |
| process_create - safe_attributes | [2-A-1, 2-A-4] |
| process_create - tracker default | [2-A-1] |
| process_create - save + call_hook | [2-A-1] |
| process_create - validation error | [2-A-9] |
| process_update - id required | [2-B-3] |
| process_update - Issue.visible.find | [2-B-4] |
| process_update - edit_issues 権限 | [2-B-5] |
| process_update - init_journal + notes | [2-B-2] |
| process_update - assigned_to_id: 'me' | (implicit in 2-B-6 pattern) |
| process_update - replace_none_values_with_blank | [2-B-6] |
| process_update - transaction + save | [2-B-1] |
| Partial success | [2-C-2] |
| 混在シナリオ | [2-C-1] |
| 大量シナリオ (14 件) | [2-C-3] |
| 認証 | [2-D-5] |
| XML 対応 | [2-F-1, 2-F-2] |
| Redmine 本体との差分ゼロ | [2-E-1, 2-E-2] |
