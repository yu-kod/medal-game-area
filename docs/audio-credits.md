# 音源の出典とライセンス

**ダウンロードが必要なものは無い。** 下記はすべて取得済みでリポジトリに入っている。

差し替えたくなったときのために、出典・ライセンス・役割の対応をここに残す。

---

## 出典

| 出典 | 使っている音 | ライセンス | 作者 | 取得日 |
|---|---|---|---|---|
| [OpenGameArt — Coin Drop](https://opengameart.org/content/coin-drop) | メダル 1 枚(打音を切り出し) | CC0 1.0 | Vinrax | 2026-09-17 |
| [OpenGameArt — 12 Coin Sound Effects](https://opengameart.org/content/12-coin-sound-effects) | メダル 数枚 | CC0 1.0 | StarNinjas | 2026-09-17 |
| [Kenney — RPG Audio](https://kenney.nl/assets/rpg-audio) | メダル 大量 | CC0 1.0 | Kenney Vleugels | 2026-09-17 |
| [Kenney — Impact Sounds](https://kenney.nl/assets/impact-sounds) | 払い出しトレイ | CC0 1.0 | Kenney Vleugels | 2026-09-16 |
| [OpenGameArt — 30 CC0 SFX loops](https://opengameart.org/content/30-cc0-sfx-loops) | プッシャー駆動音 | CC0 1.0 | rubberduck | 2026-09-16 |

**すべて CC0(パブリックドメイン)。** 表示義務のある素材は入っていない。
Kenney 分はアーカイブ同梱のライセンス原文を `docs/licenses/` にそのまま置いた。
OpenGameArt 分は同梱が無いので、上記ページの記載と作者名が根拠になる。

パックの全体ではなく**使う音だけ**を取り込んでいる。

StarNinjas はクレジットを「お願い」している(CC0 なので義務ではない)。
クレジット画面を作るときは載せる。

---

## どう鳴らしているか

盤面のメダルの音は、**物理の衝突から直接**鳴らしている(#27)。

- メダルが何かに当たるたびに、**当たった位置**で、**接触点の接近速度に比例した音量**で 1 回鳴らす
- 1 枚の音は 1 つの打音を、**音程を ±8% 揺らして**鳴らす(種を指定した乱数)
- 同じフレームに鳴らしきれない衝突(山が崩れたとき)は、`few/` `many/` の音 1 つにまとめる

仕組みの詳細は `arcade/src/core/medal/medal_strike.gd` と `arcade/src/core/audio/machine_audio.gd`。

---

## 役割の対応

### メダルの音 — `arcade/assets/audio/medal/{single,few,many}/`

**系統はサブディレクトリで決まる。** 差し替えるときはファイルを動かすだけで、コードは触らなくていい。

| 系統 | 置き場所 | 使いどころ | ファイル | 長さ |
|---|---|---|---|---|
| 1 枚 | `medal/single/` | **衝突 1 回ごと** | `coin_drop_hit_1.ogg` | 92 ms |
| | | | `coin_drop_hit_2.ogg` | 68 ms |
| 数枚 | `medal/few/` | 1 フレームに鳴らしきれなかった衝突(2〜5 枚ぶん) | `coin.1..12.ogg` | 0.33〜0.62 s |
| 大量 | `medal/many/` | 同上(6 枚ぶん以上) | `handleCoins.ogg` / `handleCoins2.ogg` | 0.85 s / 0.34 s |

`single/` は**打音 1 回ぶんの長さ(0.15 秒以下)**でなければならない。衝突 1 回ごとに鳴らすので、
余韻や跳ね返りが入っていると 1 回の衝突で何枚ものコインが鳴って聞こえる(テストで見張っている)。

各系統に **2 つ以上**置くこと(同じ音が続かないようにするため。テストで見張っている)。

#### 1 枚の音は切り出して作っている

`single/` の 2 つは、Vinrax の `coin_drop.ogg`(1.42 秒)から打音だけを切り出したもの。
元の録音は「1 枚のコインが **472 ms** に当たり、**567 ms**・**617 ms** に跳ねる」で、
**頭に 0.47 秒の無音**があった。そのまま鳴らすと衝突から約 0.5 秒遅れて聞こえる。

| ファイル | 元の録音の区間 | 処理 |
|---|---|---|
| `coin_drop_hit_1.ogg` | 470〜560 ms(1 打目) | 頭 3 ms フェードイン、末尾 20 ms フェードアウト |
| `coin_drop_hit_2.ogg` | 565〜612 ms(跳ね返りの 2 打目) | 頭 2 ms フェードイン、末尾 15 ms フェードアウト |

```
ffmpeg -i coin_drop.ogg -af "atrim=start=0.470:end=0.560,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.003,afade=t=out:st=0.070:d=0.020" -c:a libvorbis -q:a 6 coin_drop_hit_1.ogg
ffmpeg -i coin_drop.ogg -af "atrim=start=0.565:end=0.612,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.002,afade=t=out:st=0.032:d=0.015" -c:a libvorbis -q:a 6 coin_drop_hit_2.ogg
```

跳ね返りは録音に頼らず、物理が実際に跳ねたときにそれぞれの衝突として鳴る。
元の `coin_drop.ogg` は git の履歴(#24)と上記の出典ページにある。CC0 なので切り出しは自由。

### 払い出しトレイの金属音 — `arcade/assets/audio/tray/`

払い出しのメダルは落下検出に入った瞬間に場から外れ、トレイに物理的にはぶつからない。
なのでトレイの音だけは衝突ではなく、払い出しの枚数で鳴らしている。

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
**コインとして録音された素材に差し替えて削除した**(#23)。

### 2 回目: コインの録音

コインとして録音された素材に差し替えた(#23)。いったんは「良い感じ」だったが、
遊んでもらううちに違和感が出た:

> hjm-coindropがあからさまに複数のコインすぎる。こういうときって、１つの音源で音程を
> 変えたりして表現するんじゃないの?

> 払い出されたメダルが上段のステージにあたるときや、上段のステージが下段のステージに
> あたるとき、メダル同士が当たるときなど音が鳴ってない。

原因は 2 つあった。

- **音を鳴らすきっかけが衝突ではなくイベントだった。** 投入・横穴・払い出しのイベントで
  代わりに鳴らしていたので、それを通らない衝突は構造的に鳴らなかった
- **1 枚用の録音が打音ではなかった。** Malthaner の `hjm-coindrop` は転がる余韻が
  1.2〜1.4 秒続き、Vinrax の `coin_drop` にも跳ね返りと 0.47 秒の無音が入っていた

### 3 回目: 衝突から鳴らす(#27)

衝突そのものから鳴らす仕組みに変え、1 枚の音は `coin_drop.ogg` から打音だけを切り出した。
`hjm-coindrop` は削除し、それに伴って CC-BY の表示義務も無くなった。

---

## 差し替えるときに

### 手元にある差し替え先(ダウンロード不要)

- 1 回の衝突の音が軽すぎる / 金属らしくない → `tray/impactMetal_light_*.ogg` を `single/` にコピーする
  (0.2〜0.5 秒あるので、長すぎると感じたら上の ffmpeg と同じ要領で打音だけ切り出す)
- 山が崩れたときの音が「袋の中」に聞こえる → `tray/impactMetal_medium_*` を `few/` に足す

### それでも合わない場合

[Freesound](https://freesound.org) に実機のメダルプッシャーやコインの録音がある。
ただし**ダウンロードにアカウントが必要**なので、そこは手で取ってもらう必要がある。

- 検索語の例: `coin drop metal`, `token hopper`, `arcade coin pusher`
- **ライセンスを必ず確認すること。** Freesound は CC0 / CC-BY / CC-BY-NC が混在する。
  このリポジトリは公開されているので、**CC0 か CC-BY のみ**にする
- 置き場所は上の表と同じ。1 回の衝突の音なら、打音だけを切り出して `medal/single/` に入れる
- 置いたら `play.cmd -Import` を 1 度通す

---

## ファイルを足すときの決まり

- **元のファイル名を変えない。** どのパックのどの音かを追えなくする
- 切り出しなどで加工したときは、**元の区間と処理をこのファイルに書く**
- メダル音の系統は**置くディレクトリで決める**。ファイル名でごまかさない
- 出典・ライセンス・取得日をこの表に追記する
- CC0 以外を入れるときは、表示義務と表示文言をここに明記する
