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

[2-W-*]〜[4-R-*] のデータは、2 章の頭の用意でその場で作る（後片付けで消す）。[5-V-1] は、試験用のプロジェクト・利用者を作って最後に消す（ほかの HTTP テストのデータには触らない）。

---

## セットアップデータ

2 章の頭の用意で作る。`<印>` は `SecureRandom.hex(3)` の 6 桁（JSON の `Sfx`）。

### プロジェクト

| 識別子 | 名前 |
|--------|------|
| wl-spec-<印> | WL_Spec_<印> |

### ユーザー

| ログインID | 名前 |
|-----------|------|
| wl_spec_<印> | Wiki List User<印> |

admin と一緒に、用意で作るロール（`WL_Spec_Role_<印>`）でプロジェクトのメンバーにする。

### トラッカー・ステータス

既存のトラッカーの並び順で先頭の 2 つ（以下 T1・T2）と、既存のステータス（新規＝並び順の先頭・進行中＝未完了の 2 つ目・終了＝完了の先頭）を使う。名前は JSON で渡す。

### Wikiページ

| ページ名 | 親ページ | 内容 |
|---------|---------|------|
| WikiListTest | - | `担当: 山田太郎`<br>`期間: 2024/01/01`<br>`〜 2024/12/31` |
| WikiListChild1 | WikiListTest | `担当: 佐藤花子`<br>`ステータス: 進行中` |
| WikiListChild2 | WikiListTest | `担当: 鈴木一郎`<br>`ステータス: 完了` |

リダイレクト: `WLT` → `WikiListTest`

マクロは各試験で `WLMacro` ページ（無ければ作られる）に書く。

### チケット

| 題名 | トラッカー | 担当者 | ステータス | 説明 |
|------|-----------|--------|-----------|------|
| IssueNameLinkTest_<印> | T1 | admin | 新規 | |
| RefIssuesTest1_<印> | T1 | admin | 新規 | |
| RefIssuesTest2_<印> | T1 | wl_spec_<印> | 進行中 | `説明に IssueNameLinkTest_<印> を含む` |
| RefIssuesTest3_<印> | T2 | admin | 終了 | |

### カスタムクエリ

| 名前 | 公開 | 条件 |
|------|------|------|
| WikiListTestQuery_<印> | はい | ステータス = 新規 |

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

**実行方法:** [2-W-*]・[3-I-*]・[4-R-*] は、下の用意で作ったプロジェクトの Wiki ページ（`WLMacro` など）にマクロを書き込み（`PUT /projects/{ProjectIdent}/wiki/<ページ>.json`）、そのページの HTML を管理者の API キーで取って確かめる。用意の JSON の名前（`{ProjectIdent}`・`{Sfx}` など）を各試験のブロックに入れて流す。

**用意（HTTP テストの前に 1 回）:** 「セットアップデータ」のプロジェクト・ユーザー・Wiki ページ・チケット・カスタムクエリを作る（前回の残りは先に消す）。最後の行に JSON を出す。

```ruby
# 前回の残りを消す
Project.where('identifier LIKE ?', 'wl-spec-%').order(id: :desc).each(&:destroy)
User.where('login LIKE ?', 'wl_spec_%').each(&:destroy)
Role.where('name LIKE ?', 'WL_Spec_%').each(&:destroy)
sfx = SecureRandom.hex(3)
admin = User.find(1)
user = User.new(login: "wl_spec_#{sfx}", firstname: 'Wiki List', lastname: "User#{sfx}", mail: "wl_spec_#{sfx}@example.com", status: User::STATUS_ACTIVE)
user.password = user.password_confirmation = "Pw-#{sfx}-x9Z"
user.save!
t1, t2 = Tracker.sorted.first(2)
st_new = IssueStatus.sorted.first
st_prog = IssueStatus.sorted.where(is_closed: false).where.not(id: st_new.id).first
st_closed = IssueStatus.sorted.where(is_closed: true).first
prj = Project.create!(name: "WL_Spec_#{sfx}", identifier: "wl-spec-#{sfx}", is_public: false, tracker_ids: [t1.id, t2.id])
prj.enabled_module_names = %w[issue_tracking wiki]
prj.save!
role = Role.create!(name: "WL_Spec_Role_#{sfx}", permissions: [:view_issues, :view_wiki_pages], assignable: true)
[admin, user].each { |u| Member.create!(principal: u, project: prj, roles: [role]) }
wiki = prj.wiki || Wiki.create!(project: prj, start_page: 'Wiki')
mk_page = ->(title, text, parent = nil) {
  page = WikiPage.new(wiki: wiki, title: title, parent: parent)
  page.content = WikiContent.new(page: page, text: text, author: admin)
  page.save!
  page
}
top = mk_page.call('WikiListTest', "担当: 山田太郎\n期間: 2024/01/01\n〜 2024/12/31")
mk_page.call('WikiListChild1', "担当: 佐藤花子\nステータス: 進行中", top)
mk_page.call('WikiListChild2', "担当: 鈴木一郎\nステータス: 完了", top)
WikiRedirect.create!(wiki: wiki, title: 'WLT', redirects_to: 'WikiListTest')
mk_issue = ->(subject, tracker, assignee, status, desc = '') {
  Issue.create!(project: prj, tracker: tracker, subject: "#{subject}_#{sfx}", author: admin, assigned_to: assignee, status: status, description: desc)
}
inl = mk_issue.call('IssueNameLinkTest', t1, admin, st_new)
r1 = mk_issue.call('RefIssuesTest1', t1, admin, st_new)
r2 = mk_issue.call('RefIssuesTest2', t1, user, st_prog, "説明に IssueNameLinkTest_#{sfx} を含む")
r3 = mk_issue.call('RefIssuesTest3', t2, admin, st_closed)
q = IssueQuery.new(name: "WikiListTestQuery_#{sfx}", project: prj, visibility: Query::VISIBILITY_PUBLIC, user: admin)
q.filters = { 'status_id' => { operator: '=', values: [st_new.id.to_s] } }
q.save!
puts({ Sfx: sfx, ProjectIdent: prj.identifier, ProjectName: prj.name, UserLogin: user.login, UserName: user.name,
       QueryId: q.id, QueryName: q.name, Tracker1: t1.name, Tracker2: t2.name,
       StatusNewId: st_new.id, StatusNew: st_new.name, StatusClosedId: st_closed.id, AdminName: admin.name,
       InlId: inl.id, R1Id: r1.id, R2Id: r2.id, R3Id: r3.id }.to_json)
```

**後片付け（HTTP テストのあとに 1 回）:**

```ruby
Project.where('identifier LIKE ?', 'wl-spec-%').order(id: :desc).each(&:destroy)
User.where('login LIKE ?', 'wl_spec_%').each(&:destroy)
Role.where('name LIKE ?', 'WL_Spec_%').each(&:destroy)
puts 'cleanup: ok'
```

### [2-W-1] +title カラム

**マクロ:** `{{wiki_list(-p, +title)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{wiki_list(-p, +title)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[2-W-1] " + $(if ($c.Contains('/projects/{ProjectIdent}/wiki/WikiListTest">WikiListTest</a>') -and $c.Contains('/projects/{ProjectIdent}/wiki/WikiListChild1">WikiListChild1</a>') -and $c.Contains('/projects/{ProjectIdent}/wiki/WikiListChild2">WikiListChild2</a>')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[2-W-1] PASS`（ページタイトル（WikiListTest・WikiListChild1・WikiListChild2）がページへのリンクとして表示される）

### [2-W-2] +alias カラム

**マクロ:** `{{wiki_list(-p, +title, +alias)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{wiki_list(-p, +title, +alias)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[2-W-2] " + $(if ($c.Contains('>WikiListTest</a></td><td>WLT</td>')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[2-W-2] PASS`（WikiListTest の行に別名 WLT が表示される）

### [2-W-3] +project カラム

**マクロ:** `{{wiki_list(-p, +title, +project)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{wiki_list(-p, +title, +project)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[2-W-3] " + $(if ($c.Contains('>WikiListTest</a></td><td>{ProjectName}</td>')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[2-W-3] PASS`（プロジェクト名が表示される）

### [2-W-4] -c オプション（子ページのみ）

**マクロ:** WikiListTest ページの最後に `{{wiki_list(-c, +title)}}` を足す（元の本文は残す）

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WikiListTest'
$body = @{ wiki_page = @{ text = "担当: 山田太郎`n期間: 2024/01/01`n〜 2024/12/31`n`n{{wiki_list(-c, +title)}}" } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[2-W-4] " + $(if ($c.Contains('/projects/{ProjectIdent}/wiki/WikiListChild1">WikiListChild1</a>') -and $c.Contains('/projects/{ProjectIdent}/wiki/WikiListChild2">WikiListChild2</a>') -and -not $c.Contains('>WikiListTest</a>') -and -not $c.Contains('>WLMacro</a>')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[2-W-4] PASS`（WikiListChild1, WikiListChild2 のみ表示。WikiListTest は除外）

### [2-W-5] -p オプション（現在のプロジェクト）

**マクロ:** `{{wiki_list(-p, +title)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{wiki_list(-p, +title)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[2-W-5] " + $(if ($c.Contains('>WikiListTest</a>') -and ([regex]::Matches($c, 'href="[^"]*/wiki/')).Count -eq ([regex]::Matches($c, 'href="[^"]*/projects/{ProjectIdent}/wiki/')).Count) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[2-W-5] PASS`（現在のプロジェクトの Wiki ページだけが表示される（ページへのリンクがすべて現在のプロジェクトのもの））

### [2-W-6] -p=PROJECT オプション

**マクロ:** `{{wiki_list(-p={ProjectName}, +title)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{wiki_list(-p={ProjectName}, +title)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[2-W-6] " + $(if ($c.Contains('>WikiListTest</a>') -and ([regex]::Matches($c, 'href="[^"]*/wiki/')).Count -eq ([regex]::Matches($c, 'href="[^"]*/projects/{ProjectIdent}/wiki/')).Count) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[2-W-6] PASS`（指定プロジェクトの Wiki ページだけが表示される）

### [2-W-7] -w=WIDTH オプション

**マクロ:** `{{wiki_list(-p, -w=80%, +title)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{wiki_list(-p, -w=80%, +title)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[2-W-7] " + $(if ($c.Contains('<table width="80%">')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[2-W-7] PASS`（`<table width="80%">` が出力される）

### [2-W-8] キーワード抽出（行末まで）

**マクロ:** `{{wiki_list(-p, +title, 担当:)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{wiki_list(-p, +title, 担当:)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[2-W-8] " + $(if ($c.Contains('<th>担当:</th>') -and $c.Contains('山田太郎') -and $c.Contains('佐藤花子') -and $c.Contains('鈴木一郎')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[2-W-8] PASS`（「担当:」の後のテキスト（山田太郎・佐藤花子・鈴木一郎）が表示される）

### [2-W-9] キーワード抽出（終端文字まで）

**マクロ:** `{{wiki_list(-p, +title, 期間:\〜)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{wiki_list(-p, +title, 期間:\〜)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[2-W-9] " + $(if ($c.Contains('2024/01/01') -and -not $c.Contains('2024/12/31')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[2-W-9] PASS`（「期間:」から「〜」までのテキスト（2024/01/01）が表示され、「〜」の後（2024/12/31）は表示されない）

### [2-W-10] カラム名カスタマイズ

**マクロ:** `{{wiki_list(-p, +title, 担当:|責任者)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{wiki_list(-p, +title, 担当:|責任者)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[2-W-10] " + $(if ($c.Contains('<th>責任者</th>') -and $c.Contains('山田太郎')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[2-W-10] PASS`（カラムヘッダーが「責任者」）

### [2-W-11] カラム名と幅のカスタマイズ

**マクロ:** `{{wiki_list(-p, +title, 担当:|責任者|150px)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{wiki_list(-p, +title, 担当:|責任者|150px)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[2-W-11] " + $(if ($c.Contains('<th width="150px">責任者</th>')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[2-W-11] PASS`（ヘッダー「責任者」、幅 150px）

### [2-W-12] エラー: パラメータなし

**マクロ:** `{{wiki_list()}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{wiki_list()}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[2-W-12] " + $(if ($c -match 'flash error' -and $c.Contains('no parameters') -and $c.Contains('usage:')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[2-W-12] PASS`（エラーメッセージ（usage）が表示）

### [2-W-13] エラー: 不明なオプション

**マクロ:** `{{wiki_list(-x, +title)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{wiki_list(-x, +title)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[2-W-13] " + $(if ($c -match 'flash error' -and $c.Contains('unknown option: -x')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[2-W-13] PASS`（`unknown option: -x` エラー）

---

## 3. HTTP テスト - issue_name_link

### [3-I-1] 基本的な使用

**マクロ:** `{{issue_name_link(IssueNameLinkTest_{Sfx})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{issue_name_link(IssueNameLinkTest_{Sfx})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[3-I-1] " + $(if ($c -match '/issues/{InlId}">IssueNameLinkTest_{Sfx}</a>') { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[3-I-1] PASS`（チケットへのリンクが生成、表示テキストは題名）

### [3-I-2] 表示テキスト指定

**マクロ:** `{{issue_name_link(IssueNameLinkTest_{Sfx}|テストリンク)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{issue_name_link(IssueNameLinkTest_{Sfx}|テストリンク)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[3-I-2] " + $(if ($c -match '/issues/{InlId}">テストリンク</a>') { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[3-I-2] PASS`（リンクテキストが「テストリンク」）

### [3-I-3] プロジェクト指定

**マクロ:** `{{issue_name_link({ProjectIdent}:IssueNameLinkTest_{Sfx})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{issue_name_link({ProjectIdent}:IssueNameLinkTest_{Sfx})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[3-I-3] " + $(if ($c -match '/issues/{InlId}">IssueNameLinkTest_{Sfx}</a>') { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[3-I-3] PASS`（指定プロジェクトのチケットへのリンク）

### [3-I-4] プロジェクトと表示テキスト両方

**マクロ:** `{{issue_name_link({ProjectIdent}:IssueNameLinkTest_{Sfx}|リンク)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{issue_name_link({ProjectIdent}:IssueNameLinkTest_{Sfx}|リンク)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[3-I-4] " + $(if ($c -match '/issues/{InlId}">リンク</a>') { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[3-I-4] PASS`（プロジェクト指定＋カスタム表示テキスト）

### [3-I-5] エラー: パラメータなし

**マクロ:** `{{issue_name_link()}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{issue_name_link()}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[3-I-5] " + $(if ($c -match 'flash error' -and $c.Contains('no parameters')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[3-I-5] PASS`（`no parameters` エラー）

### [3-I-6] エラー: パラメータ過多

**マクロ:** `{{issue_name_link(a, b)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{issue_name_link(a, b)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[3-I-6] " + $(if ($c -match 'flash error' -and $c.Contains('too many parameters')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[3-I-6] PASS`（`too many parameters` エラー）

### [3-I-7] エラー: チケットが見つからない

**マクロ:** `{{issue_name_link(NonExistentIssue)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{issue_name_link(NonExistentIssue)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[3-I-7] " + $(if ($c -match 'flash error' -and $c.Contains('issue:NonExistentIssue is not found')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[3-I-7] PASS`（`issue:NonExistentIssue is not found` エラー）

### [3-I-8] エラー: プロジェクトが見つからない

**マクロ:** `{{issue_name_link(nonexistent:SomeIssue)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{issue_name_link(nonexistent:SomeIssue)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[3-I-8] " + $(if ($c -match 'flash error' -and $c.Contains('project:nonexistent is not found')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[3-I-8] PASS`（`project:nonexistent is not found` エラー）

---

## 4. HTTP テスト - ref_issues

### 基本機能

#### [4-R-1] デフォルト動作

**マクロ:** Wikiページ「RefIssuesTest1_{Sfx}」に `{{ref_issues()}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/RefIssuesTest1_{Sfx}'
$body = @{ wiki_page = @{ text = '{{ref_issues()}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-1] " + $(if ($set -eq 'RefIssuesTest1') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-1] PASS`（ページ名（RefIssuesTest1_…）を含むチケットだけが一覧表示）

#### [4-R-2] -i オプション（クエリID）

**マクロ:** `{{ref_issues(-i={QueryId})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-i={QueryId})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-2] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-2] PASS`（指定クエリ（新規のみ）の結果が表示）

#### [4-R-3] -q オプション（クエリ名）

**マクロ:** `{{ref_issues(-q={QueryName})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-q={QueryName})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-3] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-3] PASS`（「WikiListTestQuery_…」（新規のみ）の結果が表示）

### プロジェクト制限

#### [4-R-4] -p オプション

**マクロ:** `{{ref_issues(-p)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
$rows = ([regex]::Matches($c, '<tr id="issue-')).Count
"[4-R-4] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1,RefIssuesTest2,RefIssuesTest3' -and $rows -eq 4) { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-4] PASS`（現在のプロジェクトのチケット 4 件のみ）

#### [4-R-5] -p=identifier オプション

**マクロ:** `{{ref_issues(-p={ProjectIdent})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p={ProjectIdent})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
$rows = ([regex]::Matches($c, '<tr id="issue-')).Count
"[4-R-5] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1,RefIssuesTest2,RefIssuesTest3' -and $rows -eq 4) { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-5] PASS`（指定プロジェクトのチケット 4 件のみ）

### 検索キーワード

#### [4-R-6] -s オプション（題名検索）

**マクロ:** `{{ref_issues(-s=RefIssuesTest1_{Sfx})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-s=RefIssuesTest1_{Sfx})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-6] " + $(if ($set -eq 'RefIssuesTest1') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-6] PASS`（題名に「RefIssuesTest1_…」を含むチケット）

#### [4-R-7] -d オプション（説明検索）

**マクロ:** `{{ref_issues(-d=IssueNameLinkTest_{Sfx})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-d=IssueNameLinkTest_{Sfx})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-7] " + $(if ($set -eq 'RefIssuesTest2') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-7] PASS`（説明にキーワードを含むチケット（RefIssuesTest2）だけ。題名に含む IssueNameLinkTest は出ない）

#### [4-R-8] -w オプション（題名＋説明）

**マクロ:** `{{ref_issues(-w=IssueNameLinkTest_{Sfx})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-w=IssueNameLinkTest_{Sfx})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-8] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest2') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-8] PASS`（題名に含む IssueNameLinkTest と、説明に含む RefIssuesTest2）

#### [4-R-9] 複数キーワード（OR）

**マクロ:** `{{ref_issues(-s=RefIssuesTest1_{Sfx}|RefIssuesTest2_{Sfx})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-s=RefIssuesTest1_{Sfx}|RefIssuesTest2_{Sfx})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-9] " + $(if ($set -eq 'RefIssuesTest1,RefIssuesTest2') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-9] PASS`（どちらかを含むチケット）

### フィルタ

#### [4-R-10] -f オプション（=演算子）

**マクロ:** `{{ref_issues(-f:status_id={StatusNewId})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-f:status_id={StatusNewId})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-10] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-10] PASS`（用意したチケットのうち、ステータスが新規のもの）

#### [4-R-11] -f:tracker（名前指定）

**マクロ:** `{{ref_issues(-f:tracker={Tracker1})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-f:tracker={Tracker1})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-11] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1,RefIssuesTest2') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-11] PASS`（用意したチケットのうち、1 つ目のトラッカーのもの）

#### [4-R-12] -f:status（名前指定）

**マクロ:** `{{ref_issues(-f:status={StatusNew})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-f:status={StatusNew})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-12] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-12] PASS`（用意したチケットのうち、ステータスが新規のもの）

#### [4-R-13] -f:assigned_to（名前指定）

**マクロ:** `{{ref_issues(-f:assigned_to=admin)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-f:assigned_to=admin)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-13] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1,RefIssuesTest3') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-13] PASS`（用意したチケットのうち、担当者が admin のもの）

#### [4-R-14] 複数フィルタ

**マクロ:** `{{ref_issues(-f:tracker={Tracker1}, -f:status={StatusNew})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-f:tracker={Tracker1}, -f:status={StatusNew})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-14] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-14] PASS`（両方の条件を満たすチケット）

#### [4-R-15] 演算子指定

**マクロ:** `{{ref_issues(-f:status_id ! {StatusClosedId})}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-f:status_id ! {StatusClosedId})}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-15] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1,RefIssuesTest2') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-15] PASS`（終了（RefIssuesTest3 のステータス）でないチケット）

### 表示形式

#### [4-R-16] -t オプション

**マクロ:** `{{ref_issues(-p, -t)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -t)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-16] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1,RefIssuesTest2,RefIssuesTest3' -and -not $c.Contains('<a ')) { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-16] PASS`（題名がプレーンテキストで表示（リンクなし））

#### [4-R-17] -t=column オプション

**マクロ:** `{{ref_issues(-p, -t=id)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -t=id)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-17] " + $(if ($c.Contains('<p>{InlId}</p>') -and $c.Contains('<p>{R3Id}</p>') -and -not $c.Contains('<a ')) { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-17] PASS`（ID がテキストで表示（リンクなし））

#### [4-R-18] -l オプション

**マクロ:** `{{ref_issues(-p, -l)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -l)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-18] " + $(if ($c -match '/issues/{R1Id}">RefIssuesTest1_{Sfx}</a>' -and $set -eq 'IssueNameLinkTest,RefIssuesTest1,RefIssuesTest2,RefIssuesTest3' -and -not $c.Contains('<table')) { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-18] PASS`（題名がリンクとして表示（表は出ない））

#### [4-R-19] -l=column オプション

**マクロ:** `{{ref_issues(-p, -l=id)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -l=id)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-19] " + $(if ($c -match '/issues/{R1Id}">{R1Id}</a>' -and $c -match '/issues/{R3Id}">{R3Id}</a>') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-19] PASS`（ID がリンクとして表示）

#### [4-R-20] -c オプション（件数）

**マクロ:** `{{ref_issues(-p, -c)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -c)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
$txt = ($c -replace '<[^>]+>', '').Trim()
"[4-R-20] " + $(if ($txt -eq '4') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-20] PASS`（件数（4）のみが数字で表示）

#### [4-R-21] -0 オプション（0件非表示）

**マクロ:** `{{ref_issues(-f:subject ~ 存在しない_{Sfx}, -0)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-f:subject ~ 存在しない_{Sfx}, -0)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
$txt = ($c -replace '<[^>]+>', '').Trim()
"[4-R-21] " + $(if ($txt -eq '' -and -not $c.Contains('<table')) { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-21] PASS`（0 件なので何も表示されない）

#### [4-R-22] -n オプション

**マクロ:** `{{ref_issues(-p, -n=2)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -n=2)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
$rows = ([regex]::Matches($c, '<tr id="issue-')).Count
"[4-R-22] " + $(if ($rows -eq 2) { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-22] PASS`（最大 2 件のみ表示）

### カラム指定

#### [4-R-23] 単一カラム

**マクロ:** `{{ref_issues(-p, subject)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, subject)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
$cols = ([regex]::Matches($c, '<th class="([a-z_]+)"') | ForEach-Object { $_.Groups[1].Value }) -join ','
"[4-R-23] " + $(if ($cols -eq 'id,subject') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-23] PASS`（題名カラムのみ（# の列はいつも付く））

#### [4-R-24] 複数カラム

**マクロ:** `{{ref_issues(-p, id, subject, status)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, id, subject, status)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
$cols = ([regex]::Matches($c, '<th class="([a-z_]+)"') | ForEach-Object { $_.Groups[1].Value }) -join ','
"[4-R-24] " + $(if ($cols -eq 'id,subject,status') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-24] PASS`（指定 3 カラムが順番に表示）

### 特殊変数

#### [4-R-25] [current_user]

**マクロ:** `{{ref_issues(-f:assigned_to=[current_user])}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-f:assigned_to=[current_user])}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-25] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1,RefIssuesTest3') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-25] PASS`（用意したチケットのうち、現在のユーザー（admin）が担当のもの）

#### [4-R-26] [current_project_id]

**マクロ:** `{{ref_issues(-f:project_id=[current_project_id])}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-f:project_id=[current_project_id])}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
$rows = ([regex]::Matches($c, '<tr id="issue-')).Count
"[4-R-26] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1,RefIssuesTest2,RefIssuesTest3' -and $rows -eq 4) { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-26] PASS`（現在のプロジェクトのチケット 4 件）

#### [4-R-27] [Ndays_ago]

**マクロ:** `{{ref_issues(-f:created_on >= [7days_ago])}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-f:created_on >= [7days_ago])}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-27] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1,RefIssuesTest2,RefIssuesTest3') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-27] PASS`（過去 7 日以内に作成されたチケット（用意した 4 件を含む））

### 並び順・グループ

#### [4-R-36] -o オプション（昇順）

**マクロ:** `{{ref_issues(-p, -o=subject, subject)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -o=subject, subject)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-36] " + $(if ($o -eq 'IssueNameLinkTest,RefIssuesTest1,RefIssuesTest2,RefIssuesTest3') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-36] PASS`（IssueNameLinkTest、RefIssuesTest1、RefIssuesTest2、RefIssuesTest3 の順に表示）

#### [4-R-37] -o オプション（降順）

**マクロ:** `{{ref_issues(-p, -o=subject:desc, subject)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -o=subject:desc, subject)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-37] " + $(if ($o -eq 'RefIssuesTest3,RefIssuesTest2,RefIssuesTest1,IssueNameLinkTest') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-37] PASS`（RefIssuesTest3、RefIssuesTest2、RefIssuesTest1、IssueNameLinkTest の順に表示）

#### [4-R-38] -o オプション（複数カラム）

**マクロ:** `{{ref_issues(-p, -o=tracker|subject:desc, tracker, subject)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -o=tracker|subject:desc, tracker, subject)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-38] " + $(if ($o -eq 'RefIssuesTest2,RefIssuesTest1,IssueNameLinkTest,RefIssuesTest3') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-38] PASS`（トラッカーの順（管理画面のトラッカーの並び順）に並び、同じトラッカーの中は題名の降順（RefIssuesTest2、RefIssuesTest1、IssueNameLinkTest、RefIssuesTest3））

#### [4-R-39] -g オプション

**マクロ:** `{{ref_issues(-p, -g=tracker, -o=subject)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -g=tracker, -o=subject)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
$g = ([regex]::Matches($c, '(?s)<span class="name">(.*?)</span>\s*<span class="[^"]*count[^"]*">(\d+)</span>') | ForEach-Object { ($_.Groups[1].Value -replace '<[^>]+>', '').Trim() + ':' + $_.Groups[2].Value }) -join ','
"[4-R-39] " + $(if ($g -eq '{Tracker1}:3,{Tracker2}:1' -and $o -eq 'IssueNameLinkTest,RefIssuesTest1,RefIssuesTest2,RefIssuesTest3') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-39] PASS`（トラッカーごとの見出しが表示される（1 つ目のトラッカー: 3件、2 つ目: 1件）。各グループの中は題名の昇順）

#### [4-R-40] -g オプション（担当者）

**マクロ:** `{{ref_issues(-p, -g=assigned_to)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -g=assigned_to)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
$g = ([regex]::Matches($c, '(?s)<span class="name">(.*?)</span>\s*<span class="[^"]*count[^"]*">(\d+)</span>') | ForEach-Object { ($_.Groups[1].Value -replace '<[^>]+>', '').Trim() + ':' + $_.Groups[2].Value }) -join ','
"[4-R-40] " + $(if (((($g -split ',') | Sort-Object) -join ',') -eq ((@('{AdminName}:3', '{UserName}:1') | Sort-Object) -join ',')) { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-40] PASS`（担当者ごとの見出しが表示される（admin: 3件、用意したユーザー: 1件））

#### [4-R-41] -o・-g とカスタムクエリ

**マクロ:** `{{ref_issues(-q={QueryName}, -o=subject:desc, -g=tracker)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-q={QueryName}, -o=subject:desc, -g=tracker)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
$g = ([regex]::Matches($c, '(?s)<span class="name">(.*?)</span>\s*<span class="[^"]*count[^"]*">(\d+)</span>') | ForEach-Object { ($_.Groups[1].Value -replace '<[^>]+>', '').Trim() + ':' + $_.Groups[2].Value }) -join ','
"[4-R-41] " + $(if ($g -eq '{Tracker1}:2' -and $o -eq 'RefIssuesTest1,IssueNameLinkTest') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-41] PASS`（クエリの条件（新規のみ）で絞り込まれたまま、トラッカーごとの見出しで分かれ、各グループの中は題名の降順）

#### [4-R-42] -o と -n

**マクロ:** `{{ref_issues(-p, -o=subject:desc, -n=2)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -o=subject:desc, -n=2)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-42] " + $(if ($o -eq 'RefIssuesTest3,RefIssuesTest2') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-42] PASS`（RefIssuesTest3、RefIssuesTest2 の2件のみ表示（並べた順の上から2件））

#### [4-R-43] -g と -n

**マクロ:** `{{ref_issues(-p, -g=tracker, -o=subject, -n=2)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -g=tracker, -o=subject, -n=2)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
$g = ([regex]::Matches($c, '(?s)<span class="name">(.*?)</span>\s*<span class="[^"]*count[^"]*">(\d+)</span>') | ForEach-Object { ($_.Groups[1].Value -replace '<[^>]+>', '').Trim() + ':' + $_.Groups[2].Value }) -join ','
"[4-R-43] " + $(if ($g -eq '{Tracker1}:3' -and $o -eq 'IssueNameLinkTest,RefIssuesTest1') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-43] PASS`（1 つ目のトラッカーの見出しと IssueNameLinkTest、RefIssuesTest1 の2行のみ表示。見出しの件数はグループ全体の 3）

#### [4-R-44] -g と -c

**マクロ:** `{{ref_issues(-p, -g=tracker, -c)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -g=tracker, -c)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
$txt = ($c -replace '<[^>]+>', '').Trim()
"[4-R-44] " + $(if ($txt -eq '4') { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-44] PASS`（件数（4）のみが数字で表示（-g は使われない））

#### [4-R-45] -g と -l

**マクロ:** `{{ref_issues(-p, -g=tracker, -l)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -g=tracker, -l)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
$hit = @([regex]::Matches($c, '(IssueNameLinkTest|RefIssuesTest\d)_{Sfx}') | ForEach-Object { $_.Groups[1].Value }); $o = $hit -join ','; $set = ($hit | Sort-Object -Unique) -join ','
"[4-R-45] " + $(if ($set -eq 'IssueNameLinkTest,RefIssuesTest1,RefIssuesTest2,RefIssuesTest3' -and $c -match '/issues/{R1Id}">RefIssuesTest1_{Sfx}</a>' -and -not $c.Contains('<span class="name">') -and -not $c.Contains('<table')) { 'PASS' } else { "FAIL: $o" })
```

**期待結果:** `[4-R-45] PASS`（題名がリンクとして横並びで表示され、見出しは表示されない）

### エラーケース

#### [4-R-28] 存在しないクエリID

**マクロ:** `{{ref_issues(-i=99999)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-i=99999)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-28] " + $(if ($c -match 'flash error' -and $c.Contains('can not find CustomQuery ID')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-28] PASS`（`can not find CustomQuery ID` エラー）

#### [4-R-29] 存在しないクエリ名

**マクロ:** `{{ref_issues(-q=NonExistent)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-q=NonExistent)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-29] " + $(if ($c -match 'flash error' -and $c.Contains('can not find CustomQuery Name')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-29] PASS`（`can not find CustomQuery Name` エラー）

#### [4-R-30] 不明なオプション

**マクロ:** `{{ref_issues(-x)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-x)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-30] " + $(if ($c -match 'flash error' -and $c.Contains('unknown option:-x')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-30] PASS`（`unknown option:-x` エラー）

#### [4-R-31] 不正な表示件数

**マクロ:** `{{ref_issues(-n=abc)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-n=abc)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-31] " + $(if ($c -match 'flash error' -and $c.Contains('display limit must be a positive integer')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-31] PASS`（`display limit must be a positive integer` エラー）

#### [4-R-32] 表示件数上限超過

**マクロ:** `{{ref_issues(-n=2000)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-n=2000)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-32] " + $(if ($c -match 'flash error' -and $c.Contains('exceeds maximum (1000)')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-32] PASS`（`exceeds maximum (1000)` エラー）

#### [4-R-33] 不明なカラム

**マクロ:** `{{ref_issues(-p, unknown_column)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, unknown_column)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-33] " + $(if ($c -match 'flash error' -and $c.Contains('unknown column')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-33] PASS`（`unknown column` エラー）

#### [4-R-34] 不正な演算子

**マクロ:** `{{ref_issues(-f:status_id ?? 1)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-f:status_id ?? 1)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-34] " + $(if ($c -match 'flash error' -and $c.Contains('invalid operator')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-34] PASS`（`invalid operator` エラー）

#### [4-R-35] 存在しないフィルタ値

**マクロ:** `{{ref_issues(-f:tracker=存在しない)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-f:tracker=存在しない)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-35] " + $(if ($c -match 'flash error' -and $c.Contains('can not resolve')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-35] PASS`（`can not resolve` エラー）

#### [4-R-46] 並べ替えできないカラム

**マクロ:** `{{ref_issues(-p, -o=unknown)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -o=unknown)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-46] " + $(if ($c -match 'flash error' -and $c -match '(?s)can not sort by (&#39;|'')unknown(&#39;|'').*\[SORT\]') { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-46] PASS`（`can not sort by 'unknown'` エラー。`[SORT]` の後に使えるカラムの一覧が表示される）

#### [4-R-47] 不正な並び順の向き

**マクロ:** `{{ref_issues(-p, -o=subject:up)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -o=subject:up)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-47] " + $(if ($c -match 'flash error' -and $c -match '(?s)sort order must be (&#39;|'')asc(&#39;|'') or (&#39;|'')desc(&#39;|'')') { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-47] PASS`（`sort order must be 'asc' or 'desc'` エラー）

#### [4-R-48] 並び順のカラム数超過

**マクロ:** `{{ref_issues(-p, -o=id|subject|tracker|status)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -o=id|subject|tracker|status)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-48] " + $(if ($c -match 'flash error' -and $c.Contains('too many sort columns (max 3)')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-48] PASS`（`too many sort columns (max 3)` エラー）

#### [4-R-49] 並び順の指定なし

**マクロ:** `{{ref_issues(-p, -o)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -o)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-49] " + $(if ($c -match 'flash error' -and $c.Contains('no sort order specified')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-49] PASS`（`no sort order specified` エラー）

#### [4-R-50] グループにできないカラム

**マクロ:** `{{ref_issues(-p, -g=subject)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -g=subject)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-50] " + $(if ($c -match 'flash error' -and $c -match '(?s)can not group by (&#39;|'')subject(&#39;|'').*\[GROUP\]') { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-50] PASS`（`can not group by 'subject'` エラー。`[GROUP]` の後に使えるカラムの一覧が表示される）

#### [4-R-51] グループの指定なし

**マクロ:** `{{ref_issues(-p, -g)}}`

```powershell
$h = @{ 'X-Redmine-API-Key' = '{ApiKey}' }; $u = '{BaseUrl}/projects/{ProjectIdent}/wiki/WLMacro'
$body = @{ wiki_page = @{ text = '{{ref_issues(-p, -g)}}' } } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Put -Uri "$u.json" -Headers $h -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
$c = (((Invoke-WebRequest -Uri $u -Headers $h).Content -split '<div class="wiki wiki-page">', 2)[1] -split '<fieldset', 2)[0]
"[4-R-51] " + $(if ($c -match 'flash error' -and $c.Contains('no group column specified')) { 'PASS' } else { "FAIL: $c" })
```

**期待結果:** `[4-R-51] PASS`（`no group column specified` エラー）

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
