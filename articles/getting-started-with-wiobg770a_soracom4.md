---
title: "Wio BG770AとSORACOM 入門: 定期送信オペレーション編"
emoji: "📡"
type: "tech"
topics: ["WioBG770A", "SORACOM", "IoT", "Telemetry"]
published: false
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

:::message
本記事は[積みボード/デバイスくずしAdvent Calendar 2025](https://qiita.com/advent-calendar/2025/tsumiboard)の最終回（4日目）です。ここまで積んできた Wio BG770A + SORACOM の実験を、定期送信ジョブとして形にするための最終ラップです。
:::

## はじめに

シリーズ第4回・最終回では、前回まとめた通信＆センサ計測スケッチを土台に「定期的にデータを送る運用パターン」を仕上げます。LTE 接続やセンサ読み出しは既に確認済みという前提で、以下の観点を整理します。

- FreeRTOS/loop レベルでの周期タスク設計とバックオフ
- Harvest Data / Lagoon を前提としたメトリクス整形
- 再送・バッファリング・障害時のフェイルセーフ
- SIM グループ設定や Unified Endpoint の監視ポイント

## 目次

1. シリーズ振り返りと今回のゴール
2. 定期送信ジョブのアーキテクチャ
3. スケッチ全体像（comm_scheduler.ino 仮）
4. 送信タスクの実装ポイント
   - 送信キュー／リングバッファ
   - HTTP/TCP/UDP の再送制御
5. センササンプリングと前処理
   - GPS 測位結果のフィルタリング
   - SCD40 のウォームアップと無効値判定
6. Harvest Data / Lagoon での可視化テンプレート
7. 運用時にチェックすべき SORACOM 設定
   - グループポリシー
   - Unified Endpoint の Event Handler
   - SIM 台帳とメタデータ管理
8. まとめと今後の発展案

## 本文テンプレート

以下のセクションで順次肉付けしていきます。

### シリーズ振り返りと今回のゴール

### 定期送信ジョブのアーキテクチャ

### スケッチ全体像（comm_scheduler.ino）

### 送信タスクの実装ポイント

### センササンプリングと前処理

### Harvest Data / Lagoon での可視化テンプレート

### SORACOM 設定の最終チェック

### まとめ
