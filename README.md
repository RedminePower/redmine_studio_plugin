# redmine_studio_plugin

## 概要

[Redmine Studio](https://www.redmine-power.com/)（Redmine Power が提供する Windows クライアントアプリ）で必要な機能を提供するプラグインです。

## 機能

- **Reply Button** - チケットに「返答」ボタンを追加
- **Teams Button** - ユーザー名にチャットを開始する「Teams」ボタンを追加
- **Auto Close** - 条件に基づいてチケットを自動クローズ
- **Date Independent** - 親チケットの日付を子チケットから独立させる
- **Wiki Lists** - Wikiページやチケットの一覧を表示するマクロ
- **Subtask List Accordion** - 子チケット一覧にアコーディオン機能を追加
- **Plugin API** - プラグイン情報を取得する API（Redmine Studio が内部で使用）

## 対応 Redmine

- V5.x (V5.1.11 にて動作確認済み)
- V6.x (V6.1.1 にて動作確認済み)

## インストール

Redmine のインストール先はお使いの環境によって異なります。
以下の説明では `/var/lib/redmine` を使用しています。
お使いの環境に合わせて変更してください。

| 環境 | Redmine パス |
|------|-------------|
| apt (Debian/Ubuntu) | `/var/lib/redmine` |
| Docker (公式イメージ) | `/usr/src/redmine` |
| Bitnami | `/opt/bitnami/redmine` |

### 1. プラグインの配置

Redmine のプラグインフォルダにて、以下を実行します。

```bash
cd /var/lib/redmine/plugins
git clone https://github.com/RedminePower/redmine_studio_plugin.git
```

### 2. インストール

以下のコマンドを実行します。
このコマンドは旧プラグインの削除、DB マイグレーション、cron 登録を一括で行います。
必ず Redmine のインストール先のフォルダで実行してください。

```bash
cd /var/lib/redmine
bundle exec rake redmine_studio_plugin:install RAILS_ENV=production
```

### 3. Redmine の再起動

Redmine を再起動して変更を反映してください。

## Reply Button

チケットに「返答」ボタンを追加する機能です。

<img src="docs/images/reply_button_01.png" width="400">

- 「返答」ボタンをクリックすると、最終コメント投稿者が担当者に自動設定される
- コメントがない場合は、チケット作成者が担当者に設定される
- メールで返信する要領でチケット上でやり取りができ、チケット駆動型の開発に便利

詳細は [docs/reply_button.md](docs/reply_button.md) をご覧ください。

## Teams Button

ユーザー名の横に「Teams」ボタンを追加し、ワンクリックでチャットを開始できる機能です。

<img src="docs/images/teams_button_01.png" width="400">

- 「Teams」ボタンをクリックすると、そのユーザーとの Teams チャットが開く
- チャットにはチケット情報（タイトル、URL、チケット番号）が自動入力される

詳細は [docs/teams_button.md](docs/teams_button.md) をご覧ください。

## Auto Close

条件に基づいてチケットを自動的にクローズ（ステータス変更・担当者変更・コメント追加）する機能です。

- 全子チケット終了時に親チケットを自動クローズ
- 期限切れチケットを定期的に自動クローズ（cron で毎日 3:00 に実行）
- プロジェクト、トラッカー、ステータス、カスタムフィールドなど柔軟な条件設定が可能

詳細は [docs/auto_close.md](docs/auto_close.md) をご覧ください。

## Date Independent

親チケットの開始日・期日を子チケットから独立させる機能です。

Redmine の「子チケットの値から算出」設定はシステム全体に適用されるため、プロジェクトごとに挙動を変えることができません。
本機能を使うことで、特定のプロジェクトやステータスに応じて連動を制御できます。

- 特定のプロジェクトで親チケットの日付を独立させる
- 特定のステータス（例：終了）の場合は連動を維持する

詳細は [docs/date_independent.md](docs/date_independent.md) をご覧ください。

## Wiki Lists

Wikiページにチケットやページの一覧を表示するマクロを提供します。

<img src="docs/images/wiki_lists_03.png" width="400">

- `{{wiki_list}}` - Wikiページの一覧を表形式で表示
- `{{issue_name_link}}` - チケットの件名からリンクを生成
- `{{ref_issues}}` - 条件に合うチケットの一覧を表示

詳細は [docs/wiki_lists.md](docs/wiki_lists.md) をご覧ください。

## Subtask List Accordion

Redmine の子チケット一覧は、階層が深くなると全体を把握しにくくなります。
この機能は、子チケット一覧を折りたたみ/展開できるアコーディオン形式に変換し、複雑なチケット構造でも必要な部分だけを表示して作業できるようにします。

<img src="docs/images/subtask_list_accordion_01.png" width="500">

- 子チケット一覧の各階層を折りたたみ/展開可能
- 子チケット一覧の上部に「すべて展開」「すべて収縮」リンクを追加
- 右クリックメニューから「このツリーを展開」「このツリーを収縮」「この階層をすべて展開」を選択可能

詳細は [docs/subtask_list_accordion.md](docs/subtask_list_accordion.md) をご覧ください。

## Plugin API

| エンドポイント | 説明 |
|---------------|------|
| `GET /plugins.json` | プラグイン一覧の取得 |
| `GET /plugins/:id.json` | 単体プラグイン情報の取得 |

## アンインストール

### 1. アンインストールコマンドの実行

cron 解除と DB ロールバックを行います。

```bash
cd /var/lib/redmine
bundle exec rake redmine_studio_plugin:uninstall RAILS_ENV=production
```

### 2. プラグインの削除

プラグインのフォルダを削除してください。

```bash
cd /var/lib/redmine/plugins
rm -rf redmine_studio_plugin
```

## ライセンス

GPL v2 License
