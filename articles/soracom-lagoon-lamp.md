---
title: "SORACOM Lagoon で信号機のようなランプ表示をする"
emoji: "🚦"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [SORACOM,IoT]
published: true
---
:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## やりたいこと
SORACOM Lagoonで可視化を行う際に、信号灯のように正常な場合は緑、異常な場合は赤のランプ表示で状態を確認できるダッシュボードを作る。
こんな感じのやつ
![alt text](/images/lagoon-lamp/image-20.png)
または
![alt text](/images/lagoon-lamp/chap2/image-10.png)


## 事前準備
### 1. SORACOM Harvest Dataにデータを貯める

https://users.soracom.io/ja-jp/docs/harvest/send-data/

※まだデータがない場合はデモデータが使えるので必須ではない

### 2. SORACOM Lagoon 3 の利用を開始する

https://users.soracom.io/ja-jp/docs/lagoon-v3/getting-started/


## 方法1 Soracom Image Panel を使った方法
### 1. Folder を作成する
`Dashboards` の `Browse` タブ から `New` をクリックして

![alt text](/images/lagoon-lamp/image-3.png)

`New Folder` を選択して

![alt text](/images/lagoon-lamp/image-4.png)

適切なフォルダ名を入力して `Create` をクリックする

![alt text](/images/lagoon-lamp/image-5.png)

### 2. DashboardとTime Series(時系列の折れ線グラフ) Panel を作成する

遷移した画面から `+ Create Dashboard` をクリックして

![alt text](/images/lagoon-lamp/image-6.png)

`Add a new panel` を選択

![alt text](/images/lagoon-lamp/image-7.png)

`Resource Type` で `Demo` を選択

![alt text](/images/lagoon-lamp/image-9.png)

`Resources` で `Device-1`、`Properties`で`battery`を選択し、その状態で
    
duplicate アイコンを2回クリックし、Query `B` と `C` の`Resources`を`Device-2`、`Device-3`に変更する。

![alt text](/images/lagoon-lamp/image-12.png)

`Dashboard` に戻り、`Panel Title` をクリックして `More...`から`Duplicate` をクリック

![alt text](/images/lagoon-lamp/image-13.png)

Timeseries Panel が2枚できました。
![alt text](/images/lagoon-lamp/image-14.png)

### 3. 信号機のようなランプ表示のパネルを作る

`Panel Title` をクリックして出てくるプルダウンから `Edit` をクリック
![alt text](/images/lagoon-lamp/image-15.png)

`Visualization` で `Soracom Image Panel` を選択
![alt text](/images/lagoon-lamp/image-16.png)

`+ Add Image` を3回クリック
![alt text](/images/lagoon-lamp/image-17.png)

`Image0`、`Image1`、`Image2` をそれぞれ以下のとおり設定する。
![alt text](/images/lagoon-lamp/image-18.png)
|  | Image0 | Image1 | Image2 |
|:---:|:---:|:---:|:---:|
|Name|A-Device-1 battery|B-Device-2 battery|C-Device-3 battery|
|Threshold | 0.3 / 0.7 | 0.3 / 0.7 | 0.3 / 0.7 |
|X/Y Positions| 30 / 50 | 50 / 50 | 70 / 50 |

`Save` をクリックして保存するとこのようなダッシュボードができます。
![alt text](/images/lagoon-lamp/image-19.png)

`Device-1`のbattery値が`0.32`、`Device-2`のbattery値が`1`、`Device-3`のbattery値が`0`の場合の表示です。
これでもいいのですが、これだとどのアイコンがどのデバイス／センサーの値かわからないので、アイコンごとにパネルを分けてしまうのも一つの手です。
![alt text](/images/lagoon-lamp/image-20.png)


## 方法2 canvasを使った方法
先程の[方法1-1](#1.-Folder-を作成する)と、[方法1-2](#2.-DashboardとTime-Series(時系列の折れ線グラフ)-Panel-を作成する)までは同じです。

`Panel Title` をクリックして出てくるプルダウンから `Edit` をクリック
![alt text](/images/lagoon-lamp/image-15.png)

`Visualization` で `Canvas` を選択
![alt text](/images/lagoon-lamp/chap2/image.png)

`Layer`の中にある`Elements`でデフォルトで入っている`Element1`を削除
![alt text](/images/lagoon-lamp/chap2/image-1.png)

`Layer`の中にある`Elements`で`+ Add Element`をクリックし、`Icon`を選択
![alt text](/images/lagoon-lamp/chap2/image-2.png)
これを３つ追加します。

以下のようになっているはずです。
![alt text](/images/lagoon-lamp/chap2/image-3.png)

`Element1`をクリックすると、`Selected element(Element1)`というフィールドが現れます。
![alt text](/images/lagoon-lamp/chap2/image-4.png)

`SVG path`をクリックして好きなアイコンを選択したら`Select`をクリックします。
![alt text](/images/lagoon-lamp/chap2/image-5.png)

`Fill color`を選択して、`Devuce-1 battery`を選択します。

`Thresholds`を設定します。`0.3`と`0.7`を入力します。
![alt text](/images/lagoon-lamp/chap2/image-6.png)

`Elements2`と`Elements3`も同様に設定します。
このとき、Layoutのleftを`100`,`200`にして、それぞれのアイコンを配置します。
こんな感じになればOKです。`Apply`をクリックして保存します。
![alt text](/images/lagoon-lamp/chap2/image-7.png)

パネルのサイズを調整して、
![alt text](/images/lagoon-lamp/chap2/image-8.png)

更に`text`の`Element`を追加して、そこに`Sensor-1`、`Sensor-2`、`Sensor-3`を表示するとわかりやすくなります。

設定画面
![alt text](/images/lagoon-lamp/chap2/image-9.png)

結果
![alt text](/images/lagoon-lamp/chap2/image-10.png)


`Canvas`のほうが設定はめんどくさいですが、配置設定の柔軟性やIconと色を比較的自由に決めることができて便利です。

以上、お疲れ様でした。










