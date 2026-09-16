class_name MachineSpec
extends RefCounted

## 台の寸法と物理定数。設計書 4.1 / 4.2 に対応。
##
## 全長は実寸の 10 倍スケール。Jolt が動的物体 0.1〜10m を前提に調整されているため、
## 実寸 25mm のメダルではソルバの精度が出ない。重力は 9.8 m/s^2 のまま変えない。

## 実寸 1mm あたりのゲーム内単位(m)。10 倍スケールなので 0.01。
const MM := 0.01

# --- コイン(設計書 4.2) ---

const COIN_DIAMETER_MM := 25.0
const COIN_THICKNESS_MM := 1.6
## コリジョンだけ厚みを水増しする倍率。見た目のメッシュは実寸のまま。
const COIN_COLLISION_THICKNESS_FACTOR := 1.5
## 円柱プリミティブは使わず 16 角柱の凸包にする。
const COIN_SIDES := 16

const COIN_RADIUS := COIN_DIAMETER_MM * MM * 0.5
const COIN_VISUAL_THICKNESS := COIN_THICKNESS_MM * MM
const COIN_COLLISION_THICKNESS := COIN_VISUAL_THICKNESS * COIN_COLLISION_THICKNESS_FACTOR

const COIN_MASS := 0.05
## 金属同士。跳ねすぎるとおもちゃっぽくなる。
const COIN_FRICTION := 0.25
const COIN_BOUNCE := 0.05
## 山の収束を早めるための軽い減衰。
const COIN_LINEAR_DAMP := 0.15
const COIN_ANGULAR_DAMP := 0.40
## 投入直後の高速落下のあいだだけ CCD を有効にする秒数。
const COIN_CCD_DURATION_SEC := 0.6

# --- フィールド ---

## 側壁の内面。設計書のフィールド幅 400mm に対応。
const FIELD_HALF_WIDTH := 2.0
## 下段フィールドの床。側壁より内側に寄せた差分がサイドの落とし穴になる。
## 隙間はコイン直径より必ず広くする。狭いとコインが橋を架けて落ちない。
## 逆に広すぎると前へ進む前に全部横へ逃げるので、直径の 1.2 倍程度に収める。
const FLOOR_HALF_WIDTH := 1.70
const SIDE_GAP := FIELD_HALF_WIDTH - FLOOR_HALF_WIDTH
const FLOOR_Y := 0.0
const FLOOR_Z_BACK := -2.9
## 前端。ここを越えたコインが払い出しになる。
## プッシャー前面からの距離が還元率を直接左右する(設計書 5章)。
const FLOOR_Z_FRONT := 1.60
const WALL_TOP_Y := 1.6
const WALL_BOTTOM_Y := -2.2

# --- プッシャー ---

## 床より広くしてある。プッシャーの縁から落ちたコインが必ずサイドの穴に入るようにする。
const PUSHER_HALF_WIDTH := 1.75
const PUSHER_TOP_Y := 0.50
const PUSHER_Z_REAR_HOME := -2.60
const PUSHER_Z_FRONT_HOME := -0.10
const PUSHER_DEPTH := PUSHER_Z_FRONT_HOME - PUSHER_Z_REAR_HOME
const PUSHER_STROKE := 0.30
const PUSHER_CYCLE_SEC := 2.0
## 前進開始フレームに強制的に起こす、プッシャー前方の範囲(設計書 4.4)。
const WAKE_DEPTH := 1.0

# --- 後方デッキ ---
# プッシャーが前進したとき背後に開く隙間を塞ぐ庇。実機と同じくプッシャー上面に被せる。
# 前面は上段の後壁を兼ねるので壁の高さまで立ち上げる。ここが低いと 2 層目以降が
# 何にも支えられず、山がプッシャーと一緒に往復するだけで前に進まなくなる。

const DECK_Y_BOTTOM := PUSHER_TOP_Y
const DECK_Y_TOP := WALL_TOP_Y
const DECK_Z_FRONT := -2.20

# --- 投入シュート ---

const CHUTE_Y := 1.10
## 上段の最後方、後壁のすぐ手前に落とす。ここが押し出しの動力源。
## プッシャーが前進すると壁との間に隙間が開き、そこへ落ちたメダルが「つっかえ」になって
## 後退時に山が元の位置まで戻れなくなる。その差分だけ山が前へせり出し、前端からこぼれる。
## 中央に落とすと山の上に積み上がるだけで、この機構がまったく働かない。
const CHUTE_Z := DECK_Z_FRONT + 0.15
const CHUTE_HALF_SPREAD := 1.20

# --- シンク(回収領域) ---

const SINK_Y_TOP := -0.10
const SINK_Y_BOTTOM := -2.00
## どのシンクにも入らずに落ちてきたコインを拾う最終防壁。ここに来たら異常。
const VOID_Y_TOP := -2.60
const VOID_Y_BOTTOM := -3.40

# --- 検証用の境界(ここを出たら「吹き飛んだ」と判定する) ---

const BOUNDS_HALF_X := 3.5
const BOUNDS_Y_MIN := -4.0
const BOUNDS_Y_MAX := 4.0
const BOUNDS_Z_MIN := -4.5
const BOUNDS_Z_MAX := 4.5

# --- 衝突レイヤ ---

const LAYER_FIELD := 1
const LAYER_COIN := 2
const LAYER_PUSHER := 4
const LAYER_SINK := 8

# --- プール(設計書 4.5) ---

## 設計書の想定は 300 枚だが、Phase 0 の実測ではこの寸法の台は 300 枚では成立しない。
## 上下 2 段を 1 層で埋めるだけで約 280 枚必要で、そこから積み増さないと山が前端に届かない。
## 定常運転では 350〜430 枚で推移する。処理時間には十分な余裕がある(実測 avg 0.94ms / 予算 8.33ms)。
const POOL_SIZE := 700
## 設計書 3章の合格基準。実際の場の枚数はこれを上回る。
const TARGET_ACTIVE := 200
