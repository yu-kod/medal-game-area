class_name PayoutHopper
extends Node3D

## 抽選の当たりぶんを、実物のメダルとして盤面へ出すホッパー。
##
## 当たってもクレジットには足さない。デッキ前面の口から 1 枚ずつ吐き出して
## 上段に積む。そこから先はふつうのメダルと同じ扱いで、押されて前端から
## 落ちて初めてプレイヤーのものになる。実機のホッパーがこの順序で動く。
##
## だから 400 枚当てても、手に入るのは 400 枚ではない。盤面に 400 枚載るだけで、
## そこから何枚取れるかは盤面の形状の仕事になる。
## 抽選の確率(Roulette.TABLE)と盤面の形状が、別々の役割のまま噛み合う。
##
## メダルはプールから借りる。プールが尽きているあいだは吐き出しを止めて待つ。
## 実機のホッパーも、補給が追いつかなければ払い出しが止まる。

## 1 枚出した。音と演出の合図。
signal dispensed
## 溜まっていたぶんを出し切った。
signal drained

var pool: MedalPool

var _queue := 0
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


static func create(seed_value: int) -> PayoutHopper:
	var hopper := PayoutHopper.new()
	hopper.name = "PayoutHopper"
	hopper._rng.seed = seed_value
	return hopper


## 払い出しを予約する。すぐには出ず、1 枚ずつ間を置いて出ていく。
func enqueue(count: int) -> void:
	if count > 0:
		_queue += count


## まだ出していない枚数。実機の「払い出し中」表示にあたる。
func pending() -> int:
	return _queue


func _physics_process(delta: float) -> void:
	if _queue <= 0 or pool == null:
		return
	_timer += delta
	if _timer < PusherSpec.PAYOUT_INTERVAL:
		return
	_timer = 0.0
	if not _dispense_one():
		# プールが尽きている。予約は残したまま次のフレームを待つ。
		return
	_queue -= 1
	dispensed.emit()
	if _queue == 0:
		drained.emit()


## 樋の上へ 1 枚置いて、転がり出すきっかけの初速を与える。
## あとは勾配が運ぶ。押し出す機構は作らない。
func _dispense_one() -> bool:
	var spread := PusherSpec.PAYOUT_PORT_HALF_WIDTH - MedalSpec.RADIUS - 0.02
	var origin := Vector3(
		_rng.randf_range(-spread, spread), _spawn_height(), PusherSpec.PAYOUT_SPAWN_Z
	)
	var yaw := _rng.randf_range(0.0, TAU)
	var xform := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), origin)
	var medal := pool.acquire(xform, Vector3(0.0, 0.0, PusherSpec.PAYOUT_SPAWN_SPEED))
	return medal != null


## 出す位置での樋の面の高さ。樋の勾配から引く。
## ここを直に数値で書くと、勾配を変えたときにメダルが板にめり込む。
func _spawn_height() -> float:
	var from_mouth := PusherSpec.DECK_Z_FRONT - PusherSpec.PAYOUT_SPAWN_Z
	var along := clampf(from_mouth / PusherSpec.PAYOUT_CHUTE_DEPTH, 0.0, 1.0)
	# 板は傾いているので、面までの見かけの厚みは cos で割ったぶん増える。
	var slope := atan2(PusherSpec.PAYOUT_CHUTE_RISE, PusherSpec.PAYOUT_CHUTE_DEPTH)
	var plank := PusherSpec.PAYOUT_CHUTE_THICKNESS * 0.5 / cos(slope)
	return (
		PusherSpec.PAYOUT_PORT_Y_BOTTOM
		+ PusherSpec.PAYOUT_CHUTE_RISE * along
		+ plank
		+ MedalSpec.COLLISION_THICKNESS
	)
