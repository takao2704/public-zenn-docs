#!/bin/zsh

# バックアップを作成するかどうかのフラグ（0=作成しない、1=作成する）
CREATE_BACKUP=0

# articles ディレクトリ内の非隠しファイルの .md ファイルを処理
for file in articles/[^.]*.md; do
  # ファイルが存在するか確認
  if [[ -f "$file" ]]; then
    echo "処理中: $file"
    
    # バックアップフラグが1の場合のみバックアップを作成
    if [[ $CREATE_BACKUP -eq 1 ]]; then
      cp "$file" "${file}.bak"
      echo "バックアップ作成: ${file}.bak"
    fi
    
    # ![任意のテキスト](../images を ![任意のテキスト](/images に置換
    sed -i '' 's/\(!\[.*\]\)(\.\./\1(/g' "$file"
    
    # 確認のため、置換後のパターンを表示
    echo "置換結果:"
    grep -n "!\[.*\](/images" "$file" | head -5
    echo "---"
  fi
done

echo "すべてのファイルの処理が完了しました。"
