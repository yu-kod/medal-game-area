class_name MedalPool
extends Node3D

## メダルのオブジェクトプール(設計書 4.5)。
##
## メダルは動的生成しない。起動時に最大数を生成しておき、使い回す。
## 待機中のメダルはシーンツリーから外して保持するため、物理世界のコストはゼロになる。

## ツリーに入る前に上書きできる。台に必要な枚数は台ごとに違う。
var pool_size := 700

var _idle: Array[Medal] = []
var _active: Array[Medal] = []


func _ready() -> void:
	var shape := MedalGeometry.build_collision_shape()
	var mesh := MedalGeometry.build_mesh()
	var material := MedalGeometry.build_material()
	var physics_material := MedalGeometry.build_physics_material()
	for i in pool_size:
		var medal := Medal.create(shape, mesh, material, physics_material)
		medal.name = "Medal%04d" % i
		_idle.append(medal)


func _exit_tree() -> void:
	# ツリー外で保持している待機中のメダルは自動では解放されない。
	for medal in _idle:
		medal.free()
	_idle.clear()


## 待機中の 1 枚を取り出して場に出す。在庫が尽きていたら null。
##
## 引数は**台ローカル座標**。プールが自分のワールド変換と合成してから渡す。
## 台を複数ステーションで並べたり回転させたりしても、呼ぶ側は台の図面の座標だけ見ればよい。
func acquire(local_xform: Transform3D, local_velocity := Vector3.ZERO) -> Medal:
	if _idle.is_empty():
		return null
	var medal: Medal = _idle.pop_back()
	add_child(medal)
	medal.launch(global_transform * local_xform, global_transform.basis * local_velocity)
	_active.append(medal)
	return medal


## 平置きで 1 枚出す。場の敷き詰めに使う。
func acquire_flat(local_origin: Vector3, yaw: float) -> Medal:
	return acquire(Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), local_origin))


## 落ちたメダルをプールへ返す。物理コールバックの最中に呼んではいけない。
func release(medal: Medal) -> bool:
	var index := _active.find(medal)
	if index == -1:
		return false
	_active.remove_at(index)
	medal.park()
	remove_child(medal)
	_idle.append(medal)
	return true


func active_medals() -> Array[Medal]:
	return _active


func active_count() -> int:
	return _active.size()


func idle_count() -> int:
	return _idle.size()


## プール収支の検算用。取りこぼしがあればここが pool_size からずれる。
func total_count() -> int:
	return _active.size() + _idle.size()
