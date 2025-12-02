---
title: "Wio BG770AとSORACOM 入門: 基本編"
emoji: "🛠"
type: "tech"
topics: ["WioBG770A", "SORACOM", "Basics"]
published: false
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## はじめに

概要編で把握した全体像を前提に、本編では `wio_cellular` と Grove インターフェースの基本操作を手を動かしながら確認することを予告する。

## セルラー通信の基礎

### モデム初期化フロー

`WioCellular.begin()`, `powerOn()`, `WioNetwork.begin()` の呼び順と内部で行われる処理（電源投入、UART 準備、URC 設定）を箇条書きで整理する。

### APN 設定とアタッチ／デタッチ

`WioNetwork.config.apn` や `setSearchAccessTechnology` などのパラメータ、`WioCellular.setPhoneFunctionality()` を使ったアタッチ・デタッチ手順をステップ化する。

### HTTP 通信（GET/POST）

`WioCellularHttpClient` もしくは `HttpSession` を使った基本的な GET/POST シーケンスをサマリで示し、ヘッダ設定やレスポンス取得の流れを短く説明する。

### TCP/UDP 送信

`WioCellularTcpClient2` と `WioCellularUdpClient2` の典型的な呼び出し順（open → waitForConnect → send → close、`sendto`）を表形式または箇条書きでまとめる。

## インターフェースの使い方

### I2C（SCD40 温湿度計）

Grove I2C ポートへの接続、`Wire` 初期化、SCD40 ライブラリでの読み取りフロー（測定開始 → 測定結果取得）をシーケンスとして記述する。

### UART（SIM28 GPS）

Grove UART ポートのピン割り当て、`Serial1` 設定、NMEA 文の読み取りとパース手順をサマリにする。

## ログとデバッグの基本

USB CDC でのログ出力、`FreeRTOS configASSERT` や `NRF_LOG` の使い方、AT コマンドデバッグのための `SerialBG77` 直接アクセス方法を紹介する。

## 省電力の初歩

PSM/eDRX のパラメータ設定例、送信間隔の調整、nRF52840 側の `delay` ではなく FreeRTOS タイマを使う理由などを短くまとめる。

## まとめと次回予告

セルラー通信・I2C・UART の基本操作を確認できたことを振り返り、次回の実践編で温湿度/CO2 + GPS トラッカーを構築することを予告する。
