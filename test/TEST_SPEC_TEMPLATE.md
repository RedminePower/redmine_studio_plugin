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

### フェーズ 0: Puma 停止

```bash
docker exec {Container} bash -c "kill $(cat /usr/src/redmine/tmp/pids/server.pid)"
```

### フェーズ 1: Runner テスト

### フェーズ 2: コンテナ再起動

```bash
docker restart {Container}
```

### フェーズ 3: HTTP テスト

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
