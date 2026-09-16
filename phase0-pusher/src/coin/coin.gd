class_name Coin
extends RigidBody3D

## プール管理される 1 枚のメダル(設計書 4.5)。
##
## 生成は起動時のみ。使い終わったらツリーから外して物理世界から完全に消す。

## 投入直後だけ CCD を有効にし、着地したら落として負荷を下げる(設計書 4.3)。
var _ccd_remaining := 0.0


static func create(
	shape: ConvexPolygonShape3D,
	mesh: Mesh,
	material: Material,
	physics_material: PhysicsMaterial
) -> Coin:
	var coin := Coin.new()
	coin.mass = MachineSpec.COIN_MASS
	coin.physics_material_override = physics_material
	coin.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	coin.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	coin.linear_damp = MachineSpec.COIN_LINEAR_DAMP
	coin.angular_damp = MachineSpec.COIN_ANGULAR_DAMP
	coin.can_sleep = true
	# 計数は穴の周辺の Area3D だけで行う。接触監視は常時オフ。
	coin.contact_monitor = false
	coin.continuous_cd = false
	coin.collision_layer = MachineSpec.LAYER_COIN
	coin.collision_mask = (
		MachineSpec.LAYER_FIELD | MachineSpec.LAYER_COIN | MachineSpec.LAYER_PUSHER
	)
	coin.set_physics_process(false)

	var collision := CollisionShape3D.new()
	collision.shape = shape
	coin.add_child(collision)

	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	# 山になるコインは影を投げない(設計書 4.2)。
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coin.add_child(visual)

	return coin


## シュートから投入する。物理サーバ側の状態も直接書き換えて確実にテレポートさせる。
func launch(origin: Vector3, yaw: float) -> void:
	var xform := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), origin)
	global_transform = xform
	var rid := get_rid()
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, xform)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_SLEEPING, false)
	continuous_cd = true
	_ccd_remaining = MachineSpec.COIN_CCD_DURATION_SEC
	set_physics_process(true)


## プールへ戻す直前の後始末。
func park() -> void:
	continuous_cd = false
	_ccd_remaining = 0.0
	set_physics_process(false)
	var rid := get_rid()
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)


## プッシャーの前進開始時に外から叩き起こされる(設計書 4.4)。
func wake() -> void:
	if sleeping:
		sleeping = false


func _physics_process(delta: float) -> void:
	_ccd_remaining -= delta
	if _ccd_remaining <= 0.0:
		continuous_cd = false
		set_physics_process(false)
