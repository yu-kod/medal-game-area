class_name PusherPlate
extends AnimatableBody3D

## 往復するプッシャー盤。上面が上段フィールドを兼ねる。
##
## 実機のクランク機構に合わせて正弦運動にする。ストローク幅と往復周期は
## 台ごとの還元率を決めるパラメータ(設計書 5 章)なので、乱数は一切挟まない。

## 前進行程が始まったフレームに 1 度だけ発火する。前方のメダルを起こすのに使う。
signal stroke_started(front_z: float)
## 最前進に達したフレーム。機構の駆動音を鳴らす合図。
signal stroke_reversed

var running := true

var _phase := 0.0
var _home_z := 0.0
var _was_advancing := false


static func create() -> PusherPlate:
	var plate := PusherPlate.new()
	plate.name = "PusherPlate"
	plate.sync_to_physics = true
	plate.collision_layer = PhysicsLayers.MECHANISM
	plate.collision_mask = 0
	# 山を前へ運ぶ面。ここが滑ると山がその場で足踏みして前に出ない。
	plate.physics_material_override = ContactMaterials.pusher_plate()

	var size := Vector3(
		PusherSpec.PUSHER_HALF_WIDTH * 2.0, PusherSpec.PUSHER_TOP_Y, PusherSpec.PUSHER_DEPTH
	)
	var center_z := (PusherSpec.PUSHER_Z_REAR_HOME + PusherSpec.PUSHER_Z_FRONT_HOME) * 0.5
	plate.position = Vector3(0.0, PusherSpec.PUSHER_TOP_Y * 0.5, center_z)

	var box := BoxShape3D.new()
	box.size = size
	var collision := CollisionShape3D.new()
	collision.shape = box
	plate.add_child(collision)

	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.name = "Body"
	visual.mesh = mesh
	visual.material_override = SurfacePalette.pusher_plate()
	plate.add_child(visual)

	# 前面だけ別の面として貼る。ここが動いているかどうかが台の生死の指標なので、
	# 縁が見えないと押し出しが起きているのか止まっているのか判別できない。
	var lip := BoxMesh.new()
	lip.size = Vector3(size.x + 0.02, size.y * 0.34, 0.05)
	var lip_visual := MeshInstance3D.new()
	lip_visual.name = "FrontLip"
	lip_visual.mesh = lip
	lip_visual.material_override = SurfacePalette.cabinet_frame()
	lip_visual.position = Vector3(0.0, size.y * 0.28, PusherSpec.PUSHER_DEPTH * 0.5)
	plate.add_child(lip_visual)

	return plate


func _ready() -> void:
	_home_z = position.z


## プッシャー前面の現在位置(グローバル z)。
func front_z() -> float:
	return position.z + PusherSpec.PUSHER_DEPTH * 0.5


## 1 往復のどこにいるか。0.0 が最後退、0.5 が最前進。
func phase() -> float:
	return _phase


func _physics_process(delta: float) -> void:
	if not running:
		return
	_phase = fmod(_phase + delta / PusherSpec.PUSHER_CYCLE_SEC, 1.0)
	var angle := TAU * _phase
	# 位相 0 で最後退、0.5 で最前進。
	var offset := PusherSpec.PUSHER_STROKE * 0.5 * (1.0 - cos(angle))
	position.z = _home_z + offset

	var advancing := sin(angle) > 0.0
	if advancing and not _was_advancing:
		stroke_started.emit(front_z())
	elif not advancing and _was_advancing:
		stroke_reversed.emit()
	_was_advancing = advancing
