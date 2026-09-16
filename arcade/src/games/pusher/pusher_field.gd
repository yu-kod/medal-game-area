class_name PusherField
extends RefCounted

## 台の内側 ── メダルが実際に転がる面だけを組み立てる。
##
## 還元率は乱数ではなく、ここで決まる形状だけで決まる(設計書 5 章)。
## 筐体の外装(ガラス・受け皿・マーキー)は PusherShell の担当。
##
## 盤面は 2 段で、真上から見ると手前ほど広い台形。
##   上段  プッシャー盤の上。壁は FIELD_HALF_WIDTH。脇はガードで塞ぐ
##   下段  盤の前。壁は LOWER_HALF_WIDTH まで広がる。ここに横穴が開く
##
## プッシャーゲームの三大障害物はすべてここで作る。
##   うろこねじ  盤面のネジ。メダルを重ならせてうろこ状にする
##   エッジ(坂)  前端の坂。手前へ落としにくくする。切れ目が「スポット」
##   横穴        壁に開けた穴。メダルが減る最大の原因

const FLOOR_THICKNESS := 0.4
const WALL_THICKNESS := 0.2


## simulated が false の席は剛体メダルを持たないので、
## ねじの当たり判定は要らない。席が 6 つある島で全部に置くと無駄が大きい。
static func build(parent: Node3D, simulated := true) -> void:
	_add_floor(parent)
	_add_upper_walls(parent)
	_add_lower_walls(parent)
	_add_out_chutes(parent)
	_add_back_wall(parent)
	_add_deck(parent)
	_add_backboard(parent)
	_add_chucker(parent)
	# 坂とねじは 0 を入れたら実体ごと作らない。撤去した台の挙動をそのまま試せる。
	if PusherSpec.EDGE_HEIGHT > 0.0:
		_add_edge(parent)
	if simulated and PusherSpec.EDGE_SCREW_HEIGHT > 0.0:
		_add_edge_screws(parent)
	if simulated and PusherSpec.SCREW_HEIGHT > 0.0:
		_add_screws(parent)
	if simulated and PusherSpec.OUT_SCREW_HEIGHT > 0.0:
		_add_out_screws(parent)
	_add_front_trim(parent)


## 盤面の床。チェッカーの穴のぶんだけ割って組む。
static func _add_floor(parent: Node3D) -> void:
	var limit := PusherSpec.LOWER_HALF_WIDTH
	var hole_back := PusherSpec.CHUCKER_Z_BACK
	var hole_front := PusherSpec.CHUCKER_Z_FRONT
	var hole_x := PusherSpec.CHUCKER_HALF_WIDTH

	_add_floor_slab(parent, "FloorBack", -limit, limit, PusherSpec.FLOOR_Z_BACK, hole_back)
	_add_floor_slab(parent, "FloorFront", -limit, limit, hole_front, PusherSpec.FLOOR_Z_FRONT)
	_add_floor_slab(parent, "FloorHoleL", -limit, -hole_x, hole_back, hole_front)
	_add_floor_slab(parent, "FloorHoleR", hole_x, limit, hole_back, hole_front)


static func _add_floor_slab(
	parent: Node3D, node_name: String, x_start: float, x_end: float, z_start: float, z_end: float
) -> void:
	var width := x_end - x_start
	var depth := z_end - z_start
	if width <= 0.001 or depth <= 0.001:
		return
	PropBuilder.static_box(
		parent,
		node_name,
		Vector3(width, FLOOR_THICKNESS, depth),
		Vector3(
			x_start + width * 0.5,
			PusherSpec.FLOOR_Y - FLOOR_THICKNESS * 0.5,
			z_start + depth * 0.5
		),
		SurfacePalette.playfield(),
		ContactMaterials.playfield()
	)


## チェッカーの穴とその下のシュート。
##
## 実機と同じで、メダルは穴に入って落ち、シュートの途中のセンサーで数えられる。
## 判定領域を空中に置いたりはしない。入るか入らないかは形状だけで決まる。
static func _add_chucker(parent: Node3D) -> void:
	var length := PusherSpec.CHUCKER_Z_FRONT - PusherSpec.CHUCKER_Z_BACK
	var center_z := (PusherSpec.CHUCKER_Z_BACK + PusherSpec.CHUCKER_Z_FRONT) * 0.5
	var half := PusherSpec.CHUCKER_HALF_WIDTH
	var top := PusherSpec.FLOOR_Y - FLOOR_THICKNESS
	var bottom := PusherSpec.CHUCKER_SINK_Y_BOTTOM
	var wall := 0.06

	# シュートの四方の壁。床の下から、筒としてまっすぐ落とす。
	for side in [-1.0, 1.0]:
		PropBuilder.static_box(
			parent,
			"ChuckerChute%s" % ("L" if side < 0.0 else "R"),
			Vector3(wall, top - bottom, length + wall * 2.0),
			Vector3(side * (half + wall * 0.5), (top + bottom) * 0.5, center_z),
			SurfacePalette.steel(),
			ContactMaterials.steel()
		)
	for edge in [-1.0, 1.0]:
		PropBuilder.static_box(
			parent,
			"ChuckerChute%s" % ("B" if edge < 0.0 else "F"),
			Vector3(half * 2.0, top - bottom, wall),
			Vector3(0.0, (top + bottom) * 0.5, center_z + edge * (length * 0.5 + wall * 0.5)),
			SurfacePalette.steel(),
			ContactMaterials.steel()
		)
	# シュートの底。ここまで落ちたメダルは回収される。
	PropBuilder.static_box(
		parent,
		"ChuckerChuteFloor",
		Vector3(half * 2.0 + wall * 2.0, 0.12, length + wall * 2.0),
		Vector3(0.0, bottom - 0.06, center_z),
		SurfacePalette.steel(),
		ContactMaterials.steel()
	)

	# 奥側の縁の段差。高さ 0 なら建てない。
	# 穴が盤の可動域の中にあるうちは、床より上に出したものは盤の底に当たる。
	if PusherSpec.CHUCKER_LIP_HEIGHT > 0.0:
		PropBuilder.static_box(
			parent,
			"ChuckerLip",
			Vector3(half * 2.0 + wall * 2.0, PusherSpec.CHUCKER_LIP_HEIGHT, 0.05),
			Vector3(
				0.0,
				PusherSpec.FLOOR_Y + PusherSpec.CHUCKER_LIP_HEIGHT * 0.5,
				PusherSpec.CHUCKER_Z_BACK - 0.025
			),
			SurfacePalette.steel(),
			ContactMaterials.steel()
		)

	# 穴のふち。盤面の他の部分と区別が付くよう、縁を光らせる。
	# 床と面一に埋める ── 上に出すと盤の底が乗り上げる。
	for side in [-1.0, 1.0]:
		PropBuilder.decor_box(
			parent,
			"ChuckerRim%s" % ("L" if side < 0.0 else "R"),
			Vector3(0.05, 0.04, length),
			Vector3(side * half, PusherSpec.FLOOR_Y - 0.02, center_z),
			SurfacePalette.accent_glow()
		)


## 上段の側壁。投入レールが貫通する位置に開口を空ける。
##
## 盤の脇を塞ぐガードは無い。盤自体を壁ぎりぎりまで広げてあるので不要で、
## ガードを内側に立てると上段だけ見える幅が狭くなり、下段との境目に段差が出る。
static func _add_upper_walls(parent: Node3D) -> void:
	for side in [-1.0, 1.0]:
		_add_ported_wall(
			parent,
			"UpperWall%s" % ("L" if side < 0.0 else "R"),
			side * (PusherSpec.WALL_X_INNER + WALL_THICKNESS * 0.5),
			WALL_THICKNESS,
			PusherSpec.FLOOR_Z_BACK,
			PusherSpec.PUSHER_Z_FRONT_HOME,
			PusherSpec.WALL_BOTTOM_Y,
			PusherSpec.WALL_TOP_Y,
			SurfacePalette.inner_wall()
		)


## 下段の側壁。ここに横穴(アウトゾーン)を開ける。
## 穴は盤の最前進位置から前端まで。穴の上には詰まり防止の庇を付ける。
static func _add_lower_walls(parent: Node3D) -> void:
	var x_center := PusherSpec.LOWER_HALF_WIDTH + WALL_THICKNESS * 0.5
	var out_top := PusherSpec.FLOOR_Y + PusherSpec.OUT_HEIGHT

	for side in [-1.0, 1.0]:
		var label := "L" if side < 0.0 else "R"
		# 穴より奥は全高の壁。
		_add_slab(
			parent,
			"LowerWall%sBack" % label,
			side * x_center,
			WALL_THICKNESS,
			PusherSpec.PUSHER_Z_FRONT_HOME,
			PusherSpec.OUT_Z_BACK,
			PusherSpec.WALL_BOTTOM_Y,
			PusherSpec.WALL_TOP_Y,
			SurfacePalette.inner_wall()
		)
		# 穴の上のまぐさ。穴は床から OUT_HEIGHT まで開いている。
		_add_slab(
			parent,
			"LowerWall%sLintel" % label,
			side * x_center,
			WALL_THICKNESS,
			PusherSpec.OUT_Z_BACK,
			PusherSpec.OUT_Z_FRONT,
			out_top,
			PusherSpec.WALL_TOP_Y,
			SurfacePalette.inner_wall()
		)
		# 穴より下は床の下。メダルが潜り込まないように塞ぐ。
		_add_slab(
			parent,
			"LowerWall%sSill" % label,
			side * x_center,
			WALL_THICKNESS,
			PusherSpec.OUT_Z_BACK,
			PusherSpec.OUT_Z_FRONT,
			PusherSpec.WALL_BOTTOM_Y,
			PusherSpec.FLOOR_Y - FLOOR_THICKNESS,
			SurfacePalette.inner_wall()
		)
		# 穴より手前は全高の壁。ここが最前部の溜まり場になり、
		# 後ろから押されたメダルが前端を越える。
		_add_slab(
			parent,
			"LowerWall%sFront" % label,
			side * x_center,
			WALL_THICKNESS,
			PusherSpec.OUT_Z_FRONT,
			PusherSpec.FLOOR_Z_FRONT,
			PusherSpec.WALL_BOTTOM_Y,
			PusherSpec.WALL_TOP_Y,
			SurfacePalette.inner_wall()
		)
		# 詰まり防止の庇。穴の上端から盤面側へ張り出す。
		# 無いと穴の口でメダルが立って橋を架け、穴が塞がる。
		PropBuilder.static_box(
			parent,
			"OutHood" + label,
			Vector3(
				PusherSpec.OUT_HOOD_DEPTH,
				PusherSpec.OUT_HOOD_THICKNESS,
				PusherSpec.OUT_Z_FRONT - PusherSpec.OUT_Z_BACK
			),
			Vector3(
				side * (PusherSpec.LOWER_HALF_WIDTH - PusherSpec.OUT_HOOD_DEPTH * 0.5),
				out_top + PusherSpec.OUT_HOOD_THICKNESS * 0.5,
				(PusherSpec.OUT_Z_BACK + PusherSpec.OUT_Z_FRONT) * 0.5
			),
			SurfacePalette.steel(),
			ContactMaterials.steel()
		)


## 横穴の裏の回収路。落ちたメダルはここで店の回収箱行きになる。
## プレイヤーからは壁の陰で見えない。
static func _add_out_chutes(parent: Node3D) -> void:
	var inner := PusherSpec.LOWER_HALF_WIDTH + WALL_THICKNESS
	var outer := inner + PusherSpec.OUT_CHUTE_HALF_WIDTH * 2.0
	var depth := PusherSpec.OUT_Z_FRONT - PusherSpec.OUT_Z_BACK
	var center_z := (PusherSpec.OUT_Z_BACK + PusherSpec.OUT_Z_FRONT) * 0.5

	for side in [-1.0, 1.0]:
		var label := "L" if side < 0.0 else "R"
		# 受け止める底。ここに落ちた時点で検出されるので、深さは要らない。
		PropBuilder.static_box(
			parent,
			"OutChuteFloor" + label,
			Vector3(outer - inner, 0.2, depth),
			Vector3(side * (inner + outer) * 0.5, PusherSpec.OUT_SINK_Y_BOTTOM, center_z),
			SurfacePalette.steel(),
			ContactMaterials.steel()
		)
		# 外側の壁。台の中へ散らばらせない。
		PropBuilder.static_box(
			parent,
			"OutChuteWall" + label,
			Vector3(WALL_THICKNESS, PusherSpec.WALL_TOP_Y - PusherSpec.OUT_SINK_Y_BOTTOM, depth),
			Vector3(
				side * (outer + WALL_THICKNESS * 0.5),
				(PusherSpec.WALL_TOP_Y + PusherSpec.OUT_SINK_Y_BOTTOM) * 0.5,
				center_z
			),
			SurfacePalette.inner_wall()
		)


static func _add_back_wall(parent: Node3D) -> void:
	var height := PusherSpec.WALL_TOP_Y - PusherSpec.WALL_BOTTOM_Y
	PropBuilder.static_box(
		parent,
		"BackWall",
		Vector3(PusherSpec.LOWER_HALF_WIDTH * 2.0 + WALL_THICKNESS * 2.0, height, WALL_THICKNESS),
		Vector3(
			0.0,
			(PusherSpec.WALL_TOP_Y + PusherSpec.WALL_BOTTOM_Y) * 0.5,
			PusherSpec.FLOOR_Z_BACK - WALL_THICKNESS * 0.5
		),
		SurfacePalette.inner_wall()
	)


## 後方デッキ。プッシャーが前進したとき背後に開く隙間を塞ぐ庇。
## 前面が上段の後壁を兼ねる。ここが低いと 2 層目以降が何にも支えられず、
## 山がプッシャーと一緒に往復するだけで前に進まなくなる(Phase 0 実測)。
## 前面の手前 PAYOUT_CHUTE_DEPTH だけは払い出し口のぶんを避けて組む。
## デッキは奥が塞がった箱のままで、そこに前面を貫くダクトが 1 本通っている形。
static func _add_deck(parent: Node3D) -> void:
	var slab := PusherSpec.PAYOUT_CHUTE_DEPTH
	var duct_back := PusherSpec.DECK_Z_FRONT - slab
	var depth := duct_back - PusherSpec.FLOOR_Z_BACK

	PropBuilder.static_box(
		parent,
		"BackDeck",
		Vector3(
			PusherSpec.FIELD_HALF_WIDTH * 2.0,
			PusherSpec.DECK_Y_TOP - PusherSpec.DECK_Y_BOTTOM,
			depth
		),
		Vector3(
			0.0,
			(PusherSpec.DECK_Y_TOP + PusherSpec.DECK_Y_BOTTOM) * 0.5,
			PusherSpec.FLOOR_Z_BACK + depth * 0.5
		),
		SurfacePalette.inner_wall()
	)
	_add_payout_port(parent, duct_back, slab)


## バックボード。上段の後壁から天板までを塞ぐ板。抽選モニターはこの面に付く。
## 天板を上げたぶんここが空くので、塞がないと台の中が奥まで素通しになる。
static func _add_backboard(parent: Node3D) -> void:
	var height := PusherSpec.BACKBOARD_Y_TOP - PusherSpec.BACKBOARD_Y_BOTTOM
	if height <= 0.001:
		return
	PropBuilder.static_box(
		parent,
		"Backboard",
		Vector3(PusherSpec.FIELD_HALF_WIDTH * 2.0, height, WALL_THICKNESS),
		Vector3(
			0.0,
			(PusherSpec.BACKBOARD_Y_BOTTOM + PusherSpec.BACKBOARD_Y_TOP) * 0.5,
			PusherSpec.BACKBOARD_Z - WALL_THICKNESS * 0.5
		),
		SurfacePalette.inner_wall()
	)


## 払い出し口。デッキ前面をダクトが貫いている。
##
## 前面の板を口の左右・上・下の 4 枚に割り、空いた穴に下り勾配の樋を渡す。
## 奥は BackDeck が塞いでいて、その先の循環器は作らない ──
## 見えるのは、口から転がり出てくるところだけ。
static func _add_payout_port(parent: Node3D, duct_back: float, slab: float) -> void:
	var port := PusherSpec.PAYOUT_PORT_HALF_WIDTH
	var edge := PusherSpec.FIELD_HALF_WIDTH
	var center_z := duct_back + slab * 0.5
	var wall := SurfacePalette.inner_wall()

	for side in [-1.0, 1.0]:
		var outer: float = side * edge
		var inner: float = side * port
		PropBuilder.static_box(
			parent,
			"DeckPort%s" % ("L" if side < 0.0 else "R"),
			Vector3(
				absf(outer - inner),
				PusherSpec.DECK_Y_TOP - PusherSpec.DECK_Y_BOTTOM,
				slab
			),
			Vector3(
				(outer + inner) * 0.5,
				(PusherSpec.DECK_Y_TOP + PusherSpec.DECK_Y_BOTTOM) * 0.5,
				center_z
			),
			wall
		)

	# 口の上下。ここがダクトの天井と床下になる。
	var spans := [
		["Top", PusherSpec.PAYOUT_PORT_Y_TOP, PusherSpec.DECK_Y_TOP],
		["Sill", PusherSpec.DECK_Y_BOTTOM, PusherSpec.PAYOUT_PORT_Y_BOTTOM],
	]
	for span in spans:
		var low: float = span[1]
		var high: float = span[2]
		if high - low <= 0.001:
			continue
		PropBuilder.static_box(
			parent,
			"DeckPort%s" % span[0],
			Vector3(port * 2.0, high - low, slab),
			Vector3(0.0, (low + high) * 0.5, center_z),
			wall
		)

	# 樋。奥が高く、口に向かって下る。勾配だけでメダルが出てくる。
	var rise := PusherSpec.PAYOUT_CHUTE_RISE
	var pitch := atan2(rise, slab)
	var length := sqrt(slab * slab + rise * rise)
	PropBuilder.static_ramp(
		parent,
		"PayoutChute",
		Vector3(port * 2.0, PusherSpec.PAYOUT_CHUTE_THICKNESS, length),
		Vector3(0.0, PusherSpec.PAYOUT_PORT_Y_BOTTOM + rise * 0.5, center_z),
		pitch,
		SurfacePalette.steel(),
		ContactMaterials.steel()
	)

	# 口のふち。盤面の他の部分と区別が付くよう、枠を光らせる。
	var frame_y := (PusherSpec.PAYOUT_PORT_Y_BOTTOM + PusherSpec.PAYOUT_PORT_Y_TOP) * 0.5
	for side in [-1.0, 1.0]:
		PropBuilder.decor_box(
			parent,
			"PayoutPortEdge%s" % ("L" if side < 0.0 else "R"),
			Vector3(
				0.04,
				PusherSpec.PAYOUT_PORT_Y_TOP - PusherSpec.PAYOUT_PORT_Y_BOTTOM,
				0.04
			),
			Vector3(side * port, frame_y, PusherSpec.DECK_Z_FRONT + 0.02),
			SurfacePalette.accent_glow()
		)


## エッジ(坂)。前端に設けた、メダルを手前へ落としにくくする最後の障害物。
## 幅方向にいくつかの区間に割り、スポットのところだけ坂を置かない。
## そこがこの台の「落ちる場所」になる。
static func _add_edge(parent: Node3D) -> void:
	var pitch := atan2(PusherSpec.EDGE_HEIGHT, PusherSpec.EDGE_DEPTH)
	var length := sqrt(
		PusherSpec.EDGE_DEPTH * PusherSpec.EDGE_DEPTH
		+ PusherSpec.EDGE_HEIGHT * PusherSpec.EDGE_HEIGHT
	)
	var thickness := 0.12
	var center_z := PusherSpec.FLOOR_Z_FRONT - PusherSpec.EDGE_DEPTH * 0.5
	var center_y := PusherSpec.FLOOR_Y + PusherSpec.EDGE_HEIGHT * 0.5
	# 上面が坂になるよう、法線方向に厚みの半分だけ沈める。
	var normal := Vector3(0.0, cos(pitch), -sin(pitch))

	for span in _edge_spans():
		var width: float = span[1] - span[0]
		if width <= 0.01:
			continue
		var body := PropBuilder.static_box(
			parent,
			"Edge_%d" % int(span[0] * 100.0),
			Vector3(width, thickness, length),
			(
				Vector3((span[0] + span[1]) * 0.5, center_y, center_z)
				- normal * (thickness * 0.5)
			),
			SurfacePalette.playfield(),
			ContactMaterials.playfield()
		)
		# +z へ向かって上る向き。
		body.rotation = Vector3(-pitch, 0.0, 0.0)


## スポットを除いた、坂を置く x の区間を返す。
static func _edge_spans() -> Array:
	var limit := PusherSpec.LOWER_HALF_WIDTH
	var cuts: Array[float] = [-limit]
	var sorted := PusherSpec.EDGE_SPOTS.duplicate()
	sorted.sort()
	for center in sorted:
		cuts.append(center - PusherSpec.EDGE_SPOT_WIDTH * 0.5)
		cuts.append(center + PusherSpec.EDGE_SPOT_WIDTH * 0.5)
	cuts.append(limit)

	var spans := []
	var index := 0
	while index + 1 < cuts.size():
		spans.append([maxf(cuts[index], -limit), minf(cuts[index + 1], limit)])
		index += 2
	return spans


## うろこねじ。盤面の底に出した凹凸で、メダルを重ならせてうろこ状にする。
static func _add_screws(parent: Node3D) -> void:
	var x_limit := PusherSpec.LOWER_HALF_WIDTH - PusherSpec.SCREW_SPACING * 0.5
	var z := PusherSpec.PUSHER_Z_FRONT_HOME + PusherSpec.SCREW_SPACING
	var row := 0
	while z < PusherSpec.FLOOR_Z_FRONT - PusherSpec.EDGE_DEPTH:
		# 一列ごとに半ピッチずらす。格子だとメダルが整列してうろこにならない。
		var x := -x_limit + (PusherSpec.SCREW_SPACING * 0.5 if row % 2 == 1 else 0.0)
		while x <= x_limit:
			_place_screw(
				parent,
				"Screw_%d_%d" % [row, int(x * 100.0)],
				Vector3(x, 0.0, z),
				PusherSpec.SCREW_RADIUS,
				PusherSpec.SCREW_HEIGHT
			)
			x += PusherSpec.SCREW_SPACING
		z += PusherSpec.SCREW_SPACING
		row += 1


## 前端に打つ土手。前端まで来たメダルを絞る最後の関門。
## スポット(EDGE_SPOTS)の位置だけ抜いてある。そこがこの台の落ちる場所になる。
static func _add_edge_screws(parent: Node3D) -> void:
	var z := PusherSpec.FLOOR_Z_FRONT - PusherSpec.EDGE_SCREW_INSET
	var limit := PusherSpec.LOWER_HALF_WIDTH - PusherSpec.EDGE_SCREW_RADIUS
	var x := -limit
	var index := 0
	while x <= limit:
		if not _inside_spot(x):
			_place_screw(
				parent,
				"EdgeScrew_%d" % index,
				Vector3(x, 0.0, z),
				PusherSpec.EDGE_SCREW_RADIUS,
				PusherSpec.EDGE_SCREW_HEIGHT
			)
		x += PusherSpec.EDGE_SCREW_SPACING
		index += 1


## スポット(坂もねじも無い区間)の中か。
static func _inside_spot(x: float) -> bool:
	for center in PusherSpec.EDGE_SPOTS:
		if absf(x - center) <= PusherSpec.EDGE_SPOT_WIDTH * 0.5:
			return true
	return false


## 横穴の口の内側に打つ土手。横へ逃げるメダルを減らす。
## 横穴の長さは実機どおり下段いっぱいで固定なので、落ちる量はここで絞る。
static func _add_out_screws(parent: Node3D) -> void:
	var x := PusherSpec.WALL_X_INNER - PusherSpec.OUT_SCREW_INSET
	for side in [-1.0, 1.0]:
		var label := "L" if side < 0.0 else "R"
		var z := PusherSpec.OUT_Z_BACK + PusherSpec.OUT_SCREW_SPACING * 0.5
		var index := 0
		while z < PusherSpec.OUT_Z_FRONT:
			_place_screw(
				parent,
				"OutScrew%s_%d" % [label, index],
				Vector3(side * x, 0.0, z),
				PusherSpec.OUT_SCREW_RADIUS,
				PusherSpec.OUT_SCREW_HEIGHT
			)
			z += PusherSpec.OUT_SCREW_SPACING
			index += 1


## ねじ 1 本。球を床に沈めて頭だけ出す。
## 角柱にすると縁が立って、絨毯が引っかかって前へ滑らなくなる。球なら滑らかに乗り上げる。
static func _place_screw(
	parent: Node3D, node_name: String, ground: Vector3, radius: float, height: float
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = Vector3(ground.x, PusherSpec.FLOOR_Y + height - radius, ground.z)
	body.collision_layer = PhysicsLayers.FIELD
	body.collision_mask = 0
	body.physics_material_override = ContactMaterials.playfield()

	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = SurfacePalette.steel()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)

	parent.add_child(body)


## 投入レールが貫通する開口を残して壁を組む。
## 1 枚の板ではなく、開口のまわりを 4 つの板で囲う形にする。
static func _add_ported_wall(
	parent: Node3D,
	base_name: String,
	x_center: float,
	x_size: float,
	z_start: float,
	z_end: float,
	y_bottom: float,
	y_top: float,
	material: Material
) -> void:
	var port_z_back := PusherSpec.RAIL_Z - PusherSpec.RAIL_PORT_HALF_DEPTH
	var port_z_front := PusherSpec.RAIL_Z + PusherSpec.RAIL_PORT_HALF_DEPTH
	_add_slab(
		parent, base_name + "Back", x_center, x_size, z_start, port_z_back, y_bottom, y_top, material
	)
	_add_slab(
		parent, base_name + "Front", x_center, x_size, port_z_front, z_end, y_bottom, y_top, material
	)
	_add_slab(
		parent,
		base_name + "Sill",
		x_center,
		x_size,
		port_z_back,
		port_z_front,
		y_bottom,
		PusherSpec.RAIL_PORT_Y_BOTTOM,
		material
	)
	_add_slab(
		parent,
		base_name + "Lintel",
		x_center,
		x_size,
		port_z_back,
		port_z_front,
		PusherSpec.RAIL_PORT_Y_TOP,
		y_top,
		material
	)


## 潰れた板は置かない。開口が壁の端に掛かると寸法が 0 以下になる。
static func _add_slab(
	parent: Node3D,
	node_name: String,
	x_center: float,
	x_size: float,
	z_start: float,
	z_end: float,
	y_bottom: float,
	y_top: float,
	material: Material
) -> void:
	var depth := z_end - z_start
	var height := y_top - y_bottom
	if depth <= 0.001 or height <= 0.001:
		return
	PropBuilder.static_box(
		parent,
		node_name,
		Vector3(x_size, height, depth),
		Vector3(x_center, y_bottom + height * 0.5, z_start + depth * 0.5),
		material
	)


## 前端の見切り。実機と同じく段差ではなく薄い金属の縁。当たり判定は持たせない。
static func _add_front_trim(parent: Node3D) -> void:
	PropBuilder.decor_box(
		parent,
		"FrontEdgeTrim",
		Vector3(PusherSpec.LOWER_HALF_WIDTH * 2.0, 0.03, 0.06),
		Vector3(0.0, PusherSpec.FLOOR_Y + PusherSpec.EDGE_HEIGHT, PusherSpec.FLOOR_Z_FRONT - 0.03),
		SurfacePalette.steel()
	)
