---
title: "SORACOM Air から AWS Management Console Private Access に閉域アクセスする"
emoji: "🔐"
type: "tech"
topics: ["soracom", "aws", "vpg", "canal", "privatelink"]
published: true
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## TL;DR

- AWS Management Console Private Access により、対応する AWS Console 通信を VPC endpoint 経由にできます。
- SORACOM Air のデバイスからも、VPG と SORACOM Canal で AWS VPC に到達できれば、AWS Console の private endpoint に閉域アクセスできます。
- ポイントは、Raspberry Pi 側の DNS を Route 53 Resolver inbound endpoint に向けることです。
- VPG Type-F のインターネットゲートウェイを OFF にした状態でも、Raspberry Pi 上のブラウザから `console.aws.amazon.com` にアクセスできました。
- 本記事は 1 台の Raspberry Pi での最小検証です。

## はじめに

2026 年 6 月に、AWS Management Console Private Access がインターネット接続なしで利用できるようになりました。
これにより、対応する AWS Console 通信を AWS PrivateLink の VPC endpoint 経由にできます。

https://aws.amazon.com/jp/about-aws/whats-new/2026/06/aws-management-console-private/

通常、この機能は社内ネットワークや VPC 内の端末から AWS Console を使う文脈で説明されます。
では、SORACOM Air のセルラー回線で動く Raspberry Pi から、AWS Console を閉域で開けるでしょうか。

結論としては、以下の条件を満たせば可能です。

- Raspberry Pi が SORACOM Air で VPG に収容されている
- VPG と AWS VPC が SORACOM Canal で接続されている
- AWS VPC に AWS Console Private Access 用の interface VPC endpoint がある
- Raspberry Pi の DNS が Route 53 Resolver inbound endpoint を向いている
- VPG subnet CIDR から VPC endpoint と Resolver inbound endpoint への Security Group（SG）が許可されている

この記事では、Raspberry Pi 上のブラウザから AWS Console を開くまでの構成をまとめます。
Raspberry Pi の操作は、デバイスに接続した画面・キーボード、または任意のローカル操作手段で行う前提です。

## 全体構成

今回の構成は以下です。

![AWS Management Console Private Access に SORACOM Air から閉域アクセスする全体構成](/images/aws-console-private-access-soracom-vpg-canal/00-architecture-overview.png)

通信の流れを分けると、次の 2 つです。

| 用途 | 宛先 | 経路 |
|---|---|---|
| DNS | Route 53 Resolver inbound endpoint | Raspberry Pi -> SORACOM Air -> VPG -> Canal -> AWS VPC |
| HTTPS | AWS Console Private Access の VPC endpoint | Raspberry Pi -> SORACOM Air -> VPG -> Canal -> AWS VPC |

重要なのは、Raspberry Pi が `console.aws.amazon.com` や `signin.aws.amazon.com` をパブリック IP ではなく、VPC endpoint の private IP として名前解決することです。

## 今回扱う範囲

この記事では、以下の最小構成を扱います。

- SORACOM 日本カバレッジ
- VPG Type-F
- VPG のインターネットゲートウェイは OFF
- SORACOM Canal の VPC Peering 接続
- AWS リージョンは `ap-northeast-1`
- AWS Console、AWS Sign-In、Console static content の VPC endpoint
- Raspberry Pi 上のブラウザで AWS Console のホーム画面を開く

AWS のドキュメントでは、AWS Management Console Private Access に必要な endpoint と DNS 設定が説明されています。
各リージョンに `com.amazonaws.<region>.console`、`com.amazonaws.<region>.signin`、ネットワーク分離環境では `com.amazonaws.<region>.console-static` が必要です。
また、利用リージョンに関わらず `us-east-1` への接続性を用意する必要がある点も明記されています。

https://docs.aws.amazon.com/awsconsolehelpdocs/latest/gsg/required-endpoints-dns-configuration.html

そのため、本番利用では `ap-northeast-1` だけでなく、`us-east-1` への接続性と、利用するサービスコンソールごとの endpoint も確認してください。
AWS が公開している Console Private Access の設定 JSON から、リージョンごとの対象サービスと DNS 名を確認できます。

https://configuration.private-access.console.amazonaws.com/ap-northeast-1.config.json

## 事前準備

以下を用意します。

- SORACOM Air の IoT SIM
- Raspberry Pi
- SORACOM VPG Type-F
- SORACOM Canal で接続する AWS VPC
- Route 53 Resolver inbound endpoint を置けるサブネット
- AWS Console Private Access 用の interface VPC endpoint を置けるサブネット

この記事では、説明用に以下の例示値を使います。
実際の値は自分の環境に置き換えてください。

| 項目 | 例 |
|---|---|
| AWS リージョン | `ap-northeast-1` |
| AWS VPC CIDR | `10.64.0.0/16` |
| VPG subnet CIDR | `<VPG_SUBNET_CIDR>` |
| Resolver inbound endpoint IP | `10.64.1.205`, `10.64.2.8` |
| Console endpoint private IP | `10.64.1.148`, `10.64.2.127` |
| Sign-in endpoint private IP | `10.64.1.232`, `10.64.2.93` |

VPG subnet CIDR は、VPG 作成時に割り当てられる `vpgSubnetCidrRange` です。
図では VPG の一般的な CIDR 範囲として `100.64.0.0/10` を示していますが、AWS の route table や SG には、自分の VPG に割り当てられた VPG subnet CIDR を指定します。

ライブの AWS アカウント ID、VPC ID、VPG ID、SIM ID、group ID などは記事中では扱いません。

## ステップ 1: VPG Type-F をインターネットゲートウェイ OFF で作成する

SORACOM User Console で VPG Type-F を作成します。
このとき、VPG のインターネットゲートウェイを OFF にします。

https://users.soracom.io/ja-jp/docs/vpg/create-vpg/

1. SORACOM User Console で VPG の画面を開きます。
2. VPG を作成し、Type-F を選択します。
3. デバイスサブネット CIDR を指定します。この記事では例として `10.128.0.0/9` を使います。
4. インターネットゲートウェイを OFF にして作成します。
5. 作成後、VPG 一覧で対象 VPG が Type-F、実行中、インターネットゲートウェイなしであることを確認します。

![SORACOM User Console の VPG 作成フォーム](/images/aws-console-private-access-soracom-vpg-canal/01-vpg-create-type-f.png)

![SORACOM User Console の VPG 一覧](/images/aws-console-private-access-soracom-vpg-canal/01-soracom-vpg-list.png)

:::details CLI で作成・確認する場合

CLI で作成する場合の例です。

```bash
soracom vpg create \
  --coverage-type jp \
  --body '{
    "type": 15,
    "deviceSubnetCidrRange": "10.128.0.0/9",
    "useInternetGateway": false
  }'
```

作成後、`useInternetGateway` が `false` であることを確認します。

```bash
soracom vpg get \
  --coverage-type jp \
  --vpg-id "<TYPE_F_VPG_ID>" |
jq '{vpgId,type,status,useInternetGateway,deviceSubnetCidrRange,vpgSubnetCidrRange}'
```

確認例です。

```json
{
  "vpgId": "<TYPE_F_VPG_ID>",
  "type": 15,
  "status": "running",
  "useInternetGateway": false,
  "deviceSubnetCidrRange": "10.128.0.0/9",
  "vpgSubnetCidrRange": "<VPG_SUBNET_CIDR>"
}
```

:::

## ステップ 2: SORACOM Canal で AWS VPC と接続する

VPG と AWS VPC を SORACOM Canal の VPC Peering で接続します。

https://users.soracom.io/ja-jp/docs/canal/peering/

1. SORACOM User Console で対象 VPG を開き、SORACOM Canal の VPC Peering を作成します。
2. 接続先の AWS アカウント、VPC、CIDR などを指定して peering request を作成します。
3. AWS VPC Console の Peering connections で request を承諾します。
4. VPG 側と AWS 側の peering connection が `active` になっていることを確認します。

SORACOM User Console では、対象 VPG の「閉域網設定」タブで SORACOM Canal の VPC Peering を確認できます。

![SORACOM User Console の SORACOM Canal VPC Peering 設定](/images/aws-console-private-access-soracom-vpg-canal/02-soracom-canal-vpc-peering.png)

以下は AWS 側で peering connection が `active` になっている確認画面です。

![AWS VPC peering connection が active の状態](/images/aws-console-private-access-soracom-vpg-canal/02-aws-vpc-peering-active.png)

AWS 側の route table には、VPG subnet CIDR への戻り経路を追加します。
AWS VPC Console で対象 subnet の route table を開き、以下の route を追加します。
ここで使うのは、デバイスサブネット CIDR ではなく VPG の `vpgSubnetCidrRange` です。

| Destination | Target |
|---|---|
| `<VPG_SUBNET_CIDR>` | `<VPC_PEERING_CONNECTION_ID>` |

この戻り経路がないと、Raspberry Pi から VPC endpoint へ SYN は届いても、応答が VPG 側へ戻れません。

![AWS VPC route table の戻り経路](/images/aws-console-private-access-soracom-vpg-canal/03-aws-route-table-routes.png)

## ステップ 3: Console Private Access 用 VPC endpoint を作成する

AWS VPC Console で interface VPC endpoint を作成します。

インターネット接続なしの検証では、少なくとも以下を作成します。

```text
com.amazonaws.ap-northeast-1.console
com.amazonaws.ap-northeast-1.signin
com.amazonaws.ap-northeast-1.console-static
```

1. AWS VPC Console で Endpoints を開き、Create endpoint を選択します。
2. Service category は AWS services を選び、上記のサービス名を 1 つずつ作成します。
3. 接続先 VPC と subnet を選択します。
4. Private DNS を有効にします。
5. endpoint 用 SG を関連付けます。
6. 作成後、endpoint のステータスが `使用可能` になっていることを確認します。

![AWS VPC endpoint の作成画面](/images/aws-console-private-access-soracom-vpg-canal/04-vpc-endpoint-create.png)

Private DNS を有効にすると、VPC Resolver から見た `console.aws.amazon.com` や `signin.aws.amazon.com` が、VPC endpoint の private IP に解決されます。

endpoint 用 SG では、少なくとも VPG subnet CIDR から TCP 443 を許可します。

| Protocol | Port | Source |
|---|---:|---|
| TCP | 443 | `<VPG_SUBNET_CIDR>` |

VPC 内の EC2 から疎通確認する場合は、検証元の CIDR も一時的に許可してください。

以下は `console` endpoint の詳細例です。
`signin` と `console-static` も同じ要領で、ステータスが `使用可能`、Private DNS が有効になっていることを確認します。

![AWS VPC endpoint の詳細](/images/aws-console-private-access-soracom-vpg-canal/04-aws-vpc-endpoint-console-detail.png)

## ステップ 4: Route 53 Resolver inbound endpoint を作成する

Raspberry Pi が AWS Console の DNS 名を private IP に解決できるように、Route 53 Resolver inbound endpoint を作成します。

1. AWS Console で Route 53 Resolver を開き、Inbound endpoints を作成します。
2. 対象 VPC を選択します。
3. 複数 AZ の subnet を選び、それぞれに inbound endpoint の IP アドレスを割り当てます。
4. Resolver inbound endpoint 用 SG を関連付けます。
5. 作成後、endpoint が利用可能になったら IP アドレスを控えます。

![Route 53 Resolver inbound endpoint の作成画面](/images/aws-console-private-access-soracom-vpg-canal/05-route53-resolver-inbound-create.png)

Resolver inbound endpoint 用 SG では、VPG subnet CIDR から UDP/TCP 53 を許可します。

| Protocol | Port | Source |
|---|---:|---|
| UDP | 53 | `<VPG_SUBNET_CIDR>` |
| TCP | 53 | `<VPG_SUBNET_CIDR>` |

この記事の例では以下の 2 つを使います。

```text
10.64.1.205
10.64.2.8
```

![Route 53 Resolver inbound endpoint の IP アドレス一覧](/images/aws-console-private-access-soracom-vpg-canal/05-route53-resolver-inbound-detail.png)

## ステップ 5: SIM group に VPG と Custom DNS を設定する

SORACOM Air の SIM group で、作成した VPG を利用するように設定します。
あわせて Custom DNS に Resolver inbound endpoint の IP アドレスを設定します。

https://users.soracom.io/ja-jp/docs/air/configure-custom-dns/

1. SORACOM User Console で対象の SIM group を開きます。
2. SORACOM Air for セルラーの設定で VPG を有効にし、作成した VPG Type-F を選択します。
3. Custom DNS を有効にし、Resolver inbound endpoint の IP アドレスを DNS サーバーとして設定します。
4. 設定を保存します。
5. 対象 SIM をこの group に所属させます。
6. 既存セッションには VPG や DNS の設定が即時反映されないため、セッション再確立後に確認します。

この記事の例では、DNS サーバーとして `10.64.1.205` と `10.64.2.8` を設定しています。

![SORACOM User Console の SIM group 設定](/images/aws-console-private-access-soracom-vpg-canal/06-soracom-sim-group-air-settings.png)

:::details CLI で SIM group 設定を投入・確認する場合

CLI で設定する場合の例です。

```bash
soracom groups put-config \
  --coverage-type jp \
  --group-id "<SIM_GROUP_ID>" \
  --namespace SoracomAir \
  --body '[
    {"key":"useVpg","value":true},
    {"key":"vpgId","value":"<TYPE_F_VPG_ID>"},
    {"key":"useCustomDns","value":true},
    {"key":"dnsServers","value":["10.64.1.205","10.64.2.8"]}
  ]'
```

対象 SIM の group 所属を切り替え、セッション再確立後に確認します。

```bash
soracom sims get \
  --coverage-type jp \
  --sim-id "<SIM_ID>" |
jq '{groupId,sessionStatus:{online:.sessionStatus.online,vpgId:.sessionStatus.vpgId,dnsServers:.sessionStatus.dnsServers,ueIpAddress:.sessionStatus.ueIpAddress,gatewayPrivateIpAddress:.sessionStatus.gatewayPrivateIpAddress}}'
```

確認例です。

```json
{
  "groupId": "<SIM_GROUP_ID>",
  "sessionStatus": {
    "online": true,
    "vpgId": "<TYPE_F_VPG_ID>",
    "dnsServers": [
      "10.64.1.205",
      "10.64.2.8"
    ],
    "ueIpAddress": "<UE_IP>",
    "gatewayPrivateIpAddress": "<VPG_GATEWAY_IP>"
  }
}
```

:::

## ステップ 6: Raspberry Pi をセルラー経路だけで動かす

Raspberry Pi 上のブラウザで検証する前に、通信が Wi-Fi や有線 LAN へ逃げないようにします。
検証用であれば、Wi-Fi を OFF にするのが分かりやすいです。

1. Raspberry Pi のデスクトップでネットワークメニューを開き、Wi-Fi を OFF にします。
2. 有線 LAN を接続している場合は、検証中だけ外すか、default route がセルラー側になることを確認します。
3. Raspberry Pi のターミナルを開き、`wwan0` が上がっていること、default route と DNS がセルラー側になっていることを確認します。
4. `/etc/resolv.conf` に Resolver inbound endpoint の IP アドレスが入っていることを確認します。

期待する状態は、default route が `wwan0` を向き、DNS サーバーが `10.64.1.205` と `10.64.2.8` になっていることです。
下のスクリーンショットでは、`ip -br addr show wwan0`、`ip route show default`、`cat /etc/resolv.conf` の結果を載せています。

Wi-Fi が有効なままの場合、`/etc/resolv.conf` の先頭に家庭内ルーターや社内 DNS が残り、AWS Console の名前解決がパブリック側に流れることがあります。
この検証では、Raspberry Pi 自身が SORACOM Air 経由で Resolver inbound endpoint に問い合わせる状態にします。

![Raspberry Pi のセルラー経路と DNS 設定](/images/aws-console-private-access-soracom-vpg-canal/07-raspberry-pi-cellular-route-terminal.png)

:::details 端末でセルラー経路と DNS を確認する場合

Raspberry Pi のローカル端末で Wi-Fi を OFF にする場合は、以下を実行します。

```bash
sudo nmcli radio wifi off
```

`wwan0` がセルラーインターフェースとして上がっていることを確認します。

```bash
ip addr show wwan0
```

例です。

```text
3: wwan0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1430
    inet <UE_IP>/<PREFIX> scope global noprefixroute wwan0
```

ルーティングと DNS も確認します。

```bash
ip route
cat /etc/resolv.conf
```

期待する状態は以下です。

```text
default via <WWAN_GATEWAY_IP> dev wwan0
```

```text
nameserver 10.64.1.205
nameserver 10.64.2.8
```

:::

## ステップ 7: Raspberry Pi 上のブラウザで AWS Console を開く

Raspberry Pi 上で Chromium または Firefox を起動し、以下を開きます。

```text
https://console.aws.amazon.com/console/home?region=ap-northeast-1
```

このとき、Raspberry Pi は `console.aws.amazon.com` を VPC endpoint の private IP として解決します。
ブラウザで AWS Console のサインイン画面または Console Home が表示されれば、Raspberry Pi から閉域経路で AWS Console に到達できています。

![Raspberry Pi 上のブラウザで AWS Console を表示](/images/aws-console-private-access-soracom-vpg-canal/08-raspberry-pi-browser-aws-console.png)

## 動作確認

まずは Raspberry Pi 上のブラウザで AWS Console のサインイン画面または Console Home が表示されることを確認します。
これをこの記事の主な成功条件にします。

必要に応じて、Raspberry Pi のローカル端末で DNS と HTTPS の向き先も確認します。

### CLI で DNS と HTTPS の到達性を確認する場合

`dig` が入っていれば、Resolver inbound endpoint を明示して確認します。

```bash
dig @10.64.1.205 console.aws.amazon.com A +short
dig @10.64.1.205 signin.aws.amazon.com A +short
```

期待する例です。

```text
10.64.1.148
10.64.2.127
```

```text
10.64.1.232
10.64.2.93
```

HTTPS も確認します。

```bash
curl --connect-timeout 3 --max-time 8 \
  -o /dev/null \
  -w "console code=%{http_code} ip=%{remote_ip}\n" \
  "https://console.aws.amazon.com/console/home?region=ap-northeast-1"
```

確認例です。

```text
console code=200 ip=10.64.1.148
```

リージョナルな Console URL も確認できます。

```bash
curl --connect-timeout 3 --max-time 8 \
  -o /dev/null \
  -w "regional_console code=%{http_code} ip=%{remote_ip}\n" \
  "https://ap-northeast-1.console.aws.amazon.com/console/home?region=ap-northeast-1"
```

確認例です。

```text
regional_console code=200 ip=10.64.2.127
```

最後に、VPG のインターネットゲートウェイを使っていないことを簡単に確認します。
たとえば public IP への TCP 接続が失敗することを見ます。

```bash
curl --connect-timeout 3 --max-time 8 https://1.1.1.1/
```

VPG のインターネットゲートウェイが OFF で、他のインターネット経路もない状態なら timeout します。

```text
curl: (28) Connection timed out
```

この確認はあくまで簡易チェックです。
本番では route table、VPG 設定、AWS VPC Flow Logs、端末側の default route などを組み合わせて確認してください。

補足として、AWS 側のセキュリティ制御は AWS Management Console Private Access の公式ドキュメントも確認してください。

https://docs.aws.amazon.com/awsconsolehelpdocs/latest/gsg/console-private-access.html

## まとめ

SORACOM Air の Raspberry Pi から、VPG Type-F、SORACOM Canal、Route 53 Resolver inbound endpoint、AWS Console Private Access の VPC endpoint を組み合わせることで、AWS Management Console に閉域アクセスできました。

ポイントは次の 3 つです。

- VPG のインターネットゲートウェイを OFF にしても、Canal 経由で AWS VPC には到達できる
- AWS Console の名前解決を Route 53 Resolver inbound endpoint に向ける
- AWS Console 関連の DNS 名が VPC endpoint の private IP に解決される状態で、Raspberry Pi 上のブラウザからアクセスする

この構成は、現場端末や閉域運用端末から AWS Console を使う必要がある場合の選択肢になります。

## 参考

- [AWS Management Console Private Access now works without internet connectivity](https://aws.amazon.com/jp/about-aws/whats-new/2026/06/aws-management-console-private/)
- [AWS Management Console Private Access](https://docs.aws.amazon.com/awsconsolehelpdocs/latest/gsg/console-private-access.html)
- [Required VPC endpoints and DNS configuration](https://docs.aws.amazon.com/awsconsolehelpdocs/latest/gsg/required-endpoints-dns-configuration.html)
- [Virtual Private Gateway（VPG）を作成する](https://users.soracom.io/ja-jp/docs/vpg/create-vpg/)
- [SORACOM Canal の VPC ピアリング接続を使用して AWS と接続する](https://users.soracom.io/ja-jp/docs/canal/peering/)
- [IoT SIM のカスタム DNS を設定する](https://users.soracom.io/ja-jp/docs/air/configure-custom-dns/)
