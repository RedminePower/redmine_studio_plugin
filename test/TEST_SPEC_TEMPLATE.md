# {機能名} テスト仕様書

<!--
新しい TEST_SPEC はこのファイルをコピーして test/features/{機能名}/TEST_SPEC.md として作る。

このリポジトリは公開されている。接続先 URL・ポート・サブディレクトリ・コンテナ名・パッチ版・
管理者のログイン/パスワード・API キーは書かない。
具体値の代わりに test/README.md のプレースホルダ（{BaseUrl} など）を使う。
PR の際に .github/workflows/public-repo-guard.yml が検査する。
-->

## 概要

redmine_studio_plugin の {機能名} 機能のテスト仕様。

{何を確かめるテストか}

対象バージョン: 5.x / 6.x / 7.x（バージョンで挙動が変わる場合は境界と期待値を書く）

接続先・認証情報・コンテナ名は実行環境から注入する（プレースホルダの契約は `test/README.md`）。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| コントローラ | |
| エンドポイント | |

---

## テスト実行フロー

### フェーズ 0: Runner テストの流し方

Puma は止めずに、動かしたまま Runner テストを流す。公式 Docker イメージでは Puma がコンテナの PID 1 なので、止めるとコンテナごと止まり、`docker exec` が使えなくなる。

各バッチの Ruby スクリプトはファイルにしてコンテナにコピーし、`redmine` 利用者で実行する。`bash -c "... rails runner '...'"` の形でコードを直接渡すと、`!` や引用符の扱いで壊れやすい。

```bash
docker cp batch1.rb {Container}:/tmp/{機能名}_batch1.rb
docker exec -u redmine -w /usr/src/redmine {Container} bundle exec rails runner /tmp/{機能名}_batch1.rb
```

- `bash` のブロックは bash で流す（Windows では Git Bash で、`MSYS_NO_PATHCONV=1` を付ける。付けないと `/usr/src/redmine` や `/tmp/...` が Windows のパスに書き換わる）
- `-u redmine` を付けずに root で動かすと、ログや `files` の中に root の持ち物のファイルができ、あとで Redmine から書けなくなることがある。root が要る手順だけ `-u` を付けずに行う
- `SQLite3::BusyException`（database is locked）が出たときは、少し待ってそのバッチを流し直す

### フェーズ 1: Runner テスト

### フェーズ 2: HTTP テスト

<!--
Runner テストで変えたのが DB の中身だけなら、コンテナの再起動は要らない（Puma はリクエストのたびに DB を読む）。
再起動が要るのは、cron などのプロセスを片づけるときや、Puma が読み込み済みのファイル・設定を変えたときだけ。
そのときは HTTP テストの前に「コンテナ再起動」のフェーズを置き、`docker restart {Container}` と、要る理由を書く。
-->

---

## 1. Runner テスト

### [1-1] {確認内容}

```ruby
```

**期待結果:**

---

## 2. HTTP テスト

### [2-1] {確認内容}

```powershell
$response = Invoke-RestMethod -Uri '{BaseUrl}/xxx.json' -Headers @{'X-Redmine-API-Key'='{ApiKey}'}
```

**期待結果:**

---

## テスト実行方法

1. フェーズ 0: Runner テストの流し方を確かめる（Puma は止めない）
2. フェーズ 1: Runner テスト実行
3. フェーズ 2: HTTP テスト実行

### テストデータの管理

<!-- テストで作るデータ・変える設定と、いつ作り・いつ消して元に戻すかを書く。何度流しても同じ結果になるようにする -->

### Runner テスト実行時の注意事項

- バッチごとに 1 つのスクリプトにまとめ、各テストの結果を `[1-1] OK` / `[1-1] NG: <理由>` の形で出す。1 つのテストが例外で止まっても、後続のテストは流れるように、テストごとに `begin`〜`rescue` で囲む
- スクリプトはファイルにして渡す（フェーズ 0）。bash の引数に Ruby のコードを直接書くと、`!` が履歴展開されたり引用符がずれたりする
- SQLite のロックエラーが出たときは、少し待ってそのバッチを流し直す（フェーズ 0）
