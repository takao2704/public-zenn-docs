---
title: "SORACOM Flux から Slack API を使ってメッセージを送信する"
emoji: "🌊"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: []
published: false
---

:::message
この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## SORACOM Flux とは
SORACOM Flux は、SORACOM のローコードアプリ開発ツールです。これを使用することで、複雑なプログラミングを必要とせずに、さまざまなデータ処理や連携を実現できます。

## やりたいこと
SORACOM flux から Slack API を使ってメッセージを送信する方法を紹介します。
slack通知アクションでは困難だった改行とかスレッドへの返信ができるようになります。

## 事前準備
- Slack のワークスペースを持っていること
- SORACOM のアカウントを持っていること

## 手順
### 1. Slack App の作成
こちらの神ブログを参考にアプリの作成をします。
https://zenn.dev/kou_pg_0131/articles/slack-api-post-message
curlのサンプルによるテストが上手く行ったらこちらのブログに戻ってきてください。

### 2. SORACOM Flux の設定
1. SORACOM ユーザーコンソールにログインし、Flux の設定を開きます。
2. 新しいデータストリームを作成します。
3. アクションとして「Webhook」を選択し、以下の設定を行います：
   - **URL**: Slack の Webhook URL を入力します。
   - **Method**: `POST` を選択します。
   - **Headers**: 必要に応じて追加します（例: `Content-Type: application/json`）。
   - **Body**: Slack に送信するメッセージの内容を JSON 形式で記述します。
4. ルールを保存し、データストリームを有効化します。

### 3. テストとトラブルシューティング
- メッセージが Slack に届かない場合、Webhook URL やトークンを確認してください。
- SORACOM Flux の設定が正しいことを確認してください。

### 結論
この手順に従うことで、SORACOM Flux から Slack にメッセージを送信することができます。これにより、通知の柔軟性が向上し、さまざまなユースケースに対応できます。
