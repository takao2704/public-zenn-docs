---
title: "ソラカメの画角内で人が動いたらパトライトが点灯する仕組みを作る"
emoji: "🐷"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [IoT,SORACOM,ソラカメ,パトライト,soracomflux]
published: false
---
:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::
## やりたいこと

ソラカメの画角内で人が動いたらパトライトが点灯するようにします。
この構成はソラコムが出展する展示会ブースのデモで使用するために作りました。
今回は、人を検知したパトライトがの橙色を点灯させます。さらに、その映像の中に青色のTシャツ（通称チェレT）を着た人が映っていると、パトライトの赤色を点灯させます。
展示会で点灯しっぱなしだと困ってしまうので、ボタンデバイスを押すとパトライトが消灯するようにします。

![alt text](/images/soracam-flux-patlite/1747031857097.png)

## 準備するもの
- SORACOM アカウント
- ソラカメ
- SORACOM Air
- LTEルーター
- パトライト（HTTP対応）

    今回使用したのは[LR5-LAN](https://online-shop.patlite.co.jp/c/network/network_LR5LAN/LR5L-302E)
- スイッチングハブ
- LANケーブル
- 設定用PC

## 手順

### 配線接続
下記のように接続します。
![alt text](/images/soracam-flux-patlite/1747149359098.png)

### LTEルーターの設定
[こちら](https://users.soracom.io/ja-jp/guides/devices/ud-lt2/setup/)の手順に従ってLTEルーター(UD-LT2)を設定します。
https://users.soracom.io/ja-jp/guides/devices/ud-lt2/setup/

LAN側のIPアドレスを変えます。

ネットワーク設定から、LANを選択してIP1に`192.168.10.100/24`を入力し、更新をクリックします
(UD-LT2のLANポートのIPアドレスが192.168.10.100になります)。

![alt text](/images/202505/image-8.png)

IPアドレスが変わってしまうので、
http://192.168.10.100/　にアクセスして、UD-LT2の設定画面に入りなおします。

UD-LT2に送信したコマンドをパトライトに転送する設定（DNAT設定）を行う
1. UD-LT2 の設定画面で [転送設定] → [NAT] → [追加] の順にクリックしてます。
 ![alt text](/images/202505/image.png)

2. 以下のように設定し,
保存します。

 |項目 | 値 |
 |---|---|
 |NAT 設定| DNAT |
 |プロトコル| TCP |
 |初期アドレスタイプ| interface |
 |インターフェイス| 4G |
 |初期ポート| 50080 |
 |マッピングアドレス| 192.168.10.1 |
 |マッピングポート| 80 |

![alt text](/images/202505/image-9.png)

### パトライトの設定

1. パトライトの設定画面 http://192.168.10.1/ にアクセス

    ![alt text](/images/202505/image-1.png)

2. 言語を変更

    ![alt text](/images/202505/image-2.png)

3. パスワードを設定

    ![alt text](/images/202505/image-3.png)

4. 設定完了

    ![alt text](/images/202505/image-4.png)

5. さっきのパスワードでログイン

    ![alt text](/images/202505/image-5.png)

6. DHCPに設定

    ネットワーク設定 -> IPアドレス設定方法を「自動的に取得する」を選択肢、設定をクリック

    ![alt text](/images/202505/image-6.png)

7. コマンド受信設定で、HTTPコマンド受信設定が「有効」になっていることを確認して、右上のmacアドレスをメモ

    ![alt text](/images/202505/image-7.png)


8. もう一度、UD-LT2の設定画面（[`http://192.168.10.100`](http://192.168.10.100)）に戻ります。

    パトライトに対して、常に`192.168.10.1`がDHCPで割り当てられるように、DHCPの予約を設定します。


    Ir-5lanに![alt text](/images/202505/image-11.png)
    「DHCP設定」の「固定IP」のエントリーに以下の設定を入力します。
    |項目 | 値 |
    |---|---|
    |IPアドレス|192.168.10.1|
    |MACアドレス|パトライトのMACアドレス|

    ![alt text](/images/soracam-flux-patlite/1747151180963.png)

### ソラカメの設定
:::details ソラカメが初めての方はこちら(購入から設置まで)！

### SORACOMのアカウント作成など
https://users.soracom.io/ja-jp/guides/getting-started/create-account/

カバレッジタイプはJPで。

### ソラカメの購入〜セットアップまで

https://sora-cam.com/setup/

実は最近はソラカメのセットアップにアプリを使わなくても良くなっていたりする。

### ソラカメの設置

設置に関する知見はここにたくさん溜まっています。
https://weathernews.jp/s/topics/202403/180215/

:::

何はともあれ、カメラが正常に動作しているか確認しましょう。

1. 「ソラコムクラウドカメラサービス」 -> 「デバイス管理」

    ![alt text](/images/soracamimagetos3towp/image.png)

2. デバイスの一覧表示で、先ほど登録したカメラがオンラインになっていることを確認します。

    ![alt text](/images/soracamimagetos3towp/image-1.png)

3. さらに、カメラの名前をクリックすると、カメラの映像が表示されます。

    ![alt text](/images/soracamimagetos3towp/image-2.png)

:::message
この画面を見続けていると月72時間までの動画エクスポート時間無料枠を消費してしまうので注意しましょう。
:::

### SORACOM Fluxの設定
設定の概要
![alt text](/images/soracam-flux-patlite/1747233997143.png)

#### 1. モーション検知 webhook

イベントソース : API/マニュアル実行
出力チャネル： API Cnannel
ソラカメがモーション検知した際のアクションとして叩くwebhookのURLを設定します。
（ソラカメのモーション検知の設定については後述します。）

入力されるJSON

```json
{
    "eventType": "event_detected",
    "deviceId": "カメラのデバイスID",
    "deviceName": "カメラの名前",
    "alarmType": "motion_detected"
}
```

#### 2. パトライト点灯コマンド作成



:::details republish アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | payload.deviceId=="カメラのデバイスID" | 特定のカメラからの通知のみを処理 |
| CONFIG | データを変換する | ✅️ |  |
| CONFIG | Content Type | application/json | JSONフォーマットで出力 |
| CONFIG | Content | {<br> "command":"011990"<br>} | パトライト制御コマンド（黄色と緑色を点灯） |
| OUTPUT | アクションのアウトプットを別のチャネルに送信する | 有効 | 出力先チャネル |
| OUTPUT | 送信先チャネル | Output Channel | 出力先チャネル |
:::

#### 3. ダウンリンクAPIコマンド発行

:::details SORACOM API アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | なし | すべてのイベントを処理 |
| CONFIG | path | /v1/sims/`SIM ID`/downlink/http | SIMのHTTPダウンリンク<br>`SIM ID` はパトライトに接続しているルーターに挿入した`SIM ID` |
| CONFIG | method | POST | HTTPメソッド |
| CONFIG | body | {<br> "method": "GET",<br> "path": "/api/control?alert=${payload.command}",<br> "port": 50080,<br> "skipVerify": true,<br> "ssl": false<br>} | パトライト制御API呼び出し |
| OUTPUT | 送信先チャネル | Output | 出力先チャネル |


:::

#### 4. 画像切り出し（Harvest Files保存）

:::details アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | event.payload.deviceId != null | デバイスIDが存在する場合のみ処理 |
| CONFIG | path | /v1/sora_cam/devices/${event.payload.deviceId}/images/exports | ソラカメ画像エクスポートAPI |
| CONFIG | method | POST | HTTPメソッド |
| CONFIG | body | {"time": ${now()}, "imageFilters": [], "harvestFiles": {"pathPrefix": "/ITweek2025Spring/images"}} | 画像エクスポート設定 |
| OUTPUT | 送信先チャネル | なし | 出力なし |
:::

#### 5. ボタンデバイスからのデータ（unified endpoint）



#### 6. パトライト消灯コマンド作成

:::details republish アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | payload.deviceId=="カメラID" | 特定のカメラからの通知のみを処理 |
| CONFIG | データを変換する | ✅️ |  |
| CONFIG | Content Type | application/json | JSONフォーマットで出力 |
| CONFIG | Content | {<br> "command":"011990"<br>} | パトライト制御コマンド（黄色と緑色を点灯） |
| OUTPUT | アクションのアウトプットを別のチャネルに送信する | 有効 | 出力先チャネル |
| OUTPUT | 送信先チャネル | Output Channel | 出力先チャネル |
:::

#### 7. 画像切り出し完了



#### 8. 生成系AI（マルチモーダル基盤モデル）　を使った画像の解析

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

#### 9. パトライト点灯コマンド作成

:::details republish アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | payload.deviceId=="カメラID" | 特定のカメラからの通知のみを処理 |
| CONFIG | データを変換する | ✅️ |  |
| CONFIG | Content Type | application/json | JSONフォーマットで出力 |
| CONFIG | Content | {<br> "command":"011990"<br>} | パトライト制御コマンド（黄色と緑色を点灯） |
| OUTPUT | アクションのアウトプットを別のチャネルに送信する | 有効 | 出力先チャネル |
| OUTPUT | 送信先チャネル | Output Channel | 出力先チャネル |
:::

#### 10. パトライト点灯コマンド作成

:::details republish アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | payload.deviceId=="カメラID" | 特定のカメラからの通知のみを処理 |
| CONFIG | データを変換する | ✅️ |  |
| CONFIG | Content Type | application/json | JSONフォーマットで出力 |
| CONFIG | Content | {<br> "command":"011990"<br>} | パトライト制御コマンド（黄色と緑色を点灯） |
| OUTPUT | アクションのアウトプットを別のチャネルに送信する | 有効 | 出力先チャネル |
| OUTPUT | 送信先チャネル | Output Channel | 出力先チャネル |
:::

#### 11. パトライト点灯/消灯コマンド発行

:::details SORACOM API アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | なし | すべてのイベントを処理 |
| CONFIG | path | /v1/sims/`SIM ID`/downlink/http | SIMのHTTPダウンリンク<br>`SIM ID` はパトライトに接続しているルーターに挿入した`SIM ID` |
| CONFIG | method | POST | HTTPメソッド |
| CONFIG | body | {<br> "method": "GET",<br> "path": "/api/control?alert=${payload.command}",<br> "port": 50080,<br> "skipVerify": true,<br> "ssl": false<br>} | パトライト制御API呼び出し |
| OUTPUT | 送信先チャネル | Output | 出力先チャネル |


:::

### ソラカメの通知を設定する

## Appendix

### パトライトの制御について
