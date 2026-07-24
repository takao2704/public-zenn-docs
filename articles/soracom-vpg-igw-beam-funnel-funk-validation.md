---
title: "VPGのIGWをOFFにするとBeam・Funnel・Funkはどうなる？3構成を実測した"
emoji: "🧪"
type: "tech"
topics: ["soracom", "vpg", "aws", "awsiot", "iot"]
published: false
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## TL;DR

- 本番では、VPG（Virtual Private Gateway）Type-F のインターネットゲートウェイ（IGW）を ON にし、アウトバウンドルーティングフィルターで `0.0.0.0/0` を deny にする構成を選びます。この状態で、Beam の HTTP `200`、Funnel の AWS IoT Core 受信、Funk の Lambda 応答を確認しました。
- Type-F の IGW を OFF にすると Beam HTTP はタイムアウトしました。一方、Funnel から AWS IoT Core、Funk から AWS Lambda への転送は成功しました。公式ドキュメントの説明と一致しないため、この挙動には依存しません。

## はじめに

知りたかったのは、デバイスから直接インターネットへ出さずに、SORACOM Beam、SORACOM Funnel、SORACOM Funk だけを使えるかどうかです。

手元の Raspberry Pi と SORACOM Air for セルラーの IoT SIM を使い、2026 年 7 月に VPG Type-F の設定を切り替えて試しました。比較したのは、Type-F の IGW OFF、Type-F の IGW ON + `deny 0.0.0.0/0`、Private Garden の 3 構成です。

検証対象は、Beam の HTTP → HTTPS、Funnel の AWS IoT Core アダプター、Funk の AWS Lambda です。Beam のほかのプロトコルや、Funnel / Funk のほかの転送先は試していません。

## 検証方法

VPG を切り替えるたびに SIM セッションを再確立し、セッションが目的の VPG に収容されたことを確認してから送信しました。

| 項目 | 環境 |
|---|---|
| SORACOM Air | 日本カバレッジ |
| デバイス | Raspberry Pi |
| AWS リージョン | 東京（`ap-northeast-1`） |
| Beam エントリポイント | `http://beam.soracom.io:8888/` |
| Funnel エントリポイント | `http://funnel.soracom.io` |
| Funk エントリポイント | `http://funk.soracom.io` |

| サービス | 転送経路 | 確認した内容 |
|---|---|---|
| Beam | HTTP → AWS IoT Core の HTTPS Publish API | Beam から返る HTTP ステータス |
| Funnel | HTTP → AWS IoT Core | 送信側とは別のクライアントで MQTT メッセージを購読 |
| Funk | HTTP → AWS Lambda | Funk 経由で受け取った Lambda のレスポンス |

Funnel は非同期で転送するため、エントリポイントが返す HTTP `204` だけでは転送先への配送完了を判断できません。
AWS IoT Core の対象トピックを別クライアントから購読し、送信ごとに変えた識別子が受信データに含まれるかを確認しました。

## 結果

| サービス | Type-F / IGW OFF | Type-F / IGW ON + deny `0.0.0.0/0` | Private Garden |
|---|---:|---:|---:|
| Beam HTTP → AWS IoT Core | 30 秒でタイムアウト | HTTP `200` | HTTP `200` |
| Funnel → AWS IoT Core | MQTT 購読で受信 | MQTT 購読で受信 | MQTT 購読で受信 |
| Funk → AWS Lambda | Lambda 応答を受信 | Lambda 応答を受信 | Lambda 応答を受信 |

:::details 匿名化した検証ログ
```text
[Type-F / IGW OFF]
Beam:  HTTP 000 / curl exit code 28 / 30.00 s
Funnel: HTTP 204 / MQTT marker_match=true
Funk:  HTTP 200 / {"statusCode":204}

[Type-F / IGW ON + deny 0.0.0.0/0]
Beam:  HTTP 200
Funnel: HTTP 204 / MQTT marker_match=true
Funk:  HTTP 200 / {"statusCode":204}

[Private Garden]
Beam:  HTTP 200
Funnel: HTTP 204 / MQTT marker_match=true
Funk:  HTTP 200 / {"statusCode":204}
```

Funnel の `marker_match=true` は、送信側とは別の MQTT クライアントで `telemetry/vpg-test` を購読し、送信ごとに変えた識別子が一致したことを表します。IMSI、IMEI、VPG ID、認証情報は省略しています。
:::

### Beam

IGW OFF では Beam のエントリポイントに TCP 接続できましたが、HTTP レスポンスは返らず、30 秒でタイムアウトしました。IGW ON + `deny 0.0.0.0/0` と Private Garden では HTTP `200` が返りました。

Beam については、Funnel のような AWS IoT Core 側での独立購読までは行っていません。ここで確認したのは Beam の HTTP 応答です。

:::message alert
この結果は Beam の HTTP → HTTPS 転送に限ります。公式ドキュメントでは、Beam の MQTT → MQTT/MQTTS と TCP → TCP/TCPS からパブリックな転送先を使うにはインターネットルートが必要とされています。
:::

### Funnel

3 構成とも、Funnel は HTTP `204` を返しました。AWS IoT Core では、送信した JSON、検証用の識別子、IMSI、IMEI を含むメッセージを受信しています。Funnel から AWS IoT Core までの配送を確認できました。

### Funk

転送先には AWS Lambda を設定しました。3 構成とも Funk から HTTP `200` が返り、Lambda のレスポンスも受信しました。

## 公式ドキュメントの解釈

[VPG の特徴](https://users.soracom.io/ja-jp/docs/vpg/feature/)には、アウトバウンドルーティングフィルターについて次の記述があります。

> 「[インターネットへのルートをブロックする] にチェックを入れても、Beam、Funnel、Funk で、（中略）データを転送できます。」

これは、Type-F の IGW ON + `deny 0.0.0.0/0` で Beam、Funnel、Funk のすべてが成功した今回の結果と一致します。デバイスの直接通信を拒否しながらパブリックな転送先を使う構成として、公式ドキュメントに記載された挙動です。

同じページでは、IGW OFF の場合について次のように記載されています。

> 「Beam、Funnel、Funk を利用しても、（中略）データを転送できません。」

Beam HTTP がタイムアウトした結果は、この記述と一致します。一方、Funnel から AWS IoT Core、Funk から AWS Lambda への転送は成功しました。この成功は検証時点で観測した挙動であり、IGW OFF で利用できることが保証されたとは解釈しません。本番構成では依存せず、IGW OFF が必須なら SORACOM サポートへ確認します。

Private Garden についても、[VPG の特徴](https://users.soracom.io/ja-jp/docs/vpg/feature/)に具体的な記述があります。

> 「デバイスから直接インターネットへはアクセスできませんが、Beam、Funnel、Funk、（中略）は利用できます。」

Private Garden で Beam、Funnel、Funk のすべてが成功した結果は、この記述と一致します。ただし、[Beam Advanced Security](https://developers.soracom.io/en/docs/beam/advanced-security/)には「Using Soracom Beam MQTT and TCP → TCP/TCPS entry points with a public destination requires an Internet route」とあります。Private Garden を選ぶときも、利用するサービスとプロトコルのドキュメントをあわせて確認します。

## 本番で採用する構成

デバイスからインターネットへの直接通信を止めつつ、Beam、Funnel、Funk からパブリックな転送先を使う場合は、Type-F の IGW を ON にして `0.0.0.0/0` を deny にします。

:::message alert
[VPG の作成手順](https://users.soracom.io/ja-jp/docs/vpg/create-vpg/)にあるとおり、IGW は VPG の作成後に変更できません。IGW OFF の VPG から移行するときは、新しい VPG を作成します。VPG の作成にはセットアップ料金がかかり、削除するまで基本料金も発生します。金額は[最新の VPG 利用料金](https://soracom.jp/services/vpg/price/)を確認してください。

SIM グループの設定を変えただけでは、接続中の IoT SIM が使う VPG は切り替わりません。[IoT SIM が利用する VPG を切り替える](https://users.soracom.io/ja-jp/docs/vpg/use-vpg/)に沿ってセッションを再確立する必要があります。通信断を見込んで作業時間を決めます。
:::

```text
VPG Type-F
  インターネットゲートウェイ: ON
  アウトバウンドルーティングフィルター:
    deny 0.0.0.0/0
```

アウトバウンドルーティングフィルターの設定値は次のとおりです。

```json
[
  {
    "action": "deny",
    "ipRange": "0.0.0.0/0"
  }
]
```

この Type-F 構成は今回実測済みです。VPG Type-F2 でもアウトバウンドルーティングフィルターを利用できますが、今回の検証対象には含めていません。

VPG を個別に作成しないなら Private Garden も候補です。ただし、Beam の MQTT → MQTT/MQTTS と TCP → TCP/TCPS でパブリックな転送先を使う構成には選びません。

## まとめ

Type-F の IGW OFF でも Funnel と Funk は動きましたが、公式ドキュメントと一致しないため、この挙動を本番要件には使いません。デバイスの直接インターネット通信を止めて Beam、Funnel、Funk を使うなら、IGW ON + `deny 0.0.0.0/0` を採用します。
