# AGENTS.md

This file provides guidance to agents when working with code in this repository.

- 非標準コマンド: [imagepathpatch.sh](imagepathpatch.sh) は `articles/` 直下の `.md` だけを対象に、画像リンクの先頭 `../` を取り除き `/images/...` へ正規化する（`sed -i ''` によるインプレース置換）。macOS/BSD sed 前提のため GNU sed では失敗する。Linux で使う場合は `sed -i -e` 等に改変すること。
- 置換の安全運用: デフォルトでバックアップ無効（`CREATE_BACKUP=0`）。広範囲変更や初回適用時は `CREATE_BACKUP=1` にしてから実行し、終了後に `git diff` で意図せぬ一括置換が無いか確認する。
- 適用範囲の盲点: `articles/[^.]*.md` のみ対象。`books/` やサブディレクトリ配下の原稿は変換されないため、そこに画像を置く運用は避けるか、別途調整が必要。
- 現状の実態: 多くの記事は既に絶対パス形式 `](/images/...)` を使用。下書きで相対 `](../images/...)` を書いた場合のみ公開前に [imagepathpatch.sh](imagepathpatch.sh) を実行する。
- 画像フォルダの混在: 日付ベース（例: `/images/202505/`）とトピック/記事別（例: `/images/button-to-lineworks-with-flux/`）が併存。フォルダ名変更は広範囲の参照断を招くため禁止。
- 記事ファイル名の混在: ハッシュID（例: `articles/2d8e58423587dc.md`）とスラッグ（例: `articles/button-to-lineworks-with-flux.md`）が混在。自動化で「記事ファイル名 = 画像フォルダ名」と仮定しないこと。
- ダミーファイル: 空ディレクトリ維持のための `dummy` が複数存在（例: [images/cheatsheet/dummy](images/cheatsheet/dummy), [images/lagoon-lamp/dummy](images/lagoon-lamp/dummy), [images/ramenlife/dummy](images/ramenlife/dummy)）。削除・改名禁止。
- 配布物の安定性: 記事から参照される配布物は [files/](files/) 配下（例: `files/pillow-layer.zip`）。ファイル名・パスの変更は手順崩壊につながるため避ける。
- CLAUDEガイドの要点: [CLAUDE.md](CLAUDE.md) で「相対→絶対」変換前提のワークフローが明示されている。手順から外れた画像記法を混ぜないこと。
- 規約ファイルなし: `.editorconfig` や markdownlint 等の設定は未検出。プロジェクト内の既存パターン（画像は絶対パス、`image-1.png` などの連番命名）に合わせる。
- ビルド/テスト無し: ビルドスクリプトやテスト基盤は存在しないコンテンツ専用リポジトリ。自動整形や CI 前提の提案は行わない。
- 運用チェックリスト: 画像追加時は「配置フォルダの一貫性」「リンクの絶対パス化」「`dummy` の維持」を確認し、必要なら [imagepathpatch.sh](imagepathpatch.sh) の適用と `git diff` の目視確認を行う。