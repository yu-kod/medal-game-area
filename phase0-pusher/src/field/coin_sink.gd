class_name CoinSink
extends Area3D

## 落ちたコインを検出する領域。
##
## 設計書 4.3 のとおり、コイン側の接触監視は常時オフにしてあり、
## 計数が必要な穴の周辺だけをこの Area3D が見る。

enum Kind {
	PAYOUT,  ## 前端を越えた = 払い出し
	SIDE_LOSS,  ## サイドの落とし穴 = 損
	VOID,  ## どこにも該当せず落ちてきた = 異常
}

signal coin_sunk(coin: Coin, kind: int)

var kind: int = Kind.PAYOUT


static func create(sink_kind: int, size: Vector3, center: Vector3) -> CoinSink:
	var sink := CoinSink.new()
	sink.kind = sink_kind
	sink.name = "Sink_%s" % Kind.keys()[sink_kind]
	sink.position = center
	sink.collision_layer = MachineSpec.LAYER_SINK
	sink.collision_mask = MachineSpec.LAYER_COIN
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
	if body is Coin:
		coin_sunk.emit(body, kind)
