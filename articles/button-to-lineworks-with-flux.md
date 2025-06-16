---
title: "SORACOM ButtonとLINE WORKSをFluxで連携して業務通知を自動化する"
emoji: "🔔"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["soracom", "lineworks", "flux", "iot"]
published: false
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## はじめに

SORACOM Buttonは簡単にIoTシステムを構築できる便利なデバイスですが、単体では通知先が限られています。今回は、SORACOM FluxとLINE WORKS APIを組み合わせることで、ボタンが押されたときに指定したLINE WORKSグループへ自動で通知を送る仕組みを構築してみましょう。

## 実現できること

この記事で構築するシステムでは、以下のようなことが実現できます：

- SORACOM Buttonを押すだけで、LINE WORKSの指定したトークルームにメッセージを送信
- ボタンの種類（シングルクリック、ダブルクリック、ロングプレス）に応じて異なるメッセージを送信
- 押下時刻や場所情報も含めた詳細な通知
- 複数のボタンからの通知を一元管理

### 想定される利用シーン

- **設備点検完了報告**: 現場作業者が点検完了時にボタンを押して報告
- **緊急時の連絡**: 異常発生時にボタンを押して即座にチームに通知
- **在庫補充依頼**: 店舗や倉庫で在庫が少なくなった際の補充依頼
- **会議室利用状況**: 会議室の利用開始・終了をワンプッシュで共有

## 必要なもの

### ハードウェア
- SORACOM Button（LTE-M Button powered by AWS、SORACOM Button Plus等）
- SORACOMのSIMカード（ボタンに内蔵済み）

### サービス・アカウント
- SORACOMアカウント
- LINE WORKSアカウント（管理者権限推奨）
- SORACOM Flux（月額料金が発生します）

### 事前準備
- SORACOM Buttonの初期設定完了
- LINE WORKSでのBot作成とAPI利用設定
- SORACOM Console へのアクセス権限

## 全体の構成

今回構築するシステムの全体像は以下のようになります：

```mermaid
graph TD
    A[SORACOM Button] -->|ボタン押下| B[SORACOM プラットフォーム]
    B --> C[SORACOM Flux]
    C -->|HTTP Request| D[LINE WORKS API]
    D --> E[LINE WORKSトークルーム]
    
    F[管理者] -->|設定| C
    F -->|Bot作成| D
    
    style A fill:#ff9999
    style E fill:#99ff99
    style C fill:#9999ff
```

## STEP 1: SORACOM Buttonの設定

### 1-1. デバイスの登録

まず、SORACOM ButtonをSORACOMアカウントに登録します。

1. [SORACOMコンソール](https://console.soracom.io/)にログイン
2. 左メニューから「デバイス管理」→「デバイス」を選択
3. 「デバイス登録」ボタンをクリック
4. デバイスタイプで「SORACOM Button」を選択
5. デバイスのIMEIやシリアル番号を入力して登録

### 1-2. SIMの確認と設定

SORACOM Buttonには専用のSIMが内蔵されています。

1. 左メニューから「SIM管理」を選択
2. 該当するSIMを見つけて詳細を確認
3. SIMの状態が「アクティブ」になっていることを確認
4. 必要に応じてSIMグループを作成・割り当て

### 1-3. 初回ボタンテスト

1. SORACOM Buttonの電源ボタンを長押しして起動
2. LEDが緑色に点灯することを確認
3. ボタンを1回押してテスト送信
4. SORACOMコンソールの「ログ」でデータ送信を確認

:::message alert
SORACOM Buttonは初回利用時にネットワーク接続の設定が必要な場合があります。LEDの点滅パターンでネットワーク状態を確認してください。
:::

## STEP 2: LINE WORKS Botの作成と設定

### 2-1. LINE WORKS Developer Consoleでの設定

1. [LINE WORKS Developer Console](https://developers.worksmobile.com/)にアクセス
2. 「新しいアプリ」→「Bot」を選択
3. Bot情報を入力：
   - Bot名: 「SORACOM通知Bot」など
   - 説明: 「SORACOM Buttonからの通知を受信」
   - アイコン画像をアップロード（任意）

### 2-2. Bot APIの設定

1. 作成したBotの詳細画面を開く
2. 「Bot設定」タブで以下を設定：
   - **Callback URL**: 後でSORACOM Fluxで設定するため一旦空白
   - **公開設定**: 「特定メンバーのみ利用可能」を選択
3. 「API 2.0」タブで認証情報を取得：
   - **Consumer Key**: 控えておく
   - **Consumer Secret**: 控えておく  
   - **Server API Consumer Key**: 控えておく
   - **Server List ID**: 控えておく

### 2-3. トークルームの準備

1. LINE WORKSアプリで通知を受け取りたいトークルームを作成
2. 作成したBotをトークルームに招待
3. トークルームIDを取得（後の手順で必要）

:::message
トークルームIDの取得方法：
- LINE WORKS Admin: 組織管理 → トーク・ホーム → トークルーム → 該当ルームの詳細から確認
- または、BotにテストメッセージでトークルームIDを表示させる方法もあります
:::

## STEP 3: SORACOM Fluxの設定

### 3-1. Flux アプリの作成

1. SORACOMコンソールの左メニューから「データ処理」→「SORACOM Flux」を選択
2. 「アプリ作成」ボタンをクリック
3. アプリ名を入力（例：「Button-to-LineWorks」）
4. 説明を入力（任意）

### 3-2. フローの構築

SORACOM Fluxでは以下のようなフローを構築します：

```mermaid
graph LR
    A[SORACOM<br/>デバイス] --> B[データ変換<br/>処理]
    B --> C[条件分岐<br/>処理]
    C --> D[LINE WORKS<br/>API呼び出し]
    D --> E[レスポンス<br/>ログ出力]
```

#### 3-2-1. トリガーの設定

1. 「トリガー」として「SORACOM デバイス」を選択
2. トリガー条件を設定：
   - **デバイス**: 登録したSORACOM Buttonを選択
   - **イベント**: 「ボタン押下」を選択

#### 3-2-2. データ変換処理の追加

1. 「処理」→「データ変換」を追加
2. JavaScript処理で受信データを解析：

```javascript
// SORACOM Buttonからのデータを解析
const payload = event.payload;
const deviceId = event.deviceId;
const timestamp = new Date(event.timestamp);

// ボタンの種類を判定
let clickType = '不明';
let message = '';

if (payload.clickType === 1) {
    clickType = 'シングルクリック';
    message = '📍 点検が完了しました';
} else if (payload.clickType === 2) {
    clickType = 'ダブルクリック';  
    message = '⚠️ 異常を検出しました';
} else if (payload.clickType === 3) {
    clickType = 'ロングプレス';
    message = '🚨 緊急事態が発生しました';
}

// LINE WORKS送信用のデータを構築
const lineWorksMessage = {
    content: {
        type: 'text',
        text: `${message}\n\n` +
              `デバイス: ${deviceId}\n` +
              `押下種類: ${clickType}\n` +
              `時刻: ${timestamp.toLocaleString('ja-JP')}`
    }
};

return {
    message: lineWorksMessage,
    deviceId: deviceId,
    clickType: clickType,
    timestamp: timestamp.toISOString()
};
```

#### 3-2-3. LINE WORKS API呼び出し処理

1. 「処理」→「HTTP リクエスト」を追加
2. 以下の設定を行う：

**基本設定:**
- **URL**: `https://www.worksapis.com/v1.0/bots/{BOT_ID}/users/{USER_ID}/messages`
- **メソッド**: POST
- **Content-Type**: application/json

**ヘッダー設定:**
```json
{
  "Authorization": "Bearer {ACCESS_TOKEN}",
  "Content-Type": "application/json"
}
```

**リクエストボディ:**
```json
{
  "content": {
    "type": "text", 
    "text": "{{message.content.text}}"
  }
}
```

:::message
LINE WORKS APIのアクセストークンは事前に取得する必要があります。詳細は次のセクションで説明します。
:::

### 3-3. LINE WORKS APIアクセストークンの取得

LINE WORKS APIを利用するためには、OAuth 2.0認証でアクセストークンを取得する必要があります。

#### 3-3-1. 認証フローの実装

1. **認証用エンドポイントの準備**
   ```bash
   curl -X POST https://auth.worksmobile.com/oauth2/v2.0/token \
   -H "Content-Type: application/x-www-form-urlencoded" \
   -d "grant_type=client_credentials" \
   -d "client_id={Consumer Key}" \
   -d "client_secret={Consumer Secret}" \
   -d "scope=bot"
   ```

2. **レスポンス例**
   ```json
   {
     "access_token": "xxxxxxxxxxxxxx",
     "token_type": "Bearer",
     "expires_in": 3600
   }
   ```

#### 3-3-2. Fluxでの認証処理

SORACOM Fluxでは、認証処理も含めて自動化できます：

```javascript
// 認証トークン取得処理
const getAccessToken = async () => {
    const authUrl = 'https://auth.worksmobile.com/oauth2/v2.0/token';
    const params = new URLSearchParams();
    params.append('grant_type', 'client_credentials');
    params.append('client_id', process.env.LINEWORKS_CLIENT_ID);
    params.append('client_secret', process.env.LINEWORKS_CLIENT_SECRET);
    params.append('scope', 'bot');
    
    const response = await fetch(authUrl, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: params
    });
    
    const data = await response.json();
    return data.access_token;
};

// メイン処理
const accessToken = await getAccessToken();
event.accessToken = accessToken;
return event;
```

## STEP 4: 動作テストと確認

### 4-1. Fluxアプリのデプロイ

1. SORACOM Fluxでフローの構築が完了したら「保存」をクリック
2. 「デプロイ」ボタンでアプリを本番環境にデプロイ
3. デプロイ状況を確認し、エラーがないことを確認

### 4-2. エンドツーエンドテスト

#### テスト手順

1. **SORACOM Buttonを押下**
   - シングルクリック、ダブルクリック、ロングプレスを各1回実行

2. **SORACOM コンソールでログ確認**
   - 「データ処理」→「SORACOM Flux」→該当アプリ
   - 「実行ログ」でデータ処理状況を確認

3. **LINE WORKSで通知確認**
   - 設定したトークルームに通知が届いているか確認
   - メッセージ内容が正しいか確認

#### 期待される通知例

**シングルクリック時:**
```
📍 点検が完了しました

デバイス: button-xxxx-xxxx
押下種類: シングルクリック  
時刻: 2024/12/16 14:30:15
```

**ダブルクリック時:**
```
⚠️ 異常を検出しました

デバイス: button-xxxx-xxxx
押下種類: ダブルクリック
時刻: 2024/12/16 14:31:22
```

**ロングプレス時:**
```
🚨 緊急事態が発生しました

デバイス: button-xxxx-xxxx
押下種類: ロングプレス
時刻: 2024/12/16 14:32:45
```

### 4-3. トラブルシューティング

#### よくある問題と解決方法

**1. SORACOM Buttonからデータが送信されない**
- LEDの点滅パターンを確認
- SIMの状態が「アクティブ」か確認
- ネットワーク接続状況を確認

**2. Fluxでエラーが発生する**
- 実行ログでエラー詳細を確認
- JavaScriptの構文エラーをチェック
- 環境変数が正しく設定されているか確認

**3. LINE WORKSに通知が届かない**
- アクセストークンの有効期限を確認
- Bot権限とトークルーム参加状況を確認
- API URLとパラメータが正しいか確認

**4. 認証エラーが発生する**
- Consumer KeyとSecretが正しいか確認
- OAuth scopeが適切か確認
- トークンの取得処理に問題がないか確認

## 応用例とカスタマイズ

### 5-1. 複数デバイスの管理

複数のSORACOM Buttonを使用する場合の設定例：

```javascript
// デバイスごとの設定
const deviceConfig = {
    'button-office-001': {
        location: '本社1F受付',
        responsible: 'reception-team'
    },
    'button-factory-002': {
        location: '工場A棟',
        responsible: 'factory-team'
    }
};

const config = deviceConfig[event.deviceId] || {
    location: '不明な場所',
    responsible: 'general'
};

const message = `${baseMessage}\n` +
              `場所: ${config.location}\n` +
              `担当: ${config.responsible}`;
```

### 5-2. 時間帯による通知制御

業務時間外の通知を制御する例：

```javascript
const now = new Date();
const hour = now.getHours();
const isBusinessHour = hour >= 9 && hour < 18;

if (!isBusinessHour && payload.clickType !== 3) {
    // 緊急時以外は業務時間外は通知しない
    return { skip: true };
}
```

### 5-3. エスカレーション機能

重要度に応じて通知先を変更する例：

```javascript
let notificationTarget = 'general-room';

if (payload.clickType === 3) {
    // 緊急時は管理者グループに通知
    notificationTarget = 'emergency-room';
} else if (payload.clickType === 2) {
    // 異常時は保守チームに通知  
    notificationTarget = 'maintenance-room';
}
```

## まとめ

この記事では、SORACOM ButtonとLINE WORKSをSORACOM Fluxで連携する方法を詳しく解説しました。

### 構築したシステムの特徴

- **簡単操作**: ボタンを押すだけで通知送信
- **柔軟な通知**: 押下方法に応じてメッセージを変更
- **リアルタイム**: 即座にチーム全体に情報共有
- **拡張性**: 複数デバイス、時間制御、エスカレーション等に対応

### 今後の発展可能性

- **位置情報の活用**: GPS付きButtonで場所情報も通知
- **画像連携**: SoraComカメラとの連携で状況を可視化
- **データ蓄積**: SORACOM Harvestでボタン押下履歴を分析
- **他サービス連携**: Slack、Teams、メール等への同時通知

SORACOM FluxとLINE WORKSの組み合わせにより、従来の業務フローを大幅に効率化できます。ぜひ皆さんの業務でも活用してみてください！

:::message
この記事で紹介した設定や料金は2024年12月時点の情報です。最新の情報は各サービスの公式ドキュメントをご確認ください。
:::
