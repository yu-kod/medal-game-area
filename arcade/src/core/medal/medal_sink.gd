class_name MedalSink
extends Area3D

## 落ちたメダルを検出する領域。
##
## メダル側の接触監視は常時オフにしてあり(設計書 4.3)、
## 計数が必要な穴の周辺だけをこの Area3D が見る。
##
## 用途の区別は enum ではなく tag で持つ。プッシャーの「払い出し / サイド落下」と
## クレーンの「景品口」では意味が違うので、台ごとに好きな名前を付けられるようにする。

signal medal_sunk(medal: Medal, tag: StringName)

var tag := &"payout"


static func create(sink_tag: StringName, size: Vector3, center: Vector3) -> MedalSink:
	var sink := MedalSink.new()
	sink.tag = sink_tag
	sink.name = "Sink_%s" % sink_tag
	sink.position = center
	sink.collision_layer = PhysicsLayers.SINK
	sink.collision_mask = PhysicsLayers.MEDAL
	sink.monitoring = true
	sink.monitorable = false

	var box := BoxShape3D.new()
	box.size = size
	var collision := CollisionShape3D.new()
	collision.shape = box
	sink.add_child(collision)

	return sink


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Medal:
		medal_sunk.emit(body, tag)
