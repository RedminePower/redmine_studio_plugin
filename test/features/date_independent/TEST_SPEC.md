# Date Independent テスト仕様書

## 概要

redmine_studio_plugin の Date Independent 機能のテスト仕様。

親チケットの開始日・期日が子チケットから自動計算（derived）される動作を、プロジェクト単位・ステータス単位で制御する機能をテストする。

## 環境パラメータ

パスから自動判定:
- `redmine_5.1.11` → コンテナ名: `redmine_5.1.11`, ポート: `3051`
- `redmine_6.1.1` → コンテナ名: `redmine_6.1.1`, ポート: `3061`

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| コントローラ | `DateIndependentsController` |
| エンドポイント | `/date_independents` (RESTful) |
| モデル | `DateIndependent` |
| DBテーブル | `date_independents` |
| Issue パッチ | `RedmineStudioPlugin::DateIndependent::IssuePatch` |
| 管理メニュー | `:date_independents` |

---

## 設定項目一覧

| カテゴリ | 項目 | 設定値 |
|----------|------|--------|
| **基本** | タイトル | 任意テキスト（必須） |
| | 有効 | ON/OFF |
| **対象** | 対象プロジェクト | 複数選択可（必須） |
| | 適用しないステータス | 複数選択可 / 未指定 |

---

## テスト実行フロー

### フェーズ 0: Puma 停止

SQLite ロック競合を回避するため、Runner テスト実行前に Puma を停止する。
詳細は CLAUDE.md の「SQLite ロック競合の回避」を参照。

```bash
docker exec redmine_5.1.11 bash -c "kill $(cat /usr/src/redmine/tmp/pids/server.pid)"
```

### フェーズ 1: 登録確認テスト（バッチ 1）

プラグインの登録状態を確認する。

- バッチ 1: [1-1] 〜 [1-5] を1つのスクリプトにまとめて実行

### フェーズ 2: 機能テスト（バッチ 2〜3）

日付独立機能の動作を確認する。テストデータをセットアップ後、以下のバッチ単位で実行する。

**バッチ 2: needs_derived メソッドテスト（[2-A] 〜 [2-B]）**
- [2-A] 基本動作テスト
- [2-B] ステータス条件テスト

**バッチ 3: エッジケーステスト（[2-C]）**
- [2-C] エッジケーステスト

### フェーズ 3: コンテナ再起動

HTTP テスト・ブラウザテストに備え、コンテナを再起動して Puma を復帰させる。

```bash
docker restart redmine_5.1.11
```

---

## 1. 登録確認テスト

### [1-1] 管理メニュー登録確認

**確認方法:**
```ruby
menu_items = Redmine::MenuManager.items(:admin_menu).map(&:name)
puts menu_items.include?(:date_independents)
```

**期待結果:** `true` が出力される

### [1-2] ルーティング確認

**確認方法:**
```ruby
routes = [
  { path: '/date_independents', method: :get, expected: { controller: 'date_independents', action: 'index' } },
  { path: '/date_independents/new', method: :get, expected: { controller: 'date_independents', action: 'new' } },
  { path: '/date_independents', method: :post, expected: { controller: 'date_independents', action: 'create' } },
  { path: '/date_independents/1', method: :get, expected: { controller: 'date_independents', action: 'show', id: '1' } },
  { path: '/date_independents/1/edit', method: :get, expected: { controller: 'date_independents', action: 'edit', id: '1' } },
  { path: '/date_independents/1', method: :patch, expected: { controller: 'date_independents', action: 'update', id: '1' } },
  { path: '/date_independents/1', method: :delete, expected: { controller: 'date_independents', action: 'destroy', id: '1' } },
]

results = routes.map do |r|
  recognized = Rails.application.routes.recognize_path(r[:path], method: r[:method])
  r[:expected].all? { |k, v| recognized[k].to_s == v.to_s }
end

puts results.all?
```

**期待結果:** `true` が出力される

### [1-3] コントローラ確認

**確認方法:**
```ruby
puts defined?(DateIndependentsController)
puts DateIndependentsController.ancestors.include?(ApplicationController)
```

**期待結果:**
- `constant` が出力される
- `true` が出力される

### [1-4] Issue パッチ適用確認

**確認方法:**
```ruby
puts Issue.ancestors.include?(RedmineStudioPlugin::DateIndependent::IssuePatch)
```

**期待結果:** `true` が出力される

### [1-5] DateIndependent モデル確認

**確認方法:**
```ruby
puts defined?(DateIndependent)
puts DateIndependent.ancestors.include?(ActiveRecord::Base)

# デフォルト値の確認
di = DateIndependent.new
puts di.is_enabled == true
```

**期待結果:**
- `constant` が出力される
- `true` が出力される（2回）

---

## 2. 機能テスト

### テストデータ

テスト実行時に以下のデータを自動作成する:

**プロジェクト:**
- date-independent-test-1（テスト用プロジェクト1）
- date-independent-test-2（テスト用プロジェクト2）

**トラッカー:**
- 既存のトラッカーを使用

**ステータス:**
- 既存の「新規」「進行中」「終了」ステータスを使用

**前提条件:**
- Redmine の設定「子チケットの値から算出」が有効であること
  - `Setting.parent_issue_dates = 'derived'`

---

### [2-A] 基本動作テスト

#### [2-A-1] 全体設定が derived でない場合 → 常に連動しない

**条件:**
- `Setting.parent_issue_dates = 'independent'`
- ルールの有無に関わらず

**確認方法:**
```ruby
Setting.parent_issue_dates = 'independent'
issue = Issue.find(親チケットID)
puts issue.send(:needs_derived)
```

**期待結果:**
- `false` が出力される（連動しない）

#### [2-A-2] ルールなし → 連動する（デフォルト動作）

**条件:**
- `Setting.parent_issue_dates = 'derived'`
- 該当プロジェクトにルールが存在しない

**確認方法:**
```ruby
Setting.parent_issue_dates = 'derived'
DateIndependent.where(is_enabled: true).destroy_all
issue = Issue.find(親チケットID)
puts issue.send(:needs_derived)
```

**期待結果:**
- `true` が出力される（連動する）

#### [2-A-3] ルールあり（適用しないステータス未設定）→ 連動しない

**条件:**
- `Setting.parent_issue_dates = 'derived'`
- 該当プロジェクトに有効なルールが存在
- `calculate_status_ids` が空

**確認方法:**
```ruby
Setting.parent_issue_dates = 'derived'
project = Project.find_by(identifier: 'date-independent-test-1')
rule = DateIndependent.create(
  title: 'Test Rule',
  is_enabled: true,
  project_ids: [project.id],
  calculate_status_ids: []
)
issue = Issue.find(親チケットID)  # project = date-independent-test-1
puts issue.send(:needs_derived)
```

**期待結果:**
- `false` が出力される（連動しない = 独立）

#### [2-A-4] ルール無効 → 連動する

**条件:**
- `Setting.parent_issue_dates = 'derived'`
- 該当プロジェクトにルールが存在するが `is_enabled = false`

**確認方法:**
```ruby
Setting.parent_issue_dates = 'derived'
project = Project.find_by(identifier: 'date-independent-test-1')
rule = DateIndependent.create(
  title: 'Disabled Rule',
  is_enabled: false,
  project_ids: [project.id],
  calculate_status_ids: []
)
issue = Issue.find(親チケットID)
puts issue.send(:needs_derived)
```

**期待結果:**
- `true` が出力される（無効ルールは無視され、連動する）

#### [2-A-5] 対象外プロジェクト → 連動する

**条件:**
- `Setting.parent_issue_dates = 'derived'`
- ルールが存在するが、チケットのプロジェクトが対象外

**確認方法:**
```ruby
Setting.parent_issue_dates = 'derived'
project1 = Project.find_by(identifier: 'date-independent-test-1')
project2 = Project.find_by(identifier: 'date-independent-test-2')
rule = DateIndependent.create(
  title: 'Project 1 Only',
  is_enabled: true,
  project_ids: [project1.id],  # プロジェクト1のみ
  calculate_status_ids: []
)
issue = Issue.find(親チケットID)  # project = date-independent-test-2
puts issue.send(:needs_derived)
```

**期待結果:**
- `true` が出力される（対象外プロジェクトなので連動する）

#### [2-A-6] 複数プロジェクト選択 → いずれかに該当すれば適用

**条件:**
- ルールに複数プロジェクトを設定
- チケットがいずれかのプロジェクトに所属

**確認方法:**
```ruby
Setting.parent_issue_dates = 'derived'
project1 = Project.find_by(identifier: 'date-independent-test-1')
project2 = Project.find_by(identifier: 'date-independent-test-2')
rule = DateIndependent.create(
  title: 'Multiple Projects',
  is_enabled: true,
  project_ids: [project1.id, project2.id],  # 両方のプロジェクト
  calculate_status_ids: []
)
issue1 = Issue.find(プロジェクト1の親チケットID)
issue2 = Issue.find(プロジェクト2の親チケットID)
puts issue1.send(:needs_derived)
puts issue2.send(:needs_derived)
```

**期待結果:**
- 両方とも `false` が出力される（両プロジェクトでルールが適用され、連動しない）

---

### [2-B] ステータス条件テスト

#### [2-B-1] 適用しないステータスに該当 → 連動する

**条件:**
- ルールあり、`calculate_status_ids` に親チケットのステータスが含まれる

**確認方法:**
```ruby
Setting.parent_issue_dates = 'derived'
project = Project.find_by(identifier: 'date-independent-test-1')
status_new = IssueStatus.find_by(name: '新規')
rule = DateIndependent.create(
  title: 'Allow New Status',
  is_enabled: true,
  project_ids: [project.id],
  calculate_status_ids: [status_new.id]
)
issue = Issue.find(親チケットID)  # status = 新規
puts issue.send(:needs_derived)
```

**期待結果:**
- `true` が出力される（ステータスが「適用しない」リストに含まれるので連動する）

#### [2-B-2] 適用しないステータスに非該当 → 連動しない

**条件:**
- ルールあり、`calculate_status_ids` に親チケットのステータスが含まれない

**確認方法:**
```ruby
Setting.parent_issue_dates = 'derived'
project = Project.find_by(identifier: 'date-independent-test-1')
status_new = IssueStatus.find_by(name: '新規')
status_in_progress = IssueStatus.find_by(name: '進行中')
rule = DateIndependent.create(
  title: 'Allow New Status Only',
  is_enabled: true,
  project_ids: [project.id],
  calculate_status_ids: [status_new.id]  # 新規のみ
)
issue = Issue.find(親チケットID)  # status = 進行中
puts issue.send(:needs_derived)
```

**期待結果:**
- `false` が出力される（ステータスが「適用しない」リストに含まれないので連動しない）

#### [2-B-3] 複数ルールがある場合 → いずれかにマッチすれば連動

**条件:**
- 複数のルールが同じプロジェクトに設定
- 1つのルールの `calculate_status_ids` にマッチ

**確認方法:**
```ruby
Setting.parent_issue_dates = 'derived'
project = Project.find_by(identifier: 'date-independent-test-1')
status_new = IssueStatus.find_by(name: '新規')
status_in_progress = IssueStatus.find_by(name: '進行中')

rule1 = DateIndependent.create(
  title: 'Rule 1',
  is_enabled: true,
  project_ids: [project.id],
  calculate_status_ids: [status_new.id]
)
rule2 = DateIndependent.create(
  title: 'Rule 2',
  is_enabled: true,
  project_ids: [project.id],
  calculate_status_ids: [status_in_progress.id]
)
issue = Issue.find(親チケットID)  # status = 進行中
puts issue.send(:needs_derived)
```

**期待結果:**
- `true` が出力される（rule2 の `calculate_status_ids` にマッチ）

#### [2-B-4] 複数ステータス選択 → いずれかに該当すれば連動

**条件:**
- ルールに複数ステータスを設定
- チケットがいずれかのステータス

**確認方法:**
```ruby
Setting.parent_issue_dates = 'derived'
project = Project.find_by(identifier: 'date-independent-test-1')
status_new = IssueStatus.find_by(name: '新規')
status_in_progress = IssueStatus.find_by(name: '進行中')
status_closed = IssueStatus.find_by(name: '終了')

rule = DateIndependent.create(
  title: 'Multiple Statuses',
  is_enabled: true,
  project_ids: [project.id],
  calculate_status_ids: [status_new.id, status_in_progress.id]  # 新規と進行中
)

issue_new = Issue.find(ステータス新規の親チケットID)
issue_in_progress = Issue.find(ステータス進行中の親チケットID)
issue_closed = Issue.find(ステータス終了の親チケットID)

puts issue_new.send(:needs_derived)
puts issue_in_progress.send(:needs_derived)
puts issue_closed.send(:needs_derived)
```

**期待結果:**
- `issue_new`: `true`（新規は適用しないリストに含まれる → 連動する）
- `issue_in_progress`: `true`（進行中は適用しないリストに含まれる → 連動する）
- `issue_closed`: `false`（終了は適用しないリストに含まれない → 連動しない）

---

### [2-C] エッジケーステスト

#### [2-C-1] dates_derived? はリーフチケットで常に false

**条件:**
- 子チケットを持たないチケット

**確認方法:**
```ruby
leaf_issue = Issue.find(子チケットなしのチケットID)
puts leaf_issue.leaf?
puts leaf_issue.dates_derived?
```

**期待結果:**
- `true` が出力される（リーフである）
- `false` が出力される（リーフは常に dates_derived? = false）

#### [2-C-2] dates_derived? は非リーフで needs_derived を参照

**条件:**
- 子チケットを持つチケット

**確認方法:**
```ruby
parent_issue = Issue.find(親チケットID)
puts parent_issue.leaf?
puts parent_issue.dates_derived?
puts parent_issue.send(:needs_derived)
# dates_derived? == needs_derived であることを確認
puts parent_issue.dates_derived? == parent_issue.send(:needs_derived)
```

**期待結果:**
- `false` が出力される（リーフではない）
- `dates_derived?` と `needs_derived` が同じ値を返す
- 最後の比較で `true` が出力される

#### [2-C-3] バリデーション - タイトル必須

**確認方法:**
```ruby
di = DateIndependent.new(title: nil, project_ids: [1])
puts di.valid?
puts di.errors[:title].present?
```

**期待結果:**
- `false` が出力される（無効）
- `true` が出力される（タイトルエラーあり）

#### [2-C-4] バリデーション - プロジェクト必須

**確認方法:**
```ruby
di = DateIndependent.new(title: 'Test', project_ids: [])
puts di.valid?
puts di.errors[:project_ids].present?
```

**期待結果:**
- `false` が出力される（無効）
- `true` が出力される（プロジェクトエラーあり）

---

## 3. HTTP テスト

> **注記:** 現時点では HTTP テストは実施しない。
> 理由: 管理画面の CRUD 操作は標準的な Rails の実装であり、プラグイン固有のロジックには影響しない。
> 将来、コントローラのロジックを変更した場合に追加を検討する。

### 確認可能な項目（参考）

| ID | 確認内容 |
|----|----------|
| [3-1] | 管理画面一覧（管理者） → 200 |
| [3-2] | 管理画面一覧（非管理者） → 302（リダイレクト） |
| [3-3] | ルール作成（POST） |
| [3-4] | ルール詳細表示（GET） |
| [3-5] | ルール更新（PATCH） |
| [3-6] | ルール削除（DELETE） |

---

## 4. ブラウザテスト

> **注記:** 現時点ではブラウザテストは実施しない。
> 理由: 管理画面は標準的な Rails フォームであり、複雑な JavaScript 動作もない。
> 将来、UI を変更した場合や、JavaScript の動作確認が必要な場合に追加を検討する。

### 確認可能な項目（参考）

| ID | 確認内容 |
|----|----------|
| [4-1] | 管理画面でルール一覧表示 |
| [4-2] | ルール作成フォームの表示・入力・保存 |
| [4-3] | ルール編集 |
| [4-4] | ルール削除 |

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいて以下の順序でテストを実行する:

1. フェーズ 0: Puma 停止（SQLite ロック回避）
2. フェーズ 1: 登録確認テスト実行（バッチ 1）
3. フェーズ 2: 機能テスト実行（セットアップ → バッチ 2〜3）
4. フェーズ 3: コンテナ再起動

テストデータの管理は CLAUDE.md の「テストデータの管理」ルールに従う。

### Runner テスト実行時の注意事項

- バッチ実行のガイドラインは CLAUDE.md の「Runner テストのバッチ実行」を参照
- SQLite ロック回避は CLAUDE.md の「SQLite ロック競合の回避」を参照
