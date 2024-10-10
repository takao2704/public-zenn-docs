#!/bin/zsh

# デフォルト値を設定
DEFAULT_FROM_DATE="2024-07-01"  # デフォルトの開始日
DEFAULT_TO_DATE="2024-10-31"    # デフォルトの終了日

# 引数から日付を取得（指定がない場合はデフォルト値を使用）
FROM_DATE="${1:-$DEFAULT_FROM_DATE}"
TO_DATE="${2:-$DEFAULT_TO_DATE}"

# 取得する期間の表示
echo "開始日: $FROM_DATE"
echo "終了日: $TO_DATE"

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
all_sims=($(soracom sims list --fetch-all --api-key "$apiKey" --api-token "$apiToken" | jq -r '.[].profiles[].subscribers[].imsi'))
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
