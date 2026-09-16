class_name ArcadeRoom
extends Node3D

## メダルコーナーの箱。台を置く場所そのもの。
##
## Phase 3 で店内移動と複数台を入れる下地。今は 1 台目のプッシャーが立つ島だけ作る。
## 隣に並ぶ台は、いまはシルエットと光だけのダミー。
## 暗い床に光り物が点在する、という関係を先に作っておくと台の見え方が決まる。

## 床。台のフィールド面(y = 0)が床上 950mm に来る高さ。
## 筐体の PusherSpec.CABINET_Y_BOTTOM と一致させること。ずれると台が浮くか埋まる。
const FLOOR_Y := -9.60
## 天井高 3.2m。ゲームセンターの実際の天井はこのくらい。
const CEILING_Y := 22.0
## 幅 6.8m 奥行 8.1m の島。
const HALF_WIDTH := 34.0
const Z_BACK := -55.0
const Z_FRONT := 26.0

## 1 台ぶんの設置間隔。筐体幅 700mm にわずかな隙間を足した値。
## メダルコーナーの台は隙間なく並んでいる。ここに 2 台目以降が並ぶ。
const BAY_PITCH := 7.4

var _rng := RandomNumberGenerator.new()


static func create() -> ArcadeRoom:
	var room := ArcadeRoom.new()
	room.name = "ArcadeRoom"
	return room


## プレイヤーが遊ぶ台を置く位置。index 0 が正面。
## 2 台目以降を実装するときはここに並べる。
static func bay_origin(index: int) -> Vector3:
	return Vector3(BAY_PITCH * index, 0.0, 0.0)


func _ready() -> void:
	_rng.seed = 4423
	_build_shell()
	_build_ceiling_lights()
	_build_neighbours()


func _build_shell() -> void:
	var depth := Z_FRONT - Z_BACK
	var center_z := (Z_FRONT + Z_BACK) * 0.5

	var carpet := StandardMaterial3D.new()
	carpet.albedo_color = Color(0.055, 0.045, 0.075)
	carpet.roughness = 0.92
	PropBuilder.static_box(
		self,
		"Floor",
		Vector3(HALF_WIDTH * 2.0, 0.4, depth),
		Vector3(0.0, FLOOR_Y - 0.2, center_z),
		carpet,
		ContactMaterials.carpet()
	)

	var ceiling := StandardMaterial3D.new()
	ceiling.albedo_color = Color(0.05, 0.05, 0.06)
	ceiling.roughness = 0.85
	PropBuilder.decor_box(
		self,
		"Ceiling",
		Vector3(HALF_WIDTH * 2.0, 0.3, depth),
		Vector3(0.0, CEILING_Y + 0.15, center_z),
		ceiling
	)

	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.045, 0.05, 0.065)
	wall.roughness = 0.9
	for side in [-1.0, 1.0]:
		PropBuilder.decor_box(
			self,
			"Wall%s" % ("L" if side < 0.0 else "R"),
			Vector3(0.3, CEILING_Y - FLOOR_Y, depth),
			Vector3(side * HALF_WIDTH, (CEILING_Y + FLOOR_Y) * 0.5, center_z),
			wall
		)
	PropBuilder.decor_box(
		self,
		"WallBack",
		Vector3(HALF_WIDTH * 2.0, CEILING_Y - FLOOR_Y, 0.3),
		Vector3(0.0, (CEILING_Y + FLOOR_Y) * 0.5, Z_BACK),
		wall
	)


## 天井の蛍光灯。設計書 11 章のとおり色温度を混ぜる。
## 店内そのものは暗いままにして、明るいのは台の中だけという関係を守る。
func _build_ceiling_lights() -> void:
	var tube := StandardMaterial3D.new()
	tube.albedo_color = Color(0.6, 0.65, 0.7)
	tube.emission_enabled = true
	tube.emission = Color(0.72, 0.82, 1.0)
	tube.emission_energy_multiplier = 1.6

	for index in 5:
		var z := Z_BACK + 8.0 + index * 16.0
		PropBuilder.decor_box(
			self, "Tube%d" % index, Vector3(48.0, 0.5, 1.4), Vector3(0.0, CEILING_Y - 0.8, z), tube
		)
		var lamp := OmniLight3D.new()
		lamp.name = "CeilingLamp%d" % index
		lamp.position = Vector3(0.0, CEILING_Y - 2.0, z)
		lamp.light_color = Color(0.70, 0.80, 1.0)
		# 天井は床から 30 単位以上あるので、台に届かせるにはこの強さが要る。
		# 弱いと筐体の外装が真っ黒になって、島の形が読めなくなる。
		lamp.light_energy = 9.0
		lamp.omni_range = 46.0
		lamp.shadow_enabled = false
		add_child(lamp)


## 隣に並ぶ台。中身は無く、暗い箱と発光する看板だけ。
## 空間の広がりと、台が「並んでいる場所」であることを出すための背景。
func _build_neighbours() -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.05, 0.055, 0.075)
	body.roughness = 0.45

	var hues := [
		Color(0.20, 0.62, 1.00),
		Color(1.00, 0.30, 0.55),
		Color(0.45, 1.00, 0.55),
		Color(1.00, 0.72, 0.15),
		Color(0.72, 0.42, 1.00),
		Color(0.20, 0.95, 0.90),
	]

	# プッシャーの島は差し渡し 25 単位ほどあるので、通路を挟んだ両脇に寄せる。
	# 奥の列は通路を挟んで背中合わせ。
	var slots := [
		Vector3(-BAY_PITCH * 2.6, 0.0, 2.0),
		Vector3(-BAY_PITCH * 3.6, 0.0, 2.0),
		Vector3(BAY_PITCH * 2.6, 0.0, 2.0),
		Vector3(BAY_PITCH * 3.6, 0.0, 2.0),
		Vector3(-BAY_PITCH * 0.5, 0.0, -34.0),
		Vector3(BAY_PITCH * 0.5, 0.0, -34.0),
		Vector3(-BAY_PITCH * 1.5, 0.0, -34.0),
		Vector3(BAY_PITCH * 1.5, 0.0, -34.0),
	]

	for index in slots.size():
		var origin: Vector3 = slots[index]
		# 実機のアーケード筐体は全高 1.7〜1.9m、幅 0.7〜0.9m。
		var height := 17.5 + _rng.randf_range(-0.8, 1.8)
		var width := 7.0 + _rng.randf_range(-0.3, 0.6)
		var cabinet := Node3D.new()
		cabinet.name = "NeighbourCabinet%d" % index
		cabinet.position = origin
		cabinet.rotation_degrees = Vector3(0.0, 180.0 if origin.z < -10.0 else 0.0, 0.0)
		add_child(cabinet)

		PropBuilder.decor_box(
			cabinet,
			"Body",
			Vector3(width, height, 9.0),
			Vector3(0.0, FLOOR_Y + height * 0.5, 0.0),
			body
		)

		var glow := StandardMaterial3D.new()
		var hue: Color = hues[index % hues.size()]
		glow.albedo_color = hue * 0.35
		glow.emission_enabled = true
		glow.emission = hue
		glow.emission_energy_multiplier = 2.2
		PropBuilder.decor_box(
			cabinet,
			"Marquee",
			Vector3(width * 0.92, 2.4, 0.2),
			Vector3(0.0, FLOOR_Y + height - 1.6, 4.6),
			glow
		)
		# ガラス面のぼんやりした光。台の中で何かが光っている、という気配だけ出す。
		PropBuilder.decor_box(
			cabinet,
			"Screen",
			Vector3(width * 0.8, 5.0, 0.12),
			Vector3(0.0, FLOOR_Y + height * 0.55, 4.55),
			glow
		)

		var lamp := OmniLight3D.new()
		lamp.name = "MarqueeLamp"
		lamp.position = Vector3(0.0, FLOOR_Y + height - 1.8, 6.0)
		lamp.light_color = hue
		lamp.light_energy = 3.0
		lamp.omni_range = 14.0
		lamp.shadow_enabled = false
		cabinet.add_child(lamp)
