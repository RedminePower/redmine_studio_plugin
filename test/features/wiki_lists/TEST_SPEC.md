# Wiki Lists テスト仕様書

## 概要

redmine_studio_plugin の Wiki Lists 機能のテスト仕様。

本機能は以下の3つのWikiマクロを提供する:

| マクロ | 機能 |
|--------|------|
| `{{wiki_list}}` | Wikiページ一覧を表形式で表示 |
| `{{issue_name_link}}` | チケット題名でリンクを作成 |
| `{{ref_issues}}` | 条件に合うチケット一覧を表示 |

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| wiki_list 実装 | `lib/redmine_studio_plugin/wiki_lists/wiki_list.rb` |
| issue_name_link 実装 | `lib/redmine_studio_plugin/wiki_lists/issue_name_link.rb` |
| ref_issues 実装 | `lib/redmine_studio_plugin/wiki_lists/ref_issues.rb` |
| ref_issues パーサー | `lib/redmine_studio_plugin/wiki_lists/ref_issues/parser.rb` |
| マクロ登録 | `Redmine::WikiFormatting::Macros.register` |

---

## テスト実行フロー

### フェーズ 0: Runner テストの流し方

Puma は止めずに、動かしたまま Runner テストを流す。公式 Docker イメージでは Puma がコンテナの PID 1 なので、止めるとコンテナごと止まり、`docker exec` が使えなくなる。

各バッチの Ruby スクリプトはファイルにしてコンテナにコピーし、`redmine` 利用者で実行する。`bash -c "... rails runner '...'"` の形でコードを直接渡すと、`!` や引用符の扱いで壊れやすい。

```bash
docker cp batch1.rb {Container}:/tmp/wiki_lists_batch1.rb
docker exec -u redmine -w /usr/src/redmine {Container} bundle exec rails runner /tmp/wiki_lists_batch1.rb
```

- `bash` のブロックは bash で流す（Windows では Git Bash で、`MSYS_NO_PATHCONV=1` を付ける。付けないと `/usr/src/redmine` や `/tmp/...` が Windows のパスに書き換わる）
- `-u redmine` を付けずに root で動かすと、ログや `files` の中に root の持ち物のファイルができ、あとで Redmine から書けなくなることがある。root が要る手順だけ `-u` を付けずに行う
- `SQLite3::BusyException`（database is locked）が出たときは、少し待ってそのバッチを流し直す

### フェーズ 1: Runner テスト

バッチ 1: [1-1] 〜 [1-7] を1つのスクリプトにまとめて実行

### フェーズ 2: HTTP テスト

各マクロのオプション動作を確認する。コンテナの再起動は要らない（Runner テストは DB を書き換えない）。

[5-V-1] は、試験用のプロジェクト・利用者を作って最後に消す（ほかの HTTP テストのデータには触らない）。

---

## セットアップデータ

### プロジェクト

| 識別子 | 名前 |
|--------|------|
| wiki-list-test | Wiki List Test |

### ユーザー

| ログインID | 名前 | パスワード |
|-----------|------|-----------|
| wikilistuser | Wiki List User | password123 |

### トラッカー

既存のトラッカーを使用（バグ、機能など）

### Wikiページ

| ページ名 | 親ページ | 内容 |
|---------|---------|------|
| WikiListTest | - | `担当: 山田太郎`<br>`期間: 2024/01/01`<br>`〜 2024/12/31` |
| WikiListChild1 | WikiListTest | `担当: 佐藤花子`<br>`ステータス: 進行中` |
| WikiListChild2 | WikiListTest | `担当: 鈴木一郎`<br>`ステータス: 完了` |

リダイレクト: `WLT` → `WikiListTest`

### チケット

| 題名 | トラッカー | 担当者 | ステータス |
|------|-----------|--------|-----------|
| IssueNameLinkTest | バグ | admin | 新規 |
| RefIssuesTest1 | バグ | admin | 新規 |
| RefIssuesTest2 | バグ | wikilistuser | 進行中 |
| RefIssuesTest3 | 機能 | admin | 終了 |

### カスタムクエリ

| 名前 | 公開 | 条件 |
|------|------|------|
| WikiListTestQuery | はい | status_id = 1 (新規) |

---

## 1. Runner テスト

### [1-1] プラグイン登録確認

**確認方法:**
```ruby
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
raise "FAIL" unless plugin
puts "[1-1] PASS"
```

**期待結果:** プラグインが登録されている

### [1-2] wiki_list マクロ登録確認

**確認方法:**
```ruby
macro = Redmine::WikiFormatting::Macros.available_macros[:wiki_list]
raise "FAIL" unless macro
puts "[1-2] PASS"
```

**期待結果:** マクロが登録されている

### [1-3] issue_name_link マクロ登録確認

**確認方法:**
```ruby
macro = Redmine::WikiFormatting::Macros.available_macros[:issue_name_link]
raise "FAIL" unless macro
puts "[1-3] PASS"
```

**期待結果:** マクロが登録されている

### [1-4] ref_issues マクロ登録確認

**確認方法:**
```ruby
macro = Redmine::WikiFormatting::Macros.available_macros[:ref_issues]
raise "FAIL" unless macro
puts "[1-4] PASS"
```

**期待結果:** マクロが登録されている

### [1-5] モジュール存在確認

**確認方法:**
```ruby
raise "FAIL" unless defined?(RedmineStudioPlugin::WikiLists::WikiList)
raise "FAIL" unless defined?(RedmineStudioPlugin::WikiLists::IssueNameLink)
raise "FAIL" unless defined?(RedmineStudioPlugin::WikiLists::RefIssues)
raise "FAIL" unless defined?(RedmineStudioPlugin::WikiLists::RefIssues::Parser)
puts "[1-5] PASS"
```

**期待結果:** 全モジュールが定義されている

### [1-6] ref_issues デフォルト表示件数確認

**確認方法:**
```ruby
raise "FAIL" unless RedmineStudioPlugin::WikiLists::RefIssues::Parser::DEFAULT_DISPLAY_LIMIT == 100
puts "[1-6] PASS"
```

**期待結果:** デフォルト表示件数が100

### [1-7] ref_issues 最大表示件数確認

**確認方法:**
```ruby
raise "FAIL" unless RedmineStudioPlugin::WikiLists::RefIssues::Parser::MAX_DISPLAY_LIMIT == 1000
puts "[1-7] PASS"
```

**期待結果:** 最大表示件数が1000

---

## 2. HTTP テスト - wiki_list

### [2-W-1] +title カラム

**マクロ:** `{{wiki_list(-p, +title)}}`

**確認方法:** Wikiページを取得し、テーブルにページタイトルのリンクが含まれることを確認

**期待結果:** ページタイトルがリンクとして表示される

### [2-W-2] +alias カラム

**マクロ:** `{{wiki_list(-p, +title, +alias)}}`

**期待結果:** 別名（WLT）が表示される

### [2-W-3] +project カラム

**マクロ:** `{{wiki_list(-p, +title, +project)}}`

**期待結果:** プロジェクト名が表示される

### [2-W-4] -c オプション（子ページのみ）

**マクロ:** WikiListTest ページで `{{wiki_list(-c, +title)}}`

**期待結果:** WikiListChild1, WikiListChild2 のみ表示（WikiListTest は除外）

### [2-W-5] -p オプション（現在のプロジェクト）

**マクロ:** `{{wiki_list(-p, +title)}}`

**期待結果:** 現在のプロジェクトのWikiページのみ表示

### [2-W-6] -p=PROJECT オプション

**マクロ:** `{{wiki_list(-p=wiki-list-test, +title)}}`

**期待結果:** 指定プロジェクトのWikiページのみ表示

### [2-W-7] -w=WIDTH オプション

**マクロ:** `{{wiki_list(-p, -w=80%, +title)}}`

**期待結果:** `<table width="80%">` が出力される

### [2-W-8] キーワード抽出（行末まで）

**マクロ:** `{{wiki_list(-p, +title, 担当:)}}`

**期待結果:** 「担当:」の後のテキストが表示される

### [2-W-9] キーワード抽出（終端文字まで）

**マクロ:** `{{wiki_list(-p, +title, 期間:\〜)}}`

**期待結果:** 「期間:」から「〜」までのテキストが表示される

### [2-W-10] カラム名カスタマイズ

**マクロ:** `{{wiki_list(-p, +title, 担当:|責任者)}}`

**期待結果:** カラムヘッダーが「責任者」

### [2-W-11] カラム名と幅のカスタマイズ

**マクロ:** `{{wiki_list(-p, +title, 担当:|責任者|150px)}}`

**期待結果:** ヘッダー「責任者」、幅 150px

### [2-W-12] エラー: パラメータなし

**マクロ:** `{{wiki_list()}}`

**期待結果:** エラーメッセージ（usage）が表示

### [2-W-13] エラー: 不明なオプション

**マクロ:** `{{wiki_list(-x, +title)}}`

**期待結果:** `unknown option: -x` エラー

---

## 3. HTTP テスト - issue_name_link

### [3-I-1] 基本的な使用

**マクロ:** `{{issue_name_link(IssueNameLinkTest)}}`

**期待結果:** チケットへのリンクが生成、表示テキストは「IssueNameLinkTest」

### [3-I-2] 表示テキスト指定

**マクロ:** `{{issue_name_link(IssueNameLinkTest|テストリンク)}}`

**期待結果:** リンクテキストが「テストリンク」

### [3-I-3] プロジェクト指定

**マクロ:** `{{issue_name_link(wiki-list-test:IssueNameLinkTest)}}`

**期待結果:** 指定プロジェクトのチケットへのリンク

### [3-I-4] プロジェクトと表示テキスト両方

**マクロ:** `{{issue_name_link(wiki-list-test:IssueNameLinkTest|リンク)}}`

**期待結果:** プロジェクト指定＋カスタム表示テキスト

### [3-I-5] エラー: パラメータなし

**マクロ:** `{{issue_name_link()}}`

**期待結果:** `no parameters` エラー

### [3-I-6] エラー: パラメータ過多

**マクロ:** `{{issue_name_link(a, b)}}`

**期待結果:** `too many parameters` エラー

### [3-I-7] エラー: チケットが見つからない

**マクロ:** `{{issue_name_link(NonExistentIssue)}}`

**期待結果:** `issue:NonExistentIssue is not found` エラー

### [3-I-8] エラー: プロジェクトが見つからない

**マクロ:** `{{issue_name_link(nonexistent:SomeIssue)}}`

**期待結果:** `project:nonexistent is not found` エラー

---

## 4. HTTP テスト - ref_issues

### 基本機能

#### [4-R-1] デフォルト動作

**マクロ:** Wikiページ「RefIssuesTest1」に `{{ref_issues()}}`

**期待結果:** ページ名を含むチケットが一覧表示

#### [4-R-2] -i オプション（クエリID）

**マクロ:** `{{ref_issues(-i=<QueryID>)}}`

**期待結果:** 指定クエリの結果が表示

#### [4-R-3] -q オプション（クエリ名）

**マクロ:** `{{ref_issues(-q=WikiListTestQuery)}}`

**期待結果:** 「WikiListTestQuery」の結果が表示

### プロジェクト制限

#### [4-R-4] -p オプション

**マクロ:** `{{ref_issues(-p)}}`

**期待結果:** 現在のプロジェクトのチケットのみ

#### [4-R-5] -p=identifier オプション

**マクロ:** `{{ref_issues(-p=wiki-list-test)}}`

**期待結果:** 指定プロジェクトのチケットのみ

### 検索キーワード

#### [4-R-6] -s オプション（題名検索）

**マクロ:** `{{ref_issues(-s=RefIssuesTest1)}}`

**期待結果:** 題名に「RefIssuesTest1」を含むチケット

#### [4-R-7] -d オプション（説明検索）

**マクロ:** `{{ref_issues(-d=キーワード)}}`

**期待結果:** 説明にキーワードを含むチケット

#### [4-R-8] -w オプション（題名＋説明）

**マクロ:** `{{ref_issues(-w=RefIssues)}}`

**期待結果:** 題名または説明に含むチケット

#### [4-R-9] 複数キーワード（OR）

**マクロ:** `{{ref_issues(-s=RefIssuesTest1|RefIssuesTest2)}}`

**期待結果:** どちらかを含むチケット

### フィルタ

#### [4-R-10] -f オプション（=演算子）

**マクロ:** `{{ref_issues(-f:status_id=1)}}`

**期待結果:** ステータスID=1 のチケット

#### [4-R-11] -f:tracker（名前指定）

**マクロ:** `{{ref_issues(-f:tracker=バグ)}}`

**期待結果:** トラッカー「バグ」のチケット

#### [4-R-12] -f:status（名前指定）

**マクロ:** `{{ref_issues(-f:status=新規)}}`

**期待結果:** ステータス「新規」のチケット

#### [4-R-13] -f:assigned_to（名前指定）

**マクロ:** `{{ref_issues(-f:assigned_to=admin)}}`

**期待結果:** 担当者 admin のチケット

#### [4-R-14] 複数フィルタ

**マクロ:** `{{ref_issues(-f:tracker=バグ, -f:status=新規)}}`

**期待結果:** 両方の条件を満たすチケット

#### [4-R-15] 演算子指定

**マクロ:** `{{ref_issues(-f:status_id ! 5)}}`

**期待結果:** ステータスID≠5 のチケット

### 表示形式

#### [4-R-16] -t オプション

**マクロ:** `{{ref_issues(-p, -t)}}`

**期待結果:** 題名がプレーンテキストで表示

#### [4-R-17] -t=column オプション

**マクロ:** `{{ref_issues(-p, -t=id)}}`

**期待結果:** IDがテキストで表示

#### [4-R-18] -l オプション

**マクロ:** `{{ref_issues(-p, -l)}}`

**期待結果:** 題名がリンクとして表示

#### [4-R-19] -l=column オプション

**マクロ:** `{{ref_issues(-p, -l=id)}}`

**期待結果:** IDがリンクとして表示

#### [4-R-20] -c オプション（件数）

**マクロ:** `{{ref_issues(-p, -c)}}`

**期待結果:** 件数のみが数字で表示

#### [4-R-21] -0 オプション（0件非表示）

**マクロ:** `{{ref_issues(-f:subject ~ 存在しない, -0)}}`

**期待結果:** 0件の場合、何も表示されない

#### [4-R-22] -n オプション

**マクロ:** `{{ref_issues(-p, -n=2)}}`

**期待結果:** 最大2件のみ表示

### カラム指定

#### [4-R-23] 単一カラム

**マクロ:** `{{ref_issues(-p, subject)}}`

**期待結果:** 題名カラムのみ

#### [4-R-24] 複数カラム

**マクロ:** `{{ref_issues(-p, id, subject, status)}}`

**期待結果:** 指定3カラムが順番に表示

### 特殊変数

#### [4-R-25] [current_user]

**マクロ:** `{{ref_issues(-f:assigned_to=[current_user])}}`

**期待結果:** 現在のユーザーが担当のチケット

#### [4-R-26] [current_project_id]

**マクロ:** `{{ref_issues(-f:project_id=[current_project_id])}}`

**期待結果:** 現在のプロジェクトのチケット

#### [4-R-27] [Ndays_ago]

**マクロ:** `{{ref_issues(-f:created_on >= [7days_ago])}}`

**期待結果:** 過去7日以内に作成されたチケット

### 並び順・グループ

#### [4-R-36] -o オプション（昇順）

**マクロ:** `{{ref_issues(-p, -o=subject, subject)}}`

**期待結果:** IssueNameLinkTest、RefIssuesTest1、RefIssuesTest2、RefIssuesTest3 の順に表示

#### [4-R-37] -o オプション（降順）

**マクロ:** `{{ref_issues(-p, -o=subject:desc, subject)}}`

**期待結果:** RefIssuesTest3、RefIssuesTest2、RefIssuesTest1、IssueNameLinkTest の順に表示

#### [4-R-38] -o オプション（複数カラム）

**マクロ:** `{{ref_issues(-p, -o=tracker|subject:desc, tracker, subject)}}`

**期待結果:** トラッカーの順（管理画面のトラッカーの並び順）に並び、同じトラッカーの中は題名の降順

#### [4-R-39] -g オプション

**マクロ:** `{{ref_issues(-p, -g=tracker, -o=subject)}}`

**期待結果:** トラッカーごとの見出しが表示される（バグ: 3件、機能: 1件）。各グループの中は題名の昇順

#### [4-R-40] -g オプション（担当者）

**マクロ:** `{{ref_issues(-p, -g=assigned_to)}}`

**期待結果:** 担当者ごとの見出しが表示される（admin: 3件、Wiki List User: 1件）

#### [4-R-41] -o・-g とカスタムクエリ

**マクロ:** `{{ref_issues(-q=WikiListTestQuery, -o=subject:desc, -g=tracker)}}`

**期待結果:** クエリの条件（新規のみ）で絞り込まれたまま、トラッカーごとの見出しで分かれ、各グループの中は題名の降順

#### [4-R-42] -o と -n

**マクロ:** `{{ref_issues(-p, -o=subject:desc, -n=2)}}`

**期待結果:** RefIssuesTest3、RefIssuesTest2 の2件のみ表示（並べた順の上から2件）

#### [4-R-43] -g と -n

**マクロ:** `{{ref_issues(-p, -g=tracker, -o=subject, -n=2)}}`

**期待結果:** 「バグ」の見出しと IssueNameLinkTest、RefIssuesTest1 の2行のみ表示。見出しの件数はグループ全体の 3

#### [4-R-44] -g と -c

**マクロ:** `{{ref_issues(-p, -g=tracker, -c)}}`

**期待結果:** 件数（4）のみが数字で表示（-g は使われない）

#### [4-R-45] -g と -l

**マクロ:** `{{ref_issues(-p, -g=tracker, -l)}}`

**期待結果:** 題名がリンクとして横並びで表示され、見出しは表示されない

### エラーケース

#### [4-R-28] 存在しないクエリID

**マクロ:** `{{ref_issues(-i=99999)}}`

**期待結果:** `can not find CustomQuery ID` エラー

#### [4-R-29] 存在しないクエリ名

**マクロ:** `{{ref_issues(-q=NonExistent)}}`

**期待結果:** `can not find CustomQuery Name` エラー

#### [4-R-30] 不明なオプション

**マクロ:** `{{ref_issues(-x)}}`

**期待結果:** `unknown option:-x` エラー

#### [4-R-31] 不正な表示件数

**マクロ:** `{{ref_issues(-n=abc)}}`

**期待結果:** `display limit must be a positive integer` エラー

#### [4-R-32] 表示件数上限超過

**マクロ:** `{{ref_issues(-n=2000)}}`

**期待結果:** `exceeds maximum (1000)` エラー

#### [4-R-33] 不明なカラム

**マクロ:** `{{ref_issues(-p, unknown_column)}}`

**期待結果:** `unknown column` エラー

#### [4-R-34] 不正な演算子

**マクロ:** `{{ref_issues(-f:status_id ?? 1)}}`

**期待結果:** `invalid operator` エラー

#### [4-R-35] 存在しないフィルタ値

**マクロ:** `{{ref_issues(-f:tracker=存在しない)}}`

**期待結果:** `can not resolve` エラー

#### [4-R-46] 並べ替えできないカラム

**マクロ:** `{{ref_issues(-p, -o=unknown)}}`

**期待結果:** `can not sort by 'unknown'` エラー。`[SORT]` の後に使えるカラムの一覧が表示される

#### [4-R-47] 不正な並び順の向き

**マクロ:** `{{ref_issues(-p, -o=subject:up)}}`

**期待結果:** `sort order must be 'asc' or 'desc'` エラー

#### [4-R-48] 並び順のカラム数超過

**マクロ:** `{{ref_issues(-p, -o=id|subject|tracker|status)}}`

**期待結果:** `too many sort columns (max 3)` エラー

#### [4-R-49] 並び順の指定なし

**マクロ:** `{{ref_issues(-p, -o)}}`

**期待結果:** `no sort order specified` エラー

#### [4-R-50] グループにできないカラム

**マクロ:** `{{ref_issues(-p, -g=subject)}}`

**期待結果:** `can not group by 'subject'` エラー。`[GROUP]` の後に使えるカラムの一覧が表示される

#### [4-R-51] グループの指定なし

**マクロ:** `{{ref_issues(-p, -g)}}`

**期待結果:** `no group column specified` エラー

---

## 5. HTTP テスト - 見られる範囲

### [5-V-1] 見られないプロジェクト・チケット・ユーザーなどは、無い物と同じ表示になる

マクロに名前で書いたものは、ページを見ている人が見られる範囲だけで探す。
見られない物を書いたときの表示が、無い物を書いたときと（名前のところを除いて）同じで、期待するエラー文であることを確かめる。
見られる物（ほかのプロジェクトから共有された版を含む）とロック中のメンバーは使えることも確かめる。
エラー文の改行が改行として出ること（改行の印が文字のまま出ないこと）と、マクロに書いた文字が文字のまま出ることも確かめる。

マクロは、プラグインの Wiki プレビュー（`POST /wiki_preview.json`）を viewer の API キーで呼んで描画する。

用意（`rails runner`。下のスクリプトを `wm_setup.rb` として保存する）：非公開の Pub と Secret を作る。
viewer は Pub だけのメンバー、secretonly は Secret だけのメンバー、locked は Pub のメンバーでロック中にする。
Pub の中に、viewer から見えない非公開チケット（insider が作成）と、locked が担当のチケットを置く。
Secret には、共有しないバージョン・system で共有するバージョンとカテゴリを置く。Pub にもバージョンとカテゴリを置く。
最後の行に、viewer の API キーなどを JSON で出す。

```ruby
sfx = SecureRandom.hex(3)
mk_user = ->(name) {
  u = User.new(login: "wm_#{name}_#{sfx}", firstname: 'WM', lastname: name, mail: "wm_#{name}_#{sfx}@example.com", status: User::STATUS_ACTIVE)
  u.password = u.password_confirmation = "Pw-#{sfx}-x9Z"
  u.save!
  u
}
role = Role.create!(name: "WM_Role_#{sfx}", permissions: [:view_issues, :view_wiki_pages], users_visibility: 'members_of_visible_projects', issues_visibility: 'default', assignable: true)
tracker = Tracker.first
pub = Project.create!(name: "WM_Pub_#{sfx}", identifier: "wm-pub-#{sfx}", is_public: false, tracker_ids: [tracker.id])
secret = Project.create!(name: "WM_Secret_#{sfx}", identifier: "wm-secret-#{sfx}", is_public: false, tracker_ids: [tracker.id])
[pub, secret].each { |p| p.enabled_module_names = %w[issue_tracking wiki]; p.save! }
viewer = mk_user.call('viewer')
insider = mk_user.call('insider')
Member.create!(principal: viewer, project: pub, roles: [role])
Member.create!(principal: insider, project: secret, roles: [role])
Member.create!(principal: insider, project: pub, roles: [role])
locked = mk_user.call('locked')
Member.create!(principal: locked, project: pub, roles: [role])
secret_only = mk_user.call('secretonly')
Member.create!(principal: secret_only, project: secret, roles: [role])
admin = User.find(1)
pub_issue = Issue.create!(project: pub, tracker: tracker, subject: "WM_PubIssue_#{sfx}", author: admin)
Issue.create!(project: secret, tracker: tracker, subject: "WM_SecretIssue_#{sfx}", author: admin)
# Pub の中の、viewer から見えない非公開のチケット（ほかの人が書いた private）
Issue.create!(project: pub, tracker: tracker, subject: "WM_PrivateIssue_#{sfx}", author: insider, is_private: true)
# locked が担当のチケット（担当にしてからロックする）
Issue.create!(project: pub, tracker: tracker, subject: "WM_LockedIssue_#{sfx}", author: admin, assigned_to: locked)
locked.update_column(:status, User::STATUS_LOCKED)
Version.create!(project: secret, name: "WM_SecretVer_#{sfx}")
Version.create!(project: secret, name: "WM_SharedVer_#{sfx}", sharing: 'system')
Version.create!(project: pub, name: "WM_PubVer_#{sfx}")
IssueCategory.create!(project: secret, name: "WM_SecretCat_#{sfx}")
IssueCategory.create!(project: pub, name: "WM_PubCat_#{sfx}")
api_key = viewer.api_key
puts({ suffix: sfx, key: api_key, pub_id: pub.id, pub_ident: pub.identifier, pub_name: pub.name, pub_issue: pub_issue.id,
       secret_id: secret.id, secret_ident: secret.identifier, secret_name: secret.name, secret_only: secret_only.login,
       locked: locked.login, tracker: tracker.name }.to_json)
```

実行（PowerShell 7）：

```powershell
$Container = '{Container}'; $BaseUrl = '{BaseUrl}'
docker cp "wm_setup.rb" "${Container}:/tmp/wm_setup.rb" | Out-Null
$d = docker exec -u redmine -w /usr/src/redmine $Container bundle exec rails runner /tmp/wm_setup.rb 2>$null | Select-Object -Last 1 | ConvertFrom-Json
try {
    $s = $d.suffix
    function Render($text) {
        $body = @{ text = $text; project_id = $d.pub_id } | ConvertTo-Json -Compress
        $r = Invoke-RestMethod -Uri "$BaseUrl/wiki_preview.json" -Method Post -Headers @{ 'X-Redmine-API-Key' = $d.key } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))
        $r.wiki_preview.html
    }
    # 見られない物（hidden）と無い物（missing）で、名前のところをそろえた表示が同じで、期待するエラー文（$expect）か
    function Same($hiddenText, $missingText, $hiddenKey, $missingKey, $expect) {
        $h = (Render $hiddenText).Replace($hiddenKey, 'KEY')
        $m = (Render $missingText).Replace($missingKey, 'KEY')
        if ($h -ne $m) { "DIFF`n  hidden=$h`n  missing=$m" }
        elseif (-not $m.Contains($expect)) { "UNEXPECTED`n  missing=$m" }
        else { 'same' }
    }
    # エラーの枠が出ていないか（見られる物を書いたときに使う）
    function Works($text) { $html = Render $text; if ($html -match 'flash error') { "ERROR`n  $html" } else { 'works' } }
    $none = "wm-none-$s"
    "issue_name_link project: " + (Same "{{issue_name_link($($d.secret_ident):x)}}" "{{issue_name_link(${none}:x)}}" $d.secret_ident $none 'project:KEY is not found.')
    "issue_name_link issue: " + (Same "{{issue_name_link($($d.pub_ident):WM_PrivateIssue_$s)}}" "{{issue_name_link($($d.pub_ident):WM_NoIssue_$s)}}" "WM_PrivateIssue_$s" "WM_NoIssue_$s" 'issue:KEY is not found in prj:')
    "wiki_list -p: " + (Same "{{wiki_list(-p=$($d.secret_name))}}" "{{wiki_list(-p=WM_None_$s)}}" $d.secret_name "WM_None_$s" 'project:KEY is not found.')
    "ref_issues -p: " + (Same "{{ref_issues(-p=$($d.secret_ident))}}" "{{ref_issues(-p=$none)}}" $d.secret_ident $none 'project:KEY is not found.')
    "ref_issues -p id: " + (Same "{{ref_issues(-p=$($d.secret_id))}}" "{{ref_issues(-p=999999)}}" "$($d.secret_id)" '999999' 'project:KEY is not found.')
    "ref_issues -f:assigned_to: " + (Same "{{ref_issues(-f:assigned_to=$($d.secret_only))}}" "{{ref_issues(-f:assigned_to=wm_nobody_$s)}}" $d.secret_only "wm_nobody_$s" 'can not resolve &#39;KEY&#39;')
    "ref_issues -f:project: " + (Same "{{ref_issues(-f:project=$($d.secret_name))}}" "{{ref_issues(-f:project=WM_None_$s)}}" $d.secret_name "WM_None_$s" 'can not resolve &#39;KEY&#39;')
    "ref_issues -f:version: " + (Same "{{ref_issues(-f:version=WM_SecretVer_$s)}}" "{{ref_issues(-f:version=WM_NoVer_$s)}}" "WM_SecretVer_$s" "WM_NoVer_$s" 'can not resolve &#39;KEY&#39;')
    "ref_issues -f:category: " + (Same "{{ref_issues(-f:category=WM_SecretCat_$s)}}" "{{ref_issues(-f:category=WM_NoCat_$s)}}" "WM_SecretCat_$s" "WM_NoCat_$s" 'can not resolve &#39;KEY&#39;')
    # 見られる物は使える
    "visible issue_name_link: " + ((Render "{{issue_name_link($($d.pub_ident):WM_PubIssue_$s)}}") -match "issues/$($d.pub_issue)")
    "visible ref_issues -p: " + (Works "{{ref_issues(-p=$($d.pub_ident),-c)}}")
    "visible ref_issues -p id: " + (Works "{{ref_issues(-p=$($d.pub_id),-c)}}")
    "visible -f:version: " + (Works "{{ref_issues(-f:version=WM_PubVer_$s,-c)}}")
    # 共有された版は、本体と同じく、プロジェクトを決めたとき（-p）にそのプロジェクトで使える版として探す
    "visible -f:version shared: " + (Works "{{ref_issues(-p=$($d.pub_ident),-f:version=WM_SharedVer_$s,-c)}}")
    "visible -f:category: " + (Works "{{ref_issues(-f:category=WM_PubCat_$s,-c)}}")
    "visible -f:project: " + (Works "{{ref_issues(-f:project=$($d.pub_name),-c)}}")
    "visible -f:tracker: " + (Works "{{ref_issues(-f:tracker=$($d.tracker),-c)}}")
    # ロック中のメンバーが担当のチケットが 1 件だけ数えられる
    $lockedCount = Render "{{ref_issues(-f:assigned_to=$($d.locked),-c)}}"
    "locked member count: " + ($lockedCount -replace '<[^>]+>', '').Trim()
    # エラー文の改行は改行として出る（改行の印が文字にならない）。マクロに書いた文字は文字のまま出る
    $usage = Render "{{wiki_list(-x)}}"
    "error line break: " + (($usage -match '<br\s*/?>') -and -not ($usage -match '&lt;br'))
    $tagged = Render "{{issue_name_link(<b>wm</b>:x)}}"
    "error text escaped: " + (-not ($tagged -match '<b>wm</b>'))
} finally {
    # 後片付け。suffix が 6 桁の 16 進でなければ止める（空のまま LIKE で探すと、ほかのプロジェクト・ユーザーに当たる）
    if ($d.suffix -notmatch '^[0-9a-f]{6}$') { throw "suffix が正しくない: '$($d.suffix)'" }
    $cleanup = "sfx = '$($d.suffix)'; Project.where('identifier LIKE ?', ""wm-%-#{sfx}"").each(&:destroy); User.where('login LIKE ?', ""wm_%_#{sfx}"").each(&:destroy); Role.where(name: ""WM_Role_#{sfx}"").each(&:destroy); puts 'cleanup: ok'"
    docker exec -u redmine -w /usr/src/redmine $Container bundle exec rails runner $cleanup 2>$null | Select-Object -Last 1
}
```

**期待結果:**

- 9 の組み合わせ（issue_name_link のプロジェクト・チケット、wiki_list の `-p=`、ref_issues の `-p=`〔識別子・数字の id〕・`-f:assigned_to`・`-f:project`・`-f:version`・`-f:category`）がすべて `same`（見られない物と無い物で同じ表示で、期待するエラー文）
- `visible issue_name_link` が `True`、`visible ...` の 7 つがすべて `works`（ほかのプロジェクトから system で共有された版も、`-p` で決めたプロジェクトで使える）
- `locked member count: 1`（ロック中のメンバーが担当のチケットを数えられる）
- `error line break: True`・`error text escaped: True`
- `cleanup: ok`
---

## 6. ブラウザテスト

該当なし（HTTP テストで網羅可能）
