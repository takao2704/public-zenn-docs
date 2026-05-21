---
title: "Soracom Onyx 2本刺し Raspberry Pi を支える技術"
emoji: "🔌"
type: "tech"
topics: ["soracom", "raspberrypi", "networkmanager", "modemmanager", "lte"]
published: true
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## TL;DR

- Raspberry Pi に Soracom Onyx を 2 本接続する場合、単に `wwan0` / `wwan1` が見えるだけでは不十分です。
- NetworkManager が認識する `cdc-wdm0` / `cdc-wdm1` のような GSM デバイスごとに、`soracom-cdc-wdm0` / `soracom-cdc-wdm1` という接続プロファイルを分けるのがポイントです。
- 接続を上げるときは `nmcli con up <profile> ifname <device>` として、どのモデムでどのプロファイルを使うかを明示します。MBIM と QMI が混在していても、Linux カーネル、ModemManager、NetworkManager が吸収できれば、スクリプト側は `TYPE=gsm` のデバイスとして同じように扱えます。
- 今回の実機では、`wwan0` / `wwan1` の両方から `ping -I <interface> pong.soracom.io` で疎通できることを確認しました。ただし、通常の通信でどちらが使われるかはルーティングテーブルで決まります。

## はじめに

Soracom Onyx は、Quectel EG25-G を通信モジュールとして利用する LTE USB ドングルです。
Raspberry Pi に 1 本だけ接続して SORACOM Air へつなぐ場合は、通常のセットアップ手順に沿って接続プロファイルを作れば十分です。

一方で、冗長化やネットワークの使い分けのために Raspberry Pi に Onyx を 2 本接続したい場合は、考えるべきポイントが少し変わります。
単に USB ポートへ 2 本挿すだけではなく、NetworkManager が認識したそれぞれの GSM デバイスに対して、別々の接続プロファイルを作る必要があります。

この記事では、Soracom Onyx 2 本刺し構成の Raspberry Pi を実現するために作成した `dualonyxpi` というリポジトリについて、その実装の考え方と検証結果をまとめます。

https://github.com/takao2704/dualonyxpi

今回の検証では、Raspberry Pi に 2 本の Soracom Onyx を接続した構成を使いました。

![Raspberry Pi に 2 本の Soracom Onyx を接続した様子](/images/dualonyxpi-networkmanager/dual-soracom-onyx-raspberry-pi.jpg)

中心になるのは、以下の 2 点です。

- `cdc-wdm0`, `cdc-wdm1` のような NetworkManager の GSM デバイスごとに接続プロファイルを分ける
- 接続を上げるときに `nmcli con up <profile> ifname <device>` として、どのモデムに紐づけるかを明示する

この記事の主眼は、セットアップスクリプトの実装を読み解きながら技術的な要点を説明することです。
後半では、実際に 2 本の Onyx を接続した Raspberry Pi で確認した状態もあわせて載せます。

### 本記事で扱わないこと

この記事は、2 本の Onyx を Linux と NetworkManager の上で別々の GSM デバイス、別々の接続プロファイルとして扱えるようにするところに焦点を当てます。
そのため、以下は本記事では詳しく扱いません。

- Onyx / EG25-G の USB network mode を MBIM や QMI に変更する具体的な手順
- 宛先ごとに `wwan0` と `wwan1` を使い分ける policy routing
- 片方を主系、もう片方を従系として使う failover 構成
- 複数回線を束ねて帯域を広げる MPTCP や VPN bonding の構成
- 物理 USB ポートや個体識別子に基づいて、常に同じ Onyx を同じ名前で扱うための udev ルール設計

これらは 2 本の Onyx を別々の回線として認識できるようになった後の応用編です。
この記事では、その前段として「OS と NetworkManager から 2 本の Onyx がどう見えるか」「接続プロファイルをどう分けるか」を扱います。

## Onyx を USB 接続すると OS では何が起きるか

まず、Soracom Onyx を Raspberry Pi に挿したときに、なぜ `eth0` や `wlan0` と同じように `wwan0` というネットワークインターフェースが現れるのかを整理します。

今回の実験では、Raspberry Pi に少し意地悪をするために、2 本の Onyx を同じ USB network mode にはそろえませんでした。
片方の Onyx は MBIM モード、もう片方の Onyx は QMI モードにして接続しています。
つまり、Raspberry Pi から見ると「同じ Soracom Onyx が 2 本挿さっているのに、片方は MBIM、片方は QMI として見える」状態です。
MBIM と QMI の違いそのものは、[巻末のコラム](#%E3%82%B3%E3%83%A9%E3%83%A0%3A-mbim-%E3%81%A8-qmi-%E3%81%AE%E9%81%95%E3%81%84%E3%81%A8%E9%81%B8%E3%81%B3%E6%96%B9)で整理します。

Onyx の中には EG25-G というセルラーモデムが入っています。
これを USB 接続すると、OS からは「1 つの USB 機器」ではなく、複数の USB interface を持つ composite device として見えます。
この見え方は、まず `lsusb -t` で確認できます。

```bash
lsusb -t
```

今回の実機では、MBIM モードにした Onyx は次のように見えていました。
`Dev` や `Port` の番号は接続順や USB ハブの構成で変わるため、ここでは `If`、`Class`、`Driver` の対応に注目します。
`If 0-3` は `option` ドライバーに紐づく USB シリアルポート、`If 4` / `If 5` は `cdc_mbim` ドライバーに紐づくモバイルブロードバンド用の interface です。

```text
Dev 003, If 0, Class=Vendor Specific Class, Driver=option
Dev 003, If 1, Class=Vendor Specific Class, Driver=option
Dev 003, If 2, Class=Vendor Specific Class, Driver=option
Dev 003, If 3, Class=Vendor Specific Class, Driver=option
Dev 003, If 4, Class=Communications, Driver=cdc_mbim
Dev 003, If 5, Class=CDC Data, Driver=cdc_mbim
```

もう 1 本の QMI モードにした Onyx は、同じ `2c7c:0125` でも `qmi_wwan` ドライバーに紐づいていました。

```text
Dev 004, If 0, Class=Vendor Specific Class, Driver=option
Dev 004, If 1, Class=Vendor Specific Class, Driver=option
Dev 004, If 2, Class=Vendor Specific Class, Driver=option
Dev 004, If 3, Class=Vendor Specific Class, Driver=option
Dev 004, If 4, Class=Vendor Specific Class, Driver=qmi_wwan
```

`lsusb -t` では人間向けの class 名と割り当て済みドライバーが見えます。
より細かい `class` / `subclass` / `protocol` の数値は、`/sys/bus/usb/devices/` 配下の各 USB interface ディレクトリにある `bInterfaceClass`、`bInterfaceSubClass`、`bInterfaceProtocol` に書かれています。

今回の実機では、MBIM モード側の interface 4 / 5 は、USB descriptor 上で CDC MBIM として見えていました。

```text
1-1.1:1.4  interface 04  class 02  subclass 0e  protocol 00  driver cdc_mbim
1-1.1:1.5  interface 05  class 0a  subclass 00  protocol 02  driver cdc_mbim
```

一方で、QMI モード側の interface 4 は vendor specific class として見えていました。

```text
1-1.2:1.4  interface 04  class ff  subclass ff  protocol ff  driver qmi_wwan
```

ここで出てくる CDC は、USB Communications Device Class の略です。
USB 機器が OS に対して「自分は通信系のデバイスです」と標準的に伝えるための USB class です。
USB descriptor には `class`、`subclass`、`protocol` のような情報があり、OS はそれを見て、どのドライバーを割り当てるかを判断します。

MBIM モード側で出てきた `class 02` は CDC を表します。
さらに `subclass 0e` によって、CDC の中でも MBIM として見えていることが分かります。
そのため Linux では `cdc_mbim` ドライバーが割り当てられます。

一方で、QMI モード側の `class ff` は vendor specific class です。
これは USB の標準 class ではなく、ベンダー固有の interface として見えていることを表します。
この場合、Linux では `qmi_wwan` ドライバーが扱います。

少し紛らわしい点として、QMI 側でも制御用のデバイス名として `cdc-wdm1` のような名前が出てきます。
ただし、これは「QMI 側も CDC MBIM として見えている」という意味ではありません。
Linux のモバイルブロードバンドスタックでは、モデム制御用の character device として `cdc-wdmN` という名前が使われるため、MBIM と QMI のどちらでも `cdc-wdmN` が登場します。
ドライバーの違いを見るには、`cdc-wdmN` という名前だけでなく、`cdc_mbim` なのか `qmi_wwan` なのか、また USB descriptor が CDC MBIM なのか vendor specific なのかを見る必要があります。

Linux カーネルは、この descriptor とドライバー側の対応表を見て、前者には `cdc_mbim`、後者には `qmi_wwan` を割り当てます。
そのため、同じ `2c7c:0125` の Onyx でも、片方は MBIM、もう片方は QMI として見えることがあります。

この解釈は、USB-IF の class code 定義と Linux / Quectel のドキュメントに基づいています。
[USB-IF の Defined Class Codes](https://www.usb.org/defined-class-codes) では、`02h` は Communications and CDC Control、`0Ah` は CDC-Data、`FFh` は Vendor Specific と定義されています。
また [Linux の CDC 定義](https://codebrowser.dev/linux/linux/include/uapi/linux/usb/cdc.h.html)では、`USB_CDC_SUBCLASS_MBIM` が `0x0e` と定義されています。
[Linux カーネルの `cdc_mbim` ドキュメント](https://docs.kernel.org/networking/cdc_mbim.html) では、`cdc_mbim` が USB CDC MBIM 仕様に準拠する Mobile Broadband modem 向けのドライバーであり、制御チャネルを `/dev/cdc-wdmX`、データチャネルを `wwanY` として表すことが説明されています。
[Quectel の UMTS&LTE&5G Linux USB Driver User Guide](https://quectel.com/content/uploads/2024/04/Quectel_UMTS_LTE_5G_Linux_USB_Driver_User_Guide_V3.2.pdf) でも、USB interface class driver は interface class / sub-class / protocol に応じて自動的に割り当てられること、QMI WWAN では `wwanX` と `/dev/cdc-wdmX` が作られることが説明されています。

EG25-G では、このような USB ネットワーク機能の見せ方はモデム側の USB composition / USB network mode の設定に依存します。
この記事で扱う範囲では QMI と MBIM の 2 つです。
モードによって OS に出す interface class が変わります。
その結果として、Linux 側でバインドされるドライバーも変わります。

ただし、今回の記事の主題である NetworkManager からの扱いでは、どちらも最終的に `cdc-wdmN` と `wwanN` の組として見えています。
そのため、`setup_eg25.sh` では QMI か MBIM かを直接決め打ちせず、NetworkManager が `TYPE=gsm` として認識した `cdc-wdmN` を列挙して接続プロファイルを作る方針にしています。

### Onyx 側のモード差をどこで吸収しているのか

この構成で賢いところは、セットアップスクリプトが Onyx 側の USB network mode を直接そろえにいかない点です。
QMI / MBIM の違いは、主に Linux カーネル、ModemManager、NetworkManager の 3 層で吸収されています。

| 層 | 役割 | QMI の場合 | MBIM の場合 |
|---|---|---|---|
| Linux カーネル | USB interface にドライバーを割り当てる | `qmi_wwan` | `cdc_mbim` |
| デバイスノード | 制御口とデータ面を作る | `cdc-wdmN` + `wwanN` | `cdc-wdmN` + `wwanN` |
| ModemManager | モデム制御プロトコルを扱う | QMI で接続制御 | MBIM で接続制御 |
| NetworkManager | 接続設定を抽象化する | `TYPE=gsm` のデバイスとして見せる | `TYPE=gsm` のデバイスとして見せる |
| `setup_eg25.sh` | プロファイルを作る | `soracom-cdc-wdmN` を作る | `soracom-cdc-wdmN` を作る |

今回の実機でも、ModemManager から見ると片方は `cdc-wdm0 (mbim)`、もう片方は `cdc-wdm1 (qmi)` でした。

```text
modem 0
  primary-port: cdc-wdm0
  ports: cdc-wdm0 (mbim), wwan0 (net)

modem 1
  primary-port: cdc-wdm1
  ports: cdc-wdm1 (qmi), wwan1 (net)
```

しかし NetworkManager の段階では、どちらも `TYPE=gsm` のデバイスとして扱えます。

```text
cdc-wdm0:gsm:connected:soracom-cdc-wdm0
cdc-wdm1:gsm:connected:soracom-cdc-wdm1
```

`setup_eg25.sh` はこの抽象化された結果だけを見ます。
つまり、スクリプトにとって重要なのは「この Onyx が QMI か MBIM か」ではなく、「NetworkManager が `TYPE=gsm` の `DEVICE` として見せているか」です。

```bash
nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2 == "gsm" {print $1}'
```

この設計にすると、Onyx 側の USB network mode が混在していても、NetworkManager が扱える範囲であれば同じ処理にできます。

要するに、このスクリプトは USB network mode を変更するツールではありません。
QMI / MBIM の差分は Linux のモバイルブロードバンドスタックに任せ、その上に現れた `TYPE=gsm` のデバイスを安定して扱う、という割り切りです。

ここで出てくる名前の意味は、ざっくり以下です。

| 名前 | OS 上の意味 | 主な用途 |
|---|---|---|
| `ttyUSBN` | USB シリアルポート | AT コマンド、GPS、診断用など |
| `cdc-wdmN` | モデム制御用のデバイス | QMI / MBIM などの制御プロトコルでモデムへ接続指示を出す |
| `wwanN` | Linux のネットワークインターフェース | IP パケットが流れるデータ面 |

つまり、Onyx がいきなり Wi-Fi や Ethernet と同じ仕組みになるわけではありません。
USB モデム用の Linux カーネルドライバーが、制御用の `cdc-wdmN` とデータ通信用の `wwanN` を作ります。
この 2 つは上下関係ではなく、同じモデムに対して作られる別々の口です。
`cdc-wdmN` は「接続して」「切断して」「状態を教えて」のような制御用で、実際の IP パケットは `wwanN` 側を流れます。
その結果、`ip addr` や `ip route` からは `wwan0` / `wwan1` がネットワークインターフェースとして見えるようになります。

ただし、`wwanN` が存在するだけでは、まだセルラー回線に接続できているとは限りません。
APN、ユーザー名、パスワード、回線登録、PDP context の確立など、セルラーモデム固有の手順が必要です。
この部分を扱うのが ModemManager と NetworkManager です。

ここまで文字だけで説明してきましたが、USB interface、カーネルドライバー、ModemManager、NetworkManager、接続プロファイルの関係は少しややこしいです。
一度、システムレイヤーの全体像を図でまとめてみます。
`setup_eg25.sh` は USB descriptor や QMI / MBIM を直接見に行くのではなく、NetworkManager が `TYPE=gsm` として見せている `cdc-wdmN` を起点に接続プロファイルを作ります。

![システムレイヤーアーキテクチャ図](/images/dualonyxpi-networkmanager/system-layer-architecture.png)

アプリケーションから見ると、MBIM か QMI かはほとんど意識しません。
接続後は Linux カーネルの IP スタックがルーティングテーブルに従って、`wlan0`、`wwan0`、`wwan1` のどれへパケットを出すかを決めます。

## 全体像

今回の構成では、1 台の Raspberry Pi に 2 本の Onyx を USB 接続します。
Linux カーネル、ModemManager、NetworkManager から見ると、おおむね以下のような対応関係になります。

```text
Onyx #1
  Quectel EG25-G
    cdc-wdm0  NetworkManager から見える GSM デバイス
    wwan0     IP パケットが流れるネットワークインターフェース
    soracom-cdc-wdm0  NetworkManager の接続プロファイル

Onyx #2
  Quectel EG25-G
    cdc-wdm1  NetworkManager から見える GSM デバイス
    wwan1     IP パケットが流れるネットワークインターフェース
    soracom-cdc-wdm1  NetworkManager の接続プロファイル
```

ここで混同しやすいのは、`cdc-wdmN` と `wwanN` の役割です。
どちらかがどちらかの上位にあるというより、カーネルドライバーが制御用とデータ通信用の 2 つの口を作っている、と考えると分かりやすいです。
NetworkManager の `TYPE=gsm` は、ここでは 2G の GSM だけを指すというより、モバイルブロードバンド系のセルラー接続種別として理解するとよいです。

| 名前 | 主な役割 |
|---|---|
| `cdc-wdm0`, `cdc-wdm1` | モデムを制御するためのデバイス。NetworkManager では `TYPE=gsm` の `DEVICE` として見える |
| `wwan0`, `wwan1` | IP アドレスやルーティングの対象になる Linux のネットワークインターフェース |
| `soracom-cdc-wdm0`, `soracom-cdc-wdm1` | APN や認証情報などを持つ NetworkManager の接続プロファイル |

`dualonyxpi` のポイントは、`wwan0` / `wwan1` の数だけ手作業で設定を書くことではありません。
NetworkManager が `TYPE=gsm` として認識しているデバイスを列挙し、そのデバイス名を使って `soracom-<device>` という接続プロファイルを作ることです。

## GSM デバイスと接続プロファイルの関係

NetworkManager では、`DEVICE` と `CONNECTION` は別の概念です。
ここを分けて考えると、2 本の Onyx を扱う理由が分かりやすくなります。

`DEVICE` は、今 OS が認識している実体です。
Wi-Fi なら `wlan0`、Ethernet なら `eth0`、今回の Onyx なら `cdc-wdm0` や `cdc-wdm1` が該当します。
`nmcli dev status` で見えるものです。

```text
DEVICE    TYPE  STATE      CONNECTION
wlan0     wifi  connected  Wireless connection 1
cdc-wdm0  gsm   connected  soracom-cdc-wdm0
cdc-wdm1  gsm   connected  soracom-cdc-wdm1
```

一方で、`CONNECTION` は接続設定です。
どの APN を使うか、ユーザー名とパスワードは何か、自動接続するか、どの interface name に紐づけるか、といった設定を持ちます。
`nmcli con show` で見えるものです。

```text
NAME              TYPE  DEVICE
soracom-cdc-wdm0  gsm   cdc-wdm0
soracom-cdc-wdm1  gsm   cdc-wdm1
soracom           gsm   --
```

この接続プロファイルは、実体としては NetworkManager の設定ファイルとして保存されます。
Raspberry Pi OS では、今回の確認環境では `/etc/NetworkManager/system-connections/` 配下に `.nmconnection` ファイルとして保存されていました。

```text
/etc/NetworkManager/system-connections/
  soracom-cdc-wdm0.nmconnection
  soracom-cdc-wdm1.nmconnection
  soracom.nmconnection
```

形式は NetworkManager の keyfile 形式で、INI ファイルに近い構造です。
たとえば、`soracom-cdc-wdm0.nmconnection` は以下のような内容になります。

```ini
[connection]
id=soracom-cdc-wdm0
uuid=<uuid>
type=gsm
interface-name=cdc-wdm0

[gsm]
apn=soracom.io
username=sora
password=sora

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto

[proxy]
```

`soracom-cdc-wdm1.nmconnection` では、主に `id` と `interface-name` が `cdc-wdm1` 側になります。
この `interface-name` によって、接続プロファイルと GSM デバイスの対応関係を明示しています。

```ini
[connection]
id=soracom-cdc-wdm1
type=gsm
interface-name=cdc-wdm1
```

`DEVICE` は NetworkManager が認識している通信デバイスです。
一方で `CONNECTION` は、そのデバイスをどう使って接続するかを定義した設定一式です。
今回の `soracom-cdc-wdm0` には、`type=gsm`、`interface-name=cdc-wdm0` に加えて、PDP context の確立に使う `apn=soracom.io`、`username=sora`、`password=sora` などが含まれます。

ただし、今回のようにモデムが 2 本ある場合は逆の問題が起きます。
同じ `soracom` という接続プロファイルを 2 本の GSM デバイスで共有すると、NetworkManager がどちらの `cdc-wdmN` にそのプロファイルを適用するのかが曖昧になります。
そのため、`cdc-wdm0` には `soracom-cdc-wdm0`、`cdc-wdm1` には `soracom-cdc-wdm1` というように、GSM デバイスごとに接続プロファイルを分けます。

関係を図にすると、次のようになります。

```text
USB Onyx #1
  kernel driver
    cdc-wdm0  <--- NetworkManager の GSM device
    wwan0     <--- Linux の IP interface
  NetworkManager connection
    soracom-cdc-wdm0
      apn = soracom.io
      ifname = cdc-wdm0

USB Onyx #2
  kernel driver
    cdc-wdm1  <--- NetworkManager の GSM device
    wwan1     <--- Linux の IP interface
  NetworkManager connection
    soracom-cdc-wdm1
      apn = soracom.io
      ifname = cdc-wdm1
```

接続プロファイルは `wwan0` ではなく `cdc-wdm0` に寄せて作っている点も重要です。
NetworkManager がセルラー接続を開始するときに必要なのは、IP パケットを流す `wwan0` そのものではなく、モデムへ「この APN で接続して」と指示する制御口です。
その制御口が `cdc-wdm0` / `cdc-wdm1` です。
接続が確立した後に、結果として `wwan0` / `wwan1` に IP アドレスが付き、ルーティング対象になります。

## なぜ 1 つの `soracom` プロファイルでは足りないのか

Onyx が 1 本だけなら、`soracom` という接続プロファイルを 1 つ作っておけば運用できます。
しかし Onyx が 2 本ある状態で、1 つのプロファイルを複数モデムに使い回すと、次のような曖昧さが出ます。

- どちらのモデムで接続を上げるのかが分かりにくい
- 再接続時に意図しないモデムへプロファイルが適用される可能性がある
- `nmcli con show` を見ても、どの回線に対応する設定なのか判断しづらい

そこで `setup_eg25.sh` では、以下のように `nmcli dev status` の結果から `TYPE=gsm` のデバイスだけを取り出します。

```bash
nmcli -t -f DEVICE,TYPE dev status
```

出力例は以下のような形です。

```text
cdc-wdm0:gsm
cdc-wdm1:gsm
wlan0:wifi
eth0:ethernet
```

このうち `TYPE=gsm` の `cdc-wdm0` と `cdc-wdm1` を使い、それぞれに接続プロファイルを作ります。

```bash
sudo nmcli con add type gsm ifname cdc-wdm0 con-name soracom-cdc-wdm0 apn soracom.io user sora password sora
sudo nmcli con add type gsm ifname cdc-wdm1 con-name soracom-cdc-wdm1 apn soracom.io user sora password sora
```

さらに接続を上げるときも、プロファイル名だけでなく `ifname` を指定します。

```bash
sudo nmcli con up soracom-cdc-wdm0 ifname cdc-wdm0
sudo nmcli con up soracom-cdc-wdm1 ifname cdc-wdm1
```

この `ifname` 指定が重要です。
プロファイル名とデバイス名をそろえておくことで、人間が見ても対応関係を追いやすくなり、NetworkManager に対しても「このプロファイルはこの GSM デバイスで上げる」と明示できます。

## セットアップスクリプトの流れ

`dualonyxpi` の現状の実装は、ほぼ `setup_eg25.sh` に集約されています。
ここでは処理の流れを、ブログ向けに要点だけに分けて見ていきます。

このスクリプトは、SORACOM の公式セットアップスクリプトを 2 本構成向けに拡張する、という見方をすると理解しやすいです。
公式スクリプトは Onyx / EG25-G を 1 本接続する前提で、`soracom` という接続プロファイルを 1 つ作ります。
一方で `dualonyxpi` では、NetworkManager が認識した GSM デバイスごとに `soracom-cdc-wdm0`、`soracom-cdc-wdm1` のような接続プロファイルを作ります。

| 観点 | 公式スクリプト | `dualonyxpi` |
|---|---|---|
| 想定 | Onyx / EG25-G 1 本 | Onyx / EG25-G 複数本 |
| 接続プロファイル | `soracom` を 1 つ作る | `soracom-<device>` を GSM デバイスごとに作る |
| `nmcli con add` の `ifname` | `*` | `cdc-wdm0`、`cdc-wdm1` など |
| 接続を上げるとき | `nmcli con up soracom` | `nmcli con up soracom-<device> ifname <device>` |
| `dhcpcd` との競合回避 | `wwan0` を対象にする | 見えている `wwanN` を列挙して対象にする |
| SORACOM 向け経路 | `wwan0` などを対象にする | `wwan0` / `wwan1` など複数の `wwanN` を対象にする |
| `raw_ip` | `wwan0` の固定パスへ書く | 各 `wwanN` で `raw_ip` が存在する場合だけ書く |

つまり、基本の流れは公式スクリプトを踏襲しつつ、「1 本のモデムをよしなに接続する」処理を「NetworkManager が認識した GSM デバイスごとに分けて扱う」処理へ変えています。

### 1. root 実行と APN 情報を確認する

スクリプトは `/etc/NetworkManager/dispatcher.d/` や `/etc/dhcpcd.conf` を変更するため、root 権限で実行します。
APN、ユーザー名、パスワードは引数で渡せます。
省略した場合は、SORACOM Air の一般的な設定である `soracom.io` / `sora` / `sora` が使われます。

```bash
sudo bash ./setup_eg25.sh
```

plan-DU などで APN を変える場合は、以下のように第 1 引数で指定できます。

```bash
sudo bash ./setup_eg25.sh du.soracom.io
```

:::message
現時点のリポジトリでは `setup_eg25.sh` に実行ビットが付いていないため、README のように `sudo ./setup_eg25.sh` と実行すると `Permission denied` になる場合があります。
その場合は `sudo bash ./setup_eg25.sh` として実行するか、リポジトリ側で実行ビットを付けます。
:::

### 2. 必要なパッケージとサービスを用意する

スクリプトでは、`nmcli` が利用できるか確認します。
不足している場合は `apt-get` で `network-manager` をインストールします。

その後、NetworkManager を有効化して起動します。
ModemManager については、`mmcli` を使ってモデムの認識状態を確認します。
スクリプト内にも ModemManager を起動しようとする処理がありますが、実機では `systemctl status ModemManager` などで起動状態を別途確認しておくと安全です。

Onyx / EG25-G のような USB モデムを NetworkManager 経由で扱う場合、NetworkManager だけでなく ModemManager がモデムを正しく認識していることも重要です。
実機では、まず以下を見ます。

```bash
mmcli -L
```

2 本の Onyx が見えていれば、ModemManager 上でも複数の modem が列挙されます。
`mmcli -m <番号>` を見ると、`primary port: cdc-wdm0` や `ports: ... wwan0 (net)` のような情報を確認できます。

### 3. Onyx / EG25-G を検出する

Onyx / EG25-G 側では、USB ID `2c7c:0125` を見ます。

```bash
lsusb
```

Onyx が認識されている場合は、Quectel / EG25-G 相当の USB デバイスが見えるはずです。
スクリプト内では、ModemManager の一覧に `QUECTEL` が出てくることも待ちます。

ここで大事なのは、USB として見えていること、ModemManager が modem として認識していること、NetworkManager が `TYPE=gsm` のデバイスとして見ていることを分けて確認することです。

```bash
lsusb
mmcli -L
nmcli dev status
```

2 本構成で期待したい状態は、`lsusb` だけでなく `nmcli dev status` にも GSM デバイスが 2 つ出ていることです。

### 4. dhcpcd と NetworkManager の競合を避ける

`dhcpcd` は、ネットワークインターフェースに IP アドレス、DNS、デフォルトルートなどを設定する DHCP クライアントデーモンです。
Raspberry Pi OS では、従来 `eth0` や `wlan0` の IP 設定を `dhcpcd` が担当してきました。

一方で、`wwan0` / `wwan1` のようなセルラー回線側のインターフェースは、NetworkManager / ModemManager に任せたい対象です。
セルラー回線では、APN を指定してモデムがデータセッションを確立し、その結果として IP アドレスや DNS、経路情報が得られます。
ここに `dhcpcd` も普通の Ethernet / Wi-Fi と同じ感覚で関与すると、NetworkManager / ModemManager が設定した内容と競合する可能性があります。

Raspberry Pi OS / Debian 11 以降の環境では、`dhcpcd` と NetworkManager が同じ `wwanN` を取り合うと、接続が不安定になります。
そのためスクリプトには、`/sys/class/net` に見えている `wwanN` を `/etc/dhcpcd.conf` の `denyinterfaces` に追加する処理があります。

```text
denyinterfaces wwan0
denyinterfaces wwan1
```

これにより、`wwan0` や `wwan1` は NetworkManager 側で扱う前提に寄せます。

なお、この処理はスクリプト実行時点で見えている `wwanN` を対象にします。
初回実行時にモデムを後から挿す場合や、USB の認識順が変わる場合は、実機で `/etc/dhcpcd.conf` と `nmcli dev status` の両方を確認しておくと安全です。

### 5. SORACOM 向け経路を dispatcher に寄せる

APN が `soracom.io` を含む場合、スクリプトは NetworkManager dispatcher を作成します。
dispatcher は、NetworkManager がインターフェースの up/down を検知したタイミングで実行されるフックです。

`setup_eg25.sh` では、`/etc/NetworkManager/dispatcher.d/90.soracom_route` を作り、`wwanN` や `ppp0` が up したときに SORACOM 向けの経路を追加します。

対象にしている経路は以下です。

| 宛先 | 用途の目安 |
|---|---|
| `100.127.0.0/16` | SORACOM プラットフォーム側の内部向け宛先 |
| `54.250.252.67/32` | SORACOM 関連サービス向けの個別宛先 |
| `54.250.252.99/32` | SORACOM 関連サービス向けの個別宛先 |

`wwan0` や `wwan1` が up したときは、そのインターフェースの default route から gateway を取り出し、metric 0 で経路を追加します。
down したときは同じ宛先の経路を削除します。

このように dispatcher に寄せると、モデムの再接続や抜き差しに合わせて経路を入れ直せます。
Wi-Fi や Ethernet が同時にある Raspberry Pi でも、SORACOM 向けの通信だけをモデム側へ寄せる意図が読み取りやすくなります。

### 6. GSM デバイスごとに `soracom-<device>` プロファイルを作る

2 本対応の中心はこの部分です。
スクリプトは以下の考え方で接続プロファイルを作ります。

```bash
nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2 == "gsm" {print $1}'
```

たとえばここで `cdc-wdm0` と `cdc-wdm1` が得られたら、接続名は次のようになります。

```text
soracom-cdc-wdm0
soracom-cdc-wdm1
```

新規作成時は、以下のように `ifname` にデバイス名を指定します。

```bash
sudo nmcli con add type gsm ifname cdc-wdm0 con-name soracom-cdc-wdm0 apn soracom.io user sora password sora
```

既存プロファイルがある場合は、同じ名前のプロファイルを作り直さず、状態を見て必要なら接続を上げます。
このときも `nmcli con up soracom-cdc-wdm0 ifname cdc-wdm0` のように `ifname` を明示します。

`TYPE=gsm` のデバイスが見つからない場合は、従来寄りの fallback として `soracom` という 1 つのプロファイルを作る実装も残っています。
ただし、2 本の Onyx を別々に扱うという目的では、`soracom-cdc-wdm0` と `soracom-cdc-wdm1` のように分かれている状態を目指します。

### 7. `raw_ip` は存在する場合だけ設定する

EG25-G を QMI の `wwanN` として使う場合、環境によっては以下の sysfs パスが存在します。

```text
/sys/class/net/wwan0/qmi/raw_ip
/sys/class/net/wwan1/qmi/raw_ip
```

`setup_eg25.sh` では、`wwanN` を一度 down してから、`raw_ip` が存在する場合だけ `Y` を書き込み、再度 up します。

```bash
sudo ip link set wwan0 down
echo Y | sudo tee /sys/class/net/wwan0/qmi/raw_ip
sudo ip link set wwan0 up
```

実際のスクリプトでは、パスの存在を確認してから書き込むため、`raw_ip` が存在しない環境でもそこで失敗しないようになっています。
これは複数モデム対応というより、Raspberry Pi OS やドライバー構成の差を吸収するための守りです。
今回の確認環境でも、`/sys/class/net/wwan1/qmi/raw_ip` は存在して `Y` でしたが、`wwan0` 側には同じパスが見えていませんでした。
そのため、存在チェックを入れておく意味があります。

## 実行後に確認すること

セットアップ後は、最低限以下を確認します。

```bash
mmcli -L
nmcli dev status
nmcli con show | grep soracom
ip route | grep -E '100\.127\.|54\.250\.252\.'
```

2 本が意図通り見えていれば、`nmcli dev status` には GSM デバイスが 2 つ出ます。
また、`nmcli con show | grep soracom` では、次のようなプロファイルが見えるはずです。

```text
soracom-cdc-wdm0
soracom-cdc-wdm1
```

接続を手動で上げ直す場合は、プロファイル名と `ifname` の両方を指定します。

```bash
sudo nmcli con down soracom-cdc-wdm0
sudo nmcli con up soracom-cdc-wdm0 ifname cdc-wdm0

sudo nmcli con down soracom-cdc-wdm1
sudo nmcli con up soracom-cdc-wdm1 ifname cdc-wdm1
```

今回の確認環境では、2 本の Onyx が以下のように見えました。
USB デバイスとしては、`2c7c:0125` が 2 つあります。

```text
Bus 001 Device 003: ID 2c7c:0125 Quectel Wireless Solutions Co., Ltd. EC25 LTE modem
Bus 001 Device 004: ID 2c7c:0125 Quectel Wireless Solutions Co., Ltd. EC25 LTE modem
```

ModemManager からも、modem が 2 つ見えています。

```text
/org/freedesktop/ModemManager1/Modem/1 [QUALCOMM INCORPORATED] QUECTEL Mobile Broadband Module
/org/freedesktop/ModemManager1/Modem/0 [Quectel] EG25-G
```

per-device profile にそろえた後の `nmcli dev status` は以下です。

```text
wlan0:wifi:connected:Wireless connection 1
cdc-wdm0:gsm:connected:soracom-cdc-wdm0
cdc-wdm1:gsm:connected:soracom-cdc-wdm1
lo:loopback:connected (externally):lo
```

`wwan0` と `wwan1` には、それぞれ SORACOM Air 側の IP アドレスが割り当てられていました。
実際の IP アドレスは環境依存なので、ここでは伏せています。

```text
wwan0  UNKNOWN  <wwan0_ip>/<prefix>
wwan1  UNKNOWN  <wwan1_ip>/<prefix>
```

### `ifconfig` で `wwan0` と `wwan1` の見え方が違う理由

今回の実機では、`ifconfig` で見ると `wwan0` と `wwan1` の表示がかなり違っていました。
要点だけ抜き出すと、以下のような違いです。

```text
wwan0: flags=<UP,BROADCAST,RUNNING,NOARP,MULTICAST>  mtu 1500
        ether <mac-like-address>

wwan1: flags=<UP,POINTOPOINT,RUNNING,NOARP,MULTICAST>  mtu 1430
        unspec 00-00-00-00-...
```

これは通信できているかどうかの差ではなく、下位のドライバーとデータ形式の見え方の差です。
今回の環境では、`wwan0` は `cdc_mbim` に紐づいた MBIM 側のインターフェース、`wwan1` は `qmi_wwan` に紐づいた QMI 側のインターフェースでした。

MBIM 側の `wwan0` は、Linux からは Ethernet 風のネットワークデバイスとして見えるため、`BROADCAST` や `ether` のような表示になります。
一方、QMI 側の `wwan1` は `raw_ip` の point-to-point 風のインターフェースとして見えるため、`POINTOPOINT` や `UNSPEC` のような表示になります。

ここで注意したいのは、`wwan0` に `BROADCAST` や `ether` が出ていても、通常の LAN と同じように ARP で隣接ノードを見つけるわけではない点です。
実際には `wwan0` と `wwan1` のどちらにも `NOARP` が付いています。
セルラー回線では、モデム制御で確立したデータセッションの上に IP パケットを流している、と考える方が実態に近いです。

アプリケーションから見ると、この違いは基本的に隠れます。
アプリケーションは Linux の socket API を使って通信し、カーネルのルーティングテーブルが `wlan0`、`eth0`、`wwan0`、`wwan1` のどれから出すかを決めます。
そのため、アプリケーションが直接 MBIM や QMI を話すわけではありません。

`ifconfig` は古い表示コマンドなので、詳細を確認する場合は以下のように `ip` コマンドも併用すると読み取りやすくなります。

```bash
ip addr show wwan0
ip addr show wwan1
ip -d link show wwan0
ip -d link show wwan1
ip route
```

`ifconfig` の表示差は、「片方だけ異常」というより、「MBIM と QMI の違いが Linux の `net_device` の表現に残っている」と捉えるのがよいです。

### 通常の疎通確認

通信確認としては、SORACOM プラットフォーム側の疎通確認に使われる `pong.soracom.io` への ping などを使います。
ただし、このようにインターフェースを指定しない ping は、現在のルーティングテーブルに従って送信されます。
2 本の Onyx のどちらから出ているかを確認したい場合は、後述する `ping -I <interface>` のように出力インターフェースを明示します。

```bash
ping -c 3 pong.soracom.io
```

### 現状のルーティングではどちらが使われるか

2 本の Onyx が両方とも接続されていても、アプリケーションの通信が自動的に両方へ分散されるわけではありません。
Linux はルーティングテーブルを見て、宛先ごとにどのインターフェースから出すかを決めます。
そのため、2 本同時接続の検証では「接続できているか」だけでなく、「どちらの回線から出ているか」も確認しておくと理解しやすくなります。

今回の確認環境では、default route は次のようになっていました。

```text
default via <wifi_gateway> dev wlan0 proto dhcp metric 600
default via <wwan0_gateway> dev wwan0 proto static metric 700
default via <wwan1_gateway> dev wwan1 proto static metric 701
```

同じ default route であれば、metric が小さい方が優先されます。
そのため、通常のインターネット向け通信では `wlan0` が優先されます。
Wi-Fi が無い状態であれば、`wwan0` が `wwan1` よりも優先される並びです。

一方で、dispatcher が追加した SORACOM 向けの固定経路は、今回の確認時点では `wwan0` 側に入っていました。

```text
100.127.0.0/16 via <wwan0_gateway> dev wwan0
54.250.252.67 via <wwan0_gateway> dev wwan0
54.250.252.99 via <wwan0_gateway> dev wwan0
```

Linux のルーティングでは、default route よりも具体的な宛先経路が優先されます。
そのため、SORACOM プラットフォーム向けの宛先は、Wi-Fi の default route ではなく `wwan0` 側へ向かいます。

実際にどのインターフェースが選ばれるかは、`ip route get` で確認できます。

```bash
ip route get 1.1.1.1
ip route get 100.127.0.1
ip route get 54.250.252.67
```

今回の確認環境では、以下のような結果でした。

```text
1.1.1.1        -> dev wlan0
100.127.0.1    -> dev wwan0
54.250.252.67  -> dev wwan0
54.250.252.99  -> dev wwan0
```

つまり、`wwan1` も接続済みではありますが、現状のルーティング設定では通常のアプリケーション通信にはほとんど使われません。
`wwan1` を使うには、`ping -I wwan1 ...` のように明示的にインターフェースを指定するか、宛先ごとの経路制御を追加する必要があります。

### インターフェース指定の疎通確認

ここで確認したいのは、ルーティング上の優先度とは別に、`wwan0` と `wwan1` の両方が実際に通信できる状態になっているかです。
SORACOM プラットフォーム側の疎通確認に使える `pong.soracom.io` に対して、インターフェースを明示して ping を実行します。

```bash
ping -c 2 -W 3 -I wwan0 pong.soracom.io
ping -c 2 -W 3 -I wwan1 pong.soracom.io
```

今回の確認環境では、どちらのインターフェースを指定しても疎通できました。
送信元 IP アドレスは環境依存なので伏せています。

```text
# wwan0 を指定
PING pong.soracom.io (100.127.100.127) from <wwan0_ip> wwan0: 56(84) bytes of data.
64 bytes from 100.127.100.127: icmp_seq=1 ttl=64 time=<...> ms
64 bytes from 100.127.100.127: icmp_seq=2 ttl=64 time=<...> ms

--- pong.soracom.io ping statistics ---
2 packets transmitted, 2 received, 0% packet loss

# wwan1 を指定
PING pong.soracom.io (100.127.100.127) from <wwan1_ip> wwan1: 56(84) bytes of data.
64 bytes from 100.127.100.127: icmp_seq=1 ttl=64 time=<...> ms
64 bytes from 100.127.100.127: icmp_seq=2 ttl=64 time=<...> ms

--- pong.soracom.io ping statistics ---
2 packets transmitted, 2 received, 0% packet loss
```

この結果から、`wwan1` が通常のルーティングで優先されていないだけで、回線として使えないわけではないことが分かります。
つまり、2 本の Onyx はどちらも NetworkManager 上で接続済みであり、明示的にインターフェースを指定すれば、それぞれの回線から SORACOM 側へ通信できます。

同じ宛先プレフィックスを 2 つのインターフェースへ同時に追加するには、単純な `ip route add` だけでは足りません。
このスクリプトは「2 本を NetworkManager 上で分離して扱う」ための土台であり、アクティブ・アクティブな経路制御まで自動化するものではない、と切り分けておくと理解しやすいです。

ここから先は、別の記事のテーマにできます。
たとえば、宛先に応じて `wwan0` と `wwan1` を使い分ける policy routing、片方を主系でもう片方を従系にする failover 構成、複数回線を束ねて帯域を広げる MPTCP や VPN bonding のような構成です。
本記事では、その前段として、2 本の Onyx を Linux と NetworkManager の上で別々の回線として見える状態にするところまでを扱います。

## トラブルシュート

### `sudo ./setup_eg25.sh` で Permission denied になる

現時点のリポジトリでは、`setup_eg25.sh` のファイルモードが `100644` です。
そのため、実行ビットが付いていない環境では直接実行できません。

以下のどちらかで対応します。

```bash
sudo bash ./setup_eg25.sh
```

または、リポジトリ側で実行ビットを付けます。

```bash
chmod +x setup_eg25.sh
sudo ./setup_eg25.sh
```

### `soracom-cdc-wdm0` しか作られない

まず、NetworkManager が 2 本目を `TYPE=gsm` として見ているか確認します。

```bash
nmcli dev status
```

`cdc-wdm0` しか出ていない場合、接続プロファイルを作る以前に、USB デバイス、ModemManager、NetworkManager のどこかで 2 本目が見えていません。
順番に以下を確認します。

```bash
lsusb
mmcli -L
nmcli dev status
```

電源供給が不安定な USB ハブや、片方の Onyx が初期化途中のままになっているケースもあるため、ログも確認します。

```bash
sudo tail -n 100 /var/log/soracom_setup.log
journalctl -u NetworkManager -u ModemManager --no-pager
```

### `wwan0` / `wwan1` はあるのに通信できない

`dhcpcd` と NetworkManager が同じインターフェースを扱っていないか確認します。

```bash
grep '^denyinterfaces wwan' /etc/dhcpcd.conf
nmcli dev status
```

Raspberry Pi OS / Debian 11 以降では、`wwanN` を NetworkManager 側に寄せるため、`denyinterfaces wwan0` や `denyinterfaces wwan1` が入っていることを確認します。

また、SORACOM 向け経路が入っているかも確認します。

```bash
ip route | grep -E '100\.127\.|54\.250\.252\.'
```

経路が無い場合は、dispatcher が作られているか、対象インターフェースが up になったときに実行されているかを見ます。

```bash
ls -l /etc/NetworkManager/dispatcher.d/90.soracom_route
sudo tail -n 100 /var/log/soracom_status.log
```

### モデムの物理的な対応関係を固定したい

このスクリプトは、NetworkManager がその時点で認識している `cdc-wdm0` や `cdc-wdm1` を起点にプロファイルを作ります。
そのため、USB の挿し替えや起動順によって、物理的な Onyx と `cdc-wdmN` の対応が入れ替わる可能性は残ります。

検証用途では、`mmcli -m <番号>` で IMEI や primary port を見て対応関係を確認するとよいです。
本番運用で物理ポートや個体に強く紐づけたい場合は、udev ルールや ModemManager が持つ識別子を使った追加設計を検討します。

## まとめ

Raspberry Pi に 2 本の Soracom Onyx / EG25-G を接続する場合、重要なのは USB モデムを 2 本認識させることだけではありません。
NetworkManager が扱う GSM デバイスごとに接続プロファイルを分け、接続時にも `ifname` を明示することが、意図したモデムに接続を上げるための基本になります。

`dualonyxpi` の `setup_eg25.sh` では、`nmcli dev status` から `TYPE=gsm` のデバイスを列挙し、`soracom-cdc-wdm0` や `soracom-cdc-wdm1` のようなプロファイルを作ります。
あわせて、SORACOM 向けの経路は NetworkManager dispatcher に寄せ、インターフェースの up/down に合わせて追加・削除する構成にしています。

MBIM と QMI のどちらを使うべきかは、可能なら MBIM にそろえると説明やトラブルシュートが楽です。
ただし、QMI でも Linux のモバイルブロードバンドスタックが対応していれば問題なく扱えます。
このスクリプトでは、そこを `TYPE=gsm` のデバイスとして抽象化し、接続プロファイルをデバイスごとに分けることで、2 本の Onyx を扱えるようにしています。

今回の確認環境では、ModemManager から 2 本の Onyx が見え、NetworkManager でも `cdc-wdm0` と `cdc-wdm1` がそれぞれ `soracom-cdc-wdm0` / `soracom-cdc-wdm1` として接続されていました。
また、`ip route get` では通常の通信と SORACOM 向け通信で選ばれるインターフェースを確認でき、`ping -I wwan0` / `ping -I wwan1` ではどちらの回線からも `pong.soracom.io` に疎通できることを確認できました。

## コラム: MBIM と QMI の違いと選び方

ここで一度、MBIM と QMI の違いを切り出して整理します。
どちらも、USB 接続されたセルラーモデムを Linux から制御し、最終的に `wwanN` へ IP パケットを流すための方式です。
違うのは、主に USB interface の見せ方、モデム制御プロトコル、Linux 側で使われるドライバーです。

| 観点 | MBIM | QMI |
|---|---|---|
| 位置づけ | USB CDC 系の標準寄りの方式 | Qualcomm 系モデムで広く使われる方式 |
| USB descriptor の見え方 | CDC MBIM として見える | vendor specific class として見えることが多い |
| Linux ドライバー | `cdc_mbim` | `qmi_wwan` |
| 制御プロトコル | MBIM | QMI |
| 制御用デバイス | `cdc-wdmN` | `cdc-wdmN` |
| データ用インターフェース | `wwanN` | `wwanN` |
| 見え方の傾向 | Ethernet 風に見えやすい | raw IP / point-to-point 風に見えやすい |

結論から言うと、新しく構成をそろえられるなら MBIM に寄せるのが分かりやすいです。
MBIM は USB CDC 系の標準寄りの方式で、Linux の `cdc_mbim`、ModemManager、NetworkManager の組み合わせで扱いやすく、OS 上の見え方も比較的素直です。
今回の実機でも、MBIM 側の `wwan0` は MTU 1500 の Ethernet 風のインターフェースとして見えていました。

一方で、QMI が劣っているという意味ではありません。
Quectel / Qualcomm 系のモデムでは QMI も広く使われており、Linux では `qmi_wwan` と ModemManager が対応しています。
QMI 側では `raw_ip`、`POINTOPOINT`、`UNSPEC`、MTU 1430 のような表示になることがあり、初見では少し分かりにくいだけです。

そのため、この記事で扱う `dualonyxpi` の立場は次のように整理できます。

- 再現性を重視して 2 本をそろえるなら、MBIM に寄せると説明しやすい
- 既に MBIM と QMI が混在していても、ModemManager / NetworkManager が認識していれば動作対象にできる
- `setup_eg25.sh` は MBIM か QMI かを直接判定せず、NetworkManager に `TYPE=gsm` として見えている `cdc-wdmN` を起点にする
- アプリケーションは MBIM / QMI を意識せず、Linux の IP スタックとルーティングテーブルに従って `wwanN` から通信する

つまり、運用上の推奨は「可能なら MBIM にそろえる」です。
ただし、このスクリプトの肝は、MBIM / QMI の差を下位レイヤーに任せ、NetworkManager が見せる GSM デバイス単位で接続プロファイルを分離する点にあります。

## 参考

- `dualonyxpi`: https://github.com/takao2704/dualonyxpi
- SORACOM 公式 `setup_eg25.sh`: https://soracom-files.s3.amazonaws.com/connect/setup_eg25.sh
- Soracom Onyx - LTE™ USB ドングルをセットアップする: https://users.soracom.io/ja-jp/guides/usb-dongles/soracom-onyx/raspberrypi/
- Soracom Onyx の AT コマンド実行手順: https://users.soracom.io/ja-jp/guides/usb-dongles/soracom-onyx/at-command/
- USB-IF Defined Class Codes: https://www.usb.org/defined-class-codes
- Linux Kernel Documentation - `cdc_mbim`: https://docs.kernel.org/networking/cdc_mbim.html
- Linux CDC definitions - `USB_CDC_SUBCLASS_MBIM`: https://codebrowser.dev/linux/linux/include/uapi/linux/usb/cdc.h.html
- Quectel UMTS&LTE&5G Linux USB Driver User Guide: https://quectel.com/content/uploads/2024/04/Quectel_UMTS_LTE_5G_Linux_USB_Driver_User_Guide_V3.2.pdf
- ModemManager `libqmi` documentation: https://modemmanager.org/docs/libqmi/
