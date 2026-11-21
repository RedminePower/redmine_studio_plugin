# Server Logs API テスト仕様書

## 概要

redmine_studio_plugin の Server Logs API（ログのファイルの一覧・範囲のバイト）と、Info API に足した項目（`app_server`・`log_level`）のテスト仕様。

確かめること:

- 一覧に並ぶのは、ログフォルダーの直下の普通のファイルだけで、見分けの印・大きさ・圧縮の有無が正しい
- 範囲のバイトが、元のファイルとバイト単位で一致する（gzip で受けても、圧縮されたファイルでも）
- 失敗のときのステータス（401・403・404・409・422・429）と本文 `{"errors":[…]}`
- ログフォルダーの外・並ばないもの（名前付きパイプ・シンボリックリンク・ハードリンク・下のフォルダー）は読めない
- 読み出しを続けている間も、ほかのリクエストが止まらない（Puma と Thin）
- `/info` の `app_server`・`log_level` はシステム管理者にだけ返る

対象バージョン: 5.x / 6.x / 7.x。アプリケーションサーバーは Puma と Thin の両方で行う（Thin は 1 本のスレッドで順にリクエストを処理するため、読み出しが長いとほかの利用者が待たされる。その確かめが要る）。

接続先・認証情報・コンテナ名は実行環境から注入する（プレースホルダの契約は `test/README.md`）。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| コントローラ | `ServerLogsController`（`index`・`content`）、`InfoController`（項目を追加） |
| モジュール | `RedmineStudioPlugin::ServerLogs::LogDirectory`（一覧・開く・見分けの印）、`ReadSlots`（同時に 2 つまで）、`RangeReader`（範囲の読み出し・gzip）、`AppServerInfo`（サーバーの種類・同時に処理できる数・ログのレベル） |
| エンドポイント | `GET /server_logs.json`、`GET /server_logs/content.json`、`GET /info.json`（項目を追加） |
| 上限 | 1 回に送る量はおよそ 1 MB（圧縮した後）、読む量は 16 MB まで。`length` を省くと 16 MB |
| ロックのファイル | `{Redmine}/tmp/redmine_studio_plugin_server_logs_read_0.lock`・`_1.lock` |

---

## テスト実行フロー

### フェーズ 0: 環境の準備

#### ログをファイルに書く設定にする

公式 Docker イメージは `RAILS_LOG_TO_STDOUT` が入っていて、ログをファイルに書かない（このとき `log_file` は `null`。[2-2] で確かめる）。ほかのテストでは、コンテナを `-e RAILS_LOG_TO_STDOUT=`（空）で作り、`log/production.log` に書かせる。

#### Thin で動かす

Thin の環境は、公式イメージに `thin` を足したイメージで、`rails server -u thin -b 0.0.0.0 -p 3000` で起動する。

- `Gemfile.local` に `gem 'thin'` を書き、`config/database.yml` を使うアダプターだけにして `bundle install` し、`Gemfile.lock.<アダプター>` を作り直す（公式イメージの起動スクリプトは、その名前のファイルを `Gemfile.lock` に写すため）
- `eventmachine` のビルドに `build-essential` が要る

#### 試験用のログを置く

ログフォルダー（`/usr/src/redmine/log`）に、次のファイルを作る。架空のデータだけを使う（IP は `192.0.2.x` などの文書用のアドレス、利用者は `user12` などの架空の名前）。

| 名前 | 中身・作り方 | 期待 |
|------|-------------|------|
| `production.log.1` | Rails の形のログ（Started・Processing・Completed の行）を数百 MB | 並ぶ |
| `production.log.2.gz` | 同じ形のログを `gzip -1` で圧縮したもの | 並ぶ（`compressed: true`） |
| `production.log.3.gz` | root の持ち物・モード 600 | 並ばない（読めない） |
| `empty.log` | 空 | 並ぶ（`fingerprint: "0:"`） |
| `small.log` | `small file\n`（11 バイト） | 並ぶ |
| `fake.gz` | gzip でない中身 | 並ぶ（`compressed` を省く） |
| `production.log.fifo` | `mkfifo` | 並ばない |
| `production.log.link` | `/etc/passwd` へのシンボリックリンク | 並ばない |
| `production.log.hl`・`production.log.hl2` | 互いのハードリンク | どちらも並ばない |
| `archive/production.log.9` | 下のフォルダー | 並ばない |
| `.hidden.log` | `.` で始まる名前 | 並ばない |
| `production.log:x` | `:` を含む名前 | 並ばない |
| `bad\xff.log` | UTF-8 でない名前 | 並ばない |

root が要る `production.log.3.gz` だけ `-u` を付けずに作り、ほかは `-u redmine` で作る。

```bash
MSYS_NO_PATHCONV=1 docker exec -u redmine {Container} bash -c 'cd /usr/src/redmine/log && : > empty.log && printf "small file\n" > small.log && printf "not gzip\n" > fake.gz && mkfifo production.log.fifo && ln -s /etc/passwd production.log.link && printf "hl\n" > production.log.hl && ln production.log.hl production.log.hl2 && mkdir -p archive && printf "sub\n" > archive/production.log.9 && printf "dot\n" > .hidden.log && printf "colon\n" > "production.log:x" && printf "bad\n" > $(printf "bad\xff.log")'
MSYS_NO_PATHCONV=1 docker exec {Container} bash -c 'printf "secret\n" | gzip -c > /usr/src/redmine/log/production.log.3.gz && chmod 600 /usr/src/redmine/log/production.log.3.gz'
```

数百 MB のログは、コンテナの中で Ruby の小さなスクリプトで作る（乱数の種を決めて、毎回同じ中身にする）。

### フェーズ 1: Runner テスト

[テンプレートのフェーズ 0 と同じ流し方](../../TEST_SPEC_TEMPLATE.md)（Puma は止めない・スクリプトはファイルにして `-u redmine` で流す）。

### フェーズ 2: HTTP テスト

PowerShell 7 で流す。下の関数を先に定義しておく。`content.json` は成功のときバイトを返すので、`HttpClient` で受けて自分で展開する。

```powershell
Add-Type -AssemblyName System.Net.Http
$script:Http = [System.Net.Http.HttpClient]::new([System.Net.Http.HttpClientHandler]@{ AutomaticDecompression = 'None' })
function Get-Api([string]$Path, [string]$Key = '{ApiKey}', [switch]$Gzip) {
  $req = [System.Net.Http.HttpRequestMessage]::new('Get', "{BaseUrl}$Path")
  if ($Key) { $req.Headers.Add('X-Redmine-API-Key', $Key) }
  if ($Gzip) { $req.Headers.Add('Accept-Encoding', 'gzip') }
  $res = $script:Http.SendAsync($req).Result
  $bytes = $res.Content.ReadAsByteArrayAsync().Result
  $enc = @($res.Content.Headers.ContentEncoding)
  if ($enc -contains 'gzip') {
    $in = [IO.Compression.GZipStream]::new([IO.MemoryStream]::new($bytes), 'Decompress'); $out = [IO.MemoryStream]::new(); $in.CopyTo($out); $plain = $out.ToArray()
  } else { $plain = $bytes }
  [pscustomobject]@{ Status = [int]$res.StatusCode; Headers = $res.Headers; ContentHeaders = $res.Content.Headers; Raw = $bytes; Body = $plain
                     Text = [Text.Encoding]::UTF8.GetString($plain) }
}
function Get-Header($r, [string]$Name) { $v = $null; if ($r.Headers.TryGetValues($Name, [ref]$v) -or $r.ContentHeaders.TryGetValues($Name, [ref]$v)) { @($v)[0] } }
function Get-Sha256([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLower() }
function Get-ContainerSha([string]$Cmd) { (docker exec -u redmine {Container} bash -c "$Cmd | sha256sum").Split(' ')[0] }
```

---

## 1. Runner テスト

バッチ 1 つ（`server_logs_batch1.rb`）にまとめ、各テストを `begin`〜`rescue` で囲んで `[1-n] OK` / `[1-n] NG: 理由` を出す。

### [1-1] モジュール・コントローラ・ルートがある

```ruby
ok = defined?(ServerLogsController) && defined?(RedmineStudioPlugin::ServerLogs::LogDirectory) &&
     defined?(RedmineStudioPlugin::ServerLogs::ReadSlots) && defined?(RedmineStudioPlugin::ServerLogs::RangeReader) &&
     defined?(RedmineStudioPlugin::ServerLogs::AppServerInfo)
routes = Rails.application.routes.routes.map { |r| [r.defaults[:controller], r.defaults[:action]] }
ok &&= routes.include?(['server_logs', 'index']) && routes.include?(['server_logs', 'content'])
puts ok ? '[1-1] OK' : '[1-1] NG'
```

**期待結果:** すべてある

### [1-2] ログフォルダーは実際の場所

```ruby
dir = RedmineStudioPlugin::ServerLogs::LogDirectory.path
puts dir == File.realpath(Rails.root.join('log').to_s) ? '[1-2] OK' : "[1-2] NG: #{dir}"
```

**期待結果:** `log` フォルダーの realpath と同じ

### [1-3] 見分けの印の形

```ruby
LD = RedmineStudioPlugin::ServerLogs::LogDirectory
require 'digest'
fp = LD.format_fingerprint('abc'.b)
ok = fp == "3:#{Digest::SHA256.hexdigest('abc')}" && LD.format_fingerprint(''.b) == '0:'
puts ok ? '[1-3] OK' : "[1-3] NG: #{fp}"
```

**期待結果:** `バイト数:SHA-256`、空は `"0:"`

### [1-4] 名前の決まり

```ruby
ng = %w[.hidden a/b a\\b a:b] + ["a\0b", "bad\xff.log".b]
ok = LD.valid_name?('production.log.1') && ng.none? { |n| LD.valid_name?(n) }
puts ok ? '[1-4] OK' : '[1-4] NG'
```

**期待結果:** `.` で始まる・`/`・`\`・`:`・NUL を含む・UTF-8 でない名前は通らない

### [1-5] 圧縮されたファイルの印は、展開した先頭で取る

```ruby
require 'zlib'
dir = Dir.mktmpdir
begin
  data = ('x' * 5000).b
  File.binwrite(File.join(dir, 'a.log'), data)
  Zlib::GzipWriter.open(File.join(dir, 'a.log.gz')) { |gz| gz.write(data) }
  fps = %w[a.log a.log.gz].map do |n|
    LD.send(:with_open, dir, n) { |f| [LD.fingerprint(f), f.compressed] }
  end
  ok = fps[0][0] == fps[1][0] && fps[0][0].start_with?('4096:') && fps[0][1] == false && fps[1][1] == true
  puts ok ? '[1-5] OK' : "[1-5] NG: #{fps.inspect}"
ensure
  FileUtils.rm_rf(dir)
end
```

**期待結果:** 2 つの印が同じ。`.gz` だけ `compressed` が真

### [1-6] 同時に 2 つまで

```ruby
RS = RedmineStudioPlugin::ServerLogs::ReadSlots
a = RS.acquire; b = RS.acquire; c = RS.acquire
ok = a.is_a?(File) && b.is_a?(File) && c == :busy
a.close; d = RS.acquire
ok &&= d.is_a?(File)
[b, d].each(&:close)
puts ok ? '[1-6] OK' : "[1-6] NG: #{[a, b, c, d].map(&:class).inspect}"
```

**期待結果:** 3 つ目は `:busy`。1 つ外すと、また取れる（同じプロセスの中でも数えられる）

### [1-7] 範囲の読み出しの上限

```ruby
RR = RedmineStudioPlugin::ServerLogs::RangeReader
dir = Dir.mktmpdir
begin
  rnd = Random.new(1)
  File.binwrite(File.join(dir, 'r.log'), rnd.bytes(3 * 1024 * 1024))  # 圧縮が効かない中身
  LD.send(:with_open, dir, 'r.log') do |f|
    plain = RR.read(f, 0, 10 * 1024 * 1024, gzip: false)
    gz = RR.read(f, 100, 10 * 1024 * 1024, gzip: true)
    tail = RR.read(f, f.size - 5, 100, gzip: false)
    over = RR.read(f, f.size + 10**20, 1, gzip: true)
    ok = plain.length == 1024 * 1024 && !plain.gzipped &&
         gz.gzipped && gz.body.bytesize < 1024 * 1024 + 300 * 1024 &&
         Zlib.gunzip(gz.body) == File.binread(File.join(dir, 'r.log'), gz.length, 100) &&
         tail.length == 5 && over.length == 0 && over.body.empty?
    puts ok ? '[1-7] OK' : "[1-7] NG: #{[plain.length, gz.length, gz.body.bytesize, tail.length].inspect}"
  end
ensure
  FileUtils.rm_rf(dir)
end
```

**期待結果:** 圧縮しないときは 1 MB まで。圧縮するときは送る量がおよそ 1 MB で止まり、展開すると元の範囲と一致する。終わりを超える範囲は終わりで切れ、大きすぎる `offset` は空

### [1-8] ログのレベルの名前

```ruby
AS = RedmineStudioPlugin::ServerLogs::AppServerInfo
orig = Rails.logger.level
begin
  names = [0, 1, 2, 3, 4, 5].map { |lv| Rails.logger.level = lv; AS.log_level }
  puts names == %w[debug info warn error fatal unknown] ? '[1-8] OK' : "[1-8] NG: #{names.inspect}"
ensure
  Rails.logger.level = orig
end
```

**期待結果:** `debug`〜`unknown` の名前になる

### [1-9] サーバーの種類の見分け

```ruby
names = {
  'puma 6.4.0 (ruby 3.3.0-p0) Our Fancy Name' => 'puma',
  'thin 1.8.2 codename Ruby Razor' => 'thin',
  'WEBrick/1.8.1 (Ruby/3.3.0/2023-12-25)' => 'webrick',
  '' => (defined?(::PhusionPassenger) ? 'passenger' : 'unknown')
}
got = names.keys.map { |s| AS.server_name('SERVER_SOFTWARE' => s) }
puts got == names.values ? '[1-9] OK' : "[1-9] NG: #{got.inspect}"
```

**期待結果:** `SERVER_SOFTWARE` から決まる。gem が読み込まれているだけ（Puma の定数がある）では `puma` にならない

---

## 2. HTTP テスト

`{ApiKey}` はシステム管理者、`{UserApiKey}` はシステム管理者でないユーザー。

### [2-1] 一覧

```powershell
$r = Get-Api '/server_logs.json'
$j = $r.Text | ConvertFrom-Json
$j.server_logs.log_file
$j.server_logs.files | Format-Table name, size, updated_on, fingerprint, compressed
```

**期待結果:**
- 200。`log_file` が `production.log`
- 並ぶのは `empty.log`・`fake.gz`・`production.log`・`production.log.1`・`production.log.2.gz`・`small.log` だけ（フェーズ 0 の表の「並ばない」ものは無い）
- `empty.log` の `fingerprint` が `"0:"`、`size` が 0
- `production.log.1` の `fingerprint` が `4096:` ＋ `head -c 4096 production.log.1 | sha256sum`
- `production.log.2.gz` の `fingerprint` が `4096:` ＋ `zcat production.log.2.gz | head -c 4096 | sha256sum`、`compressed` が `true`
- `fake.gz`・`production.log.1` に `compressed` が無い
- `size` がコンテナの中の `stat -c %s` と同じ。`updated_on` が時差つき

### [2-2] ログを標準出力に出しているとき

`RAILS_LOG_TO_STDOUT=true`（公式イメージの既定）の環境で [2-1] を流す。

**期待結果:** `log_file` が `null`

### [2-3] ファイル全体を gzip で順に読むと、元のファイルと一致する

```powershell
$fp = ($j.server_logs.files | Where-Object name -eq 'production.log.1').fingerprint
$sha = [Security.Cryptography.IncrementalHash]::CreateHash('SHA256'); $off = 0; $n = 0
do {
  $r = Get-Api "/server_logs/content.json?name=production.log.1&offset=$off&fingerprint=$fp" -Gzip
  if ($r.Status -ne 200) { throw "status $($r.Status)" }
  $len = [long](Get-Header $r 'X-Server-Log-Length'); $size = [long](Get-Header $r 'X-Server-Log-Size')
  if ($r.Body.Length -ne $len) { throw 'length mismatch' }
  $sha.AppendData($r.Body); $off += $len; $n++
} while ($off -lt $size)
[Convert]::ToHexString($sha.GetHashAndReset()).ToLower() -eq (Get-ContainerSha 'cat /usr/src/redmine/log/production.log.1')
```

**期待結果:**
- 一致する（`True`）。読み終わりの `$off` がファイルの大きさと同じ
- 応答の `Content-Encoding` が `gzip`、`Content-Type` が `application/octet-stream`、`Cache-Control` が `no-store`
- 1 回に送った量（`$r.Raw.Length`）がおよそ 1 MB 以下、読んだ量（`X-Server-Log-Length`）が 16 MB 以下

### [2-4] 途中の範囲（gzip なし・あり）

`offset`・`length` をいくつか変えて読み、コンテナの中の `tail -c +<offset+1> production.log.1 | head -c <返った量>` の SHA-256 と比べる。

**期待結果:**
- gzip なし：`Content-Encoding` が無く、1 回に 1 MB まで。中身が一致する
- gzip あり：展開した中身が一致する。返った量は `length` 以下
- 終わりを超える `length` は、ファイルの終わりで切れる（`X-Server-Log-Length` が残りのバイト数）

### [2-5] 圧縮されたファイルは圧縮し直さない

`production.log.2.gz` を [2-3] と同じように `-Gzip` で順に読む。

**期待結果:** 応答に `Content-Encoding` が無く、つないだバイトの SHA-256 がコンテナの中の `sha256sum production.log.2.gz` と同じ

### [2-6] 大きさ以上の offset・空のファイル

```powershell
(Get-Api "/server_logs/content.json?name=production.log.1&offset=$size").Status
(Get-Api '/server_logs/content.json?name=production.log.1&offset=1000000000000000000000000000000').Status
(Get-Api '/server_logs/content.json?name=empty.log&offset=0&fingerprint=0:').Status
```

**期待結果:** どれも 200 で本文が空。1 つ目は `X-Server-Log-Length` が 0、`X-Server-Log-Size` がファイルの大きさ

### [2-7] 409（見分けの印が違う）

```powershell
$r = Get-Api "/server_logs/content.json?name=production.log.1&offset=0&fingerprint=4096:$('0' * 64)"
$r.Status; ($r.Text | ConvertFrom-Json).fingerprint; Get-Header $r 'X-Server-Log-Size'
```

続けて次も確かめる。

- `small.log` に、ファイルより長いバイト数の印（`4096:` ＋ 64 文字）を渡す
- `small.log` の一覧の印を控え、`small.log` の中身を書き換えてから、控えた印で読む（ローテーションで入れ替わった場合）。終わったら中身を戻す
- 書き足されている `production.log` を、一覧の印で読む

**期待結果:**
- 1 つ目・2 つ目・3 つ目は 409。本文の `fingerprint` が今の印、`X-Server-Log-Size` が今の大きさ、`errors` がある
- 4 つ目（書き足されているだけ）は 200

### [2-8] 422

`offset` が無い・`-1`・`abc`・`1.5`、`length` が `0`・`-5`、`name` が無い、`fingerprint` が `xyz`。

**期待結果:** どれも 422 で `{"errors":[…]}`

### [2-9] 404（並ばないもの・ログフォルダーの外）

`name` に次を渡す: `../../config/database.yml`、`../config/configuration.yml`、`/etc/passwd`、`..`、`.`、`production.log.fifo`、`production.log.link`、`production.log.hl`、`production.log.hl2`、`archive`、`archive/production.log.9`、`.hidden.log`、`production.log:x`、`production.log.3.gz`、`nothing.log`、`PRODUCTION.LOG.1`（Linux のサーバー）、`production.log.1 `（後ろに空白）。

**期待結果:**
- どれも 404 で、本文が JSON の `{"errors":[…]}`
- 名前付きパイプでも待たされずにすぐ返る（数ミリ秒〜数十ミリ秒）
- `PRODUCTION.LOG.1` は、Windows のサーバーでは 200（大文字・小文字を区別しない）
- `name=bad%FF.log`（UTF-8 でない名前。URL にそのまま書く）は、API に届く前に Rails が 400 で断る（本文は JSON でない）。読めないことだけを確かめる

### [2-10] 401・403・形式

```powershell
(Get-Api '/server_logs.json' -Key '').Status
(Get-Api '/server_logs.json' -Key ('0' * 40)).Status
(Get-Api '/server_logs.json' -Key '{UserApiKey}').Status
(Get-Api '/server_logs/content.json?name=small.log&offset=0' -Key '{UserApiKey}').Status
(Get-Api '/server_logs/content.json?name=small.log&offset=0' -Key '').Status
(Get-Api '/server_logs.xml').Status
(Get-Api '/server_logs').Status
```

**期待結果:**
- API キーが無い・無効は 401（`WWW-Authenticate` が付く）、管理者でないと 403。どれも本文が `{"errors":[…]}`
- `.xml` は 404。拡張子なしは 200 で JSON
- 本体の「認証が必要」（`login_required`）を入れた状態でも、API キーが無いときは 401 の JSON

### [2-11] 429（同時に 2 つまで）

別のプロセスでロックを 2 つとも持ち、その間に読む。

```bash
MSYS_NO_PATHCONV=1 docker exec -u redmine -w /usr/src/redmine {Container} ruby -e 'fs=(0..1).map{|i| f=File.open("tmp/redmine_studio_plugin_server_logs_read_#{i}.lock", File::RDWR|File::CREAT); f.flock(File::LOCK_EX); f}; sleep 10'
```

**期待結果:**
- ロックを 2 つ持っている間：`content.json` は 429、`Retry-After: 2`、本文 `{"errors":[…]}`。`server_logs.json`（一覧）は 200
- ロックを 1 つだけ持っている間：200
- 16 MB の読み出しを 8 本同時に送ると、200 と 429 だけが返り、200 が 1 本以上ある（Puma のスレッドどうしでも数えられる）

### [2-12] 読み出しを続けている間も、ほかのリクエストが止まらない

1 本の流れで `content.json` を `offset` を進めながら読み続け、その間に別の流れで `GET /projects.json` を 0.05 秒おきに 40 回送り、かかった時間を測る。読み出しの前にも 10 回測っておく。

**期待結果:**
- Puma・Thin とも、読み出しの間の `/projects.json` がいちばん長くても 2 秒未満（目安は、読み出し 1 回にかかる時間＋ふだんの時間）
- 測った時間（読み出し 1 回の中央値・最大、`/projects.json` の中央値・最大）を結果に書く

### [2-13] Info API の追加項目

```powershell
(Get-Api '/info.json').Text | ConvertFrom-Json | ForEach-Object { $_.info.app_server; $_.info.log_level }
(Get-Api '/info.json' -Key '{UserApiKey}').Text
(Get-Api '/info.xml').Text
```

**期待結果:**
- 管理者：`app_server.name` が動いているサーバー（`puma` または `thin`）。`capacity` は Puma なら 1 以上の整数、Thin なら `null`。`log_level` が `info`
- 管理者でない：`app_server`・`log_level` の項目そのものが無い（ほかの項目はある）
- XML でも管理者にだけ `<app_server>`・`<log_level>` が出る

### [2-14] ログフォルダーがシンボリックリンクのとき

1 つの環境で、`log` フォルダーを別の場所へ移し、`log` をそこへのシンボリックリンクにしてから、コンテナを再起動する（ログフォルダーは起動の後に最初に使うときに決まるため）。

```bash
MSYS_NO_PATHCONV=1 docker exec {Container} bash -c 'cd /usr/src/redmine && mv log /var/redmine_log && ln -s /var/redmine_log log && chown -h redmine:redmine log'
docker restart {Container}
```

**期待結果:** [2-1] と同じ一覧が返り、`log_file` が `production.log`。`content.json` で読める。終わったら元に戻して再起動する

### [2-15] tmp に書けないとき

ロックのファイルを root の持ち物・モード 600 にして、Redmine から開けないようにする。

```bash
MSYS_NO_PATHCONV=1 docker exec {Container} bash -c 'cd /usr/src/redmine/tmp && for i in 0 1; do f=redmine_studio_plugin_server_logs_read_$i.lock; touch $f; chown root:root $f; chmod 600 $f; done'
```

**期待結果:** `content.json` は 200 で読める（数えずに読む）。`production.log` に `server_logs: concurrent read limit is disabled` の警告が 1 回だけ出る。終わったらロックのファイルを消す

---

## テスト実行方法

1. フェーズ 0: 環境の準備（ログをファイルに書く設定・Thin・試験用のログ）
2. フェーズ 1: Runner テスト（Puma の環境で 1 回）
3. フェーズ 2: HTTP テスト（5.x / 6.x / 7.x のそれぞれで、Puma と Thin）

### テストデータの管理

- 試験用のログは、フェーズ 0 でログフォルダーに作り、終わったら消す（`production.log` は Redmine が書いているので消さない）
- [2-7] で書き換えた `small.log`、[2-14] のシンボリックリンク、[2-15] のロックのファイルは、その場で元に戻す
- 管理者でないユーザーは、`{UserApiKey}` のユーザーを使う（新しく作らない）

### Runner テスト実行時の注意事項

- バッチごとに 1 つのスクリプトにまとめ、各テストの結果を `[1-1] OK` / `[1-1] NG: <理由>` の形で出す。1 つのテストが例外で止まっても、後続のテストは流れるように、テストごとに `begin`〜`rescue` で囲む
- スクリプトはファイルにして渡す（テンプレートのフェーズ 0）
- [1-6] は Runner のプロセスでロックを取るので、同じときに HTTP テストの読み出しを流さない
