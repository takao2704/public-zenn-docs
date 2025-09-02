---
title: "VS Code × Python Snowflake Connector ハンズオン：インストールから実務活用まで（Google SSO対応・pandas/SQLAlchemy/Jupyter）"
emoji: "🐍❄️"
type: "tech"
topics: ["snowflake", "python", "vscode", "sqlalchemy", "pandas", "jupyter", "dataengineering"]
published: false
---

本記事は VS Code 上で Python Snowflake Connector（以下、Connector）を用いて Snowflake に接続・操作するためのハンズオンです。インストール、接続（パスワード/Google SSO/キーペア）、pandas/SQLAlchemy との連携、Jupyter 統合、VS Code の便利設定、トラブルシュートまでを一気通貫で解説します。

この記事でできること

- 仮想環境を作成し、Connector と周辺パッケージをインストールできる
- パスワード/Google SSO（externalbrowser）/キーペアで接続できる
- SQL 実行、pandas での入出力、SQLAlchemy Engine の利用ができる
- VS Code から .env/タスク/ノートブックで快適に開発できる
- つまずきやすいポイントの切り分けと対処ができる

対象読者

- Snowflake を Python（スクリプト/Notebook/アプリ）から扱いたい方
- VS Code を日常的に使うデータエンジニア/アナリスト/ML エンジニア
- Python と基本的な SQL が分かる方（入門レベルでOK）

目次

- 前提条件
- 推奨プロジェクト構成
- セットアップ（venv/インストール）
- 接続情報の管理（.env）
- 接続方法
  - パスワード
  - Google SSO（externalbrowser）
  - キーペア（PKCS#8）
- 基本のクエリ実行（Python API）
- pandas 連携（read_sql/write_pandas）
- SQLAlchemy 連携（Engine/Session）
- Jupyter（VS Code 統合）
- VS Code の便利設定（envFile/Tasks）
- トラブルシューティング（詳細）
- セキュリティ運用のメモ
- まとめと次のステップ

前提条件

- Python 3.9–3.12（推奨 3.10+）
- VS Code 最新版と Python 拡張（ms-python.python）
- Snowflake アカウントと必要権限（ROLE/WAREHOUSE/DB/SCHEMA）
- ネットワークから *.snowflakecomputing.com（および OCSP）へ到達可能

推奨プロジェクト構成（例）

```text
your-project/
├── .env                 # 接続情報と可変設定（Git管理しない）
├── .gitignore
├── .vscode/
│   ├── settings.json    # envFile 指定など
│   └── tasks.json       # よく使う処理のワンコマンド化
├── requirements.txt
├── src/
│   ├── main.py
│   ├── sqlalchemy_example.py
│   └── pandas_io.py
└── notebooks/
    └── playground.ipynb
```

セットアップ（venv/インストール）

```bash
# venv 作成と有効化（macOS/Linux）
python3 -m venv .venv
source .venv/bin/activate

# Windows PowerShell
# python -m venv .venv
# .venv\Scripts\Activate.ps1

# 必要パッケージのインストール
pip install --upgrade pip
pip install snowflake-connector-python "sqlalchemy>=2" snowflake-sqlalchemy pandas pyarrow python-dotenv jupyter ipykernel cryptography
```

requirements.txt（任意）

```text
snowflake-connector-python
sqlalchemy>=2
snowflake-sqlalchemy
pandas
pyarrow
python-dotenv
jupyter
ipykernel
cryptography
```

接続情報の管理（.env）

```env
# Snowflake 基本
SNOWFLAKE_ACCOUNT=xy12345.ap-northeast-1     # 必要に応じて .aws など
SNOWFLAKE_USER=YOUR_USER
SNOWFLAKE_PASSWORD=YOUR_PASSWORD             # SSO 利用時は未使用
SNOWFLAKE_ROLE=SYSADMIN
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_DATABASE=DEMO_DB
SNOWFLAKE_SCHEMA=PUBLIC

# Google SSO（externalbrowser）利用時の目印（任意）
SNOWFLAKE_USE_SSO=true

# キーペア利用時のパス（任意）
SNOWFLAKE_PRIVATE_KEY_PATH=/Users/you/.ssh/snowflake_rsa_pk8.pem
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE=
```

.gitignore（抜粋）

```text
.venv/
.env
.ipynb_checkpoints/
```

接続方法

パスワード

```python
import os
from dotenv import load_dotenv
import snowflake.connector as sf

load_dotenv()

conn = sf.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    role=os.getenv("SNOWFLAKE_ROLE"),
    warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
    database=os.getenv("SNOWFLAKE_DATABASE"),
    schema=os.getenv("SNOWFLAKE_SCHEMA"),
)
try:
    cur = conn.cursor()
    cur.execute("select current_version()")
    print(cur.fetchone())
finally:
    cur.close()
    conn.close()
```

Google SSO（externalbrowser）

- ブラウザが自動起動し、Google でサインイン→ VS Code/プロセスへ戻ると接続完了
- 複数の Google アカウントに同時ログインしている場合、Snowflake と紐づくアカウントでログインすること

```python
import os
from dotenv import load_dotenv
import snowflake.connector as sf

load_dotenv()

conn = sf.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    user=os.getenv("SNOWFLAKE_USER"),
    authenticator="externalbrowser",   # ここがポイント
    role=os.getenv("SNOWFLAKE_ROLE"),
    warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
    database=os.getenv("SNOWFLAKE_DATABASE"),
    schema=os.getenv("SNOWFLAKE_SCHEMA"),
)
# 以降はパスワード方式と同様
```

基本のクエリ実行（Python API）

- プレースホルダは「%s」
- fetchone/fetchall、DataFrame 変換（後述）

```python
import snowflake.connector as sf

with sf.connect( ... ) as conn:
    with conn.cursor() as cur:
        cur.execute("use role sysadmin")
        cur.execute("use warehouse compute_wh")
        cur.execute("select current_role(), current_warehouse()")
        print(cur.fetchall())

        # パラメタバインド
        cur.execute(
            "select :1 as id, :2 as name",
            ("1", "snowflake"),  # or cur.execute("select %s, %s", (1, "snowflake"))
        )
        print(cur.fetchone())
```

pandas 連携（read_sql/write_pandas）

```python
import os
import pandas as pd
from dotenv import load_dotenv
import snowflake.connector as sf
from snowflake.connector.pandas_tools import write_pandas

load_dotenv()

with sf.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
    database=os.getenv("SNOWFLAKE_DATABASE"),
    schema=os.getenv("SNOWFLAKE_SCHEMA"),
    role=os.getenv("SNOWFLAKE_ROLE"),
) as conn:
    # 読み取り（簡易）
    cur = conn.cursor()
    cur.execute("select 1 as id, 'a' as name union all select 2, 'b'")
    df = cur.fetch_pandas_all()
    print(df)

    # 書き込み（write_pandas）
    df2 = pd.DataFrame({"id": [1, 2, 3], "name": ["x", "y", "z"]})
    write_pandas(conn, df2, "HELLO", database=os.getenv("SNOWFLAKE_DATABASE"), schema=os.getenv("SNOWFLAKE_SCHEMA"), quote_identifiers=False)
```

SQLAlchemy 連携（Engine/Session）

- 接続 URL 例（パスワード）
  - snowflake://USER:PASSWORD@ACCOUNT/DB/SCHEMA?warehouse=WH&role=ROLE
- Google SSO（externalbrowser）を使う場合は、`authenticator=externalbrowser` を URL のクエリに付与するか、`connect_args` で渡します

```python
import os
from urllib.parse import quote_plus
from sqlalchemy import create_engine, text

ACCOUNT = os.getenv("SNOWFLAKE_ACCOUNT")
USER = os.getenv("SNOWFLAKE_USER")
PWD = quote_plus(os.getenv("SNOWFLAKE_PASSWORD") or "")  # URL エンコード
DB = os.getenv("SNOWFLAKE_DATABASE")
SC = os.getenv("SNOWFLAKE_SCHEMA")
WH = os.getenv("SNOWFLAKE_WAREHOUSE")
ROLE = os.getenv("SNOWFLAKE_ROLE")

# パスワード
engine = create_engine(
    f"snowflake://{USER}:{PWD}@{ACCOUNT}/{DB}/{SC}?warehouse={WH}&role={ROLE}"
)

# externalbrowser（Google SSO）
engine_sso = create_engine(
    f"snowflake://{USER}@{ACCOUNT}/{DB}/{SC}?warehouse={WH}&role={ROLE}&authenticator=externalbrowser"
)

with engine.begin() as conn:
    rows = conn.execute(text("select current_version()")).all()
    print(rows)
```

Jupyter（VS Code 統合）

- 仮想環境を Jupyter カーネルとして登録

```bash
python -m ipykernel install --user --name snowflake-venv --display-name "Python (snowflake-venv)"
```

- VS Code で Notebook を開き、上記カーネルを選択
- .env の読み込みは `python-dotenv` を使用（ノートブックの先頭で）

```python
from dotenv import load_dotenv
load_dotenv()  # .env をカレントから読み込む
```

VS Code の便利設定（envFile/Tasks）

.vscode/settings.json（例）

```json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.envFile": "${workspaceFolder}/.env",
  "terminal.integrated.env.osx": {
    "PYTHONWARNINGS": "ignore"
  }
}
```

.vscode/tasks.json（例）

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Snowflake: run main.py",
      "type": "shell",
      "command": "${workspaceFolder}/.venv/bin/python",
      "args": ["${workspaceFolder}/src/main.py"],
      "problemMatcher": []
    }
  ]
}
```

トラブルシューティング（詳細）

A. アカウント/接続先の誤り（例: 250001）

- 症状: 「Account is invalid」
- 原因: アカウント識別子のリージョン/クラウド表記違い、タイプミス
- 確認:
  - Snowsight のアカウント表記、`xy12345.ap-northeast-1` や `...ap-northeast-1.aws`
- 解決:
  - .env の `SNOWFLAKE_ACCOUNT` を修正し再実行

B. 認証失敗（ユーザー/パスワード/ロック）

- 症状: 「Incorrect username or password」
- 確認:
  - Snowsight で同資格情報でログインできるか
- 解決:
  - パスワードリセット/ロック解除を管理者へ依頼

C. Google SSO/externalbrowser がうまくいかない

- 症状:
  - ブラウザが戻らない、複数 Google アカウントで誤認証、390189（トークン期限）
- 確認:
  - 既定ブラウザのデフォルトアカウントが Snowflake と紐づくものか
  - ポップアップ/Cookie 制限、端末の時刻同期、企業プロキシ/SSL 検査
- 解決:
  - 先に Snowsight で Google SSO ログインを成功させてから再試行
  - 別ブラウザのシークレットモードで拡張を無効化して切り分け
  - 企業プロキシ配下ならネットワークチームにホワイトリスト/リダイレクト許可を依頼

D. キーペア（Incorrect key format/パスフレーズ）

- 確認:
  - 秘密鍵は PKCS#8 か（`BEGIN PRIVATE KEY`）
  - パスフレーズ指定が正しいか
- 変換:
  - 本文の OpenSSL 例を参照

E. SSL/OCSP/ネットワーク

- 症状: タイムアウト、CERTIFICATE_VERIFY_FAILED、OCSP 関連の遅延
- 確認:
  - `nslookup <account>.snowflakecomputing.com`
  - `curl -I https://<account>.snowflakecomputing.com`
  - `curl -I https://ocsp.snowflakecomputing.com`
- 注意:
  - OCSP 無効化は推奨されません（要社内基準）。まずは到達性/プロキシ設定を確認

F. 権限/コンテキスト

- 症状: 「Object does not exist or not authorized」「SQL access control error」
- 診断 SQL:
  - `select current_role(), current_warehouse(), current_database(), current_schema();`
- 対処:
  - `use role ...; use warehouse ...; use database ...; use schema ...;`
  - 必要な権限（USAGE/OPERATE/SELECT 等）を管理者へ依頼

G. SQLAlchemy でオプションが効かない/エラー

- 症状:
  - `authenticator=externalbrowser` が解釈されない、方言エラー
- 対処:
  - snowflake-sqlalchemy / sqlalchemy のバージョン確認・更新
  - URL で渡すか `connect_args={"authenticator": "externalbrowser"}` で渡す

H. pandas で書き込みが遅い/詰まる

- まずは `write_pandas` を優先的に利用（COPY ベースで高速）
- 大量データは外部ステージ + COPY へ設計転換を検討

セキュリティ運用のメモ

- .env は Git 管理しない（.gitignore）。共有は安全な秘匿ストアで
- 本番/開発で Role/WH/DB/Schema を明確に分離（誤操作防止）
- externalbrowser は対話的利用に適合。非対話（バッチ/CI）は OAuth（Refresh Token）やキーペア等を検討

まとめと次のステップ

- Connector の導入から SSO/キーペア、pandas/SQLAlchemy/Jupyter、VS Code 連携、トラブル対応までを整理しました
- 次のステップ
  - src/ に用途別スクリプトを用意（抽出/変換/ロードを分離）
  - notebooks/ でアドホック分析を進め、再利用部分をスクリプトへ昇格
  - CI/CD で環境変数とシークレット管理を整備し、自動実行へ展開