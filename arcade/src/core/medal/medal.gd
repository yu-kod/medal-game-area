class_name Medal
extends RigidBody3D

## プール管理される 1 枚のメダル(設計書 4.5)。
##
## 生成は起動時のみ。使い終わったらツリーから外して物理世界から完全に消す。

## 投入直後だけ CCD を有効にし、着地したら落として負荷を下げる(設計書 4.3)。
var _ccd_remaining := 0.0


static func create(
	shape: ConvexPolygonShape3D, mesh: Mesh, material: Material, physics_material: PhysicsMaterial
) -> Medal:
	var medal := Medal.new()
	medal.mass = MedalSpec.MASS
	medal.physics_material_override = physics_material
	medal.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	medal.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	medal.linear_damp = MedalSpec.LINEAR_DAMP
	medal.angular_damp = MedalSpec.ANGULAR_DAMP
	medal.can_sleep = true
	# 計数は穴の周辺の Area3D だけで行う。接触監視は常時オフ。
	medal.contact_monitor = false
	medal.continuous_cd = false
	medal.collision_layer = PhysicsLayers.MEDAL
	medal.collision_mask = PhysicsLayers.MEDAL_MASK
	medal.set_physics_process(false)

	var collision := CollisionShape3D.new()
	collision.shape = shape
	medal.add_child(collision)

	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	# 山になるメダルは影を投げない(設計書 4.2)。
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	medal.add_child(visual)

	return medal


## 場に出す。物理サーバ側の状態も直接書き換えて確実にテレポートさせる。
##
## 受け取るのは**ワールド座標**の姿勢と速度。台ローカルからの変換は MedalPool の仕事。
## ここにローカル座標を渡すと、台が原点以外に置かれた瞬間に全部あらぬ場所へ飛ぶ。
func launch(xform: Transform3D, velocity := Vector3.ZERO) -> void:
	global_transform = xform
	var rid := get_rid()
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, xform)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, velocity)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_SLEEPING, false)
	continuous_cd = true
	_ccd_remaining = MedalSpec.CCD_DURATION_SEC
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
