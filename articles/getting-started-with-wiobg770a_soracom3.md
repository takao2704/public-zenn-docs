---
title: "Wio BG770AとSORACOM 入門: 実践編"
emoji: "🚀"
type: "tech"
topics: ["WioBG770A", "SORACOM", "IoT"]
published: false
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## はじめに

概要編・基本編で得た知識を用いて、温湿度/CO₂ 計測と GPS 取得を備えたトラッカーを組み立てることを宣言する。完成形の要件（SORACOM へ定期送信、再送・再接続）を明記する。

## システム設計

### 構成要素

SCD40（I2C）、CO₂ センサー、SIM28 GPS（UART）、BG770A モデム、SORACOM Harvest/Lagoon などの役割を表形式で記載する。

### データフロー

センサー取得 → メタデータ付与（位置情報/タイムスタンプ）→ フォーマット化 → HTTP/TCP 送信 → SORACOM 側で保管、という流れをシーケンス図レベルでメモする。

## 実装ステップ

### 初期化ルーチン

- FreeRTOS タスク作成（センサー、モデム、送信、監視）
- `WioCellular` と `WioNetwork` の初期化（APN、PSM設定）
- Grove 電源制御とセンサー初期化

### メタデータ取得

GPS からの位置情報、nRF52840 の RTC 時刻、電圧監視（VSYS_DIV）などをまとめ、送信メッセージに付与する手順をアウトライン化する。

### 定期データ送信

送信周期タイマ、バッチング（複数センサーデータをまとめる）、HTTP もしくは TCP 送信シーケンスを箇条書きで記述する。

### エラーハンドリング

再送ロジック、LTE 再接続、連続失敗時のバックオフ、ログ保存／SORACOM Event Hub への通知などを盛り込む。

## SORACOM 連携

Harvest Data での可視化例、Lagoon ダッシュボードの構成、アラート設定の概要を紹介する。

## 運用とアップデート

UF2 更新手順、設定ファイル（`platformio.ini`, `src/config.h`）の管理、SIM の状態監視、バッテリー交換やアンテナチェックなどの運用タスクを列挙する。

## まとめ

実践編で実装した機能を振り返り、応用として他のセンサーやアクチュエータを追加するアイデア、より高度なクラウド連携（Funnel、Beam など）への誘導を記載する。
