class_name Medal
extends RigidBody3D

## プール管理される 1 枚のメダル(設計書 4.5)。
##
## 生成は起動時のみ。使い終わったらツリーから外して物理世界から完全に消す。

## 何かに当たった。音を鳴らすために出す(#27)。
##
## approach_speed は接触点での接近速度、at は当たった位置(ワールド座標)。
## メダル同士の衝突は速いほうだけが出すので、1 回の衝突につき 1 回だけ届く。
signal struck(approach_speed: float, at: Vector3)

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
	# 計数は穴の周辺の Area3D だけで行う。接触監視(body_entered などの signal)は常時オフ。
	medal.contact_monitor = false
	# 音のために、接触の中身だけは _integrate_forces へ届けてもらう(#27)。
	#
	# _integrate_forces で接触が読めるかどうかを決めるのは max_contacts_reported で、
	# contact_monitor ではない。contact_monitor をオンにすると signal 用の管理が
	# 約 1.3 ms 余計にかかるだけで、音には使わない(本物の台で実測)。
	# 遅いメダルは _integrate_forces の冒頭で打ち切るので、静止した山のぶんは計算しない。
	medal.max_contacts_reported = MedalStrike.MAX_CONTACTS_REPORTED
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


## 衝突を探して報告する。物理ステップごとに、起きているメダルだけ呼ばれる。
##
## 静止した山の接触は 30 秒で約 260 万ステップあり、鳴らすべき衝突は数百回しかない。
## 遅いメダルは接触を見ずにすぐ返す(衝突は速い側が報告する)。
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var speed := MedalStrike.body_speed(state.linear_velocity, state.angular_velocity)
	if speed < MedalStrike.GATE_SPEED:
		return

	var strongest := 0.0
	var strongest_index := -1
	for index in state.get_contact_count():
		var approach := MedalStrike.approach_speed(
			state.get_contact_local_velocity_at_position(index),
			state.get_contact_collider_velocity_at_position(index),
			state.get_contact_local_normal(index)
		)
		if approach > strongest:
			strongest = approach
			strongest_index = index
	if strongest_index < 0 or not MedalStrike.is_audible(strongest):
		return

	# 相手もメダルなら、速いほうだけが報告する。同じ衝突を 2 回鳴らさない。
	#
	# 速さは同じ接触から見た両者の接触点の速さで比べる。相手ノードの
	# linear_velocity は同期の順番しだいで 1 ステップ古く、両方が報告してしまう(再現済み)。
	var other := state.get_contact_collider_object(strongest_index)
	if other is RigidBody3D:
		var own_at_contact := state.get_contact_local_velocity_at_position(strongest_index).length()
		var other_at_contact := (
			state.get_contact_collider_velocity_at_position(strongest_index).length()
		)
		if not MedalStrike.reports(
			own_at_contact, other_at_contact, get_instance_id(), other.get_instance_id()
		):
			return

	struck.emit(strongest, state.get_contact_local_position(strongest_index))
