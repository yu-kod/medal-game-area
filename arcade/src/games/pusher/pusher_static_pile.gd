class_name PusherStaticPile
extends MultiMeshInstance3D

## 遊んでいない席に積んである、剛体を持たないメダルの山。
##
## 島には 4〜6 席あるが、全席で物理を回すと 1 席 300 枚 × 6 = 1800 剛体になって破綻する。
## プレイヤーが座っている席だけを実際にシミュレートし、残りは見た目だけの山にする。
## 設計書 4.5 が「奥のコインは事実上動かないのでメッシュだけ残す」と書いているのと同じ発想を、
## 台の単位でやっている。
##
## MultiMesh なので何枚並べてもドローコールは 1。

## 上段(プッシャー盤の上)に積む枚数。
const UPPER_COUNT := 150
## 下段(フィールド)に敷く枚数。
const LOWER_COUNT := 130


static func create(seed_value: int) -> PusherStaticPile:
	var pile := PusherStaticPile.new()
	pile.name = "StaticPile"
	pile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = MedalGeometry.build_mesh()
	multi.instance_count = UPPER_COUNT + LOWER_COUNT
	pile.multimesh = multi
	pile.material_override = MedalGeometry.build_material()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# 上段は投入口の下あたりが高くなる。実機で遊ばれている台の山の形。
	var index := pile._fill(
		rng,
		0,
		UPPER_COUNT,
		PusherSpec.PUSHER_TOP_Y,
		0.34,
		PusherSpec.DECK_Z_FRONT + MedalSpec.RADIUS,
		PusherSpec.PUSHER_Z_FRONT_HOME
	)
	# 下段は薄く敷いてあるだけ。
	pile._fill(
		rng,
		index,
		LOWER_COUNT,
		PusherSpec.FLOOR_Y,
		0.10,
		PusherSpec.PUSHER_Z_FRONT_HOME + MedalSpec.RADIUS,
		PusherSpec.FLOOR_Z_FRONT - MedalSpec.RADIUS
	)
	return pile


func _fill(
	rng: RandomNumberGenerator,
	start: int,
	count: int,
	base_y: float,
	heap: float,
	z_back: float,
	z_front: float
) -> int:
	var x_limit := PusherSpec.LOWER_HALF_WIDTH - MedalSpec.RADIUS
	for i in count:
		var x := rng.randf_range(-x_limit, x_limit)
		var z := rng.randf_range(z_back, z_front)
		# 奥ほど高く積む。前端に近いほど薄い。
		var depth_ratio := inverse_lerp(z_front, z_back, z)
		var y := (
			base_y + MedalSpec.VISUAL_THICKNESS * 0.5 + rng.randf_range(0.0, heap * depth_ratio)
		)
		# ほぼ水平だが、山なので少しだけ傾いて重なる。
		var basis := (
			Basis(Vector3.UP, rng.randf_range(0.0, TAU))
			* Basis(Vector3.RIGHT, rng.randf_range(-0.16, 0.16))
			* Basis(Vector3.BACK, rng.randf_range(-0.16, 0.16))
		)
		multimesh.set_instance_transform(start + i, Transform3D(basis, Vector3(x, y, z)))
	return start + count
