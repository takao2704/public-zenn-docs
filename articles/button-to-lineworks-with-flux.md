---
title: "SORACOM Button と LINE WORKS を Flux で連携して業務通知を自動化する"
emoji: "🔔"
type: "tech"
topics: ["soracom", "lineworks", "flux", "iot"]
published: false
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## はじめに

SORACOM Button は簡単に IoT 通知の仕組みを作れるデバイスです。本記事では SORACOM Flux の最新仕様を用い、Button 押下をトリガに LINE WORKS の Incoming Webhook へメッセージを送信する仕組みを解説します。

Flux では UI 上での設定とテンプレート変数を使用したデータ参照が中心となり、JavaScriptコードを記述することはありません。本記事は以下の公式ドキュメントに準拠しています：
- [Flux 概要](https://users.soracom.io/ja-jp/docs/flux/)
- [イベントソース: IoT デバイス](https://users.soracom.io/ja-jp/docs/flux/event-source-iot-device/)
- [アクション: Webhook](https://users.soracom.io/ja-jp/docs/flux/action-webhook/)

## 実現できること

- SORACOM Button の押下（シングル／ダブル／ロング）を検知し、指定の LINE WORKS トークルームに通知
- 押下種別・時刻・デバイス ID を含むメッセージの自動送信
- Flux のテンプレート機能を使った柔軟なメッセージ構築

### 想定ユースケース
- 設備点検完了の簡易報告
- 異常検知の一次連絡
- 在庫補充依頼
- 会議室利用開始／終了の共有

## 事前準備

- SORACOM アカウント
- SORACOM Button（LTE-M Button powered by AWS / Button Plus など）と内蔵 SIM のアクティブ化
- LINE WORKS テナント（Incoming Webhook 利用権限）
- SORACOM Flux 利用（月額料金が発生します）

## 全体構成

![alt text](/images/button-to-lineworks-with-flux/1754975318101.png)

## STEP 1: SORACOM LTE-M Button for Enterprise の基本確認

### 1-1. デバイスの登録

[ユーザーコンソールに SORACOM LTE-M Button for Enterprise を登録する](https://users.soracom.io/ja-jp/guides/soracom-lte-m-button-series/lte-m-button-enterprise/register/)に従って、ボタンの初期セットアップを行います。
https://users.soracom.io/ja-jp/guides/soracom-lte-m-button-series/lte-m-button-enterprise/register/

## STEP 2: LINE WORKS Incoming Webhook の準備

### 2-1. Webhook の設定

LINE WORKS で Incoming Webhook を設定します。詳細は [LINE WORKS Incoming Webhook](https://line-works.com/appdirectory/incoming-webhook/) を参照してください。

1. [アプリディレクトリ](https://apps.worksmobile.com/appdirectory) で Incoming Webhook を設定
![alt text](/images/button-to-lineworks-with-flux/1754910209102.png)
![alt text](/images/button-to-lineworks-with-flux/1754910241217.png)
![alt text](/images/button-to-lineworks-with-flux/1754910264228.png)
![alt text](/images/button-to-lineworks-with-flux/1754910281433.png)
![alt text](/images/button-to-lineworks-with-flux/1754910335090.png)
![alt text](/images/button-to-lineworks-with-flux/1754910352604.png)

2. 通知先のトークルーム（グループ）に Webhook を追加
![alt text](/images/button-to-lineworks-with-flux/1754910544687.png)
![alt text](/images/button-to-lineworks-with-flux/1754910566836.png)
![alt text](/images/button-to-lineworks-with-flux/1754910616214.png)
![alt text](/images/button-to-lineworks-with-flux/1754910691338.png)
![alt text](/images/button-to-lineworks-with-flux/1754911260093.png)
![alt text](/images/button-to-lineworks-with-flux/1754911275062.png)
![alt text](/images/button-to-lineworks-with-flux/1754911300220.png)
3. 発行された「Webhook URL」を控える
![alt text](/images/button-to-lineworks-with-flux/1754911393469.png)
4. アイコン・表示名など任意設定

:::message
Webhook URL は秘匿情報です。第三者に共有しないでください。
:::

### 2-2. 動作確認（任意）

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

1. コンソール左メニュー「データ処理」→「SORACOM Flux」
2. 「アプリ作成」→ アプリ名（例: button-to-lineworks）と説明を入力

### 3-2. イベントソース（IoT デバイス）の設定

1. イベントソースを追加 → 種別「IoT デバイス」を選択
2. 対象デバイスとして SORACOM Button の属する SIM/グループを指定
3. イベント条件を設定（押下イベント全てを対象にする場合は特に条件指定は不要）

イベントソースから取得できる主なデータ：
- `{{event.deviceId}}` - デバイス識別子
- `{{event.timestamp}}` - イベント発生時刻（UNIX ミリ秒）
- `{{event.payload.clickType}}` - ボタンの押下種別（1:シングル、2:ダブル、3:ロング）

参考: [イベントソース: IoT デバイス](https://users.soracom.io/ja-jp/docs/flux/event-source-iot-device/)

### 3-3. アクション（HTTP Webhook）の設定

1. アクションを追加 → 種別「Webhook」を選択
2. 基本設定：
   - **メソッド**: POST
   - **URL**: STEP 2 で取得した LINE WORKS Webhook URL
   - **ヘッダ**: Content-Type: application/json

### 3-4. メッセージ内容の構築

Flux の UI では、テンプレート変数と条件式を使用してメッセージを構築します。JavaScriptコードの記述は不要です。

**リクエストボディの設定例：**

アクションの設定画面で、以下のようなJSONテンプレートを設定します：

```json
{
  "content": {
    "type": "text",
    "text": "{{clickTypeMessage}}\n\nデバイス: {{event.deviceId}}\n押下種類: {{clickTypeName}}\n時刻: {{formattedTime}}"
  }
}
```

**テンプレート変数の定義：**

Flux の UI 上で、以下のような変数を定義できます（実際の設定方法は UI に従ってください）：

- `clickTypeMessage`: 
  - clickType が 1 の場合: "📍 点検が完了しました"
  - clickType が 2 の場合: "⚠️ 異常を検出しました"
  - clickType が 3 の場合: "🚨 緊急事態が発生しました"

- `clickTypeName`:
  - clickType が 1 の場合: "シングルクリック"
  - clickType が 2 の場合: "ダブルクリック"
  - clickType が 3 の場合: "ロングプレス"

- `formattedTime`: タイムスタンプを日本時間の読みやすい形式に変換

:::message
条件分岐は Flux UI の条件設定機能や、テンプレート内での三項演算子などを使用して実現します。具体的な設定方法は Flux の UI ガイドに従ってください。
:::

参考: [アクション: Webhook](https://users.soracom.io/ja-jp/docs/flux/action-webhook/)

### 3-5. 高度な設定（任意）

#### 複数アクションの設定

異なる押下種別に応じて異なるアクションを実行したい場合は、条件付きアクションを複数設定できます：

1. アクションに条件を設定（例：`event.payload.clickType == 3`）
2. 条件に応じて異なる Webhook URL や メッセージ内容を設定

#### Republish アクションの活用

デバッグや他システムへの連携のために、Republish アクションを追加できます：
- イベントデータを別のトピックに再発行
- 複数の宛先への同時配信

参考: [アクション: Republish](https://users.soracom.io/ja-jp/docs/flux/action-republish/)

## STEP 4: テストと動作確認

### 4-1. Flux アプリのデプロイ

1. Flux アプリを保存
2. 「デプロイ」ボタンでアプリを有効化
3. デプロイ状態を確認

### 4-2. エンドツーエンドテスト

1. **SORACOM Button を押下**
   - シングル、ダブル、ロングの各パターンでテスト

2. **Flux の実行ログ確認**
   - コンソールの Flux アプリ詳細画面で実行ログを確認
   - イベント受信とアクション実行の成功を確認

3. **LINE WORKS での受信確認**
   - 設定したトークルームでメッセージ受信を確認

期待される通知例：
```
📍 点検が完了しました

デバイス: button-xxxx
押下種類: シングルクリック
時刻: 2025/08/11 15:00:15
```

## トラブルシューティング

### Button からイベントが来ない場合
- LED 状態、SIM ステータス、電波状況を確認
- SORACOM コンソールのログでデータ送信を確認

### Flux でエラーが発生する場合
- 実行ログでエラー詳細を確認
- テンプレート変数の参照パスが正しいか確認
- まずは固定文字列でテストし、段階的に変数を追加

### LINE WORKS に届かない場合
- Webhook URL のコピーミスを確認
- JSON 形式が正しいか確認（Content-Type も含む）
- LINE WORKS 側の Webhook 設定・権限を確認

## 応用と拡張

### 複数デバイスの管理

デバイス ID に基づいて異なるメッセージや宛先を設定：
- Flux の条件機能を使用してデバイスごとにアクションを分岐
- デバイス ID をキーとした変数マッピングを活用

### 時間帯による制御

Flux の条件機能を使用して時間帯による制御を実装：
- 営業時間内外での通知先変更
- 緊急度に応じた通知の優先度設定

### データの蓄積と分析

- SORACOM Harvest との連携でデータ蓄積
- SORACOM Lagoon でのダッシュボード作成
- 押下履歴の可視化と分析

## まとめ

SORACOM Flux の最新仕様では、UI 上での設定とテンプレート変数を使用することで、コーディング不要で柔軟なデータ処理が可能です。主なポイント：

- イベントソースとアクションを UI で設定
- テンプレート変数（`{{event.payload.clickType}}` など）でデータ参照
- 条件分岐は UI の条件設定機能で実現
- JavaScriptコードの記述は不要

この仕組みにより、SORACOM Button と LINE WORKS の連携が簡単に実現でき、業務の効率化に貢献できます。

:::message
本記事は 2025年8月時点の公式ドキュメントに基づいています。各サービスの仕様は更新される可能性があるため、導入時は必ず最新の公式ドキュメントをご確認ください。
:::
