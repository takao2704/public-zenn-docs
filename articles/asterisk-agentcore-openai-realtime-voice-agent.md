---
title: "【実装編】AsteriskとAgentCoreでSORACOMに答える日本語電話AIを動かす"
emoji: "☎️"
type: "tech"
topics: [asterisk, aws, agentcore, openai, mcp]
published: false
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

:::message
この記事は2026年7月時点の検証結果をもとにしています。利用できるモデル、API、料金、サービス仕様は変更される可能性があるため、実装時は各サービスの公式ドキュメントも確認してください。
:::

:::message alert
本記事の手順では、Amazon EC2、Amazon Bedrock AgentCore Runtime、OpenAI Realtime APIなどの料金が発生します。作成前に各サービスの最新料金を確認し、検証後は「後片付け」の手順で不要なリソースを削除してください。
:::

## TL;DR

- EC2へAsteriskとPython製Media Bridgeを配置し、スマートフォンからAI用内線`7000`へ発信できるようにします。
- Amazon Bedrock AgentCore Runtime上でOpenAI GPT-Realtime-2.1を動かし、日本語音声とSORACOM Knowledge MCPの3ツールを接続します。
- デプロイ、SIP設定、通話試験に加え、実機で起きた回り込みと回答の途中切れへの対処まで扱います。

## はじめに

今回作ったのは、スマートフォンのソフトフォンから内線`7000`へ電話すると、日本語のAIが応答するデモです。SORACOMについて聞くと、必要なときだけ公式ドキュメントを検索して答えます。

各コンポーネントの役割と、通話からツール呼び出しまでの流れは[アーキテクチャ編](/articles/asterisk-agentcore-realtime-architecture)へ分けました。こちらはデプロイから通話試験までの記録です。

1台のEC2上にAsteriskとMedia Bridgeを置き、スマートフォンのSIPソフトフォンからAI用内線へ発信します。日本語の音声対話、SORACOM Knowledge MCPの呼び出し、スピーカーフォンでの回り込み対策までが対象です。

SIPトランク、既存PBXとの接続、冗長化、同時通話の負荷試験、有人転送は今回試していません。

## 実装する構成

音声は次の経路を往復します。

```text
スマートフォン
  ↕ SIP / RTP
Asterisk on EC2
  ↕ WebSocket / 16 kHz PCM
Media Bridge
  ↕ SigV4 WebSocket
AgentCore Runtime
  ↕ 音声イベント、ツール呼び出し
OpenAI Realtime / SORACOM Knowledge MCP
```

Asteriskは電話を終端し、Media Bridgeは音声形式とWebSocketを中継します。AgentCore Runtimeは通話ごとのエージェントをホストし、RealtimeモデルとMCPツールを接続します。

## 事前準備

検証環境です。

| 項目 | 検証条件 |
|---|---|
| AWSリージョン | `ap-northeast-1` |
| PBX | Ubuntu 24.04、EC2 `t3.small`、Asterisk 22.10.1 |
| AgentCore CLI | `bedrock-agentcore-starter-toolkit==0.1.25` |
| Python | 3.12 |
| 音声モデル | `gpt-realtime-2.1`、音声`cedar` |
| 電話側 | スマートフォンのSIPソフトフォン、スピーカーフォンを有効化 |

端末機種とソフトフォンの種類は検証記録に残していません。後述する回り込み回数はこの環境での観測値であり、別の端末でも同じ値になるとは限りません。

ほかに、AWSアカウント、OpenAI APIを利用できるプロジェクト、AgentCore Runtimeを作成・呼び出しできるIAM権限が必要です。

[`chan_websocket`の公式ドキュメント](https://docs.asterisk.org/Configuration/Channel-Drivers/WebSocket/)によると、ドライバー自体はAsterisk 20.16.0、21.11.0、22.6.0、23.0.0以降で利用できます。JSON形式の制御イベントを使えるのは、20.18.0、22.8.0、23.2.0以降です。

:::message alert
SIPの5060/UDPやRTPのポート範囲を`0.0.0.0/0`へ公開しないでください。接続元のソフトフォン、SIPトランク、SBCのアドレス範囲だけをSecurity Groupで許可します。Media Bridgeの待ち受けポートはAsteriskと同じEC2の`127.0.0.1`だけにバインドします。
:::

## ステップ1: AgentCoreへ音声エージェントをデプロイする

### OpenAI APIキーをAgentCore Identityへ保存する

OpenAI APIキーはリポジトリやEC2の環境変数へ置かず、AgentCore IdentityのAPI key credential providerへ保存します。
ここではprovider名を`openai-realtime`とします。

作成方法は[`AgentCore IdentityのCredential provider設定`](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/resource-providers.html)を参照してください。コンソールでproviderを作成し、OpenAI APIキーを登録します。実行ロールには、作成されたproviderとその裏側のSecrets Manager secretだけを取得できる権限を付けます。

ローカル開発時だけ`OPENAI_API_KEY`を参照し、デプロイ後は`OPENAI_API_KEY_PROVIDER_NAME`からIdentityを使う実装にしました。

```python
async def resolve_openai_api_key() -> str:
    local_key = os.getenv("OPENAI_API_KEY", "").strip()
    if local_key:
        return local_key

    provider_name = os.environ["OPENAI_API_KEY_PROVIDER_NAME"]

    @requires_api_key(provider_name=provider_name, into="api_key")
    async def get_identity_api_key(*, api_key: str) -> str:
        return api_key

    return await get_identity_api_key()
```

### Realtimeモデルを構成する

モデルには`gpt-realtime-2.1`、音声には`cedar`を指定しました。
日本語での入力と応答を実通話で確認しています。

```python
model = BidiOpenAIRealtimeModel(
    model_id="gpt-realtime-2.1",
    client_config={"api_key": api_key},
    provider_config={
        "audio": {
            "input_rate": 24_000,
            "output_rate": 24_000,
            "channels": 1,
            "format": "pcm",
            "voice": "cedar",
        },
        "inference": {
            "tool_choice": "auto",
            "max_output_tokens": 2048,
        },
    },
)
```

日本語のsystem promptには、言語を切り替える条件まで書きました。

```text
- 応答は必ず日本語のみで行う
- 英語で話しかけられても、英語応答を明示的に求められない限り日本語で答える
- 名前、住所、単独の外国語、アクセントだけを理由に英語へ切り替えない
- 聞き取れないときは、推測して別言語で答えず日本語で聞き返す
- ツール利用中の案内、ツール結果、最終回答も日本語にする
```

電話ではURLや長い箇条書きを目で追えません。回答の長さと話す順序も指定しました。

```text
- 簡単な質問は1〜2文で答える
- 結論や直接の答えから話す
- 長い回答は重要な点を最大3つに絞る
- 収まりきらない場合は自然な文で締め、続きが必要か確認する
- URL、JSON、内部的なツール名を読み上げない
```

### AgentCore Runtimeへデプロイする

この記事で使った`configure`と`launch`は、AgentCore Starter Toolkit 0.1.25のコマンドです。CLIの世代によってコマンド体系が異なるため、同じ手順を再現するときはバージョンを固定します。

```bash
python3 -m pip install \
  'bedrock-agentcore-starter-toolkit==0.1.25'

agentcore configure \
  --entrypoint agent/voice_agent.py \
  --name voip_realtime_agent \
  --requirements-file agent/requirements.txt \
  --disable-memory \
  --disable-otel \
  --region ap-northeast-1 \
  --protocol HTTP \
  --non-interactive

agentcore launch \
  --agent voip_realtime_agent \
  --env OPENAI_API_KEY_PROVIDER_NAME=openai-realtime \
  --env MODEL_ID=gpt-realtime-2.1 \
  --env VOICE_ID=cedar
```

WebSocketはHTTP Upgradeから開始するため、AgentCore CLIのprotocolには`HTTP`を指定します。
デプロイ完了後に表示されるRuntime ARNは、次のMedia Bridge設定で使います。

状態はCLIで確認できます。

```bash
agentcore status --agent voip_realtime_agent
```

Runtime ARNやAWSアカウントIDは公開せず、`READY`になったことだけを確認します。

## ステップ2: EC2へAsteriskとMedia Bridgeを配置する

このPoCでは、Ubuntu 24.04のEC2へAsteriskとPython製Media Bridgeを同居させました。
Media Bridgeは`127.0.0.1:8787`でAsteriskからの接続を待ち受けます。

実装一式は[サンプルリポジトリ](https://github.com/takao2704/voice-agent-demo)に置いています。

### EC2を作成する

リポジトリを取得し、利用者の現在のグローバルIPアドレスだけにSIPとRTPを許可してCloudFormation stackを作ります。`RuntimeArn`には前のステップで得たARNを指定します。

```bash
git clone https://github.com/takao2704/voice-agent-demo.git
cd voice-agent-demo

aws ssm put-parameter \
  --region ap-northeast-1 \
  --name /voice-agent-demo/sip/6001/password \
  --type SecureString \
  --value "$(openssl rand -base64 32)" \
  --overwrite

aws cloudformation deploy \
  --region ap-northeast-1 \
  --stack-name voice-agent-demo-pbx \
  --template-file infra/pbx-stack.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    AllowedClientCidr='<YOUR_PUBLIC_IP>/32' \
    InstanceType=t3.small \
    RuntimeArn='<AGENTCORE_RUNTIME_ARN>' \
    SubnetId='<PUBLIC_SUBNET_ID>' \
    VpcId='<VPC_ID>'
```

stackの出力からEC2のinstance IDとElastic IPを取得します。

```bash
PBX_INSTANCE_ID="$(
  aws cloudformation describe-stacks \
    --region ap-northeast-1 \
    --stack-name voice-agent-demo-pbx \
    --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue | [0]' \
    --output text
)"

aws cloudformation describe-stacks \
  --region ap-northeast-1 \
  --stack-name voice-agent-demo-pbx \
  --query 'Stacks[0].Outputs[?OutputKey==`ElasticIp`].OutputValue | [0]' \
  --output text
```

### AsteriskとMedia Bridgeをインストールする

SSHは開けず、AWS Systems Manager Session Managerで接続します。

```bash
aws ssm start-session \
  --region ap-northeast-1 \
  --target "$PBX_INSTANCE_ID"
```

EC2へ入ったら、リポジトリのインストーラーを実行します。Asterisk 22.10.1のbuild、PJSIP、Media Bridge、systemd unitの設定まで行います。

```bash
sudo git clone \
  https://github.com/takao2704/voice-agent-demo.git \
  /opt/voip-agent

sudo env \
  AWS_REGION=ap-northeast-1 \
  RUNTIME_ARN='<AGENTCORE_RUNTIME_ARN>' \
  SIP_PASSWORD_PARAMETER=/voice-agent-demo/sip/6001/password \
  /opt/voip-agent/deploy/install-pbx.sh
```

インストーラーはAsteriskとMedia Bridgeを同じEC2に置き、Media Bridgeの待ち受けをloopbackに限定します。

```ini
AGENTCORE_RUNTIME_ARN=arn:aws:bedrock-agentcore:ap-northeast-1:<AWS_ACCOUNT_ID>:runtime/<RUNTIME_ID>
AWS_REGION=ap-northeast-1
MODEL_ID=gpt-realtime-2.1
VOICE_ID=cedar
MAX_OUTPUT_TOKENS=2048
BRIDGE_HOST=127.0.0.1
BRIDGE_PORT=8787
LOG_LEVEL=INFO
LOG_TRANSCRIPTS=false
HALF_DUPLEX_MODE=true
HALF_DUPLEX_RELEASE_MS=800
```

EC2のinstance roleには、対象RuntimeとRuntime endpointに対する呼び出し権限を付与します。
CloudFormation templateは、通話ごとのユーザーコンテキストを渡すために次の2つのactionだけを対象Runtimeへ許可します。

```json
{
  "Effect": "Allow",
  "Action": [
    "bedrock-agentcore:InvokeAgentRuntimeWithWebSocketStream",
    "bedrock-agentcore:InvokeAgentRuntimeWithWebSocketStreamForUser"
  ],
  "Resource": [
    "arn:aws:bedrock-agentcore:ap-northeast-1:<AWS_ACCOUNT_ID>:runtime/<RUNTIME_ID>",
    "arn:aws:bedrock-agentcore:ap-northeast-1:<AWS_ACCOUNT_ID>:runtime/<RUNTIME_ID>/runtime-endpoint/*"
  ]
}
```

Media Bridgeは通話ごとにUUIDを生成し、AgentCoreのsession IDとRuntime user IDに同じ値を使います。

```python
session_id = str(uuid.uuid4())
ws_url, headers = runtime_client.generate_ws_connection(
    runtime_arn=runtime_arn,
    session_id=session_id,
)
headers["X-Amzn-Bedrock-AgentCore-Runtime-User-Id"] = session_id
```

## ステップ3: AsteriskからMedia Bridgeへ接続する

`websocket_client.conf`に、通話ごとに作るWebSocket接続を定義します。

```ini
[voice_agent]
type = websocket_client
connection_type = per_call_config
uri = ws://127.0.0.1:8787/media
protocols = media
connection_timeout = 1000
reconnect_interval = 500
reconnect_attempts = 3
tls_enabled = no
```

AI用の内線`7000`では、`slin16`を指定してMedia Bridgeへ接続します。

```ini
[from-internal]
exten = 7000,1,NoOp(Voice agent demo)
 same = n,Answer()
 same = n,Dial(WebSocket/voice_agent/c(slin16)f(json))
 same = n,Hangup()
```

制御イベントはJSONにします。

```ini
[global]
control_message_format = json
```

Asteriskから受けるイベントと処理を対応させます。

| イベント | Media Bridgeの処理 |
|---|---|
| `MEDIA_START` | `slin16`と640 byteフレームを確認 |
| `MEDIA_XOFF` | Asteriskへの音声送信を一時停止 |
| `MEDIA_XON` | 音声送信を再開 |
| `DTMF_END` | 押された番号をログへ記録 |

`slin16`は、16 kHz、16 bit、モノラルの符号付きリニアPCMです。Media Bridgeはモデルから届く任意長のPCMを、20 msに相当する640 byte単位へそろえてAsteriskへ返します。端数は最後に無音で埋めます。AgentCoreアプリケーションでは、OpenAI Realtimeに合わせて16 kHzと24 kHzを相互変換します。

モデルが割り込まれたら、すでにAsteriskへ積まれた音声を`FLUSH_MEDIA`で破棄します。
古い回答をキューに残したままだと、次の発話へ重なってしまいます。

## ステップ4: SORACOM Knowledge MCPを追加する

3つのツールの使い分けと、外部検索へ渡さない情報は[アーキテクチャ編](/articles/asterisk-agentcore-realtime-architecture)に書きました。AgentCoreアプリケーションから接続する主要部分は次のコードです。

[SORACOM Knowledge MCPサーバーのツール一覧](https://users.soracom.io/ja-jp/tools/soracom-knowledge-mcp-server/tools/)では、次の3つが読み取り専用で公開されています。

| ツール | 用途 |
|---|---|
| `search_soracom_docs` | サービスガイド、操作手順、料金、IoTレシピの検索 |
| `search_api_docs` | API、CLI、SAM権限の検索 |
| `get_document` | 検索結果URLの全文取得 |

AgentCoreアプリケーションからMCPのStreamable HTTP transportへ接続し、必要なツールだけを呼びます。以下は接続処理の主要部分です。

```python
import httpx


def _http2_client(headers=None, timeout=None, auth=None):
    return httpx.AsyncClient(
        headers=headers,
        timeout=timeout,
        auth=auth,
        follow_redirects=True,
        http2=True,
    )


async with streamablehttp_client(
    "https://knowledge-mcp.soracom.com",
    httpx_client_factory=_http2_client,
) as (read_stream, write_stream, _):
    async with ClientSession(read_stream, write_stream) as session:
        await session.initialize()
        result = await session.call_tool(
            "search_soracom_docs",
            arguments={
                "query": "SORACOM Airの概要",
                "search_mode": "hybrid",
                "language": "Japanese",
                "max_results": 5,
            },
        )
```

音声で聞いた値をそのまま外部検索へ送ると、SIM ID、IMSI、電話番号、メールアドレス、APIキーなどが混ざるおそれがあります。
検索前に代表的な識別子パターンを検出して拒否し、具体的な値を除いた質問へ言い換えるよう返します。

:::message alert
SORACOM Knowledge MCPはAgentCore Runtimeの外部にある公開endpointです。正規表現による検査は補助策であり、ハイフン、空白、日本語数字などを含むあらゆる表記を防ぐDLPではありません。実際のSIM ID、IMSI、電話番号、メールアドレス、アカウントID、APIキー、token、passwordは話さないでください。
:::

また、Realtimeのコンテキストを検索結果で埋めないよう、検索結果は最大5件、抜粋は1件あたり最大1,600文字へ縮めています。
`get_document`で取得できるURLもSORACOM公式ドメインのHTTPSだけに制限しました。

エージェントへ登録するツールは3つです。

```python
AGENT_TOOLS = [
    search_soracom_docs,
    search_api_docs,
    get_document,
]
```

たとえば「SORACOM Airとは何ですか」と話すと、Realtimeモデルが`search_soracom_docs`を選びます。
検索結果だけで足りなければ`get_document`で本文を取得し、電話向けの日本語にまとめて読み上げます。
固定の検索手順ではなく、モデルが質問を見て検索と全文取得を選ぶAgentic RAGとして動かしています。

## 動作確認

### オフラインテスト

音声フレーム、半二重ゲート、MCP入力検査、Realtime設定を外部サービスへ接続せずテストします。
`requirements-dev.txt`からAgentCore、Media Bridge、テスト用の依存関係をまとめて入れます。

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
pytest -q
```

検証時点では29件のテストが成功しました。

### 通話テスト

ローカル端末でSIP passwordを取得します。値は画面共有、shell history、記事、ログへ残さないでください。

```bash
aws ssm get-parameter \
  --region ap-northeast-1 \
  --name /voice-agent-demo/sip/6001/password \
  --with-decryption \
  --query Parameter.Value \
  --output text
```

ソフトフォンへ設定する値です。

| 項目 | 値 |
|---|---|
| SIP server | CloudFormation outputの`ElasticIp` |
| Transport | UDP |
| Port | `5060` |
| User | `6001` |
| Password | SSM Parameter Storeから取得した値 |
| 発信先 | `7000` |

登録後、内線`7000`へ発信します。

まず日本語の音声応答を確認し、そのあとMCPを使う質問を試します。

```text
こんにちは。何ができますか。
```

```text
SORACOM Airとは何ですか。
```

ログは次の順で追いました。

1. Asteriskから`MEDIA_START`が届く
2. AgentCore WebSocketが接続される
3. OpenAI Realtimeの認証が成功する
4. 音声transcriptが生成される
5. 必要な場合だけtool useが始まる
6. 日本語音声がAsteriskへ戻る
7. `stop_reason=complete`で応答が完了する

デプロイ後のRuntimeへ「SORACOM Airとは何ですか」という合成音声を直接送り、transcriptを表示せず主要イベントだけを抜粋しました。`tool_use_stream`のあとに7.1秒の日本語音声が返り、応答は`complete`で終了しました。

```json
{
  "major_event_types": [
    "bidi_response_start",
    "bidi_audio_stream",
    "tool_use_stream",
    "bidi_response_complete"
  ],
  "audio_seconds": 7.1,
  "stop_reason": "complete"
}
```

同じ呼び出しのCloudWatch Logsです。時刻とresponse IDは省略しています。

```text
Voice session connected
Realtime response finished status=completed reason=none output_tokens=262 max_output_tokens=2048
```

## 実装中に分かったこと

### プロンプトの秒数指定は技術上限ではない

電話では回答が長すぎると待ち時間が増えます。
一方、`max_output_tokens`を小さくしすぎると文の途中で音声が止まります。

同じAI解説の質問をデプロイ済みRuntimeへ1回ずつ送り、返ってきた16 kHz、16 bit、モノラルPCMのbyte数から発話時間を計算しました。この比較は回答品質の統計評価ではなく、文中停止の原因を切り分けるための確認です。

| 設定 | 発話時間 | 終了理由 | 結果 |
|---|---:|---|---|
| `MAX_OUTPUT_TOKENS=1024` | 38.7秒 | `interrupted` | 文の途中で停止 |
| `MAX_OUTPUT_TOKENS=2048`と短話プロンプト | 37.5秒 | `complete` | 自然な文末で完了 |

プロンプトで目指す長さと、応答ごとに設定する出力上限は分けました。

- プロンプトでは、簡単な質問は1〜2文、長い回答は最大3点を目安にします。
- `MAX_OUTPUT_TOKENS=2048`は、モデルが少し長く話したときの安全余裕として使います。
- `response.done`のstatus、reason、output token数をログへ残します。

トークン上限へ到達しても、次の応答が自動的に続きを話すわけではありません。
途中停止をログで見分けられるようにし、上限には余裕を持たせました。

### スピーカーフォンでは回り込みが起きる

全二重の状態でスマートフォンをスピーカー通話にすると、AIの音声を端末のマイクが拾い、ユーザーの発話として再認識することがありました。
スピーカーフォンを有効にした約2分間の1通話では、31回の割り込みと音声キューのflushが発生しました。端末機種とソフトフォンの条件を記録していないため、これは今回のPoCで原因を見つけた観測値として扱い、一般的な性能値にはしません。

デモではAIが話している間だけ入力を止める半二重モードを追加しました。

```ini
HALF_DUPLEX_MODE=true
HALF_DUPLEX_RELEASE_MS=800
```

AIの応答完了後も800 ms待ってから入力を再開し、端末側に残った音の減衰を待ちます。

半二重では、AIの発話中に利用者が割り込むbarge-inが使えません。
半二重を採用するかは、電話端末やSBCのエコーキャンセル品質と、barge-inが必要かどうかで決めます。

## トラブルシュート

| 症状 | 確認する境界 |
|---|---|
| `MEDIA_START`が来ない | Asteriskのmodule、dialplan、WebSocket設定 |
| `MEDIA_START`後にAgentCoreへ接続できない | EC2 role、Runtime ARN、リージョン、WSSの外向き通信 |
| AgentCore接続直後に失敗する | Identity provider名、OpenAI APIキー、実行ロール |
| transcriptは出るが電話へ音が戻らない | 16/24 kHz変換、PCMフレーム、Asteriskの`MEDIA_XOFF` |
| ツール利用時に長く無音になる | MCP/APIのtimeout、外部API応答、ツール結果サイズ |
| 文の途中で止まる | `response.done`のstatus、reason、`max_output_tokens` |
| スピーカー通話で連続割り込みになる | 回り込み、半二重設定、端末のエコーキャンセル |

Bridgeのログは次のコマンドで確認します。

```bash
journalctl -u voip-agent-bridge -f
```

Asterisk側はCLIで確認します。

```bash
sudo asterisk -rvvv
```

AgentCore Runtimeのロググループ名は次の形式です。

```text
/aws/bedrock-agentcore/runtimes/<RUNTIME_ID>-DEFAULT
```

会話transcriptには個人情報が含まれる可能性があります。
通常は`LOG_TRANSCRIPTS=false`とし、制御されたデバッグ通話だけ一時的に有効化します。

## 後片付け

AgentCore Runtimeは、削除対象をdry runで確認してから削除します。

```bash
agentcore destroy \
  --agent voip_realtime_agent \
  --dry-run

agentcore destroy \
  --agent voip_realtime_agent
```

PBX用stackとSIP passwordも削除します。

```bash
aws cloudformation delete-stack \
  --region ap-northeast-1 \
  --stack-name voice-agent-demo-pbx

aws cloudformation wait stack-delete-complete \
  --region ap-northeast-1 \
  --stack-name voice-agent-demo-pbx

aws ssm delete-parameter \
  --region ap-northeast-1 \
  --name /voice-agent-demo/sip/6001/password
```

CloudFormation templateのS3 artifact bucketは誤削除を防ぐため`Retain`にしています。不要なら中身が空であることを確認して、`voice-agent-demo-deploy-<AWS_ACCOUNT_ID>-ap-northeast-1`も削除します。AgentCore IdentityのAPI key credential providerと、そのために作られたsecretも、ほかのRuntimeから使っていないことを確認して削除します。

## 本番化する前に必要なこと

今回作ったのは、1台のPBXと1つのAI内線を使うPoCです。
まだ次の機能や検証がありません。

- 同時通話数と負荷試験
- SIPトランクや既存PBXとの接続条件
- AgentCore、OpenAI Realtime、EC2、通話回線のコスト
- ツールごとのtimeout、再試行、circuit breaker
- 録音や文字起こしの告知、同意、保存期間
- PIIのマスキングと監査ログ
- AIが応答できない場合の有人転送
- DTMFによるメニューや緊急離脱
- 電話番号、内線、顧客情報と会話セッションの対応づけ

有人転送は優先して追加したい機能です。
AIが止まったときに通常の内線やフロントへ戻せないと、電話システムとしては使えません。

## まとめ

内線`7000`へ電話して日本語で会話し、必要なときだけSORACOM Knowledge MCPを呼ぶところまで動かせました。

最初に音声が往復したあと、実際に時間を使ったのはスピーカーフォンの回り込みと、長い回答の途中切れです。
どちらもプロンプトだけでは直りませんでした。
前者は半二重の入力制御、後者は`response.done`の終了理由を見ながら出力上限を調整して対応しています。

電話、Media Bridge、AgentCore、Realtimeを一気にデバッグするのはつらいです。`MEDIA_START`、AgentCore接続、transcript、tool use、音声出力、`response.done`の順にログを追うようにしてから、止まった場所を切り分けやすくなりました。

構成を分けた理由と、通話からMCP回答までの流れは[アーキテクチャ編](/articles/asterisk-agentcore-realtime-architecture)に書いています。

## 参考資料

- [Asterisk WebSocket channel driver](https://docs.asterisk.org/Configuration/Channel-Drivers/WebSocket/)
- [Amazon Bedrock AgentCore - WebSocketによる双方向ストリーミング](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/runtime-get-started-websocket.html)
- [Amazon Bedrock AgentCore - Credential providerの設定](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/resource-providers.html)
- [OpenAI Realtime conversations](https://developers.openai.com/api/docs/guides/realtime-conversations)
- [OpenAI GPT-Realtime-2.1](https://developers.openai.com/api/docs/models/gpt-realtime-2.1)
- [SORACOM Knowledge MCPサーバーで利用できるツール](https://users.soracom.io/ja-jp/tools/soracom-knowledge-mcp-server/tools/)
- [サンプルリポジトリ: takao2704/voice-agent-demo](https://github.com/takao2704/voice-agent-demo)
