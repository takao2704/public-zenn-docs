---
title: "ボタンデバイスのクリックをトリガにLINE WORKS にメッセージ投稿する。ローコードで"
emoji: "🔔"
type: "tech"
topics: ["soracom", "lineworks", "soracomflux", "iot"]
published: true
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## はじめに

SORACOM LTE-M Button for Enterprise は簡単に IoT 通知の仕組みを作れるデバイスです。本記事では SORACOM Flux を使ってButton 押下をトリガに LINE WORKS の Incoming Webhook へメッセージを送信する仕組みを解説します。

## 実現できること

- SORACOM Button の押下（シングル／ダブル／ロング）を検知し、指定の LINE WORKS トークルームに通知
- 押下種別・時刻・デバイス ID を含むメッセージの自動送信
- ローコードIoTアプリケーションビルダー SORACOM Flux を使った柔軟なメッセージ構築


## 事前準備

- SORACOM アカウント
- SORACOM LTE-M Button for Enterpriseのアクティブ化
- LINE WORKS テナント（Incoming Webhook 利用権限）

## 全体構成

![alt text](/images/button-to-lineworks-with-flux/1754975318101.png)

## STEP 1: SORACOM LTE-M Button for Enterprise のセットアップ

### 1-1. デバイスの登録

[ユーザーコンソールに SORACOM LTE-M Button for Enterprise を登録する](https://users.soracom.io/ja-jp/guides/soracom-lte-m-button-series/lte-m-button-enterprise/register/)に従って、ボタンの初期セットアップを行います。
https://users.soracom.io/ja-jp/guides/soracom-lte-m-button-series/lte-m-button-enterprise/register/

## STEP 2: LINE WORKS Incoming Webhook の準備

### 2-1. Webhook の設定

LINE WORKS で Incoming Webhook を設定します。詳細は [LINE WORKS Incoming Webhook](https://line-works.com/appdirectory/incoming-webhook/) を参照してください。
https://line-works.com/appdirectory/incoming-webhook/

1. [アプリディレクトリ](https://apps.worksmobile.com/appdirectory)で「Incoming webhook」を選択
![alt text](/images/button-to-lineworks-with-flux/1754910209102.png)
1. 「追加する」をクリックしてアプリを追加します。
![alt text](/images/button-to-lineworks-with-flux/1754910241217.png)
1. 規約を読んでチェックボックスすべてONにして同意した後に「次へ」をクリックします。
![alt text](/images/button-to-lineworks-with-flux/1754910264228.png)
1. アプリを利用するメンバーを選択して保存します。
![alt text](/images/button-to-lineworks-with-flux/1754910281433.png)
1. アプリの追加を完了させていきます。
![alt text](/images/button-to-lineworks-with-flux/1754910335090.png)
![alt text](/images/button-to-lineworks-with-flux/1754910352604.png)
1. 通知先のトークルーム（グループ）に botを招待します。
![alt text](/images/button-to-lineworks-with-flux/1754911300220.png)
![alt text](/images/button-to-lineworks-with-flux/1755002193208.png)
1. 招待が完了したら以下のようなメッセージが投稿されます。
![alt text](/images/button-to-lineworks-with-flux/1755002308951.png)
1. チャンネルIDをクリックします。
![alt text](/images/button-to-lineworks-with-flux/1754911260093.png)
1. チャンネルIDを控えます。
![alt text](/images/button-to-lineworks-with-flux/1754911275062.png)
1. 先程の投稿の「Webhookリスト」をクリックします。
![alt text](/images/button-to-lineworks-with-flux/1755002308951.png)
1. 「追加」をクリックしてwebhookを設定します。
![alt text](/images/button-to-lineworks-with-flux/1755002366628.png)
1. 控えたチャンネルIDを設定します。
![alt text](/images/button-to-lineworks-with-flux/1755001859715.png)
3. 発行された「Webhook URL」を控えます。
![alt text](/images/button-to-lineworks-with-flux/1754911393469.png)

:::message
Webhook URL は秘匿情報です。第三者に共有しないでください。
:::

### 2-2. 動作確認

curl コマンドでテスト送信して動作確認：

```bash
curl -X POST "<取得した Webhook URL>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "送信テスト",
    "body": {
      "text": "テスト通知です"
    },
    "button":
      {
        "label": "詳細を表示",
        "url": "https://soracom.jp"
      }
  }'
```

![alt text](/images/button-to-lineworks-with-flux/1754922329501.png)



## STEP 3: SORACOM Flux の設定

SORACOM Flux では、イベントソースとアクションを UI 上で設定します。コードの記述は不要で、テンプレート変数を使用してデータを参照・加工します。

### 3-1. アプリ作成

1. コンソール左メニュー「SORACOM Flux」-> 「Flux アプリ」
![alt text](/images/button-to-lineworks-with-flux/1755004560412.png)
1. 「+新しいFluxアプリを作成する」をクリック
![alt text](/images/button-to-lineworks-with-flux/1755004536996.png)
1. 「最初から作成」をクリック
![alt text](/images/button-to-lineworks-with-flux/1755004647112.png)
1. アプリ名（例: button to LINEWORKS）と説明（空欄でもOK）を入力
![alt text](/images/button-to-lineworks-with-flux/1755004670361.png)


### 3-2. イベントソース（IoT デバイス）の設定

1. 「+チャンネルを作成する」をクリック
![alt text](/images/button-to-lineworks-with-flux/1755004704175.png)
1. 「IoT デバイス」を選択して次へ
![alt text](/images/button-to-lineworks-with-flux/1755004717739.png)
1. ボタンデバイスが所属しているグループを選択して「チャネルを作成する」をクリック
![alt text](/images/button-to-lineworks-with-flux/1755004750394.png)

参考: [イベントソース: IoT デバイス](https://users.soracom.io/ja-jp/docs/flux/event-source-iot-device/)

### 3-3. イベントソースからwebhookに接続するアクションの設定

このブロックは後で、設定を調整するために使います。今の時点ではデータを何も処理せずにイベントを後段のアクションに転送します。

1. 「アクション」のタブに移って「アクションを追加」
![alt text](/images/button-to-lineworks-with-flux/1755049013539.png)
1. 「Republish」を選択して「OK」をクリック
![alt text](/images/button-to-lineworks-with-flux/1755049839647.png)
1. 以下のような設定で「作成する」をクリック
![alt text](/images/button-to-lineworks-with-flux/1755004839794.png)


### 3-4. アクション（HTTP Webhook）の設定

1. Studioに戻ると以下のようなフローができています。一番右の「Output Channel」の土管をクリックします。
![alt text](/images/button-to-lineworks-with-flux/1755004867260.png)
1. 「アクション」のタブから「アクションを追加」
![alt text](/images/button-to-lineworks-with-flux/1755004887502.png)
1. 「Webhook」を選択して「OK」をクリック
![alt text](/images/button-to-lineworks-with-flux/1755004902232.png)
1. 以下のような設定で「作成する」をクリック
**CONFIG:HTTPメソッド**: POST
**CONFIG:URL**: STEP 2 で取得した LINE WORKS Webhook URL
**CONFIG:認証方法**:なし
**CONFIG:HTTPヘッダ-**: Content-Type: application/json
**CONFIG:HTTPボディ**:
```json
{
  "title": "送信テスト",
  "body": {
    "text": "テスト通知です"
  },
  "button": {
    "label": "詳細を表示",
    "url": "https://soracom.jp"
  }
}
```
![alt text](/images/button-to-lineworks-with-flux/1755005028708.png)
6. 以下のようなフローができていたら完成
![alt text](/images/button-to-lineworks-with-flux/1755005055843.png)


参考: [アクション: Webhook](https://users.soracom.io/ja-jp/docs/flux/action-webhook/)


## STEP 4: 動作確認

1. **SORACOM Button を押下**
   - ボタンをシングルクリック
   - オレンジの点滅後に緑の点灯があれば成功。

2. **Flux の実行ログ確認**
   - コンソールの Flux アプリ詳細画面で実行ログを確認
   - イベント受信とアクション実行の成功を確認
    ![alt text](/images/button-to-lineworks-with-flux/1755072301230.png)

3. **LINE WORKS での受信確認**
   - 設定したトークルームでメッセージ受信を確認
   ![alt text](/images/button-to-lineworks-with-flux/1755072365808.png)

## STEP 5: ボタンの押しかたによって投稿されるメッセージを変更する

STEP 3-4 で設定した静的なテストメッセージを、実際のボタンデータを使った動的なメッセージに変更します。
今回は以下のようなボタンの押し方によってメッセージを分けることを考えます。

1. **シングルクリック** 
  メッセージ: 「✅ 作業が完了しました」

2. **ダブルクリック**
  メッセージ: 「⚠️ 緊急対応が必要です」

3. **ロングクリック**
  メッセージ: 「🚨 異常を検知しました」


### 5-1. SORACOM Button のデータフォーマット

#### 基本的なデータ構造
IoTデバイスイベントチャネルのpayloadは以下のようなJSONとなっています。

```json
{
  "clickType": 1,
  "clickTypeName": "SINGLE",
  "batteryLevel": 1,
  "binaryParserEnabled": true
}
```

#### 各フィールドの詳細

| フィールド名 | 型 | 説明 | 値の範囲 |
|------------|---|------|---------|
| `clickType` | 数値 | クリックの種類を表す数値 | 1: シングル<br>2: ダブル<br>3: ロング |
| `clickTypeName` | 文字列 | クリックの種類を表す文字列 | "SINGLE"<br>"DOUBLE"<br>"LONG" |
| `batteryLevel` | 数値 | バッテリー残量（4段階） | 1.0: 満充電<br>0.75: 75%<br>0.5: 50%<br>0.25: 25% |
| `binaryParserEnabled` | 真偽値 | バイナリパーサーの有効/無効 | true または false |

### 5-4. Republish アクションの設定変更
クリックタイプごとに別々のrepublishアクションを作成し、それぞれに実行条件（condition）を設定します。
最終形態はこんな感じになります。
![alt text](/images/button-to-lineworks-with-flux/1755090011103.png)


「IoT Device Channel」をクリックします。
![alt text](/images/button-to-lineworks-with-flux/1755087375793.png)

#### 手順1: シングルクリック用のRepublishアクションを設定

1. 「アクション」タブに移動
2. 既存のRepublishアクションの「詳細」を選択
![alt text](/images/button-to-lineworks-with-flux/1755087396512.png)
3. 以下の設定に変更：
   - **CONDITION:アクションの実行条件**: `payload.clickType == 1`
   - **CONFIG:データを変換する**:✅️
   - **CONFIG:Content Type**: `application/json`
   - **CONFIG:Content**:
   ```json
   {
     "text": "✅ 作業が完了しました",
     "batteryLevel": ${payload.batteryLevel}
   }
   ```
   - **OUTPUT:アクションのアウトプットを別のチャネルに送信する**: 有効
   - **OUTPUT:送信先チャネル**: Output Channel

   ![alt text](/images/button-to-lineworks-with-flux/1755087775857.png)

#### 手順2: ダブルクリック用のRepublishアクションを作成
1. 同様に「アクションを追加」
2. 「Republish」を選択
3. 以下の設定で作成：
   - **CONDITION:アクションの実行条件**: `payload.clickType == 2`
   - **CONFIG:データを変換する**:✅️
   - **CONFIG:Content Type**: `application/json`
   - **CONFIG:Content**:
   ```json
   {
     "text": "⚠️ 緊急対応が必要です",
     "batteryLevel": ${payload.batteryLevel}
   }
   ```
   - **OUTPUT:アクションのアウトプットを別のチャネルに送信する**: 有効
   - **OUTPUT:送信先チャネル**: Output Channel



#### 手順3: ロングクリック用のRepublishアクションを作成
1. 同様に「アクションを追加」
2. 「Republish」を選択
3. 以下の設定で作成：
   - **CONDITION:アクションの実行条件**: `payload.clickType == 3`
   - **CONFIG:データを変換する**:✅️
   - **CONFIG:Content Type**: `application/json`
   - **CONFIG:Content**:
   ```json
   {
     "text": "🚨 異常を検知しました",
     "batteryLevel": ${payload.batteryLevel}
   }
   ```
   - **OUTPUT:アクションのアウトプットを別のチャネルに送信する**: 有効
   - **OUTPUT:送信先チャネル**: Output Channel



### 5-5. Webhook ボディの修正

STEP 3-4 で設定した Webhook アクションを編集し、republishアクションから受け取ったデータを使用するようにHTTPボディを変更します：

1. Flux Studio で Webhook アクションをクリック
2. 「編集」ボタンをクリック
3. HTTPボディを以下のように変更：

```json
{
  "title": "🔔 ボタン通知",
  "body": {
    "text": "${payload.text}\n\nバッテリー: ${payload.batteryLevel * 100}%"
  },
  "button": {
    "label": "コンソールで確認",
    "url": "https://console.soracom.io/"
  }
}
```

これで、3つのrepublishアクションのいずれかが条件に応じて実行され、そのペイロードがWebhookアクションに渡されます。
![alt text](/images/button-to-lineworks-with-flux/1755088720362.png)
