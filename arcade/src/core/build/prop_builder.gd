class_name PropBuilder
extends RefCounted

## 箱を並べて筐体を組むためのヘルパ。
##
## モデルデータを持ち込む前の段階なので、形はすべてコードで積む。
## ここに集約しておけば、後で .glb に差し替えるときの置換点が 1 箇所で済む。


## 衝突する静的な箱。台の床・壁・筐体はすべてこれ。
##
## contact は省略できるが、省略すると Godot 既定の friction = 1.0 が使われ、
## メダルが張り付く。メダルが触れる面には必ず適切なものを渡すこと。
static func static_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	center: Vector3,
	material: Material,
	contact: PhysicsMaterial = null
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = PhysicsLayers.FIELD
	body.collision_mask = 0
	body.physics_material_override = ContactMaterials.plastic() if contact == null else contact

	var box := BoxShape3D.new()
	box.size = size
	var collision := CollisionShape3D.new()
	collision.shape = box
	body.add_child(collision)

	body.add_child(_mesh_instance(size, material))
	parent.add_child(body)
	return body


## 傾いた静的な箱。払い出しシュートの傾斜など。
static func static_ramp(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	center: Vector3,
	pitch_rad: float,
	material: Material,
	contact: PhysicsMaterial = null
) -> StaticBody3D:
	var body := static_box(parent, node_name, size, center, material, contact)
	body.rotation = Vector3(pitch_rad, 0.0, 0.0)
	return body


## 当たり判定を持たない飾り。マーキー・銘板・光る面など。
static func decor_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	center: Vector3,
	material: Material
) -> MeshInstance3D:
	var visual := _mesh_instance(size, material)
	visual.name = node_name
	visual.position = center
	parent.add_child(visual)
	return visual


static func _mesh_instance(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	return visual
