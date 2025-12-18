---
title: "スイッチサイエンス製 nRF9160 IoT Dev Board でSORACOM使ってみる：基本編"
emoji: "🐕"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["nrf9160", "soracom", "iot", "cellular", "embedded"]
published: false
---
:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

:::message
本記事は[積みボード/デバイスくずしAdvent Calendar 2025](https://qiita.com/advent-calendar/2025/tsumiboard)の5日目の記事です。
日頃積んだままになっているIoTデバイスに電源とSIMを入れて動かしつつ、今度もう一度動かしたくなったときにすぐ動かせるようにするための手順やノウハウをまとめ超個人的な備忘録です。
:::




メモ：
手順
https://144lab.kibe.la/shared/entries/dfeba412-a69e-47ae-b53e-dc8e8218527b


https://www.nordicsemi.com/Products/Development-tools/nRF-Connect-for-Desktop/Download#infotabs
からnRF Connect for Desktopをダウンロード、インストール

インストールの画面
![alt text](/images/getting-started-with-nrf9160iotdevb/1765287956890.png)

launchpadからnRF Connect for Desktopを起動
![alt text](/images/getting-started-with-nrf9160iotdevb/1765287995336.png)

開く
![alt text](/images/getting-started-with-nrf9160iotdevb/1765288046226.png)

accept,とかOKをクリックしながら、Launchanywayをクリック
![alt text](/images/getting-started-with-nrf9160iotdevb/1765288100073.png)

Adding the Mynewt Homebrew Tap
If this is your first time installing newt, add the JuulLabs-OSS/mynewt tap:

$ brew tap JuulLabs-OSS/mynewt