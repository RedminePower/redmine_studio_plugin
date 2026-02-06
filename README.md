# redmine_studio_plugin

## 概要

[Redmine Studio](https://www.redmine-power.com/)（Redmine Power が提供する Windows クライアントアプリ）で必要な機能を提供するプラグインです。

### 前提条件

「管理」→「設定」→「API」にて「REST による Web サービスを有効にする」を有効にしてください。

## 機能

- **Reply Button** - チケットに「返答」ボタンを追加
- **Teams Button** - ユーザー名にチャットを開始する「Teams」ボタンを追加
- **Auto Close** - 条件に基づいてチケットを自動クローズ
- **Date Independent** - 親チケットの日付を子チケットから独立させる
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

### 2. インストール

以下のコマンドを実行します。このコマンドは旧プラグインの削除、DB マイグレーション、cron 登録を一括で行います。

```bash
cd /path/to/redmine
bundle exec rake redmine_studio_plugin:install RAILS_ENV=production
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

## Teams Button

ユーザー名の横に「Teams」ボタンを追加し、ワンクリックでチャットを開始できる機能です。

- 「Teams」ボタンをクリックすると、そのユーザーとの Teams チャットが開く
- チャットにはチケット情報（タイトル、URL、チケット番号）が自動入力される

### 対応クライアント

- Office365 を利用していること（Windows10、Android で動作確認済み）
  - Teams を起動するために、DeepLink 機能を使用しているため

### 有効化

本機能はプロジェクトごとに有効・無効を切り替えられます。
以下の設定を行わないと「Teams」ボタンは表示されません。

1. プロジェクトの「設定」を開く
2. 「プロジェクト」タブ内の「モジュール」で「Teams button」にチェックを入れて保存

## Auto Close

条件に基づいてチケットを自動的にクローズ（ステータス変更・担当者変更・コメント追加）する機能です。

- 全子チケット終了時に親チケットを自動クローズ
- 期限切れチケットを定期的に自動クローズ（cron で毎日 3:00 に実行）
- プロジェクト、トラッカー、ステータス、カスタムフィールドなど柔軟な条件設定が可能

### 管理画面

管理者メニューの「自動クローズ」からルールの作成・編集・削除ができます。

### 期限切れチケットの手動実行

期限切れトリガーは cron で自動実行されますが、手動で実行する場合は以下のコマンドを使用します。

```bash
bundle exec rake redmine_studio_plugin:auto_close:check_expired RAILS_ENV=production
```

## Date Independent

親チケットの開始日・期日を子チケットから独立させる機能です。

Redmine では「子チケットの値から算出」設定を有効にすると、親チケットの日付が子チケットから自動計算されます。
本機能を使うと、プロジェクトやステータスに応じてこの動作を制御できます。

- 特定のプロジェクトで親チケットの日付を独立させる
- 特定のステータス（例：終了）の場合は連動を維持する

### 管理画面

管理者メニューの「開始日/期日の独立」からルールの作成・編集・削除ができます。

## Plugin API

| エンドポイント | 説明 |
|---------------|------|
| `GET /plugins.json` | プラグイン一覧の取得 |
| `GET /plugins/:id.json` | 単体プラグイン情報の取得 |

## アンインストール

### 1. アンインストールコマンドの実行

cron 解除と DB ロールバックを行います。

```bash
cd /path/to/redmine
bundle exec rake redmine_studio_plugin:uninstall RAILS_ENV=production
```

### 2. プラグインの削除

プラグインのフォルダを削除してください。

```bash
cd /path/to/redmine/plugins
rm -rf redmine_studio_plugin
```

## ライセンス

MIT License
