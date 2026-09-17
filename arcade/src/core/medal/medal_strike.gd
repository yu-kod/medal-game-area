class_name MedalStrike
extends RefCounted

## 衝突の強さの測り方。音を鳴らすかどうかと、その音量を決める。
##
## 強さは Jolt の `get_contact_impulse()` ではなく、接触点での**接近速度**で測る。
## Jolt の力積は推定値で、「2 つの物体が他の物体と触れていないときだけ正確」
## (Godot docs: Using Jolt Physics)。山の中のメダルはほぼ常に何かに触れているので使えない。
## 接近速度は推定ではなく、その瞬間の実際の速度から出る。
##
## 速度はすべてゲーム内単位(10 倍スケール)。長さと重力をどちらも 10 倍にしているので
## 速度も 10 倍になる。2.0 は実物の 0.2 m/s、8.0 は 0.8 m/s にあたる。

## これ以上の接近速度で当たったら鳴らす。
##
## 静止しているメダルも、1 ステップぶんの重力加速(98 / 180 ≒ 0.544)が接近速度として
## 毎ステップ見える。これに近いと、山が止まっているだけで鳴り続ける。3 倍以上離してある。
const AUDIBLE_APPROACH := 2.0
## この接近速度で最大音量。実測では投入やホッパーからの落下が 9〜12 で当たる。
const FULL_APPROACH := 8.0
## これより遅いメダルは接触を見ずに打ち切る。
##
## 衝突は速い側のメダルが報告するので、遅い側は見なくてよい。これで接触を読む
## 計算のほとんど(静止している山)を省ける。
## 接近速度は 2 つの速さの和を超えないので、鳴らすしきい値の半分にしておけば
## 「両方とも少し遅い」正面衝突を取りこぼさない。
const GATE_SPEED := AUDIBLE_APPROACH / 2.0
## 1 枚あたりに報告させる接触の数。本物の台で計測した値(#27)。
const MAX_CONTACTS_REPORTED := 4


## 接近速度。自分が相手へ向かって動いていれば正。
##
## Godot の接触法線は相手から自分へ向くので、相対速度と逆向きの成分を取る。
static func approach_speed(
	local_velocity: Vector3, collider_velocity: Vector3, normal: Vector3
) -> float:
	return -(local_velocity - collider_velocity).dot(normal)


## 剛体の速さ。回転しているメダルの縁の速さも含める。
static func body_speed(linear_velocity: Vector3, angular_velocity: Vector3) -> float:
	return maxf(linear_velocity.length(), angular_velocity.length() * MedalSpec.RADIUS)


static func is_audible(approach: float) -> bool:
	return approach >= AUDIBLE_APPROACH


## 音量(dB)。振幅を速さに比例させる。速さが半分なら -6 dB。
static func volume_db(approach: float) -> float:
	var clamped := clampf(approach, AUDIBLE_APPROACH, FULL_APPROACH)
	return linear_to_db(clamped / FULL_APPROACH)


## 自分がこの衝突を報告するか。
##
## メダル同士の衝突は両方の剛体が同じ接触を見る。速いほうだけが報告し、
## 同じ速さならインスタンス ID の小さいほうが報告する。これで 1 回の衝突が 1 回だけ鳴る。
static func reports(own_speed: float, other_speed: float, own_id: int, other_id: int) -> bool:
	if other_speed > own_speed:
		return false
	if other_speed == own_speed and other_id < own_id:
		return false
	return true
