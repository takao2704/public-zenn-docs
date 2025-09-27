# AGENTS.md

This file provides guidance to agents when working with code in this repository.

- 参照の優先順位: ワークフローは [CLAUDE.md](CLAUDE.md) に明示。README は最小構成のため判断材料にならないケースが多い。
- 画像パスの事実: 公開済み記事はほぼ全て `](/images/...)` の絶対パス。相対 `](../images/...)` は下書きのみ。回答やサンプルでは絶対パスで示す。
- 画像フォルダの併存: 月別 [images/202505](images/202505) と記事別 [images/button-to-lineworks-with-flux](images/button-to-lineworks-with-flux) が共存。整理提案（統合/移動）はリンク断の原因になるため非推奨。
- 記事ファイル名の混在: ハッシュIDとスラッグが混在（例: [articles/2d8e58423587dc.md](articles/2d8e58423587dc.md), [articles/button-to-lineworks-with-flux.md](articles/button-to-lineworks-with-flux.md)）。「記事名=画像フォルダ名」の前提で推論しない。
- ダミーファイルの意図: 空ディレクトリ維持用の `dummy` が存在（例: [images/cheatsheet/dummy](images/cheatsheet/dummy)）。削除提案やクリーンアップ促しは行わない。
- 配布物の所在: 記事から参照される配布物は [files/](files/) 配下に固定（例: `files/pillow-layer.zip`）。名称変更や移動を助言しない。
- 非標準スクリプトの参照先: 画像パス不整合の相談には [imagepathpatch.sh](imagepathpatch.sh) を案内。macOS の `sed -i ''` 依存やバックアップフラグ（`CREATE_BACKUP`）の注意点も併記。
- 誤案内の典型回避: `books/` や `articles/` サブディレクトリ配下は [imagepathpatch.sh](imagepathpatch.sh) の対象外。変換されない前提で説明する。
- 実例優先: 具体例は既存記事/画像へのリンクで提示（例の通りにパスを記す）。独自命名や構成の提案は避け、現状パターンに倣う。
- 運用の前提: 本リポはビルド/テスト無しのコンテンツ専用。CI/整形ツール導入前提の回答は避け、手動運用を前提に説明する。