class_name EntryRails
extends Node3D

## 左右の投入ユニット。台の裏の循環器からフィールドへメダルを送り込む。
##
## 日本のプッシャーはメダルを上から落とすのではなく、台の左右から
## 立ったまま転がして入れる。プレイヤーの選択は 2 つだけ。
##   1. 左右どちらの口に入れるか  → 山のどちら側に落ちるか
##   2. プッシャーの往復のどの位相で入れるか → 壁との隙間に入るかどうか
## どちらも乱数を介さず形状と時間だけで決まる(設計書 5 章)。
##
## 機構の筋が通るように、裏から表まで一本のレールが通っている構造にしてある。
##
##   循環器 ── 給送部 ──[壁の貫通部]── 首振り部 ── 出口
##            (壁の裏)                  (フィールド内)
##
## レールは全体が**一直線**。給送部と首振り部で勾配を変えない。
## 折れ曲がりは機構として不自然だし、継ぎ目でメダルが跳ねる。
##
## パーツが分かれているのは首振りのため。首振り部は壁の内面を支点にした
## 子ノードに載せてあるので、`set_head_angle()` で y 回転させれば
## 実機の首振りシュートになる。支点が壁にあるので、振っても貫通部はずれない。

const LEFT := -1
const RIGHT := 1

## 給送部を首振り部側へわずかに伸ばす量。継ぎ目に段差を作らないため。
## 支点のすぐ近くなので、首を振ってもここは動かない。
const JOINT_OVERLAP := 0.02

var _heads := {}


static func create() -> EntryRails:
	var rails := EntryRails.new()
	rails.name = "EntryRails"
	for side in [LEFT, RIGHT]:
		var label := "L" if side < 0 else "R"

		# 壁の裏から貫通部まで。台に固定。
		rails._build_channel(rails, rails._feed_segment(side), "Feed" + label)

		# 壁の内側。首振りの支点に載せる。
		var head := Node3D.new()
		head.name = "Head" + label
		head.position = Vector3(
			side * PusherSpec.RAIL_ENTRY_X, PusherSpec.RAIL_ENTRY_Y, PusherSpec.RAIL_Z
		)
		rails.add_child(head)
		rails._heads[side] = head
		rails._build_channel(head, rails._head_segment(side), "Head" + label)

		rails._build_collar(side, label)
		rails._build_hopper(side, label)
		rails._build_port_frame(side, label)
	return rails


## メダルを置く姿勢(台ローカル)。給送部の外端 ── 側壁の裏側。
## 円盤を立てて、レール面に接するところに置く。
##
## lean は倒れる向きへのわずかな傾き。0 のままだと転がりきったあと直立して止まる。
func spawn_transform(side: int, lean := 0.0) -> Transform3D:
	var segment := _feed_segment(side)
	var origin: Vector3 = (
		segment.start + segment.up * (MedalSpec.RADIUS + 0.004) + segment.travel * MedalSpec.RADIUS
	)
	# メダルの面法線はローカル +Y。x 軸まわりに 90 度回すと法線が z を向き、
	# 円盤の面が xy 平面に立つ。この向きでだけ x 方向へ転がる。
	# 90 度からずらした分がそのまま倒れ込みの傾きになる。
	return Transform3D(Basis(Vector3(1.0, 0.0, 0.0), PI * 0.5 + lean), origin)


## 循環器がレールへ送り出す初速(台ローカル)。
## あとは勾配が仕事をするので、転がり出しのきっかけがあれば足りる。
func spawn_velocity(side: int) -> Vector3:
	return _feed_segment(side).travel * PusherSpec.RAIL_ENTRY_SPEED


## 首振り。0 で正面(まっすぐ内向き)。実機のシュートはここがゆっくり左右に振れる。
## いまは呼んでいないが、構造として振れるようにしてある。
func set_head_angle(side: int, radians: float) -> void:
	var head: Node3D = _heads.get(side)
	if head != null:
		head.rotation.y = radians


## レール面の高さ。全区間がこの一次式に乗る。
static func _rail_y(x: float) -> float:
	return PusherSpec.RAIL_EXIT_Y + (x - PusherSpec.RAIL_EXIT_X) * PusherSpec.RAIL_SLOPE


## 壁の裏の給送部。台ローカル座標。
func _feed_segment(side: int) -> Dictionary:
	var inner := PusherSpec.RAIL_ENTRY_X - JOINT_OVERLAP
	return _segment(
		side,
		Vector3(side * PusherSpec.RAIL_FEED_X, _rail_y(PusherSpec.RAIL_FEED_X), PusherSpec.RAIL_Z),
		Vector3(side * inner, _rail_y(inner), PusherSpec.RAIL_Z)
	)


## 壁の内側の首振り部。支点を原点とするローカル座標で書く。
func _head_segment(side: int) -> Dictionary:
	return _segment(
		side,
		Vector3.ZERO,
		Vector3(
			side * (PusherSpec.RAIL_EXIT_X - PusherSpec.RAIL_ENTRY_X),
			PusherSpec.RAIL_EXIT_Y - PusherSpec.RAIL_ENTRY_Y,
			0.0
		)
	)


## 壁を貫通する部分。襟を張る範囲。台ローカル座標。
func _collar_segment(side: int) -> Dictionary:
	var outer := PusherSpec.RAIL_PORT_X_OUTER + PusherSpec.RAIL_COLLAR_MARGIN
	var inner := PusherSpec.RAIL_PORT_X_INNER - PusherSpec.RAIL_COLLAR_MARGIN
	return _segment(
		side,
		Vector3(side * outer, _rail_y(outer), PusherSpec.RAIL_Z),
		Vector3(side * inner, _rail_y(inner), PusherSpec.RAIL_Z)
	)


## レール 1 区間の寸法。start から finish へ向かって下る前提。
func _segment(side: int, start: Vector3, finish: Vector3) -> Dictionary:
	var span := finish - start
	# 下り角。左右どちらでも正の値になるように x は絶対値で取る。
	var pitch := atan2(-span.y, absf(span.x))
	var tilt := side * pitch
	return {
		"start": start,
		"finish": finish,
		"travel": span.normalized(),
		"length": span.length(),
		"tilt": tilt,
		"up": Vector3(-sin(tilt), cos(tilt), 0.0),
		"mid": (start + finish) * 0.5,
	}


## 溝 1 区間。床と左右の壁と蓋で、筒になっている。
func _build_channel(parent: Node3D, segment: Dictionary, label: String) -> void:
	var up: Vector3 = segment.up
	var mid: Vector3 = segment.mid
	var tilt: float = segment.tilt
	var length: float = segment.length

	var rail_floor := PropBuilder.static_box(
		parent,
		"RailFloor" + label,
		Vector3(length, PusherSpec.RAIL_FLOOR_THICKNESS, PusherSpec.RAIL_CHANNEL_WIDTH),
		mid - up * (PusherSpec.RAIL_FLOOR_THICKNESS * 0.5),
		SurfacePalette.steel(),
		ContactMaterials.steel()
	)
	rail_floor.rotation = Vector3(0.0, 0.0, tilt)

	# 溝の左右の壁。メダルが寝て転がらなくなるのを防ぐ。
	var wall_offset := (PusherSpec.RAIL_CHANNEL_WIDTH + PusherSpec.RAIL_WALL_THICKNESS) * 0.5
	for wall_side in [-1.0, 1.0]:
		var wall := PropBuilder.static_box(
			parent,
			"RailWall%s%s" % [label, "B" if wall_side < 0.0 else "F"],
			Vector3(length, PusherSpec.RAIL_WALL_HEIGHT, PusherSpec.RAIL_WALL_THICKNESS),
			(
				mid
				+ up * (PusherSpec.RAIL_WALL_HEIGHT * 0.5 - 0.03)
				+ Vector3(0.0, 0.0, wall_side * wall_offset)
			),
			SurfacePalette.cabinet_frame(),
			ContactMaterials.steel()
		)
		wall.rotation = Vector3(0.0, 0.0, tilt)

	# 蓋。実機の投入シュートは筒であって溝ではない。
	# 開いたままだと、レール上で跳ねたメダルが溝から飛び出して台の外へ抜ける。
	var cover := PropBuilder.static_box(
		parent,
		"RailCover" + label,
		Vector3(
			length,
			PusherSpec.RAIL_FLOOR_THICKNESS,
			PusherSpec.RAIL_CHANNEL_WIDTH + PusherSpec.RAIL_WALL_THICKNESS * 2.0
		),
		mid + up * PusherSpec.RAIL_WALL_HEIGHT,
		SurfacePalette.cabinet_frame(),
		ContactMaterials.steel()
	)
	cover.rotation = Vector3(0.0, 0.0, tilt)


## 貫通部の襟。傾いた筒と四角い穴のあいだにできる楔形の遊びを塞ぐ。
## 筒と同じ角度で傾けてあるので、穴の内側どこでも隙間が残らない。
## これが無いと、遊びからメダルが台の裏へ落ちて消える。
func _build_collar(side: int, label: String) -> void:
	var segment := _collar_segment(side)
	var up: Vector3 = segment.up
	var mid: Vector3 = segment.mid
	var depth := PusherSpec.RAIL_PORT_HALF_DEPTH * 2.0 + 0.02

	var offsets := {
		"Over": PusherSpec.RAIL_TUBE_ABOVE + PusherSpec.RAIL_COLLAR_THICKNESS * 0.5,
		"Under": -(PusherSpec.RAIL_TUBE_BELOW + PusherSpec.RAIL_COLLAR_THICKNESS * 0.5),
	}
	for key in offsets:
		var slab := PropBuilder.static_box(
			self,
			"PortCollar%s%s" % [label, key],
			Vector3(segment.length, PusherSpec.RAIL_COLLAR_THICKNESS, depth),
			mid + up * offsets[key],
			SurfacePalette.cabinet_frame(),
			ContactMaterials.steel()
		)
		slab.rotation = Vector3(0.0, 0.0, segment.tilt)


## メダル循環器。レールの外端に繋がっている、壁の裏の箱。
## 開口越しにちらりと見えるだけだが、レールがどこから来ているかがこれで分かる。
func _build_hopper(side: int, label: String) -> void:
	var x := PusherSpec.RAIL_FEED_X + 0.45
	PropBuilder.decor_box(
		self,
		"Hopper" + label,
		Vector3(0.9, 1.5, 0.9),
		Vector3(side * x, _rail_y(x) - 0.25, PusherSpec.RAIL_Z),
		SurfacePalette.cabinet_frame()
	)
	# 機械室の作業灯。開口の奥が真っ黒だと壁に穴が開いているように見えない。
	var lamp := OmniLight3D.new()
	lamp.name = "HopperLamp" + label
	lamp.position = Vector3(
		side * (PusherSpec.RAIL_FEED_X - 0.3),
		_rail_y(PusherSpec.RAIL_FEED_X) + 0.25,
		PusherSpec.RAIL_Z
	)
	lamp.light_color = Color(0.9, 0.86, 0.72)
	lamp.light_energy = 1.6
	lamp.omni_range = 2.2
	lamp.shadow_enabled = false
	add_child(lamp)


## 開口のふち。壁を抜いただけだと切り口が板の断面に見えるので、枠を回す。
func _build_port_frame(side: int, label: String) -> void:
	var x := side * PusherSpec.RAIL_PORT_X_INNER
	var y_bottom := PusherSpec.RAIL_PORT_Y_BOTTOM
	var y_top := PusherSpec.RAIL_PORT_Y_TOP
	var half_depth := PusherSpec.RAIL_PORT_HALF_DEPTH

	for edge in [-1.0, 1.0]:
		PropBuilder.decor_box(
			self,
			"PortJamb%s%s" % [label, "B" if edge < 0.0 else "F"],
			Vector3(0.05, y_top - y_bottom + 0.06, 0.04),
			Vector3(x, (y_top + y_bottom) * 0.5, PusherSpec.RAIL_Z + edge * (half_depth + 0.02)),
			SurfacePalette.cabinet_frame()
		)
	# 上端だけ光らせる。暗い台内で左右の口の位置が読めるようにする最小限。
	PropBuilder.decor_box(
		self,
		"PortTrim" + label,
		Vector3(0.05, 0.04, half_depth * 2.0 + 0.08),
		Vector3(x, y_top + 0.03, PusherSpec.RAIL_Z),
		SurfacePalette.accent_glow()
	)
