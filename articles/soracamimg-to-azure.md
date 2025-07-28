---
title: "ソラカメ画像自動保存システム - 初心者向けセットアップガイド"
emoji: "📸"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: []
published: false
---

このガイドでは、SORACOM SoraCamの画像を自動的にAzure Data Lake Storageに保存するシステムを、Azure Portalを使って構築する手順を説明します。

## システム構成図

```
ソラカメデバイス → SORACOM API → Azure Functions → Azure Data Lake Storage
```

## 必要な情報

セットアップを開始する前に、以下の情報を準備してください：

### SORACOM情報
- **SORACOM Auth Key ID**: `keyId-xxxxxxxxxx`
- **SORACOM Auth Key**: `secret-xxxxxxxxxx` 
- **SORACOM Device ID**: `xxxxxxxxxx`

## ステップ1: Azure Storage Account の作成

### 1-1. Azure Portalにログイン
1. https://portal.azure.com にアクセス
2. Azureアカウントでログイン

### 1-2. ストレージアカウントの作成
1. Azure Portal上部の検索バーで「ストレージ アカウント」と検索
2. 「ストレージ アカウント」をクリック
![alt text](/images/soracamimg-to-azure/1753710136978.png)
3. 「+ 作成」ボタンをクリック
![alt text](/images/soracamimg-to-azure/1753710215515.png)

### 1-3. 基本設定
以下の通り入力してください：

![alt text](/images/soracamimg-to-azure/1753710538219.png)

| 項目 | 値 |
|------|-----|
| **サブスクリプション** | 使用するサブスクリプションを選択 |
| **リソースグループ** | 新規作成: `soracam-rg` |
| **ストレージアカウント名** | `soracamstorage` + 任意の数字（例：`soracamstorage001`） |
| **地域** | `Japan East` |
| **プライマリ サービス** | `Azure Blob Storage または Azure Data Lake Storage Gen2` |
| **パフォーマンス** | `Standard` |
| **冗長性** | `ローカル冗長ストレージ (LRS)` |

### 1-4. 詳細設定
「詳細」タブで以下を設定：

![alt text](/images/soracamimg-to-azure/1753710601372.png)

| 項目 | 値 |
|------|-----|
| **階層型名前空間を有効にする** | ✅ チェック（重要！） |
| **最小 TLS バージョン** | `バージョン 1.2` |

その他の設定はデフォルトのままでOKです。

### 1-5. 作成完了
1. 「確認および作成」をクリック
2. 検証が完了したら「作成」をクリック
3. デプロイが完了するまで待機（約2-3分）
![alt text](/images/soracamimg-to-azure/1753710681224.png)


### 1-6. コンテナの作成
1. 作成されたストレージアカウントにアクセス
![alt text](/images/soracamimg-to-azure/1753710740093.png)
2. 左メニューの「データストレージ」→「コンテナー」をクリック
![alt text](/images/soracamimg-to-azure/1753710781382.png)
3. 「+ コンテナー」をクリック
4. コンテナー名に `soracam-images` と入力
![alt text](/images/soracamimg-to-azure/1753710849094.png)
5. パブリックアクセスレベルは「プライベート」のまま
6. 「作成」をクリック
![alt text](/images/soracamimg-to-azure/1753710892342.png)

### 1-7. アクセスキーの確認
1. ストレージアカウントで「アクセス キー」をクリック
![alt text](/images/soracamimg-to-azure/1753711230231.png)
2. 「接続文字列」の「表示」をクリック
![alt text](/images/soracamimg-to-azure/1753711303463.png)
3. **key1の接続文字列**をコピーしてメモ帳に保存
   - 形式: `DefaultEndpointsProtocol=https;AccountName=...`

## ステップ2: Azure Functions App の作成

### 2-1. Functions Appの作成
1. Azure Portal上部の検索バーで「関数アプリ」と検索
2. 「関数アプリ」をクリック
3. 「+ 作成」をクリック

### 2-2. 基本設定
以下の通り入力：

| 項目 | 値 |
|------|-----|
| **サブスクリプション** | 同じサブスクリプションを選択 |
| **リソースグループ** | `soracam-rg`（既存を選択） |
| **関数アプリ名** | `soracam-functions` + 任意の数字 |
| **公開** | `コード` |
| **ランタイム スタック** | `Python` |
| **バージョン** | `3.11` |
| **地域** | `Japan East` |

### 2-3. ホスティング設定
「ホスティング」タブで：

| 項目 | 値 |
|------|-----|
| **ストレージ アカウント** | 新規作成（自動生成される名前でOK） |
| **オペレーティング システム** | `Linux` |
| **プラン** | `従量課金 (サーバーレス)` |

### 2-4. 作成完了
1. 「確認および作成」をクリック
2. 「作成」をクリック
3. デプロイが完了するまで待機（約3-5分）

## ステップ3: 環境変数の設定

### 3-1. Functions Appの設定画面へ
1. 作成されたFunctions Appにアクセス
2. 左メニューの「構成」をクリック
3. 「アプリケーション設定」タブを選択

### 3-2. 環境変数の追加
「+ 新しいアプリケーション設定」をクリックして、以下の環境変数を**1つずつ**追加：

#### Azure Storage設定
| 名前 | 値 |
|------|-----|
| `AZURE_STORAGE_CONNECTION_STRING` | ステップ1-7でコピーした接続文字列 |
| `AZURE_STORAGE_CONTAINER_NAME` | `soracam-images` |

#### SORACOM設定
| 名前 | 値 |
|------|-----|
| `USE_SORACOM_API` | `true` |
| `SORACOM_AUTH_KEY_ID` | あなたのSORACAM Auth Key ID |
| `SORACOM_AUTH_KEY` | あなたのSORACAM Auth Key |
| `SORACOM_DEVICE_ID` | あなたのSORACAM Device ID |

### 3-3. 設定の保存
1. すべての環境変数を追加したら「保存」をクリック
2. 「続行」で確定

## ステップ4: Python関数コードの作成

### 4-1. 関数の作成
1. Functions Appで「関数」をクリック
2. 「+ 作成」をクリック
3. 「テンプレートから開発」を選択
4. 「タイマー トリガー」を選択
5. 関数名: `SoraCamFunction`
6. スケジュール: `0 */5 * * * *`（5分間隔）
7. 「作成」をクリック

### 4-2. requirements.txtの設定
1. 作成された関数で「App Serviceエディター」をクリック
2. 左側のファイル一覧で `requirements.txt` をクリック
3. 以下の内容に**置き換え**：

```txt
azure-functions
azure-storage-file-datalake
requests
python-dateutil
```

### 4-3. メイン関数コードの設定
1. `SoraCamFunction` フォルダの `__init__.py` をクリック
2. 以下のコードに**全て置き換え**：

```python
import datetime
import json
import logging
import os
import azure.functions as func
import requests
from azure.storage.filedatalake import DataLakeServiceClient
from typing import Dict, Optional

def main(mytimer: func.TimerRequest) -> None:
    """
    SORACOM SoraCam画像を定期取得してAzure Data Lake Storageに保存
    """
    utc_timestamp = datetime.datetime.utcnow().replace(
        tzinfo=datetime.timezone.utc).isoformat()

    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)
    
    logger.info(f'SoraCam Function開始: {utc_timestamp}')
    
    if mytimer.past_due:
        logger.info('タイマーが遅延しています')

    try:
        logger.info('=== SORACOM画像取得プロセス開始 ===')
        
        # SORACOM認証情報チェック
        required_vars = ['SORACOM_AUTH_KEY_ID', 'SORACOM_AUTH_KEY', 'SORACOM_DEVICE_ID']
        missing_vars = [var for var in required_vars if not os.environ.get(var)]
        
        if missing_vars:
            raise ValueError(f"SORACOM環境変数が不足: {', '.join(missing_vars)}")
        
        # SORACOM APIから画像取得
        image_data = fetch_soracom_image()
        
        # Azure Data Lake Storageに保存
        save_result = save_to_data_lake(image_data)
        
        logger.info('=== 画像保存完了 ===')
        logger.info(f'ファイル: {save_result["file_path"]}')
        logger.info(f'サイズ: {save_result["size"]} bytes')
        
    except Exception as e:
        logger.error(f'エラー発生: {str(e)}')
        raise

def fetch_soracom_image() -> Dict:
    """SORACOM APIから画像を取得"""
    logger = logging.getLogger(__name__)
    
    # SORACOM API認証
    auth_data = {
        "authKeyId": os.environ.get('SORACOM_AUTH_KEY_ID'),
        "authKey": os.environ.get('SORACOM_AUTH_KEY')
    }
    
    # 認証トークン取得
    auth_response = requests.post(
        'https://api.soracom.io/v1/auth',
        json=auth_data,
        headers={'Content-Type': 'application/json'},
        timeout=30
    )
    auth_response.raise_for_status()
    
    token = auth_response.json()['token']
    device_id = os.environ.get('SORACOM_DEVICE_ID')
    
    # 画像エクスポート要求
    export_data = {
        "deviceId": device_id,
        "time": int(datetime.datetime.utcnow().timestamp() * 1000)
    }
    
    export_response = requests.post(
        'https://api.soracom.io/v1/sora_cam/devices/images/exports',
        json=export_data,
        headers={
            'X-Soracom-API-Key': token,
            'Content-Type': 'application/json'
        },
        timeout=30
    )
    export_response.raise_for_status()
    
    export_id = export_response.json()['exportId']
    
    # エクスポート完了待機
    import time
    for attempt in range(10):
        status_response = requests.get(
            f'https://api.soracom.io/v1/sora_cam/devices/images/exports/{export_id}',
            headers={'X-Soracom-API-Key': token}
        )
        status_response.raise_for_status()
        
        status_data = status_response.json()
        if status_data['status'] == 'completed':
            image_url = status_data['url']
            break
        elif status_data['status'] == 'failed':
            raise Exception('SORACOM画像エクスポートが失敗しました')
        
        time.sleep(2)
    else:
        raise Exception('SORACOM画像エクスポートがタイムアウトしました')
    
    # 画像データ取得
    image_response = requests.get(image_url, timeout=30)
    image_response.raise_for_status()
    
    logger.info(f"SORACOM画像取得成功: {len(image_response.content)} bytes")
    
    return {
        'data': image_response.content,
        'size': len(image_response.content),
        'content_type': 'image/jpeg',
        'timestamp': datetime.datetime.utcnow(),
        'source_url': image_url,
        'device_id': device_id
    }

def save_to_data_lake(image_data: Dict) -> Dict:
    """Azure Data Lake Storageに画像を保存"""
    logger = logging.getLogger(__name__)
    
    # Azure Storage接続
    connection_string = os.environ.get('AZURE_STORAGE_CONNECTION_STRING')
    container_name = os.environ.get('AZURE_STORAGE_CONTAINER_NAME')
    
    service_client = DataLakeServiceClient.from_connection_string(connection_string)
    file_system_client = service_client.get_file_system_client(container_name)
    
    # ファイル名生成 (例: 2025/01/28/soracam_20250128_120500_123.jpg)
    timestamp = image_data['timestamp']
    filename = f"soracam_{timestamp.strftime('%Y%m%d_%H%M%S')}_{timestamp.microsecond//1000:03d}.jpg"
    file_path = f"{timestamp.strftime('%Y/%m/%d')}/{filename}"
    
    # メタデータ
    metadata = {
        'capture_time': timestamp.isoformat() + 'Z',
        'content_type': image_data['content_type'],
        'device_id': image_data['device_id'],
        'source': 'soracom_api',
        'file_size': str(image_data['size'])
    }
    
    # ファイルアップロード
    file_client = file_system_client.get_file_client(file_path)
    file_client.upload_data(
        image_data['data'],
        overwrite=True,
        metadata=metadata
    )
    
    logger.info(f"Data Lake Storage保存完了: {file_path}")
    
    return {
        'file_path': file_path,
        'size': image_data['size'],
        'upload_time': datetime.datetime.utcnow().isoformat()
    }
```

### 4-4. コードの保存
1. `Ctrl + S` でファイルを保存
2. 画面上部の「保存」ボタンもクリック

## ステップ5: 動作確認

### 5-1. 関数の手動実行
1. 関数一覧で `SoraCamFunction` をクリック
2. 「テスト/実行」をクリック
3. 「実行」をクリック
4. ログを確認（実行には30秒程度かかります）

### 5-2. 実行ログの確認
1. 「監視」タブをクリック
2. 最新の実行結果を確認
3. 緑色のチェックマークが表示されれば成功

### 5-3. 保存された画像の確認
1. ストレージアカウントにアクセス
2. 「Data Lake Gen2」→「コンテナー」
3. `soracam-images` をクリック
4. `2025/01/28/` のようなフォルダ構造で画像が保存されていることを確認

## ステップ6: 自動実行の確認

### 6-1. スケジュール実行の確認
- 関数は5分間隔で自動実行されます
- 次回実行時刻は「概要」タブで確認できます

### 6-2. 継続監視
1. 「監視」→「ログ」で実行履歴を確認
2. エラーがある場合は「Application Insights」でデバッグ

## トラブルシューティング

### よくある問題と解決方法

#### 1. 「SORACOM環境変数が不足」エラー
- ステップ3の環境変数設定を再確認
- 名前と値にタイプミスがないかチェック

#### 2. 「認証エラー」
- SORACOM Auth Key ID/Keyが正しいかSORACOMコンソールで確認
- デバイスIDが正しいか確認

#### 3. 「Azure Storage接続エラー」
- ストレージアカウントの接続文字列を再確認
- コンテナ名が `soracam-images` で正しいか確認

#### 4. 関数がタイムアウトする
- Azure Portal の関数設定で「タイムアウト」を10分に延長

## 完了！

これで、ソラカメの画像が5分間隔で自動的にAzure Data Lake Storageに保存されるシステムが完成しました。

### システムの特徴
- ✅ 完全自動化（手動操作不要）
- ✅ サーバーレス（サーバー管理不要）
- ✅ 高可用性（Azure基盤）
- ✅ コスト最適化（従量課金）
- ✅ 画像の整理（年/月/日フォルダ構造）

何か問題が発生した場合は、Azure Portalの「監視」機能でログを確認してください。