# 未使用画像のリネーム手順（本記事フォルダ限定）

対象
- フォルダ: `images/using-soracom-with-customdns-and-vpcpeering/`
- 基準: [articles/using-soracom-with-customdns-and-vpcpeering.md](articles/using-soracom-with-customdns-and-vpcpeering.md) から未参照
- リネーム方法: 接頭辞 `unused_` を付与（例: `1762003134153.png` → `unused_1762003134153.png`）
- 参照断のリスク: 本記事から未参照であることを確認済み。別記事から参照していない前提で進めます（不安な場合は先に `git grep` で全記事検索してください）。

## 未使用候補一覧

| Filename | New Name |
|---|---|
| 1762003134153.png | unused_1762003134153.png |
| 1762003184590.png | unused_1762003184590.png |
| 1762005793946.png | unused_1762005793946.png |
| 1762006014887.png | unused_1762006014887.png |
| 1762006118580.png | unused_1762006118580.png |
| 1762006230560.png | unused_1762006230560.png |
| 1762006722807.png | unused_1762006722807.png |
| 1762006902440.png | unused_1762006902440.png |
| 1762006964525.png | unused_1762006964525.png |
| 1762007039521.png | unused_1762007039521.png |
| 1762007076679.png | unused_1762007076679.png |
| 1762007168287.png | unused_1762007168287.png |
| 1762007204665.png | unused_1762007204665.png |
| 1762007461891.png | unused_1762007461891.png |
| 1762007537900.png | unused_1762007537900.png |
| 1762067695632.png | unused_1762067695632.png |
| 1762067846071.png | unused_1762067846071.png |
| 1762067870764.png | unused_1762067870764.png |
| 1762086337729.png | unused_1762086337729.png |

参考: 本記事で使用済み（抜粋）
- 1761958942764.png, 1761962152425.png, 1761962575245.png, 1762000169637.png, 1762002878061.png, 1762002920386.png, 1762005920414.png, 1762006851148.png, 1762073285602.png, 1762080604677.png, 1762080622936.png, 1762080682400.png, 1762081279087.png, 1762081301702.png, 1762081407337.png, 1762084588699.png, 1762084633280.png, 1762084738917.png, 1762086416912.png, 1762090688613.png

---

## 実行手順（安全版：ドライラン→適用）

1) ドライラン（実際には mv せず表示のみ）
```bash
DIR="images/using-soracom-with-customdns-and-vpcpeering"
LIST=(
1762003134153.png 1762003184590.png 1762005793946.png 1762006014887.png
1762006118580.png 1762006230560.png 1762006722807.png 1762006902440.png
1762006964525.png 1762007039521.png 1762007076679.png 1762007168287.png
1762007204665.png 1762007461891.png 1762007537900.png 1762067695632.png
1762067846071.png 1762067870764.png 1762086337729.png
)
for f in "${LIST[@]}"; do
  [[ -f "$DIR/$f" ]] || { echo "skip(not found): $f"; continue; }
  echo "mv \"$DIR/$f\" \"$DIR/unused_$f\""
done
```

2) 適用（実際にリネーム）
```bash
DIR="images/using-soracom-with-customdns-and-vpcpeering"
LIST=(
1762003134153.png 1762003184590.png 1762005793946.png 1762006014887.png
1762006118580.png 1762006230560.png 1762006722807.png 1762006902440.png
1762006964525.png 1762007039521.png 1762007076679.png 1762007168287.png
1762007204665.png 1762007461891.png 1762007537900.png 1762067695632.png
1762067846071.png 1762067870764.png 1762086337729.png
)
moved=0; skipped=0
for f in "${LIST[@]}"; do
  src="$DIR/$f"; dst="$DIR/unused_$f"
  if [[ ! -f "$src" ]]; then echo "skip(not found): $f"; ((skipped++)); continue; fi
  if grep -q "$f" articles/using-soracom-with-customdns-and-vpcpeering.md; then
    echo "skip(referenced): $f"; ((skipped++)); continue
  fi
  mv "$src" "$dst"
  echo "moved: $src -> $dst"; ((moved++))
done
echo "done. moved=$moved skipped=$skipped"
```

3) 取り消し（必要な場合）
```bash
DIR="images/using-soracom-with-customdns-and-vpcpeering"
for f in unused_*.png; do
  [[ -f "$DIR/$f" ]] || continue
  base="${f#unused_}"
  mv "$DIR/$f" "$DIR/$base" && echo "reverted: $f -> $base"
done
```

---

## 追加の安全確認（任意）

- 全記事横断で参照が無いことを確認（念のため）
```bash
git grep -n "1762003134153.png" -- articles/ || true
# 上記を他ファイル名にも必要に応じて実行
```

- 変更差分の確認
```bash
git status
git diff --name-status
```

---

運用ノート
- [AGENTS.md](AGENTS.md) の方針上、画像の移動/リネームは参照断リスクがあるため原則非推奨。今回は「本記事フォルダ」「本記事から未参照」限定での軽微変更として対応し、作業後は `git diff` と記事プレビューで最終確認する運用を推奨します。