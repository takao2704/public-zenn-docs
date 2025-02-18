---
title: "SORACOM Air タリフチートシート(日本)"
emoji: "🔖"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [soracom]
published: true
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## はじめに
日本で使うとき、結局どのプランを選べばいいかいっぱいありすぎてわからなくなっちゃうときがあるのでまとめてみました。
商談中にドヤ顔早口でテクニカル話をしてたのに急に値段のこと聞かれた途端、急に答えられなくなっちゃうのカッコ悪いので。

## グローバルカバレッジプラン別機能比較（よく気にする項目）

| 項目 | [plan01s](https://soracom.jp/services/air/cellular/pricing/price_iot_sim/#plan01s) | [plan01s - Low Data Volume](https://soracom.jp/services/air/cellular/pricing/price_iot_sim/#plan01sLDV) | [planX1](https://soracom.jp/services/air/cellular/pricing/price_iot_sim_add_subscription/#planX1) | [planX2](https://soracom.jp/services/air/cellular/pricing/price_iot_sim_esim_profile_download/#planX2) | [planP1](https://soracom.jp/services/air/cellular/pricing/price_iot_sim_add_subscription/#planP1) | [planX3](https://soracom.jp/services/air/cellular/pricing/price_iot_sim_add_subscription/#planX3) |
|--------------|---------|------------------------|--------|--------|--------| ------ |
| **docomo** |  ✓  |  |  ✓  |  | ✓ | ✓  |
| **softbank** |  ✓  |  ✓  |  ✓  |  |  ✓  | ✓  |
| **KDDI** |  ✓  |  ✓  |  ✓  |  ✓  |  |  |
| **LTE-M 対応可否** | ✓ | ✓ | ✓ |  |  | ✓ |
| **tokyoLBO** | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| **プリインSIMの色** | black | black |  |  | navy | orange |
| **eSIMプロファイル（QR）** | ✓ |  | ✓ | ✓ | ✓ |  |
| **embedded SIM** | ✓ | ✓ |  |  |  | ✓ |



## 料金比較

### 複数キャリア対応、中容量（〜300MiB/月）
基本的にこのオーダーのデータ通信量となる場合は特定地域向けプランのほうがコスパが良いが、1つのSIMで複数キャリアに対応できることに価値を見いだせる場合に検討する。
したがって、シングルキャリアのプランは比較対象外。

![alt text](/images/cheatsheet/image.png)

月額料金代表値
|| plan01s | planX1 (D,SB,K) | planX1 (SB,K) | planX3 |
|---------|--------|--------|--------|------|
|@100MiB/月| 21.9 | 21.8 | 3.8 | 7.9 |
|@200MiB/月| 41.9 | 41.8 | 5.8 | 15.2 |
|@300MiB/月| 61.9 | 61.8 | 7.8 | 22.5 |

この領域ではplan01s ≒ planX1(D,SB,K) > planX3 > planX1(SB,K)の順で月額料金が高い。

### 複数キャリア対応、小容量（〜60MiB/月）

![alt text](/images/cheatsheet/image-1.png)

分岐点
- planX3 = planX2

    19MiB/月 2.0USD

- planX3 = planX1(D,SB)

    22MiB/月 2.2USD

- planX3 = planP1

    51MiB/月 4.3USD


### 複数キャリア対応、超小容量（〜5MiB/月）
![alt text](/images/cheatsheet/image-2.png)

分岐点
- plan01s LDV = planX3

    1.2MiB/月 1.0USD

- plan01s LDV = planX1(SB,K),P1,X2

    3.0MiB/月 1.9USD

- plan01s LDV = plan01s, planX1(D,SB,K)

    4.8MiB/月 2.8USD

### 特定地域向けプラン 300MBバンドル(plan-D, plan-K2)
いわゆる「おかわり」とか「階段状のプライシング」を図示するとこんな感じ。
![alt text](/images/cheatsheet/image-4.png)
![alt text](/images/cheatsheet/image-3.png)

### plan-DUのバンドルプラン
![alt text](/images/cheatsheet/image-5.png)

分岐点
下記のしきい値を超えたら一度高い方のバンドルに切り替えてすぐに戻すとその月は高いバンドルの料金が適用される。
（バンドルが低いプランのままだと、しきい値を超えた分の料金が高くなってしまう逆転現象が発生する）
- DU-10GB = DU-50GB

    20GB/月 

- DU-50GB = DU-100GB

    70GB/月

### plan-DU vs plan-D D300MB
![alt text](/images/cheatsheet/image-7.png)

plan-DUで下りの使いすぎに注意。
上り：下りの不均衡が、概ね8：2を超えるとplan-D D300MBのほうが安くなる。


### plan-KM1
![alt text](/images/cheatsheet/image-6.png)

うっかりplan-KM1の使いすぎに注意。


| 通信量 | 月額料金|
|---------|--------|
| 10kB | 116円 |
| 100kB | 166円 |
| 1MB | 673円 |
| 10MB | 5742円 |
| 100MB | 56430円 |