---
title: "SORACOM Arc + Canal + VPG + Route 53 PHZでカスタムDNS"
emoji: "🔗"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["soracom", "IoT","route53","openwrt","dnsmasq"]
published: true
---
:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## tl;dr

- 既存: Air(JP)+JP VPG+Canal+PHZ で FQDN 到達可
- 追加: Air(Global) 端末は Arc+WireGuard で JP VPG に参加
- 名前解決の要: WireGuard IF に PHZ Resolver を注入（RasPi=wg-quick/resolvconf、OpenWrt(teltonika RUT240)=dnsmasq）
- OpenWrt(teltonika RUT240)の注意: dnsmasq の Rebind 防御でプライベート回答が落ちる -> reject を無効化する必要あり
- これで グローバルカバレッジ端末でも既存 FQDN（PHZ）で日本 VPC のサーバーに到達できる


## やりたいこと

日本カバレッジのSORACOM Air の回線を用いてSORACOM Canal 経由で AWS VPC 内のアプリケーションへ FQDN 通信している既存構成に、グローバルカバレッジのIoT デバイス（またはSORACOM以外の回線のIoT デバイス）を追加し、同じく FQDN 通信を実現したい。
結論として構成としては以下のようになる
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1761958942764.png)

今回のブログでは以下に詳述する既存構成を構築済みであり、この構成に対して新たにグローバルカバレッジのIoT デバイス（またはSORACOM以外の回線のIoT デバイス）を追加する形となる。
- 既存構成の詳細
  - Serve managed DNS to SORACOM Air（Route 53 Private Hosted Zone（PHZ）と Resolver Inbound を用いた FQDN 通信）
https://dev.classmethod.jp/articles/serve-managed-dns-to-soracom-air/
↑ takiponeパイセンの記事（不朽の名作）だYO!！

このときのIoTデバイス側の設定に関する注意点やポイントを解説する。

## 課題

本当は以下の図のようにグローバルカバレッジのSORACOM Air 回線から直接 日本カバレッジのVPGに 通信ができれば理想的であるのですが、SORACOMのカバレッジを跨いだVPG接続はサポートされていないため、直接の接続はできません。
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1761962152425.png)

そのためグローバルカバレッジのSORACOM Air 回線をインターネットに接続するための土管として利用し、その上にSORACOM Arc のWireGuard トンネルを構築して日本カバレッジのVPGに接続する形で、閉域通信を実現します。

ということで、経路をもう少し詳しく書くと以下のようになります。
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1761962575245.png)

普通のSORACOM Canalを使った閉域ネットワーク構築する場合であればこれで完結するのですが、Route 53 Private Hosted Zone (PHZ) を用いた FQDN 通信を実現するためには、さらにDNS解決のためのIoTデバイス側での対応が必要となります。

## STEP0. 既存構成のおさらい

AWS側の構成と設定を確認していきます。
下記の設定がきちんとされているか確認しましょう。
うまくいかない場合は下記の2つの記事をもう一度確認してください。

https://users.soracom.io/ja-jp/docs/canal/peering/
https://dev.classmethod.jp/articles/serve-managed-dns-to-soracom-air/

### AWS 側構成サマリー

先程の構成図に具体的なIPアドレス、レンジを入れたものが以下になります。
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762000169637.png)


VPC設定
| 項目 | 値 |ホストゾーン/レコード |
|---|---|---|
| **VPC CIDR** | 10.0.0.0/16 | takao.ramen |
| **EC2 プライベートIP** | 10.0.15.169 | app.takao.ramen |



ルートテーブル
| 宛先 (Destination) | ターゲット (Target) | 備考 |
|---|---|---|
| 10.0.0.0/16 | local | VPC 内ローカル |
| SORACOM VPG の CIDR<br>(100.64.0.0/10の一部) | VPC Peering 接続（Canal） | 閉域（Canal）経路 |

EC2向けセキュリティグループ（インバウンド）
| プロトコル | ポート | 許可元 (Source) | 用途 |
|---|---|---|---|
| ICMP | - | 必要範囲（例: VPGレンジ） | 疎通確認（ping 等） |
| TCP | 22 | 必要範囲（例: VPGレンジ） | SSH |
| TCP | 443 | 必要範囲（例: クライアント/VPGレンジ） | HTTPS ssm agent 等 |
| （その他） | 必要ポート | 必要範囲 | デバイス→サーバーの想定通信に合わせて開放 |

リゾルバエンドポイント向けセキュリティグループ（インバウンド）
| プロトコル | ポート | 許可元 (Source) | 用途 |
|---|---|---|---|
| TCP | 53 | 必要範囲（例: VPC 内/Resolver/必要クライアント） | DNS over TCP |
| UDP | 53 | 必要範囲（例: VPC 内/Resolver/必要クライアント） | DNS over UDP |

セキュリティグループ（アウトバウンド）
| プロトコル | ポート | 宛先 (Destination) | 用途 |
|---|---|---|---|
| All | All | 0.0.0.0/0 | すべて許可 |

ゾーン概要
| 項目 | 値 |
|---|---|
| ゾーン名 | takao.ramen |
| 種別 | Private Hosted Zone |
| VPC 関連付け | Canalの接続先VPC|
| Resolver Inbound Endpoint IP <br> (SORACOM Air のカスタムDNSに設定する値) | 10.0.6.215 / 10.0.9.201 |

ユーザーが管理するレコード（必要最小限）
| レコード名 | 種別 | 値（IP/DNS） | TTL（秒） | ルーティングポリシー | エイリアス |
|---|---|---|---:|---|---|
| app.takao.ramen | A | 10.0.15.169 | 任意（例: 300） | シンプル | いいえ |

## STEP1. 接続確認

まずは既存のSORACOM Air + Canal + VPC Peering + Route53 PHZ の構成が正しく動作しているか確認します。
今回はRaspberry Pi + Onyx にJPカバレッジのSORACOM Air を挿して確認します。

Raspberry PiにSSHでログインし、インターフェース情報を確認します。

```bash
ip addr
```

レスポンスから、`wwan0` インターフェースがSORACOM Air のセルラーインターフェースであることを確認します。

レスポンス例
```bash
pi@raspberrypi1:~ $ ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: eth0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether dc:a6:32:c5:ed:a8 brd ff:ff:ff:ff:ff:ff
4: wlan0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether dc:a6:32:c5:ed:a9 brd ff:ff:ff:ff:ff:ff
8: wwan0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 1000
    link/none 
    inet 192.168.222.244/29 brd 192.168.222.247 scope global noprefixroute wwan0
       valid_lft forever preferred_lft forever
```

wwan0 インターフェースに192.168.222.244が割り当てられていることがわかります。

ユーザーコンソールの表示とも一致しています。
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762002878061.png)

グループ設定でカスタムDNSにResolver InboundのIPアドレスが設定されていることを確認します。
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762002920386.png)

この状態でRaspberry PiからRoute53 PHZのFQDNに対して名前解決と疎通確認を行います。

```bash
ping -c 4 app.takao.ramen
```

レスポンス例
```
pi@raspberrypi1:~ $ ping -c 4 app.takao.ramen
PING app.takao.ramen (10.0.15.169) 56(84) bytes of data.
64 bytes from ip-10-0-15-169.ap-northeast-1.compute.internal (10.0.15.169): icmp_seq=1 ttl=126 time=40.6 ms
64 bytes from ip-10-0-15-169.ap-northeast-1.compute.internal (10.0.15.169): icmp_seq=2 ttl=126 time=34.9 ms
64 bytes from ip-10-0-15-169.ap-northeast-1.compute.internal (10.0.15.169): icmp_seq=3 ttl=126 time=33.9 ms
64 bytes from ip-10-0-15-169.ap-northeast-1.compute.internal (10.0.15.169): icmp_seq=4 ttl=126 time=32.4 ms

--- app.takao.ramen ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3003ms
rtt min/avg/max/mdev = 32.421/35.436/40.557/3.086 ms
pi@raspberrypi1:~ $ 
```

ちゃんと返ってきました。
念の為Raspberry PiのDNS周りの状況を確認します。


```bash
cat /etc/resolv.conf
```

レスポンス例
```
pi@raspberrypi1:~ $ cat /etc/resolv.conf
# Dynamic resolv.conf(5) file for glibc resolver(3) generated by resolvconf(8)
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
nameserver 10.0.6.215
nameserver 10.0.9.201
```
カスタムDNSに設定したResolver InboundのIPアドレスが設定されていることがわかります。

ヘッダにもあるようにこの設定はresolvconfコマンドによって自動生成されているようです。

resolvconfがどのようにしてDNSの状態を取得したかを見てみます。

```bash
sudo resolvconf -l
```

レスポンス例
```
pi@raspberrypi1:~ $ sudo resolvconf -l
# resolv.conf from NetworkManager
nameserver 10.0.6.215
nameserver 10.0.9.201
```
NetworkManager 経由で取得していることがわかります。

NetworkManager で確認します。

```bash
nmcli dev show | grep DNS
```

レスポンス例
```
pi@raspberrypi1:~ $ nmcli dev show | grep DNS
IP4.DNS[1]:                             10.0.6.215
IP4.DNS[2]:                             10.0.9.201
```

DNSにResolver InboundのIPアドレスが設定されていることがわかります。
この構成は`/etc/resolvconf/update.d/libc`内のスクリプトによって実現されているようです。
詳細は割愛しますが、システム内の様々なソースからDNS情報を収集し、`resolv.conf` を動的に生成する仕組みのようです。


## STEP2. グローバルカバレッジのSORACOM Air 回線での接続確認
ここまでは普通のSORACOM Air + Canal + VPC Peering + Route53 PHZ の構成での接続確認でした。
takiponeパイセンのブログの記事のトレースになります。

ここからはグローバルカバレッジのSORACOM Air 回線の上にSORACOM Arc を用いてWireGuard トンネルを構築し、日本カバレッジのVPGに接続する形で同じことができるか確認していきます。

まずはRaspberry Pi にグローバルカバレッジの IoT SIM を挿し、通信が確立している状態を確認します。

```bash
ip addr show
```

レスポンス例
```
pi@raspberrypi1:~ $ ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: eth0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether dc:a6:32:c5:ed:a8 brd ff:ff:ff:ff:ff:ff
4: wlan0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether dc:a6:32:c5:ed:a9 brd ff:ff:ff:ff:ff:ff
10: wwan0: <BROADCAST,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 1000
    link/ether be:a4:e4:33:b9:03 brd ff:ff:ff:ff:ff:ff
    inet 10.249.245.52/29 brd 10.249.245.55 scope global noprefixroute wwan0
       valid_lft forever preferred_lft forever
pi@raspberrypi1:~ $ 
```

今度は、別のIPアドレス 10.249.245.52 が割り当てられていることがわかります。

ユーザーコンソールの表示とも一致しています。
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762005920414.png)

続いて、この状態でインターネットに接続できるか確認します。

```bash
ping -c 4 google.com
```

レスポンス例
```
pi@raspberrypi1:~ $ ping -c 4 google.com
PING google.com (216.58.220.142) 56(84) bytes of data.
64 bytes from syd09s01-in-f142.1e100.net (216.58.220.142): icmp_seq=1 ttl=113 time=42.7 ms
64 bytes from syd09s01-in-f142.1e100.net (216.58.220.142): icmp_seq=2 ttl=113 time=35.8 ms
64 bytes from syd09s01-in-f142.1e100.net (216.58.220.142): icmp_seq=3 ttl=113 time=39.9 ms
64 bytes from syd09s01-in-f142.1e100.net (216.58.220.142): icmp_seq=4 ttl=113 time=33.8 ms

--- google.com ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3003ms
rtt min/avg/max/mdev = 33.808/38.052/42.681/3.458 ms
pi@raspberrypi1:~ $ 
```

ちゃんと接続できました。

この状態ではまだ日本カバレッジのVPGやその先のCanal、VPCには接続できません。
この状態で、デバイスのDNS設定を確認します。

```bash
cat /etc/resolv.conf
```

レスポンス例
```
pi@raspberrypi1:~ $ cat /etc/resolv.conf
# Dynamic resolv.conf(5) file for glibc resolver(3) generated by resolvconf(8)
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
nameserver 100.127.0.53
nameserver 100.127.1.53
pi@raspberrypi1:~ $ 
```
`100.127.0.53` と `100.127.1.53` です。この２つがSORACOM Air グローバルカバレッジのDNSサーバーのIPアドレスであることは公式ドキュメントにも記載があります。
https://users.soracom.io/ja-jp/docs/air/endpoints/

ここからSORACOM Air日本カバレッジに対してSORACOM ArcのWireGuard トンネルを構築し、VPGに接続する設定を行っていきます。

ユーザーコンソールからWireguardの設定（バーチャルSIM）を発行します。
設定内容をRaspberry Piに書き込み、`/etc/wireguard/wg0.conf` に保存します。
このとき AllowedIPs に今回の場合のVPCのCIDR`10.0.0.0/16`を追記します。
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762006851148.png)

この状態でwireguardを起動します。

```bash
wg-quick up wg0
```

レスポンス例
```
pi@raspberrypi1:~ $ wg-quick up wg0
[#] ip link add wg0 type wireguard
[#] wg setconf wg0 /dev/fd/63
[#] ip -4 address add 192.168.47.77/32 dev wg0
[#] ip link set mtu 1420 up dev wg0
[#] ip -4 route add 54.250.252.67/32 dev wg0
[#] ip -4 route add 100.127.10.17/32 dev wg0
[#] ip -4 route add 100.127.10.18/31 dev wg0
[#] ip -4 route add 100.127.10.20/30 dev wg0
[#] ip -4 route add 100.127.10.24/29 dev wg0
[#] ip -4 route add 100.127.10.0/28 dev wg0
[#] ip -4 route add 100.127.10.32/27 dev wg0
[#] ip -4 route add 100.127.10.64/26 dev wg0
[#] ip -4 route add 100.127.10.128/25 dev wg0
[#] ip -4 route add 100.127.11.0/24 dev wg0
[#] ip -4 route add 100.127.8.0/23 dev wg0
[#] ip -4 route add 100.127.12.0/22 dev wg0
[#] ip -4 route add 100.127.0.0/21 dev wg0
[#] ip -4 route add 100.127.16.0/20 dev wg0
[#] ip -4 route add 100.127.32.0/19 dev wg0
[#] ip -4 route add 100.127.64.0/18 dev wg0
[#] ip -4 route add 100.127.128.0/17 dev wg0
[#] ip -4 route add 10.0.0.0/16 dev wg0
pi@raspberrypi1:~ $ 
```
正しくwireguardのトンネルインターフェースをupできたようです。
この状態でCanal経由でVPCに接続しているはずです。
それではいきなり、Route53 PHZのFQDNに対して名前解決と疎通確認を行ってみます。

```bash
ping -c 4 app.takao.ramen
```

レスポンス例
```
pi@raspberrypi1:~ $ ping -c 4 app.takao.ramen
ping: app.takao.ramen: Name or service not known
pi@raspberrypi1:~ $ 
```

あれ、通りませんね。

FQDNではなくIPアドレス直接で疎通確認を行ってみます。

```bash
ping -c 4 10.0.15.169
```

レスポンス例
```
pi@raspberrypi1:~ $ ping -c 4 10.0.15.169
PING 10.0.15.169 (10.0.15.169) 56(84) bytes of data.
64 bytes from 10.0.15.169: icmp_seq=1 ttl=126 time=40.8 ms
64 bytes from 10.0.15.169: icmp_seq=2 ttl=126 time=36.5 ms
64 bytes from 10.0.15.169: icmp_seq=3 ttl=126 time=52.9 ms
64 bytes from 10.0.15.169: icmp_seq=4 ttl=126 time=47.0 ms

--- 10.0.15.169 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 36.520/44.290/52.894/6.207 ms
pi@raspberrypi1:~ $ 
```
これは通りました。

つまり、DNS解決がうまくいっていないことがわかります。
デバイスのDNS設定を再度確認します。

```bash
cat /etc/resolv.conf
```

レスポンス例
```
pi@raspberrypi1:~ $ cat /etc/resolv.conf
# Dynamic resolv.conf(5) file for glibc resolver(3) generated by resolvconf(8)
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
nameserver 100.127.0.53
nameserver 100.127.1.53
pi@raspberrypi1:~ $ 
```
先程のまま変わっていません。
WireGuard トンネル経由でVPC内のResolver Inbound に名前解決を投げる設定になっていないため、解けないようです。

なんとかしてWireGuard トンネル経由でResolver Inbound に名前解決を投げるように設定を変更する必要があります。

ここで早まってwwan0 インターフェースのDNS設定を書き換えても意味がありません。それをやってしまうとインターネットの名前解決もできなくなってしまい、SORACOM Arcで利用するWireguardのトンネル確立に必要な`link.arc.soracom.io` の名前解決もできなくなってしまいます。
(globalカバレッジのSORACOM Air 回線からRoute53のDNSサーバーに直接問い合わせることはできないため。あくまで、wireguardトンネル経由でResolver Inboundに問い合わせる必要があります。)



対処方針としては、wireguardインターフェース `wg0` にResolver InboundのIPアドレスをDNSサーバーとして設定し、さらにRoute53 PHZのドメインを `wg0` インターフェースにバインドする設定を行います。
先程のWireGuardの設定ファイル `/etc/wireguard/wg0.conf` に以下を追記します。

[Interface] セクションに以下を追加します。
```ini
DNS = 10.0.6.215,10.0.9.201
```
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762073285602.png)

新しい設定でWireGuard トンネルを再起動します。

```bash
wg-quick down wg0
wg-quick up wg0
```

レスポンス例
```
pi@raspberrypi1:~ $ wg-quick down wg0
[#] ip link delete dev wg0
[#] resolvconf -d tun.wg0 -f
pi@raspberrypi1:~ $ wg-quick up wg0
[#] ip link add wg0 type wireguard
[#] wg setconf wg0 /dev/fd/63
[#] ip -4 address add 192.168.47.77/32 dev wg0
[#] ip link set mtu 1420 up dev wg0
[#] resolvconf -a tun.wg0 -m 0 -x
[#] ip -4 route add 54.250.252.67/32 dev wg0
[#] ip -4 route add 100.127.10.17/32 dev wg0
[#] ip -4 route add 100.127.10.18/31 dev wg0
[#] ip -4 route add 100.127.10.20/30 dev wg0
[#] ip -4 route add 100.127.10.24/29 dev wg0
[#] ip -4 route add 100.127.10.0/28 dev wg0
[#] ip -4 route add 100.127.10.32/27 dev wg0
[#] ip -4 route add 100.127.10.64/26 dev wg0
[#] ip -4 route add 100.127.10.128/25 dev wg0
[#] ip -4 route add 100.127.11.0/24 dev wg0
[#] ip -4 route add 100.127.8.0/23 dev wg0
[#] ip -4 route add 100.127.12.0/22 dev wg0
[#] ip -4 route add 100.127.0.0/21 dev wg0
[#] ip -4 route add 100.127.16.0/20 dev wg0
[#] ip -4 route add 100.127.32.0/19 dev wg0
[#] ip -4 route add 100.127.64.0/18 dev wg0
[#] ip -4 route add 100.127.128.0/17 dev wg0
[#] ip -4 route add 10.0.0.0/16 dev wg0
```


コマンドの出力を比べると、
`[#] resolvconf -a tun.wg0 -m 0 -x`
という出力が追加されています。

VPCへの名前解決と疎通確認を試してみます。

```bash
ping -c 4 app.takao.ramen
```

レスポンス例
```
pi@raspberrypi1:~ $ ping -c 4 app.takao.ramen
PING app.takao.ramen (10.0.15.169) 56(84) bytes of data.
64 bytes from ip-10-0-15-169.ap-northeast-1.compute.internal (10.0.15.169): icmp_seq=1 ttl=126 time=38.7 ms
64 bytes from ip-10-0-15-169.ap-northeast-1.compute.internal (10.0.15.169): icmp_seq=2 ttl=126 time=42.6 ms
64 bytes from ip-10-0-15-169.ap-northeast-1.compute.internal (10.0.15.169): icmp_seq=3 ttl=126 time=55.9 ms
64 bytes from ip-10-0-15-169.ap-northeast-1.compute.internal (10.0.15.169): icmp_seq=4 ttl=126 time=39.3 ms

--- app.takao.ramen ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 38.675/44.117/55.876/6.949 ms
```

今度は通りました。


この状態で、`resolv.conf` の内容を確認します。

```bash
cat /etc/resolv.conf
```


レスポンス例
```
pi@raspberrypi1:~ $ cat /etc/resolv.conf
# Dynamic resolv.conf(5) file for glibc resolver(3) generated by resolvconf(8)
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
nameserver 10.0.6.215
nameserver 10.0.9.201
nameserver 100.127.0.53
```
nameserver に Resolver Inbound のIPアドレスが追加されていることがわかります。

先ほどと同様に `resolvconf -l` コマンドで情報源を確認します。

```bash
sudo resolvconf -l
```
レスポンス例
```
pi@raspberrypi1:~ $ sudo resolvconf -l
# resolv.conf from tun.wg0
nameserver 10.0.6.215
nameserver 10.0.9.201
# resolv.conf from NetworkManager
nameserver 100.127.0.53
nameserver 100.127.1.53
```
`tun.wg0` インターフェースから Resolver Inbound のIPアドレスが取得されていることがわかります。
/etc/resolv.conf にはnameserver 100.127.1.53が入っていませんでした。
これはresolvconfが、3つ以上のnameserverを/etc/resolv.confに書き込まないようにしているためです。
これでグローバルカバレッジのSORACOM Air 回線でSORACOM Arc を用いてWireGuard トンネルを構築し、日本カバレッジのVPGに接続する形でRoute53 PHZ のFQDN に対して名前解決と疎通確認ができることがわかりました。


## STEP3. Teltonika RUT240（OpenWrt系）での動作確認

Raspberry PiのようにNetworkManager + resolvconf の構成であれば、WireGuard トンネルインターフェースにDNSサーバーを設定するだけで、Route53 PHZ のFQDN に対して名前解決と疎通確認ができるようになることがわかりました。
他のルーターではどうなるでしょうか？
今回はTeltonika RUT240 を用いて確認してみます。
こちらはOpenWrt ベースのルーターです。BusyBox シェルをベースにしており、DNS 解決は dnsmasq が担います。

ひとまずSIMを入れて、設定を確認します。
IMSI,ICCIDやSORACOM Air のIPアドレスがユーザーコンソールの表示と一致していることを確認します。
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762080622936.png)
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762080604677.png)

![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762080682400.png)

この状態でSSHでログインし、内部のDNSに関連する設定を確認します。

```bash
cat /etc/resolv.conf
```

レスポンス例
```
root@RUT240:~# cat /etc/resolv.conf
search lan
nameserver 127.0.0.1
nameserver ::1
root@RUT240:~# 
```
これは、ルーター自身が 127.0.0.1 (dnsmasq) を DNS リゾルバとして動作していることを示しています。
DNSサーバーは別ファイルでdnsmasqに設定されているはずです。

```bash
cat /var/etc/dnsmasq.conf.*
```

レスポンス例
```
root@RUT240:~# cat /var/etc/dnsmasq.conf.*
# auto-generated config file from /etc/config/dhcp
conf-file=/etc/dnsmasq.conf
dhcp-authoritative
domain-needed
localise-queries
read-ethers
enable-ubus=dnsmasq
expand-hosts
bind-dynamic
edns-packet-max=1232
domain=lan
local=/lan/
addn-hosts=/tmp/hosts
dhcp-leasefile=/tmp/dhcp.leases
dhcp-script=/usr/lib/dnsmasq/dhcp-script.sh
script-arp
resolv-file=/tmp/resolv.conf.d/resolv.conf.auto
stop-dns-rebind
rebind-localhost-ok
dhcp-broadcast=tag:needs-broadcast
conf-dir=/tmp/dnsmasq.d
user=dnsmasq
group=dnsmasq


dhcp-ignore-names=tag:dhcp_bogus_hostname
conf-file=/usr/share/dnsmasq/dhcpbogushostname.conf


bogus-priv
conf-file=/usr/share/dnsmasq/rfc6761.conf
dhcp-range=set:lan,192.168.150.100,192.168.150.254,255.255.255.0,12h





root@RUT240:~# 
```
`resolv-file=/tmp/resolv.conf.d/resolv.conf.auto` という行がポイントです。
dnsmasq は `/tmp/resolv.conf.d/resolv.conf.auto` に記載されているDNSサーバーを用いて名前解決を行うようです。

```bash
cat /tmp/resolv.conf.d/resolv.conf.auto
```

レスポンス例：
```
root@RUT240:~# cat /tmp/resolv.conf.d/resolv.conf.auto
# Interface mob1s1a1_4
nameserver 100.127.0.53
nameserver 100.127.1.53
root@RUT240:~# 
```
SORACOM Air グローバルカバレッジのDNSサーバーが設定されていることを示しています。
つまり、SORACOM Air のPDPコンテキストから配布されたDNS設定が
OpenWrtの dnsmasq によって正しく反映されています。

nslookup コマンドで SORACOM Beam のドメインを解決してみます。

```bash
nslookup beam.soracom.io
```

レスポンス例
```
root@RUT240:~# nslookup beam.soracom.io
Server:         127.0.0.1
Address:        127.0.0.1#53

Name:      beam.soracom.io
Address 1: 100.127.127.100
*** Can't find beam.soracom.io: No answer
root@RUT240:~# 
```
ちゃんと解決できました。
`*** Can't find beam.soracom.io: No answer` は一見エラーのように見えますが、 IPv6（AAAAレコード）の問い合わせが応答しなかっただけであり、IPv4(Aレコード)の解決は成功しています。

IPv4 のみを指定して確認すると、正常応答となります。
```
root@RUT240:~# nslookup -query=A beam.soracom.io
Server:         127.0.0.1
Address:        127.0.0.1#53

Non-authoritative answer:
Name:   beam.soracom.io
Address: 100.127.127.100

root@RUT240:~# 
```
ここまではSORACOM Air グローバルカバレッジ環境での正しい応答です。

ここまでのまとめです。

| レイヤ                                   | ファイル/設定                                | 役割                                  |
| ------------------------------------- | -------------------------------------- | ----------------------------------- |
| `/etc/resolv.conf`                    | nameserver 127.0.0.1                   | ルータ自身の問い合わせをdnsmasqへ転送              |
| `/tmp/resolv.conf.d/resolv.conf.auto` | nameserver 100.127.0.53 / 100.127.1.53 | 上流DNS（SORACOM Airから配布）              |
| `/var/etc/dnsmasq.conf.*`             | resolv-file設定で上記を参照                    | dnsmasq が上流へ転送                      |
| `dnsmasq` プロセス                        | UDP:53 リスナー                            | LANクライアントおよびルータ自身のDNS問い合わせを中継・キャッシュ |


それではここからWireGuard トンネルインターフェース `soracom` にResolver InboundのIPアドレスをDNSサーバーとして設定し、さらにRoute53 PHZのドメインを `soracom` インターフェースにバインドする設定を行います。

:::message
RUT240 では GUI で付けた名前（ここでは soracom）が WireGuard IF 名になります
:::

まずはWireGuard トンネルインターフェースの設定をします。

GUIで、「Services」→「VPN」→「WireGuard」を開きます。
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762081279087.png)

![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762081301702.png)

「Add new instance」に名前を入力して、「Add」をクリックします。
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762081407337.png)

GeneralSetupで
以下を設定します。
- Private Key: ユーザーコンソールで発行したWireGuard設定の
- IP Address: VPGに接続するために設定したIPアドレス
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762084588699.png)

また、Peersには以下を設定します。
- General Setup
  - Public Key: ユーザーコンソールで発行したWireGuard設定の
  - Endpoint host: ユーザーコンソールで発行したWireGuard設定のEndpoint
  - Allowed IPs: ユーザーコンソールで発行したWireGuard設定のAllowedIPsにVPCのCIDRを追加したもの
  - Route allowed IPs: ONに設定
- Advanced Settings
  - Endpoint Port: ユーザーコンソールで発行したWireGuard設定のPort
  - Persistent Keepalive: 25に設定
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762084633280.png)
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762084738917.png)

SSHでルーターにログインし、WireGuard トンネルインターフェースの疎通を確認します。

```
wg show
```

レスポンス例
```
root@RUT240:~# wg show
interface: soracom
  public key: xW+26plW2oibT852MKeUW7UKHCBwYRmbbNphJSQtoTA=
  private key: (hidden)
  listening port: 51820

peer: vqJbLlnMb57k9Vrs3jqdwNaYKGQ1jUUGUyT2ex8F8Wc=
  endpoint: 35.75.26.187:11010
  allowed ips: 100.127.0.0/21, 100.127.10.0/28, 100.127.10.128/25, 100.127.10.17/32, 100.127.10.18/31, 100.127.10.20/30, 100.127.10.24/29, 100.127.10.32/27, 100.127.10.64/26, 100.127.11.0/24, 100.127.12.0/22, 100.127.128.0/17, 100.127.16.0/20, 100.127.32.0/19, 100.127.64.0/18, 100.127.8.0/23, 54.250.252.67/32, 10.0.0.0/16
  latest handshake: 24 seconds ago
  transfer: 1.18 KiB received, 3.21 KiB sent
  persistent keepalive: every 25 seconds
root@RUT240:~# 

`wg show`コマンド出力結果の確認ポイント表にまとめると以下のようになります。
所望のインターフェースの、peer endpointが正しいこと、トンネルが確立していること、通信が発生していること、VPCまでのルートが通っていることを確認します。
```
| 項目               | 値                              | 判定                          |
| ---------------- | ------------------------------ | --------------------------- |
| インターフェース名        | `soracom`                      | OK                          |
| peer endpoint    | `35.75.26.187:11010`           | SORACOM Arc (日本リージョン) 側で正しい |
| latest handshake | 24 seconds ago       | トンネル確立中（定期keepaliveも動作中） |
| transfer         | 1.18 KiB received, 3.21 KiB sent      | 通信あり（往復できている）               |
| allowed ips      | 各種 100.127.x.x + `10.0.0.0/16` | 日本側VPCまでルート通過OK             |


日本側のVPC内EC2インスタンス（例：10.0.15.169）にIPアドレス直でPingしてみましょう。

```bash
ping -c 3 10.0.15.169
```

レスポンス例
```
root@RUT240:~# ping -c 3 10.0.15.169
PING 10.0.15.169 (10.0.15.169): 56 data bytes
64 bytes from 10.0.15.169: seq=0 ttl=126 time=49.969 ms
64 bytes from 10.0.15.169: seq=1 ttl=126 time=38.970 ms
64 bytes from 10.0.15.169: seq=2 ttl=126 time=48.622 ms

--- 10.0.15.169 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 38.970/45.853/49.969 ms
root@RUT240:~# 
```
ちゃんと通りました。

先程のRaspberry Piのときと同様にこの時点で一度Route53 PHZのFQDNに対して名前解決と疎通確認を行ってみます。

```bash
ping -c 4 app.takao.ramen
```

レスポンス例
```
root@RUT240:~# ping -c 4 app.takao.ramen
ping: bad address 'app.takao.ramen'
root@RUT240:~# 
```
あれ、通りませんね。
まだWireGuardのDNS設定をしていないためでした。

もう一度、webUIに戻り「Services」→「VPN」→「WireGuard」を開き、「WireGuard Configuration」で先程作成したWireGuard インターフェースの「Advanced Settings」タブを開きます。
DNS Servers に Resolver Inbound のIPアドレスを設定します。
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762086416912.png)

「Save & Apply」をクリックして保存します。

次の画面でも Save & Applyをクリックして設定を適用します。

SSHに戻り、FQDNでの疎通確認を行います。

```bash
ping -c 4 app.takao.ramen
```

レスポンス例
```
root@RUT240:~# ping -c 4 app.takao.ramen
ping: bad address 'app.takao.ramen'
root@RUT240:~# 
```

あれ、まだ通りませんね。
DNS設定を確認してみます。

```bash
cat /tmp/resolv.conf.d/resolv.conf.auto
```


レスポンス例
```
root@RUT240:~# cat /tmp/resolv.conf.d/resolv.conf.auto
# Interface soracom
nameserver 10.0.6.215
nameserver 10.0.9.201
# Interface mob1s1a1_4
nameserver 100.127.0.53
nameserver 100.127.1.53
root@RUT240:~# 
```

Interface soracomというのがWireGuard トンネルインターフェースです。
Resolver Inbound のIPアドレスが設定されていることがわかります。

これで名前解決ができるはずですが、できていません。
一度WireGuard トンネルインターフェースを再起動してみます。

GUIからon -> off -> on と切り替えます。

SSHに戻り、FQDNでの疎通確認を行います。

```bash
ping -c 4 app.takao.ramen
```

レスポンス例
```
root@RUT240:~# ping -c 4 app.takao.ramen
ping: bad address 'app.takao.ramen'
```

ダメでした。なぜでしょう。
nslookup コマンドで詳細を確認してみます。

```bash
nslookup app.takao.ramen
```

レスポンス例：
```
root@RUT240:~# nslookup app.takao.ramen
Server:         127.0.0.1
Address:        127.0.0.1#53

** server can't find app.takao.ramen: NXDOMAIN
** server can't find app.takao.ramen: NXDOMAIN
```

しょっぱい結果ですね。

次に、nslookup コマンドでWireGuard 先の Resolver（Route 53 Resolver inbound）へ直接問い合わせます。
```
# 片方だけでもOK
nslookup app.takao.ramen 10.0.6.215
nslookup app.takao.ramen 10.0.9.201
```

レスポンス例：
```
root@RUT240:~# nslookup app.takao.ramen 10.0.6.215
Server:         10.0.6.215
Address:        10.0.6.215#53

Name:      app.takao.ramen
Address 1: 10.0.15.169
*** Can't find app.takao.ramen: No answer
root@RUT240:~# nslookup app.takao.ramen 10.0.9.201
Server:         10.0.9.201
Address:        10.0.9.201#53

Name:      app.takao.ramen
Address 1: 10.0.15.169
*** Can't find app.takao.ramen: No answer
```

例によって、エラーが出ていますがこれはAAAAレコードの問い合わせが応答しなかっただけであり、IPv4(Aレコード)の解決は成功しています。

ローカルdnsmasq経由だと解決ができないことを直接的に確認します。

```bash
nslookup app.takao.ramen 127.0.0.1
```

レスポンス例：
```
root@RUT240:~# nslookup app.takao.ramen 127.0.0.1
Server:         127.0.0.1
Address:        127.0.0.1#53

** server can't find app.takao.ramen: NXDOMAIN
** server can't find app.takao.ramen: NXDOMAIN
```

ローカルdnsmasq経由ではRoute53 PHZのFQDNを解決できていないことがわかります。
もう少しログを取って確認してみます。
まずクエリログを有効化して、リアルタイムに確認します。

```bash
# クエリログ有効化
uci set dhcp.@dnsmasq[0].logqueries='1'
# apply
uci commit dhcp 
# dnsmasq再起動
/etc/init.d/dnsmasq restart
```

レスポンス例
```
root@RUT240:~# uci set dhcp.@dnsmasq[0].logqueries='1'
root@RUT240:~# uci commit dhcp
root@RUT240:~# /etc/init.d/dnsmasq restart
udhcpc: started, v1.34.1
udhcpc: broadcasting discover
udhcpc: no lease, failing
```

この状態で、別のSSHセッションでリアルタイムログを確認します。

```bash
logread -f | grep -i dnsmasq
```

もとのSSHセッションでFQDNでの疎通確認を行います。

```bash
nslookup app.takao.ramen 127.0.0.1
```

レスポンス例
```
root@RUT240:~# nslookup app.takao.ramen 127.0.0.1
Server:         127.0.0.1
Address:        127.0.0.1#53

** server can't find app.takao.ramen: NXDOMAIN
** server can't find app.takao.ramen: NXDOMAIN
root@RUT240:~# 
```

このときの仕掛けておいたログを確認します。

ログ出力例
```
root@RUT240:~# logread -f | grep -i dnsmasq

Sun Nov  2 13:16:56 2025 daemon.info dnsmasq[29795]: 1 127.0.0.1/36257 query[A] app.takao.ramen from 127.0.0.1
Sun Nov  2 13:16:56 2025 daemon.info dnsmasq[29795]: 1 127.0.0.1/36257 forwarded app.takao.ramen to 10.0.6.215
Sun Nov  2 13:16:56 2025 daemon.info dnsmasq[29795]: 1 127.0.0.1/36257 forwarded app.takao.ramen to 10.0.9.201
Sun Nov  2 13:16:56 2025 daemon.info dnsmasq[29795]: 1 127.0.0.1/36257 forwarded app.takao.ramen to 100.127.0.53
Sun Nov  2 13:16:56 2025 daemon.info dnsmasq[29795]: 1 127.0.0.1/36257 forwarded app.takao.ramen to 100.127.1.53
Sun Nov  2 13:16:56 2025 daemon.info dnsmasq[29795]: 2 127.0.0.1/36257 query[AAAA] app.takao.ramen from 127.0.0.1
Sun Nov  2 13:16:56 2025 daemon.info dnsmasq[29795]: 2 127.0.0.1/36257 forwarded app.takao.ramen to 10.0.6.215
Sun Nov  2 13:16:56 2025 daemon.info dnsmasq[29795]: 2 127.0.0.1/36257 forwarded app.takao.ramen to 10.0.9.201
Sun Nov  2 13:16:56 2025 daemon.info dnsmasq[29795]: 2 127.0.0.1/36257 forwarded app.takao.ramen to 100.127.0.53
Sun Nov  2 13:16:56 2025 daemon.info dnsmasq[29795]: 2 127.0.0.1/36257 forwarded app.takao.ramen to 100.127.1.53
Sun Nov  2 13:16:56 2025 daemon.warn dnsmasq[29795]: possible DNS-rebind attack detected: app.takao.ramen
```

何が起こっているかと言うと、
dnsmasq が `app.takao.ramen` の問い合わせを受けると、
1. Resolver Inbound (Route 53 Resolver inbound) へ問い合わせを転送する
2. SORACOM Air グローバルカバレッジのDNSサーバーへ問い合わせを転送する
3. その後、`possible DNS-rebind attack detected: app.takao.ramen`という警告を出してNXDOMAINを返す

という流れになっています。
これは、dnsmasq のセキュリティ機能の一つである「DNS Rebind 攻撃防止機能」が働いているためです。
Route53 PHZ のFQDNはVPC内のプライベートIPアドレスに解決されますが、RUT240のdnsmasq はこれを「外部から内部ネットワークへの不正なアクセス」とみなして拒否してしまうのです。

今回はSORACOM Airというとてもセキュアな通信を、SORACOM Canalというこれまたセキュアな方法でVPCに接続しています。
したがって、dnsmasq のDNS Rebind 攻撃防止機能を無効化してこのDNSを解決できるようにします。


webUIに戻り、「Network」→「DNS」の「General Settings」タブを開きます。

Rebind protection の設定をon -> off に変更して、「Save & Apply」をクリックします。
![alt text](/images/using-soracom-with-customdns-and-vpcpeering/1762090688613.png)

この状態で、SSHに戻り、FQDNでの疎通確認を行います。

```bash
nslookup app.takao.ramen
```

レスポンス例
```
root@RUT240:~# nslookup app.takao.ramen 127.0.0.1
Server:         127.0.0.1
Address:        127.0.0.1#53

Name:      app.takao.ramen
Address 1: 10.0.15.169
*** Can't find app.takao.ramen: No answer
```

ちゃんと解決できました。
*** Can't find app.takao.ramen: No answer はいつものAAAAレコードのやつです。

念の為pingコマンドで疎通確認も行います。

```bash
ping -c 4 app.takao.ramen
```

レスポンス例
```
root@RUT240:~# ping app.takao.ramen
PING app.takao.ramen (10.0.15.169): 56 data bytes
64 bytes from 10.0.15.169: seq=0 ttl=126 time=56.448 ms
64 bytes from 10.0.15.169: seq=1 ttl=126 time=54.642 ms
64 bytes from 10.0.15.169: seq=2 ttl=126 time=53.355 ms
64 bytes from 10.0.15.169: seq=3 ttl=126 time=53.733 ms
^C
--- app.takao.ramen ping statistics ---
4 packets transmitted, 4 packets received, 0% packet loss
round-trip min/avg/max = 53.355/54.544/56.448 ms
root@RUT240:~# 
```
ちゃんと通りました。

これでRUT240でもSORACOM Arc を用いてWireGuard トンネルを構築し、日本カバレッジのVPGに接続する形でRoute53 PHZ のFQDN に対して名前解決と疎通確認ができることがわかりました。
お疲れ様でした！

