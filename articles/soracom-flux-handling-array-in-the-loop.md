---
title: "SORACOM Fluxでループを使って配列を処理する"
emoji: "🔄"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [SORACOM,IoT]
published: false
---
:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## やりたいこと
SORACOM Fluxでループを使って配列を処理するためのtipsを紹介します。
以前書いたblogの中でSORACOM Fluxは未知の長さの配列を扱うのが難しいと書きましたが、ループを使うことで解決できることがわかりました。

## やり方

SORACOM Fluxの設定をしていきます。
SORACOM Flux is 何？という方は[こちら](https://users.soracom.io/ja-jp/docs/flux/overview/)をご覧ください。

### 設定の概要
![alt text](/images/202505/image-38.png)
以下のようなことを実施するフローを作っていきます。
数字は、上記のフローの説明をした図中の吹き出しの番号に合わせています。

0. トリガ設定
    イベントソース : API/マニュアル実行
    出力チャネル： API Cnannel
    今回はループの機能確認を行うので、API/マニュアル実行を選択します。
    実際のアプリケーションで使う場合は適切なトリガを選択してください。

1. 簡易物体検出アクション
    入力チャネル： API Channel
    :::details APIアクションブロックの設定

    設定内容    
    | 大項目 | 詳細項目| 設定値 | 備考 |
    | --- | ------ | --- | ------ |
    | CONDITION | アクションの実行条件 | 空欄 |  |
    | CONFIG | 画像URL | https://blog.soracom.com/ja-jp/wp-content/uploads/2024/07/soracam-team-1-1024x683.jpg | SORACOM [公式ブログ](https://blog.soracom.com/ja-jp/2024/08/07/soracam-team-interview/)の画像を拝借 |
    |OUTPUT | アクションのアウトプットを別のチャネルに送信する | 有効 | |
    |OUTPUT | 送信先チャネル | Output | チャネル名称は自由 |

    設定画面（例）
    ![alt text](/images/202505/image-39.png)

    
    出力チャネル： Output

    出力されるJSON
    ```json
    {
      "person": 6,
      "car": 0,
      "bus": 0,
      "truck": 0,
      "cat": 0,
      "dog": 0,
      "objects": [
        {
          "location": [
            0.6609779,
            0.17652985,
            0.9373262,
            0.9943735
          ],
          "score": 0.8904824,
          "label": "person",
          "ts": "2025-05-07T01:48:41Z"
        },
        {
          "location": [
            0.37141305,
            0.3185921,
            0.5251937,
            0.969292
          ],
          "score": 0.8751769,
          "label": "person",
          "ts": "2025-05-07T01:48:41Z"
        },
        {
          "location": [
            0.04004524,
            0.21790065,
            0.21095791,
            0.84099317
          ],
          "score": 0.8547369,
          "label": "person",
          "ts": "2025-05-07T01:48:41Z"
        },
        {
          "location": [
            0.4620108,
            0.37004647,
            0.6945141,
            0.9970469
          ],
          "score": 0.83913076,
          "label": "person",
          "ts": "2025-05-07T01:48:41Z"
        },
        {
          "location": [
            0.23511018,
            0.3791213,
            0.39225024,
            0.8577786
          ],
          "score": 0.8179504,
          "label": "person",
          "ts": "2025-05-07T01:48:41Z"
        },
        {
          "location": [
            0.13871717,
            0.3871962,
            0.27425474,
            0.8432603
          ],
          "score": 0.7499229,
          "label": "person",
          "ts": "2025-05-07T01:48:41Z"
        },
        {
          "location": [
            0.4429141,
            0.47117797,
            0.48522377,
            0.6288479
          ],
          "score": 0.2793063,
          "label": "tie",
          "ts": "2025-05-07T01:48:41Z"
        },
        {
          "location": [
            0.39311492,
            0.4475629,
            0.42104053,
            0.6097326
          ],
          "score": 0.2578054,
          "label": "tie",
          "ts": "2025-05-07T01:48:41Z"
        }
      ]
    }
    ```
    :::
2. ループカウンタ(num)とループ上限(length)と分解したい配列をセット

    入力チャネル：Output
    :::details repubrishブロックの設定

    入力されるpayload
    ```json
    {
      "person": 6,
      "car": 0,
      "bus": 0,
      "truck": 0,
      "cat": 0,
      "dog": 0,
      "objects": [···]
    }
    ```
    ※`objects`の中身は省略しています。
    

    設定内容    
    | 大項目 | 詳細項目| 設定値 | 備考 |
    | --- | ------ | --- | ------ |
    | CONDITION | アクションの実行条件 | 空欄 |  |
    | CONFIG | データを変換する | ✅️ |  |
    | CONFIG | Content Type | application/json | デフォルト設定 |
    | CONFIG | Content |{<br>  "num" : 0,<br>  "length" : ${len(payload.objects)},<br>  "objects" : ${payload.objects}<br>} | objectsで出力される配列の長さを計算する<br>`len()`も含めて`${}`の中にいれる。<br>`len(${payload.objects})`としたくなるが、それは間違い。 |
    |OUTPUT | アクションのアウトプットを別のチャネルに送信する | 有効 | |
    |OUTPUT | 送信先チャネル | Output Channel |  |

    ![alt text](/images/202505/image-40.png)

    出力チャネル： Output Channel

    出力されるJSON
    ```json
    {
        "num":0,
        "length":8,
        "objects":[···]
    }
    ```
    ※`objects`の中身は省略しています。
    :::

3. `num`のインクリメントと`payload.objects`の`num`番目の要素の取り出し
  
    :::details Repubishブロックの設定
    入力チャネル： Output Channel
    ```json
    {
        "num":0,
        "length":8,
        "objects":[···]
    }
    ```
    ※`objects`の中身は省略しています。

    設定内容    
    | 大項目 | 詳細項目| 設定値 | 備考 |
    | --- | ------ | --- | ------ |
    | CONDITION | アクションの実行条件 | payload.num < payload.length - 1 | 左記条件のときにはインクリメントをして出力を行う。 |
    | CONFIG | データを変換する | ✅️ |  |
    | CONFIG | Content Type | application/json | デフォルト設定 |
    | CONFIG | Content |{<br>"num":${payload.num+1},<br>"length": ${payload.length},<br>"objects": ${payload.objects}<br>} | 入力された`num`をインクリメントして出力する。<br> インクリメントの`+1`は`${}`内に書く。<br>`length`と`objects`はそのまま出力する。 |
    |OUTPUT | 送信先チャネル | Output Channel | 入力チャネルに戻して再びこのアクションに入ってくるようにループをかける |

    出力チャネル： Output Channel（このアクションへの入力チャネルと同じ）

    ```json
    {
        "num":1,
        "length":8,
        "objects":[···]
    }
    ```
    ※`objects`の中身は省略しています。

    :::
4. num番目の要素を通知
    入力チャネル： Output Channel
    :::details Slack通知アクションの設定

    入力されるpayload
    ```json
    {
        "num":0,
        // 1,2,3,4···とインクリメントされ、入ってくる
        "length":8,
        "objects":[···]
    }
    ```
    設定内容    
    | 大項目 | 詳細項目| 設定値 | 備考 |
    | --- | ------ | --- | ------ |
    | CONDITION | アクションの実行条件 | 空欄 |  |
    | CONFIG | URL |  |  |
    | CONFIG | Payload | ${payload.num} : <br> ${payload.objects[payload.num]} | 1行目に番号を、2行目に`payload.objects`の `num`番目の要素をいれる |  |
    |OUTPUT | アクションのアウトプットを別のチャネルに送信する | 無効 | |

    ![alt text](/images/202505/image-41.png)

    :::

    出力チャネル： Quality Data

### 実行結果
以下のようにSORACOMのSlackに通知されます。
ただし、slackへ通知が届く順序は順不同となっているようです。
配列の並び順とリクエストの到達順序にシビアなアプリケーションでは注意が必要です。
![alt text](/images/202505/image-42.png)

なお、今回ループをかけたRepublishアクションに実行条件
```
payload.num < payload.length - 1
```
を設定していたのでこれがループ回数の上限となりましたが、この条件文を外した場合は10回でループが止まりまるようになっています。
長さ10以上の配列を処理したい場合は、`Output`のチャネルに接続するRepublishアクションの設定を並行でもう一つ作成し、`num`の初期値を10にせっていして　を行うようにしループを回すことで各要素への処理を行うことができるようになると思います。
```json
{
    "num" : 10,
    "length" : ${len(payload.objects)},
    "objects": ${payload.objects}
}
```