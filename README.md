# redmine_studio_plugin

## 概要

[Redmine Studio](https://www.redmine-power.com/)（Redmine Power が提供する Windows クライアントアプリ）で必要な機能を提供するプラグインです。

## 機能

- インストールされているプラグインの情報を取得できる API の追加
  - プラグイン一覧の取得
  - 単体プラグイン情報の取得（設定値を含む）

## 対応 Redmine

- V5.x (V5.1.11 にて動作確認済み)
- V6.x (V6.1.1 にて動作確認済み)

## インストール

Redmine のプラグインフォルダにて、以下を実行し、Redmine を再起動してください。

```
$ cd /var/lib/redmine/plugins
$ git clone https://github.com/RedminePower/redmine_studio_plugin.git
```

## 使用方法

### 前提条件

- 管理 > 設定 > API にて「REST による Web サービスを有効にする」を有効にしてください。

### API エンドポイント

本プラグインは以下の API を提供します。Redmine Studio の処理に使用されます。

| エンドポイント | 説明 |
|---------------|------|
| `GET /plugins.json` | プラグイン一覧の取得 |
| `GET /plugins/:id.json` | 単体プラグイン情報の取得 |

## アンインストール

プラグインのフォルダを削除してください。

```
$ cd /var/lib/redmine/plugins
$ rm -rf redmine_studio_plugin
```

## ライセンス

MIT License
