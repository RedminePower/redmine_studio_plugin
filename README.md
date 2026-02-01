# redmine_studio_plugin

## 概要

[Redmine Studio](https://www.redmine-power.com/)（Redmine Power が提供する Windows クライアントアプリ）で必要な機能を提供するプラグインです。

### 前提条件

「管理」→「設定」→「API」にて「REST による Web サービスを有効にする」を有効にしてください。

## 機能

- **Reply Button** - チケットに「返答」ボタンを追加
- **Plugin API** - プラグイン情報を取得する API（Redmine Studio が内部で使用）

## 対応 Redmine

- V5.x (V5.1.11 にて動作確認済み)
- V6.x (V6.1.1 にて動作確認済み)

## インストール

### 1. プラグインの配置

Redmine のプラグインフォルダにて、以下を実行します。

```bash
cd /path/to/redmine/plugins
git clone https://github.com/RedminePower/redmine_studio_plugin.git
```

### 2. セットアップ

以下のコマンドを実行します。このコマンドは統合済みプラグインの削除を行います。

```bash
cd /path/to/redmine
bundle exec rake redmine_studio_plugin:setup RAILS_ENV=production
```

### 3. Redmine の再起動

Redmine を再起動して変更を反映してください。

## Reply Button

チケットに「返答」ボタンを追加する機能です。

- 「返答」ボタンをクリックすると、最終コメント投稿者が担当者に自動設定される
- コメントがない場合は、チケット作成者が担当者に設定される
- メールで返信する要領でチケット上でやり取りができ、チケット駆動型の開発に便利

### 有効化

本機能はプロジェクトごとに有効・無効を切り替えられます。
以下の設定を行わないと「返答」ボタンは表示されません。

1. プロジェクトの「設定」を開く
2. 「プロジェクト」タブ内の「モジュール」で「Reply button」にチェックを入れて保存

## Plugin API

| エンドポイント | 説明 |
|---------------|------|
| `GET /plugins.json` | プラグイン一覧の取得 |
| `GET /plugins/:id.json` | 単体プラグイン情報の取得 |

## アンインストール

プラグインのフォルダを削除してください。

```bash
cd /path/to/redmine/plugins
rm -rf redmine_studio_plugin
```

## ライセンス

MIT License
