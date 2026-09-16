class_name FieldBuilder
extends RefCounted

## 台の静的形状を組み立てる。
##
## 還元率は乱数ではなく、ここで決まる形状だけで決まる(設計書 5章)。
## 下段フィールドの床は側壁より内側に寄せてあり、その差分がサイドの落とし穴になる。

static func build(parent: Node3D) -> void:
	var floor_depth := MachineSpec.FLOOR_Z_FRONT - MachineSpec.FLOOR_Z_BACK
	var floor_center_z := (MachineSpec.FLOOR_Z_FRONT + MachineSpec.FLOOR_Z_BACK) * 0.5
	var wall_height := MachineSpec.WALL_TOP_Y - MachineSpec.WALL_BOTTOM_Y
	var wall_center_y := (MachineSpec.WALL_TOP_Y + MachineSpec.WALL_BOTTOM_Y) * 0.5
	var wall_thickness := 0.2

	# 下段フィールド。上面がちょうど FLOOR_Y に来るように沈める。
	_add_box(
		parent,
		"LowerFloor",
		Vector3(MachineSpec.FLOOR_HALF_WIDTH * 2.0, 0.4, floor_depth),
		Vector3(0.0, MachineSpec.FLOOR_Y - 0.2, floor_center_z),
		Color(0.22, 0.23, 0.26)
	)

	# 側壁。床より外側にあり、その隙間がサイドの落とし穴になる。
	for side in [-1.0, 1.0]:
		_add_box(
			parent,
			"SideWall%s" % ("L" if side < 0.0 else "R"),
			Vector3(wall_thickness, wall_height, floor_depth),
			Vector3(
				side * (MachineSpec.FIELD_HALF_WIDTH + wall_thickness * 0.5),
				wall_center_y,
				floor_center_z
			),
			Color(0.12, 0.13, 0.15)
		)

	# 後壁。デッキより上に跳ねたコインを台内に留める。
	_add_box(
		parent,
		"BackWall",
		Vector3(MachineSpec.FIELD_HALF_WIDTH * 2.0 + wall_thickness * 2.0, 2.0, wall_thickness),
		Vector3(0.0, 1.0, MachineSpec.FLOOR_Z_BACK - wall_thickness * 0.5),
		Color(0.12, 0.13, 0.15)
	)

	# 後方デッキ。プッシャーが前進したとき背後に開く隙間を塞ぐ庇。
	# プッシャー上面と同じ高さから始めることで、コインが下に潜り込む余地をなくす。
	var deck_depth := MachineSpec.DECK_Z_FRONT - MachineSpec.FLOOR_Z_BACK
	_add_box(
		parent,
		"BackDeck",
		Vector3(
			MachineSpec.FIELD_HALF_WIDTH * 2.0,
			MachineSpec.DECK_Y_TOP - MachineSpec.DECK_Y_BOTTOM,
			deck_depth
		),
		Vector3(
			0.0,
			(MachineSpec.DECK_Y_TOP + MachineSpec.DECK_Y_BOTTOM) * 0.5,
			MachineSpec.FLOOR_Z_BACK + deck_depth * 0.5
		),
		Color(0.18, 0.19, 0.22)
	)


static func _add_box(
	parent: Node3D, node_name: String, size: Vector3, center: Vector3, color: Color
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = MachineSpec.LAYER_FIELD
	body.collision_mask = 0

	var box := BoxShape3D.new()
	box.size = size
	var collision := CollisionShape3D.new()
	collision.shape = box
	body.add_child(collision)

	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)

	parent.add_child(body)
	return body
