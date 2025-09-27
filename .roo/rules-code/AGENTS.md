# AGENTS.md

This file provides guidance to agents when working with code in this repository.

- 編集時の非標準コマンド: [`imagepathpatch.sh`](imagepathpatch.sh) は `articles/[^.]*.md` のみ対象。相対 `](../images/...)` を絶対 `](/images/...)` に一括変換。macOS/BSD sed 固有の `-i ''` を使用。Linux では `-i -e` 等に置換。
- バックアップ運用: スクリプト先頭の `CREATE_BACKUP=0` を初回や広範囲変更時のみ `1` に変更。実行後は `git diff` で意図しない置換が無いか必ず確認。
- 適用範囲の盲点: `books/` や `articles/` サブディレクトリ配下は対象外。そこに原稿/画像を置く運用は追加対応が必要。
- 画像パスの前提: 記事では絶対パス `/images/...` が既定。相対で書いた下書きは公開前にパッチ必須。
- 命名の混在リスク: 記事ファイルはハッシュIDとスラッグが混在（例: `articles/2d8e58423587dc.md` と `articles/button-to-lineworks-with-flux.md`）。自動化で「記事名=画像フォルダ名」と仮定しない。
- 画像フォルダ再配置禁止: 月別（`/images/202505/`）と記事別フォルダが併存。フォルダ名変更や移動は参照断を誘発するため行わない。
- ダミーファイル保全: 空ディレクトリ維持用の `dummy` が複数存在（例: `images/cheatsheet/dummy` など）。削除・改名禁止。
- 配布物の固定パス: 記事から参照される配布物は [`files/`](files/) 配下に固定。ファイル名変更は手順崩壊につながる。
- 参考: ワークフローの要点は [`CLAUDE.md`](CLAUDE.md) に集約。

編集時チェックリスト:
- [ ] 画像追加は既存パターンに合わせて配置（記事別 or 月別）
- [ ] 画像リンクは絶対パス化（必要なら [`imagepathpatch.sh`](imagepathpatch.sh) 実行）
- [ ] `dummy` と配布物パスの破壊がないか確認