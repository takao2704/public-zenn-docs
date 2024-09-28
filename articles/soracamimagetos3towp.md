---
title: "ソラカメの画像をワードプレスで表示する"
emoji: "👻"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["soracom","ソラカメ","wordpress","s3","lambda","IoT"]
published: false
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## やりたいこと
ソラカメで撮影した画像をwordpressで作成したwebサイトに表示する！

## 準備
### 必要なもの
- SORACOM アカウント
- ソラカメ関連
    - ソラカメ（AtomCam2）
    - Wifi環境
    - ソラカメライセンス(常時録画ライセンス 7日間プラン)  
- AWSアカウント
- Wordpressの環境

### SORACOMのアカウント作成など
https://users.soracom.io/ja-jp/guides/getting-started/create-account/

カバレッジタイプはJPで。

### ソラカメの購入〜セットアップまで

https://sora-cam.com/setup/

