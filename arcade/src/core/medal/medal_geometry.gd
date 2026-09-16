class_name MedalGeometry
extends RefCounted

## メダル 1 枚ぶんの形状・素材を組み立てる(設計書 4.2)。
##
## プール全体で 1 つずつを共有するので、生成はプール初期化時の一度だけ。


## 16 角柱の凸包。薄い円柱プリミティブは剛体ソルバの最悪ケースなので使わない。
static func build_collision_shape() -> ConvexPolygonShape3D:
	var half_thickness := MedalSpec.COLLISION_THICKNESS * 0.5
	var points := PackedVector3Array()
	for i in MedalSpec.SIDES:
		var angle := TAU * float(i) / float(MedalSpec.SIDES)
		var x := MedalSpec.RADIUS * cos(angle)
		var z := MedalSpec.RADIUS * sin(angle)
		points.push_back(Vector3(x, half_thickness, z))
		points.push_back(Vector3(x, -half_thickness, z))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape


## 描画メッシュは実寸の厚み。水増しはコリジョンだけに効かせる。
static func build_mesh() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = MedalSpec.RADIUS
	mesh.bottom_radius = MedalSpec.RADIUS
	mesh.height = MedalSpec.VISUAL_THICKNESS
	mesh.radial_segments = MedalSpec.SIDES
	mesh.rings = 0
	return mesh


## 真鍮メッキのメダル。金属らしさは反射環境(SceneEnvironment)に依存する。
## 反射源が無い場所でこのマテリアルを使うと真っ黒に潰れる。
static func build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.63, 0.31)
	material.metallic = 0.90
	# 鏡面を抑える。実機のメダルは擦れて曇っており、鏡ではない。
	# ここを magnify すると、盤面いっぱいのメダルが照明を返して白く飛ぶ。
	material.metallic_specular = 0.35
	material.roughness = 0.44
	return material


static func build_physics_material() -> PhysicsMaterial:
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = MedalSpec.FRICTION
	physics_material.bounce = MedalSpec.BOUNCE
	return physics_material
