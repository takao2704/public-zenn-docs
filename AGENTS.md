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
## ライティングスタイル / 文体規約（articles/*.md）

以下は本リポジトリの既存記事（例: [articles/button-to-lineworks-with-flux.md](articles/button-to-lineworks-with-flux.md), [articles/forms-sending-photo.md](articles/forms-sending-photo.md), [articles/vpg-sim-based-routing-mas120.md](articles/vpg-sim-based-routing-mas120.md), [articles/soracom-air-tariff-cheatsheet.md](articles/soracom-air-tariff-cheatsheet.md), [articles/soracamimg-to-azure.md](articles/soracamimg-to-azure.md) 等) から抽出した、文章構成・文調・表記の実態と推奨ルールです。

- フロントマター（必須/推奨）
  - 必須: `title`, `emoji`, `type` は `tech` を基本、`topics` は配列、`published` を明示（true/false）
  - 任意: `published_at`（公開日時を固定表示したい場合のみ）
  - タイトルは日本語中心。固有名詞の公式表記を尊重（例: SORACOM Canal, Route 53, Private Hosted Zone）
  - topics は 3〜6 程度までを目安に、技術タグを簡潔に

- 章立ての基本構成
  - 導入セクションは「はじめに」を原則。見出しレベルは「推奨: `## はじめに`（H2）」、許容: `# はじめに`（H1）
    - 理由: Zenn タイトルとの重複を避け、本文の最上位は H2 起点にする慣行が多い
  - 記事末尾に「まとめ」を原則配置（同じく H2 を推奨）
  - 中央部は目的別に H2/H3 を使い分ける（例: 設計/手順/検証/トラブルシュート/参考/コスト など）
  - 手順は番号付きリスト（1., 2., ...）とスクリーンショットの併用が既定パターン

- 文体・トーン
  - です/ます調で一貫した丁寧体。読み手に行動を促す記述（〜しましょう）を許容
  - 主語は過度に明示しない簡潔な技術解説調。冗長な比喩や雑談は抑制
  - 専門用語は初出で正式名称＋略語（例: Route 53 Private Hosted Zone（PHZ））を示し、以降は略語

- 画像と図表
  - 画像は絶対パスで参照（`](/images/...)`）。相対は下書き時のみ可とし、公開前に [imagepathpatch.sh](imagepathpatch.sh) で置換
  - 画像は手順直下に配置し、キャプションや直前文で意図を補足
  - Mermaid 図の利用可。Zenn の仕様上、角括弧内にダブルクォートや括弧を混在させない
    - 例: `[Route 53 PHZ]` は可、`["Route 53 (PHZ)"]` は非推奨

- コード/コマンド記法
  - フェンスコードは言語を明示（例: ```bash, ```ini）。1 セクション 1 操作単位で短く区切る
  - インラインコードはバッククォートで強調（例: `AllowedIPs`, `resolvectl`）
  - 実行例は出力を必要最小限に。機微情報は `&lt;redacted&gt;` などでマスク

- 一貫表記（例）
  - SORACOM サービス名: SORACOM Air / Arc / Canal / Gate / Lagoon / Harvest Data
  - AWS サービス名: Route 53 / Private Hosted Zone / Resolver inbound endpoint
  - ネットワーク用語: CIDR, MTU, SG（Security Group は初出で展開）
  - 固有略語: Private Hosted Zone は「PHZ」を採用

- 検証/運用セクションの原則
  - 検証計画: 成功条件/観測ポイント/確認コマンド（`dig`, `curl`, `resolvectl`, `ip route` 等）
  - トラブルシュート: 代表事象（NXDOMAIN/Timeout/ServFail 等）と原因切り分け観点
  - コスト/セキュリティ: エンドポイント時間課金/転送料/最小権限 SG/監査ログ などの所感

- 書式ルール（細目）
  - 箇条書きは「-」を基本。見出し直後に一行空ける
  - 1 行を過度に長くしない（画像/コードの直前直後は空行で区切る）
  - 外部リンクは行頭または直後に素置き（パーマリンクを優先）

### レビューチェックリスト（運用用）

- [ ] フロントマターが揃っている（title/emoji/type/topics/published）
- [ ] 「はじめに」と「まとめ」がある（H2 推奨）
- [ ] 手順は番号付き/画像は絶対パス
- [ ] コードブロックに言語指定（bash/ini 等）
- [ ] 用語の初出で正式名称＋略語を提示
- [ ] 検証/トラブルシュート/コストの記載がある
- [ ] 文体がです/ます調で一貫
- [ ] Mermaid 図があれば構文/表記の注意点を満たす