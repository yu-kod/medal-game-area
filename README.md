# medal-game-area

[![CI](https://github.com/yu-kod/medal-game-area/actions/workflows/ci.yml/badge.svg)](https://github.com/yu-kod/medal-game-area/actions/workflows/ci.yml)

メダルゲームコーナーのシミュレーター。Godot 4.7.1 / GDScript。

実機のプッシャー台を、見た目ではなく**物理で**成立させることを目標にしている。
払い出しは確率ではなく盤面の形状だけで決まる。

## 必要なもの

| | |
|---|---|
| Godot | 4.7.1 (standard 版) |
| Python | 3.12 以上(gdtoolkit 用) |

```
pip install "gdtoolkit==4.*"
```

Godot の場所は `scripts/check.ps1` と `arcade/run.ps1` の既定値を使う。
別の場所に置いている場合は環境変数 `GODOT` で指定する。

## 遊ぶ

```
play.cmd                   手で遊ぶ
play.cmd -Debug            左上に検証用の計器を出す
play.cmd -Debug -Demo      自動投入を回して放置観察する
play.cmd -Import           class_name を追加したあとに 1 度通す
```

クローン直後は `.godot/` が無くグローバルクラスが未登録なので、
**まず `play.cmd -Import` を 1 度通す。** これを飛ばすと
"Identifier not declared" で落ちる。

## 検査する

```
check.cmd                  format / lint / import / test を全部
check.cmd -Only test       テストだけ
check.cmd -Fix             gdformat をかけてから全部
```

CI とまったく同じコマンドを回している。PR を出す前にこれを通す。

## 構成

```
arcade/              本体
  src/               実装
  tests/             gdUnit4 のテスト(src と同じ階層)
  addons/gdUnit4/    テストフレームワーク(外部のコード)
phase0-pusher/       物理の検証台。凍結済み
docs/                設計書
scripts/             CI と共通の検査スクリプト
```

### phase0-pusher について

「プッシャーの押し出しが物理的に成立するか」を実測で確かめた検証台。
**結果ごと凍結してある。** `arcade` の物理設定はここで合格した値をそのまま
持ち込んだもの。触ると Phase 0 の検証結果が無効になる。

実測で判明した成立条件は 4 つ。

1. 上段後方は壁の高さまでの固定壁。庇にすると 2 層目が支えを失う
2. 投入は上段の最後方、壁のすぐ手前。中央に落とすと山に積むだけ
3. 投入そのものが動力源。「満ちたら止める」設計にすると台も止まる
4. 横穴は盤の可動域より手前だけ。可動域の脇に開けると延々とこぼれる

## テストの方針

物理そのもの(積み上がり、崩れ、押し出し)は単体テストで固定しない。
ソルバの結果であって、目と計器で確かめる領域にある。

テストで守るのはその手前の決定的な部分に限る。

- 寸法どうしの関係と設定値の整合
- 状態遷移と境界
- 抽選表の健全性と、種を固定したときの再現性

なかでも `test_gravity_matches_the_scale` は、
**10 倍スケールと重力 98 の対応**という、このリポジトリで最も壊れやすい前提を
`ProjectSettings` から直接見張っている。長さだけ変えて重力を据え置くと、
世界が実物の 1/3 の速さになる。

GDScript に使えるカバレッジ計測が無いため、カバレッジの閾値は設けていない。

## 開発の進め方

`CLAUDE.md` と `.claude/skills/coding-standards.md` を参照。
TDD(Red → Green → Refactor)、トランクベース開発、Conventional Commits。
