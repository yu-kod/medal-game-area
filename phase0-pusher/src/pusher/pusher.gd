class_name Pusher
extends AnimatableBody3D

## 往復するプッシャー。上面が上段フィールドを兼ねる。
##
## 実機のクランク機構に合わせて正弦運動にする。ストローク幅と往復周期は
## 台ごとの還元率を決めるパラメータ(設計書 5章)なので、乱数は一切挟まない。

## 前進行程が始まったフレームに 1 度だけ発火する。前方のコインを起こすのに使う。
signal stroke_started(front_z: float)

var running := true

var _phase := 0.0
var _home_z := 0.0
var _was_advancing := false


static func create() -> Pusher:
	var pusher := Pusher.new()
	pusher.name = "Pusher"
	pusher.sync_to_physics = true
	pusher.collision_layer = MachineSpec.LAYER_PUSHER
	pusher.collision_mask = 0

	var size := Vector3(
		MachineSpec.PUSHER_HALF_WIDTH * 2.0,
		MachineSpec.PUSHER_TOP_Y,
		MachineSpec.PUSHER_DEPTH
	)
	var center_z := (MachineSpec.PUSHER_Z_REAR_HOME + MachineSpec.PUSHER_Z_FRONT_HOME) * 0.5
	pusher.position = Vector3(0.0, MachineSpec.PUSHER_TOP_Y * 0.5, center_z)

	var box := BoxShape3D.new()
	box.size = size
	var collision := CollisionShape3D.new()
	collision.shape = box
	pusher.add_child(collision)

	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.17, 0.20)
	material.roughness = 0.7
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	pusher.add_child(visual)

	return pusher


func _ready() -> void:
	_home_z = position.z


## プッシャー前面の現在位置(グローバル z)。
func front_z() -> float:
	return position.z + MachineSpec.PUSHER_DEPTH * 0.5


func _physics_process(delta: float) -> void:
	if not running:
		return
	_phase = fmod(_phase + delta / MachineSpec.PUSHER_CYCLE_SEC, 1.0)
	var angle := TAU * _phase
	# 位相 0 で最後退、0.5 で最前進。
	var offset := MachineSpec.PUSHER_STROKE * 0.5 * (1.0 - cos(angle))
	position.z = _home_z + offset

	var advancing := sin(angle) > 0.0
	if advancing and not _was_advancing:
		stroke_started.emit(front_z())
	_was_advancing = advancing
