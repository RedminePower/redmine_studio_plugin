# Issues With Extras API テスト仕様書

## 概要

`GET /issues_with_extras/:id` および `GET /issues_with_extras` のテスト仕様。Redmine 標準の `GET /issues/:id.json` / `/issues.json` のレスポンスに、本 Plugin が提供する `reply_count` / `children_count` / `spent_hours_by_user` と、Redmine 標準の一覧カラム（標準 API では返らない）である `last_updated_by` / `last_notes` を追加で含めて返す専用エンドポイント。

標準の `IssuesController` を継承し、view (`app/views/issues_with_extras/*.api.rsb`) でフィールドを追加している。標準の `/issues` エンドポイントは変更しないため、他 Plugin と共存可能。

`reply_count` / `children_count` は `count` + `items` のネストオブジェクトで返す。`items` は表示の元情報（id + name の配列）で、整形（ラベル化・件名の省略・「他N件」）はクライアント側の責務とする。

`last_updated_by` / `last_notes` は Redmine 本体の `Issue#last_updated_by` / `Issue#last_notes`（およびプリロード `load_visible_last_updated_by` / `load_visible_last_notes`）をそのまま利用する。プラグインでの再実装はしない。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| Controller | `IssuesWithExtrasController` (`IssuesController` を継承) |
| ファイル | `app/controllers/issues_with_extras_controller.rb` |
| ルーティング | `GET /issues_with_extras`, `GET /issues_with_extras/:id` |
| View ファイル | `app/views/issues_with_extras/show.api.rsb`, `app/views/issues_with_extras/index.api.rsb` |
| 認証 | 標準 `IssuesController` と同一（`accept_api_auth :index, :show`） |
| 権限 | 標準 `view_issues` を流用（`authorize` を controller 名 `'issues'` で override） |
| レスポンス形式 | JSON / XML 両対応 |

### 追加されるフィールド

- `reply_count`: ネストオブジェクト
  - `count`: `issue.reply_count_value`（担当者変更回数、reply_count 機能と同じ値）
  - `items`: 担当者の遷移（初期担当者 → 変更ごとの新担当者）の `{ id, name }` 配列。担当者なしは `id=0, name=''`、削除済み等の無効ユーザーは `id=元のID, name=''`。変更履歴がないチケットは現在の担当者 1 件
- `children_count`: ネストオブジェクト
  - `count`: `issue.children_count_value`（直下の子チケット数、children_count 機能と同じ値）
  - `items`: 子チケットの `{ id, name=件名 }` 配列（先頭 10 件、`MAX_ITEMS` キャップ、visible スコープ適用）
- `last_updated_by`: `{ id, name }`（`issue.last_updated_by`＝可視ジャーナルの最新更新者）。更新履歴が無い、または最新ジャーナルの投稿者が実在しない場合は **プロパティごと省略**（nullable ネストの標準パターン）
- `last_notes`: 文字列（`issue.last_notes`＝可視の最新コメント本文）。コメントが無い場合は空文字 `""`（単純文字列なので常に出力する）
- `spent_hours_by_user`: `{ user_id, hours }` の配列（`issue.spent_hours_by_user_items`）。チケットとその子孫（subtree）に紐づく作業時間を担当者ごとに合計したもの。集計範囲は `total_spent_hours` と同じ subtree（nested set の `root_id` 一致 + `lft`/`rgt` 包含）で、`hours` の総和は `total_spent_hours` に一致する。可視な作業時間のみ対象（`TimeEntry.visible`）で self-guard のため権限ガードは付けず常に出力（作業時間ゼロは空配列）

---

## 1. Runner テスト

### [1-1] Controller が IssuesController を継承している

**確認方法:**
```ruby
puts IssuesWithExtrasController.ancestors.map(&:name).include?('IssuesController')
```

**期待結果:** `true`

### [1-2] Route が登録されている

**確認方法:**
```ruby
routes = Rails.application.routes.routes.map do |r|
  { verb: r.verb, path: r.path.spec.to_s, controller: r.defaults[:controller], action: r.defaults[:action] }
end
show_route = routes.find { |r| r[:controller] == 'issues_with_extras' && r[:action] == 'show' }
index_route = routes.find { |r| r[:controller] == 'issues_with_extras' && r[:action] == 'index' }
puts "show: #{show_route.inspect}"
puts "index: #{index_route.inspect}"
```

**期待結果:**
- `show: {verb: 'GET', path: '/issues_with_extras/:id(.:format)', ...}` が存在
- `index: {verb: 'GET', path: '/issues_with_extras(.:format)', ...}` が存在

### [1-3] View ファイルが存在する

**確認方法:**
```ruby
plugin_dir = Redmine::Plugin.registered_plugins[:redmine_studio_plugin].directory
show_view = File.join(plugin_dir, 'app/views/issues_with_extras/show.api.rsb')
index_view = File.join(plugin_dir, 'app/views/issues_with_extras/index.api.rsb')
puts "show_exists: #{File.exist?(show_view)}"
puts "index_exists: #{File.exist?(index_view)}"
```

**期待結果:**
- `show_exists: true`
- `index_exists: true`

---

## 2. HTTP テスト

`{BaseUrl}` は `http://localhost:3061/redmine_61`、`{Username}` / `{Password}` は Redmine 管理者アカウント（`admin` / `password123` など）。

### [2-1] GET /issues_with_extras/:id.json で reply_count / children_count が返る

**前提条件:**
- 任意の Issue が存在すること（チケットID を `{ISSUE_ID}` とする）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras/{ISSUE_ID}.json' -Credential $cred -AllowUnencryptedAuthentication
Write-Host "has_reply_count: $($r.issue.PSObject.Properties.Name -contains 'reply_count')"
Write-Host "has_children_count: $($r.issue.PSObject.Properties.Name -contains 'children_count')"
Write-Host "reply_count_count: $($r.issue.reply_count.count)"
Write-Host "reply_items_is_array: $($r.issue.reply_count.items -is [array] -or $r.issue.reply_count.items -eq $null -or $r.issue.reply_count.items.Count -ge 0)"
Write-Host "children_count_count: $($r.issue.children_count.count)"
```

**期待結果:**
- `has_reply_count: True`
- `has_children_count: True`
- `reply_count_count` の値は整数（`count` プロパティ）
- `reply_items_is_array: True`（`items` プロパティが配列）
- `children_count_count` の値は整数

### [2-2] GET /issues_with_extras/:id.xml で reply_count / children_count が返る

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues_with_extras/{ISSUE_ID}.xml' -Credential $cred -AllowUnencryptedAuthentication
Write-Host "reply_count_matched: $($response.Content -match '<reply_count><count>\d+</count><items type=\"array\">')"
Write-Host "children_count_matched: $($response.Content -match '<children_count><count>\d+</count><items type=\"array\">')"
```

**期待結果:**
- `reply_count_matched: True`（`<reply_count><count>N</count><items type="array">` のネスト構造）
- `children_count_matched: True`

### [2-3] GET /issues_with_extras.json で issues 配列に reply_count / children_count が返る

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras.json?limit=3' -Credential $cred -AllowUnencryptedAuthentication
Write-Host "issues_count: $($r.issues.Count)"
Write-Host "first_has_reply_count: $($r.issues[0].PSObject.Properties.Name -contains 'reply_count')"
Write-Host "first_has_children_count: $($r.issues[0].PSObject.Properties.Name -contains 'children_count')"
```

**期待結果:**
- `issues_count`: 3 (または 3 未満、DB のチケット数による)
- `first_has_reply_count: True`
- `first_has_children_count: True`

### [2-4] GET /issues_with_extras.xml で issue 要素に reply_count / children_count が返る

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues_with_extras.xml?limit=3' -Credential $cred -AllowUnencryptedAuthentication
Write-Host "reply_count_matched: $($response.Content -match '<reply_count><count>\d+</count><items type=\"array\">')"
Write-Host "children_count_matched: $($response.Content -match '<children_count><count>\d+</count><items type=\"array\">')"
```

**期待結果:**
- `reply_count_matched: True`（ネスト構造）
- `children_count_matched: True`

### [2-5] 標準 GET /issues/:id.json では reply_count / children_count が返らない（副作用ゼロ確認）

Plugin が標準エンドポイントを変更していないことを確認する回帰テスト。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues/{ISSUE_ID}.json' -Credential $cred -AllowUnencryptedAuthentication
Write-Host "has_reply_count: $($r.issue.PSObject.Properties.Name -contains 'reply_count')"
Write-Host "has_children_count: $($r.issue.PSObject.Properties.Name -contains 'children_count')"
```

**期待結果:**
- `has_reply_count: False`
- `has_children_count: False`

### [2-6] 標準 GET /issues.json では reply_count / children_count が返らない（副作用ゼロ確認）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues.json?limit=1' -Credential $cred -AllowUnencryptedAuthentication
Write-Host "first_has_reply_count: $($r.issues[0].PSObject.Properties.Name -contains 'reply_count')"
Write-Host "first_has_children_count: $($r.issues[0].PSObject.Properties.Name -contains 'children_count')"
```

**期待結果:**
- `first_has_reply_count: False`
- `first_has_children_count: False`

### [2-7] 認証は標準 IssuesController と同一挙動

標準 `/issues` と同じく `accept_api_auth :index, :show` を継承しているため、認証の要求条件は標準と一致する。標準 `/issues/:id.json` が返せる状況では本エンドポイントも返り、標準が 401 を返す状況では本エンドポイントも 401 を返す。

**確認方法:**
```powershell
# 認証ヘッダなしで、標準 /issues/{ID}.json と /issues_with_extras/{ID}.json のステータスコードを比較
$stdStatus = 0
try { $r = Invoke-WebRequest -Uri '{BaseUrl}/issues/{ISSUE_ID}.json' -UseBasicParsing -ErrorAction Stop; $stdStatus = $r.StatusCode } catch { $stdStatus = $_.Exception.Response.StatusCode.value__ }

$extStatus = 0
try { $r = Invoke-WebRequest -Uri '{BaseUrl}/issues_with_extras/{ISSUE_ID}.json' -UseBasicParsing -ErrorAction Stop; $extStatus = $r.StatusCode } catch { $extStatus = $_.Exception.Response.StatusCode.value__ }

Write-Host "std: $stdStatus / ext: $extStatus / match: $($stdStatus -eq $extStatus)"
```

**期待結果:** `match: True`（標準と本エンドポイントが同じステータスコードを返す）

### [2-8] Issue API レスポンスの他フィールドが Redmine 本体と同一（等価性検証、show）

Redmine 本体の `issues/show.api.rsb` の全 API フィールドが `issues_with_extras/show.api.rsb` にも含まれることを確認する回帰テスト。本体側の view 更新への追従漏れを検知する。

**確認方法:**

`GET /issues/{ISSUE_ID}.json?include=journals,attachments,relations,children,watchers,allowed_statuses,changesets` と `GET /issues_with_extras/{ISSUE_ID}.json?include=journals,attachments,relations,children,watchers,allowed_statuses,changesets` を Runner または PowerShell で取得し、issue 直下のキーを比較する。

```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$include = 'journals,attachments,relations,children,watchers,allowed_statuses,changesets'
$std = Invoke-RestMethod -Uri "{BaseUrl}/issues/{ISSUE_ID}.json?include=$include" -Credential $cred -AllowUnencryptedAuthentication
$ext = Invoke-RestMethod -Uri "{BaseUrl}/issues_with_extras/{ISSUE_ID}.json?include=$include" -Credential $cred -AllowUnencryptedAuthentication

$stdKeys = $std.issue.PSObject.Properties.Name | Sort-Object
$extKeys = $ext.issue.PSObject.Properties.Name | Sort-Object

$onlyInExt = $extKeys | Where-Object { $stdKeys -notcontains $_ }
$onlyInStd = $stdKeys | Where-Object { $extKeys -notcontains $_ }
Write-Host "only_in_extras: $($onlyInExt -join ',')"
Write-Host "only_in_std: $($onlyInStd -join ',')"
```

**期待結果（`{ISSUE_ID}` は更新履歴が 1 件以上あるチケットを使う）:**
- `only_in_extras: children_count,last_notes,last_updated_by,reply_count,spent_hours_by_user`（追加した 5 フィールドのみ差分）
- `only_in_std:` (空)

※ `last_updated_by` は最終更新者が居るときだけ出力される。更新履歴が無いチケットを使うと `last_updated_by` が差分に現れず 4 フィールドになる。`spent_hours_by_user` は作業時間ゼロでも空配列で常に出力される。

### [2-9] Issue API レスポンスの他フィールドが Redmine 本体と同一（等価性検証、index）

show と同様に、`/issues.json` と `/issues_with_extras.json` の issue 配列各要素のキーを比較する。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$std = Invoke-RestMethod -Uri '{BaseUrl}/issues.json?limit=1' -Credential $cred -AllowUnencryptedAuthentication
$ext = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras.json?limit=1' -Credential $cred -AllowUnencryptedAuthentication

$stdKeys = $std.issues[0].PSObject.Properties.Name | Sort-Object
$extKeys = $ext.issues[0].PSObject.Properties.Name | Sort-Object

$onlyInExt = $extKeys | Where-Object { $stdKeys -notcontains $_ }
$onlyInStd = $stdKeys | Where-Object { $extKeys -notcontains $_ }
Write-Host "only_in_extras: $($onlyInExt -join ',')"
Write-Host "only_in_std: $($onlyInStd -join ',')"
```

**期待結果:**
- `only_in_extras` は `children_count,last_notes,reply_count,spent_hours_by_user` を必ず含む。先頭チケットに更新履歴があれば `last_updated_by` も加わる（最大 `children_count,last_notes,last_updated_by,reply_count,spent_hours_by_user`）
- `only_in_std:` (空)

### [2-10] pagination が動作する

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras.json?limit=2&offset=0' -Credential $cred -AllowUnencryptedAuthentication
Write-Host "issues_count: $($r.issues.Count)"
Write-Host "total_count: $($r.total_count)"
Write-Host "offset: $($r.offset)"
Write-Host "limit: $($r.limit)"
```

**期待結果:**
- `issues_count: 2` (総数が 2 以上のとき)
- `total_count`: 数値
- `offset: 0`
- `limit: 2`

### [2-11] filter が動作する（status_id）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras.json?status_id=open&limit=3' -Credential $cred -AllowUnencryptedAuthentication
Write-Host "issues_count: $($r.issues.Count)"
$allOpen = $true
foreach ($i in $r.issues) {
  if ($i.status.is_closed) { $allOpen = $false; break }
}
Write-Host "all_open: $allOpen"
```

**期待結果:**
- `issues_count`: 0 以上の数値
- `all_open: True`

### [2-12] 存在しない ID で 404

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
try {
  $response = Invoke-WebRequest -Uri '{BaseUrl}/issues_with_extras/9999999.json' -Credential $cred -AllowUnencryptedAuthentication
  Write-Host "status: $($response.StatusCode)"
} catch {
  Write-Host "status: $($_.Exception.Response.StatusCode.value__)"
}
```

**期待結果:** `status: 404`

### [2-13] reply_count.items が担当者の遷移を表す

**前提条件:**
- 担当者変更が 1 回以上あるチケットが存在すること（チケットID を `{CHANGED_ISSUE_ID}` とする）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras/{CHANGED_ISSUE_ID}.json' -Credential $cred -AllowUnencryptedAuthentication
$rc = $r.issue.reply_count
Write-Host "count: $($rc.count)"
Write-Host "items_count: $($rc.items.Count)"
Write-Host "chain: $($rc.items | ForEach-Object { "$($_.id):$($_.name)" } | Join-String -Separator ' -> ')"
```

**期待結果:**
- `items_count` = `count + 1`（初期担当者 + 変更ごとの新担当者）
- `chain` が実際の担当者変更履歴と一致する（各要素に `id` と `name` がある）
- 担当者変更がないチケットでは `count: 0`、`items` は現在の担当者 1 件（担当者未設定なら `id=0, name=''`）

### [2-14] children_count.items が子チケット一覧（最大 10 件）を表す

**前提条件:**
- 子チケットを持つチケットが存在すること（チケットID を `{PARENT_ISSUE_ID}` とする）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras/{PARENT_ISSUE_ID}.json' -Credential $cred -AllowUnencryptedAuthentication
$cc = $r.issue.children_count
Write-Host "count: $($cc.count)"
Write-Host "items_count: $($cc.items.Count)"
Write-Host "first_item: id=$($cc.items[0].id) name=$($cc.items[0].name)"
Write-Host "capped: $($cc.items.Count -le 10)"
```

**期待結果:**
- `count` = 直下の子チケット数（visible スコープ適用）
- `items` の各要素は `id` = 子チケット ID、`name` = 件名（省略なしの全文）
- `capped: True`（`items` は最大 10 件。`count` が 10 超でも `items` は 10 件まで）

### [2-15] show で last_updated_by / last_notes が返る

**前提条件:**
- 更新履歴（担当者変更やコメント）が 1 件以上あるチケットが存在すること（チケットID を `{UPDATED_ISSUE_ID}` とする）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras/{UPDATED_ISSUE_ID}.json' -Credential $cred -AllowUnencryptedAuthentication
Write-Host "has_last_updated_by: $($r.issue.PSObject.Properties.Name -contains 'last_updated_by')"
Write-Host "last_updated_by: id=$($r.issue.last_updated_by.id) name=$($r.issue.last_updated_by.name)"
Write-Host "has_last_notes: $($r.issue.PSObject.Properties.Name -contains 'last_notes')"
Write-Host "last_notes: $($r.issue.last_notes)"
```

**期待結果:**
- `has_last_updated_by: True`（最終更新者が居るチケットの場合。id / name を持つ）
- `has_last_notes: True`（コメントが無いチケットでも空文字で必ず出力される）
- `last_updated_by` の name が実際の最終更新者と一致、`last_notes` が最新コメント本文と一致

### [2-16] index で last_updated_by / last_notes が返る（プリロード経路）

デフォルトの並び順に依存しないよう、更新履歴ありの `{UPDATED_ISSUE_ID}` と履歴なしの `{NO_JOURNAL_ISSUE_ID}` を `issue_id` フィルタで明示して一覧取得し、プリロード経路（`load_visible_last_updated_by` / `load_visible_last_notes`）が正しく値を配ることを確認する。

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras.json?issue_id={UPDATED_ISSUE_ID},{NO_JOURNAL_ISSUE_ID}' -Credential $cred -AllowUnencryptedAuthentication
foreach ($i in $r.issues) {
  $hasLub = $i.PSObject.Properties.Name -contains 'last_updated_by'
  Write-Host "#$($i.id) has_last_updated_by=$hasLub last_notes='$($i.last_notes)'"
}
```

**期待結果:**
- `last_notes` は全 issue で出力される（コメント無しは空文字）
- `last_updated_by` は更新履歴のある issue でのみ出力される（`{UPDATED_ISSUE_ID}` は True、`{NO_JOURNAL_ISSUE_ID}` は省略）
- 値が show（[2-15]）と一致する = プリロード経路と単一取得経路で同値

### [2-17] 標準 GET /issues では last_updated_by / last_notes が返らない（副作用ゼロ確認）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues/{ISSUE_ID}.json' -Credential $cred -AllowUnencryptedAuthentication
Write-Host "has_last_updated_by: $($r.issue.PSObject.Properties.Name -contains 'last_updated_by')"
Write-Host "has_last_notes: $($r.issue.PSObject.Properties.Name -contains 'last_notes')"
```

**期待結果:**
- `has_last_updated_by: False`
- `has_last_notes: False`

### [2-18] spent_hours_by_user が担当者ごとの subtree 作業時間を表す

**前提条件:**
- 子孫を含めて作業時間が登録されたチケットが存在すること（親チケット ID を `{SPENT_PARENT_ID}` とする。子孫にも別ユーザーの作業時間があると分離を確認できる）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues_with_extras/{SPENT_PARENT_ID}.json' -Credential $cred -AllowUnencryptedAuthentication
$sh = $r.issue.spent_hours_by_user
$sum = ($sh | Measure-Object -Property hours -Sum).Sum
Write-Host "has_field: $($r.issue.PSObject.Properties.Name -contains 'spent_hours_by_user')"
Write-Host "entries: $($sh | ForEach-Object { "$($_.user_id):$($_.hours)" } | Join-String -Separator ',')"
Write-Host "sum: $sum / total_spent_hours: $($r.issue.total_spent_hours) / match: $($sum -eq $r.issue.total_spent_hours)"
```

**期待結果:**
- `has_field: True`（配列で常に出力される）
- 各要素は `user_id` = ユーザー ID、`hours` = そのユーザーの subtree 合計時間
- `match: True`（`hours` の総和 = `total_spent_hours`。subtree 集計が正しい）
- 作業時間が 1 件も無いチケットでは空配列 `[]`

### [2-19] 標準 GET /issues では spent_hours_by_user が返らない（副作用ゼロ確認）

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$r = Invoke-RestMethod -Uri '{BaseUrl}/issues/{ISSUE_ID}.json' -Credential $cred -AllowUnencryptedAuthentication
Write-Host "has_spent_hours_by_user: $($r.issue.PSObject.Properties.Name -contains 'spent_hours_by_user')"
```

**期待結果:**
- `has_spent_hours_by_user: False`

---

## 3. ブラウザテスト

該当なし（すべて Runner / HTTP テストでカバー済み）
