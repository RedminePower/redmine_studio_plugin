# Issues With Extras API テスト仕様書

## 概要

`GET /issues_with_extras/:id` および `GET /issues_with_extras` のテスト仕様。Redmine 標準の `GET /issues/:id.json` / `/issues.json` のレスポンスに、本 Plugin が提供する `reply_count` / `children_count` を追加で含めて返す専用エンドポイント。

標準の `IssuesController` を継承し、view (`app/views/issues_with_extras/*.api.rsb`) で 2 フィールドを追加している。標準の `/issues` エンドポイントは変更しないため、他 Plugin と共存可能。

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

- `reply_count`: `issue.reply_count_value`（担当者変更回数、reply_count 機能と同じ値）
- `children_count`: `issue.children_count_value`（直下の子チケット数、children_count 機能と同じ値）

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
Write-Host "reply_count: $($r.issue.reply_count)"
Write-Host "children_count: $($r.issue.children_count)"
```

**期待結果:**
- `has_reply_count: True`
- `has_children_count: True`
- `reply_count` の値は整数
- `children_count` の値は整数

### [2-2] GET /issues_with_extras/:id.xml で reply_count / children_count が返る

**確認方法:**
```powershell
$cred = New-Object PSCredential('{Username}', (ConvertTo-SecureString '{Password}' -AsPlainText -Force))
$response = Invoke-WebRequest -Uri '{BaseUrl}/issues_with_extras/{ISSUE_ID}.xml' -Credential $cred -AllowUnencryptedAuthentication
Write-Host "reply_count_matched: $($response.Content -match '<reply_count[^>]*>\d+</reply_count>')"
Write-Host "children_count_matched: $($response.Content -match '<children_count[^>]*>\d+</children_count>')"
```

**期待結果:**
- `reply_count_matched: True`
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
Write-Host "reply_count_matched: $($response.Content -match '<reply_count[^>]*>\d+</reply_count>')"
Write-Host "children_count_matched: $($response.Content -match '<children_count[^>]*>\d+</children_count>')"
```

**期待結果:**
- `reply_count_matched: True`
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

**期待結果:**
- `only_in_extras: reply_count,children_count`（追加した 2 フィールドのみ差分）
- `only_in_std:` (空)

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
- `only_in_extras: reply_count,children_count`
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

---

## 3. ブラウザテスト

該当なし（すべて Runner / HTTP テストでカバー済み）
