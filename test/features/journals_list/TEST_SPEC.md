# Journals List（更新履歴）テスト仕様書

## 概要

チケット一覧に「更新履歴」ブロックカラムを追加する機能のテスト仕様。チケットのコメント一覧を折りたたみ/展開可能なテーブル形式で表示する。展開時のコンテンツは AJAX で遅延ロードする。

## 環境パラメータ

パスから自動判定:
- `redmine_5.1.11` → コンテナ名: `redmine_5.1.11`, ポート: `3051`
- `redmine_6.1.1` → コンテナ名: `redmine_6.1.1`, ポート: `3061`

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| カラム名 | `:journals_list` |
| カラムクラス | `RedmineStudioPlugin::JournalsList::QueryColumn` |
| Issue パッチ | `RedmineStudioPlugin::JournalsList::IssuePatch` |
| IssueQuery パッチ | `RedmineStudioPlugin::JournalsList::IssueQueryPatch` |
| QueriesHelper パッチ | `RedmineStudioPlugin::JournalsList::QueriesHelperPatch` |
| コントローラー | `JournalsListController` |
| ロケールファイル | `config/locales/journals_list_ja.yml`, `config/locales/journals_list_en.yml` |

### AJAX エンドポイント

| エンドポイント | メソッド | 用途 |
|---------------|---------|------|
| `/journals_list/:id` | GET | 単一ジャーナルの Wiki レンダリング結果を返す |
| `/journals_list/show_all?ids[]=...` | GET | 複数ジャーナルの Wiki レンダリング結果を JSON で一括返す |

---

## 1. Runner テスト

### [1-1] カラムクラス定義確認

**確認方法:**
```ruby
puts defined?(RedmineStudioPlugin::JournalsList::QueryColumn)
```

**期待結果:** `constant` が出力される

### [1-2] Issue パッチ適用確認

**確認方法:**
```ruby
puts Issue.included_modules.map(&:name).include?('RedmineStudioPlugin::JournalsList::IssuePatch')
```

**期待結果:** `true` が出力される

### [1-3] IssueQuery パッチ適用確認

**確認方法:**
```ruby
puts IssueQuery.ancestors.map(&:name).include?('RedmineStudioPlugin::JournalsList::IssueQueryPatch')
```

**期待結果:** `true` が出力される

### [1-4] QueriesHelper パッチ適用確認

**確認方法:**
```ruby
puts QueriesHelper.instance_methods.include?(:column_content_with_journals_list)
```

**期待結果:** `true` が出力される

### [1-5] カラム登録確認

**確認方法:**
```ruby
col = IssueQuery.available_columns.find { |c| c.name == :journals_list }
puts "found: #{col ? true : false}"
puts "inline: #{col ? col.inline? : 'N/A'}"
```

**期待結果:**
- `found: true`
- `inline: false`

### [1-6] カラムがブロックカラムとして動作する

**確認方法:**
```ruby
q = IssueQuery.new(name: 'test', filters: {})
q.column_names = [:id, :subject, :journals_list]
puts "inline: #{q.inline_columns.map { |c| c.name.to_s }.join(', ')}"
puts "block: #{q.block_columns.map { |c| c.name.to_s }.join(', ')}"
```

**期待結果:**
- `inline: id, subject`
- `block: journals_list`

### [1-7] ロケールファイル存在確認

**確認方法:**
```ruby
files = [
  'config/locales/journals_list_ja.yml',
  'config/locales/journals_list_en.yml'
]
files.each do |f|
  path = Rails.root.join('plugins', 'redmine_studio_plugin', f)
  puts "#{f}: #{File.exist?(path)}"
end
```

**期待結果:** すべて `true`

### [1-8] ロケールキー確認

**確認方法:**
```ruby
I18n.locale = :ja
puts "field_journals_list: #{I18n.t(:field_journals_list)}"
puts "label_journals_list_author: #{I18n.t(:label_journals_list_author)}"
puts "label_journals_list_date: #{I18n.t(:label_journals_list_date)}"
puts "label_journals_list_notes: #{I18n.t(:label_journals_list_notes)}"
puts "label_journals_list_show_detail: #{I18n.t(:label_journals_list_show_detail)}"
puts "label_journals_list_hide_detail: #{I18n.t(:label_journals_list_hide_detail)}"
puts "label_journals_list_show_all: #{I18n.t(:label_journals_list_show_all)}"
puts "label_journals_list_hide_all: #{I18n.t(:label_journals_list_hide_all)}"
```

**期待結果:**
- `field_journals_list: 更新履歴`
- `label_journals_list_author: 更新者`
- `label_journals_list_date: 更新日`
- `label_journals_list_notes: コメント`
- `label_journals_list_show_detail: 詳細を表示`
- `label_journals_list_hide_detail: 詳細を隠す`
- `label_journals_list_show_all: すべての詳細を表示`
- `label_journals_list_hide_all: すべての詳細を隠す`

### [1-9] Issue#visible_journals_with_notes の動作確認

**確認方法:**
```ruby
# テストデータ作成
project = Project.first
issue = Issue.create(project: project, tracker: project.trackers.first, subject: 'JL_1-9_Test', author: User.find(1))
Journal.create(journalized: issue, user: User.find(1), notes: 'Test comment 1')
Journal.create(journalized: issue, user: User.find(1), notes: 'Test comment 2')
# ノートなしジャーナル（属性変更のみ）
Journal.create(journalized: issue, user: User.find(1), notes: '')

User.current = User.find(1)
journals = issue.visible_journals_with_notes
puts "count: #{journals.size}"
puts "all_have_notes: #{journals.all? { |j| j.notes.present? }}"
puts "note_numbers_set: #{journals.all? { |j| j.instance_variable_get(:@note_number).is_a?(Integer) }}"
```

**期待結果:**
- `count: 2`（ノートありのみ）
- `all_have_notes: true`
- `note_numbers_set: true`

### [1-10] プライベートコメントのフィルタリング確認

**確認方法:**
```ruby
project = Project.first
issue = Issue.create(project: project, tracker: project.trackers.first, subject: 'JL_1-10_PrivateTest', author: User.find(1))
Journal.create(journalized: issue, user: User.find(1), notes: 'Public comment')
Journal.create(journalized: issue, user: User.find(1), notes: 'Private comment', private_notes: true)

# 管理者（プライベートコメント参照可能）
User.current = User.find(1)
admin_journals = issue.visible_journals_with_notes
puts "admin_count: #{admin_journals.size}"

# プライベートコメント参照不可のユーザー
user = User.where(admin: false).where(status: 1).first
User.current = user
role = Role.find_by(name: 'Manager') || Role.first
Member.create(user: user, project: project, roles: [role]) unless Member.where(user: user, project: project).exists?
user_journals = issue.visible_journals_with_notes
puts "user_count: #{user_journals.size}"

User.current = User.find(1)
```

**期待結果:**
- `admin_count: 2`（パブリック + プライベート）
- `user_count:` ユーザーの `:view_private_notes` 権限に応じた数値

### [1-11] 一括プリロード（N+1 対策）確認

**確認方法:**
```ruby
q = IssueQuery.new(name: 'test', filters: {})
q.column_names = [:id, :subject, :journals_list]
issues = q.issues(limit: 5)
preloaded = issues.select { |i| i.instance_variable_defined?(:@visible_journals_with_notes) }
puts "preloaded_count: #{preloaded.size}"
puts "total_issues: #{issues.size}"
```

**期待結果:**
- `preloaded_count` と `total_issues` が同じ値

### [1-12] ルーティング確認

**確認方法:**
```ruby
show_all_route = Rails.application.routes.recognize_path('/journals_list/show_all')
puts "show_all_action: #{show_all_route[:action]}"

show_route = Rails.application.routes.recognize_path('/journals_list/123')
puts "show_action: #{show_route[:action]}"
puts "show_id: #{show_route[:id]}"
```

**期待結果:**
- `show_all_action: show_all`
- `show_action: show`
- `show_id: 123`

---

## 2. HTTP テスト

### チケット一覧の HTML 出力

### [2-1] チケット一覧で journals_list カラムを指定して表示できる

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:{ポート}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
```

**期待結果:** `200`

### [2-2] コメント付きチケットで journals-list テーブルが出力される

**前提条件:**
- コメント付きジャーナルを持つチケットが存在すること（チケットID を `{ISSUE_ID}` とする）

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:{ポート}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list&f[]=issue_id&op[issue_id]==&v[issue_id][]={ISSUE_ID}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'journals-list'
```

**期待結果:** `True`

### [2-3] テーブルのセル構造が正しい

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$response.Content -match 'class="jl-note"'
$response.Content -match 'class="jl-author"'
$response.Content -match 'class="jl-date"'
$response.Content -match 'class="jl-preview"'
$response.Content -match 'class="jl-toggle"'
```

**期待結果:** すべて `True`

### [2-4] コメントなしチケットでは journals-list が出力されない

**前提条件:**
- コメントなしのチケットが存在すること（チケットID を `{NO_COMMENT_ID}` とする）

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:{ポート}/issues?set_filter=1&c[]=id&c[]=subject&c[]=journals_list&f[]=issue_id&op[issue_id]==&v[issue_id][]={NO_COMMENT_ID}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'journals-list'
```

**期待結果:** `False`

### [2-5] ブロックカラムとして block_column クラスが付与される

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$response.Content -match 'journals_list block_column'
```

**期待結果:** `True`

### [2-6] チケット一覧カラムオプションに journals_list が表示される

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:{ポート}/issues?set_filter=1' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.Content -match 'journals_list'
```

**期待結果:** `True`

### [2-7] コメント番号のリンクが正しいアンカーを持つ

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$response.Content -match 'href="/issues/{ISSUE_ID}#note-'
```

**期待結果:** `True`

### [2-8] 投稿者名がユーザーページへのリンクになっている

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$response.Content -match 'href="/users/\d+"'
```

**期待結果:** `True`

### [2-9] 折りたたみ/展開ボタンと AJAX 用属性が出力される

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$response.Content -match 'jl-expand-btn'
$response.Content -match 'jl-collapse-btn'
$response.Content -match 'data-journal-id'
```

**期待結果:** すべて `True`

### [2-10] ソート用の data 属性が出力される

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$response.Content -match 'data-sort-col'
$response.Content -match 'data-sort-keys'
```

**期待結果:** 両方 `True`

### [2-11] CSS と JavaScript が出力される

**確認方法:**
```powershell
# [2-2] と同じリクエスト
$response.Content -match 'table\.journals-list'
$response.Content -match 'jl-context-menu'
$response.Content -match 'expandJournal'
```

**期待結果:** すべて `True`

### AJAX エンドポイント

### [2-12] JournalsListController#show - 単一ジャーナル取得

**前提条件:**
- コメント付きジャーナルが存在すること（ジャーナル ID を `{JOURNAL_ID}` とする）

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:{ポート}/journals_list/{JOURNAL_ID}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
$response.Headers['Content-Type']
```

**期待結果:**
- ステータスコード: `200`
- Content-Type: `text/html` を含む

### [2-13] JournalsListController#show - Wiki レンダリング確認

**前提条件:**
- Wiki 記法を含むコメントを持つジャーナルが存在すること

**確認方法:**
```powershell
# [2-12] と同じリクエスト
$response.Content.Length -gt 0
```

**期待結果:** `True`（空でないレスポンス）

### [2-14] JournalsListController#show_all - 複数ジャーナル一括取得

**前提条件:**
- 複数のコメント付きジャーナルが存在すること（ID を `{JID1}`, `{JID2}` とする）

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:{ポート}/journals_list/show_all?ids[]={JID1}&ids[]={JID2}' `
  -Credential $cred -AllowUnencryptedAuthentication
$response.StatusCode
$response.Headers['Content-Type']
$json = $response.Content | ConvertFrom-Json
$json.PSObject.Properties.Name
```

**期待結果:**
- ステータスコード: `200`
- Content-Type: `application/json` を含む
- JSON のキーに `{JID1}`, `{JID2}` が含まれる

### [2-15] JournalsListController#show - 存在しない ID で 404 エラー

**確認方法:**
```powershell
$cred = New-Object PSCredential('admin', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
try {
  Invoke-WebRequest -Uri 'http://localhost:{ポート}/journals_list/999999' `
    -Credential $cred -AllowUnencryptedAuthentication
} catch {
  $_.Exception.Response.StatusCode.Value__
}
```

**期待結果:** `404`

### [2-16] JournalsListController#show - チケット閲覧権限なしで 403 エラー

**前提条件:**
- 権限のないユーザーが存在すること
- そのユーザーが閲覧できないプロジェクトのジャーナルが存在すること（ID を `{JOURNAL_ID}` とする）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{権限なしユーザー}', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
try {
  Invoke-WebRequest -Uri 'http://localhost:{ポート}/journals_list/{JOURNAL_ID}' `
    -Credential $cred -AllowUnencryptedAuthentication
} catch {
  $_.Exception.Response.StatusCode.Value__
}
```

**期待結果:** `403`

### [2-17] JournalsListController#show_all - 権限フィルタリング

**前提条件:**
- 権限のないユーザーが存在すること
- アクセス可能なジャーナル（ID: `{ACCESSIBLE_JID}`）とアクセス不可のジャーナル（ID: `{RESTRICTED_JID}`）が存在すること

**確認方法:**
```powershell
$cred = New-Object PSCredential('{権限なしユーザー}', (ConvertTo-SecureString 'password123' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri 'http://localhost:{ポート}/journals_list/show_all?ids[]={ACCESSIBLE_JID}&ids[]={RESTRICTED_JID}' `
  -Credential $cred -AllowUnencryptedAuthentication
$json = $response.Content | ConvertFrom-Json
$json.PSObject.Properties.Name
```

**期待結果:** `{ACCESSIBLE_JID}` のみが含まれる（`{RESTRICTED_JID}` は除外される）

---

## 3. ブラウザテスト

### セットアップデータ

以下のデータが必要。テスト環境に存在しなければ作成する。

**チケット:**

| テストID | subject | コメント数 | 備考 |
|---------|---------|-----------|------|
| 用途 | JL_Browser_TestIssue | 3件以上 | 複数ユーザーによるコメント |

**コメント:**

| # | 投稿者 | 内容 |
|---|--------|------|
| 1 | admin | レビュー指摘（複数行、Wiki 記法あり） |
| 2 | 一般ユーザー | 修正報告 |
| 3 | admin | 確認完了 |

### [3-1] 折りたたみ/展開操作

**手順:**
1. admin でログイン
2. チケット一覧で `journals_list` カラムを有効にし、テストチケットを表示
3. コメント #1 の「表示」リンクをクリック

**確認1:** コメント #1 の詳細（Wiki レンダリングされた全文）が展開される

4. コメント #1 の「隠す」リンクをクリック

**確認2:** コメント #1 の詳細が折りたたまれる

5. 再度コメント #1 の「表示」をクリック

**確認3:** AJAX リクエストなしで即座に展開される（キャッシュ動作）

### [3-2] ソート操作

**手順:**
1. 「更新者」ヘッダーをクリック

**確認1:** コメントが更新者名の昇順でソートされる。ソートアイコンが表示される

2. 再度「更新者」ヘッダーをクリック

**確認2:** 降順に切り替わる。ソートアイコンが変わる

3. 「#」ヘッダーをクリック

**確認3:** コメント番号の昇順でソートされる。「更新者」のソートアイコンが消える

### [3-3] 右クリックコンテキストメニュー

**手順:**
1. 折りたたまれたコメントのヘッダー行を右クリック

**確認1:** 「詳細を表示」が表示される（`＞` 右向きアイコン付き）。「詳細を隠す」は表示されない

2. 「詳細を表示」をクリック → 展開されたコメントのヘッダー行を右クリック

**確認2:** 「詳細を隠す」が表示される（`＞` 下向きアイコン付き）。「詳細を表示」は表示されない

3. 展開されたコメントの詳細部分（Wiki レンダリング領域）を右クリック

**確認3:** ヘッダー行を右クリックした場合と同じメニューが表示される

### [3-4] すべての詳細を表示/隠す

**手順:**
1. すべて折りたたまれた状態で、任意のコメントを右クリック → 「すべての詳細を表示」

**確認1:** 同じチケットのすべてのコメントが展開される

2. 任意のコメントを右クリック → 「すべての詳細を隠す」

**確認2:** すべてのコメントが折りたたまれる

### [3-5] コンテキストメニューの閉じ動作と既存メニューとの排他

**手順:**
1. コメントを右クリックしてメニュー表示 → メニュー外をクリック

**確認1:** メニューが閉じる

2. コメントを右クリックしてメニュー表示 → チケット行（更新履歴外）を右クリック

**確認2:** 更新履歴メニューが閉じ、Redmine 標準メニューが表示される

3. Redmine 標準メニューが表示された状態で、コメントを右クリック

**確認3:** Redmine 標準メニューが閉じ、更新履歴メニューが表示される
