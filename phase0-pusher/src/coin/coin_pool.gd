class_name CoinPool
extends Node3D

## コインのオブジェクトプール(設計書 4.5)。
##
## コインは動的生成しない。起動時に最大数を生成しておき、使い回す。
## 待機中のコインはシーンツリーから外して保持するため、物理世界のコストはゼロになる。

## ツリーに入る前に上書きできる。台に必要な枚数は Phase 0 で実測して決める。
var pool_size := MachineSpec.POOL_SIZE

var _idle: Array[Coin] = []
var _active: Array[Coin] = []


func _ready() -> void:
	var shape := CoinGeometry.build_collision_shape()
	var mesh := CoinGeometry.build_mesh()
	var material := CoinGeometry.build_material()
	var physics_material := CoinGeometry.build_physics_material()
	for i in pool_size:
		var coin := Coin.create(shape, mesh, material, physics_material)
		coin.name = "Coin%03d" % i
		_idle.append(coin)


func _exit_tree() -> void:
	# ツリー外で保持している待機中のコインは自動では解放されない。
	for coin in _idle:
		coin.free()
	_idle.clear()


## 待機中の 1 枚を取り出して投入する。在庫が尽きていたら null。
func acquire(origin: Vector3, yaw: float) -> Coin:
	if _idle.is_empty():
		return null
	var coin: Coin = _idle.pop_back()
	add_child(coin)
	coin.launch(origin, yaw)
	_active.append(coin)
	return coin


## 落ちたコインをプールへ返す。物理コールバックの最中に呼んではいけない。
func release(coin: Coin) -> bool:
	var index := _active.find(coin)
	if index == -1:
		return false
	_active.remove_at(index)
	coin.park()
	remove_child(coin)
	_idle.append(coin)
	return true


func active_coins() -> Array[Coin]:
	return _active


func active_count() -> int:
	return _active.size()


func idle_count() -> int:
	return _idle.size()


## プール収支の検算用。取りこぼしがあればここが POOL_SIZE からずれる。
func total_count() -> int:
	return _active.size() + _idle.size()
