# Setup Task テスト仕様書

## 概要

`rake redmine_studio_plugin:setup` タスクのテスト仕様。
このタスクはプラグインインストール後に実行され、統合済みプラグインの削除を行う。

## 環境パラメータ

以下のパラメータは TEST_SPEC.md のパスから自動判定する:

| パラメータ | 判定方法 |
|-----------|----------|
| Container | パス内の `redmine_X.Y.Z` フォルダ名をそのまま使用 |

## タスクの内部実装

| 項目 | 値 |
|------|-----|
| ファイル | `lib/tasks/setup.rake` |
| タスク名 | `redmine_studio_plugin:setup` |
| 統合済みプラグイン | `redmine_reply_button` |

### 処理フロー

1. ログ出力: `[redmine_studio_plugin] Setup task started`
2. 統合済みプラグインのフォルダを確認
3. 存在すれば削除、なければスキップ
4. 結果をログ出力
5. ログ出力: `[redmine_studio_plugin] Setup task completed`

### 出力メッセージ

| 条件 | stdout 出力 |
|------|-------------|
| プラグイン削除時 | `Removing {plugin}...` → `{plugin} removed.` |
| プラグインなし | `{plugin} not found (already removed or not installed).` |
| 削除あり | `{N} plugin(s) removed.` |
| 削除なし | `No plugins to remove.` |
| 常に | `Setup completed. Please restart Redmine to apply changes.` |

### ログ出力

| 条件 | ログメッセージ |
|------|---------------|
| 開始時 | `[redmine_studio_plugin] Setup task started` |
| 削除あり | `[redmine_studio_plugin] Removed plugins: {plugin1}, {plugin2}` |
| 削除なし | `[redmine_studio_plugin] No plugins to remove` |
| 完了時 | `[redmine_studio_plugin] Setup task completed` |

---

## テスト実行フロー

開発環境で統合済みプラグインが存在する場合に備え、テスト前に退避・テスト後に復元を行う。

### 1. 事前処理（退避）

```ruby
plugins_dir = Rails.root.join('plugins')
backup_dir = Rails.root.join('tmp', 'test_backup_plugins')
integrated_plugins = ['redmine_reply_button']

FileUtils.mkdir_p(backup_dir)
backed_up = []
skipped_empty = []

integrated_plugins.each do |plugin|
  plugin_path = plugins_dir.join(plugin)
  backup_path = backup_dir.join(plugin)
  if File.directory?(plugin_path)
    # 空フォルダはバックアップ対象外（復元しても意味がない）
    if Dir.empty?(plugin_path)
      skipped_empty << plugin
      puts "WARNING: #{plugin} folder is empty, skipping backup"
    else
      FileUtils.mv(plugin_path, backup_path)
      backed_up << plugin
      puts "Backed up: #{plugin}"
    end
  else
    puts "Not found (skip backup): #{plugin}"
  end
end
```

**注意:** 空フォルダは退避対象外とする。空フォルダを退避・復元しても意味がなく、
元のプラグインファイルが失われる原因となるため。

### 2. テスト実行

各テストケースを実行

### 3. 事後処理（復元）

```ruby
integrated_plugins.each do |plugin|
  backup_path = backup_dir.join(plugin)
  plugin_path = plugins_dir.join(plugin)
  if File.directory?(backup_path)
    FileUtils.rm_rf(plugin_path) if File.directory?(plugin_path)
    FileUtils.mv(backup_path, plugin_path)
  end
end
FileUtils.rm_rf(backup_dir)
```

---

## 1. rails runner テスト

**実行方法:**
```bash
docker exec {Container} rails runner plugins/redmine_studio_plugin/test/setup_task/runner_test.rb
```

### [1-1] 統合済みプラグインが存在する場合 → 削除される

**事前条件:**
- `plugins/redmine_reply_button/` フォルダを作成（ダミー）

**確認方法:**
```ruby
plugins_dir = Rails.root.join('plugins')
test_plugin = 'redmine_reply_button'
plugin_path = plugins_dir.join(test_plugin)

# ダミーフォルダ作成
FileUtils.mkdir_p(plugin_path)
FileUtils.touch(plugin_path.join('init.rb'))

# タスク実行
Rake::Task['redmine_studio_plugin:setup'].reenable
Rake::Task['redmine_studio_plugin:setup'].invoke

# 確認
File.directory?(plugin_path)
```

**期待結果:**
- `File.directory?(plugin_path)` が false（削除されている）

---

### [1-2] 統合済みプラグインが存在しない場合 → エラーなくスキップ

**事前条件:**
- `plugins/redmine_reply_button/` フォルダが存在しない

**確認方法:**
```ruby
plugins_dir = Rails.root.join('plugins')
test_plugin = 'redmine_reply_button'
plugin_path = plugins_dir.join(test_plugin)

# フォルダがないことを確認（退避済みのはず）
FileUtils.rm_rf(plugin_path) if File.directory?(plugin_path)

# タスク実行（エラーが発生しないこと）
Rake::Task['redmine_studio_plugin:setup'].reenable
Rake::Task['redmine_studio_plugin:setup'].invoke
```

**期待結果:**
- 例外が発生しない
- タスクが正常に完了する

---

### [1-3] ログに実行記録が残る

**確認方法（ファイルログの場合）:**
```ruby
# ログファイルのパス
log_file = Rails.root.join('log', "#{Rails.env}.log")

# 実行前のログサイズを記録
log_size_before = File.size(log_file)

# タスク実行
Rake::Task['redmine_studio_plugin:setup'].reenable
Rake::Task['redmine_studio_plugin:setup'].invoke

# ログの新規部分を読み取り
File.open(log_file) do |f|
  f.seek(log_size_before)
  new_log = f.read
  new_log.include?('[redmine_studio_plugin] Setup task started') &&
  new_log.include?('[redmine_studio_plugin] Setup task completed')
end
```

**Docker 環境での確認方法:**

Docker 環境ではログがファイルではなく stdout に出力される場合がある。
その場合、タスク実行時のコンソール出力で以下のログを目視確認する:

```
I, [2026-02-01T...] INFO -- : [redmine_studio_plugin] Setup task started
I, [2026-02-01T...] INFO -- : [redmine_studio_plugin] Setup task completed
```

**期待結果:**
- ログに `[redmine_studio_plugin] Setup task started` が含まれる
- ログに `[redmine_studio_plugin] Setup task completed` が含まれる

---

## テスト実行上の注意

### タスクの再実行

Rake タスクは一度実行すると「実行済み」としてマークされるため、
テストで複数回実行する場合は `reenable` を呼ぶ必要がある:

```ruby
Rake::Task['redmine_studio_plugin:setup'].reenable
Rake::Task['redmine_studio_plugin:setup'].invoke
```

---

## テスト実行方法

Claude が TEST_SPEC.md の仕様に基づいてコマンドを実行し、結果を報告する。

**実行順序:**
1. 事前処理（統合済みプラグインを退避）
2. 各テストケースを実行
3. 事後処理（退避したプラグインを復元）
