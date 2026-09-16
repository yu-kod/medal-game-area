extends GdUnitTestSuite

## メダルの寸法とスケールの整合。
##
## ここは「値が正しいか」ではなく「値どうしの関係が壊れていないか」を見る。
## 個々の実測値は調整して構わないが、関係が崩れると Phase 0 の検証が無効になる。

## 実寸 1m がゲーム内で何単位になるか。MM から逆算する。
const SCALE := MedalSpec.MM * 1000.0


func test_scale_is_ten_times_real_size() -> void:
	# 10 倍スケール。Jolt が動的物体 0.1〜10m を前提にしているのでここを外せない。
	assert_float(SCALE).is_equal_approx(10.0, 0.0001)


func test_diameter_follows_from_millimetres_and_scale() -> void:
	assert_float(MedalSpec.DIAMETER).is_equal_approx(MedalSpec.DIAMETER_MM * MedalSpec.MM, 1e-9)
	assert_float(MedalSpec.RADIUS * 2.0).is_equal_approx(MedalSpec.DIAMETER, 1e-9)


func test_medal_stays_inside_jolt_sweet_spot() -> void:
	# Jolt が精度を出せる動的物体のサイズ帯。実寸 25mm のままだと下限を割る。
	assert_float(MedalSpec.DIAMETER).is_between(0.1, 10.0)


func test_collision_is_thicker_than_the_visible_mesh() -> void:
	# 積み重なりの安定はこの水増しで持たせている。等しくすると山が崩れる。
	assert_float(MedalSpec.COLLISION_THICKNESS).is_greater(MedalSpec.VISUAL_THICKNESS)
	assert_float(MedalSpec.COLLISION_THICKNESS).is_equal_approx(
		MedalSpec.VISUAL_THICKNESS * MedalSpec.COLLISION_THICKNESS_FACTOR, 1e-9
	)


func test_medal_is_a_prism_not_a_thin_cylinder() -> void:
	# 薄い円柱プリミティブは剛体ソルバの最悪ケースなので凸包の角数で近似する。
	assert_int(MedalSpec.SIDES).is_greater_equal(12)


func test_friction_stays_in_the_measured_band() -> void:
	# 0.19 では山が盛りすぎ、0.12 では平らになりすぎる(medal_spec.gd の実測メモ)。
	assert_float(MedalSpec.FRICTION).is_between(0.12, 0.19)


func test_gravity_matches_the_scale() -> void:
	# このプロジェクトで最も壊れやすい不変条件。
	#
	# 剛体系は「長さ k 倍・重力 a 倍」で時間が √(k/a) 倍にスケールする。
	# k = 10 で重力を実物の 9.8 のままにすると時間が √10 ≒ 3.16 倍に伸び、
	# 実物の 1/3 の速さで落ちる。a = k にして初めて sim 秒 = 実秒 になる。
	#
	# 設計書 4.1 は「重力を変えると嘘くさくなる」と書いているが、
	# スケールを変えた場合は逆。ここは設計書からの意図的な逸脱。
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	(
		assert_float(gravity)
		. override_failure_message(
			"重力 %s はスケール %s 倍と合っていない。9.8 × %s = %s にすること" % [gravity, SCALE, SCALE, 9.8 * SCALE]
		)
		. is_equal_approx(9.8 * SCALE, 0.001)
	)


func test_physics_tick_is_raised_for_the_faster_world() -> void:
	# 重力を 10 倍にしたぶん速度も √10 倍になるので時間解像度を上げてある。
	var ticks: int = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	assert_int(ticks).is_greater_equal(180)


func test_penetration_slop_is_finer_than_a_medal() -> void:
	# 既定の 0.02 はコリジョン厚とほぼ同じで、メダル 1 枚ぶんのめり込みを許してしまう。
	var slop: float = ProjectSettings.get_setting(
		"physics/jolt_physics_3d/simulation/penetration_slop"
	)
	assert_float(slop).is_less(MedalSpec.COLLISION_THICKNESS * 0.5)
