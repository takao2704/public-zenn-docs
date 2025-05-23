---
title: "ソラカメとAIでエメラルドグリーンTシャツを検知してパトライトを点灯させる展示会デモの作り方"
emoji: "🚨"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [IoT,SORACOM,ソラカメ,パトライト,soracomflux]
published: false
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## はじめに

展示会のブースでは、来場者の注目を集めるためにインタラクティブなデモが効果的です。本記事では、SORACOM Fluxを活用して「ソラカメの画角内で人が動いたらパトライトが点灯し、さらにエメラルドグリーン色のTシャツを着た人が映っていると別の色のパトライトが点灯する」という展示会デモの実装方法を紹介します。

このデモでは以下の機能を実現します：
1. ソラカメの画角内で人が動いたことを検知すると、パトライトの橙色が点灯
2. 映像内にエメラルドグリーン色のTシャツを着た人が映っていると、パトライトの赤色が点灯
3. ボタンデバイスを押すとパトライトが消灯

![デモの概要図](/images/soracam-flux-patlite/1747031857097.png)

## システム構成

### 使用機器とサービス

- **SORACOM アカウント**: 各種サービスの利用に必要
- **ソラカメ**: 人の動きを検知するカメラ
- **SORACOM Air**: LTE通信用のSIM
- **LTEルーター**: インターネット接続用
- **パトライト（HTTP対応）**: 視覚的な通知装置
- **スイッチングハブ**: 機器の接続用
- **LANケーブル**: 機器の接続用
- **設定用PC**: 各種設定作業用

### 配線接続

下記のように機器を接続します。LTEルーターとパトライトはLANケーブルで接続し、ソラカメは無線でインターネットに接続します。

![配線接続図](/images/soracam-flux-patlite/1747149359098.png)

## SORACOM Fluxの設定

SORACOM Fluxは、様々なイベントをトリガーにしてアクションを実行できるサービスです。今回は以下のようなフローを構築します。

![SORACOM Fluxの設定概要](/images/soracam-flux-patlite/1747233997143.png)

### チャネルの設定

SORACOM Fluxでは、データの入出力経路として「チャネル」を設定します。今回のデモでは以下の7つのチャネルを使用します：

1. **API Channel**: 外部からのAPI呼び出しを受け付けるチャネル
2. **Output Channel**: アクションからの出力を受け取るチャネル
3. **IoT Device Channel**: IoTデバイスからのイベントを受け取るチャネル
4. **Output**: SORACOM APIアクションの出力チャネル
5. **Harvest Files Event Channel**: Harvest Filesからのイベントを受け取るチャネル
6. **Output AI**: AI分析結果の出力チャネル
7. **Output Channel 2**: 2つ目の出力チャネル

### アクションの設定

次に、各チャネル間でデータを処理する「アクション」を設定します。今回のデモでは以下の8つのアクションを使用します：

#### 1. ボタンデバイスからの信号処理（パトライト消灯）

:::details アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | payload.deviceId=="7CDDE902DBC3" | 特定のボタンデバイスからの信号のみを処理 |
| CONFIG | transform.contentType | application/json | JSONフォーマットで出力 |
| CONFIG | transform.content | {"command":"011990"} | パトライト制御コマンド（黄色と緑色を点灯） |
| OUTPUT | 送信先チャネル | Output Channel | 出力先チャネル |
:::

#### 2. IoTデバイスからのイベント処理（パトライト点灯）

:::details アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | なし | すべてのイベントを処理 |
| CONFIG | transform.contentType | application/json | JSONフォーマットで出力 |
| CONFIG | transform.content | {"command":"000990"} | パトライト制御コマンド（すべて消灯） |
| OUTPUT | 送信先チャネル | Output Channel | 出力先チャネル |
:::

#### 3. パトライト制御API呼び出し

:::details アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | なし | すべてのイベントを処理 |
| CONFIG | path | /v1/sims/8981100005605415950/downlink/http | SIMのHTTPダウンリンク |
| CONFIG | method | POST | HTTPメソッド |
| CONFIG | body | {"method": "GET", "path": "/api/control?alert=${payload.command}", "port": 50080, "skipVerify": true, "ssl": false} | パトライト制御API呼び出し |
| OUTPUT | 送信先チャネル | Output | 出力先チャネル |
:::

#### 4. ソラカメ画像のAI解析

:::details アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | なし | すべてのイベントを処理 |
| CONFIG | service | azure-openai | 使用するAIサービス |
| CONFIG | model | gpt-4o | 使用するAIモデル |
| CONFIG | user_prompt | 画像を解析し、画像の中にエメラルドグリーン色のTシャツを来ている人が写っているか確認してください。出力はJSONで... | AIへの指示 |
| CONFIG | response_format | json | 応答フォーマット |
| CONFIG | image_url | ${payload.presignedUrls.get} | 解析する画像のURL |
| OUTPUT | 送信先チャネル | Output AI | 出力先チャネル |
:::

#### 5. AI結果が真の場合の処理（エメラルドグリーンTシャツあり）

:::details アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | payload.output.result == true | AIがエメラルドグリーンTシャツを検出した場合 |
| CONFIG | transform.contentType | application/json | JSONフォーマットで出力 |
| CONFIG | transform.content | {"command":"111119"} | パトライト制御コマンド（すべて点灯、ブザー鳴動） |
| OUTPUT | 送信先チャネル | Output Channel 2 | 出力先チャネル |
:::

#### 6. パトライト制御API呼び出し（AI結果に基づく）

:::details アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | なし | すべてのイベントを処理 |
| CONFIG | path | /v1/sims/8981100005605415950/downlink/http | SIMのHTTPダウンリンク |
| CONFIG | method | POST | HTTPメソッド |
| CONFIG | body | {"method": "GET", "path": "/api/control?alert=${payload.command}", "port": 50080, "skipVerify": true, "ssl": false} | パトライト制御API呼び出し |
| OUTPUT | 送信先チャネル | なし | 出力なし |
:::

#### 7. AI結果が偽の場合の処理（エメラルドグリーンTシャツなし）

:::details アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | payload.output.result == false | AIがエメラルドグリーンTシャツを検出しなかった場合 |
| CONFIG | transform.contentType | application/json | JSONフォーマットで出力 |
| CONFIG | transform.content | {"command":"000000"} | パトライト制御コマンド（すべて消灯） |
| OUTPUT | 送信先チャネル | Output Channel 2 | 出力先チャネル |
:::

#### 8. ソラカメ画像のエクスポート

:::details アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | event.payload.deviceId != null | デバイスIDが存在する場合のみ処理 |
| CONFIG | path | /v1/sora_cam/devices/${event.payload.deviceId}/images/exports | ソラカメ画像エクスポートAPI |
| CONFIG | method | POST | HTTPメソッド |
| CONFIG | body | {"time": ${now()}, "imageFilters": [], "harvestFiles": {"pathPrefix": "/ITweek2025Spring/images"}} | 画像エクスポート設定 |
| OUTPUT | 送信先チャネル | なし | 出力なし |
:::

## パトライト制御コマンドについて

パトライトの制御コマンドは6桁の数字で、各桁が赤・黄・緑・青・白・ブザーの状態を表しています。

| 桁位置 | 1桁目 | 2桁目 | 3桁目 | 4桁目 | 5桁目 | 6桁目 |
| --- | --- | --- | --- | --- | --- | --- |
| 制御対象 | 赤 | 黄 | 緑 | 青 | 白 | ブザー |
| 値の意味 | 0=消灯<br>1=点灯<br>9=現状維持 | 0=消灯<br>1=点灯<br>9=現状維持 | 0=消灯<br>1=点灯<br>9=現状維持 | 0=消灯<br>1=点灯<br>9=現状維持 | 0=消灯<br>1=点灯<br>9=現状維持 | 0=停止<br>1=動作<br>9=現状維持 |

今回のデモで使用するコマンドは以下の通りです：

- **011990**: 黄色と緑色のみ点灯（赤=0, 黄=1, 緑=1, 青=9, 白=9, ブザー=0）
- **000990**: すべて消灯、青と白は現状維持（赤=0, 黄=0, 緑=0, 青=9, 白=9, ブザー=0）
- **111119**: 赤・黄・緑・青・白すべて点灯、ブザー鳴動（赤=1, 黄=1, 緑=1, 青=1, 白=1, ブザー=9）
- **000000**: すべて消灯（赤=0, 黄=0, 緑=0, 青=0, 白=0, ブザー=0）

## 実装のポイント

### AIによる画像解析の設定

このデモの特徴は、Azure OpenAIのGPT-4oモデルを使用して画像解析を行っている点です。AIへのプロンプトは以下のように設定しています：

```
画像を解析し、画像の中にエメラルドグリーン色のTシャツを来ている人が写っているか確認してください。

出力はJSONで
エメラルドグリーン色のTシャツを来ている人が写っている場合は、
{"result":true}
エメラルドグリーン色のTシャツを来ている人が写っていない場合は、
{"result":false}
を返してください。
```

このプロンプトにより、AIは画像内のエメラルドグリーン色のTシャツの有無を判定し、結果をJSON形式で返します。

### イベント連携の流れ

このデモのイベント連携の流れは以下の通りです：

1. IoTデバイスからのイベント（人の動き検知）を受信
2. パトライトを点灯させるコマンドを生成
3. ソラカメの画像をHarvest Filesにエクスポート
4. エクスポートされた画像をAIで解析
5. AI解析結果に基づいてパトライトの点灯パターンを変更
6. ボタンデバイスからの信号を受信した場合はパトライトを消灯

この一連の流れにより、人の動きを検知してパトライトを点灯させ、さらにエメラルドグリーン色のTシャツを検出した場合は別の点灯パターンに切り替えるという、インタラクティブなデモが実現できます。

## 展示会での活用方法

### デモの見せ方

1. **基本的な動作説明**:
   - ソラカメの前で動くと、パトライトの橙色が点灯することを説明
   - エメラルドグリーン色のTシャツを着た人が映ると、パトライトの赤色が点灯することを説明
   - ボタンを押すとパトライトが消灯することを説明

2. **実演**:
   - 来場者にソラカメの前で動いてもらい、パトライトが点灯することを確認
   - エメラルドグリーン色のTシャツを用意し、着用した人がカメラの前に立つとパトライトの点灯パターンが変わることを実演
   - ボタンを押してパトライトを消灯する操作を体験してもらう

### 来場者への説明ポイント

1. **SORACOM Fluxの特徴**:
   - ノーコードでIoTデバイスとクラウドサービスを連携できる点
   - イベントドリブンでリアルタイムに処理できる点
   - AIサービスとの連携が容易な点

2. **ソラカメの特徴**:
   - クラウド接続型カメラで簡単に設置できる点
   - 動体検知機能を持つ点
   - 画像をクラウドに保存・分析できる点

3. **応用例の提案**:
   - 工場での異常検知（特定の色の作業着を着た作業員の入室検知など）
   - 店舗での顧客行動分析（特定の服装の顧客の動線分析など）
   - セキュリティ監視（不審者の検知と通知など）

## まとめ

本記事では、SORACOM Fluxを活用して「ソラカメの画角内で人が動いたらパトライトが点灯し、さらにエメラルドグリーン色のTシャツを着た人が映っていると別の色のパトライトが点灯する」という展示会デモの実装方法を紹介しました。

このデモは、IoTデバイス、クラウドサービス、AIを組み合わせることで、ノーコードでインタラクティブなシステムを構築できることを示しています。展示会での来場者とのコミュニケーションツールとして、また、IoTとAIの可能性を示すデモンストレーションとして活用いただければ幸いです。

## 参考情報

- [SORACOM Flux公式ドキュメント](https://users.soracom.io/ja-jp/docs/flux/)
- [ソラカム公式サイト](https://sora-cam.com/)
- [Azure OpenAI Service公式ドキュメント](https://learn.microsoft.com/ja-jp/azure/ai-services/openai/)