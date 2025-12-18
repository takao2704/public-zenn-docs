---
title: "VSCode + MicroPico で MicroCat.1(MECHATRAX) に接続する"
emoji: "🔌"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["micropython", "raspberrypipico", "vscode","microcat1"]
published: true
---

:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

:::message
本記事は[積みボード/デバイスくずしAdvent Calendar 2025](https://qiita.com/advent-calendar/2025/tsumiboard)の17日目の記事です。
日頃積んだままになっているIoTデバイスに電源とSIMを入れて動かしつつ、今度もう一度動かしたくなったときにすぐ動かせるようにするための手順やノウハウをまとめ超個人的な備忘録です。
:::

## 何の話

2025/12/15に販売開始されたMECHATRAX社のMicroCat.1（プレリリース版）を早速購入し、人柱になっております。

https://mechatrax.com/2025/12/15/microcat1-pre/

ThonnyでMicroPythonを動かすことはできたのですが、どうしてもVSCodeで動かしたくなり試した記録です。
具体的にはMicroCat.1（RP2350 系）の MicroPython 環境を VS Code 拡張 MicroPico から扱う際にscreen等でシリアルポートを占有していないにもかかわらず接続できなかった問題を解決しました。
また、ポートを認識したあとにも若干動作が安定しなかった部分がありその点も合わせて対処する方法をメモしておきます。

## クイックスタート
- microcat.1 を USB 接続
![alt text](/images/mechatrax-microcat1-ide/1766071222960.png)
![alt text](/images/mechatrax-microcat1-ide/1766071069080.png)

- `screen /dev/cu.usbmodem1101 115200` 等で REPL に入れることを確認。
![alt text](/images/mechatrax-microcat1-ide/1766067406509.png)

- VSCodeで新しいウィンドウを開きプロジェクトフォルダを作成して開く。
![alt text](/images/mechatrax-microcat1-ide/1766067583702.png)
![alt text](/images/mechatrax-microcat1-ide/1766067632413.png)

- MicroPico 拡張をインストール。
![alt text](/images/mechatrax-microcat1-ide/1766067654983.png)
![alt text](/images/mechatrax-microcat1-ide/1766067687535.png)

- micropicoのinitializeを実行
cmd + shift + p でコマンドパレットを開き、`MicroPico: Initialize micropico project` を実行。
![alt text](/images/mechatrax-microcat1-ide/1766067757656.png)

- こんな感じのフォルダ構成になる
![alt text](/images/mechatrax-microcat1-ide/1766067845960.png)

- この状態で左下のMicroPicoアイコンをクリックしても接続できない。
(理由は後ほど解説)
![alt text](/images/mechatrax-microcat1-ide/1766067906789.png)

- [patch_micropico.sh](https://github.com/takao2704/public-zenn-docs/blob/main/files/patch_micropico.sh) をダウンロードして実行し、拡張にパッチを当てる。

https://github.com/takao2704/public-zenn-docs/blob/main/files/patch_micropico.sh

```bash
chmod +x patch_micropico.sh
./patch_micropico.sh
```

実行例：
```
takao@TakaonoMacBook-Pro files % ./patch_micropico.sh 
Found extensions:
  /Users/takao/.vscode/extensions/paulober.pico-w-go-4.3.4-darwin-arm64
Patching /Users/takao/.vscode/extensions/paulober.pico-w-go-4.3.4-darwin-arm64/dist/extension.js
Backup will be saved to /Users/takao/.vscode/extensions/paulober.pico-w-go-4.3.4-darwin-arm64/dist/extension.js.bak.20251218233200
Patched successfully.
Done. Backup saved as /Users/takao/.vscode/extensions/paulober.pico-w-go-4.3.4-darwin-arm64/dist/extension.js.bak.20251218233200
```

- ワークスペースをリロードする。
shift + cmd + p でコマンドパレットを開き、`Developer: Reload Window` を実行。
![alt text](/images/mechatrax-microcat1-ide/1766068420655.png)


- 実機に対してREPL接続が可能になる。
![alt text](/images/mechatrax-microcat1-ide/1766068503159.png)

- 当然、左下の表示も変わる。
![alt text](/images/mechatrax-microcat1-ide/1766068541607.png)

- たとえば、

```python
from machine import Pin
pin = Pin("LED", Pin.OUT)
pin.high()
```
と打っていくとLEDが点灯する。
![alt text](/images/mechatrax-microcat1-ide/1766068852427.png)
before
![alt text](/images/mechatrax-microcat1-ide/1766071222960.png)
after
![alt text](/images/mechatrax-microcat1-ide/1766071069080.png)



例えば、
[こちら](https://kousaku-prog.com/vscode-micropython/)のサイトで紹介されている

```python
from machine import Pin
from utime import sleep

pin = Pin("LED", Pin.OUT)

print("LED starts flashing...")
while True:
    try:
        pin.toggle()
        sleep(1) # sleep 1sec
    except KeyboardInterrupt:
        break
pin.off()
print("Finished.")
```

のようなスクリプトを`blink.py`として保存して、ファイルを開いた状態で左下のRunボタンを押すと実行できる。
![alt text](/images/mechatrax-microcat1-ide/1766069921347.png)

- 自動的に実行されるプログラムとしてmicroCat.1に書き込みたい場合
`main.py`としてファイルを保存して、Shift + Cmd + P でコマンドパレットを開き、`MicroPico: Upload file to Pico`を実行する。
![alt text](/images/mechatrax-microcat1-ide/1766070078971.png)

- 書き込み後にリセットされ、自動的に`main.py`が実行される。

## 解説編

### 使った環境

- ボード: MechaTracks MicroCat.1
- ファーム: `mechatrax/micropython` の `mtx` ブランチ
- 拡張: `paulober.pico-w-go-4.3.4`（MicroPico）
- OS: macOS（~/.vscode/extensions 配下にインストール）

### 症状と環境確認

- 症状1:
    `/dev/cu.usbmodem1101` は見えているが、標準 Pico と VID/PID が異なるため MicroPico が接続できない。
    - 対処:
        VID/PID 差分を吸収するパッチを当てる。

- 症状2:
    VID/PID の差分を把握した後も、`getSerialPorts` が連続発火して RangeError が出続ける。
    - 対処：
        指定ポートがあるときは列挙を止めるパッチを当てる。

- 症状3:
    Toggle Mpy FS を有効にすると `stat/readFile` エラーが頻発し、ファイル一覧が取れず実用にならない。
    - 対処：
        諦める（MicroCat.1 では Toggle Mpy FS を使わず、手動接続＋アップロード運用に絞る）。


### 切り分けと観察

#### 1. 物理・ファーム確認
- ケーブルとポートを変えて再接続し、`screen /dev/cu.usbmodem1101 115200` で REPL に入れるかを確認。
- BOOTSEL モードで `picotool info -d` が見えることを確認（基板は応答している）。

#### 2. VID/PID の相違を確認

- `ports/rp2/boards/MTX_MICROCAT1/mpconfigboard.h` に以下の定義あり。
  - `MICROPY_HW_USB_VID (0x388B)`
  - `MICROPY_HW_USB_PID (0xCA71)`
- 標準 Pico（0x2E8A 系）と異なるため、拡張の自動列挙が対象外になっている。

#### 3. MicroPico の挙動を確認

- VID/PID 差分を吸収しても、`getSerialPorts` が 1.5 秒ごとに走り RangeError が連続発生し、接続が確立しない。
- Toggle Mpy FS では `stat/readFile` エラーが多発し、仮想 FS は実質使えない。

### ログサンプル（抜粋）

```text
RangeError: offset is out of bounds              # getSerialPorts 連打時
Error: Failed to read file: stat/readFile error  # Toggle Mpy FS 時
```

### 対処と解決の方針

1. ファームウェア側の VID/PID は変更せず、拡張側で吸収する。
2. 手動指定ポートがあるときはポート列挙と自動接続タイマーを止める。
3. Toggle Mpy FS は不安定なため使わず、手動接続＋アップロード運用に絞る。

### 暫定対処（設定のみ、未解決）

- `micropico.manualComDevice` を指定し `autoConnect` を `false` にしても、列挙タイマーが残り RangeError が止まらないケースがあった。
- VID/PID の差分を把握しただけでは、連続発火する `getSerialPorts` を抑えられず解決に至らない。

### 根本対処（拡張パッチ）

- 手動指定ポートがあるときは `getSerialPorts()` を呼ばず、タイマーも張らずに直接 `openSerialPort()` するよう `setupAutoConnect()` を変更。
- これにより RangeError が止まり、手動接続＋アップロードに絞って安定動作する。

### パッチの概要

- 対象ファイル: `~/.vscode/extensions/paulober.pico-w-go-4.3.4-darwin-arm64/dist/extension.js`
- 変更点:
  - `setupAutoConnect()` 相当の処理を以下の挙動に変更。
    - `micropico.manualComDevice` が設定されている場合は `getSerialPorts()` を呼ばず、指定ポートを直接 `openSerialPort()` して終了。自動接続タイマーも張らない。
    - 手動指定が空かつ `micropico.autoConnect` が `true` の場合のみ、従来通りポート列挙を行う。
  - これによりカスタム VID/PID 環境でも RangeError が発生せず、手動接続で安定する。

### パッチ適用手順

1. MicroPico 拡張がインストール済みであることを確認します。
2. リポジトリルートでパッチスクリプトを実行します。

```bash
cd /Users/takao/Project/MicroPico-1
./scripts/patch_micropico.sh
# 拡張を複数持つ場合はパスを明示
# ./scripts/patch_micropico.sh ~/.vscode/extensions/paulober.pico-w-go-4.3.4-darwin-arm64
```

- 実行すると `dist/extension.js.bak.<timestamp>` が作成され、対象拡張に直接パッチが当たります。拡張を再インストールすると元に戻るため、必要に応じて再適用してください。

### VS Code 設定例（安定運用）

`settings.json` の一例です。手動指定ポートでのみ接続し、自動接続タイマーを使いません。

```json
{
  "micropico.manualComDevice": "/dev/cu.usbmodem1101",
  "micropico.autoConnect": false,
  "micropico.openOnStart": false
}
```

## 検証結果

- パッチ後は手動指定ポートで RangeError が再発せず、接続・アップロードが安定しました。
- アップロード後にリセットすると `main.py` が起動し、LED 点滅などの動作を確認できました。

## 再発防止・アップデート時の注意

- 拡張更新で `extension.js` が上書きされると元に戻るため、更新後は再度 `patch_micropico.sh` を実行する。
- Toggle Mpy FS は未対応（安定しない）として扱い、使用しない運用を前提で。
- 他 OS やバージョンでパスが異なる場合は `patch_micropico.sh` に拡張ディレクトリを明示指定してください。

## まとめ
- とりあえずそこまでストレスなく使えるようにはなりました。
- MicroCat.1 のカスタム VID/PID で MicroPico の自動列挙が失敗する問題は、拡張側で「手動指定ポートがあれば列挙しない」ようにするだけで解消できます。
- `scripts/patch_micropico.sh` で簡単に適用でき、手動接続＋アップロード運用で安定しました。
- 拡張を更新した際はバックアップを確認しつつ再適用してください。
