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

## やりたいこと
SORACOM flux から Slack API を使ってメッセージを送信する方法を紹介します。
slack通知アクションでは困難だった改行とかスレッドへの返信ができるようになります。

## 事前準備
- Slack のワークスペースを持っていること
- SORACOM のアカウントを持っていること

## 手順
### 1. Slack App の作成
1. [Slack API](https://api.slack.com/apps) にアクセスして、新しいアプリを作成します。
