class_name PusherShell
extends RefCounted

## 筐体の外側 ── 払い出しシュート、受け皿、前面ガラス、外装、マーキー、台内照明。
##
## 設計書 11 章「リアルさの 9 割は音と光」の光の側。
## 情報は現実の筐体にあるものだけ載せる(設計書 1 章)。説明パネルの類は置かない。

const RAMP_THICKNESS := 0.6
const PANEL_THICKNESS := 0.14


## simulated が false の席は誰も遊んでいない席。影の生成を止めて負荷を落とす。
## 島には 4〜6 席あるので、全席で影付きライトを焚くと描画が持たない。
static func build(parent: Node3D, simulated := true) -> void:
	_build_payout_ramp(parent)
	_build_tray(parent)
	_build_glass(parent)
	_build_housing(parent)
	_build_house_lights(parent, simulated)


## 前端からこぼれたメダルを受け皿まで運ぶ傾斜。
## 板ではなく厚い楔にしてある。薄い板だと裏側に隙間ができて、
## そこにメダルが 1 枚挟まったまま永久に残る。
static func _build_payout_ramp(parent: Node3D) -> void:
	var run := PusherSpec.RAMP_Z_FRONT - PusherSpec.RAMP_Z_BACK
	var drop := PusherSpec.RAMP_Y_BACK - PusherSpec.RAMP_Y_FRONT
	var pitch := atan2(drop, run)
	var length := sqrt(run * run + drop * drop)

	# 上面の中点から法線方向に半分沈めた位置が箱の中心。
	var surface_mid := Vector3(
		0.0,
		(PusherSpec.RAMP_Y_BACK + PusherSpec.RAMP_Y_FRONT) * 0.5,
		(PusherSpec.RAMP_Z_BACK + PusherSpec.RAMP_Z_FRONT) * 0.5
	)
	var normal := Vector3(0.0, cos(pitch), sin(pitch))
	PropBuilder.static_ramp(
		parent,
		"PayoutRamp",
		Vector3(PusherSpec.TRAY_HALF_WIDTH * 2.0, RAMP_THICKNESS, length),
		surface_mid - normal * (RAMP_THICKNESS * 0.5),
		pitch,
		SurfacePalette.steel(),
		ContactMaterials.steel()
	)


static func _build_tray(parent: Node3D) -> void:
	var tray_depth := PusherSpec.TRAY_Z_FRONT - PusherSpec.TRAY_Z_BACK
	var tray_center_z := (PusherSpec.TRAY_Z_BACK + PusherSpec.TRAY_Z_FRONT) * 0.5
	var floor_thickness := 0.16

	PropBuilder.static_box(
		parent,
		"TrayFloor",
		Vector3(PusherSpec.TRAY_HALF_WIDTH * 2.0, floor_thickness, tray_depth),
		Vector3(0.0, PusherSpec.TRAY_FLOOR_Y - floor_thickness * 0.5, tray_center_z),
		SurfacePalette.steel(),
		ContactMaterials.steel()
	)

	# 手前の縁。ここが無いとメダルが床にこぼれ続ける。
	PropBuilder.static_box(
		parent,
		"TrayLip",
		Vector3(
			PusherSpec.TRAY_HALF_WIDTH * 2.0 + PusherSpec.TRAY_WALL_THICKNESS * 2.0,
			PusherSpec.TRAY_LIP_HEIGHT,
			PusherSpec.TRAY_WALL_THICKNESS
		),
		Vector3(
			0.0,
			PusherSpec.TRAY_FLOOR_Y + PusherSpec.TRAY_LIP_HEIGHT * 0.5,
			PusherSpec.TRAY_Z_FRONT + PusherSpec.TRAY_WALL_THICKNESS * 0.5
		),
		SurfacePalette.cabinet_frame(),
		ContactMaterials.steel()
	)

	# 払い出し口から受け皿の前縁までを通しで塞ぐ側壁。
	# 後端をフィールド前端より奥まで伸ばしてあり、
	# サイドの落とし穴の前側の栓を兼ねている。
	var wall_z_back := PusherSpec.RAMP_Z_BACK
	var wall_depth := PusherSpec.TRAY_Z_FRONT - wall_z_back
	var wall_y_bottom := PusherSpec.TRAY_FLOOR_Y - 0.2
	var wall_y_top := PusherSpec.GLASS_Y_BOTTOM
	for side in [-1.0, 1.0]:
		PropBuilder.static_box(
			parent,
			"PayoutWall%s" % ("L" if side < 0.0 else "R"),
			Vector3(PusherSpec.TRAY_WALL_THICKNESS, wall_y_top - wall_y_bottom, wall_depth),
			Vector3(
				side * (PusherSpec.TRAY_HALF_WIDTH + PusherSpec.TRAY_WALL_THICKNESS * 0.5),
				(wall_y_top + wall_y_bottom) * 0.5,
				wall_z_back + wall_depth * 0.5
			),
			SurfacePalette.cabinet_frame(),
			ContactMaterials.steel()
		)


## 前面ガラス。フィールドとプレイヤーのあいだ。
## メダルが台の外へ飛び出すのを止める実体でもあるので、当たり判定を持たせる。
static func _build_glass(parent: Node3D) -> void:
	PropBuilder.static_box(
		parent,
		"FrontGlass",
		Vector3(
			PusherSpec.LOWER_HALF_WIDTH * 2.0 + 0.4,
			PusherSpec.GLASS_Y_TOP - PusherSpec.GLASS_Y_BOTTOM,
			PusherSpec.GLASS_THICKNESS
		),
		Vector3(
			0.0, (PusherSpec.GLASS_Y_TOP + PusherSpec.GLASS_Y_BOTTOM) * 0.5, PusherSpec.GLASS_Z
		),
		SurfacePalette.glass(),
		ContactMaterials.glass()
	)


static func _build_housing(parent: Node3D) -> void:
	var depth := PusherSpec.CABINET_Z_FRONT - PusherSpec.CABINET_Z_BACK
	var center_z := (PusherSpec.CABINET_Z_BACK + PusherSpec.CABINET_Z_FRONT) * 0.5
	# 席の外装は天板までで止める。その上の看板は島の中央塔が持つ。
	# クレジット表示はモニターの中へ移したので、天板の上の帯はもう無い。
	var top_y := PusherSpec.GLASS_Y_TOP
	var height := top_y - PusherSpec.CABINET_Y_BOTTOM
	var center_y := (top_y + PusherSpec.CABINET_Y_BOTTOM) * 0.5

	# 左右の外装。フィールドの側壁より外側にあり、視界の額縁になる。
	for side in [-1.0, 1.0]:
		PropBuilder.static_box(
			parent,
			"CabinetSide%s" % ("L" if side < 0.0 else "R"),
			Vector3(PANEL_THICKNESS, height, depth),
			Vector3(
				side * (PusherSpec.CABINET_HALF_WIDTH + PANEL_THICKNESS * 0.5), center_y, center_z
			),
			SurfacePalette.cabinet_body()
		)

	# 背面と底。台の中を素通しで見せないための塞ぎ。
	PropBuilder.static_box(
		parent,
		"CabinetBack",
		Vector3(PusherSpec.CABINET_HALF_WIDTH * 2.0, height, PANEL_THICKNESS),
		Vector3(0.0, center_y, PusherSpec.CABINET_Z_BACK - PANEL_THICKNESS * 0.5),
		SurfacePalette.cabinet_body()
	)
	PropBuilder.static_box(
		parent,
		"CabinetFloor",
		Vector3(PusherSpec.CABINET_HALF_WIDTH * 2.0, PANEL_THICKNESS, depth),
		Vector3(0.0, PusherSpec.CABINET_Y_BOTTOM - PANEL_THICKNESS * 0.5, center_z),
		SurfacePalette.cabinet_body()
	)

	# 受け皿より下の前面。ここから下は機械室で、外からは開かない。
	var apron_top := PusherSpec.TRAY_FLOOR_Y - 0.2
	PropBuilder.static_box(
		parent,
		"CabinetApron",
		Vector3(
			PusherSpec.CABINET_HALF_WIDTH * 2.0,
			apron_top - PusherSpec.CABINET_Y_BOTTOM,
			PANEL_THICKNESS
		),
		Vector3(
			0.0,
			(apron_top + PusherSpec.CABINET_Y_BOTTOM) * 0.5,
			PusherSpec.CABINET_Z_FRONT - PANEL_THICKNESS * 0.5
		),
		SurfacePalette.cabinet_body()
	)

	# 天板。ガラスの上端の高さでフィールドに蓋をする。台内照明はこの裏に付く。
	PropBuilder.static_box(
		parent,
		"Canopy",
		Vector3(
			PusherSpec.CABINET_HALF_WIDTH * 2.0,
			PANEL_THICKNESS,
			PusherSpec.GLASS_Z - PusherSpec.CABINET_Z_BACK
		),
		Vector3(
			0.0,
			PusherSpec.GLASS_Y_TOP + PANEL_THICKNESS * 0.5,
			(PusherSpec.GLASS_Z + PusherSpec.CABINET_Z_BACK) * 0.5
		),
		SurfacePalette.cabinet_body()
	)

	# ガラスの左右を埋める前面パネル。フィールド幅(400mm)より筐体(700mm)が広いので、
	# ここを塞がないと台の中が横から素通しになる。
	var glass_edge := PusherSpec.LOWER_HALF_WIDTH + 0.2
	var front_width := PusherSpec.CABINET_HALF_WIDTH - glass_edge
	for side in [-1.0, 1.0]:
		PropBuilder.static_box(
			parent,
			"FrontPanel%s" % ("L" if side < 0.0 else "R"),
			Vector3(
				front_width, PusherSpec.GLASS_Y_TOP - PusherSpec.GLASS_Y_BOTTOM, PANEL_THICKNESS
			),
			Vector3(
				side * (glass_edge + front_width * 0.5),
				(PusherSpec.GLASS_Y_TOP + PusherSpec.GLASS_Y_BOTTOM) * 0.5,
				PusherSpec.GLASS_Z
			),
			SurfacePalette.cabinet_body()
		)

	# 払い出し口の左右。受け皿の幅より外側は塞ぐ。
	var mouth_edge := PusherSpec.TRAY_HALF_WIDTH + PusherSpec.TRAY_WALL_THICKNESS
	var mouth_width := PusherSpec.CABINET_HALF_WIDTH - mouth_edge
	for side in [-1.0, 1.0]:
		PropBuilder.static_box(
			parent,
			"MouthPanel%s" % ("L" if side < 0.0 else "R"),
			Vector3(
				mouth_width,
				PusherSpec.GLASS_Y_BOTTOM - apron_top,
				PusherSpec.CABINET_Z_FRONT - PusherSpec.GLASS_Z
			),
			Vector3(
				side * (mouth_edge + mouth_width * 0.5),
				(PusherSpec.GLASS_Y_BOTTOM + apron_top) * 0.5,
				(PusherSpec.CABINET_Z_FRONT + PusherSpec.GLASS_Z) * 0.5
			),
			SurfacePalette.cabinet_body()
		)

	# ガラスを囲む金属フレーム。左右の縦框だけで枠に見える。
	for side in [-1.0, 1.0]:
		PropBuilder.decor_box(
			parent,
			"GlassStile%s" % ("L" if side < 0.0 else "R"),
			Vector3(0.16, PusherSpec.GLASS_Y_TOP - PusherSpec.GLASS_Y_BOTTOM, 0.16),
			Vector3(
				side * (PusherSpec.LOWER_HALF_WIDTH + 0.12),
				(PusherSpec.GLASS_Y_TOP + PusherSpec.GLASS_Y_BOTTOM) * 0.5,
				PusherSpec.GLASS_Z
			),
			SurfacePalette.cabinet_frame()
		)

	# 台の縁を走る青いラインライト。暗い店内で台の輪郭を出す。
	for side in [-1.0, 1.0]:
		PropBuilder.decor_box(
			parent,
			"EdgeLight%s" % ("L" if side < 0.0 else "R"),
			Vector3(0.05, 0.05, depth * 0.86),
			Vector3(side * PusherSpec.CABINET_HALF_WIDTH, PusherSpec.GLASS_Y_TOP - 0.06, center_z),
			SurfacePalette.accent_glow()
		)


## 台に内蔵された照明。店内は暗い前提なので、フィールドの明るさはここで決まる。
static func _build_house_lights(parent: Node3D, simulated: bool) -> void:
	# 天板の裏に仕込んだ蛍光灯。盤面が奥行き 625mm あるので 1 灯では届かない。
	# 下段の前寄り / 下段の奥 / 上段 の 3 灯で通しに照らす。
	# 天板がフィールドから 450mm 上がっているぶん、距離の二乗で暗くなる。
	# 光源の高さを変えたら必ず強さを見直すこと。
	#
	# 影を落とすのは中央の 1 灯だけ。山の立体感はそれで足りるし、
	# 席が 6 つある島で影付きを増やすと描画が持たない。
	var lower_center := (PusherSpec.FLOOR_Z_FRONT + PusherSpec.PUSHER_Z_FRONT_HOME) * 0.5
	var upper_center := (PusherSpec.PUSHER_Z_FRONT_HOME + PusherSpec.DECK_Z_FRONT) * 0.5
	# 強さは控えめに。盤面(albedo 0.5)に 3 灯が重なるので、1 灯ずつを明るくすると
	# 重なった中央だけが白く飛ぶ。全体が均一に見える強さで止める。
	var lamps := [
		# z 位置, 色, 強さ, 影を落とすか
		[lower_center + 1.40, Color(0.86, 0.91, 1.0), 1.5, false],
		[lower_center - 1.40, Color(0.86, 0.91, 1.0), 1.6, simulated],
		# 奥は電球色を混ぜる。1 色だけだと山が平らに見える(設計書 11 章)。
		[upper_center, Color(1.0, 0.84, 0.62), 1.8, false],
	]
	for index in lamps.size():
		var entry: Array = lamps[index]
		var lamp := SpotLight3D.new()
		lamp.name = "CanopyLamp%d" % index
		lamp.position = Vector3(0.0, PusherSpec.HOUSE_LAMP_Y, entry[0])
		lamp.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		lamp.light_color = entry[1]
		lamp.light_energy = entry[2]
		lamp.spot_range = 14.0
		lamp.spot_angle = 74.0
		# 減衰の指数。小さいほど中心と縁の差が減る。大きいと山の中央だけ白く飛ぶ。
		lamp.spot_angle_attenuation = 0.25
		lamp.shadow_enabled = entry[3]
		lamp.shadow_bias = 0.02
		parent.add_child(lamp)

	# バックボードを洗う光。天板を上げたぶんここが広く空いたので、
	# 当てないと画面の周りが真っ黒な穴になって、モニターだけが宙に浮く。
	# 灯具は天板の裏、ガラス寄りに吊って奥へ向ける。実機の内照と同じ位置。
	var wash := SpotLight3D.new()
	wash.name = "BackboardWash"
	wash.position = Vector3(0.0, PusherSpec.GLASS_Y_TOP - 0.30, PusherSpec.BACKBOARD_Z + 2.20)
	wash.rotation_degrees = Vector3(-32.0, 180.0, 0.0)
	wash.light_color = Color(0.72, 0.80, 1.0)
	wash.light_energy = 1.6
	wash.spot_range = 9.0
	wash.spot_angle = 66.0
	wash.spot_angle_attenuation = 0.5
	wash.shadow_enabled = false
	parent.add_child(wash)

	# 受け皿の照明。溜まったメダルが見えないと払い出しの手応えが消える。
	var tray_lamp := SpotLight3D.new()
	tray_lamp.name = "TrayLamp"
	tray_lamp.position = Vector3(
		0.0, PusherSpec.GLASS_Y_BOTTOM - 0.02, PusherSpec.TRAY_Z_BACK + 0.35
	)
	tray_lamp.rotation_degrees = Vector3(-84.0, 0.0, 0.0)
	tray_lamp.light_color = Color(1.0, 0.90, 0.74)
	# ステンレスの傾斜に強い光を当てると鏡面が飽和して白い塊になる。弱く広く。
	tray_lamp.light_energy = 0.7
	tray_lamp.spot_range = 6.0
	tray_lamp.spot_angle = 72.0
	tray_lamp.spot_angle_attenuation = 0.4
	tray_lamp.shadow_enabled = false
	parent.add_child(tray_lamp)
