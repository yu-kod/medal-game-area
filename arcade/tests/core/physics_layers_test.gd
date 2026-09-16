extends GdUnitTestSuite

## 物理レイヤの割り当て。
##
## レイヤ番号の取り違えは静かに壊れる。当たり判定が消えてもエラーは出ず、
## 「メダルがすり抜ける」「落下が検出されない」という遠い症状でしか現れない。
## ビット単位で見張る。

## 名前つきで回すための一覧。定数が増えたらここにも足す。
const LAYERS := {
	"FIELD": PhysicsLayers.FIELD,
	"MEDAL": PhysicsLayers.MEDAL,
	"MECHANISM": PhysicsLayers.MECHANISM,
	"SINK": PhysicsLayers.SINK,
}

# --- レイヤのビット ---


func test_every_layer_uses_a_single_bit() -> void:
	for name in LAYERS:
		var bits: int = LAYERS[name]
		assert_int(bits).override_failure_message("%s が 0。1 << n で割り当てること" % name).is_greater(0)
		# 1 << n はビットが 1 本だけ立つ。x & (x - 1) == 0 で確かめる。
		(
			assert_int(bits & (bits - 1))
			. override_failure_message("%s = %d が単一ビットではない" % [name, bits])
			. is_equal(0)
		)


func test_no_two_layers_share_a_bit() -> void:
	# コピペで同じシフト量が並ぶと、別のレイヤが同じものとして扱われる。
	var names := LAYERS.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var left: int = LAYERS[names[i]]
			var right: int = LAYERS[names[j]]
			(
				assert_int(left & right)
				. override_failure_message("%s と %s が同じビットを使っている" % [names[i], names[j]])
				. is_equal(0)
			)


func test_layers_fit_in_the_engine_limit() -> void:
	# Godot の物理レイヤは 32 本まで。
	for name in LAYERS:
		(
			assert_int(LAYERS[name])
			. override_failure_message("%s が 32 レイヤの範囲を超えている" % name)
			. is_less_equal(1 << 31)
		)


# --- メダルが衝突する相手 ---


func test_medal_mask_covers_the_solid_world() -> void:
	for name in ["FIELD", "MEDAL", "MECHANISM"]:
		(
			assert_int(PhysicsLayers.MEDAL_MASK & LAYERS[name])
			. override_failure_message("MEDAL_MASK に %s が入っていない。メダルがすり抜ける" % name)
			. is_not_equal(0)
		)


func test_medal_mask_excludes_the_sink() -> void:
	# physics_layers.gd のコメントが明示している:
	#   「Area3D(SINK)は衝突ではなく検出側から見るので含めない」
	#
	# ここに SINK が混ざると、落下検出用の Area3D がメダルを弾く側になり、
	# メダルが穴の上で止まる。症状から原因にたどり着きにくい。
	(
		assert_int(PhysicsLayers.MEDAL_MASK & PhysicsLayers.SINK)
		. override_failure_message("MEDAL_MASK に SINK が入っている。落下検出の Area3D がメダルを弾いて穴の上で止まる")
		. is_equal(0)
	)


func test_medal_mask_is_exactly_the_three_solid_layers() -> void:
	# 上 2 つの合わせ技。将来レイヤが増えたときに、
	# 黙って MEDAL_MASK に混ざるのを防ぐ。
	assert_int(PhysicsLayers.MEDAL_MASK).is_equal(
		PhysicsLayers.FIELD | PhysicsLayers.MEDAL | PhysicsLayers.MECHANISM
	)
