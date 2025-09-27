# AGENTS.md

This file provides guidance to agents when working with code in this repository.

- リポ性質: Zenn記事+画像資産のみ。ビルド/テスト/依存管理なし。構成変更は公開資産の参照断に直結。
- 画像配置の制約: 月別フォルダ（例: [`images/202505`](images/202505)）と記事別フォルダ（例: [`images/button-to-lineworks-with-flux`](images/button-to-lineworks-with-flux)）が併存。統合・移動・リネームは不可。
- 記事命名の混在: [`articles/`](articles) にはハッシュIDとスラッグが混在（例: [`articles/2d8e58423587dc.md`](articles/2d8e58423587dc.md), [`articles/button-to-lineworks-with-flux.md`](articles/button-to-lineworks-with-flux.md)）。「記事名=画像フォルダ名」の前提で自動化/情報設計をしない。
- 絶対パス前提: 記事内画像は `](/images/...)` を既定。相対 `](../images/...)` は公開前に [`imagepathpatch.sh`](imagepathpatch.sh) で置換。運用設計では絶対パスを前提に。
- 非標準スクリプト依存: [`imagepathpatch.sh`](imagepathpatch.sh) は macOS/BSD sed 前提（`-i ''`）。Linux/CIでの再現性は別実装に切り出す設計とする。
- 作業単位の原則: 画像/記事の追加はフォルダ単位の加法的変更を原則。既存資産の再配置・削除は避け、差分最小の増築を選ぶ。
- ダミーファイルの保存: 空ディレクトリ維持用の `dummy` が存在（例: [`images/cheatsheet/dummy`](images/cheatsheet/dummy), [`images/lagoon-lamp/dummy`](images/lagoon-lamp/dummy), [`images/ramenlife/dummy`](images/ramenlife/dummy)）。クリーンアップ対象に含めない。
- 配布物の固定パス: ダウンロード素材は [`files/`](files) に固定（例: `files/pillow-layer.zip`）。命名変更/移動を禁止。
- 単一情報源: 運用詳細は [`CLAUDE.md`](CLAUDE.md) に集約。READMEは最小。新規運用ルールは CLAUDE.md に追記し、重複規約を作らない。
- 自動化の落とし穴: [`imagepathpatch.sh`](imagepathpatch.sh) の対象は `articles/[^.]*.md` のみ。`articles/` サブディレクトリや [`books/`](books) 配下は変換されない前提でフロー設計。
- 命名のばらつき: 画像名は `image-1.png` 等の連番とID系の混在。厳格スキーマ導入は既存と衝突しやすく、段階移行（並行運用→マイグレーション）を前提に。