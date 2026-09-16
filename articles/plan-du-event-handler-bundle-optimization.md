---
title: "SORACOM Air plan-DUを賢く使う自動節約術"
emoji: "📡"
type: "tech"
topics: ["soracom", "soracomflux", "iot"]
published: true
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

:::message
この記事は2026-09-16時点の情報に基づいています。料金やサービス内容は変更される可能性がありますので、最新情報は公式サイトでご確認ください。

https://soracom.jp/services/air/japan_coverage/
:::

## やりたいこと

plan-DUは、通信量に合わせてバンドルを選ぶことで通信料金を最適化（抑制）できます。

通信量をチェックしてバンドルを切り替える作業を人手で実施するのは、なかなか大変です。この記事では、その作業の自動化について検討し、方法をまとめました。

月初は最小のDU-10GBで始め、通信量が増えたら、その時点で料金が安くなるバンドルへ変更します。翌月もDU-10GBから始められるよう、変更後はすぐに戻しておきます。この運用を、イベントハンドラーとSORACOM Fluxで組みます。

## plan-DUの料金体系

金額は1SIMあたりの月額・税込です。通信量は1GB = 1,024³バイトで、料金表では公式表記のGB、本文と実装ではGiBを使います。

| バンドル | 月額基本料金 | 含まれる上り通信量 | 含まれる下り通信量 |
| --- | ---: | ---: | ---: |
| DU-10GB | 1,452円 | 10GB | 1GB |
| DU-50GB | 3,509円 | 50GB | 2GB |
| DU-100GB | 6,534円 | 100GB | 3GB |

超過料金は上り10GB・下り1GBを1ブロックとして1,100円です。

https://soracom.jp/services/air/japan_coverage/

本記事では、**下り通信量がバンドル選択に影響せず、上り通信量を基準に料金を比較できる使い方**を対象とします。

以下のグラフと設定例では、この前提を満たす条件として下り月1GiB以下を使います。グラフは基本料金と超過料金の合計で、背景色は最安のバンドルを示しています。

![plan-DUの月次上り通信量と月額料金の比較](/images/plan-du-bundle-optimization/48-bundle-cost-overview.png)
*plan-DU：どこで大きいバンドルが安くなる？ 下り月1GiB以下で、基本料金と超過料金を比較。背景色は最安のバンドル。*

![上り20GiBと70GiB付近の料金の拡大図](/images/plan-du-bundle-optimization/49-bundle-cost-boundaries.png)
*左：20GiB超でDU-50GB、右：70GiB超でDU-100GBが有利。●は境界ちょうど、○は境界を超えた側の料金。*

公式料金表から算出（2026-09-15確認）。初期費用・付加サービス等は対象外です。

切り替えの分岐点は、上りが**20GiBを超えたらDU-50GB、70GiBを超えたらDU-100GB**です。境界ちょうどでは小さいバンドルの方が安く、超過料金が1ブロック増えたところで逆転します。100GiBを超えた後も、3バンドルの中ではDU-100GBが最安です。

この分岐点は公式の料金表・課金条件から計算した値です。

:::details 差額と超過料金から分岐点を計算する

超過料金は、上り・下りそれぞれに必要なブロック数の大きい方で計算します。下り月1GiB以下なら下りの超過はなく、次の式になります。

https://soracom.jp/files/terms/air_terms_ja-jp.pdf

各バンドルには月額330円のアプリケーションサービス料相当の枠が含まれますが、比較では基本料金から差し引いていません。初期費用、送料、アプリケーションサービスの利用料、アカウント全体の無料枠は対象外です。

`料金 = 基本料金 + 1,100円 × ceil(max(上り通信量 - バンドル内の上り通信量, 0) / 10GB)`

`ceil`は端数の切り上げです。超過料金はブロック単位なので、差額を1GBあたりの単価で割るだけでは分岐点を求められません。

切り替え分岐点を差額で見ると次のようになります。

| 切り替え | 基本料金差 | 差額を上回る超過料金 | 大きいバンドルが安くなる上り通信量 |
| --- | ---: | ---: | ---: |
| DU-10GB → DU-50GB | 2,057円 | 2ブロック = 2,200円 | 20GiB超 |
| DU-50GB → DU-100GB | 3,025円 | 3ブロック = 3,300円 | 70GiB超 |

境界例を明示します（厳密に20GiB、70GiBの閾値で判断します）。

- 20GiBちょうど: DU-10GB適用で2,552円、DU-50GB適用で3,509円
- 20GiB+1byte: DU-10GB適用で3,652円、DU-50GB適用で3,509円となり、ここからDU-50GBが有利
- 70GiBちょうど: DU-50GB適用で5,709円、DU-100GB適用で6,534円
- 70GiB+1byte: DU-50GB適用で6,809円、DU-100GB適用で6,534円となり、ここからDU-100GBが有利

:::

## 料金を最適化するためのバンドル変更運用

plan-DUでは、**当月に一度でも選んだ最大バンドルの基本料金と容量**が適用されます。基本料金は日割り・合算されず、超過料金もその容量を基準に計算されます。

https://users.soracom.io/ja-jp/docs/air/set-bundle/

例えば、同月内に「DU-10GB → DU-50GB → DU-10GB」と変更しても、当月はDU-50GBの料金と容量を使えます。変更成功後すぐにDU-10GBへ戻すことで、翌月を最小バンドルから始められます。

## バンドル変更自動化のロジック

イベントハンドラーでSIMごとの月次通信量を監視し、**上り・下り合計10GiB超から毎日再評価**します。このルールでは上り・下りを個別に指定できないため、内訳の取得とバンドル判定をFluxで行います。

https://users.soracom.io/ja-jp/docs/event-handler/rules/

![合計10GiB超を毎日再評価し、Fluxで通信量取得・判定・変更・復元を行う構成](/images/plan-du-bundle-optimization/50-daily-flow-only.png)

Fluxの処理は「通信量取得 → バンドル判定 → 変更 → DU-10GBへ復元」の4つです。DU-10GBと判定した場合は変更しません。10GiBは見直しを始めるしきい値で、実際の切り替えは前述の20／70GiBの分岐点で判断します。

## 事前準備

設定例では、当月の通信量が`u1.standard`に集まり、下りが月1GiB以下のplan-DU SIMを使います。ACKや制御通信などの下りも含め、この上限を実績で確認します。翌月を小さいバンドルから始めるため、月初の設定はDU-10GBとします。

構築時は`plan-du-bundle-optimizer-test`という空の専用グループを作成しました。バンドル変更・復元アクションとイベントハンドラーは無効で保存し、まずサンプルデータで判定だけを確認します。

## 1. FluxアプリとIncoming Webhookを作る

1. コンソール右上のカバレッジを「日本」に切り替え、「メニュー」→「SORACOM Flux」→「Flux アプリ」を開きます。
2. 「新しい Flux アプリ を作成する」→「最初から作成」を選び、名前を`plan-du-bundle-optimizer`として作成します。

![Fluxアプリの名前と概要の設定](/images/plan-du-bundle-optimization/01-create-app.png)

3. 「チャネルを作成する」をクリックし、「API/マニュアル実行」を選んで「次へ」を押します。チャネル名を`input`として作成します。

![イベントソースでAPI・マニュアル実行を選択](/images/plan-du-bundle-optimization/02-event-source.png)

4. `input`チャネルの「イベントソース」を開き、「Incoming Webhook を作成する」をクリックします。名前を`plan-du-event-handler`として作成します。

![Incoming Webhookの名前と説明を入力](/images/plan-du-bundle-optimization/07-webhook.png)

5. 作成後の「Webhook URL を表示する」でURLを確認し、後述するイベントハンドラーに設定します。このURLには認証に使う秘密情報が含まれるため、記事や共有する画面には載せません。本文では`<FLUX_INCOMING_WEBHOOK_URL>`と表記します。

## 2. Fluxで4つの処理をつなぐ

### チャネルとSAMユーザーを用意する

各入力元チャネルで「アクション」→「アクションを追加」から、SORACOM APIまたはRepublishを選びます。名前と接続先は次のとおりです。

| 名前 | 入力元 | API・種類 | OUTPUTの送信先 |
| --- | --- | --- | --- |
| A1-get-monthly-stats | `input` | `getAirStats` | `stats` |
| A2-select-bundle | `stats` | Republish | `decision` |
| A3-upgrade-bundle | `decision` | `putBundles` | `upgraded` |
| A4-restore-bundle | `upgraded` | `putBundles` | `finished` |

![4アクションで構築したFlux Studio。変更と復元は無効](/images/plan-du-bundle-optimization/17-four-studio.png)

SORACOM APIアクションではAPI名を検索して選び、注意事項を確認して「注意点を理解して利用する」にチェックを入れます。APIのURLには`/v1`を含めます。

SAMユーザーは、次の2種類を使います。初めて作る場合は「新しく SAM User を作成する」で名前を入力すると、選んだAPIに必要な権限とFluxの信頼設定が作られます。A4では「既存の SAM User から選択する」でA3と同じユーザーを指定します。

https://users.soracom.io/ja-jp/docs/flux/action-soracom-api/

| SAMユーザー | API権限 | 使用するアクション |
| --- | --- | --- |
| `plan-du-flux-get-stats` | `Stats:getAirStats` | A1 |
| `plan-du-flux-put-bundles` | `Subscriber:putBundles` | A3・A4 |

OUTPUTを有効にし、送信先チャネルがなければ「新しくチャネルを作成する」を選びます。APIアクションのOUTPUTでは「高度な設定」→「データを変換する」にチェックし、Content Typeを`application/json`として各手順のJSONを入力します。遅延は0秒、配列の分割は無効です。

変更と復元は、成功出力を次のチャネルへ渡して順につなぎます。同じチャネルに2つのアクションを並べると非同期に実行されるため、順序を保証できません。

https://users.soracom.io/ja-jp/docs/flux/action-overview/

ERROR OUTPUTは4アクションとも有効にし、共通の`errors`チャネルへ送ります。A3・A4は、アクション自体のスイッチを「無効」にして保存してください。OUTPUTのスイッチとは別です。

### 1. 当月の上り・下り通信量を取得する

`input`にSORACOM APIアクションを追加し、名前を`A1-get-monthly-stats`、APIを`getAirStats`（GET）にします。受信した`imsi`を使い、UTC月初から現在までの月次統計を取得します。

#### 前半：CONDITIONとCONFIGを設定する

1. アクション自体のスイッチは「有効」にします。
2. CONDITIONの「アクションの実行条件」に`event.payload.speedClass == "u1.standard"`を入力します。
3. CONFIGのURLに次の式を入力し、HTTPボディは空欄にします。
4. 「APIを実行するSAMユーザー」に`plan-du-flux-get-stats`を選びます。

```text
/v1/stats/air/subscribers/${event.payload.imsi}?from=${floor(now() / 86400000) * 86400 - (getUTCDate(now()) - 1) * 86400}&to=${floor(now() / 1000)}&period=month
```

`speedClass`は統計のキーを指定する固定値です。この条件はイベント本文に`u1.standard`が入っていることを確認します。実SIMの速度クラスや料金プランを取得して確認する処理ではありません。

![A1前半：実行条件、GETのURL、空のHTTPボディ、読み取り用SAMユーザー](/images/plan-du-bundle-optimization/35-a1-condition-config.png)

#### 後半：OUTPUTで通信量をstatsへ渡す

1. OUTPUTの「アクションのアウトプットを別のチャネルに送信する」を有効にし、送信先を`stats`にします。
2. 「高度な設定」を開き、「データを変換する」にチェックします。
3. Content Typeを`application/json`にし、Contentに次のJSONを入力します。
4. 遅延は`0`秒、配列の分割はチェックを外します。

```json
{
  "imsi": "${event.payload.imsi}",
  "from": "${floor(now() / 86400000) * 86400 - (getUTCDate(now()) - 1) * 86400}",
  "checkedAt": "${now()}",
  "rowCount": "${len(result)}",
  "statsMonth": "${result[0].unixtime}",
  "uploadBytes": "${result[0].dataTrafficStatsMap[event.payload.speedClass].uploadByteSizeTotal}",
  "downloadBytes": "${result[0].dataTrafficStatsMap[event.payload.speedClass].downloadByteSizeTotal}"
}
```

上り・下り通信量に加え、次の判定で使う行数と対象月を渡します。`from`はUTC月初のUNIX秒、`checkedAt`は取得時点のUNIXミリ秒です。

![A1後半：statsへの送信、OUTPUT変換のJSON、遅延0秒と配列分割オフ](/images/plan-du-bundle-optimization/36-a1-output.png)

### 2. バンドルを決める

`stats`にRepublishアクションを追加し、名前を`A2-select-bundle`にします。対象月と下り通信量を確認してから、上り通信量に合うバンドルを選びます。

#### CONDITION：対象月と下り通信量を確認する

アクションは「有効」にし、「アクションの実行条件」に次の式を入力します。統計が1行で対象月が一致し、上り・下りが0以上、下りが1GiB以下の場合にだけ先へ進みます。

```text
toNumber(payload.rowCount) == 1 && toNumber(payload.statsMonth) == toNumber(payload.from) && toNumber(payload.uploadBytes) >= 0 && toNumber(payload.downloadBytes) >= 0 && toNumber(payload.downloadBytes) <= 1073741824
```

下りが1GiBを超えた場合は、この上り中心の分岐点を適用せず止めます。統計が空、またはカウンタが欠落している場合も、ゼロに置き換えて進めないでください。

![A2のCONDITION：アクション有効と対象月・下り1GiB以下の実行条件](/images/plan-du-bundle-optimization/37-a2-condition.png)

#### CONFIG：上り通信量からtargetを作る

1. CONFIGの「データを変換する」にチェックします。
2. Content Typeを`application/json`にします。
3. Contentに次のJSONを入力します。

```json
{
  "imsi": "${payload.imsi}",
  "checkedAt": "${payload.checkedAt}",
  "uploadBytes": "${payload.uploadBytes}",
  "downloadBytes": "${payload.downloadBytes}",
  "target": "DU-${toNumber(payload.uploadBytes) > 75161927680 ? 100 : (toNumber(payload.uploadBytes) > 21474836480 ? 50 : 10)}GB"
}
```

上り20GiB以下ならDU-10GB、20GiB超〜70GiB以下ならDU-50GB、70GiB超ならDU-100GBを`target`に入れます。IMSIや通信量も、後続処理で使うため引き継ぎます。

![A2のCONFIG：JSON変換で上り通信量に応じたtargetを作成](/images/plan-du-bundle-optimization/38-a2-config.png)

#### OUTPUT：判定結果をdecisionへ送る

OUTPUTの送信を有効にし、送信先を`decision`にします。変換はCONFIGで済んでいるため、OUTPUTの「高度な設定」には追加のデータ変換を設定しません。

![A2のOUTPUT：送信を有効にしてdecisionを指定](/images/plan-du-bundle-optimization/39-a2-output.png)

:::details 式の書き方について

`${...}`は値の埋め込みに使い、CONDITIONには囲まず式を入力します。数値を文字列で渡しているため、比較時に`toNumber`で変換します。実画面では、式内の`'DU-100GB'`のような文字列で構文エラーになったため、`DU-`と`GB`の間に数値を埋め込む形にしました。

https://users.soracom.io/ja-jp/docs/flux/action-payload-condition/

:::

### 3. 大きいバンドルに変更する

`decision`にSORACOM APIアクションを追加し、名前を`A3-upgrade-bundle`、APIを`putBundles`（PUT）にします。DU-50GBかDU-100GBと判定された場合に、そのバンドルへ変更する処理です。

#### CONDITION：変更する条件を設定する

**アクション自体のスイッチは「無効」にしておきます。**「アクションの実行条件」には、次の式を入力します。

```text
(payload.target == "DU-50GB" || payload.target == "DU-100GB") && getUTCYear(now()) == getUTCYear(toNumber(payload.checkedAt)) && getUTCMonth(now()) == getUTCMonth(toNumber(payload.checkedAt)) && (getUTCHours(now()) < 23 || getUTCMinutes(now()) < 50)
```

選択されたバンドルに加え、判定時と同じUTC月であることを確認します。また、毎日23:50〜24:00 UTCでの新たな変更処理はおこなわないようにします。（微妙にタイミングがずれて翌月に変更が入るのを極力防ぐため）


![A3のCONDITION：アクションを無効にし、変更対象とUTC日時の条件を設定](/images/plan-du-bundle-optimization/40-a3-condition.png)

#### CONFIG：選んだバンドルへの変更を設定する

1. URLに`/v1/subscribers/${payload.imsi}/bundles`を入力します。
2. HTTPボディに次のJSONを入力します。A2が選んだ`target`をそのまま渡します。
3. 「APIを実行するSAMユーザー」に`plan-du-flux-put-bundles`を選びます。

```json
["${payload.target}"]
```

![A3のCONFIG：PUTのURL、targetを渡すHTTPボディ、変更用SAMユーザー](/images/plan-du-bundle-optimization/41-a3-config.png)

#### OUTPUT：変更成功後に復元処理へつなぐ

1. OUTPUTの送信を有効にし、送信先を`upgraded`にします。
2. 「高度な設定」→「データを変換する」にチェックします。
3. Content Typeを`application/json`にし、Contentに次のJSONを入力します。
4. 遅延は`0`秒、配列の分割はチェックを外します。

```json
{
  "imsi": "${payload.imsi}",
  "target": "${payload.target}",
  "checkedAt": "${payload.checkedAt}"
}
```

APIの成功出力を受けて、このJSONを次のアクションへ渡します。OUTPUTは有効にしますが、画面上部のアクション自体は無効のまま保存します。

![A3のOUTPUT：upgradedへの送信と、IMSI・選択バンドル・判定時刻の引き継ぎ](/images/plan-du-bundle-optimization/42-a3-output.png)

### 4. DU-10GBに戻す

`upgraded`にSORACOM APIアクションを追加し、名前を`A4-restore-bundle`、APIを`putBundles`（PUT）にします。変更の成功出力を受け取り、DU-10GBに戻します。

#### CONDITION：復元する対象を確認する

**A4もアクション自体は「無効」にします。**「アクションの実行条件」に`payload.target == "DU-50GB" || payload.target == "DU-100GB"`を入力します。

![A4のCONDITION：アクション無効とDU-50GB・DU-100GBを対象にする条件](/images/plan-du-bundle-optimization/43-a4-condition.png)

#### CONFIG：DU-10GBへの復元を設定する

1. URLに`/v1/subscribers/${payload.imsi}/bundles`を入力します。
2. HTTPボディに次のJSONを入力します。戻し先は固定でDU-10GBです。
3. SAMユーザーは、A3と同じ`plan-du-flux-put-bundles`を選びます。

```json
["DU-10GB"]
```

![A4のCONFIG：DU-10GBを指定するHTTPボディとA3と共通のSAMユーザー](/images/plan-du-bundle-optimization/44-a4-config.png)

#### OUTPUT：復元結果をfinishedへ残す

1. OUTPUTの送信を有効にし、送信先を`finished`にします。
2. 「高度な設定」→「データを変換する」にチェックします。
3. Content Typeを`application/json`にし、Contentに次のJSONを入力します。
4. 遅延は`0`秒、配列の分割はチェックを外し、アクション自体は無効のまま保存します。

```json
{
  "imsi": "${payload.imsi}",
  "selected": "${payload.target}",
  "configured": "${result.bundles[0]}"
}
```

`configured`には`putBundles`の成功応答に含まれるバンドルを入れます。確認用のGETアクションは不要です。

https://github.com/soracom/soracom-cli/blob/cbc57fcb34878ab4c358d42f03f8d91bca1ecb8d/generators/assets/soracom-api.en.yaml

![A4のOUTPUT：finishedへの送信と、選択バンドル・復元後のバンドルを残すJSON](/images/plan-du-bundle-optimization/45-a4-output.png)

実SIMで動かす際は、`finished.configured`が`DU-10GB`であることを確認します。`selected`は今回選んだバンドルで、確定請求を示す項目ではありません。

## 3. 合計10GiB超を毎日再評価するイベントを作る

月次通信量は同じ月の中で増えていくため、10GiB超のルール1つで、その後も毎日見直せます。翌月は通信量がリセットされ、再び合計10GiBを超えるまで待ちます。

例えば上り9.9GiB・下り0.2GiBなら、合計10GiBを超えてFluxが起動しますが、DU-10GBのままです。その後、上り20GiBを超えた後の再評価でDU-50GBを選んでまたDU-10GBに戻るようにします。

1. 左上の「メニュー」→「SORACOM Air for セルラー」→「イベントハンドラー」を開き、「イベント作成」をクリックします。

   ![メニュー内のSORACOM Air for セルラーを展開した状態。イベントハンドラーはグループの下](/images/plan-du-bundle-optimization/31-event-menu.png)

2. 監視対象を「グループ」とし、対象のplan-DU SIMを入れる専用グループを選びます。今回は空の`plan-du-bundle-optimizer-test`を使っています。
3. ルールと再評価を次のように設定します。

| 項目 | 設定値 |
| --- | --- |
| イベント名 | `plan-du-check-10gb` |
| ルール | サブスクライバーの月次データ通信量が一定を超えたら実行 |
| しきい値 | `10240` MiB（10GiB） |
| 再評価を行うタイミング | 翌日開始時（`BEGINNING_OF_NEXT_DAY`） |
| オフセット | `0` 分 |
| 再評価を行うタイミングまで再実行しない | **チェックを外す** |

監視対象をグループにしても、このルールはグループ内の各サブスクライバーを評価します。「監視対象に紐づく全SIMの月次データ通信量合計」のルールとは異なります。

「翌日開始時」は、発火した同じSIMの評価を翌日の0:00 UTC、日本時間09:00から再開する設定です。日次通信量に切り替わるわけではなく、再評価する値は引き続き当月の累積通信量です。再開時刻ぴったりの実行は保証されません。

「再評価を行うタイミングまで再実行しない」は、同じイベントの対象に含まれる**別のSIM**の評価も待たせるオプションです。今回は各SIMを独立して判定したいのでオフにします。同じSIMの再評価間隔は「翌日開始時」で指定します。

https://users.soracom.io/ja-jp/docs/event-handler/how-it-works/

4. 「アクション追加」から、FluxへのPOSTを設定します。

| 項目 | 設定値 |
| --- | --- |
| アクション | 指定の URL にリクエストを送る（`ExecuteWebRequestAction`） |
| 実行するタイミング | すぐに実行、オフセット0分 |
| Method | POST |
| Content Type | `application/json` |
| URL | 作成したIncoming Webhook URL |
| HTTP Header | 追加なし |

Bodyには次のJSONを入力します。

```json
{"imsi":"${imsi}","speedClass":"u1.standard"}
```

`${imsi}`はイベントハンドラーの変数です。Fluxでは受信したJSONを`event.payload`として参照します。`speedClass`は統計のキーを指定する値で、SIMの速度クラスを変更する指定ではありません。

5. 画面下の「有効」はチェックを外して保存します。

設定画面全体は次のとおりです。上から監視対象、10GiBのルール、FluxへのPOSTを設定し、最下部の「有効」は外します。撮影時だけURL欄を`<FLUX_INCOMING_WEBHOOK_URL>`に置き換えています。

![イベント編集画面全体。監視対象、月次10240MiBと翌日開始時、POSTの本文、有効チェックと保存ボタンの位置](/images/plan-du-bundle-optimization/32-event-settings.png)

検証環境では、この10GiBルールを保存して開き直し、しきい値・翌日開始時の再評価・再実行抑止オフ・イベント無効を確認しました。

## 4. 判定を試した結果

2026-09-15に`stats`の「テスト実行」からサンプルデータを送信し、次の5ケースを確認しました。実SIMのIMSIは使わず、`imsi`には`TEST_SIM`を指定しています。実行時点では後段の書き込みアクションを作成していないため、SIMの設定変更は発生していません。

| 上り（バイト） | 下り（バイト） | Flux上で確認した結果 |
| ---: | ---: | --- |
| 21474836480 | 0 | DU-10GB |
| 21474836481 | 0 | DU-50GB |
| 75161927680 | 0 | DU-50GB |
| 75161927681 | 0 | DU-100GB |
| 75161927681 | 1073741825 | アクション詳細が「未実行」、decisionへの出力なし |

実行結果の`decision`をクリックすると、変換後のメッセージを確認できます。

![20GiBちょうどの判定結果。実行詳細からdecisionを開いたメッセージ詳細モーダル全体](/images/plan-du-bundle-optimization/46-result-20g-modal.png)

![70GiBを1バイト超えた判定結果。メッセージ詳細モーダルでDU-100GBの出力を確認](/images/plan-du-bundle-optimization/47-result-70g-modal.png)

行数の不一致や対象月のずれは、現時点では確認予定のケースです。上記の結果は判定部分の動作確認で、APIによるバンドル変更・復元や請求を確認したものではありません。

4アクションへ整理した後にも、上り20GiB+1バイト・下り0のデータを`stats`から投入し、DU-50GBになることと、無効にしたA3が「未実行」で止まることを確認しました。

今回使う構成は4アクション・Webhook・10GiBの1イベントです。A3・A4とイベントハンドラーは無効です。実SIMの読み取り、10GiB超からの起動、翌日の再評価、複数SIMの独立した発火、変更・復元、確定請求は未検証です。

## 実SIMで動かす前に

この例では、対象SIMをイベントハンドラーの専用グループで絞ります。Flux内でSIM情報を取得してplan-DUかどうかを再確認する処理は入れていないため、グループには対象のplan-DU SIMだけを入れてください。Incoming WebhookのURLも公開しないように気をつけましょう。

実SIMで動かす前に、次の順で確認します。

1. A3・A4を無効にしたまま、`input`から対象SIMのIMSIと`speedClass`を送り、取得した上り・下り通信量をコンソールと照合します。
2. 課金を伴う確認に進むときは、変更と復元の両方を有効にしてから`input`から実行します。一度大きいバンドルを選ぶと、その月の高い基本料金は取り消せません。
3. `finished.configured`とSIM管理画面でDU-10GBへの復元を確認し、その後に`plan-du-check-10gb`だけを有効にします。翌日にも同じSIMが再評価されること、複数SIMがそれぞれ発火することを確認します。確定請求は後日確認します。

```json
{"imsi":"<TARGET_IMSI>","speedClass":"u1.standard"}
```

### 運用上の注意

日次再評価のため、分岐点を超えてから変更までに時間差があります。月末最後の評価後に増えた通信量は当月の判定に反映できない場合があり、月額の最安を保証する構成ではありません。

下りが月1GiBを超えると、今回の判定は変更処理を止めます。下りも多い用途では、各バンドルの上り・下り両方の超過料金を比較するロジックへの拡張が必要です。

:::details 月またぎ・統計・復元失敗への対応

- 通信量の集計月はUTC基準です。翌月1日00:00 UTCは日本時間で09:00です。復元に失敗したまま翌月を迎えると、大きいバンドルの基本料金が翌月にも適用されます。失敗時は同月内に状態を確認して対処します。
- A1は`u1.standard`の統計だけを使います。当月に`u1.slow`など別の速度クラスの通信量もある場合は、この例のままでは合計になりません。全速度クラスの集計が必要です。
- A1のURLとOUTPUTでは、実行時刻からUTC月初を計算します。月またぎの実行検証は未実施です。行数や対象月の不一致を含め、実行履歴で確認してください。
- この構成はSIMごとの排他制御、処理済みの台帳、自動再試行を持ちません。毎日の再評価と手動実行などで処理が重なる可能性があります。同月に同じ大きいバンドルを選び直しても基本料金は積み上がりませんが、Fluxイベントを消費します。
- `errors`と`finished`の両方を確認します。条件不成立で止まった場合はAPIエラーとは別です。復元側には月末の停止条件を付けず、成功出力を受けたら戻します。
- 停止時はまず`plan-du-check-10gb`を無効にします。処理中の復元まで止めないよう、現在バンドルと実行履歴を確認してから書き込みアクションを無効化します。

:::

SORACOM APIアクション自体の利用とAPI実行は無料ですが、Fluxのイベント消費は発生します。SIM数に応じてFluxのプランと上限設定を確認してください。

https://users.soracom.io/ja-jp/docs/flux/plans/

https://users.soracom.io/ja-jp/docs/flux/set-upper-limit/

## まとめ

イベントハンドラーには、合計10GiB超を毎日再評価する1つのルールを設定します。Fluxでは上り・下りの実績を取得し、今回の下り1GiB以下という前提を確認してから、上り20GiB超でDU-50GB、70GiB超でDU-100GBを選びます。

変更後はすぐDU-10GBへ戻し、翌月に備えます。毎日の見直しと、月内に選んだ最大バンドルが適用される課金仕様を組み合わせた構成です。

設定の保存と判定テストまでは確認できました。実運用では日次の再評価と復元の完了を確認し、月末最後の通信量が判定から漏れる場合もあることを踏まえて使ってください。

## 参考資料

https://soracom.jp/services/air/japan_coverage/

https://soracom.jp/files/terms/air_terms_ja-jp.pdf

https://users.soracom.io/ja-jp/docs/air/set-bundle/

https://users.soracom.io/ja-jp/docs/air/view-data-usage/

https://users.soracom.io/ja-jp/docs/flux/incoming-webhook/

https://users.soracom.io/ja-jp/docs/flux/action-soracom-api/

https://users.soracom.io/ja-jp/docs/flux/action-overview/

https://users.soracom.io/ja-jp/docs/flux/create-channel/

https://users.soracom.io/ja-jp/docs/flux/send-action-errors-to-channel/

https://users.soracom.io/ja-jp/docs/flux/action-payload-condition/

https://users.soracom.io/ja-jp/docs/flux/action-output-advanced-settings/

https://users.soracom.io/ja-jp/docs/flux/action-republish/

https://users.soracom.io/ja-jp/docs/event-handler/actions/

https://users.soracom.io/ja-jp/docs/event-handler/rules/

https://users.soracom.io/ja-jp/docs/event-handler/how-it-works/

https://users.soracom.io/ja-jp/docs/flux/plans/

https://users.soracom.io/ja-jp/docs/flux/set-upper-limit/

https://zenn.dev/takao2704/articles/soracom-air-tariff-cheatsheet
