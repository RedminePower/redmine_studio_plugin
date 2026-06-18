# Wiki Preview API

Wiki 記法のテキストを HTML に変換する API。Redmine 本体のプレビュー画面と同じレンダリングを行い、API キー認証だけで利用できる。

WebView2 でブラウザに自動ログインしてプレビューを行う従来方式は 2 段階認証（2FA）を有効にしたユーザーで失敗するため、本 API でブラウザログイン不要のプレビューを実現する。

## エンドポイント一覧

| エンドポイント | 説明 |
|---------------|------|
| `POST /wiki_preview.json` | Wiki テキストの HTML 変換 |

## 認証

API キー認証が必要。

## パラメータ

| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `text` | string | ○ | 変換する Wiki 記法のテキスト（空文字も可。空の場合は空文字を返す） |
| `project_id` | int | | プロジェクトのコンテキスト。マクロや `#123` チケットリンク、`[[Wiki ページ]]` リンクの解決に使用する。未指定の場合はプロジェクトに依存しない範囲でレンダリングする |

## レンダリング

Redmine 本体のプレビュー画面と同じ `textilizable` を使用する。Redmine の設定（Textile / Markdown / CommonMark）に従い、以下をすべて展開する。

- 見出し・リスト・テーブル・装飾などの基本記法
- マクロ（`{{toc}}`、`{{collapse}}`、プラグイン提供マクロなど）
- `#123` 形式のチケットリンク
- `[[Wiki ページ]]` 形式の Wiki リンク

リンクは Redmine 本体のプレビューと同様に相対パス（例: `/issues/123`）で出力される。

## レスポンス形式

API は JSON と XML の両方をサポートする。

| 拡張子 | Content-Type |
|--------|--------------|
| `.json` | application/json |
| `.xml` | application/xml |

例:
```
POST /wiki_preview.json   → JSON 形式で返却
POST /wiki_preview.xml    → XML 形式で返却
```

---

## Wiki テキストの HTML 変換

### POST /wiki_preview

Wiki 記法のテキストを HTML に変換する。

リクエスト:

```json
{
  "text": "h1. 見出し\n\n* 項目1\n* 項目2\n\n関連: #123",
  "project_id": 1
}
```

レスポンス:

```json
{
  "wiki_preview": {
    "html": "<h1>見出し</h1>\n\n<ul>\n<li>項目1</li>\n<li>項目2</li>\n</ul>\n\n<p>関連: <a class=\"issue\" href=\"/issues/123\">#123</a></p>"
  }
}
```

---

## レスポンスフィールド

### wiki_preview

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `html` | string | 変換後の HTML |

---

## エラーレスポンス

| ステータス | 条件 |
|-----------|------|
| 401 | API キー未指定（認証が必要な環境のみ） |
| 404 | 指定した `project_id` のプロジェクトが存在しない、または閲覧権限がない |
| 422 | 必須パラメータ `text` が未指定 |

### 422 エラー例

```json
{
  "errors": ["text is required"]
}
```
