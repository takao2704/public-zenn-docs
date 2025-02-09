---
title: "SORACOM Fluxでソラカメの画質をHDに保つ"
emoji: "😎"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [SORACOM,ソラカメ,IoT]
published: false
---
:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::
## やりたいこと
タイトルのとおりです。ソラカメの画質をHDに保つ方法をSORACOM Fluxを使って実現します。

以前書いた下記のブログを実装したら勝手に画質が下がっちゃって急に精度が出なくなって困ってる方向けの記事です。

https://zenn.dev/takao2704/articles/soracom-flux-croudness-count
https://zenn.dev/takao2704/articles/soracom-flux-croudness-count2

### 背景
なぜこのようなことをやりたいかについて説明します。
ソラカメは、Wifi接続で24時間映像をクラウドにアップロードし続けるクラウド録画型のカメラソリューションです。
カメラはwifi接続でインターネットを経由して映像をアップロードしますが。通信環境によって映像を送るための帯域が一時的に不十分になることがあります。

ソラカメ対応カメラには、通信環境が不十分になると映像の画質を自動的に下げてアップロードを続けるという動作が実装されています。
このようにして、できるだけ映像を取り逃がさないようになっているのは良いのですが、この機能が発動して一度画質が下がるとその後も画質が下がったままになってしまいます。

帯域の低下が慢性的なものでなく一時的なものである場合、もう一度画質を上げられないかと思うのが人間の性です。
そこで、SORACOM Fluxを使って、一度画質が下がったソラカメの画質をHDに保つ方法を考えてみました。

公式ドキュメントの記述は下記のとおりですので一読ください。

https://users.soracom.io/ja-jp/docs/soracom-cloud-camera-services/feature/#network-bandwidth

## やり方

### 準備

#### 必要なもの
- SORACOM アカウント
- ソラカメ関連
    - ソラカメ（AtomCam2）
    - Wifi環境
    - ソラカメライセンス(常時録画ライセンス 7日間プラン)  

:::details ソラカメが初めての方はこちら(購入から設置まで)！

#### SORACOMのアカウント作成など
https://users.soracom.io/ja-jp/guides/getting-started/create-account/

カバレッジタイプはJPで。

#### ソラカメの購入〜セットアップまで

https://sora-cam.com/setup/

実は最近はソラカメのセットアップにアプリを使わなくても良くなっていたりする。

#### ソラカメの設置

設置に関する知見はここにたくさん溜まっています。
https://weathernews.jp/s/topics/202403/180215/

### カメラチェック
何はともあれ、カメラが正常に動作しているか確認しましょう。

「ソラコムクラウドカメラサービス」 -> 「デバイス管理」

![alt text](/images/soracamimagetos3towp/image.png)

デバイスの一覧表示で、先ほど登録したカメラがオンラインになっていることを確認します。

![alt text](/images/soracamimagetos3towp/image-1.png)

さらに、カメラの名前をクリックすると、カメラの映像が表示されます。

:::message
このカメラの映像を見続けていると月72時間までの動画エクスポート時間無料枠を消費してしまうので注意しましょう。
:::

:::

### SORACOM Fluxの設定
SORACOM Fluxの設定をしていきます。
SORACOM Flux is 何？という方は[こちら](https://users.soracom.io/ja-jp/docs/flux/overview/)をご覧ください。

#### 設定の概要
![alt text](/images/keep-soracam-hd/image-5.png)
以下のようなことを実施するフローを作っていきます。
数字は、上記のフローの説明をした図中の吹き出しの番号に合わせています。

1. タイマーで定期的にトリガ
    出力チャネル： Timer Cnannel
2. APIアクションを使ってソラカメの画質を取得
    入力チャネル： Timer Channel
    :::details APIアクションブロックの設定

    利用するAPI：画質設定を取得する SoraCam:getSoraCamDeviceAtomCamSettingsQuality
    https://users.soracom.io/ja-jp/tools/api/reference/#/SoraCam/getSoraCamDeviceAtomCamSettingsQuality

    設定内容    
    | 大項目 | 詳細項目| 設定値 | 備考 |
    | --- | ------ | --- | ------ |
    | CONDITION |アクションの実行条件 | 空欄 | |
    | CONFIG | URL | `GET` <br> `/v1/sora_cam/devices/カメラID/atom_cam/settings/quality` | `カメラID`はソラカメのデバイスIDに置き換える <br> `getSoraCamDeviceAtomCamSettingsQuality`で検索|
    | CONFIG | HTTPボディ | 空欄 | 設定不可 |
    | CONFIG | APIを実行するSAMユーザー | 新規作成 | 個別に制御する場合は、`SoraCam:getSoraCamDeviceAtomCamSettingsQuality`と `OAuth2:authorize` |
    |OUTPUT | アクションのアウトプットを別のチャネルに送信する | 有効 | |
    |OUTPUT | 送信先チャネル | Current Quality | チャネル名称は自由 |

    設定画面（例）
    ![alt text](/images/keep-soracam-hd/image-3.png)

    :::
    出力チャネル： Current Quality
3. 取得した画質(low / mid / high)を数値（1 / 2 / 3）に変換
    入力チャネル： Current Quality
    :::details repubrishブロックの設定

    入力されるpayload
    ```json
    {
        "state": "low"
        // または "state": "mid"
        // または "state": "high"
    }
    ```
    設定内容    
    | 大項目 | 詳細項目| 設定値 | 備考 |
    | --- | ------ | --- | ------ |
    | CONDITION | アクションの実行条件 | `payload.state == "low"` | low, mid, highの分岐を用意する |
    | CONFIG | データを変換する | ✅️ |  |
    | CONFIG | Content Type | application/json | デフォルト設定 |
    | CONFIG | Content |{<br>"state" : "${payload.state}",<br>"state_num":1<br>} | `payload.state`はそのまま残し、新たに`state_num`というキーを追加する。<br> lowの場合1, midは2, highは3とする。 |
    |OUTPUT | アクションのアウトプットを別のチャネルに送信する | 有効 | |
    |OUTPUT | 送信先チャネル | midとlowの場合：`mid_or_low`<br>highの場合：`high` | lowの出力先を新規で作った場合は、midは既存の出力先に接続する |

    ![alt text](/images/keep-soracam-hd/image-4.png)
    :::
    出力チャネル： mid_or_low (画質がmidまたはlowの場合), high (画質がhighの場合)

4. APIアクションを使って画質がlowまたはmidの場合、画質をhighに設定  
    入力チャネル： mid_or_low
    :::details APIアクションブロックの設定
    利用するAPI: 画質設定を変更する SoraCam:setSoraCamDeviceAtomCamSettingsQuality
    https://users.soracom.io/ja-jp/tools/api/reference/#/SoraCam/setSoraCamDeviceAtomCamSettingsQuality

    設定内容    
    | 大項目 | 詳細項目| 設定値 | 備考 |
    | --- | ------ | --- | ------ |
    | CONDITION || 空欄 | |
    | CONFIG | URL | `POST` <br> `/v1/sora_cam/devices/カメラID/atom_cam/settings/quality` | `カメラID`はソラカメのデバイスIDに置き換える <br> `setSoraCamDeviceAtomCamSettingsQuality`で検索|
    | CONFIG | HTTPボディ | {<br>"state": "high"<br>} | `state`の値を`high`に設定する |
    | CONFIG | APIを実行するSAMユーザー | 新規作成 | 個別に制御する場合は、`SoraCam:setSoraCamDeviceAtomCamSettingsQuality`と `OAuth2:authorize` |
    |OUTPUT | アクションのアウトプットを別のチャネルに送信する | 無効 |  |

    ![alt text](/images/keep-soracam-hd/image-6.png)

    :::
5. 画質 -> 数値変換後の出力をそのまま同じチャンネルに返す
    入力チャネル： high, mid_or_low
    :::details repubrishブロックの設定

    入力されるpayload
    ```json
    {
        "state": "low",
        "state_num": 1
        // stateがmidの場合はstate_numが2,
        // stateがhighの場合はstate_numが3となる
    }
    ```
    設定内容    
    | 大項目 | 詳細項目| 設定値 | 備考 |
    | --- | ------ | --- | ------ |
    | CONDITION | アクションの実行条件 | 空欄 |  |
    | CONFIG | データを変換する | □  | チェックしない |
    | CONFIG | Content Type | 設定不可 |  |
    | CONFIG | Content | 設定不可 | |
    |OUTPUT | アクションのアウトプットを別のチャネルに送信する | 有効 | |
    |OUTPUT | 送信先チャネル | Quality Data | low_or_midからの出力先を新規で作った場合は、highからの出力は既存の出力先から選択する |

    ![alt text](/images/keep-soracam-hd/image-7.png)
    :::

    出力チャネル： Quality Data

6. APIアクションを使って数値変換された画質をSORACOM Harvest Dataに送信
    入力チャネル： Quality Data
    :::details APIアクションブロックの設定

        入力されるpayload
    ```json
    {
        "state": "low",
        "state_num": 1
        // stateがmidの場合はstate_numが2,
        // stateがhighの場合はstate_numが3となる
    }
    ```

    利用するAPI:任意のデータをソラカメ対応カメラに紐づけて Harvest Data に保存する createSoraCamDeviceDataEntry
    https://users.soracom.io/ja-jp/tools/api/reference/#/SoraCam/createSoraCamDeviceDataEntry

    設定内容    
    | 大項目 | 詳細項目| 設定値 | 備考 |
    | --- | ------ | --- | ------ |
    | CONDITION | アクションの実行条件 | 空欄 | |
    | CONFIG | URL | `POST` <br> `/v1/sora_cam/devices/カメラID/data` | `カメラID`はソラカメのデバイスIDに置き換える <br> `createSoraCamDeviceDataEntry`で検索|
    | CONFIG | HTTPボディ | ${payload} | 前のチャネルの出力をそのままHarvest Dataに投入する |
    | CONFIG | APIを実行するSAMユーザー | 新規作成 | 個別に制御する場合は、`SoraCam:createSoraCamDeviceDataEntry`と `OAuth2:authorize` |
    |OUTPUT | アクションのアウトプットを別のチャネルに送信する | 無効 |  |

    ![alt text](/images/keep-soracam-hd/image-8.png)

    :::

## 画質の時間変化の確認
[SORACOM Harvest Data](https://console.soracom.io/harvest_data)に保存されたデータを確認して、画質がどのように変化しているかを確認します。

「リソース」で「ソラカメ」を選択しソラカメの名称やIDなどを入力して検索します。
![alt text](/images/keep-soracam-hd/image-11.png)

画質がlowに落ちたタイミングで「3」-> 「1」に変わっていることが確認できます。
![alt text](/images/keep-soracam-hd/image-9.png)

## まとめ
ここまでの設定で、もしソラカメの画質がlowまたはmidになった場合、自動的に画質をhighに設定することができます。
また、5分起きに画質を取得して、その結果をSORACOM Harvest Dataに保存することができるので、もし頻繁にlowまたはmidになる場合はその時間帯や状況を把握することができ速度低下の原因究明に役立てましょう。
