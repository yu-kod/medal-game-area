extends GdUnitTestSuite

## 盤面形状の不変条件。
##
## pusher_spec.gd の「フィールド」節は phase0-pusher で 5 分間の耐久試験に
## 合格した組み合わせで、押し出し機構が成立する条件そのもの。
## 壊れたことが分かるのは数分後の挙動なので、その場では気づけない。
##
## ここで見るのは値そのものではなく**値どうしの関係**。実測値は調整してよい。
## 導出されている定数の等式は書かない(定義を定義自身と比べても何も守れない)。
## 不等式と、MedalSpec との横断関係だけを書く。

# --- 段の並び ---


func test_stages_run_from_back_to_front_without_crossing() -> void:
	# 奥から手前へ: 上段の後壁 → 上段前端 → 盤の最前進位置 → 下段前端。
	# 順序が入れ替わると段が裏返り、メダルの行き場が消える。
	assert_float(PusherSpec.FLOOR_Z_BACK).is_less(PusherSpec.DECK_Z_FRONT)
	assert_float(PusherSpec.DECK_Z_FRONT).is_less(PusherSpec.PUSHER_Z_FRONT_HOME)
	assert_float(PusherSpec.PUSHER_Z_FRONT_HOME).is_less(PusherSpec.FLOOR_Z_FRONT)


func test_pusher_travels_forward_from_its_rear_home() -> void:
	assert_float(PusherSpec.PUSHER_Z_REAR_HOME).is_less(PusherSpec.PUSHER_Z_FRONT_HOME)
	assert_float(PusherSpec.PUSHER_STROKE).is_greater(0.0)


# --- 幅の入れ子 ---


func test_medals_rest_inside_the_walls() -> void:
	# メダルが載れる範囲は側壁の内面より内側。外に出ると壁に埋まる。
	assert_float(PusherSpec.FLOOR_HALF_WIDTH).is_less(PusherSpec.FIELD_HALF_WIDTH)


func test_the_plate_clears_the_walls() -> void:
	# 盤が壁と同じ幅だと擦って噛む。
	assert_float(PusherSpec.PUSHER_HALF_WIDTH).is_less(PusherSpec.FIELD_HALF_WIDTH)


func test_both_stages_show_the_same_width() -> void:
	# pusher_spec.gd が明示的に要求している条件:
	#   「下段の側壁の内面。**上段と同じ位置**。」
	# 外へ張り出させると盤の最後退位置に段差ができ、別の台に見える。
	assert_float(PusherSpec.LOWER_HALF_WIDTH).is_equal_approx(PusherSpec.FIELD_HALF_WIDTH, 1e-9)


# --- 横穴(還元率の最大のつまみ) ---


func test_out_hole_swallows_flat_medals_but_not_standing_ones() -> void:
	# pusher_spec.gd の実測メモ:
	#   直径の 1.3 倍まで開けると立ったメダルも重なったメダルも吸い込まれ、
	#   横穴 140 : 払い出し 35 という渋さになった。
	#   直径の 0.8 倍にして、寝たメダルが 1 枚ずつ入る程度に絞る。
	(
		assert_float(PusherSpec.OUT_HEIGHT)
		. override_failure_message("横穴がメダル直径以上。立ったメダルまで吸い込んで台が渋くなる")
		. is_less(MedalSpec.DIAMETER)
	)
	(
		assert_float(PusherSpec.OUT_HEIGHT)
		. override_failure_message("横穴がメダル厚以下。寝たメダルも入らず横穴が機能しない")
		. is_greater(MedalSpec.COLLISION_THICKNESS)
	)


func test_out_hole_height_stays_near_the_measured_ratio() -> void:
	# つまみなので帯で見る。0.8 倍が実測で落ち着いた値。
	var ratio := PusherSpec.OUT_HEIGHT / MedalSpec.DIAMETER
	(
		assert_float(ratio)
		. override_failure_message("横穴が直径の %.2f 倍。実測で落ち着いた 0.8 倍から離れすぎている" % ratio)
		. is_between(0.7, 0.9)
	)


func test_out_hole_starts_ahead_of_the_plate_travel() -> void:
	# 実測で判明した成立条件のひとつ:
	#   「横穴は盤の可動域より手前だけ。可動域の脇に開けると延々とこぼれる」
	(
		assert_float(PusherSpec.OUT_Z_BACK)
		. override_failure_message("横穴が盤の可動域にかかっている。盤の脇からメダルがこぼれ続ける")
		. is_greater_equal(PusherSpec.PUSHER_Z_FRONT_HOME + PusherSpec.PUSHER_STROKE)
	)


func test_out_hole_is_not_shortened() -> void:
	# pusher_spec.gd が明示的に禁じている:
	#   「横穴を短くすれば払い出しは増えるが、それは実機の作りではない。
	#     落ちる量の調整は、うろこねじと前端の坂でやること。」
	(
		assert_float(PusherSpec.OUT_Z_FRONT)
		. override_failure_message("横穴が下段前端まで届いていない。払い出しの調整は SCREW_* と EDGE_* でやること")
		. is_greater_equal(PusherSpec.FLOOR_Z_FRONT)
	)


func test_out_chute_is_wide_enough_for_a_medal() -> void:
	assert_float(PusherSpec.OUT_CHUTE_HALF_WIDTH * 2.0).is_greater(MedalSpec.DIAMETER)


func test_out_sink_sits_below_the_field() -> void:
	assert_float(PusherSpec.OUT_SINK_Y_TOP).is_less(PusherSpec.FLOOR_Y)
	assert_float(PusherSpec.OUT_SINK_Y_BOTTOM).is_less(PusherSpec.OUT_SINK_Y_TOP)


func test_out_hood_exists_to_stop_bridging() -> void:
	# 「これが無いと穴の口でメダルが立って橋を架け、穴が塞がる」
	assert_float(PusherSpec.OUT_HOOD_DEPTH).is_greater(0.0)
	assert_float(PusherSpec.OUT_HOOD_THICKNESS).is_greater(0.0)


# --- 払い出し口 ---


func test_payout_duct_never_pinches_a_medal() -> void:
	# pusher_spec.gd が要求している:
	#   「天井までの隙間はダクトのどこでもメダルの直径(0.25)より広く取る。
	#     狭いと、転がってきた 1 枚が立ったまま噛んで詰まる。」
	var gap := PusherSpec.PAYOUT_PORT_Y_TOP - PusherSpec.PAYOUT_PORT_Y_BOTTOM
	(
		assert_float(gap)
		. override_failure_message(
			"払い出し口の高さ %.3f がメダル直径 %.3f 以下。立ったまま噛んで詰まる" % [gap, MedalSpec.DIAMETER]
		)
		. is_greater(MedalSpec.DIAMETER)
	)


func test_payout_port_is_wide_enough_for_a_medal() -> void:
	assert_float(PusherSpec.PAYOUT_PORT_HALF_WIDTH * 2.0).is_greater(MedalSpec.DIAMETER)


func test_payout_port_sits_above_the_pile() -> void:
	# 「上段の面から 420mm 上。山がここまで積むことはない」
	assert_float(PusherSpec.PAYOUT_PORT_Y_BOTTOM).is_greater(PusherSpec.PUSHER_TOP_Y)


func test_payout_chute_is_tilted_enough_to_roll_out() -> void:
	# 「樋の奥がこれだけ高い。転がり出るのに必要な勾配」
	assert_float(PusherSpec.PAYOUT_CHUTE_RISE).is_greater(0.0)
	assert_float(PusherSpec.PAYOUT_SPAWN_SPEED).is_greater(0.0)
