---
title: "SORACOM Beam Web サイトエントリポイントから AWS IoT Core に HTTPS Publish する"
emoji: "📡"
type: "tech"
topics: ["soracom", "aws", "iot", "awsiot", "soracombeam"]
published: true
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## TL;DR

- デバイスからは SORACOM Beam の Web サイトエントリポイント `http://beam.soracom.io:18080` に HTTP で送信します。
- Beam 側で AWS Signature Version 4（SigV4）を付与し、AWS IoT Core の HTTPS Publish API に転送します。
- AWS IoT Core のトピックは HTTP リクエストのパスで指定するため、Web サイトエントリポイントの「パスをそのまま引き継ぐ」挙動が向いています。
- MQTT スタックを積みにくい軽量なマイコンデバイスでも、HTTP のパスとしてトピック階層を渡すことで、AWS IoT Core の MQTT トピック設計や Rule Engine 連携のメリットを Publish 側で利用できます。
- SigV4 のサービス名は `iotdevicegateway`、ポートは `443` を使います。

![SORACOM Beam から AWS IoT Core へ HTTPS Publish する構成図](/images/soracom-beam-website-aws-iot-core-http-publish/10-architecture-diagram.png)

図中の IoT Rule 以降（AWS Lambda、Amazon Data Firehose、Amazon Timestream）は、AWS IoT Core 側で利用できる連携先の例です。
この記事では、SORACOM Beam から AWS IoT Core の MQTT トピックに Publish するところまでを扱います。

## はじめに

IoT デバイスから AWS IoT Core にデータを送る場合、よくある構成は MQTT over TLS で接続し、デバイスに X.509 証明書と秘密鍵を持たせる方法です。
一方で、デバイス側の実装や運用上の都合で、デバイスからは単純な HTTP POST だけを行い、クラウド側への認証や HTTPS 化はネットワーク側に寄せたいことがあります。

SORACOM Beam を使うと、デバイスからの HTTP リクエストを受け取り、転送先に HTTPS で送信できます。
さらに Beam の Authorization ヘッダー機能で AWS SigV4 を付与できるため、デバイスに AWS 認証情報や SigV4 署名ロジックを持たせずに AWS IoT Core の HTTPS Publish API を呼び出せます。

この構成の価値は、単に HTTP を AWS IoT Core に転送できることだけではありません。
AWS IoT Core では MQTT トピックの階層構造をデバイス種別、設置場所、通信種別などに合わせて設計し、IoT Rule や IAM ポリシーの単位として活用できます。
一方で、すべてのデバイスが MQTT、TLS、証明書管理、再接続処理まで実装できるとは限りません。
そこで、軽量なマイコンデバイスからは HTTP POST だけを行い、Beam 経由で AWS IoT Core のトピックに Publish することで、MQTT トピック設計の柔軟性を HTTP デバイスにも持ち込めます。

この記事では、SORACOM Beam の Web サイトエントリポイントから AWS IoT Core に HTTPS Publish する方法を解説します。
以下のようなリクエストを送ると AWS IoT Core の MQTT トピック `telemetry/site-a/line-1/device-001` に Publish されるように、AWS 側と SORACOM Beam 側を設定します。

```bash
curl -v 'http://beam.soracom.io:18080/topics/telemetry/site-a/line-1/device-001?qos=1' \
  -H 'content-type: application/json' \
  --data '{"temp":24.1,"status":"ok"}'
```

## 全体構成

今回の構成では、デバイスは AWS IoT Core のエンドポイントを直接呼びません。
デバイスの送信先は Beam の Web サイトエントリポイントです。
デバイスは `http://beam.soracom.io:18080/topics/telemetry/site-a/line-1/device-001?qos=1` に HTTP POST し、Beam は AWS SigV4 の `Authorization` ヘッダーを付与して AWS IoT Core Data-ATS エンドポイントの `https://<AWS_IOT_DATA_ENDPOINT>/topics/telemetry/site-a/line-1/device-001?qos=1` に転送します。

ポイントは 2 つです。

1. AWS IoT Core の HTTPS Publish API は、送信先トピックを `/topics/{topicName}` というパスで指定します。
2. Beam の Web サイトエントリポイントは、デバイスから送られたパスとクエリパラメータを転送先に引き継げます。

AWS IoT Core の HTTPS Publish API は以下のような URL に POST します。

```text
https://<AWS_IOT_DATA_ENDPOINT>/topics/<TOPIC_NAME>?qos=1
```

Beam の転送先を AWS IoT Core の Data-ATS エンドポイントのホスト部分にしておけば、デバイス側のリクエストパスがそのまま AWS IoT Core の Publish API のパスになります。

```text
デバイスから Beam へ:
http://beam.soracom.io:18080/topics/telemetry/site-a/line-1/device-001?qos=1

Beam から AWS IoT Core へ:
https://<AWS_IOT_DATA_ENDPOINT>/topics/telemetry/site-a/line-1/device-001?qos=1
```

参考:

- [SORACOM Beam: Web サイトエントリポイント](https://users.soracom.io/ja-jp/docs/beam/website/)
- [AWS IoT Core: HTTPS publish](https://docs.aws.amazon.com/iot/latest/developerguide/http.html)
- [AWS IoT Core: Publish API](https://docs.aws.amazon.com/iot/latest/apireference/API_iotdata_Publish.html)
- [AWS ブログ: Designing MQTT Topics for AWS IoT Core – ホワイトペーパーについて](https://aws.amazon.com/jp/blogs/news/about_designing_mqtt_topics_for_aws_iot_core/)

## SORACOM Beam Web サイトエントリポイントで IoT Core に連携するメリット

SORACOM Beam の Web サイトエントリポイントを使うメリットは、デバイス側の送信先を `http://beam.soracom.io:18080` に固定しつつ、リクエストパスを AWS IoT Core の Publish API に引き継げることです。
これにより、デバイス側は HTTP POST のまま、クラウド側では AWS IoT Core の MQTT トピック設計を使えます。

AWS のブログ「[Designing MQTT Topics for AWS IoT Core – ホワイトペーパーについて](https://aws.amazon.com/jp/blogs/news/about_designing_mqtt_topics_for_aws_iot_core/)」では、MQTT トピックの階層構造を自由に設計できること、デバイス情報や通信種別に合わせて構造をそろえること、トピックごとにポリシーや Rule Engine の処理を組み立てられることが紹介されています。

たとえば、MQTT を直接話せるデバイスであれば、以下のようなトピック設計が考えられます。

```text
telemetry/site-a/line-1/device-001
telemetry/site-a/line-1/device-002
event/site-a/line-1/device-001
```

このように、抽象的な情報から具体的な情報へ階層化しておくと、AWS IoT Rule Engine 側で `telemetry/+/+/+` のような単位でテレメトリを集約したり、トピック ARN を使って Publish 可能な範囲を制限したりしやすくなります。

SORACOM Beam の Web サイトエントリポイントでは、デバイスが MQTT を直接実装していなくても、HTTP のパスとして同じトピック階層を表現できます。
トピック名に URL として扱いにくい文字を含める場合は、AWS IoT Core の HTTPS Publish API に渡すパスとして適切に URL エンコードしてください。

```bash
curl -v 'http://beam.soracom.io:18080/topics/telemetry/site-a/line-1/device-001?qos=1' \
  -H 'content-type: application/json' \
  --data '{"temp":24.1,"status":"ok"}'
```

Beam から AWS IoT Core へは、以下のような Publish API として転送されます。

```text
POST /topics/telemetry/site-a/line-1/device-001?qos=1
```

AWS IoT Core から見ると、最終的には MQTT トピック `telemetry/site-a/line-1/device-001` への Publish です。
つまり、デバイス側の実装は HTTP POST のままでも、クラウド側では AWS IoT Core のトピック設計、IoT Rule、トピック ARN による権限制御を活用できます。
MQTT スタックを積みにくい軽量なマイコンデバイスでも、HTTP リクエストのパスを使ってトピック階層を表現できる点が、この構成の大きな利点です。

:::message
この構成で扱うのは、デバイスからクラウドへの Publish です。MQTT の Subscribe、クラウドからデバイスへのコマンド配信、双方向セッションまで HTTP で置き換えるものではありません。コマンドやデバイス状態管理が必要な場合は、AWS IoT Device Shadow、AWS IoT Jobs、MQTT 接続、または別の下り方向の通信設計を検討してください。
:::

## 事前準備

この記事では、以下が準備済みであることを前提にします。

- SORACOM Air for セルラー、または SORACOM Arc で Beam に到達できるデバイス
- Beam を設定する SIM グループ
- AWS IoT Core を利用する AWS アカウント
- AWS マネジメントコンソール

以降は、AWS 側の準備、SORACOM 側の設定、Publish 確認の順で進めます。

1. AWS IoT Core のデータエンドポイントを確認する
2. IAM ポリシーと IAM ロールを作成する
3. SORACOM Beam をセットアップする
4. Web サイトエントリポイントを使って AWS IoT Core に Publish する
5. AWS IoT Core で受信を確認する

## ステップ 1: AWS IoT Core のデータエンドポイントを確認する

AWS IoT Core の HTTPS Publish API にリクエストを送るため、AWS IoT Core の Data-ATS エンドポイントを確認します。

AWS IoT Core コンソールの [ドメイン設定] でも、`iot:Data-ATS` のドメイン名として確認できます。

![AWS IoT Core の Data-ATS エンドポイント](/images/soracom-beam-website-aws-iot-core-http-publish/01-aws-iot-data-endpoint.png)

以降、この値を `<AWS_IOT_DATA_ENDPOINT>` と表記します。

:::message
この記事ではリージョン例として `ap-northeast-1` を使います。実際の設定では、AWS IoT Core のリージョン、Beam の SigV4 設定のリージョン、IAM ポリシーの ARN をそろえてください。
:::

## ステップ 2: IAM ポリシーと IAM ロールを作成する

Beam から AWS IoT Core に Publish するために、Beam が AssumeRole できる IAM ロールを用意します。

作成するものは以下です。

| 項目 | 説明 |
|---|---|
| IAM ポリシー | AWS IoT Core のトピックに Publish するための権限です。 |
| IAM ロール | SORACOM の AWS アカウントから AssumeRole できるロールです。 |

### IAM ポリシーを作成する

AWS IoT Core に Publish するには `iot:Publish` が必要です。
動作確認だけなら広い権限でも動きますが、意図しない Publish を防ぐため、実際に利用するトピックに合わせて権限を絞る方が安全です。

AWS マネジメントコンソールで作成する場合は、IAM ポリシーの作成画面で以下のように設定します。

| 項目 | 値 |
|---|---|
| Service | IoT |
| アクション | `Publish` |
| リソース | Publish を許可する topic ARN |
| ポリシー名 | 例: `beam-aws-iot-publish-policy` |

たとえば `telemetry/site-a/line-1/` 配下のトピックだけに Publish させるなら、以下のようにします。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iot:Publish",
      "Resource": "arn:aws:iot:ap-northeast-1:<AWS_ACCOUNT_ID>:topic/telemetry/site-a/line-1/*"
    }
  ]
}
```

以下は動作確認用の IAM ポリシーの例です。`iot:Publish` が許可されていることを確認します。

![AWS IoT Core への Publish を許可する IAM ポリシー](/images/soracom-beam-website-aws-iot-core-http-publish/02-iam-policy-iot-publish.png)

この記事の動作確認例で使う `telemetry/site-a/line-1/device-001` だけに絞る場合は、以下のようにできます。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iot:Publish",
      "Resource": "arn:aws:iot:ap-northeast-1:<AWS_ACCOUNT_ID>:topic/telemetry/site-a/line-1/device-001"
    }
  ]
}
```

:::message alert
`Resource: "*"` でも動作確認はできますが、意図しないトピックへの Publish を防ぐため、実際に使うトピック名やプレフィックスに合わせて ARN を絞ってください。
:::

### IAM ロールを作成する

IAM ロールの信頼ポリシーでは、SORACOM 側の AWS アカウントから `sts:AssumeRole` できるようにします。
日本カバレッジで利用する場合の SORACOM の AWS アカウントは `762707677580` です。

IAM ロールの作成画面では、以下のように設定します。

| 項目 | 値 |
|---|---|
| 信頼されたエンティティ | SORACOM の AWS アカウント |
| SORACOM の AWS アカウント | `762707677580` |
| 外部 ID | 任意の十分に推測しにくい文字列。以降 `<EXTERNAL_ID>` と表記 |
| 許可ポリシー | 先ほど作成した `beam-aws-iot-publish-policy` |
| ロール名 | 例: `beam-aws-iot-publish-role` |

信頼ポリシーの例です。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::762707677580:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "<EXTERNAL_ID>"
        }
      }
    }
  ]
}
```

作成した IAM ロールの信頼関係では、SORACOM の AWS アカウントからの `sts:AssumeRole` と `sts:ExternalId` 条件を確認します。

![SORACOM の AWS アカウントを許可する IAM ロール信頼ポリシー](/images/soracom-beam-website-aws-iot-core-http-publish/03-iam-role-trust-policy.png)

`<EXTERNAL_ID>` は任意の十分に推測しにくい文字列にします。
この値は、あとで SORACOM の認証情報ストアにも同じ値で登録します。
作成した IAM ロールの ARN は、以降 `<IAM_ROLE_ARN>` と表記します。

:::message
SORACOM のカバレッジタイプやランデブーポイントによって、利用する SORACOM 側 AWS アカウントや STS エンドポイントの考慮点が変わります。実際の環境では SORACOM のドキュメントを確認してください。
:::

参考:

- [SORACOM 認証情報ストア: 登録項目リファレンス](https://users.soracom.io/ja-jp/docs/credentials-store/references/)
- [SORACOM Beam: AWS Signature V4](https://users.soracom.io/ja-jp/docs/beam/http/#aws-signature-v4)

## ステップ 3: SORACOM Beam をセットアップする

ここでは、認証情報ストアに IAM ロールを登録してから、SIM グループに Beam の Web サイトエントリポイントを設定します。

### 認証情報ストアに AWS IAM ロール認証情報を登録する

Beam から AWS IoT Core に Publish するために、IAM ロールに関する認証情報を SORACOM ユーザーコンソールに登録します。

1. SORACOM ユーザーコンソールで、認証情報ストアの「認証情報を登録」画面を開きます。
2. 以下のように登録します。

| 項目 | 値 |
|---|---|
| 認証情報 ID | 任意の ID。例: `aws-iot-publish-role` |
| 種別 | AWS IAM ロール認証情報 |
| ロール ARN | `<IAM_ROLE_ARN>` |
| 外部 ID | IAM ロールの信頼ポリシーに設定した `<EXTERNAL_ID>` |

登録後、認証情報ストアで AWS IAM ロール認証情報として保存されていることを確認します。

![SORACOM 認証情報ストアに登録した AWS IAM ロール認証情報](/images/soracom-beam-website-aws-iot-core-http-publish/04-soracom-credentials-store-iam-role.png)

この時点で、デバイスやファームウェアには AWS のアクセスキー、シークレットアクセスキー、IAM ロール ARN、ExternalId を持たせません。
AWS への署名は Beam が行います。

### Beam の Web サイトエントリポイントを設定する

:::message
Beam の設定は SIM グループに対して行います。ここでは、対象の SIM / vSIM が所属するグループを変更する操作のみを説明します。
:::

1. SIM グループ画面で [SORACOM Beam 設定] をクリックします。
2. [＋設定を追加する] → [Web サイトエントリポイント] の順にクリックします。
3. 「SORACOM Beam - Web サイト転送設定」画面で、以下のように設定します。

| 項目 | 値 |
|---|---|
| 設定名 | 任意の設定名。例: `AWS IoT Core HTTPS Publish` |
| 転送先 → プロトコル | HTTPS |
| 転送先 → ホスト名 | `<AWS_IOT_DATA_ENDPOINT>` |
| 転送先 → ポート番号 | 空欄、または `443` |
| ヘッダ操作 → Authorization ヘッダ | オン |
| Authorization ヘッダ → タイプ | AWS Signature V4 |
| Authorization ヘッダ → サービス | `iotdevicegateway` |
| Authorization ヘッダ → リージョン | AWS IoT Core のリージョン。例: `ap-northeast-1` |
| Authorization ヘッダ → 認証情報 ID | 認証情報ストアに登録した ID。例: `aws-iot-publish-role` |

Web サイトエントリポイントでは、デバイスがアクセスする `http://beam.soracom.io:18080` と、転送先の AWS IoT Core Data-ATS エンドポイントを確認します。

![SORACOM Beam の Web サイトエントリポイント設定](/images/soracom-beam-website-aws-iot-core-http-publish/05-soracom-beam-website-entrypoint.png)

Authorization ヘッダーでは、AWS Signature V4、サービス `iotdevicegateway`、リージョン、認証情報 ID がそろっていることを確認します。

![SORACOM Beam の AWS Signature V4 設定](/images/soracom-beam-website-aws-iot-core-http-publish/06-soracom-beam-aws-sigv4.png)

4. [保存] をクリックします。
5. 対象の IoT SIM / vSIM がこの SIM グループに所属していることを確認します。

:::message alert
AWS IoT Core のデバイス向け通信を SigV4 で署名する場合、AWS Signature V4 の [サービス] には `iotdevicegateway` を指定します。`iot` や `IoT` ではありません。画面上で選択肢が見つからない場合は、利用環境のサポート状況と最新の SORACOM ドキュメントを確認してください。
:::

:::message
この記事は 2026年5月時点の検証結果に基づく構成例です。AWS SigV4 で利用できるサービスコードやサポート範囲は、実運用前に最新の SORACOM ドキュメントやサポート窓口で確認してください。
:::

参考:

- [AWS IoT Core: Device communication protocols](https://docs.aws.amazon.com/iot/latest/developerguide/protocols.html)
- [AWS IoT Core: MQTT](https://docs.aws.amazon.com/iot/latest/developerguide/mqtt.html)

:::message alert
AWS IoT Core の HTTPS Publish では、認証方式によって使うポートが変わります。
この構成では Beam が AWS SigV4 で署名して HTTPS で Publish するため、転送先ポートは `443` です。

`8443` は X.509 クライアント証明書で HTTPS Publish する場合に使うポートです。
今回のように SigV4 を使う構成では、Beam の転送先に `https://<AWS_IOT_DATA_ENDPOINT>:8443` を指定しないようにします。
:::

## ステップ 4: Web サイトエントリポイントを使用して AWS IoT Core に Publish する

Beam の Web サイトエントリポイントを使用して、AWS IoT Core のトピックにデータを Publish します。

1. デバイスが、Beam を設定した SIM グループの SORACOM Air for セルラー、または SORACOM Arc で通信していることを確認します。
2. デバイスから、Beam の Web サイトエントリポイントに HTTP POST します。

```bash
curl -v 'http://beam.soracom.io:18080/topics/telemetry/site-a/line-1/device-001?qos=1' \
  -H 'content-type: application/json' \
  --data '{"temp":24.1,"status":"ok"}'
```

AWS IoT Core 側では、以下の Publish API として扱われます。

```text
POST /topics/telemetry/site-a/line-1/device-001?qos=1
```

`qos` は `0` または `1` を指定できます。
AWS IoT Core の Publish API では、トピック名はパス、QoS はクエリパラメータで指定します。

SORACOM Onyx に内蔵されている Quectel EG25-G のように、モデム側の HTTP クライアントを使える場合は、`AT+QHTTPURL` と `AT+QHTTPPOST` でも同じリクエストを送信できます。

:::details SORACOM Onyx の `QHTTPPOST` で送信する例

以下は、Onyx に挿入した SIM が Beam 設定済みグループに所属している状態で実行する例です。
APN と PDP コンテキストは利用する回線向けに設定済みで、ここでは `contextid=1` の PDP コンテキストを使う前提です。

```text
AT+QIACT=1
AT+QHTTPCFG="contextid",1
AT+QHTTPCFG="responseheader",1
AT+QHTTPCFG="contenttype",4
AT+QHTTPURL=76,30
http://beam.soracom.io:18080/topics/telemetry/site-a/line-1/device-001?qos=1
AT+QHTTPPOST=27,30,30
{"temp":24.1,"status":"ok"}
AT+QHTTPREAD=30
```

`AT+QHTTPURL` では、URL のバイト数を指定してから URL を送信します。
`AT+QHTTPCFG="contenttype",4` では、HTTP リクエストの `Content-Type` として `application/json` を指定しています。
`AT+QHTTPPOST` では、POST ボディのバイト数、入力待ちタイムアウト、応答待ちタイムアウトを指定してからボディを送信します。

:::

3. 成功時に以下のようなレスポンスが返ることを確認します。

```json
{"message":"OK","traceId":"..."}
```

実行結果では `+QHTTPPOST: 0,200,65` と `HTTP/1.1 200 OK` が返り、Beam から AWS IoT Core への Publish が成功しています。

![Onyx の QHTTPPOST で Beam に送信して 200 OK が返った結果](/images/soracom-beam-website-aws-iot-core-http-publish/08-device-qhttppost-success.png)

成功条件としては、まず HTTP ステータスが `200 OK` であることを確認します。
あわせて AWS IoT Core の MQTT テストクライアントで `telemetry/site-a/line-1/device-001` を Subscribe し、送信した JSON ペイロードが届くことを確認します。

## ステップ 5: AWS IoT Core で受信を確認する

AWS IoT Core コンソールの MQTT テストクライアントで、対象トピックを Subscribe します。

1. AWS IoT Core コンソールで MQTT テストクライアントを開きます。
2. この記事の例では、以下のトピックを Subscribe します。

```text
telemetry/site-a/line-1/device-001
```

複数のトピックを広く見る場合は以下を Subscribe します。

```text
#
```

3. Subscribe した状態で、デバイス側からステップ 4 の curl または QHTTPPOST の送信を実行します。
4. MQTT テストクライアントに以下のようなペイロードが表示されれば成功です。

```json
{
  "temp": 24.1,
  "status": "ok"
}
```

MQTT テストクライアントで `telemetry/site-a/line-1/device-001` を Subscribe すると、Onyx の `QHTTPPOST` で送った JSON ペイロードが表示されます。

![AWS IoT Core MQTT テストクライアントで受信した JSON ペイロード](/images/soracom-beam-website-aws-iot-core-http-publish/09-aws-iot-mqtt-test-client.png)

CloudWatch Logs で AWS IoT Core のログを有効化している場合は、AWS IoT Core コンソールや CloudWatch Logs から Publish リクエストの到達状況も確認できます。
MQTT テストクライアントで受信できない場合の補助的な切り分けに使います。

## トラブルシュート

### `Failed to assume Role` が返る

Beam が IAM ロールを AssumeRole できていない状態です。

以下を確認します。

- SORACOM 認証情報ストアのロール ARN が存在する IAM ロールを指しているか
- 認証情報ストアの ExternalId と IAM ロール信頼ポリシーの `sts:ExternalId` が一致しているか
- IAM ロールの信頼ポリシーで、利用中の SORACOM カバレッジに対応する AWS アカウントからの `sts:AssumeRole` を許可しているか
- Beam で AWS SigV4 を使うリージョンの AWS STS エンドポイントが有効か

### `403 Forbidden` が返る

Beam から AWS IoT Core へリクエストは届いているものの、AWS IoT Core 側で拒否されている可能性があります。

以下を確認します。

- Beam の SigV4 サービス名が `iotdevicegateway` になっているか
- Beam の転送先ポートが `443` になっているか
- IAM ロールに `iot:Publish` が許可されているか
- IAM ポリシーの `Resource` が実際のトピック ARN と一致しているか
- AWS IoT Core の Data-ATS エンドポイント、リージョン、AWS アカウントが一致しているか

### HTTP エントリポイントではなく Web サイトエントリポイントを使う理由

AWS IoT Core の HTTPS Publish API では、トピック名をパスで、QoS をクエリパラメータで指定します。

Beam の Web サイトエントリポイントは、デバイスから送ったパスとクエリパラメータを転送先に引き継げます。
そのため、デバイス側が `/topics/telemetry/site-a/line-1/device-001?qos=1` のようにパスを変えるだけで、Publish 先トピックを選べます。

一方、HTTP エントリポイントは特定のエントリパスに対する転送設定を作る用途に向いています。
デバイス側で Publish 先トピックをパスとして変えたい場合は、Web サイトエントリポイントの方が自然です。

### IMSI などの SORACOM ヘッダーは必要か

Beam では IMSI、SIM ID、MSISDN、IMEI などのヘッダーを転送先に付与できます。
ただし、AWS IoT Core の Publish API に単純にメッセージを送るだけなら、これらのヘッダーは必須ではありません。

デバイス識別子を AWS IoT Core 側に渡したい場合は、以下のような選択肢があります。

- Beam の SORACOM ヘッダーを付与する
- MQTT5 User Properties に相当するヘッダーを使う
- ペイロードにデバイス ID を含める
- トピック名にデバイス ID を含める

今回の記事では、まず Publish を成立させることに絞るため、SORACOM ヘッダーは無効の例にしています。
実運用では、必要な識別子だけを送るようにしてください。

## セキュリティと運用上の注意点

この構成では、デバイスに AWS 認証情報を持たせずに AWS IoT Core に Publish できます。
一方で、Beam に到達できる対象デバイスからは、IAM ロールで許可された範囲に Publish できることになります。

そのため、少なくとも以下を確認します。

- IAM ポリシーの `Resource` を必要なトピックに絞る
- SIM グループの対象を意図した SIM / vSIM に限定する
- ExternalId を環境ごとに分ける
- 不要な SORACOM ヘッダーを転送しない
- AWS IoT Core のログやメトリクスで Publish の失敗を検知できるようにする
- AWS IoT Core と SORACOM Beam の料金、クォータ、制限を本番前に確認する

特に、`telemetry/{siteId}/{lineId}/{deviceId}` のようにトピック設計を決めてから IAM ポリシーを作ると、権限を絞りやすくなります。

```json
{
  "Effect": "Allow",
  "Action": "iot:Publish",
  "Resource": "arn:aws:iot:ap-northeast-1:<AWS_ACCOUNT_ID>:topic/telemetry/site-a/line-1/*"
}
```

## まとめ

SORACOM Beam の Web サイトエントリポイントを使うと、デバイスからの HTTP リクエストパスをそのまま AWS IoT Core の HTTPS Publish API に引き継げます。
Beam が AWS SigV4 を付与するため、デバイス側に AWS 認証情報や SigV4 の実装を持たせる必要はありません。

設定で重要なのは以下です。

- Beam の転送先は AWS IoT Core の Data-ATS エンドポイントにする
- Web サイトエントリポイント `http://beam.soracom.io:18080` を使う
- AWS SigV4 のサービス名は `iotdevicegateway` にする
- SigV4 では転送先ポート `443` を使う
- IAM ロールは `iot:Publish` の対象トピックをできるだけ絞る

HTTP だけを話せるデバイスから AWS IoT Core にデータを入れたい場合や、デバイスに AWS 認証情報を持たせたくない場合の選択肢として使えます。
