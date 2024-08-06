---
title: "Microsoft365でスマートフォンで撮影した写真を管理する仕組みを作る（step1）"
emoji: "🐥"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Microsoft 365","Power Automate","Microsoft Forms"]
published: false
---
## はじめに
Microsoft365でスマートフォンで撮影した写真を管理する仕組みを作っていきます。
まずは、Microsoft FormsとPower Automateを使って写真を送信し、送信結果をTeamsに通知する仕組みを作ります。

一連の作業を行うことで、以下のようなフローを実現していきます。
![alt text](images/forms-sending-photo/image-27.png)

## 事前準備
office 365のアカウントを持っていることが前提です。
以下のサービスが利用できることを確認してください。
- Microsoft Forms
- Power Automate
- SharePoint または OneDrive

## フォームの作成
1. https://www.office.com/ にアクセスし、Microsoft Formsを開きます。

    ![alt text](images/forms-sending-photo/image.png)

2. 新しいフォームを作成します。

    ![alt text](images/forms-sending-photo/image-1.png)

3. フォームのタイトルを入力します。

    ![alt text](images/forms-sending-photo/image-2.png)

4. 新規追加ボタンをクリックし、フォームに質問を追加します。

    ![alt text](images/forms-sending-photo/image-3.png)

    ![alt text](images/forms-sending-photo/image-5.png)

    ![alt text](images/forms-sending-photo/image-6.png)

    ![alt text](images/forms-sending-photo/image-7.png)


## Microsoft Teamsのチームを作成
1. Microsoft Teamsを開きます。
2. チームを作成します。

    ![alt text](images/forms-sending-photo/image-8.png)

3. チームの名前を入力し、チームを作成します。
    
    ![alt text](images/forms-sending-photo/image-9.png)

4. チームが作成されると、チームのメンバーを追加します。


## Power Automateの作成
1. Power Automateを開きます。

    ![alt text](images/forms-sending-photo/image-10.png)

2. 新しいフローを作成します。

    「+作成」から、「自動化したクラウドフロー」を選択します。

    ![alt text](images/forms-sending-photo/image-11.png)

3. トリガーを選択します。

    検索窓に「Forms」を入力し、「新しい応答が送信されるとき」を選択し「作成」をクリックします。

    ![alt text](images/forms-sending-photo/image-12.png)

4. フォームを選択します。

    ![alt text](images/forms-sending-photo/image-13.png)

5. フォームの質問に対応するアクションを追加します。

    ![alt text](images/forms-sending-photo/image-14.png)

6. アクションを追加します。

    検索窓に「Forms」と入力し、「フォームの応答の詳細を取得」を選択します。

    ![alt text](images/forms-sending-photo/image-17.png)

6. アクションの設定を行います。

    フォームのIDを選択し、フォームの応答IDを選択します。

    ![alt text](images/forms-sending-photo/image-18.png)

6. アクションを追加します。

    ![alt text](images/forms-sending-photo/image-19.png)

6. 検索窓に「メッセージを投稿」と入力し、「Microsoft Teams」の「チャットまたはチャネルでメッセージを投稿する」を選択します。

    ![alt text](images/forms-sending-photo/image-15.png)

7. 投稿先のチーム,チャネルを選択します。

    ![alt text](images/forms-sending-photo/image-16.png)

8. メッセージの本文を設定します。

    まずは以下のように入力して、
    ![alt text](images/forms-sending-photo/image-21.png)

    前のアクションで取得した内容を入力したい箇所にカーソルを合わせた状態で稲妻マークをクリックして入力します。

    ![alt text](images/forms-sending-photo/image-20.png)

    ![alt text](images/forms-sending-photo/image-22.png)

    同じ要領で追加していきます。
    ![alt text](images/forms-sending-photo/image-23.png)

9. 保存ボタンをクリックし、フローを保存します。

    ![alt text](images/forms-sending-photo/image-24.png)

10. ここまでの内容で一度テストを行います。

    保存したformを開き、プレビューから回答を送信します。
    ![alt text](images/forms-sending-photo/image-25.png)

11. Teamsのチャンネルにメッセージが投稿されていることを確認します。

    ![alt text](images/forms-sending-photo/image-26.png)
    
    
    
## まとめ

ここまででまずはFlowからPowerAutomateをつかってOffice365のサービスを連携させる方法を確認しました。
