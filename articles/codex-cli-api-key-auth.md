---
title: "Codex CLIだけAPIキー運用にするためにCODEX_HOMEを分ける"
emoji: "🔑"
type: "tech"
topics: ["openai", "codex", "cli", "api", "macos"]
published: true
---

## やりたいこと

Codex app や VS Code 拡張の ChatGPT Business ログイン環境はそのまま残しつつ、Codex CLI だけを API 従量課金用の別環境として使い分けます。

## はじめに

普段は ChatGPT Business のアカウントで Codex のデスクトップアプリを使い、プラグインやオートメーションを組み合わせて Slack や Google Workspace と連携しながら、業務効率化をガンガン進めています。

一方で、諸事情により一部の作業は Codex CLI で実行し、さらに CLI での作業だけは OpenAI Platform の API 従量課金として扱いたくなりました。

ここで問題になるのが、Codex app、VS Code 拡張、Codex CLI が通常は同じ `~/.codex` を参照することです。普通にログインし直したり設定を変えたりすると、CLI だけを切り替えたいつもりでも、デスクトップアプリや VS Code 拡張側の認証状態に影響する可能性があります。

そこでこの記事では、`CODEX_HOME` を使って Codex CLI の設定や認証情報の保存先を分け、CLI だけを API キー用の環境として使う方法をまとめます。あわせて、既存環境で使っていた skills や CLI のローカルセッション履歴も、必要なものだけ API キー用環境へ同期する手順を紹介します。

この記事の内容は、macOS / zsh / Codex CLI `0.135.0` で確認しています。

## 結論

やることは次の 3 つです。

1. API キー用の `CODEX_HOME` を作る
2. API キーをファイルに直書きせず、ログイン時または実行時だけ渡す
3. 必要なら `codex` コマンドを API キー用ホームへ向ける

最小構成は以下です。`OPENAI_API_KEY` に API キーが入っている前提です。

```bash
mkdir -p "$HOME/.codex-api"
printenv OPENAI_API_KEY | CODEX_HOME="$HOME/.codex-api" codex login --with-api-key
CODEX_HOME="$HOME/.codex-api" codex exec "Say hello"
```

毎回 `CODEX_HOME=...` と打ちたくない場合は、alias を使います。

```bash
echo "alias codex='CODEX_HOME=\$HOME/.codex-api command codex'" >> ~/.zshrc
source ~/.zshrc
```

この alias には API キーを含めません。

## 前提

この記事では、以下が済んでいる前提です。

- Codex CLI がインストール済み
- OpenAI Platform の API キーを発行済み
- macOS の zsh を使用している

Codex CLI のバージョンは以下で確認できます。

```bash
codex --version
```

この記事では次のバージョンで確認しました。

```text
codex-cli 0.135.0
```

## Codex の認証方式

Codex は、OpenAI モデルを使う場合に大きく 2 種類のサインイン方法を持ちます。

- ChatGPT でサインインする
- API キーでサインインする

ChatGPT でサインインした場合は ChatGPT 側の workspace やプランの扱いになります。API キーでサインインした場合は OpenAI Platform 側の API 利用として扱われます。

また、Codex CLI と IDE 拡張はログイン情報を共有します。通常の `~/.codex` をそのまま使っていると、CLI のログアウトやログイン変更が IDE 拡張側にも影響する可能性があります。

そこで、CLI 用に別の `CODEX_HOME` を使います。

## CODEX_HOME で状態ディレクトリを分ける

`CODEX_HOME` は、Codex の設定、認証情報、ログ、セッション、skills などを置くルートディレクトリです。デフォルトは `~/.codex` です。

ざっくり言うと、`CODEX_HOME` を変えると「Codex が自分の状態を読み書きする場所」を丸ごと切り替えられます。

代表的には、次のようなファイルやディレクトリが置かれます。

| パス | 役割 |
|---|---|
| `config.toml` | ユーザー単位の Codex 設定 |
| `auth.json` | ファイル保存方式を使う場合の認証キャッシュ |
| `sessions/` | CLI のローカルセッション履歴 |
| `skills/` | ユーザーが追加した skills |
| `plugins/` | plugin 本体や cache |
| `logs/` など | Codex のログ。`log_dir` を設定している場合はその指定先 |
| `<profile-name>.config.toml` | `--profile <profile-name>` で使う追加設定 |

この中で普段よく触るのは `config.toml` です。たとえば、以下のような設定が入ります。

```toml
model = "gpt-5.5"
approval_policy = "on-request"
sandbox_mode = "workspace-write"
cli_auth_credentials_store = "keyring"

[features]
shell_snapshot = true
```

主な意味は以下です。

- `model`: デフォルトで使うモデル
- `approval_policy`: コマンド実行前にどのタイミングで確認を挟むか
- `sandbox_mode`: Codex がコマンドを実行するときのファイルシステムやネットワークの扱い
- `cli_auth_credentials_store`: CLI の認証情報を `auth.json` に保存するか、OS のキーチェーンに保存するか
- `[features]`: experimental / optional な機能フラグ

ほかにも、MCP サーバーや権限プロファイルなどを `config.toml` に書けます。つまり `config.toml` は「どのモデルで、どの権限で、どんな外部ツールを使って Codex を動かすか」を定義するファイルです。

一方で、API キーやアクセストークンのような認証情報は、`config.toml` に直接書かないほうが安全です。認証情報は `codex login --with-api-key` で保存するか、実行時の環境変数として渡します。`auth.json` を使う設定にしている場合は、`auth.json` もパスワード相当のファイルとして扱います。

API キー用に分けるなら、たとえば `~/.codex-api` を使います。

```bash
mkdir -p "$HOME/.codex-api"
```

この状態で以下のように起動すると、通常の `~/.codex` ではなく `~/.codex-api` 側を使います。

```bash
CODEX_HOME="$HOME/.codex-api" codex
```

この時点では、あくまで保存先を分けただけです。次に API キーでログインします。

## API キーでログインする

まず、API キーを環境変数に設定します。シェル履歴に API キーを残さないため、ここでは `read -s` で入力します。

```bash
read -s OPENAI_API_KEY
export OPENAI_API_KEY
```

すでに環境変数に入っているか確認する場合は、キー本体を表示しないようにします。

```bash
test -n "$OPENAI_API_KEY" && echo "OPENAI_API_KEY is set"
```

次に、API キーを標準入力から `codex login --with-api-key` に渡します。

```bash
printenv OPENAI_API_KEY | CODEX_HOME="$HOME/.codex-api" codex login --with-api-key
```

`codex login --help` では、`--with-api-key` は API キーを標準入力から読むオプションとして表示されます。

```text
--with-api-key
    Read the API key from stdin
```

ログイン状態を確認します。

```bash
CODEX_HOME="$HOME/.codex-api" codex login status
```

## 動作確認する

API キー用ホームを使って、単発実行で確認します。

```bash
CODEX_HOME="$HOME/.codex-api" codex exec "Say hello"
```

ここで ChatGPT workspace 側の credit エラーが出ずに応答が返れば、少なくとも通常の `~/.codex` 側ではなく `~/.codex-api` 側の認証情報で動いています。

一回だけ API キーを渡して `codex exec` を実行したい場合は、現行の Codex ドキュメントでは `CODEX_API_KEY` も案内されています。

この記事では、手元で一時的に保持する変数として `OPENAI_API_KEY` を使い、`codex exec` に直接渡す例では `CODEX_API_KEY` に詰め替えています。

```bash
CODEX_HOME="$HOME/.codex-api" CODEX_API_KEY="$OPENAI_API_KEY" codex exec "Say hello"
```

継続利用するなら `codex login --with-api-key`、一回だけ実行するなら `CODEX_API_KEY=... codex exec` という形で使い分けます。

## codex と打つだけで API キー用ホームを使う

毎回 `CODEX_HOME="$HOME/.codex-api"` と入力するのは手間なので、alias にします。

既存の `codex` alias がある場合は確認します。

```bash
alias codex
```

API キー用ホームを使う alias を追加します。

```bash
echo "alias codex='CODEX_HOME=\$HOME/.codex-api command codex'" >> ~/.zshrc
source ~/.zshrc
```

:::message
この alias は `CODEX_HOME` だけを切り替え、API キー本体は含めません。`~/.zshrc` に API キーを平文で残さないためです。
:::

確認します。

```bash
alias codex
```

期待する表示は以下です。

```bash
codex='CODEX_HOME=$HOME/.codex-api command codex'
```

`command codex` としているのは、alias の中で再び `codex` alias を呼んでしまう再帰を避けるためです。

この設定後は、次のコマンドが API キー用ホームで動きます。

```bash
codex
codex exec "Say hello"
codex resume --all
```

## 通常環境の設定だけ引き継ぐ

`~/.codex` 側で使っていた設定を `~/.codex-api` 側にも引き継ぎたい場合があります。

このとき、認証情報はコピーしないのがポイントです。

コピーしてよい候補は以下です。

- `config.toml`
- `skills`
- `plugins`
- `sessions`

コピーしないものは以下です。

- `auth.json`
- `.credentials.json`
- その他トークンや API キーを含むファイル

まず `config.toml` をコピーします。

```bash
mkdir -p "$HOME/.codex-api"
cp "$HOME/.codex/config.toml" "$HOME/.codex-api/config.toml"
```

コピー後に、認証情報らしき文字列が混ざっていないか確認します。

```bash
grep -nEi 'api[_-]?key|token|secret|credential|authorization|bearer|sk-' "$HOME/.codex-api/config.toml"
```

何か出た場合は、その行を確認して、認証情報なら削除します。

skills や plugins も引き継ぐ場合は、cache を除いてコピーするのが無難です。

```bash
mkdir -p "$HOME/.codex-api/plugins"
rsync -a --exclude 'cache/' "$HOME/.codex/plugins/" "$HOME/.codex-api/plugins/" 2>/dev/null || true
rsync -a "$HOME/.codex/skills/" "$HOME/.codex-api/skills/" 2>/dev/null || true
```

CLI のローカルセッションも引き継ぎたい場合は、`sessions` をコピーします。

```bash
mkdir -p "$HOME/.codex-api/sessions"
rsync -a "$HOME/.codex/sessions/" "$HOME/.codex-api/sessions/" 2>/dev/null || true
```

その後、再開できるセッションを確認します。

```bash
CODEX_HOME="$HOME/.codex-api" codex resume --all
```

ここで扱えるのは、ローカルに保存されている CLI セッションです。Codex app 側の通常チャット履歴まで、`CODEX_HOME` のコピーで移せるとは考えないほうがよいです。

## 環境が切り替わったことを確認する

`codex` と打って起動したら、まず `/status` を実行します。

```text
/status
```

`/status` は、起動中の Codex セッションの状態を確認する slash command です。ここで認証方式や現在の設定状態を見れば、API キー側で動いているか確認できます。

たとえば、API キー側で起動できている場合は、次のように表示されます。

```text
╭────────────────────────────────────────────────────────────────────────────╮
│  >_ OpenAI Codex (v0.135.0)                                                │
│                                                                            │
│  Model:                gpt-5.5 (reasoning xhigh, summaries auto)           │
│  Directory:            ~                                                   │
│  Permissions:          Workspace (on-request)                              │
│  Agents.md:            <none>                                              │
│  Account:              API key configured (run codex login to use ChatGPT) │
│  Collaboration mode:   Default                                             │
│  Session:              019e8407-cd3a-7ad1-bda2-87e124f4ea2c                │
│                                                                            │
│  Token usage:          0 total  (0 input + 0 output)                       │
│  Limits:               data not available yet                              │
╰────────────────────────────────────────────────────────────────────────────╯
```

見るポイントは以下です。

- `Account` が `API key configured` になっているか
- `Model` や `Permissions` が `~/.codex-api/config.toml` 側の設定と一致しているか
- `Directory` が意図した作業ディレクトリになっているか

`CODEX_HOME` のパスそのものまで確認したい場合は、Codex の外側で `codex doctor` を使います。

```bash
CODEX_HOME="$HOME/.codex-api" codex doctor
```

出力の `Environment > state` や `Configuration > config` に `~/.codex-api` が出ていれば、API キー用ホームを参照しています。

```text
CODEX_HOME    ~/.codex-api (dir)
config.toml   ~/.codex-api/config.toml
auth file     ~/.codex-api/auth.json
```

なお、Codex の TUI 起動画面に表示される `directory:` は作業ディレクトリであり、`CODEX_HOME` ではありません。`directory: ~/project` のように表示されていても、`CODEX_HOME` が `~/.codex-api` に向いていれば、設定や認証情報は API キー用ホーム側を参照します。

もし `CODEX_HOME` の指定先ディレクトリが存在しない場合は、起動時にエラーになります。

```text
CODEX_HOME points to "...", but that path does not exist
```

その場合は、先にディレクトリを作成します。

```bash
mkdir -p "$HOME/.codex-api"
```

## まとめ

Codex CLI を API キー用に分けたい場合は、`CODEX_HOME` を分けるのが扱いやすいです。

重要なのは、API キーを alias や設定ファイルへ直書きしないことです。`~/.codex-api` のような専用ホームを作り、ログイン時または実行時だけ API キーを渡すようにすると、通常の ChatGPT ログイン環境と API キー環境を切り分けやすくなります。

設定や skills を引き継ぐ場合も、`auth.json` のような認証情報はコピーしないようにしましょう。

## 参考

https://developers.openai.com/codex/cli

https://developers.openai.com/codex/auth

https://developers.openai.com/codex/environment-variables

https://developers.openai.com/codex/config-basic

https://help.openai.com/ja-jp/articles/5112595-best-practices-for-api-key-safety
