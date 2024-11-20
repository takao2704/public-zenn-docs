---
title: "SORACOM Fluxを使って混雑度を可視化する(export画像は保存されないパターン)"
emoji: "🈵"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [soracom,ソラカメ,生成AI]
published: true
---
:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::


## やりたいこと
ソラカメで録画した映像を切り抜いてダッシュボードに表示させたいと思います。
ついでに、その画像に対してAIによる解析をかけて数値化した結果も表示してみたいと思います。
こんな感じのものが出来上がります。
![](https://storage.googleapis.com/zenn-user-upload/ab48246b4d38-20241017.png)


## 準備

### 必要なもの
- SORACOM アカウント
- ソラカメ関連
    - ソラカメ（AtomCam2）
    - Wifi環境
    - ソラカメライセンス(常時録画ライセンス 7日間プラン)  

:::details ソラカメが初めての方はこちら(購入から設置まで)！

### SORACOMのアカウント作成など
https://users.soracom.io/ja-jp/guides/getting-started/create-account/

カバレッジタイプはJPで。

### ソラカメの購入〜セットアップまで

https://sora-cam.com/setup/

実は最近はソラカメのセットアップにアプリを使わなくても良くなっていたりする。

### ソラカメの設置

設置に関する知見はここにたくさん溜まっています。
https://weathernews.jp/s/topics/202403/180215/

:::


## カメラチェック

何はともあれ、カメラが正常に動作しているか確認しましょう。

「ソラコムクラウドカメラサービス」 -> 「デバイス管理」

![alt text](/images/soracamimagetos3towp/image.png)

デバイスの一覧表示で、先ほど登録したカメラがオンラインになっていることを確認します。
![alt text](/images/soracom-flux-croudness-count/image.png)
images/soracom-flux-croudness-count/image-1.png
ここで重要な情報はデバイスIDになります。
後で使うので、メモをしておくかいつでもここに戻ってこられるようにしておきましょう。

さらに、カメラの名前をクリックすると、カメラの映像が表示されます。
![alt text](/images/soracom-flux-croudness-count/image-1.png)

こちら現在20時過ぎのソラコムの赤坂オフィスです。ホワイト企業なので、この時間にオフィスで働いている人はほとんどいません。



:::message
この画面を見続けていると月72時間までの動画エクスポート時間無料枠を消費してしまうので注意しましょう。
:::


## SORACOM Fluxの設定
### SORACOM Fluxとは
SORACOM Fluxは2024年7月17日のSORACOM Discovery 2024で発表された新サービスで、デバイスから送信されたセンサーデータ、カメラから送信された画像に対して、ルールを適用し、複数のデータソースや生成 AI を組み合わせて分析/判断し、その結果を IoT デバイスの制御に反映させる IoT アプリケーションをローコードで構築できる IoT アプリケーションビルダーです。


サービスの詳細：
https://soracom.jp/services/flux/

Discovery2024での発表の様子：
https://ascii.jp/elem/000/004/210/4210823/3/

### SORACOM Fluxでやりたいこと
今回は、SORACOM Fluxを使って以下の一連の流れを実装していきます。

1. ソラカメの録画データから画像を切り出す（Exportする）
2. 切り出した画像のデータを取得する
3. 切り出した画像をAIに読み込ませて解析させる
4. 解析させた結果（データ）と切り出した画像をSORACOM Harvestに送信する
5. SORACOM Harvestに送信されたデータをSORACOM Lagoonで表示する

今まではこれを実装しようと思うと[AWS Lambdaをwebhookで呼び出してゴニョゴニョ](https://blog.soracom.com/ja-jp/2024/07/23/soracom-flux-meets-soracam/)しないと難しかったのですが、2024年10月16日にリリースされた「SORACOM API アクション」を使うと、AWS Lambdaで呼び出していたソラカメAPIなどが呼び出せるようになりました。わーい！
https://changelog.soracom.io/ja/soracom-flux-ni-soracom-api-akusiyongazhui-jia-saremasita-1JXTX2

ということでそんな便利な機能を早速使っていきましょう。

### その前に
その前にSORACOM Fluxで解析したデータをSORACOM Harvestにいれるための準備をしておきます。
あれ？SORACOM HarvestってSORACOM AirとかSORACOM ArcみたいなSIM的なものが必要なんじゃ・・・と思ったそこのあなた。
こういう場合に使える手段があります。
その名も [SORACOM Inventory](https://soracom.jp/services/inventory/)
いくつかある機能のうちの、`デバイスIDとデバイスシークレットを使用した Harvest 連携`の機能を使います。

> デバイス登録時に払い出されるデバイスIDとデバイスシークレットを使用した HTTP リクエストで > SORACOM Harvest 連携ができます。
> SORACOM Air やデバイスエージェントを使用することなく Harvest にデータを蓄積し、可視化することができます。

これは意外と知らない人も多かったのではないかと思いますが、ESP32やM5Stackなどをwifiで利用している皆さんにはとても愛されている方法の一つとなっております。

#### Inventoryのデバイス追加
ハンバーガーメニューから 「SORACOM INVENTORY」 -> 「Inventory デバイス管理」を探します。
![](https://storage.googleapis.com/zenn-user-upload/96ab4ecc20cf-20241016.png)

「デバイスを追加」ボタンからデバイスを追加します。
![](https://storage.googleapis.com/zenn-user-upload/768e42ac49d0-20241016.png)

デバイス名やグループ名をきめます。

![](https://storage.googleapis.com/zenn-user-upload/30103ae44546-20241016.png)

![](https://storage.googleapis.com/zenn-user-upload/87acb5bc782a-20241016.png)

「追加」ボタンで追加します。
![](https://storage.googleapis.com/zenn-user-upload/7411cd0037e8-20241016.png)

デバイスIDとシークレットが発行されるので大切に取っておきます（後で使います）。

![](https://storage.googleapis.com/zenn-user-upload/206436ec3733-20241016.png)

これでHarvest Dataにデータを貯める用の仮想的なデバイスは完成です。

#### Harvest Data の設定
あとはこのデバイスが所属するグループにHarvest Dataの設定を有効化します。

「Inventory デバイス管理」から先ほど登録したデバイスを探し出して、グループのところをクリックします。
![alt text](/images/soracom-flux-croudness-count/image-2.png)

ちょっと下の方にスクロールして、「SORACOM Harvest Data 設定」のトグルスイッチをONして有効化します。
![](https://storage.googleapis.com/zenn-user-upload/99e22c511266-20241016.png)

### いよいよFluxの設定
このブログのクライマックスです。慌てず落ち着いていきましょう。

#### タイマー起動の設定
ハンバーガーメニューから「SORACOM Flux」-> 「Fluxアプリ」
![](https://storage.googleapis.com/zenn-user-upload/c874076aabfe-20241016.png)

新しいFluxアプリを作成します。
![](https://storage.googleapis.com/zenn-user-upload/2e4bc250a59d-20241016.png)

名前をつけましょう（何でもよいです）
![](https://storage.googleapis.com/zenn-user-upload/2f1fe08ba050-20241016.png)

こんな感じのチャネルを作成するしかやることがないページに飛びます。
大人しくチャネルを作成します。
![](https://storage.googleapis.com/zenn-user-upload/80106f9ad404-20241016.png)

今回は5分に1回のタイマーで駆動していきたいので、「タイマー」を選択します。
![](https://storage.googleapis.com/zenn-user-upload/c9402aa8374c-20241016.png)

こんな感じで設定します。
![](https://storage.googleapis.com/zenn-user-upload/f8378138776b-20241016.png)

これをこのまま放置するとこのあとの工程をやっている間に意図せず駆動されてしまうので、一旦無効化しておきます。
![](https://storage.googleapis.com/zenn-user-upload/ad46038f4648-20241016.png)

※急に現れてblinkしている、「変更を保存」ボタンは忘れずに押しましょう

STUDIOの画面上はこんな感じになっています。
![](https://storage.googleapis.com/zenn-user-upload/e32ff3d1c401-20241016.png)

#### ソラカメの録画データから画像を切り出す（Exportする）
「アクション」のタブに移動します。
![](https://storage.googleapis.com/zenn-user-upload/ab1a878327cf-20241016.png)

「アクションを追加」からの「SORACOM APIアクション」をクリックしてOKします。
![](https://storage.googleapis.com/zenn-user-upload/b3a12384e578-20241016.png)

`SoraCam:exportSoraCamDeviceRecordedImage` をなんとかして探し出します。
![](https://storage.googleapis.com/zenn-user-upload/a69295bf38f3-20241016.png)

こんな感じの画面になります。
![](https://storage.googleapis.com/zenn-user-upload/059462c0a325-20241016.png)

URLのところの`{device_id}`をソラカメのデバイスIDに置き換えます。

この画面
![alt text](/images/soracom-flux-croudness-count/image.png)

の右側のやつです。

HTTPボディには、
```json
{
 "time":${now()}
}
```
を入れましょう。

SAM Userは新しく作成します。
名前もデフォルトのままでいきます。

こんな感じになります。
![alt text](/images/soracom-flux-croudness-count/image-3.png)

最後にアクションのアウトプットを有効にして別のチャンネルに送信するを有効にします。
![](https://storage.googleapis.com/zenn-user-upload/8b6e847ad746-20241016.png)

こんな画面に遷移すればOKです。

![alt text](/images/soracom-flux-croudness-count/image-4.png)

##### ちゃんと設定できたか試してみる
自分の設定に自身のある方は次に進みましょう。
自身のない方はこのSORACOM APIアクションがちゃんと動くか試してみましょう

「テスト実行」タブに移動して、BODYに`{}`と空のJSON（？）を入れて、実行をクリックします。
![](https://storage.googleapis.com/zenn-user-upload/f5d884b845be-20241016.png)

実行結果が下の方に現れてきます。
緑色で`COMPLETED`となったらOKです。
![alt text](/images/soracom-flux-croudness-count/image-5.png)

JSONのレスポンスのフォーマットはこのような感じになっています。
![alt text](/images/soracom-flux-croudness-count/image-6.png)

このレスポンスの内容は`payload`というJSONとなって後段のアクションで再利用できます。

:::message
今回のExportのAPIは非同期のAPIとなっており、`now()`という画像の切り出しで指定した時刻の画像を録画した動画から切り取るためのキューに入れるイメージとなります。

`exportID`はキューを特定するためのIDで、`status`はそのキューがいまどういう状態かを示していて、`initializing`は始まったところで、`processing` -> `completed`という変化をしていきます。
:::

### 切り出した画像のデータを取得する
こんな感じの状態になっているともいます。
![](https://storage.googleapis.com/zenn-user-upload/64eca84b6eed-20241016.png)

画像を切り出すためのリクエストをしただけなので、まだ切り出された画像は取得できていません。
切り出された画像を取得するためのAPIを実行します。

右側に伸びているグレーの土管をクリックして「アクション」タブから「アクションを追加」します。
![](https://storage.googleapis.com/zenn-user-upload/04342820a050-20241016.png)

先ほどと同様に「SORACOM API」を選択して「OK」

なんとかして、`SoraCam:getSoraCamDeviceExportedImage`を探し出します。
![](https://storage.googleapis.com/zenn-user-upload/41e6c588e54a-20241016.png)

先ほどと同様にURLのプレースホルダーを変えていきます。
`{device_id}`はソラカメのデバイスIDを直打ちしてもいいのですが、先程実行したAPIのレスポンスのボディに含まれるので今後対象のデバイスを変えたりしたときのために、レスポンスから引くことにします。

`{export_id}`は先程実行した画像切り出しのリクエストのIDを入れます。
（このAPIは、先程実行したリクエストもう終わっているかどうかをリクエストのIDをキーにして調べるAPIです。）これも先程のレスポンスのボディから引くことができます。

この部分には以下のような呪文をいれるのが正解となります。
```
/v1/sora_cam/devices/${payload.deviceId}/images/exports/${payload.exportId}
```
`payload.deviceID`で先程のAPIのレスポンスのJSONからdeviceIDを呼び出せます。また、お作法としてこのように、設定パラメータのなかで使う場合は`${}`で囲うというFluxのローカルルールになっています。

注意点を理解して、新しいSAM Userを作ります。

アウトプットのチャンネルは、一旦無効にして作成し、テストを実行してみます。
一度STUDIOに戻って、左端のタイマーをクリックして、先ほどと同じようにBODYを入れて実行します。
![](https://storage.googleapis.com/zenn-user-upload/dc1006c82201-20241016.png)

さっきより出力が伸びたと思います。一番下が緑でCOMPLETEDになっていればOKです。
![alt text](/images/soracom-flux-croudness-count/image-7.png)


最後の出力を見てみると、statusがprocessingとなっています。
![alt text](/images/soracom-flux-croudness-count/image-8.png)

これは、まだ画像が作り終わっていないという意味になります。
おわかりの通り、画像が作り終わるまで作り終わったかどうかを確認する必要がありますね。
プログラミングの知識のある人は、whileループみたいなものを使えばいいという発想になると思いますが、Fluxの場合は次のようにします。

#### 画像のexportが完了するまでデータ取得のAPIを実行し続ける

STUDIOに戻って右端のSORACOM API アクションをクリックします。
![alt text](/images/soracom-flux-croudness-count/image-10.png)


アクションの実行条件のところに
```
payload.status == "initializing" || payload.status == "processing"
```

を入れます。

![alt text](/images/soracom-flux-croudness-count/image-9.png)

これは、一つ前のアクションの実行結果のレスポンスに含まれる、`status`が`initializing`または`processing`のときだけ、このAPIを実行しますよーというWhile文やIf文の条件のようなものになります。

これをwhileループっぽく使いたいので、アクションのアウトプットをこのアクションの入口のチャネルにいれるように設定してループを作ってあげます。
「有効」をONして、「既存のチャンネルを選択する」からのこのアクションの前にあるチャネルをプルダウンから選びます。
![](https://storage.googleapis.com/zenn-user-upload/3580f81ff985-20241016.png)

更新を押すとこんな感じになっていると思いますが、
![](https://storage.googleapis.com/zenn-user-upload/898d9c70433f-20241016.png)

心の目で見るとオレンジの線が見えてくるはずです。
![](https://storage.googleapis.com/zenn-user-upload/571377974cc3-20241016.png)


これで、どこかで必ず`status`が`completed`（正確には`initializing`と`processing`以外）になってループを抜けれるはずなので、`completed`になったときのアクションを設定しておきます。

テスト実行するとこんな感じの結果が出ることになります。
![](https://storage.googleapis.com/zenn-user-upload/fb24ae6084d8-20241016.png)

### 切り出した画像をAIに読み込ませて解析させる
ここの土管をクリックします
![](https://storage.googleapis.com/zenn-user-upload/c5984d589f7e-20241016.png)

AIアクションを選択します。
![](https://storage.googleapis.com/zenn-user-upload/906b194b2a78-20241016.png)

このブロックはさっきのループを`complete`のステータスで抜けて来たときだけ実行したいので、アクションの実行条件に以下を設定します。
```
payload.status == "completed"
```

AIモデルはGPT-4o等のマルチモーダルに対応したモデルを選択します。

今回の例では画角の映像から着席している人数と着席割合から混雑度を解析するため、プロンプトを以下のようにしてみました。
自由にいじってみてください。

```
画像の様子を説明してください。

また、だいたいどのぐらいの人数が着席しているか、正確でなくて良いので教えて下さい。

出力の形式は以下のようなJSON形式でお願いします。

{
 "state": 状態を表現する文章
 "person_count": 着席している人数
 "crowding_level":座席数に対する着席している人数の割合(0-100)
 "url":"${payload.url}"
}
```
AIからの返答をJSON形式にするとAIに画像を読み込ませるにチェックを入れます。

AIに読み込ませる画像のところにはURLを入れますが、`complete`のstatusで返ってきたexport画像を取得するAPIにはpresigned URLが入っていますのでそこを参照させるように以下を設定します。
```
${payload.url}
```

出力は新しいチャネルに出す設定でこのアクションを作成します。
![](https://storage.googleapis.com/zenn-user-upload/ce383a025cbe-20241016.png)

テストはの実施方法は省略しますが、うまくいくと以下のようなレスポンスがAIから返ってくるはずです。
![](https://storage.googleapis.com/zenn-user-upload/f93e67784a60-20241016.png)

#### 解析させた結果（データ）と切り出した画像をSORACOM Harvestに送信する
STUDIOに戻ると以下のようになっていると思います。
![](https://storage.googleapis.com/zenn-user-upload/15566e6f0bca-20241016.png)

当然心の目で見ると
![](https://storage.googleapis.com/zenn-user-upload/8dfecf140946-20241016.png)
オレンジの線が見えてきます。

最後のアクションは青い箱から出ている土管に接続します。
![](https://storage.googleapis.com/zenn-user-upload/f8c5a26e2936-20241016.png)

今回はwebhookのアクションを使います。
![](https://storage.googleapis.com/zenn-user-upload/00a9cf4be2a9-20241016.png)

名前をHarvestにデータを送信などとして、アクションの実行条件はそのまま（空白）で、
HTTPメソッド：POST
URL：https://api.soracom.io/v1/devices/デバイスID/publish
HTTPヘッダー：x-device-secret：シークレットキー

URLの中のデバイスIDと、HTTPヘッダーのシークレットキーは後で使うと予告してあった、こちらのものを利用します。
![](https://storage.googleapis.com/zenn-user-upload/206436ec3733-20241016.png)

こんな感じで設定したら更新して閉じます。
BODYはAIアクションのレスポンスのボディからoutputを抜き出して設定するので、`${payload.output}`となります。
![](https://storage.googleapis.com/zenn-user-upload/0f95a406f3bd-20241017.png)

テストしてちゃんと送信できたか確認してみましょう。
webhookアクションの実行履歴が緑色でcompletedとなっていればOKですが、念の為Harvest Dataの方でも確認してみます。


「データ収集・蓄積・可視化」から、「SORACOM Harvest Data」を選択します。
![](https://storage.googleapis.com/zenn-user-upload/d5c438dede27-20241017.png)

Inventoryを使っているので、「デバイス」の中からリソースを指定して、
![](https://storage.googleapis.com/zenn-user-upload/11b69802e9f5-20241017.png)

確認するとちゃんと送られているようです。
![](https://storage.googleapis.com/zenn-user-upload/28fb9f19b56a-20241017.png)

### SORACOM Harvestに送信されたデータをSORACOM Lagoonで表示する
Harvest DataまでくればあとはいつもどおりLagoonで可視化するだけです。

「データ収集・蓄積・可視化」から、「SORACOM Lagoon」を選択します。
![](https://storage.googleapis.com/zenn-user-upload/57cd54595221-20241017.png)

Lagoonの契約がない場合は、こちらを参考にセットアップしましょう。今回の可視化はフリープランでも実施可能です。
https://users.soracom.io/ja-jp/docs/lagoon-v3/getting-started/

Lagoon3のコンソールにログインします。
![](https://storage.googleapis.com/zenn-user-upload/49170e455982-20241017.png)

こんな感じのダッシュボードを作っていきたいと思います。
![](https://storage.googleapis.com/zenn-user-upload/ab48246b4d38-20241017.png)

#### 一番上に様子（文章）を表示
「add a new panel」します。
![](https://storage.googleapis.com/zenn-user-upload/53e86ca34ccb-20241017.png)

- visualizationは「logs」を選択
- Queryは左から、「Device」, 「Inventoryで設定したデバイス名」,「Standard」、「-All-」でOKです
![](https://storage.googleapis.com/zenn-user-upload/d67791b1114c-20241017.png)
その他はデフォルトのままにします。

#### 左側上段に混雑度と人数を表示
「add a new panel」します。
- Visualizationは「Stat」を選択
  ![](https://storage.googleapis.com/zenn-user-upload/4b392414fa8c-20241017.png)
- Queryは2系列
    - A:「Device」, 「Inventoryで設定したデバイス名」,「Standard」、「crowding_level」
    - B:「Device」, 「Inventoryで設定したデバイス名」,「Standard」、「person_count」
    ![](https://storage.googleapis.com/zenn-user-upload/d6dac3075728-20241017.png)

#### 左側下段に混雑度と人数（時系列推移）を表示
「add a new panel」します。

- Visualization は「Time series」
    ![](https://storage.googleapis.com/zenn-user-upload/2f0a42f71bc1-20241017.png)
- Queryは2系列
    - A:「Device」, 「Inventoryで設定したデバイス名」,「Standard」、「crowding_level」
    - B:「Device」, 「Inventoryで設定したデバイス名」,「Standard」、「person_count」
    ![](https://storage.googleapis.com/zenn-user-upload/d6dac3075728-20241017.png)
- Query optionsを選択して、Relative timeを少し長めに設定（下記の例では6h）。
  ![](https://storage.googleapis.com/zenn-user-upload/e8ed46ec0c3a-20241017.png)

#### 右側は大きめにソラカメのエクスポート画像を表示
「add a new panel」します。

- Visualizationは「Soracom Dynamic Image Panel」
  ![](https://storage.googleapis.com/zenn-user-upload/376ea5dd1267-20241017.png)

- Queryは「Device」, 「Inventoryで設定したデバイス名」,「Standard」、「-All-」
  ![](https://storage.googleapis.com/zenn-user-upload/712bbb190540-20241017.png)

- Settings
    - Mode：「URL」
    - Name：「A-url」
    ![](https://storage.googleapis.com/zenn-user-upload/5933fec0382f-20241017.png)
:::message
- QueryのAという系列の中のurlというキーの値を使うという意味です。この場合は、ソラカメから切り出した画像のpresigned URLを渡すようにしていたのでそのURLが動的に参照されます。

- presigned URLの有効期限はエクスポート完了後10分なので、切り出した画像を永続的に参照したい場合はどこか別の場所に保存する処理を追加する必要があります。
:::

各パネルの設定が完了したら、ダッシュボードのTime Rangeを`now-6m` ~ `now`となるように設定します。
![](https://storage.googleapis.com/zenn-user-upload/ce294d395174-20241017.png)
（SORACOM Fluxの駆動が5分おきのため、マージンを1分取って6分で設定しています。）

Save current time range as dashboard defaultのチェックを入れて保存したらダッシュボードの完成です。
![](https://storage.googleapis.com/zenn-user-upload/54fa7acffdef-20241017.png)

お疲れ様でした！！
