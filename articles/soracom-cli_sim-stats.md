---
title: "大量の回線の過去何ヶ月かの利用状況を把握する"
emoji: "📊"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [soracom,zsh]
published: false
---
:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::
## やりたいこと
保有するSIMの数が増えてくると、実はあんまり使ってないSIMもあるんじゃないか？と思って調べたくなることがあります。
一応、サービス利用履歴をCSVダウンロードすることもできますが、SIMの枚数がいっぱいあると結構大変です。
![alt text](image.png)
ダウンロードしたCSVをExcelで開いて、集計するのも結構面倒です。
ファイルのフォーマットとか・・・
![alt text](image-1.png)
こういった作業は定期的にやるケースがあると思うので、ある程度自動化したいですよね。

今回のブログでは、「ここnヶ月であんまり使ってないSIMを割り出す！」ということをSORACOM CLIを使ってやってみたいと思います。

## 前提
今回はmacOSを使って進めます。
(Windowsの場合は、PowerShellを使って進めることができます。ニーズがあれば、Windowsの場合の記事も書きます。)

## 準備

### SORACOM-CLIをセットアップ
基本的にこちらの通り。
- homebrewを使ってインストールする場合
    
    https://users.soracom.io/ja-jp/tools/cli/getting-started/?tab-2-1=selected

- homebrewを使わない場合
    
    https://users.soracom.io/ja-jp/tools/cli/getting-started/?tab-2-2=selected

    versionやOSに合わせてインストールが必要です。
    https://github.com/soracom/soracom-cli/releases

    お使いのmacのCPUがM1/M2/M3の場合はdarwin_arm64を、それ以外の場合はdarwin_amd64を選びましょう。



### 認証情報の準備
https://users.soracom.io/ja-jp/tools/cli/getting-started/?tab-2-1=selected#%e3%82%b9%e3%83%86%e3%83%83%e3%83%97-2-%e8%aa%8d%e8%a8%bc%e6%83%85%e5%a0%b1%e3%82%92%e6%ba%96%e5%82%99%e3%81%99%e3%82%8b

ここにも書いてある通り、SAM ユーザーの認証キーを使いましょう。ということで、こちら　https://users.soracom.io/ja-jp/docs/sam/create-sam-user/　の手順に沿ってやっていきます。
認証キーは無くさないように大事にしまっておきましょう。

:::message
発行されたキーはテキストエディタなどにコピペして保存しておきつつ、この画面は後で使いやすいので開いたままにしておきましょう。
![alt text](image-2.png)
:::

### 認証情報の保存
https://users.soracom.io/ja-jp/tools/cli/getting-started/?tab-2-1=selected#%e3%82%b9%e3%83%86%e3%83%83%e3%83%97-3-%e8%aa%8d%e8%a8%bc%e6%83%85%e5%a0%b1%e3%82%92%e4%bf%9d%e5%ad%98%e3%81%99%e3%82%8b

ここまで終わったらSORACOM CLIが使えるようになります。

## 練習
ターミナルを立ち上げます。

![alt text](image-3.png)

![alt text](image-4.png)

試しに、持っているSIMの一覧を引き出してみましょう。
```
soracom sims list
```
何かそれっぽいJSONが出てきたら大成功です。

![alt text](image-6.png)

## 本番

いよいよここからです。


結論から書きます。スクリプトは以下のとおりです。

```zsh
#!/bin/zsh

# デフォルトの日付設定
DEFAULT_FROM_DATE="2024-07-01"  # デフォルト開始日
DEFAULT_TO_DATE="2024-10-31"    # デフォルト終了日

# 引数が渡されていれば、それを使用。なければデフォルト値を使用
FROM_DATE=${1:-$DEFAULT_FROM_DATE}  # 第1引数が指定されていなければデフォルト値
TO_DATE=${2:-$DEFAULT_TO_DATE}      # 第2引数が指定されていなければデフォルト値

# UNIX秒に変換
FROM_UNIX=$(date -j -f "%Y-%m-%d" "$FROM_DATE" +%s)
TO_UNIX=$(date -j -f "%Y-%m-%d" "$TO_DATE" +%s)

# データ通信量が0のSIMを格納する配列
inactive_sims=()

# authkey,IDを取得
configure=$(soracom configure get)
authKeyId=$(echo $configure | jq -r '.authKeyId')
authKey=$(echo $configure | jq -r '.authKey')

# APIキーとトークンを取得
auth_info=$(soracom auth --auth-key-id "$authKeyId" --auth-key "$authKey" --token-timeout-seconds 3600)
apiKey=$(echo "$auth_info" | jq -r '.apiKey')
apiToken=$(echo "$auth_info" | jq -r '.token')

# 全てのSIMのIMSIを取得
all_sims=($(soracom sims list --fetch-all | jq -r '.[].profiles[].subscribers[].imsi'))
total_sims=${#all_sims[@]}  # 総SIM数

# プログレスバーの表示関数
display_progress() {
    local progress=$1
    local bar_width=50
    local filled=$((progress * bar_width / 100))
    local empty=$((bar_width - filled))
    
    printf "\r["
    printf "#%.0s" $(seq 1 $filled)
    printf " %.0s" $(seq 1 $empty)
    printf "] %d%%" $progress
}

# 各SIMのデータ通信量を確認
for ((i=0; i<total_sims; i++)); do
    imsi=${all_sims[$i]}
    
    # データ通信量を取得
    data_usage=$(soracom stats air get --imsi "$imsi" --from "$FROM_UNIX" --to "$TO_UNIX" --period "month" --api-key "$apiKey" --api-token "$apiToken" 2>> error.log)

    # エラーチェック
    if [[ $? -ne 0 ]]; then
        echo "IMSI: $imsi のデータ取得に失敗しました。" >> error.log
        continue
    fi

    # データ通信量が0の場合、配列に追加
    download=$(echo "$data_usage" | jq '.[].dataTrafficStatsMap[].downloadByteSizeTotal' | awk '{s+=$1} END {print s}')
    upload=$(echo "$data_usage" | jq '.[].dataTrafficStatsMap[].uploadByteSizeTotal' | awk '{s+=$1} END {print s}')

    if [[ "$download" -eq 0 && "$upload" -eq 0 ]]; then
        inactive_sims+=("$imsi")
    fi

    # 進捗率の表示
    progress=$(( (i + 1) * 100 / total_sims ))
    display_progress $progress
done

# 結果を表示
echo ""  # プログレスバーの改行
if [[ ${#inactive_sims[@]} -eq 0 ]]; then
    echo "全てのSIMがデータ通信を行っています。"
else
    echo "データ通信を行っていないSIM:"
    for sim in "${inactive_sims[@]}"; do
        echo "$sim"
    done
fi
```