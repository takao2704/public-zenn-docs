---
title: "ソラカメごとに異なるメールアドレスに対してソラカメの通知を送信する"
emoji: "😸"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: []
published: false
---
:::message
「[一般消費者が事業者の表示であることを判別することが困難である表示](https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/assets/representation_cms216_230328_03.pdf)」の運用基準に基づく開示: この記事は記載の日付時点で[株式会社ソラコム](https://soracom.jp/)に所属する社員が執筆しました。ただし、個人としての投稿であり、株式会社ソラコムとしての正式な発言や見解ではありません。
:::

## やりたいこと
ソラカメごとに異なるメールアドレスに対してソラカメの通知を送信するようにします。

## 背景
ソラカメには


```mermaid
graph TD
    subgraph イベント発生元
        A["SORACOMアカウント - オペレーター"]
        B["ソラカメカメラ群"]
    end

    subgraph イベントタイプ
        A --> C["アカウントイベント"]
        B --> D["カメラ状態イベント"]
        B --> E["カメラ検出イベント"]
    end

    subgraph ソラコムサービス
        F["ソラコムクラウドカメラサービス"]
        C --> F
        D --> F
        E --> F
    end

    subgraph 通知設定
        G["アカウントイベント通知設定"]
        H["カメラ状態イベント通知設定"]
        I["カメラ検出イベント通知設定"]
    end

    F -->|設定参照| G
    F -->|設定参照| H
    F -->|設定参照| I

    subgraph 通知判定プロセス
        F --> J["通知要否判定"]
        J -->|設定無効 または 条件不一致| K["通知せず"]
        J -->|設定有効 かつ 条件一致| L["通知情報準備"]
    end

    subgraph 条件チェック
        J --> G1["通知タイプ有効か"]
        G1 -->|YES| J1["通知先設定が有効か"]
        J1 -->|YES| J2["通知メッセージが設定されているか"]
        J2 -->|YES カメライベントのみ| J3["通知対象カメラか"]
        J3 -->|YES 検出イベントのみ| J4["レート制限の範囲内か"]
        J4 -->|YES| L
        J1 -->|NO| K
        J2 -->|NO| K
        J3 -->|NO| K
        J4 -->|NO| K
    end

    L --> M["通知送信"]

    subgraph 通知先
        M --> N["Eメール"]
        M --> O["Webhook 1"]
        M --> P["Webhook 2"]
    end
```

    %% スタイル設定
    classDef orange fill:#f9f,stroke:#333,stroke-width:2px;
    classDef green fill:#9f9,stroke:#333,stroke-width:2px;
    classDef red fill:#f99,stroke:#333,stroke-width:2px;

    class G,H,I orange
    class J orange
    class L green
    class K red

    %% 注釈

    note right of G
      デバイス追加 削除 共有
      レート制限なし
    end

    note right of H
      デバイスオンライン オフライン
      クラウド常時録画停止
      レート制限なし
      最大15分遅延あり
    end

    note right of I
      モーション検知 サウンド検出
      レート制限あり
    end

    note left of M
      通知先は設定画面ごとに1セット
      メールは最大3件 Webhookは最大2件
    end

    note left of J3
      カメラ状態と検出イベントのみ対象
      通知対象カメラの選択が必要
    end

    note left of J4
      カメラ検出イベントのみ
      時間あたりの通知可能数に制限あり
    end

    note left of N
      ルートユーザーで設定
      件名と本文は必須
    end

    note left of O
      URL メソッド ボディは必須
      ヘッダー設定は可能 JSON形式に対応
    end

    note left of P
      Webhook 1と同様
    end

    note right of P
      Public beta機能
      カメラ通知は有料
    end
```


