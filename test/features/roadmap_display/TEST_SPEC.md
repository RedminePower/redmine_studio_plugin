# Roadmap Display テスト仕様書

## 概要

redmine_studio_plugin の Roadmap Display 機能のテスト仕様。

ロードマップのバージョン画面・ロードマップ画面の「関連するチケット」を、管理者が設定した列・グループ条件・並び順のチケット一覧に置き換える機能をテストする。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| コントローラ | `RoadmapDisplaysController` |
| エンドポイント | `/roadmap_displays`（index / new / create / edit / update / destroy）、`/roadmap_displays/matches`（GET）、`/roadmap_displays/preview`（POST） |
| モデル | `RoadmapDisplay`（並び順は `acts_as_positioned`） |
| DBテーブル | `roadmap_displays` |
| フック | `view_versions_show_bottom`（バージョン画面）、`view_projects_roadmap_version_bottom`（ロードマップ画面）、`view_layouts_base_html_head`（CSS と標準一覧の非表示） |
| ヘルパーパッチ | `RedmineStudioPlugin::RoadmapDisplay::QueriesHelperPatch`（担当者列のアバター） |
| 管理メニュー | `:roadmap_displays` |

---

## 設定項目一覧

| カテゴリ | 項目 | 設定値 |
|----------|------|--------|
| **基本** | 名前 | 任意テキスト（必須） |
| | 有効 | ON/OFF |
| | プロジェクトパターン | プロジェクト識別子に対する正規表現 / 空欄（すべて） |
| **一覧** | グループ条件 | チケット一覧のグループ条件 / 空欄 |
| | 対象のチケット | all / open / closed |
| | 合計 | チケット一覧の合計対象の列（複数） |
| | 標準の一覧 | 隠す / 下に残す |
| | ソート条件 | 最大3つ |
| | 項目 | チケット一覧の列（複数・順序あり） |

---

## テスト実行フロー

### フェーズ 0: Puma 停止

SQLite ロック競合を回避するため、Runner テスト実行前に Puma を停止する。
詳細は CLAUDE.md の「SQLite ロック競合の回避」を参照。

```bash
docker exec {Container} bash -c "kill $(cat /usr/src/redmine/tmp/pids/server.pid)"
```

### フェーズ 1: 登録確認テスト（バッチ 1）

- バッチ 1: [1-1] 〜 [1-5] を1つのスクリプトにまとめて実行

### フェーズ 2: 機能テスト（バッチ 2）

- バッチ 2: [2-1] 〜 [2-8] を1つのスクリプトにまとめて実行する。
  テストデータは `ActiveRecord::Base.transaction` の中で作成し、最後に `raise ActiveRecord::Rollback` で戻す。

### フェーズ 3: コンテナ再起動

HTTP テスト・ブラウザテストに備え、コンテナを再起動して Puma を復帰させる。

```bash
docker restart {Container}
```

### フェーズ 4: HTTP テスト・ブラウザテスト

- [3-1] 〜 [3-3] を実行する
- [4-1] 〜 [4-9] をブラウザで確認する

---

## 1. 登録確認テスト

### [1-1] 管理メニュー登録確認

```ruby
puts Redmine::MenuManager.items(:admin_menu).map(&:name).include?(:roadmap_displays)
```

**期待結果:** `true`

### [1-2] ルーティング確認

```ruby
routes = [
  { path: '/roadmap_displays', method: :get, expected: { controller: 'roadmap_displays', action: 'index' } },
  { path: '/roadmap_displays/new', method: :get, expected: { controller: 'roadmap_displays', action: 'new' } },
  { path: '/roadmap_displays', method: :post, expected: { controller: 'roadmap_displays', action: 'create' } },
  { path: '/roadmap_displays/1/edit', method: :get, expected: { controller: 'roadmap_displays', action: 'edit', id: '1' } },
  { path: '/roadmap_displays/1', method: :patch, expected: { controller: 'roadmap_displays', action: 'update', id: '1' } },
  { path: '/roadmap_displays/1', method: :delete, expected: { controller: 'roadmap_displays', action: 'destroy', id: '1' } },
  { path: '/roadmap_displays/matches', method: :get, expected: { controller: 'roadmap_displays', action: 'matches' } },
  { path: '/roadmap_displays/preview', method: :post, expected: { controller: 'roadmap_displays', action: 'preview' } },
]
results = routes.map do |r|
  recognized = Rails.application.routes.recognize_path(r[:path], method: r[:method])
  r[:expected].all? { |k, v| recognized[k].to_s == v.to_s }
end
puts results.all?
```

**期待結果:** `true`

### [1-3] モデル・テーブル確認

```ruby
puts RoadmapDisplay.table_exists?
puts RoadmapDisplay.respond_to?(:sorted)
puts RoadmapDisplay.new.respond_to?(:position)
```

**期待結果:** すべて `true`

### [1-4] フック登録確認

```ruby
listeners = Redmine::Hook.hook_listeners(:view_versions_show_bottom).map(&:class).map(&:name)
puts listeners.include?('RedmineStudioPlugin::RoadmapDisplay::Hooks')
listeners = Redmine::Hook.hook_listeners(:view_projects_roadmap_version_bottom).map(&:class).map(&:name)
puts listeners.include?('RedmineStudioPlugin::RoadmapDisplay::Hooks')
```

**期待結果:** すべて `true`

### [1-5] ヘルパーパッチ確認

```ruby
puts QueriesHelper.instance_methods.include?(:column_content_with_roadmap_display)
puts VersionsController._helpers.ancestors.include?(QueriesHelper)
puts VersionsController._helpers.ancestors.include?(SortHelper)
```

**期待結果:** すべて `true`

---

## 2. 機能テスト

### セットアップ

```ruby
ActiveRecord::Base.transaction do
  RoadmapDisplay.delete_all
  project_a = Project.create!(identifier: "rd-test-a-#{SecureRandom.hex(3)}", name: 'RD Test A',
                              tracker_ids: Tracker.pluck(:id), enabled_module_names: %w[issue_tracking roadmap])
  project_b = Project.create!(identifier: "rd-other-#{SecureRandom.hex(3)}", name: 'RD Other',
                              tracker_ids: Tracker.pluck(:id), enabled_module_names: %w[issue_tracking roadmap])
  version = project_a.versions.create!(name: 'RD v1')
  User.current = User.where(admin: true).first
  closed = IssueStatus.where(is_closed: true).first
  open = IssueStatus.where(is_closed: false).first
  t1, t2 = Tracker.first(2)
  [[t1, open], [t1, closed], [t2, open]].each_with_index do |(tracker, status), i|
    Issue.create!(project: project_a, tracker: tracker, status: status, subject: "rd issue #{i}",
                  author: User.current, fixed_version: version, priority: IssuePriority.first)
  end
  # 以下 [2-1] 〜 [2-8]
  raise ActiveRecord::Rollback
end
```

### [2-1] パターンが無いプロジェクトは標準のまま

```ruby
puts RoadmapDisplay.for_project(project_a).nil?
```

**期待結果:** `true`

### [2-2] 上から順に照合し、最初に当てはまったものを使う

```ruby
specific = RoadmapDisplay.create!(name: 'specific', project_pattern: '^rd-test-a-')
all = RoadmapDisplay.create!(name: 'all', project_pattern: '')
puts RoadmapDisplay.for_project(project_a) == specific
puts RoadmapDisplay.for_project(project_b) == all
specific.update!(position: 2)  # all を上へ
puts RoadmapDisplay.for_project(project_a) == all
```

**期待結果:** すべて `true`

### [2-3] 無効なパターンは照合されない

```ruby
all.update!(is_enabled: false)
puts RoadmapDisplay.for_project(project_b).nil?
puts RoadmapDisplay.for_project(project_a) == specific
all.update!(is_enabled: true)
```

**期待結果:** すべて `true`

### [2-4] 正規表現の検証

```ruby
d = RoadmapDisplay.new(name: 'bad', project_pattern: '^rd(')
puts d.valid? == false
puts d.errors[:project_pattern].any?
puts RoadmapDisplay.new(name: '', project_pattern: '').valid? == false
```

**期待結果:** すべて `true`

### [2-5] 該当プロジェクト（上のパターンに取られるものを分ける）

```ruby
# この時点の順序: all（1番目）→ specific（2番目）
m = specific.project_matches
puts m[:applied].empty?
puts m[:overridden].any? { |p, winner| p == project_a && winner == all }
```

**期待結果:** すべて `true`

### [2-6] 対象のチケット（すべて / 未完了のみ / 完了のみ）

```ruby
specific.update!(status_scope: 'all')
puts specific.build_query(version).issue_count == 3
specific.update!(status_scope: 'open')
puts specific.build_query(version).issue_count == 2
specific.update!(status_scope: 'closed')
puts specific.build_query(version).issue_count == 1
specific.update!(status_scope: 'all')
```

**期待結果:** すべて `true`

### [2-7] トラッカー・プロジェクトの絞り込み（ロードマップ画面・バージョン画面のトラッカー絞り込み用）

```ruby
puts specific.build_query(version, tracker_ids: [t1.id]).issue_count == 2
puts specific.build_query(version, project_ids: [project_b.id]).issue_count == 0
```

**期待結果:** すべて `true`

### [2-8] 列・グループ条件・並び順がクエリに反映される

```ruby
specific.update!(column_names: %w[tracker subject assigned_to], group_by: 'assigned_to',
                 sort_criteria: [%w[status asc]])
q = specific.build_query(version)
puts q.inline_columns.map(&:name).include?(:assigned_to)
puts q.group_by == 'assigned_to'
puts q.sort_criteria.to_a == [%w[status asc]]
puts specific.copy.name.include?('specific')
```

**期待結果:** すべて `true`

---

## 3. HTTP テスト

管理者でログインしたセッション（または管理者の API キーではなくブラウザのセッション）で確認する。いずれも HTML 画面のため、curl 等で確認する場合はログイン済みの Cookie を使う。

### [3-1] 画面が 500 にならない

| 画面 | パス | 期待結果 |
|------|------|----------|
| 一覧 | `GET /roadmap_displays` | 200 |
| 新規 | `GET /roadmap_displays/new` | 200 |
| コピー | `GET /roadmap_displays/new?copy_from={id}` | 200、名前が「{元の名前} のコピー」 |
| 編集 | `GET /roadmap_displays/{id}/edit` | 200 |
| 該当プロジェクト | `GET /roadmap_displays/matches?project_pattern=^a` | 200 |
| 該当プロジェクト（不正な正規表現） | `GET /roadmap_displays/matches?project_pattern=^a(` | 200、「正規表現の書き方が正しくありません。」 |
| バージョン画面 | `GET /versions/{id}` | 200（パターンあり・なしの両方） |
| ロードマップ画面 | `GET /projects/{identifier}/roadmap` | 200（パターンあり・なしの両方） |

### [3-2] 管理者以外は管理画面に入れない

一般ユーザーで `GET /roadmap_displays` → 403

### [3-3] 並び替え（つまみのドラッグ）の保存

`PUT /roadmap_displays/{id}.js` に `roadmap_display[position]=1` を送ると 200 が返り、一覧の順序が変わる。列などの他の設定は変わらない。

---

## 4. ブラウザテスト

V5.1 / V6.1 / V7.0 で確認する。

| ID | 確認内容 | 期待結果 |
|----|----------|----------|
| [4-1] | 管理メニューに「ロードマップ表示」が出る | アイコン付きで表示。V7.0 では選択中の項目のアイコン位置が他の項目とそろう |
| [4-2] | 新規作成でプロジェクトパターンを入力 | 入力に合わせて該当プロジェクトが表示される。上のパターンに取られるものは「対象外」、不正な正規表現は赤字で保存できない |
| [4-3] | 項目・グループ条件・ソート条件・合計を選んで保存 | 一覧に戻り、該当プロジェクトの件数と名前が表示される |
| [4-4] | プレビュー | バージョンを選ぶと、保存前の内容で一覧が表示される（表が崩れない） |
| [4-5] | バージョン画面 | 「関連するチケット」の位置に設定した一覧が出る。グループの見出しと件数、終了チケットの取り消し線、担当者のアバター（V6.0 以降）、右クリックメニュー、列見出しでの並び替えが動く |
| [4-6] | 標準の一覧「隠す / 下に残す」 | 「隠す」では標準の一覧がちらつかずに消える。「下に残す」では設定した一覧の下に標準の一覧が出る |
| [4-7] | バージョン画面のトラッカー絞り込み | 右側（トラッカー別のチケットの下）に、そのバージョンにあるトラッカーだけが全部チェック済みで出る。外すとすぐ絞り込まれ、URL と列見出しの並び替えリンクに残る |
| [4-8] | ロードマップ画面 | バージョンごとに設定した一覧に置き換わる。サイドバーのトラッカーとサブプロジェクトの絞り込みに従う |
| [4-9] | 並び替え | 一覧のつまみをドラッグすると順序が保存され、バージョン画面で使われるパターンが変わる |

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいて以下の順序でテストを実行する:

1. フェーズ 0: Puma 停止（SQLite ロック回避）
2. フェーズ 1: 登録確認テスト実行（バッチ 1）
3. フェーズ 2: 機能テスト実行（バッチ 2）
4. フェーズ 3: コンテナ再起動
5. フェーズ 4: HTTP テスト・ブラウザテスト

テストデータの管理は CLAUDE.md の「テストデータの管理」ルールに従う。
