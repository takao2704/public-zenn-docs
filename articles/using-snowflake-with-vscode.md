---
title: "VS CodeでSnowflakeを使おう！セットアップ完全ガイド（トラブルシューティング充実版）"
emoji: "❄️"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["snowflake", "vscode", "sql", "database", "dataengineering"]
published: false
---

本記事では、VS Code（Visual Studio Code）からSnowflakeに接続して、SQLを実行できるようにするまでをハンズオン形式で解説します。公式拡張機能と汎用SQLクライアント拡張（SQLTools）の両方に対応し、特にトラブルシューティングを詳しくまとめました。

この記事でできること

- VS CodeにSnowflake関連拡張機能をインストールできる
- Snowflakeへの接続（パスワード/SSO/キーペア）を設定できる
- SQLを実行し、結果グリッドを確認できる
- よくあるエラーの対処法が分かる

対象読者

- SnowflakeをVS Codeから使いたい方
- これからデータ基盤・データエンジニアリングを始める方
- SQLの基礎を理解している方（入門レベルでOK）

目次

- 前提条件
- 画像フォルダ構成
- 方式A: 公式「Snowflake」拡張機能を使う
- 方式B: SQLTools + Snowflakeドライバを使う
- 基本の使い方（共通）
- 便利機能の活用
- トラブルシューティング（詳細）
- 次のステップ

前提条件

- VS Code 1.85+（できれば最新）
- Snowflakeアカウント（トライアル可）
- 接続可能なネットワーク（社内プロキシ/ファイアウォール越えの場合は設定が必要なことあり）
- 役割/ウェアハウス/DB/スキーマへ最低限の権限が付与されていること

用語メモ（アカウント識別子）

- アカウント識別子は「xy12345.ap-northeast-1」や「xy12345.ap-northeast-1.aws」のような形式です
- Snowsight右上の「アカウント」から確認できます
- URLのサブドメイン部分や「ORGANIZATION.ACCOUNT」表記に注意してください

画像フォルダ構成（任意）

```text
images/using-snowflake-with-vscode/
├── installation/
├── connection/
├── basic-usage/
└── features/
```

方式A: 公式「Snowflake」拡張機能を使う

概要

Snowflake公式のVS Code拡張機能を使う方法です。接続管理、SQL実行、オブジェクト探索、補完などが提供されます。

インストール

- 拡張機能（Extensions）で「Snowflake」を検索し、発行元がSnowflakeの拡張機能をインストール
- 再読み込み（Reload）が求められたら従います

接続を作成

- コマンドパレット（Cmd/Ctrl+Shift+P）→「Snowflake: Add Connection」
- 入力項目の例
  - Account: 例）xy12345.ap-northeast-1
  - Username
  - Authentication: Password / SSO / Key Pair
  - Role（任意）
  - Warehouse
  - Database / Schema（任意）

認証方式のポイント

1) Password 認証
  - 通常のユーザー名/パスワードで接続
  - パスワードはVS CodeのSecret Storageで安全に保持されます

2) SSO（OAuth/外部ブラウザ）認証
  - 企業SSO（Okta/Azure AD等）を使う場合
  - 初回はブラウザでログインを完了し、トークンをVS Codeに連携
  - 組織ポリシーによりSnowflake側のOAuth統合設定が必要なことがあります
  - Google SSO を使う場合（例）
    - Authentication で「SSO」または「External Browser」相当を選択
    - 既定ブラウザが開く → Google アカウントでサインイン
    - 成功後に VS Code へ自動でトークンが連携され接続完了（必要に応じてウィンドウへ戻る）
  - 管理者向けメモ
    - Snowflake と Google の SSO（SAML または External OAuth）統合が有効であること
    - 社内のブラウザ/端末ポリシーでポップアップ/サードパーティ Cookie/組織アプリ制限が有効だとブロックされる場合あり
    - 外部 OAuth を採用する場合は許可済みリダイレクトURI・スコープの設定を確認

3) Key Pair 認証（推奨：PKCS#8）
  - RSAキーペアを使ったパスワードレス接続
  - 生成例（平文PKCS#8）

```bash
openssl genrsa -out rsa_key.pem 2048
openssl pkcs8 -topk8 -inform PEM -outform PEM -in rsa_key.pem -out rsa_key_pk8.pem -nocrypt
```

  - パスフレーズ付きにしたい場合

```bash
openssl genrsa -aes256 -out rsa_key_with_pass.pem 2048
openssl pkcs8 -topk8 -inform PEM -outform PEM -in rsa_key_with_pass.pem -out rsa_key_pk8.pem
```

  - VS Code側では「Private Key（PKCS#8）」のパスと、必要に応じてパスフレーズを指定

方式B: SQLTools + Snowflakeドライバを使う

概要

汎用SQLクライアント拡張「SQLTools」と、そのSnowflakeドライバを用いる方法です。設定JSONで接続を管理しやすいのが特徴です。

インストール

- 拡張機能で「SQLTools」と「SQLTools Snowflake Driver」をインストール

接続設定（GUI）

- コマンドパレット→「SQLTools: Add New Connection」
- Driverに「Snowflake」を選択し、以下を入力して保存
  - Name: snowflake-dev
  - Account, Username, Password（またはKey Pair/SSO）
  - Warehouse, Database, Schema, Role

接続設定（settings.jsonで管理）

```json
{
  "sqltools.connections": [
    {
      "name": "snowflake-dev",
      "driver": "Snowflake",
      "account": "xy12345.ap-northeast-1",
      "username": "YOUR_USER",
      "password": "${env:SNOWFLAKE_PASSWORD}",
      "warehouse": "COMPUTE_WH",
      "database": "DEMO_DB",
      "schema": "PUBLIC",
      "role": "SYSADMIN"
    }
  ]
}
```

基本の使い方（共通）

1) 接続する
- 方式A: 拡張機能の「Connections」ビュー→接続→Connect
- 方式B: SQLToolsの「DATABASES」ビュー→接続→Connect

2) ワークシート（.sql）を作成
- 新規ファイルをexample.sqlとして保存し、言語モードをSQLに

3) クエリを実行

```sql
-- バージョン確認
select current_version();

-- 簡単なテーブル作成と操作
create or replace table demo_db.public.hello (id int, name string);
insert into demo_db.public.hello values (1, 'world'), (2, 'snowflake');
select * from demo_db.public.hello order by id;
```

- 選択実行（選択範囲だけ実行）やファイル全体の実行が可能
- 結果はグリッド表示され、CSV/JSONエクスポートも可能です

4) オブジェクト探索
- データベース/スキーマ/テーブル/ビュー/ステージなどをツリーで参照
- 右クリックから「Preview」「Copy DDL」などのアクションが利用可能（拡張機能により差異あり）

便利機能の活用

- IntelliSense（オートコンプリート）：テーブル/カラム/関数名の補完
- SQL整形（Format）：チームでスタイル統一
- クエリ履歴：過去実行の検索・再実行
- 複数接続の切替：本番/開発の使い分け（Role/権限でガード）

トラブルシューティング（詳細）

本章は「症状（エラー）/原因/確認/解決/再発防止」で整理しています。必要に応じて診断SQLやネットワーク確認コマンドも併記します。

A. アカウント/接続先の誤り（例: 250001 Account エラー）

- 症状: ログイン直後に「Account is invalid」等で接続できない
- 原因: アカウント識別子のスペル/リージョン/クラウド（.aws/.gcp/.azure）不一致
- 確認:
  - Snowsightで実際のアカウント名を確認
  - URLや「ORGANIZATION.ACCOUNT」表記をコピペした際の余分な文字に注意
- 解決:
  - 例）xy12345.ap-northeast-1（必要に応じて .aws を付加）
- 再発防止:
  - 接続プロファイルを共通のテンプレート化し、レビュー運用を行う

B. 認証失敗（例: 390100 Username/Password エラー）

- 症状: 「Incorrect username or password」
- 原因: 入力ミス、パスワード期限切れ、アカウントロック
- 確認:
  - Snowsightで同一資格情報でログインできるかを確認
- 解決:
  - 管理者にロック解除/パスワードリセットを依頼
- 再発防止:
  - パスワードはVS Code Secret Storageか、環境変数参照を利用

C. SSO/OAuth関連（例: ブラウザが開かない/戻らない、390189 Token 失効）

- 症状:
  - 外部ブラウザが開かない / 開いても VS Code に戻らない
  - Google でログイン後に「権限がありません」「このユーザーは存在しません」等で停止
  - トークン期限切れ・更新失敗（390189 等）
- 主な原因:
  - ポップアップ/リダイレクトがブロック（ブラウザ/拡張/企業ポリシー）
  - SSO/External OAuth の統合未整備（許可リダイレクトURI・スコープ不備）
  - 複数 Google アカウントに同時ログインしており、誤アカウントで認証
  - 端末の時刻ずれ（トークン検証に失敗）
  - プロキシ/SSL検査でコールバックを阻害
- 確認:
  - 会社のSSOガイドライン、Snowflake側の SSO（SAML）/External OAuth 設定
  - Google の組織ポリシー（サードパーティ Cookie/ポップアップ/SSO ドメイン制限）
  - 端末の時刻同期（NTP）
  - 別ブラウザのシークレットモードで再現するか（アカウント切替/拡張無効化の切り分け）
- 解決（Google SSO の典型手順）:
  - いったん Snowsight へ Google SSO で正常ログイン → その後 VS Code で再試行
  - 既定ブラウザのデフォルトアカウントを、Snowflake と紐づく Google アカウントに切り替え
  - ブラウザのポップアップブロック/サードパーティ Cookie を一時許可
  - 企業内プロキシ配下の場合はネットワークチームへリダイレクト許可/ホワイトリスト登録を依頼
- 再発防止:
  - チームの標準ブラウザ/SSOの使い方（既定アカウント/プロファイル）をナレッジ化
  - External OAuth を使う場合は、許可リダイレクトURI・スコープ・クライアント設定を手順化
  - 定期的なトークン有効期限/更新動作の確認（期限切れ時のリトライ運用を明記）

D. Key Pair 認証（例: Incorrect key format）

- 症状: 「Incorrect key format」「Could not read private key」
- 原因: PKCS#1のまま、PKCS#8へ変換していない／パスフレーズ不一致
- 確認:
  - 鍵の先頭行が「BEGIN PRIVATE KEY」（PKCS#8）かを確認
- 解決（変換例）:

```bash
openssl pkcs8 -topk8 -inform PEM -outform PEM -in old_key.pem -out rsa_key_pk8.pem -nocrypt
```

- 再発防止:
  - 鍵管理手順をREADMEに明文化し、運用で固定

E. ネットワーク/プロキシで接続不可

- 症状: タイムアウト、ホスト解決失敗
- 原因: *.snowflakecomputing.com への疎通不可、企業プロキシ/SSL検査
- 確認（例: macOS）:

```bash
nslookup xy12345.ap-northeast-1.snowflakecomputing.com
curl -I https://xy12345.ap-northeast-1.snowflakecomputing.com
curl -I https://ocsp.snowflakecomputing.com
```

- 解決:
  - ネットワークチームに必要ドメインのホワイトリスト化を依頼
  - VS Codeのproxy設定（http.proxy）、システム証明書の取り扱いを確認
- 再発防止:
  - 社内標準の開発PCイメージ/プロキシ設定をナレッジ化

F. 権限/ロール/ウェアハウス関連（SQLは通るが権限で失敗）

- 症状: 「SQL access control error」「Object does not exist or not authorized」
- 原因: Roleに必要権限がない、Warehouseが停止/権限不足
- 確認（診断SQL）:

```sql
select current_role(), current_warehouse(), current_database(), current_schema();
show roles;
show warehouses like 'COMPUTE_WH';
```

- 解決:
  - 必要に応じて
```sql
use role SYSADMIN;
use warehouse COMPUTE_WH;
use database DEMO_DB;
use schema PUBLIC;
```
  - 管理者にGRANT権限付与を依頼（例: USAGE/OPERATE/SELECT など）
- 再発防止:
  - 接続プロファイルに既定のROLE/WH/DB/SCHEMAを明示しておく

G. SQLコンパイル/存在エラー（例: 002003/000904 等）

- 症状: 「Object does not exist」「SQL compilation error」
- 原因: DB/SCHEMAミス、権限不足、名前解決の完全修飾不足
- 確認:
  - 完全修飾名（DB.SCHEMA.OBJECT）で実行して再現するか確認
- 解決:
  - USE文で現在コンテキストを正す or 完全修飾名で参照
- 再発防止:
  - チームのDDL/DMLスニペットに完全修飾名をテンプレ化

H. 拡張機能固有の問題（UI/キャッシュ/バージョン差異）

- 症状: 接続パネルに反映されない、補完が出ない
- 原因: 拡張機能のバグ/キャッシュ、VS Codeバージョン差、競合
- 対処:
  - 拡張機能の再読み込み/再インストール
  - VS Codeを一度リロード（Developer: Reload Window）
  - 拡張機能の設定を初期化、競合拡張を一時無効化

I. 実行時/パフォーマンス（Warehouseサイズ/Auto-Suspend）

- 症状: 実行が遅い、最初の実行が特に遅い
- 原因: 小さすぎるWarehouse、Auto-Suspend後の起動レイテンシ
- 対処:
  - 適切なWarehouseサイズへ調整、必要に応じてAuto-Resumeを有効化

クイック診断チェックリスト

- Snowsightで同じ資格情報/SSOでログインできるか
- Account識別子とリージョン/クラウドは正しいか
- ネットワークから *.snowflakecomputing.com と ocsp.snowflakecomputing.com へ到達できるか
- current_role()/warehouse()/database()/schema() を確認したか
- 完全修飾名でクエリして再現するか
- 拡張機能/VS Codeの再読み込みで改善するか

次のステップ

- dbt-snowflake と組み合わせて、VS Codeからモデル開発/テストを実施
- Snowflake CLI / SnowSQLの導入で権限やオブジェクト管理を自動化
- Dev Containers/Codespacesで開発環境を標準化

まとめ

公式拡張とSQLToolsの2パターンでVS CodeからSnowflakeを扱う手順を紹介し、特に詰まりやすいポイントを詳しく整理しました。接続に成功したら、クエリ実行やオブジェクト探索を活用し、権限/ネットワーク/認証の運用をチームで標準化していきましょう。
