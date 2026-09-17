# 音源の出典とライセンス

**ダウンロードが必要なものは無い。** 下記はすべて取得済みでリポジトリに入っている。

差し替えたくなったときのために、出典・ライセンス・役割の対応をここに残す。

---

## 出典

| 出典 | 使っている音 | ライセンス | 作者 | 取得日 |
|---|---|---|---|---|
| [OpenGameArt — Coin Drop](https://opengameart.org/content/coin-drop) | メダル 1 枚 | CC0 1.0 | Vinrax | 2026-09-17 |
| [OpenGameArt — Coin Sounds](https://opengameart.org/content/coin-sounds-0) | メダル 1 枚 | **CC-BY 3.0** | Hansjörg Malthaner | 2026-09-17 |
| [OpenGameArt — 12 Coin Sound Effects](https://opengameart.org/content/12-coin-sound-effects) | メダル 数枚 | CC0 1.0 | StarNinjas | 2026-09-17 |
| [Kenney — RPG Audio](https://kenney.nl/assets/rpg-audio) | メダル 大量 | CC0 1.0 | Kenney Vleugels | 2026-09-17 |
| [Kenney — Impact Sounds](https://kenney.nl/assets/impact-sounds) | 払い出しトレイ | CC0 1.0 | Kenney Vleugels | 2026-09-16 |
| [OpenGameArt — 30 CC0 SFX loops](https://opengameart.org/content/30-cc0-sfx-loops) | プッシャー駆動音 | CC0 1.0 | rubberduck | 2026-09-16 |

Kenney 分はアーカイブ同梱のライセンス原文を `docs/licenses/` にそのまま置いた。
OpenGameArt 分は同梱が無いので、上記ページの記載と作者名が根拠になる。

パックの全体ではなく**使う音だけ**を取り込んでいる。

### 表示(CC-BY 3.0)

次の素材は CC-BY 3.0 で、**表示が義務**。配布物にクレジットを載せるときはこの文言を使う。

> Coin Sounds by **Hansjörg Malthaner** — <http://opengameart.org/users/varkalandar>
> licensed under CC-BY 3.0 (https://creativecommons.org/licenses/by/3.0/)
>
> 使用ファイル: `hjm-coindrop_v1.wav`, `hjm-coindrop_v2.wav`(改変なし)

この素材は CC-BY / CC-BY-SA / GPL などから選べる複数ライセンスで公開されている。
このリポジトリでは **CC-BY 3.0** を選んで使っている。

StarNinjas はクレジットを「お願い」している(CC0 なので義務ではない)。
クレジット画面を作るときは載せる。

---

## 役割の対応

### メダルの落下音 — `arcade/assets/audio/medal/{single,few,many}/`

設計書 §11 が要求する「1枚 / 数枚 / 大量 の 3 系統」に対応させる。
**系統はサブディレクトリで決まる。** 差し替えるときはファイルを動かすだけで、コードは触らなくていい。

| 系統 | 置き場所 | ファイル | 長さ |
|---|---|---|---|
| 1 枚 | `medal/single/` | `coin_drop.ogg` | 1.42 s |
| | | `hjm-coindrop_v1.wav` | 3.50 s |
| | | `hjm-coindrop_v2.wav` | 1.81 s |
| 数枚 | `medal/few/` | `coin.1..12.ogg`(手の中で鳴らしたもの) | 0.33〜0.62 s |
| 大量 | `medal/many/` | `handleCoins.ogg` / `handleCoins2.ogg` | 0.85 s / 0.34 s |

同系統の中でもランダムに散らす。同じサンプルが続くと即座に嘘だとバレる。
「連続させない」を満たすため、**各系統に 2 つ以上**置くこと(テストで見張っている)。

WAV と OGG の両方を読む。**元の形式のまま入れる**(変換すると出自が追えなくなる)。

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
| `machine_11.ogg` | 5.67 s | **既定。**いちばん長く、繰り返しが目立ちにくい |
| `machine_08.ogg` | 4.53 s | |
| `machine_06.ogg` | 3.17 s | `PusherSpec.PUSHER_CYCLE_SEC`(3.0 s)に近い。往復に同期させたいならこれ |
| `machine_09.ogg` | 2.70 s | 最も短い |

---

## 経緯

### 1 回目: カジノチップ(不採用)

最初は [Kenney — Casino Audio](https://kenney.nl/assets/casino-audio) の `chips-*` を
メダル音に使っていた(#20)。聴いてもらった結果:

> chipsはプラスチックに聞こえる

カジノチップは粘土・プラスチックで、メダルは真鍮なので質が根本から違った。
**コインとして録音された素材に差し替えて削除した**(#23)。ファイルは履歴に残っている。

### 2 回目: コインの録音(採用)

コインとして録音された素材に差し替えた(#23)。`play.cmd -Debug -Demo` で聴いてもらった結果:

> 良い感じだと思う

**いまの構成で確定。** 以降の調整は、下の差し替え先の順に試す。

---

## 差し替えるときに

### 手元にある差し替え先(ダウンロード不要)

- 1 枚の音が長すぎる / 転がる余韻が邪魔 → `hjm-coindrop_v1.wav`(3.50 s)を `single/` から外す。
  それでも長ければ `tray/impactMetal_light_*.ogg` を `single/` にコピーする
- 数枚・大量の音が「袋の中」に聞こえる → `tray/impactMetal_medium_*` を `few/` に足す

### それでも合わない場合

[Freesound](https://freesound.org) に実機のメダルプッシャーやコインの録音がある。
ただし**ダウンロードにアカウントが必要**なので、そこは手で取ってもらう必要がある。

- 検索語の例: `coin drop metal`, `token hopper`, `arcade coin pusher`
- **ライセンスを必ず確認すること。** Freesound は CC0 / CC-BY / CC-BY-NC が混在する。
  このリポジトリは公開されているので、**CC0 か CC-BY のみ**にする
- 置き場所は上の表と同じ。メダル音なら `medal/single|few|many/` のどれかに入れるだけ
- 置いたら `play.cmd -Import` を 1 度通す

---

## ファイルを足すときの決まり

- **元のファイル名を変えない。** どのパックのどの音かを追えなくする
- **元の形式のまま入れる。** 変換しない
- メダル音の系統は**置くディレクトリで決める**。ファイル名でごまかさない
- 出典・ライセンス・取得日をこの表に追記する
- CC0 以外を入れるときは、表示義務と表示文言をここに明記する
