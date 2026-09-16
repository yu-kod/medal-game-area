# 音源の出典とライセンス

**ダウンロードが必要なものは無い。** 下記はすべて取得済みでリポジトリに入っている。

差し替えたくなったときのために、出典・ライセンス・役割の対応をここに残す。

---

## 出典

| 出典 | ライセンス | 作者 | 取得日 |
|---|---|---|---|
| [Kenney — Casino Audio](https://kenney.nl/assets/casino-audio) | CC0 1.0 | Kenney Vleugels | 2026-09-16 |
| [Kenney — Impact Sounds](https://kenney.nl/assets/impact-sounds) | CC0 1.0 | Kenney Vleugels | 2026-09-16 |
| [OpenGameArt — 30 CC0 SFX loops](https://opengameart.org/content/30-cc0-sfx-loops) | CC0 1.0 | rubberduck | 2026-09-16 |

**すべて CC0(パブリックドメイン)。** 商用・非商用を問わず、表示義務なしで使える。
Kenney 分はアーカイブ同梱のライセンス原文を `docs/licenses/` にそのまま置いた。
OpenGameArt 分は同梱が無いので、上記ページの記載と作者名が根拠になる。

パックの全体ではなく**使う音だけ**を取り込んでいる。
残りはカード・サイコロ・足音・水音で、この台には要らない。

---

## 役割の対応

### メダルの落下音 — `arcade/assets/audio/medal/`

設計書 §11 が要求する「1枚 / 数枚 / 大量 の 3 系統」に対応させる。

| 系統 | ファイル | 枚数の目安 |
|---|---|---|
| 1 枚 | `chips-collide-1..4.ogg` | 1 枚が落ちた / 当たった |
| 数枚 | `chips-stack-1..6.ogg` | 数枚がまとまって動いた |
| 大量 | `chips-handle-1..6.ogg` | 山が崩れた・押し出された |

同系統の中でもランダムに散らす。同じサンプルが続くと即座に嘘だとバレる。

### 払い出しトレイの金属音 — `arcade/assets/audio/tray/`

| 強さ | ファイル |
|---|---|
| 弱 | `impactMetal_light_000..004.ogg` |
| 中 | `impactMetal_medium_000..004.ogg` |
| 強 | `impactMetal_heavy_000..004.ogg` |

### プッシャー盤の駆動音 — `arcade/assets/audio/motor/`

ループ素材。候補を 4 つ入れてある。

| ファイル | 長さ | 備考 |
|---|---|---|
| `machine_11.ogg` | 5.67 s | **既定候補。**いちばん長く、繰り返しが目立ちにくい |
| `machine_08.ogg` | 4.53 s | |
| `machine_06.ogg` | 3.17 s | `PusherSpec.PUSHER_CYCLE_SEC`(3.0 s)に近い。往復に同期させたいならこれ |
| `machine_09.ogg` | 2.70 s | 最も短い |

---

## 正直な注意: 音は聴いて確かめていない

**これらの音が実際にメダルらしく聞こえるかは確認できていない。**
ファイル名・長さ・出典から選んだだけで、再生して判断してはいない。
最終的な採否は耳で決めてほしい。

聴くには `play.cmd -Debug -Demo`。

### 想定される外れ方と差し替え先

いちばんありそうなのは **カジノチップは粘土やプラスチック、メダルは真鍮**という素材の違い。
チップ音が鈍く、金属らしく聞こえない可能性がある。

その場合の差し替え先は**すでにリポジトリに入っている**。

- 1 枚の音が鈍い → `tray/impactMetal_light_*.ogg` を 1 枚の音に回す
- 逆に金属的すぎる → `medal/chips-*.ogg` に戻す

どちらも追加のダウンロードは要らない。

### それでも合わない場合

[Freesound](https://freesound.org) に実機のメダルプッシャーを録音した素材がある。
ただし**ダウンロードにアカウントが必要**なので、そこは手で取ってもらう必要がある。

- 検索語の例: `coin drop metal`, `token hopper`, `arcade coin pusher`
- **ライセンスを必ず確認すること。** Freesound は CC0 / CC-BY / CC-BY-NC が混在する。
  このリポジトリは公開されているので、**CC0 か CC-BY のみ**にする
  (CC-BY を使う場合はこのファイルに表示を追加する)
- 置き場所は上の表と同じ `arcade/assets/audio/{medal,tray,motor}/`
- 置いたら `play.cmd -Import` を 1 度通す

---

## ファイルを足すときの決まり

- **元のファイル名を変えない。** どのパックのどの音かを追えなくする
- 役割への割り当てはコード側で行う。ファイル名でごまかさない
- 出典・ライセンス・取得日をこの表に追記する
- CC0 以外を入れるときは、表示義務の有無をここに明記する
