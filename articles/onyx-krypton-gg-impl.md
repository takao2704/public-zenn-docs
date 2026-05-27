---
title: "Soracom Onyx と Krypton で Greengrass Core をゼロタッチ化する実装検証"
emoji: "🛠️"
type: "tech"
topics: ["soracom", "aws", "awsiot", "greengrass", "raspberrypi"]
published: false
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## TL;DR

- この記事は実装検証編です。設計の考え方は設計編で扱います。
- サンプルリポジトリでは、`scripts/setup-raspi.sh` が Onyx、Krypton、Greengrass の手動セットアップを担当します。
- ゼロタッチキッティングでは、`tools/prepare-base-image.sh` で固定依存を base image に入れ、`tools/inject-sd.sh` で boot partition に first boot payload を注入します。
- 初回起動後は `firstrun.sh`、`krgg-provision.timer`、`firstboot-provision.sh`、`setup_eg25.sh`、`setup-raspi.sh` の順に処理が進みます。
- 現状のサンプル実装では `device.env` は自動同梱されません。ゼロタッチで完結させるには、payload への同梱または `/opt/krgg/device.env` への配置が必要です。

## はじめに

設計編では、Soracom Onyx、SORACOM Krypton、AWS IoT Greengrass Core を組み合わせる理由と、Raspberry Pi の base image と first boot payload を分ける考え方を整理しました。

この記事では、サンプルリポジトリの実装が具体的に何をしているかを確認します。

https://github.com/takao2704/soracom-onyx-krypton-greengrass-setup

## リポジトリ構成

主なファイルは次のとおりです。

| ファイル | 役割 |
|---|---|
| `docs/cloud-setup.md` | AWS IoT endpoint、role alias、policy、SORACOM Krypton group 設定の準備 |
| `scripts/setup-raspi.sh` | Raspberry Pi 上で Onyx、Krypton、Greengrass の順にセットアップ |
| `tools/prepare-base-image.sh` | ゼロタッチ配布向けの固定依存を base image へ入れる |
| `tools/build-payload.sh` | first boot 用ファイルを tarball に固める |
| `tools/inject-sd.sh` | boot partition に first boot 用 payload と起動 hook を注入する |
| `inject/boot/firstrun.sh` | 初回起動時に payload を root filesystem へ展開する |
| `inject/payload/opt/krgg/firstboot-provision.sh` | systemd timer から実行される provisioning entrypoint |
| `inject/payload/opt/krgg/setup_eg25.sh` | Onyx / EG25-G の APN profile と SORACOM route を準備する |

## 事前準備

まずはリポジトリを取得します。

```bash
git clone https://github.com/takao2704/soracom-onyx-krypton-greengrass-setup.git
cd soracom-onyx-krypton-greengrass-setup
```

前提は次のとおりです。

- Raspberry Pi OS または Debian 系 OS
- Soracom Onyx を挿した Raspberry Pi
- 対象 SIM が SORACOM Air で通信できること
- 対象 SIM の group に SORACOM Krypton for AWS IoT を設定できること
- AWS IoT Core と AWS IoT Greengrass を利用できる AWS account
- Greengrass token exchange role alias を作成できる権限

ゼロタッチ配布まで考える場合は、準備用 Raspberry Pi、配布用の base image、SD カードの boot partition に書き込める Mac や Linux なども必要です。

## クラウド側を準備する

Raspberry Pi 側のスクリプトは、AWS や SORACOM の管理 API credential を持たない前提です。クラウド側の準備は事前に行います。

### 1. AWS IoT endpoint を確認する

AWS IoT の Data-ATS endpoint と Credential Provider endpoint を確認します。

```bash
aws iot describe-endpoint \
  --endpoint-type iot:Data-ATS \
  --region ap-northeast-1

aws iot describe-endpoint \
  --endpoint-type iot:CredentialProvider \
  --region ap-northeast-1
```

取得した値は、Raspberry Pi 側の `device.env` に設定します。

```bash
AWS_REGION="ap-northeast-1"
AWS_IOT_DATA_ENDPOINT="<AWS_IOT_DATA_ENDPOINT>"
AWS_IOT_CRED_ENDPOINT="<AWS_IOT_CRED_ENDPOINT>"
GREENGRASS_ROLE_ALIAS="GreengrassV2TokenExchangeCoreDeviceRoleAlias"
```

### 2. Greengrass 用の role alias と policy を用意する

Greengrass Core は token exchange role alias を使って、AWS リソースへアクセスするための一時 credential を取得します。AWS IoT policy には、Greengrass Core と `iot:AssumeRoleWithCertificate` に必要な権限を含めます。

検証用の例は次のような形です。本番では利用する Greengrass component、ログ出力先、S3 artifact、Shadow、Jobs などに合わせて権限を絞ってください。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iot:Connect",
        "iot:Publish",
        "iot:Subscribe",
        "iot:Receive",
        "greengrass:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iot:AssumeRoleWithCertificate",
      "Resource": "arn:aws:iot:ap-northeast-1:<AWS_ACCOUNT_ID>:rolealias/GreengrassV2TokenExchangeCoreDeviceRoleAlias"
    }
  ]
}
```

この policy を作成し、SORACOM Krypton の AWS IoT 設定で `policyName` として指定できるようにします。

### 3. SORACOM Krypton group 設定を追加する

対象 SIM が所属する group に、Krypton の AWS IoT 設定を追加します。

```bash
soracom groups put-config \
  --group-id <SORACOM_GROUP_ID> \
  --namespace SoracomKrypton \
  --body '[
    {
      "key": "enabled",
      "value": true
    },
    {
      "key": "AwsIot",
      "value": {
        "region": "ap-northeast-1",
        "credentialsId": "<SORACOM_AWS_CREDENTIALS_ID_FOR_KRYPTON>",
        "policyName": "GreengrassKryptonCorePolicy",
        "thingNamePattern": "takao-rpi-krypton-$imsi",
        "host": "<AWS_IOT_DATA_ENDPOINT>"
      }
    }
  ]'
```

`thingNamePattern` は、デバイスが Thing 名を明示しない場合に使われます。ゼロタッチ運用では、Raspberry Pi 側の `KRYPTON_THING_NAME` を空にして、この pattern で SIM ごとに一意な Thing 名を作る方針にします。

## Raspberry Pi 上で手動実行する

まずは SSH できる Raspberry Pi で動きを確認するのが分かりやすいです。

```bash
cp examples/device.env.example device.env
vi device.env
```

最低限、以下を設定します。

```bash
AWS_REGION="ap-northeast-1"
AWS_IOT_DATA_ENDPOINT="<AWS_IOT_DATA_ENDPOINT>"
AWS_IOT_CRED_ENDPOINT="<AWS_IOT_CRED_ENDPOINT>"
GREENGRASS_ROLE_ALIAS="GreengrassV2TokenExchangeCoreDeviceRoleAlias"
KRYPTON_THING_NAME=""
```

Raspberry Pi 上でセットアップを実行します。

```bash
sudo bash scripts/setup-raspi.sh --env ./device.env
```

複数の cellular interface がある場合は、Krypton bootstrap に使う interface を明示できます。

```bash
sudo bash scripts/setup-raspi.sh --env ./device.env --interface wwan1
```

このスクリプトは、概ね次の順番で進みます。

1. NetworkManager / ModemManager などの前提コマンドを確認またはインストールする
2. Soracom Onyx の EG25-G modem を検出する
3. NetworkManager の GSM device ごとに `soracom-<device>` connection profile を作成する
4. SORACOM サービス向け route を追加する
5. SORACOM Air 回線経由で Krypton bootstrap endpoint を呼び出す
6. 取得した AWS IoT 証明書を保存する
7. Greengrass Nucleus を manual provisioning で systemd service として登録する
8. `greengrass.service` が active / enabled になっていることを確認する

## base image を作る

ゼロタッチ配布では、準備用 Raspberry Pi を Ethernet や Wi-Fi でインターネットに出られる状態にして、固定依存を入れます。

```bash
sudo tools/prepare-base-image.sh
```

このコマンドは、Raspberry Pi OS の上で次の処理を行います。

| 処理 | 具体的にやっていること |
|---|---|
| 固定パッケージの導入 | `apt-get update` の後、`ca-certificates`、`curl`、`default-jdk-headless`、`modemmanager`、`network-manager`、`net-tools`、`python3`、`unzip`、`usbutils`、`usb-modeswitch` をインストールする |
| base service の有効化 | `systemctl enable NetworkManager` と `systemctl enable ModemManager` を実行する |
| Greengrass Nucleus の取得 | 既定では AWS が公開している Nucleus zip を `/opt/krgg/greengrass-nucleus.zip` にダウンロードする |
| 前提条件の検査 | `curl`、`ip`、`java`、`lsusb`、`mmcli`、`nmcli`、`python3`、`route`、`unzip`、`usb_modeswitch` が存在するか確認する |
| service 状態の検査 | NetworkManager と ModemManager が enable になっているか確認する |

このスクリプトは、Krypton bootstrap や Greengrass Core の登録は行いません。現地初回起動時にネットワークが不安定でも処理を進められるように、OS イメージ側へ「後で必ず必要になるもの」を先に入れるための工程です。

確認だけを行う場合は以下です。

```bash
tools/prepare-base-image.sh --check-only
```

準備が終わった SD カードを clone または capture し、配布用の base image として扱います。製品運用に近づける場合は、この時点で OS バージョン、追加パッケージ、Greengrass Nucleus のバージョン、作成日時、checksum を manifest として残します。

## boot partition に payload を注入する

base image を Raspberry Pi Imager などで SD カードへ書き込み、Mac や Linux から boot partition に payload を注入します。

```bash
tools/inject-sd.sh --boot /Volumes/bootfs
```

Greengrass Nucleus zip を payload 側に同梱する場合は、次のように指定します。

```bash
tools/inject-sd.sh \
  --boot /Volumes/bootfs \
  --nucleus-zip ./greengrass-nucleus-latest.zip
```

このコマンドは、マウントされた Raspberry Pi の boot partition に対して、次の処理を行います。

| 処理 | 具体的にやっていること |
|---|---|
| payload tarball の作成 | `tools/build-payload.sh` を呼び出し、first boot 用ファイルを `krgg-payload.tgz` として固める |
| setup script の同梱 | `scripts/setup-raspi.sh` を payload 内の `/opt/krgg/setup-raspi.sh` に入れる |
| Onyx setup script の同梱 | payload 内の `/opt/krgg/setup_eg25.sh` を同梱する |
| systemd unit の同梱 | `krgg-provision.service` と `krgg-provision.timer` を payload 内の `/etc/systemd/system/` に入れる |
| Nucleus zip の同梱 | `--nucleus-zip` を指定した場合、payload 内の `/opt/krgg/greengrass-nucleus.zip` にコピーする |
| boot partition への配置 | boot partition に `/krgg/payload.tgz` と `/krgg/firstrun.sh` を置く |
| 起動 hook の追加 | `cmdline.txt` を `cmdline.txt.pre-krgg` にバックアップし、`systemd.run=/boot/firmware/krgg/firstrun.sh` を追加する |
| ディスク反映 | 最後に `sync` して、boot partition への書き込みを反映する |

つまり、`inject-sd.sh` は root filesystem を直接起動して設定するのではなく、boot partition に「初回起動で root filesystem へ展開するための荷物」と「一度だけ実行する hook」を置くスクリプトです。

標準では `cmdline.txt` に一度だけ `firstrun.sh` を起動する hook を追加します。これにより、Raspberry Pi Imager が作った `user-data` を上書きせず、ユーザー作成や Wi-Fi 設定と共存できます。

## 初回起動で何が起きるか

初回起動後の処理は次のように進みます。

1. `cmdline.txt` の `systemd.run` により、boot partition の `/krgg/firstrun.sh` が起動する
2. `firstrun.sh` が `/var/log/krgg-firstrun.log` にログを書きながら、`/krgg/payload.tgz` を `/` に展開する
3. 展開により、`/opt/krgg/firstboot-provision.sh`、`/opt/krgg/setup_eg25.sh`、`/opt/krgg/setup-raspi.sh`、`/etc/systemd/system/krgg-provision.*` が配置される
4. `systemctl daemon-reload` のあと、`krgg-provision.timer` を enable して起動する
5. `firstrun.sh` は `/var/lib/krgg/injected` を作り、`cmdline.txt` から自分自身の hook を削除する
6. timer は起動後 2 分で `krgg-provision.service` を実行し、失敗した場合は 10 分ごとに再試行する
7. `krgg-provision.service` は `/opt/krgg/firstboot-provision.sh` を実行する
8. `firstboot-provision.sh` は `/opt/krgg/device.env` を読み込み、前提コマンドを確認する
9. NetworkManager と ModemManager を enable / start する
10. `setup_eg25.sh` を実行し、`soracom.io` APN の cellular profile と SORACOM サービス向け route を準備する
11. `setup-raspi.sh --env /opt/krgg/device.env` を実行し、Krypton bootstrap と Greengrass manual provisioning を進める
12. 成功すると `/var/lib/krgg/provisioned` を作り、`krgg-provision.timer` を disable する

`device.env` はこの流れの中で必須です。現在のサンプル実装では、`build-payload.sh` は `device.env` を自動では同梱していません。ゼロタッチで完結させるには、payload に `device.env` を含める拡張を入れるか、SD カード書き込み後に root filesystem の `/opt/krgg/device.env` へ配置する運用が必要です。

`--nucleus-zip` は、Nucleus zip を payload に含めるための指定です。`setup-raspi.sh` 側でその zip を確実に使うには、`device.env` で次のように指定します。

```bash
GREENGRASS_NUCLEUS_ZIP_URL="file:///opt/krgg/greengrass-nucleus.zip"
```

この指定をしない場合、`setup-raspi.sh` は既定の URL から Greengrass Nucleus をダウンロードしようとします。現地初回起動で外部ダウンロードに頼りたくない場合は、Nucleus zip の同梱と `device.env` の指定をセットで扱います。

## 動作確認

Raspberry Pi 上では、Greengrass service を確認します。

```bash
systemctl is-active greengrass
systemctl is-enabled greengrass
sudo tail -n 120 /greengrass/v2/logs/greengrass.log
```

AWS 側では、Greengrass Core device を確認します。

```bash
aws greengrassv2 get-core-device \
  --core-device-thing-name <THING_NAME_FROM_KRYPTON> \
  --region ap-northeast-1
```

正常な場合、Core device status は `HEALTHY` になります。

first boot のログを見る場合は、次を確認します。

```bash
sudo cat /var/lib/krgg/last-status
sudo tail -n 200 /var/log/krgg-provision.log
sudo tail -n 120 /var/log/soracom-krypton-greengrass-setup.log
sudo journalctl -u krgg-provision.service -n 120 --no-pager
```

<!-- TODO screenshot: SORACOM group の SoracomKrypton 設定。groupId と credentialsId はマスクする。 -->
<!-- TODO screenshot: AWS IoT Greengrass Core device が HEALTHY になっている画面。Thing 名は記事中の例と合わせる。 -->

## トラブルシュート

### base image missing prerequisites

base image に必要なコマンドが入っていない状態です。`tools/prepare-base-image.sh` を実行した base image を作り直します。

```bash
tools/prepare-base-image.sh --check-only
```

### Onyx setup failed or timed out

modem が見えていない、SIM が挿入されていない、SIM が inactive、radio attach に時間がかかっている、USB 認識が不安定、といった原因が考えられます。

SSH できる場合は、次を確認します。

```bash
lsusb
mmcli -L
nmcli -t -f DEVICE,TYPE dev status
```

### Krypton bootstrap failed

主な原因は次のとおりです。

- SIM が対象 group に所属していない
- SORACOM Krypton group 設定がない
- SORACOM サービス向け route が入っていない
- `policyName`、`credentialsId`、`host` が誤っている
- AWS IoT policy が Greengrass Core に必要な権限を満たしていない

スクリプトは `curl --interface <iface>` で Krypton endpoint を呼び出します。複数 interface がある場合は、`--interface wwan1` のように明示して切り分けます。

### SESSION_TAKEN_OVER が出る

複数台が同じ Thing name または MQTT clientId を使っている可能性があります。ゼロタッチ運用では、`KRYPTON_THING_NAME` を空にし、SORACOM Krypton group の `thingNamePattern` に `$imsi` など SIM ごとに一意な値を含めます。

### greengrass.service is not active

Greengrass Nucleus の起動に失敗しています。AWS IoT policy、token exchange role alias、endpoint、Greengrass config、Nucleus zip、Java runtime を確認します。

```bash
sudo tail -n 200 /greengrass/v2/logs/greengrass.log
sudo journalctl -u greengrass -n 120 --no-pager
```

## まとめ

実装としては、手動検証用の `scripts/setup-raspi.sh` と、ゼロタッチ配布用の `tools/prepare-base-image.sh` / `tools/inject-sd.sh` / systemd timer を分けています。

ポイントは、現地初回起動で package install に頼らないこと、Onyx の APN 設定を Krypton より前に行うこと、Krypton が払い出した証明書を Greengrass manual provisioning に使うこと、失敗時に timer で再試行できるようにすることです。

現状のサンプルは検討用の出発点です。製品運用に近づける場合は、`device.env` の同梱方法、Nucleus zip の固定、base image manifest、image build pipeline、batch 管理まで設計に含める必要があります。

## 参考

https://github.com/takao2704/soracom-onyx-krypton-greengrass-setup

https://users.soracom.io/ja-jp/docs/krypton/aws-iot/

https://docs.aws.amazon.com/greengrass/v2/developerguide/manual-installation.html
