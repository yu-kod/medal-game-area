extends GdUnitTestSuite

## 衝突の強さの測り方(純粋な計算)。
##
## 強さは Jolt の推定力積ではなく、接触点での**接近速度**で測る。
## 推定力積は「他の物体と触れていないときだけ正確」なので、山の中では使えない。

# --- 接近速度 ---


func test_approaching_along_the_normal_is_positive() -> void:
	# 法線は相手から自分へ向く。自分が相手へ向かって動いていれば正。
	var approach := MedalStrike.approach_speed(Vector3(0, -5, 0), Vector3.ZERO, Vector3.UP)
	assert_float(approach).is_equal_approx(5.0, 1e-6)


func test_separating_is_negative() -> void:
	var approach := MedalStrike.approach_speed(Vector3(0, 3, 0), Vector3.ZERO, Vector3.UP)
	assert_float(approach).is_less(0.0)


func test_sliding_along_the_surface_is_not_a_strike() -> void:
	# 押されて床を滑っているだけのメダル。
	var approach := MedalStrike.approach_speed(Vector3(4, 0, 0), Vector3.ZERO, Vector3.UP)
	assert_float(approach).is_equal_approx(0.0, 1e-6)


func test_approach_is_relative_to_a_moving_collider() -> void:
	# 同じ速さで一緒に動いている相手には当たっていない(押されている山の中)。
	var approach := MedalStrike.approach_speed(Vector3(0, -2, 0), Vector3(0, -2, 0), Vector3.UP)
	assert_float(approach).is_equal_approx(0.0, 1e-6)


func test_body_speed_counts_the_spinning_rim() -> void:
	# 回っているメダルは、止まっていても縁は動いている。
	var speed := MedalStrike.body_speed(Vector3.ZERO, Vector3(0, 20, 0))
	assert_float(speed).is_equal_approx(20.0 * MedalSpec.RADIUS, 1e-6)


# --- 鳴らすかどうか ---


func test_resting_noise_is_far_below_the_audible_threshold() -> void:
	# 静止しているメダルも、1 ステップぶんの重力加速(重力 / ティック数)が
	# 接近速度として毎ステップ見える。実測で 0.544(= 98 / 180)。
	# しきい値がこれに近いと、山が止まっているだけで鳴り続ける。
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var ticks: int = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	var resting_noise := gravity / ticks
	(
		assert_float(MedalStrike.AUDIBLE_APPROACH)
		. override_failure_message(
			(
				"鳴らすしきい値 %.2f が静止中の見かけの接近速度 %.3f の 3 倍未満"
				% [MedalStrike.AUDIBLE_APPROACH, resting_noise]
			)
		)
		. is_greater(resting_noise * 3.0)
	)


func test_audible_threshold_boundary() -> void:
	assert_bool(MedalStrike.is_audible(MedalStrike.AUDIBLE_APPROACH - 0.01)).is_false()
	assert_bool(MedalStrike.is_audible(MedalStrike.AUDIBLE_APPROACH)).is_true()


func test_the_gate_cannot_hide_an_audible_head_on_strike() -> void:
	# 遅いメダルは計算を打ち切るが、打ち切り速度が高すぎると
	# 「両方とも少し遅い」正面衝突をどちらも報告しなくなる。
	# 接近速度は 2 つの速さの和を超えないので、打ち切りは鳴らすしきい値の半分以下にする。
	assert_float(MedalStrike.GATE_SPEED * 2.0).is_less_equal(MedalStrike.AUDIBLE_APPROACH)


# --- 音量 ---


func test_the_quietest_audible_strike() -> void:
	var expected := linear_to_db(MedalStrike.AUDIBLE_APPROACH / MedalStrike.FULL_APPROACH)
	assert_float(MedalStrike.volume_db(MedalStrike.AUDIBLE_APPROACH)).is_equal_approx(
		expected, 0.01
	)


func test_a_full_strike_is_full_volume() -> void:
	assert_float(MedalStrike.volume_db(MedalStrike.FULL_APPROACH)).is_equal_approx(0.0, 0.01)


func test_volume_never_exceeds_full() -> void:
	assert_float(MedalStrike.volume_db(MedalStrike.FULL_APPROACH * 5.0)).is_equal_approx(0.0, 0.01)


func test_amplitude_follows_speed() -> void:
	# 振幅は速さに比例させる。速さが半分なら -6 dB。
	var full := MedalStrike.volume_db(MedalStrike.FULL_APPROACH)
	var half := MedalStrike.volume_db(MedalStrike.FULL_APPROACH * 0.5)
	assert_float(full - half).is_equal_approx(6.02, 0.05)


func test_harder_strikes_are_never_quieter() -> void:
	var previous := -INF
	var approach := MedalStrike.AUDIBLE_APPROACH
	while approach < MedalStrike.FULL_APPROACH * 2.0:
		var db := MedalStrike.volume_db(approach)
		assert_float(db).is_greater_equal(previous)
		previous = db
		approach += 0.25


# --- どちらが報告するか ---


func test_the_faster_body_reports() -> void:
	assert_bool(MedalStrike.reports(5.0, 1.0, 10, 20)).is_true()
	assert_bool(MedalStrike.reports(1.0, 5.0, 10, 20)).is_false()


func test_equal_speeds_report_exactly_once() -> void:
	# メダル同士の衝突は両方の剛体が同じ接触を見る。片方だけが鳴らす。
	var a := MedalStrike.reports(3.0, 3.0, 10, 20)
	var b := MedalStrike.reports(3.0, 3.0, 20, 10)
	(
		assert_bool(a != b)
		. override_failure_message("同じ速さの衝突が %s 回鳴る" % (2 if a and b else 0))
		. is_true()
	)
