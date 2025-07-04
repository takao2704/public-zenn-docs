---
title: "ソラカメの画角内で人が動いたらパトライトが点灯する仕組みを作る"
emoji: "🐷"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [IoT,SORACOM,ソラカメ,パトライト,soracomflux]
published: true
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

:::message
ASCIIさんの記事にもこのデモを取り上げていただきました！
:::
こちらの記事もご覧ください。
https://ascii.jp/elem/000/004/292/4292665/
https://ascii.jp/elem/000/004/278/4278992/img.html


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
このようなフローを作成します。詳細の設定内容について説明していきます。



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

入力チャネル：API Channel

:::details republish アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | payload.deviceId=="カメラのデバイスID" | 特定のカメラからの通知のみを処理 |
| CONFIG | データを変換する | ✅️ |  |
| CONFIG | Content Type | application/json | JSONフォーマットで出力 |
| CONFIG | Content | {<br> "command":"011990"<br>} | パトライト制御コマンド（黄色と緑色を点灯） |
| OUTPUT | アクションのアウトプットを別のチャネルに送信する | 有効 | 出力先チャネル |
| OUTPUT | 送信先チャネル | Output Channel | 出力先チャネル |

設定画面（例）
![alt text](/images/soracam-flux-patlite/1751549663998.png)

:::

出力チャネル：Output Channel

#### 3. ダウンリンクAPIコマンド発行

入力チャネル：Output Channel

:::details SORACOM API アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | なし | すべてのイベントを処理 |
| CONFIG | URL:path | /v1/sims/`SIM ID`/downlink/http | SIMのHTTPダウンリンク<br>`SIM ID` はパトライトに接続しているルーターに挿入した`SIM ID` |
| CONFIG | URL:method | POST | HTTPメソッド |
| CONFIG | body | {<br> "method": "GET",<br> "path": "/api/control?alert=${payload.command}",<br> "port": 50080,<br> "skipVerify": true,<br> "ssl": false<br>} | パトライト制御API呼び出し |
| OUTPUT | 送信先チャネル | Output | 出力先チャネル |

設定画面（例）
![alt text](/images/soracam-flux-patlite/1751550539658.png)

:::

出力チャネル：Output

#### 4. 画像切り出し（Harvest Files保存）

入力チャネル：Output

:::details アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | event.payload.deviceId != null | デバイスIDが存在する場合のみ処理 |
| CONFIG | URL:path | /v1/sora_cam/devices/${event.payload.deviceId}/images/exports | ソラカメ画像エクスポートAPI |
| CONFIG | URL:method | POST | HTTPメソッド |
| CONFIG | body | {"time": ${now()}, "imageFilters": [], "harvestFiles": {"pathPrefix": "画像エクスポート（保存）先ディレクトリ名"}} | 画像エクスポート設定 |
| OUTPUT | 送信先チャネル | なし | 出力なし |

設定画面（例）
![alt text](/images/soracam-flux-patlite/1751550700353.png)

:::

#### 5. ボタンデバイスからのデータ（unified endpoint）

イベントソース：IoTデバイス
有効化して、ボタンデバイスの所属するグループを選択しておきます。
![alt text](/images/soracam-flux-patlite/1751551156384.png)

出力チャネル：IoT Device Channel

#### 6. パトライト消灯コマンド作成

入力チャネル：IoT Device Channel

:::details republish アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | payload.deviceId=="カメラID" | 特定のカメラからの通知のみを処理 |
| CONFIG | データを変換する | ✅️ |  |
| CONFIG | Content Type | application/json | JSONフォーマットで出力 |
| CONFIG | Content | {<br> "command":"000990"<br>} | パトライト制御コマンド（黄色と緑色を点灯） |
| OUTPUT | アクションのアウトプットを別のチャネルに送信する | 有効 | 出力先チャネル |
| OUTPUT | 送信先チャネル | Output Channel | 出力先チャネル |

設定画面（例）
![alt text](/images/soracam-flux-patlite/1751552364248.png)

:::

出力チャネル：Output Channel
（2.のアクションの出力に合流させます。）

#### 7. 画像切り出し完了

イベントソースとして「SORACOM Harvest Files」を選択します。
有効化して、画像エクスポートの保存先ディレクトリ名を指定します。
![alt text](/images/soracam-flux-patlite/1751551606389.png)

出力チャネル：Harvest Files Event Channel

#### 8. 生成系AI（マルチモーダル基盤モデル）　を使った画像の解析

入力チャネル：Harvest Files Event Channel

:::details アクションの詳細設定

| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | なし | すべてのイベントを処理 |
| CONFIG | AIモデル | azure-openai（gpt-4o） | 使用するAIサービス（AIモデル） |
| CONFIG | プロンプト | 画像を解析し、画像の中にエメラルドグリーン色のTシャツを来ている人が写っているか確認してください。<br>出力はJSONで<br>エメラルドグリーン色のTシャツを来ている人が写っている場合は、<br>{"result":true}<br>エメラルドグリーン色のTシャツを来ている人が写っていない場合は、<br>{"result":false}<br>を返してください。 | AIへの指示 |
| CONFIG | AIからの返答をJSONにする | ✅️ |  |
| CONFIG | AIに画像を読み込ませる | ${payload.presignedUrls.get} | 解析する画像のURL |
| OUTPUT | 送信先チャネル | Output AI | 出力先チャネル |

設定画面（例）
![alt text](/images/soracam-flux-patlite/1751551699295.png)

:::

出力チャネル：Output AI

#### 9. パトライト点灯コマンド作成()

入力チャネル：Output AI

:::details republish アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | payload.output.result == true | AIの判定結果が`true`の場合 |
| CONFIG | データを変換する | ✅️ |  |
| CONFIG | Content Type | application/json | JSONフォーマットで出力 |
| CONFIG | Content | {<br> "command":"011990"<br>} | パトライト制御コマンド（黄色と緑色を点灯） |
| OUTPUT | アクションのアウトプットを別のチャネルに送信する | 有効 | 出力先チャネル |
| OUTPUT | 送信先チャネル | Output Channel 2 | 出力先チャネル |

設定画面（例）
![alt text](/images/soracam-flux-patlite/1751552055895.png)

:::

出力チャネル：Output Channel 2

#### 10. パトライト点灯コマンド作成

入力チャネル：Output AI

:::details republish アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | payload.output.result == false | AIの判定結果が`false`の場合 |
| CONFIG | データを変換する | ✅️ |  |
| CONFIG | Content Type | application/json | JSONフォーマットで出力 |
| CONFIG | Content | {<br> "command":"000000"<br>} | パトライト制御コマンド（全部消灯） |
| OUTPUT | アクションのアウトプットを別のチャネルに送信する | 有効 | 出力先チャネル |
| OUTPUT | 送信先チャネル | Output Channel 2 | 出力先チャネル |

設定画面（例）
![alt text](/images/soracam-flux-patlite/1751552435004.png)

:::

出力チャネル：Output Channel 2

#### 11. パトライト点灯/消灯コマンド発行

入力チャネル：Output Channel 2

:::details SORACOM API アクションの詳細設定
| 大項目 | 詳細項目 | 設定値 | 備考 |
| --- | ------ | --- | ------ |
| CONDITION | アクションの実行条件 | なし | すべてのイベントを処理 |
| CONFIG | path | /v1/sims/`SIM ID`/downlink/http | SIMのHTTPダウンリンク<br>`SIM ID` はパトライトに接続しているルーターに挿入した`SIM ID` |
| CONFIG | method | POST | HTTPメソッド |
| CONFIG | body | {<br> "method": "GET",<br> "path": "/api/control?alert=${payload.command}",<br> "port": 50080,<br> "skipVerify": true,<br> "ssl": false<br>} | パトライト制御API呼び出し |
| OUTPUT | 送信先チャネル | Output | 出力先チャネル |

設定画面（例）
![alt text](/images/soracam-flux-patlite/1751552536562.png)
:::

### ソラカメの通知を設定する

ソラカメでモーション検知が発生した際に、SORACOM FluxのWebhookエンドポイントにペイロードを送信するように設定します。

#### 1. SORACOM FluxのWebhookURL取得

はじめに、Fluxで作成した「1. モーション検知 webhook」アクションからWebhook URLを取得します。

1.  SORACOM Fluxの管理画面で、該当のアクションを選択します。
2.  「API Channel」の詳細画面に表示されているWebhook URLをコピーします。

#### 2. ソラカメの通知を設定する

次に、SORACOMユーザーコンソールで、モーション検知時の通知先として先ほどのWebhook URLを設定します。

1.  SORACOMユーザーコンソールにログインし、[メニュー] > [ソラコムクラウドカメラサービス] > [通知設定] へ進みます。
    *   「ソラカメ通知オプションのご利用について」画面が表示された場合は、内容を確認のうえ [理解して利用する] をクリックしてください。
2.  [デバイスのモーション検知/サウンド検出の通知] の項目で [通知を設定する] をクリックします。
![alt text](/images/soracam-flux-patlite/1751588114843.png)

#### 3. モーション検知通知の設定

3.  **通知先を追加します。**
    1.  [Webhook] タブを選択し、[+Webhook通知先を追加] をクリックします。
   ![alt text](/images/soracam-flux-patlite/1751588268433.png)
    2.  以下の通り設定し、[保存する] をクリックします。
        -   **Webhook URL**: 手順1でコピーしたURLを貼り付けます。
        -   **HTTPメソッド**: `POST`
        -   **HTTPヘッダー**: デフォルトのまま
           ![alt text](/images/soracam-flux-patlite/1751588337252.png)

4.  **通知対象のカメラを選択します。**
    1.  通知設定画面に戻り、[通知対象デバイスを設定する] をクリックします。
    2.  一覧からモーション検知を行うカメラを選択し、通知対象のトグルをオンにします。

5.  **送信するペイロードをカスタマイズします。**
    1.  通知設定画面の [通知メッセージ設定] > [モーション検知/サウンド検出の設定] にあるトグルを有効化します。
    2.  [メッセージ内容を設定する] をクリックし、[Webhook] タブを選択します。
    3.  先ほど追加した通知先を選択し、[Webhookメッセージを編集する] をクリックします。
    ![alt text](/images/soracam-flux-patlite/1751588766422.png)
    4.  リクエストボディに以下の内容を設定します。

```json
{
 "eventType":"{{ event_type }}",
 "deviceId":"{{ device_id }}",
 "deviceName":"{{ device_name }}",
 "alarmType":"{{ alarm_type }}"
}
```
設定画面（例）
![alt text](/images/soracam-flux-patlite/1751588848215.png)

モーション検知が発生すると、以下のようなJSONペイロードがSORACOM Fluxに送信されます：

```json
{
    "eventType": "event_detected",
    "deviceId": "カメラのデバイスID",
    "deviceName": "カメラの名前",
    "alarmType": "motion_detected"
}
```

このペイロードを受け取ったSORACOM Fluxが、パトライト制御の処理を開始します。

## Appendix

### パトライトの制御について

パトライト（LR5-LAN）は、HTTPコマンドを使用して制御できます。以下に主要なコマンドを説明します。

#### HTTPコマンドの基本形式

```
GET /api/control?alert=XXXXXX
```

#### コマンド構成

コマンドは6桁の数字で構成され、各桁が以下の意味を持ちます：

| 桁位置 | 意味 | 値 |
|--------|------|-----|
| 1桁目 | 赤色LED | 0:消灯, 1:点灯, 2:点滅（低速）, 3:点滅（中速）, 4:点滅（高速）, 5:シングルフラッシュ, 6:ダブルフラッシュ, 7:トリプルフラッシュ 9:変化なし |
| 2桁目 | 黄色LED | 0:消灯, 1:点灯, 2:点滅（低速）, 3:点滅（中速）, 4:点滅（高速）, 5:シングルフラッシュ, 6:ダブルフラッシュ, 7:トリプルフラッシュ 9:変化なし |
| 3桁目 | 緑色LED | 0:消灯, 1:点灯, 2:点滅（低速）, 3:点滅（中速）, 4:点滅（高速）, 5:シングルフラッシュ, 6:ダブルフラッシュ, 7:トリプルフラッシュ 9:変化なし |
| 4桁目 | 青色LED | 0:消灯, 1:点灯, 2:点滅（低速）, 3:点滅（中速）, 4:点滅（高速）, 5:シングルフラッシュ, 6:ダブルフラッシュ, 7:トリプルフラッシュ 9:変化なし |
| 5桁目 | 白色LED | 0:消灯, 1:点灯, 2:点滅（低速）, 3:点滅（中速）, 4:点滅（高速）, 5:シングルフラッシュ, 6:ダブルフラッシュ, 7:トリプルフラッシュ 9:変化なし |
| 6桁目 | ブザー | 0:停止, 1〜9:パターン1〜9 |

#### 信号灯パターン詳細

各LEDの点滅パターンは以下のような動作をします：

| パターン | 動作 | タイミング |
|----------|------|------------|
| 0 | 消灯 | 常時OFF |
| 1 | 点灯 | 常時ON |
| 2 | 点滅（低速） | ON 500ms → OFF 500ms の繰り返し |
| 3 | 点滅（中速） | ON 250ms → OFF 250ms の繰り返し |
| 4 | 点滅（高速） | ON 125ms → OFF 125ms の繰り返し |
| 5 | シングルフラッシュ | ON 50ms → OFF 450ms の繰り返し |
| 6 | ダブルフラッシュ | ON 50ms → OFF 50ms → ON 50ms → OFF 350ms の繰り返し |
| 7 | トリプルフラッシュ | ON 50ms → OFF 50ms → ON 50ms → OFF 50ms → ON 50ms → OFF 250ms の繰り返し |

#### 使用例

本記事で使用したコマンド例：

- **`011990`**: 黄色と緑色を点灯（人検知時）
- **`100990`**: 赤色を点灯（青いTシャツ検知時）
- **`000000`**: 全消灯

#### その他の制御コマンド例

```bash
# 基本的な点灯・消灯
GET /api/control?alert=100000  # 赤色点灯
GET /api/control?alert=010000  # 黄色点灯
GET /api/control?alert=001000  # 緑色点灯

# 点滅パターン（低速）
GET /api/control?alert=200000  # 赤色点滅（低速）
GET /api/control?alert=020000  # 黄色点滅（低速）
GET /api/control?alert=002000  # 緑色点滅（低速）

# 点滅パターン（中速・高速）
GET /api/control?alert=300000  # 赤色点滅（中速）
GET /api/control?alert=400000  # 赤色点滅（高速）

# フラッシュパターン
GET /api/control?alert=500000  # 赤色シングルフラッシュ
GET /api/control?alert=600000  # 赤色ダブルフラッシュ
GET /api/control?alert=700000  # 赤色トリプルフラッシュ

# 複数色の組み合わせ
GET /api/control?alert=120000  # 赤色点灯 + 黄色点滅（低速）
GET /api/control?alert=234000  # 赤色点滅（低速） + 黄色点滅（中速） + 緑色点滅（高速）
GET /api/control?alert=567000  # 赤色シングルフラッシュ + 黄色ダブルフラッシュ + 緑色トリプルフラッシュ

# ブザー付きパターン
GET /api/control?alert=001001  # 緑色点灯 + ブザーパターン1
GET /api/control?alert=222225  # 全色点滅（低速） + ブザーパターン5
GET /api/control?alert=567009  # 複数フラッシュパターン + ブザーパターン9

# 全色同時パターン
GET /api/control?alert=111110  # 全色点灯
GET /api/control?alert=222220  # 全色点滅（低速）
GET /api/control?alert=444440  # 全色点滅（高速）
GET /api/control?alert=777770  # 全色トリプルフラッシュ
```

#### ブザーパターンについて

パラメータによるパターンの指定はできず、本体のDIPスイッチで設定されたパターンが使用されます。

| パターン | 説明 |
|----------|------|
| 0 | 停止（無音） |
| 1 | 吹鳴 |
| 9 | 変化なし |


#### 注意事項

- コマンドは必ず6桁で指定する必要があります

詳細な仕様については、[パトライト公式カタログ](https://www.patlite.co.jp/catalogimg/JP_KF_0000000983_czbJbJum.pdf)を参照してください。
