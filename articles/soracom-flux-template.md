# SORACOM Fluxの設定テンプレート

## 重要な注意点
- **チャネル名**: output channelの名称が同じ場合は同じチャンネルになります。これはループ処理などを実装する際に特に重要です。

## 設定の概要
![フロー図の画像](/images/path/to/flow-diagram.png)
以下のようなことを実施するフローを作っていきます。
数字は、上記のフローの説明をした図中の吹き出しの番号に合わせています。

0. トリガ設定
    イベントソース : [イベントソースの種類]
    出力チャネル： [チャネル名]
    [トリガに関する補足説明]

1. [アクション名]
    入力チャネル： [入力チャネル名]
    :::details [アクション名]ブロックの設定

    設定内容    
    | 大項目 | 詳細項目| 設定値 | 備考 |
    | --- | ------ | --- | ------ |
    | CONDITION | アクションの実行条件 | [条件式または空欄] | [補足説明] |
    | CONFIG | [設定項目1] | [設定値1] | [補足説明] |
    | CONFIG | [設定項目2] | [設定値2] | [補足説明] |
    |OUTPUT | アクションのアウトプットを別のチャネルに送信する | [有効/無効] | [補足説明] |
    |OUTPUT | 送信先チャネル | [チャネル名] | [補足説明] |

    設定画面（例）
    ![設定画面のスクリーンショット](/images/path/to/screenshot.png)

    入力されるJSON（例）
    ```json
    {
      "key1": "value1",
      "key2": "value2",
      "array": [
        {
          "item1": "value1",
          "item2": "value2"
        }
      ]
    }
    ```

    出力されるJSON（例）
    ```json
    {
      "result": "success",
      "data": {
        "key1": "value1",
        "key2": "value2"
      }
    }
    ```
    :::
    出力チャネル： [出力チャネル名]

2. [アクション名]
    入力チャネル： [入力チャネル名]
    :::details [アクション名]ブロックの設定

    入力されるpayload（例）
    ```json
    {
      "key1": "value1",
      "key2": "value2"
    }
    ```

    設定内容    
    | 大項目 | 詳細項目| 設定値 | 備考 |
    | --- | ------ | --- | ------ |
    | CONDITION | アクションの実行条件 | [条件式または空欄] | [補足説明] |
    | CONFIG | [設定項目1] | [設定値1] | [補足説明] |
    | CONFIG | [設定項目2] | [設定値2] | [補足説明] |
    |OUTPUT | アクションのアウトプットを別のチャネルに送信する | [有効/無効] | [補足説明] |
    |OUTPUT | 送信先チャネル | [チャネル名] | [補足説明] |

    設定画面（例）
    ![設定画面のスクリーンショット](/images/path/to/screenshot.png)

    出力されるJSON（例）
    ```json
    {
      "result": "success",
      "data": {
        "key1": "value1",
        "key2": "value2"
      }
    }
    ```
    :::
    出力チャネル： [出力チャネル名]

3. [アクション名]
    入力チャネル： [入力チャネル名]
    :::details [アクション名]ブロックの設定

    入力されるpayload（例）
    ```json
    {
      "key1": "value1",
      "key2": "value2"
    }
    ```

    設定内容    
    | 大項目 | 詳細項目| 設定値 | 備考 |
    | --- | ------ | --- | ------ |
    | CONDITION | アクションの実行条件 | [条件式または空欄] | [補足説明] |
    | CONFIG | [設定項目1] | [設定値1] | [補足説明] |
    | CONFIG | [設定項目2] | [設定値2] | [補足説明] |
    |OUTPUT | アクションのアウトプットを別のチャネルに送信する | [有効/無効] | [補足説明] |
    |OUTPUT | 送信先チャネル | [チャネル名] | [補足説明] |

    設定画面（例）
    ![設定画面のスクリーンショット](/images/path/to/screenshot.png)

    出力されるJSON（例）
    ```json
    {
      "result": "success",
      "data": {
        "key1": "value1",
        "key2": "value2"
      }
    }
    ```
    :::
    出力チャネル： [出力チャネル名]

4. [アクション名]
    入力チャネル： [入力チャネル名]
    :::details [アクション名]ブロックの設定

    入力されるpayload（例）
    ```json
    {
      "key1": "value1",
      "key2": "value2"
    }
    ```

    設定内容    
    | 大項目 | 詳細項目| 設定値 | 備考 |
    | --- | ------ | --- | ------ |
    | CONDITION | アクションの実行条件 | [条件式または空欄] | [補足説明] |
    | CONFIG | [設定項目1] | [設定値1] | [補足説明] |
    | CONFIG | [設定項目2] | [設定値2] | [補足説明] |
    |OUTPUT | アクションのアウトプットを別のチャネルに送信する | [有効/無効] | [補足説明] |
    |OUTPUT | 送信先チャネル | [チャネル名] | [補足説明] |

    設定画面（例）
    ![設定画面のスクリーンショット](/images/path/to/screenshot.png)

    出力されるJSON（例）
    ```json
    {
      "result": "success",
      "data": {
        "key1": "value1",
        "key2": "value2"
      }
    }
    ```
    :::
    出力チャネル： [出力チャネル名]

## テンプレートの使用方法

1. **フロー図の準備**:
   - SORACOM Fluxのフロー図をスクリーンショットで撮影
   - 各ステップに番号を振り、吹き出しで説明を追加

2. **各アクションの設定内容の整理**:
   - アクションごとに必要な設定項目を表形式で整理
   - 入出力JSONの例を準備

3. **スクリーンショットの準備**:
   - 各アクションの設定画面のスクリーンショットを撮影
   - 必要に応じて説明を追加

4. **テンプレートへの当てはめ**:
   - 準備した情報をテンプレートに当てはめる
   - 不要な項目は削除、必要な項目は追加

## Mermaidによるフロー図の例（オプション）

フロー図をテキストベースで作成したい場合は、Mermaidを使用することも可能です：

```mermaid
graph TD
    A[トリガ: API/マニュアル実行] -->|API Channel| B[アクション1]
    B -->|Output| C[アクション2]
    C -->|Output Channel| D[アクション3]
    D -->|Output Channel| D
    D -->|Output Channel| E[アクション4]
```

## 実装例

以下は、実際のSORACOM Fluxアプリケーションの設定JSONの例です。これを参考に、各アクションの設定内容を記述することができます。

```json
{
    "appId": "01JT7K440VXVXEMTBZX4P8GE8T",
    "name": "takao_test",
    "description": "",
    "tags": {},
    "channels": [
        {
            "channelId": "01JT7K5R54CBVGE3ER8SDCRVBR",
            "appId": "01JT7K440VXVXEMTBZX4P8GE8T",
            "name": "API Channel",
            "description": "",
            "tags": {}
        },
        {
            "channelId": "01JT7KJ8CAKWMBDPFBVMHP5S4V",
            "appId": "01JT7K440VXVXEMTBZX4P8GE8T",
            "name": " Output",
            "description": "",
            "tags": {}
        },
        {
            "channelId": "01JT7KN1RRMQ51D0SZM9BTKXY2",
            "appId": "01JT7K440VXVXEMTBZX4P8GE8T",
            "name": "Output Channel",
            "description": "Output from actions",
            "tags": {}
        }
    ],
    "actions": [
        {
            "actionId": "01JT7K8QG7V7RR18ARXV39A283",
            "appId": "01JT7K440VXVXEMTBZX4P8GE8T",
            "channelId": "01JT7K5R54CBVGE3ER8SDCRVBR",
            "name": "簡易物体検出",
            "description": "",
            "enabled": true,
            "condition": "",
            "output": {
                "enabled": true,
                "channelId": "01JT7KJ8CAKWMBDPFBVMHP5S4V",
                "splitArray": false
            },
            "tags": {},
            "type": "object-detection",
            "config": {
                "payload": {
                    "imageUrl": "https://blog.soracom.com/ja-jp/wp-content/uploads/2024/07/soracam-team-1-1024x683.jpg"
                }
            }
        },
        {
            "actionId": "01JT7KN2T93DBK5XA2M5TZ7ZPS",
            "appId": "01JT7K440VXVXEMTBZX4P8GE8T",
            "channelId": "01JT7KJ8CAKWMBDPFBVMHP5S4V",
            "name": "Republish",
            "description": "",
            "enabled": true,
            "condition": "",
            "output": {
                "enabled": true,
                "channelId": "01JT7KN1RRMQ51D0SZM9BTKXY2",
                "splitArray": false
            },
            "tags": {},
            "type": "republish",
            "config": {
                "transform": {
                    "contentType": "application/json",
                    "content": "{ \"num\":0,\n  \"length\":${len(payload.objects)},\n   \"objects\":${payload.objects}\n}"
                }
            }
        },
        {
            "actionId": "01JTK0C8GEWQY0QR58ARMNE88Q",
            "appId": "01JT7K440VXVXEMTBZX4P8GE8T",
            "channelId": "01JT7KN1RRMQ51D0SZM9BTKXY2",
            "name": "Republish",
            "description": "",
            "enabled": true,
            "condition": "payload.num < payload.length -1",
            "output": {
                "enabled": true,
                "channelId": "01JT7KN1RRMQ51D0SZM9BTKXY2",
                "splitArray": false
            },
            "tags": {},
            "type": "republish",
            "config": {
                "transform": {
                    "contentType": "application/json",
                    "content": "{\"num\":${payload.num+1},\"length\": ${payload.length}, \"objects\": ${payload.objects}}"
                }
            }
        },
        {
            "actionId": "01JTK1H48SDKHKF8F0EJNDD0CX",
            "appId": "01JT7K440VXVXEMTBZX4P8GE8T",
            "channelId": "01JT7KN1RRMQ51D0SZM9BTKXY2",
            "name": "Slack 通知",
            "description": "",
            "enabled": true,
            "condition": "",
            "output": {
                "enabled": false,
                "splitArray": false
            },
            "tags": {},
            "type": "slack-notification",
            "config": {
                "url": "https://hooks.slack.com/services/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",
                "payload": {
                    "text": "${payload.num} :\n${payload.objects[payload.num]}"
                }
            }
        }
    ]
}

## 補足：チャネルとループ処理について

SORACOM Fluxでは、チャネル名が同じ場合、それらは同じチャネルとして扱われます。これを利用して、ループ処理を実装することができます。

例えば、あるアクションの出力チャネルを「Output Channel」とし、別のアクションの入力チャネルも「Output Channel」とした場合、最初のアクションの出力は次のアクションの入力となります。さらに、次のアクションの出力チャネルも「Output Channel」とすることで、そのアクションの出力が再び自身の入力となり、ループ処理が実現できます。

これは、配列の要素を1つずつ処理するような場合に特に有用です。アクションの実行条件（CONDITION）を設定することで、ループの終了条件を指定することもできます。