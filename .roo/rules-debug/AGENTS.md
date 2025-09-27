# AGENTS.md

This file provides guidance to agents when working with code in this repository.

- 実行後検証: [`imagepathpatch.sh`](imagepathpatch.sh) は記事内の画像パスをインプレース置換するため、実行直後に `git diff` で全変更行を確認し、意図しない差分が無いか目視すること（特に大量記事一括時）。
- 置換対象の実態: スクリプトは `!\[...\](..` という「画像マークダウン かつ `../` 始まり」のリンク全般から `../` を除去する（パス末尾が `images/` 固定ではない点に注意）。相対参照で `../files/...` 等を画像として貼っていた場合でも `../` が除去される。
- 範囲の盲点: 処理対象は `articles/[^.]*.md` のみ。`articles/` サブディレクトリ配下や `books/` は未処理のため、相対画像リンクが残存しうる。誤検知時は対象ファイルの場所をまず確認。
- macOS 依存: `sed -i ''` 前提。GNU sed 環境（Linux CI 等）では失敗するため、実行環境が macOS 以外でエラーが出たら `-i -e` への置換など移植対応が必要。
- バックアップ方針: 広範囲変更・初回適用時は [`imagepathpatch.sh`](imagepathpatch.sh) 冒頭の `CREATE_BACKUP=1` にして `.bak` を生成。万一の誤置換時は `.bak` から速やかに復旧し、原因（対象外パス混入等）を切り分ける。
- 想定と異なる変換の兆候: 変更後に `/images/` 以外（例: `/files/`）へ変換された画像リンクが増える、もしくは画像が表示されなくなる場合、原稿中の相対参照運用が混在している可能性が高い。該当行だけ手戻し（`.bak` or `git restore`）し、記事単位で運用を揃える。
- 確認のコマンド出力は限定的: スクリプト末尾の `grep -n "!\[.*\](/images"` は最大5件までしか表示しない。件数が多い記事では網羅できないため、必要に応じてファイル全体を開き全出現箇所を確認する。
- 既存の絶対パスは無変化: すでに `](/images/...)` の記事が大半。不要な再実行で副作用は基本出ないが、混在記事では上記リスクを再確認。
- 画像資産の前提: 画像ディレクトリは月別（例: [`images/202505/`](images/202505)）と記事別（例: [`images/button-to-lineworks-with-flux/`](images/button-to-lineworks-with-flux)）が併存し、さらに空維持用の `dummy`（例: [`images/cheatsheet/dummy`](images/cheatsheet/dummy)）が存在。誤削除・移動はリンク切れの主因になる。
- 参照断の典型: 「記事ファイル名＝画像フォルダ名」という前提が成り立たない（ハッシュID系とスラッグが混在。例: [`articles/2d8e58423587dc.md`](articles/2d8e58423587dc.md), [`articles/button-to-lineworks-with-flux.md`](articles/button-to-lineworks-with-flux.md)）。自動修復系スクリプトの前提にしない。