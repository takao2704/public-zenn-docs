---
title: "VS Code × Snowflake CLI ハンズオン：インストールから実運用まで（詳解トラブルシュート付き）"
emoji: "🧊"
type: "tech"
topics: ["snowflake", "cli", "vscode", "sql", "dataengineering"]
published: false
---

本記事は VS Code から Snowflake CLI（以下、Snowflake CLI または `sf`）を用いて Snowflake を操作するためのハンズオンです。インストール、接続設定（config.toml）、基本操作、VS Code 連携、実践例（スクリプト/データロードのパターン解説）に加えて、詰まりやすいポイントを網羅したトラブルシューティングを収録しています。

この記事でできること

- Snowflake CLI を Homebrew / pipx でインストールできる
- config.toml で接続プロファイルを作成し、接続テストできる
- `sf sql` で SQL を実行し、ファイルからの一括実行ができる
- VS Code のターミナル/タスクから CLI を快適に使える
- よくあるエラーの原因切り分けと対処ができる

対象読者

- これから Snowflake を CLI/自動化で扱いたい開発者/データエンジニア
- VS Code を日常的に使う方
- SQL の基礎がある方（入門レベルでOK）

目次

- 前提条件
- 画像フォルダ構成
- インストール（推奨2パターン）
- 初期設定（~/.snowflake/config.toml）
- 基本の使い方（sf sql）
- VS Code からの活用（統合ターミナル/タスク）
- 実践的な使用例（スクリプト化・データロードの考え方）
- トラブルシューティング（詳細）
- まとめと次のステップ

前提条件

- OS: macOS / Windows / Linux（本記事のコマンド例は主に macOS）
- VS Code 最新版（1.85+ を推奨）
- Snowflake アカウント（トライアル可）
- ネットワークから Snowflake へ疎通可能であること（社内プロキシ/SSL検査等に注意）

画像フォルダ構成（任意）

```text
images/snowflake-cli/
├── install/
├── config/
├── usage/
└── vscode/
```

インストール（推奨2パターン）

A) Homebrew（macOS 推奨）

```bash
# Homebrew が未導入の場合は公式手順で導入してから
brew update
brew install snowflake/snowflake/snowflake-cli

# 動作確認
sf --version
```

B) pipx（クロスプラットフォームで隔離導入）

```bash
# pipx が未導入の場合
python3 -m pip install --user pipx
python3 -m pipx ensurepath

# Snowflake CLI の導入
pipx install snowflake-cli

# 動作確認
sf --version
```

メモ

- 既存の「SnowSQL（snowsql）」とは別製品です。本記事は `sf`（Snowflake CLI）を対象とします
- Windows の場合は winget/choco などの配布手段もあります。環境に合わせて導入してください

初期設定（~/.snowflake/config.toml）

Snowflake CLI はデフォルトで `~/.snowflake/config.toml` を参照します。複数接続をプロファイルとして定義できます。

最小構成（パスワード認証の例）

```toml
# ~/.snowflake/config.toml

default_connection = "dev"

[connections.dev]
account = "xy12345.ap-northeast-1"   # 例: リージョン/クラウド表記に注意（.aws 等）
user = "YOUR_USER"
password = "YOUR_PASSWORD"
role = "SYSADMIN"
warehouse = "COMPUTE_WH"
database = "DEMO_DB"
schema = "PUBLIC"
```

キーペア認証（PKCS#8 の秘密鍵を使用）

```toml
default_connection = "dev"

[connections.dev]
account = "xy12345.ap-northeast-1"
user = "YOUR_USER"
private_key_path = "/Users/you/.ssh/snowflake_rsa_pk8.pem"
# パスフレーズ付きの場合は必要に応じて追加
# private_key_passphrase = "******"
role = "SYSADMIN"
warehouse = "COMPUTE_WH"
database = "DEMO_DB"
schema = "PUBLIC"
```

PKCS#8 変換（OpenSSL例）

```bash
openssl genrsa -out rsa_key.pem 2048
openssl pkcs8 -topk8 -inform PEM -outform PEM -in rsa_key.pem -out snowflake_rsa_pk8.pem -nocrypt
# パスフレーズ付きで作る場合
# openssl genrsa -aes256 -out rsa_key_with_pass.pem 2048
# openssl pkcs8 -topk8 -inform PEM -outform PEM -in rsa_key_with_pass.pem -out snowflake_rsa_pk8.pem
```

注意

- TOML は「=」の前後スペース・クォートの有無など構文に厳密です
- パスワードの平文記載は避けたい場合、運用で OS の環境変数や秘密情報管理を併用してください（config.toml には書かない）

接続テスト

```bash
sf connection test --name dev
```

基本の使い方（sf sql）

単発クエリの実行

```bash
sf sql -q "select current_version();"
```

複数クエリの実行（セミコロン区切り）

```bash
sf sql -q "use role sysadmin; use warehouse compute_wh; select current_warehouse(), current_role();"
```

SQL ファイルの一括実行

```bash
# 例: ./sql/init.sql に複数行のDDL/ DML を記述
sf sql -f ./sql/init.sql
```

典型的な SQL 例

```sql
-- コンテキスト確認
select current_account(), current_region(), current_role(), current_warehouse(), current_database(), current_schema();

-- サンプルオブジェクト
create or replace database demo_db;
create or replace schema demo_db.public;

create or replace table demo_db.public.hello (id int, name string);
insert into demo_db.public.hello values (1,'world'), (2,'snowflake');

select * from demo_db.public.hello order by id;
```

VS Code からの活用（統合ターミナル/タスク）

統合ターミナルで都度実行

- VS Code のターミナルを開き、上記の `sf` コマンドをそのまま実行します
- `sf --version` / `sf connection test --name dev` でまずは疎通確認

tasks.json でワンコマンド実行

`.vscode/tasks.json`（プロジェクト内）にタスクを定義しておくと、コマンドパレットからすぐに実行できます。

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Snowflake: run init.sql",
      "type": "shell",
      "command": "sf sql -f ./sql/init.sql",
      "problemMatcher": []
    },
    {
      "label": "Snowflake: version",
      "type": "shell",
      "command": "sf --version",
      "problemMatcher": []
    }
  ]
}
```

実践的な使用例（スクリプト化・データロードの考え方）

1) 初期化スクリプトで環境を整える

- `./sql/init.sql` を用意し、ROLE/WH/DB/SCHEMA の `use` と最低限のテーブル作成をまとめる
- CI/CD で `sf sql -f ./sql/init.sql` を流すと環境差異を吸収しやすい

2) パラメタライズの考え方

- 変数注入は CLI 側で標準化されていないため、環境変数/テンプレートエンジン（Makefile/justfile/簡易スクリプト）で置換してから `sf sql` を実行する方法が安全

3) データロードの基本戦略

- ローカル→Snowflake への直接 PUT は、専用クライアント（例: SnowSQL）や他手段を使うのが一般的です
- Snowflake CLI では `sf sql -q "copy into ..."` のように COPY 文自体は実行可能
- 外部ステージ（S3/GCS/Azure Blob）を使ったロードを標準化しておくと、CLI からは COPY 実行だけで済む運用にできます

外部ステージ経由の COPY イメージ（概念）

```sql
-- 例: 事前に外部ステージと必要な資格情報/統合が設定済みとする
create or replace table demo_db.public.events (
  id number, payload variant
);

copy into demo_db.public.events
from @demo_db.public.ext_stage/path/
file_format = (type = json)
on_error = 'skip_file';
```

トラブルシューティング（詳細）

A. `sf: command not found`

- 原因: パスが通っていない / インストール失敗
- 確認:
  - `which sf`（macOS/Linux）
  - `sf --version`
- 対処:
  - Homebrew: `brew doctor` / 再インストール
  - pipx: `pipx ensurepath` 後にシェルを再起動

B. config.toml 構文エラー / 読み込み失敗

- 症状: 実行時に設定が読めない・接続名が見つからない
- 原因: TOML の記法ミス（クォート/カンマ/セクション名）
- 確認:
  - `~/.snowflake/config.toml` の `[connections.<name>]` が正しいか
  - `default_connection` が存在する接続名か
- 対処:
  - 最小構成に戻してから、一つずつ項目を足す
  - 重複キーや全角スペースに注意

C. アカウント識別子の誤り（例: 250001）

- 症状: 「Account is invalid」
- 原因: リージョン/クラウドのサフィックス違い、タイプミス
- 確認:
  - Snowsight 右上のアカウント表記
- 対処:
  - `xy12345.ap-northeast-1` または `xy12345.ap-northeast-1.aws` のように正しく指定

D. 認証失敗（ユーザー/パスワード）

- 症状: 「Incorrect username or password」
- 原因: 入力ミス / パスワード期限切れ / ロック
- 確認:
  - Snowsight で同じ資格情報でログイン可能か
- 対処:
  - パスワードリセット / ロック解除を管理者へ依頼

E. キーペア認証（Incorrect key format）

- 症状: 「Incorrect key format」等
- 原因: PKCS#1 のまま / パスフレーズ不一致
- 確認:
  - 秘密鍵の先頭が `BEGIN PRIVATE KEY`（PKCS#8）になっているか
- 対処（再掲）:

```bash
openssl pkcs8 -topk8 -inform PEM -outform PEM -in old_key.pem -out snowflake_rsa_pk8.pem -nocrypt
```

F. ネットワーク/プロキシで疎通不可

- 症状: タイムアウト / TLS エラー
- 原因: 社内プロキシ/SSL 検査、DNS 解決不可
- 確認（例: macOS）:

```bash
nslookup xy12345.ap-northeast-1.snowflakecomputing.com
curl -I https://xy12345.ap-northeast-1.snowflakecomputing.com
curl -I https://ocsp.snowflakecomputing.com
```

- 対処:
  - ネットワークチームへ必要ドメインのホワイトリスト登録を依頼
  - システム/VS Code の proxy 設定（HTTPS_PROXY/HTTP_PROXY など環境変数）を見直し

G. 権限/ロール/WH 関連

- 症状: 「SQL access control error」「Object does not exist or not authorized」
- 確認（診断 SQL）:

```sql
select current_role(), current_warehouse(), current_database(), current_schema();
show roles;
show warehouses like 'COMPUTE_WH';
```

- 対処:
  - `use role ...; use warehouse ...; use database ...; use schema ...;`
  - 必要権限（USAGE/OPERATE/SELECT など）を管理者に付与依頼

H. SQL コンパイル/存在エラー

- 症状: 「Object does not exist」「SQL compilation error」
- 原因: 完全修飾名不足 / DB/SCHEMA を間違えている
- 対処:
  - 一時的に完全修飾（`DB.SCHEMA.OBJECT`）で実行
  - `use` でコンテキストを明示

I. CLI 固有の挙動/バージョン差

- 症状: オプションが使えない/挙動が異なる
- 対処:
  - `sf --version` を共有して同一バージョンで再現を取る
  - 公式リリースノート/ドキュメントでオプションの有無を確認
  - 一時的に単発 `sf sql -q` に落として切り分け

クイック診断チェックリスト

- `sf --version` は通るか（PATH/導入確認）
- `sf connection test --name dev` は成功するか
- Snowsight で同じ資格情報/SSO でログインできるか
- `current_role()/warehouse()/database()/schema()` を確認したか
- 完全修飾名で実行して再現するか
- ネットワーク到達性（Snowflake/OCSP）を確認したか

まとめと次のステップ

- Snowflake CLI の導入から基本操作、VS Code 連携、トラブル対応まで一通り紹介しました
- 次のステップ
  - プロジェクト配下に `./sql/` を作り、DDL/DML をスクリプト化
  - VS Code の Tasks/Launch と組み合わせてチーム運用を標準化
  - 外部ステージと COPY 戦略を確立し、CLI からの実行を自動化
  - （必要に応じて）dbt-snowflake 連携や CI/CD での `sf sql` 実行へ展開

以上で、VS Code × Snowflake CLI ハンズオンは完了です。詰まりやすい箇所はトラブルシュートの章に戻って都度確認してください。