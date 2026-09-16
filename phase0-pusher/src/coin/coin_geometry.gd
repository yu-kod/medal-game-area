class_name CoinGeometry
extends RefCounted

## コイン 1 枚ぶんの形状・素材を組み立てる(設計書 4.2)。
##
## プール全体で 1 つずつを共有するので、生成はプール初期化時の一度だけ。


## 16 角柱の凸包。薄い円柱プリミティブは剛体ソルバの最悪ケースなので使わない。
static func build_collision_shape() -> ConvexPolygonShape3D:
	var half_thickness := MachineSpec.COIN_COLLISION_THICKNESS * 0.5
	var points := PackedVector3Array()
	for i in MachineSpec.COIN_SIDES:
		var angle := TAU * float(i) / float(MachineSpec.COIN_SIDES)
		var x := MachineSpec.COIN_RADIUS * cos(angle)
		var z := MachineSpec.COIN_RADIUS * sin(angle)
		points.push_back(Vector3(x, half_thickness, z))
		points.push_back(Vector3(x, -half_thickness, z))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape


## 描画メッシュは実寸の厚み。水増しはコリジョンだけに効かせる。
static func build_mesh() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = MachineSpec.COIN_RADIUS
	mesh.bottom_radius = MachineSpec.COIN_RADIUS
	mesh.height = MachineSpec.COIN_VISUAL_THICKNESS
	mesh.radial_segments = MachineSpec.COIN_SIDES
	mesh.rings = 0
	return mesh


static func build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.86, 0.74, 0.36)
	# 反射環境(空・リフレクションプローブ)を置いていないので、metallic を上げると
	# 拾う光が無くなって真っ黒に潰れる。金属らしさは roughness と鏡面反射で出す。
	# 店内の照明を組む Phase 3 で反射環境ごと見直す。
	material.metallic = 0.35
	material.roughness = 0.28
	return material


static func build_physics_material() -> PhysicsMaterial:
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = MachineSpec.COIN_FRICTION
	physics_material.bounce = MachineSpec.COIN_BOUNCE
	return physics_material
