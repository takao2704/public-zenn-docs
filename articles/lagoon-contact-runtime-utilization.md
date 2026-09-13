---
title: "接点信号から設備の稼働率をSORACOM Lagoonで可視化する"
emoji: "⏱️"
type: "tech"
topics: ["soracom", "iot"]
published: true
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## はじめに

接点信号のON/OFFから、設備の稼働時間と稼働率を可視化するダッシュボードを作ります。第1章で作成する完成形は次のとおりです。接点状態の時系列グラフと、稼働時間・稼働率・受信件数を並べて表示します。

![今回作成するダッシュボード。接点状態の時系列グラフ、稼働時間2,880秒、稼働率80%、受信件数360件](/images/lagoon-contact-runtime-utilization/09-periodic-dashboard.jpg)

設備の接点状態を `ON=1`、`OFF=0` としてSORACOM Harvest Dataに保存している場合、SORACOM Lagoonを使ってON時間や稼働率を表示できます。ただし、現在の状態を一定間隔で送信する場合と、状態の変化時のみ送信する場合とでは、計算方法が異なります。

この記事では、Harvest Dataに保存済みのサンプルデータを使用し、Lagoonのパネルを設定する手順を解説します。10秒間隔のデータと接点変化のデータそれぞれにおいて、ON時間・稼働率・状態グラフを表示する方法を紹介します。どちらのケースも、保存されている `state` と時刻情報をもとに、Lagoon内で直接計算します。

## 全体構成

接点入力デバイスからUnified Endpointへ送信したデータをSORACOM Harvest Dataに保存し、SORACOM Lagoonで可視化する構成を想定します。

![接点入力デバイスからUnified Endpoint、SORACOM Harvest Data、SORACOM Lagoonへ至る構成図](/images/lagoon-contact-runtime-utilization/12-architecture.png)

## 使用するデータと表示する値

Harvest Dataに以下のデータが保存されており、Lagoonから参照できる状態であることを前提とします。

検証には、2026年9月12日20:00〜21:00（JST）の1時間分のサンプルデータを使用しました。ONの区間は次の3つです。

| ONの区間 | ON時間 |
| --- | --- |
| 20:00〜20:20 | 1,200秒 |
| 20:25〜20:45 | 1,200秒 |
| 20:52〜21:00 | 480秒 |
| 合計 | 2,880秒（48分） |

ここでの稼働率は、対象の1時間に占めるON時間の割合を指します。計算式は `2,880 ÷ 3,600 × 100 = 80%` です。計画稼働時間など、別の分母を用いる指標とは区別してください。

### 10秒間隔の状態データ

`state` に数値の `0` または `1` が格納されています。検証用データは20:00:00から20:59:50までの全360件で、そのうち288件が `1` です。

Harvest Dataでは、次のように10秒刻みの時刻と `state` の値を確認できます。画像は20:20にON（`1`）からOFF（`0`）へ切り替わる前後の記録です。

![Harvest Dataに保存された10秒間隔の接点状態データ](/images/lagoon-contact-runtime-utilization/13-harvest-periodic.jpg)

以下は接点状態を表す部分の例です。

```json
{"state": 1}

```

データ1件を10秒分として扱うと、ON時間は `288 × 10 = 2,880秒`、稼働率は `288 ÷ 360 × 100 = 80%` になります。

:::message
ここでの10秒間隔とは、保存されているデータのタイムスタンプの間隔を意味します。デバイスの実際の送信周期や、送信から画面更新にかかる時間を表したものではありません。
:::

### 接点変化の状態データ

もう一方のデータには、以下の5件の状態記録が含まれます。先頭の記録から集計開始時点の状態が把握でき、それ以降のデータに欠落がないことを前提とします。

| 時刻（JST） | state |
| --- | --- |
| 20:00:00 | 1 |
| 20:20:00 | 0 |
| 20:25:00 | 1 |
| 20:45:00 | 0 |
| 20:52:00 | 1 |

この5件の `state` のみを使用して計算を行います。あらかじめ積算されたON時間や稼働率のデータは不要です。

## 1. 10秒間隔のデータからパネルを作る

### 1.1 ダッシュボードの表示期間を設定する

1. Lagoonで対象のダッシュボードを開きます。
2. 画面右上の時間範囲設定を開きます。
3. サンプルの対象期間を絶対時刻で指定します。今回の検証では、JSTの `2026-09-12 20:00:00` から `2026-09-12 20:59:59` までを指定します。
4. 表示されるタイムゾーンと時刻を確認します。

ご自身のデータで試す場合は、該当データが保存されている期間に置き換えて設定してください。計算対象となる期間は、開始時刻を含み終了時刻を含まない1時間です。

接点変化を補完する第2章でも同様の設定を行います。終了時刻を21:00:00にすると、その時刻の補完点まで計算に含まれてしまうため、ここでは20:59:59に設定します。なお、10秒間隔の元データは20:59:50が最終データのため、第1章の計算結果はいずれの指定でも変わりません。

![Lagoonの時間選択で20:00:00から20:59:59を指定する](/images/lagoon-contact-runtime-utilization/01-time-range.jpg)

### 1.2 10秒間隔のデータからON時間を表示する

#### Query Aで接点状態を取得する

1. **Add panel** → **Add a new panel** を選択します。
2. 表示形式を **Stat** に設定します。
3. Query Aを以下のとおり設定します。

| 項目 | 設定 |
| --- | --- |
| Data source | Soracom |
| Resource Type | Air |
| Group | 対象SIMが所属するグループ |
| Resources | 10秒間隔のデータを保存したSIM |
| Data Format | Standard |
| Properties | state |

Query Aでは、数値データの `state` プロパティを取得します。

#### Expressionで合計し、10倍する

Query Aの `state` の値を合計するとONの記録件数が求まります。これに1件あたりの10秒を掛け合わせます。

1. **Expression** を追加し、Bを作成します。
2. Bを以下のとおり設定します。

| 項目 | 設定 |
| --- | --- |
| Operation | Reduce |
| Function | Sum |
| Input | A |
| Mode | Strict |

3. さらにExpressionを追加し、Cを作成します。
4. Cの **Operation** を **Math** に設定し、式に `$B * 10` と入力します。
5. AとBの目のアイコンをオフにし、表示対象をCのみにします。

検証を行ったUI環境では、AとBに **Disabled** と表示されましたが、Cの入力値として正常に機能し、計算結果が表示されました。そのため、AとBの定義自体は消さずに残しておきます。

Expressionの基本的な操作手順は、[公式のExpressionドキュメント](https://users.soracom.io/ja-jp/docs/lagoon-v3/expression/)でも確認できます。

#### Statの表示を整える

| 項目 | 設定 |
| --- | --- |
| パネル名 | 定期送信：稼働時間 |
| Calculation | Last * |
| Unit | カスタム単位 `suffix: 秒` |
| Decimals | 0 |

設定を適用すると、今回の検証データでは **2,880秒** と表示されます。

![stateの取得、Reduce Sum、Mathで10倍する式とStatの秒表示](/images/lagoon-contact-runtime-utilization/02-periodic-runtime.jpg)

### 1.3 稼働率と受信件数を表示する

#### 稼働率のGauge

1. 新しいパネルを追加し、表示形式を **Gauge** に設定します。
2. Query Aには、前のパネルと同じSIMの `state` を指定します。
3. Expression Bを **Reduce / Mean / Input A / Strict** に設定します。
4. Expression Cを **Math** に設定し、式を `$B * 100` とします。
5. AとBを非表示にし、Cのみを表示します。

表示設定は以下のとおりです。

| 項目 | 設定 |
| --- | --- |
| パネル名 | 定期送信：稼働率 |
| Calculation | Last * |
| Unit | Percent (0-100) |
| Min / Max | 0 / 100 |
| Decimals | 0 |

検証結果では **80%** と表示されました。計算式の中で100倍しているため、単位には **Percent (0-100)** を選択します。

![Reduce Meanと100倍するMath、Gaugeの単位と最小値・最大値の設定](/images/lagoon-contact-runtime-utilization/03-periodic-utilization.jpg)

#### 受信件数のStat

稼働率と並べて、集計対象となったデータ件数も表示します。

1. **Stat** パネルを追加します。
2. Query Aに同じ `state` を指定します。
3. Expression Bを **Reduce / Count / Input A / Strict** に設定します。
4. Aを非表示にし、Bを表示します。Mathは追加しません。
5. パネル名を「定期送信：受信件数」、Calculationを **Last \***、単位を `suffix: 件`、Decimalsを `0` に設定します。

今回の設定での表示は **360件** となり、1時間を10秒で割った数値と一致します。

![Reduce Countで360件を表示するStatの設定](/images/lagoon-contact-runtime-utilization/04-periodic-count.jpg)

ただし、件数が一致しているだけでは、同一時刻でのデータ重複や別時刻での欠落の有無までは判断できません。今回の検証サンプルでは、各レコードのタイムスタンプと値も個別に照合しています。

### 1.4 接点の状態を時系列で表示する

集計値と併せて、10秒ごとに記録されたON/OFFの状態も確認できるようにします。

1. **Time series** パネルを追加します。
2. Query Aには、1.2と同じSIMの `state` を指定します。このパネルにはExpressionを追加しません。
3. **Graph styles** の **Line interpolation** を **Step after** に設定します。
4. **Show points** を **Always** に設定します。
5. **Standard options** のMinを `0`、Maxを `1`、Decimalsを `0` に設定します。
6. パネル名を「10秒間隔の接点状態」と設定し、適用します。

![10秒間隔のstateをTime seriesで表示し、Step afterとShow points Alwaysを設定する](/images/lagoon-contact-runtime-utilization/10-periodic-time-series.jpg)

点は各記録時刻の状態を表し、Step afterの線はその状態を次の記録まで保持する形で描かれます。線でつながっていても、10秒のサンプル間に起きた変化まで確認できるわけではありません。

### 1.5 保存して表示を確認する

第1章のパネル設定を適用し、ダッシュボードを保存します。ダッシュボードを開き直し、2,880秒・80%・360件と、接点状態の時系列グラフが表示されているか確認してください。

作成した4つのパネルを並べると、次のように表示されます。

![10秒間隔のデータから作成した完成パネル。接点状態の時系列グラフ、稼働時間2,880秒、稼働率80%、受信件数360件](/images/lagoon-contact-runtime-utilization/09-periodic-dashboard.jpg)

## 2. 接点変化のデータからパネルを作る

変化通知で送信された `state` の値をそのまま平均しても、時間の割合を表すことにはなりません。今回のデータ値は `1, 0, 1, 0, 1` であるため、単純平均を100倍すると60%になりますが、時刻から算出した実際のON時間の割合は80%です。

そこで、Lagoonの **Resample** 機能を使い、直前の状態を補完して10秒ごとのデータに揃えてから集計します。今回のサンプルでは、外部の集計処理を使わずに2,880秒・80%を表示できました。

### 2.1 接点変化からON時間と稼働率を表示する

#### 表示期間とQuery Aを設定する

1. 第1章と同じダッシュボードに **Stat** パネルを追加します。
2. 表示期間が **20:00:00〜20:59:59（JST）** になっていることを確認します。
3. Data sourceを **Soracom**、Resource Typeを **Air** に設定します。
4. GroupとResourcesで、接点変化データが保存されているSIMを選択します。
5. Data Formatを **Standard**、Propertiesを **state** に設定します。

入力データは冒頭で示した5件です。20:00時点の状態が分かっており、20:52の最後のON状態が21:00まで継続するものとして計算します。

#### Resampleで直前の状態を補う

**Expression** を追加し、Bを以下のとおり設定します。

| 項目 | 設定 |
| --- | --- |
| Operation | Resample |
| Input | A |
| Resample to | 10s |
| Downsample | Mean |
| Upsample | pad |

`pad` は、データの記録がない時間枠に直前の値を補完する設定です。たとえば、20:00の `1` が20:20の `0` まで継続するものとして、その間の10秒ごとの枠を `1` で埋めます。[SORACOMのExpressionドキュメント](https://users.soracom.io/ja-jp/docs/lagoon-v3/expression/)でも、Resampleおよびpadの仕様が解説されています。

今回のデータでは各10秒枠に含まれる元の記録が最大1件のため、DownsampleのMeanによって元の0/1の値が変わることはありません。ただし、1つの枠内に複数の変化記録が含まれる場合はこの前提が成り立たなくなります。

:::message
検証において、終了時刻を21:00:00に設定したところ、Resampleは21:00:00の点を含む361点を生成しました。一方、20:59:59に設定すると20:00:00〜20:59:50の360点となりました。今回は1点を10秒分としてカウントするため、後者の設定を採用しています。任意の時間範囲で設定を行う際も、補完後のデータ点数と集計期間の対応関係を必ず確認してください。
:::

#### ON時間をStatに表示する

1. Expression Cを **Reduce / Sum / Input B / Strict** に設定します。
2. Expression Dを **Math** に設定し、式を `$C * 10` とします。
3. A・B・Cの目のアイコンをオフにして非表示にし、Dのみを表示させます。
4. Calculationを **Last \***、Unitを `suffix: 秒`、Decimalsを `0` に設定します。
5. パネル名を「変化通知：稼働時間（Lagoonで計算）」と設定し、適用します。

補完後の360点のうち、`1` のデータは288点となります。`288 × 10` の計算により **2,880秒** と表示されます。Query inspectorのJSON確認でも、入力Aが5件、補完後Bが360点、Sum結果Cが288となることを確認済みです。

![stateをResampleのpadで補い、Reduce SumとMathで2880秒を求める](/images/lagoon-contact-runtime-utilization/05-event-runtime.jpg)

#### 稼働率をGaugeに表示する

1. **Gauge** パネルを追加します。
2. Query Aに同じSIMの `state`、Expression Bに同じ **Resample / 10s / Mean / pad** を設定します。
3. Expression Cを **Reduce / Mean / Input B / Strict** に設定します。
4. Expression Dを **Math** に設定し、式を `$C * 100` とします。
5. A・B・Cを非表示にし、Dのみを表示します。
6. Calculationを **Last \***、Unitを **Percent (0-100)**、Minを `0`、Maxを `100`、Decimalsを `0` に設定します。
7. パネル名を「変化通知：稼働率（Lagoonで計算）」と設定し、適用します。

等間隔に揃えた360点の平均値となるため、`288 ÷ 360 × 100` により **80%** と表示されます。

![Resample後のMeanを100倍して80%を表示するGaugeの設定](/images/lagoon-contact-runtime-utilization/06-event-utilization.jpg)

### 2.2 接点の状態を時系列で表示する

集計値と併せて、元の状態変化も確認できるようにします。

1. **Time series** パネルを追加します。
2. Query Aで接点変化SIMの `state` を選択します。このパネルにはExpressionを追加しません。
3. **Graph styles** の **Line interpolation** を **Step after** に設定します。
4. **Show points** を **Always** に設定します。
5. **Standard options** のMinを `0`、Maxを `1` に設定します。
6. パネル名を「接点変化通知の状態」と設定し、適用します。

![接点変化の5件をTime seriesで表示し、Step afterとShow points Alwaysを選ぶ](/images/lagoon-contact-runtime-utilization/07-time-series.jpg)

Step afterは、直前の状態が次の記録まで保持される形で折れ線を描画する設定です。この表示設定自体には積算機能はありません。ON時間と稼働率の計算を行っているのは、2.1で設定したExpressionです。

### 2.3 保存して表示を確認する

各パネルの設定を適用したらダッシュボードを保存し、一度画面を再読み込みします。表示期間を 20:00:00〜20:59:59 に指定し、以下の結果が表示されることを確認してください。

| パネル | 確認結果 |
| --- | --- |
| 変化通知：稼働時間（Lagoonで計算） | 2,880秒 |
| 変化通知：稼働率（Lagoonで計算） | 80% |
| 接点変化通知の状態 | 5件の状態記録とON/OFFの波形 |

参考用として、Resampleを挟まずに `state` の **Reduce Mean → Math `$B * 100`** を適用したパネルも並べて掲載しています。赤色で表示されている60%は、変化通知の単純平均をそのまま稼働率として使用できないことを示す誤った例です。

![接点変化のパネルだけを抜粋。Lagoonで計算した2880秒と80%、誤例の60%、状態変化のグラフ](/images/lagoon-contact-runtime-utilization/08-dashboard.jpg)

保存後の再読み込み時においても、正しく2,880秒・80%と表示されることを確認できました。

## 毎日の始業時刻から現在までを表示する

たとえば9:00始業なら、固定日付の代わりに次の時間範囲を指定します。

| 項目 | 設定 |
| --- | --- |
| Time zone | Asia/Tokyo（日本時間） |
| From | `now/d+9h` |
| To | `now` |
| 自動更新 | `30s`（例） |

1. 時間範囲設定でFromとToを入力し、**Apply time range** を選択します。
2. 更新ボタン横のメニューで **30s** を選択します。
3. ダッシュボードの保存時に **Save current time range as dashboard default** をオンにして保存します。
4. 固定日時の `from`・`to` が付いたURLではなく、保存したダッシュボードを開き直して確認します。

![毎日9時から現在までを表示する時間範囲。Fromはnow/d+9h、Toはnow](/images/lagoon-contact-runtime-utilization/11-daily-time-range.jpg)

`now/d` は当日の0:00、`+9h` はそこから9時間後です。更新のたびに終了時刻が進み、翌日はその日の9:00が開始時刻になります。9:00より前は開始時刻が未来になるため、この設定は始業後の表示に使います。[相対時刻の指定方法はGrafanaの公式ドキュメント](https://grafana.com/docs/grafana/latest/visualizations/dashboards/use-dashboards/#semi-relative-time-range)でも紹介されています。

集計方法は第1章・第2章と同じですが、日次で使う場合は次の点を確認してください。

- **10秒の定期送信**：始業からの全件を取得できていることが条件です。8時間なら2,880件になるため、Countの結果と取得上限・間引きの影響を確認します。
- **接点変化のみ**：始業時点の状態が分かるデータが必要です。9:00より前の通知しかない場合、今回のQueryと `pad` だけでは状態を引き継げず、時間範囲の変更だけで正しく集計することはできません。
- **稼働率の分母**：始業から現在までの時間を対象とし、休憩時間も含みます。休憩を除く稼働率には別の集計条件が必要です。

ここでは相対時刻と自動更新の設定を確認しました。日をまたぐ連続運用と、8時間分のデータを使った集計は未検証です。

## 計算結果を読むときの注意点

- **10秒単位の概算です。** サンプル間の変化や10秒未満の端数は正確に扱えません。現在までの表示では、末尾の未経過分も10秒として数える場合があります。
- **欠落・重複と取得件数を確認します。** データが揃っていないと、ON時間や稼働率も正しく求まりません。
- **`pad` は取得した直前の状態を保持します。** 取得範囲より前の状態や、欠落した変化通知は復元しません。

今回確認したのは、開始時の状態が分かり、欠落がなく、変化が10秒境界に揃った1時間分のサンプルです。

## まとめ

10秒間隔の状態データは、Lagoon上で **Reduce Sum → Math `$B * 10`** を使用してON時間を、**Reduce Mean → Math `$B * 100`** を使用して稼働率を表示できました。

今回の接点変化データも、**Resample / 10s / pad** によって直前の状態を補完してから集計することで、Lagoon単体で2,880秒・80%の数値を表示できました。これは元データ5件を単純平均した数値（60%）とは異なります。

開始時の状態確認、通知の欠落対策、補完間隔の設定、および期間終了端の扱いを揃えた上で、数値パネルと状態遷移グラフを並べて検証を行ってください。
