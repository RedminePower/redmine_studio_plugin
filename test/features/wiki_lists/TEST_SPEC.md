# Wiki Lists テスト仕様書

## 概要

redmine_studio_plugin の Wiki Lists 機能のテスト仕様。

本機能は以下の3つのWikiマクロを提供する:

| マクロ | 機能 |
|--------|------|
| `{{wiki_list}}` | Wikiページ一覧を表形式で表示 |
| `{{issue_name_link}}` | チケット題名でリンクを作成 |
| `{{ref_issues}}` | 条件に合うチケット一覧を表示 |

## 環境パラメータ

パスから自動判定:
- `redmine_5.1.11` → コンテナ名: `redmine_5.1.11`, ポート: `3051`
- `redmine_6.1.1` → コンテナ名: `redmine_6.1.1`, ポート: `3061`

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

### フェーズ 0: Puma 停止

SQLite ロック競合を回避するため、Runner テスト実行前に Puma を停止する。

```bash
docker exec redmine_5.1.11 bash -c "kill $(cat /usr/src/redmine/tmp/pids/server.pid)"
```

### フェーズ 1: Runner テスト

バッチ 1: [1-1] 〜 [1-7] を1つのスクリプトにまとめて実行

### フェーズ 2: コンテナ再起動

HTTP テストに備え、コンテナを再起動して Puma を復帰させる。

```bash
docker restart redmine_5.1.11
```

### フェーズ 3: HTTP テスト

各マクロのオプション動作を確認する。

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

**マクロ:** `{{ref_issues(-f:subject~=存在しない, -0)}}`

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

---

## 5. ブラウザテスト

該当なし（HTTP テストで網羅可能）
