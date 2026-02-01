# 競合プラグイン検出テスト仕様書

## 概要

redmine_studio_plugin が統合する各機能と、元となるプラグインとの競合検出テスト。
競合プラグインが存在する場合、該当機能は無効化され、警告メッセージが表示される。

## 環境パラメータ

以下のパラメータは TEST_SPEC.md のパスから自動判定する:

| パラメータ | 判定方法 |
|-----------|----------|
| Container | パス内の `redmine_X.Y.Z` フォルダ名をそのまま使用 |

## 競合検出の仕様

| 機能 | モジュール名 | 競合プラグイン | 検出条件 |
|------|-------------|---------------|----------|
| Reply Button | `:reply_button` | `redmine_reply_button` | `plugins/redmine_reply_button/init.rb` が存在 |
| Teams Button | `:teams_button` | `redmine_teams_button` | `plugins/redmine_teams_button/init.rb` が存在 |

※ フォルダのみ存在し `init.rb` がない場合は競合とみなさない

## 競合検出時の動作

1. プラグインの description に `WARNING:` を含む警告メッセージを追加
2. 該当機能のモジュールを登録しない（権限が追加されない）

---

## 1. rails runner テスト

**実行方法:**
```bash
docker exec {Container} rails runner plugins/redmine_studio_plugin/test/conflict_detection/runner_test.rb
```

### Reply Button の競合検出

#### [1-1] 競合プラグインなし → 警告なし、モジュール登録あり

**事前条件:**
- `plugins/redmine_reply_button/init.rb` が存在しない

**確認方法:**
```ruby
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
has_warning = plugin.description.include?("WARNING") && plugin.description.include?("reply_button")
permissions = Redmine::AccessControl.permissions.select { |p| p.project_module == :reply_button }
```

**期待結果:**
- `has_warning` が false
- `permissions.any?` が true

**スキップ条件:**
- `plugins/redmine_reply_button/init.rb` が存在する場合

---

#### [1-2] 競合プラグインあり → 警告表示、モジュール登録なし

**事前条件:**
- `plugins/redmine_reply_button/init.rb` が存在する

**確認方法:**
```ruby
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
has_warning = plugin.description.include?("WARNING") && plugin.description.include?("reply_button")
permissions = Redmine::AccessControl.permissions.select { |p| p.project_module == :reply_button }
```

**期待結果:**
- `has_warning` が true
- `permissions.empty?` が true

**スキップ条件:**
- `plugins/redmine_reply_button/init.rb` が存在しない場合

---

#### [1-3] 空フォルダのみ（init.rb なし）→ 競合とみなさない

**事前条件:**
- `plugins/redmine_reply_button/` フォルダは存在するが `init.rb` がない

**確認方法:**
```ruby
plugins_dir = Rails.root.join('plugins')
folder_exists = File.directory?(plugins_dir.join('redmine_reply_button'))
init_exists = File.exist?(plugins_dir.join('redmine_reply_button', 'init.rb'))
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
has_warning = plugin.description.include?("WARNING") && plugin.description.include?("reply_button")
```

**期待結果:**
- `folder_exists` が true
- `init_exists` が false
- `has_warning` が false

**スキップ条件:**
- フォルダが存在しない、または init.rb が存在する場合

---

### Teams Button の競合検出

#### [2-1] 競合プラグインなし → 警告なし、モジュール登録あり

**事前条件:**
- `plugins/redmine_teams_button/init.rb` が存在しない

**確認方法:**
```ruby
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
has_warning = plugin.description.include?("WARNING") && plugin.description.include?("teams_button")
permissions = Redmine::AccessControl.permissions.select { |p| p.project_module == :teams_button }
```

**期待結果:**
- `has_warning` が false
- `permissions.any?` が true

**スキップ条件:**
- `plugins/redmine_teams_button/init.rb` が存在する場合
- Teams Button 機能が未実装の場合

---

#### [2-2] 競合プラグインあり → 警告表示、モジュール登録なし

**事前条件:**
- `plugins/redmine_teams_button/init.rb` が存在する

**確認方法:**
```ruby
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
has_warning = plugin.description.include?("WARNING") && plugin.description.include?("teams_button")
permissions = Redmine::AccessControl.permissions.select { |p| p.project_module == :teams_button }
```

**期待結果:**
- `has_warning` が true
- `permissions.empty?` が true

**スキップ条件:**
- `plugins/redmine_teams_button/init.rb` が存在しない場合
- Teams Button 機能が未実装の場合

---

#### [2-3] 空フォルダのみ（init.rb なし）→ 競合とみなさない

**事前条件:**
- `plugins/redmine_teams_button/` フォルダは存在するが `init.rb` がない

**確認方法:**
```ruby
plugins_dir = Rails.root.join('plugins')
folder_exists = File.directory?(plugins_dir.join('redmine_teams_button'))
init_exists = File.exist?(plugins_dir.join('redmine_teams_button', 'init.rb'))
plugin = Redmine::Plugin.find(:redmine_studio_plugin)
has_warning = plugin.description.include?("WARNING") && plugin.description.include?("teams_button")
```

**期待結果:**
- `folder_exists` が true
- `init_exists` が false
- `has_warning` が false

**スキップ条件:**
- フォルダが存在しない、または init.rb が存在する場合
- Teams Button 機能が未実装の場合

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいてコマンドを実行し、結果を報告する。

**注意事項:**
- 競合プラグインの有無によってテスト結果が変わるため、環境の状態を確認してからテストを実行する
- 競合プラグインをインストール/アンインストールした場合は、コンテナの再起動が必要
