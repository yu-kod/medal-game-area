extends GdUnitTestSuite

## クリッカーと時計(設計書 §6.3 のシフト制)。
##
## 日付の境目、時差、時計の巻き戻し・先走り、作業の間隔を測る時計。
## プレイヤーの PC の時計は正しいとは限らないので、ずれたときに
## 「上限が戻る」「締め出される」のどちらにも倒れないことを見る。

## 2026-09-17 00:00:00 UTC
const DAY_START := 1789603200.0


func _wallet() -> PlayerWallet:
	return PlayerWallet.new()


func _shift() -> WorkShift:
	return WorkShift.new()


func test_the_day_boundary_is_midnight() -> void:
	# シフト制なので、決まった時刻で切り替わる。最後に叩いた時刻からの 24 時間ではない。
	assert_int(WorkShift.day_of(DAY_START - 1.0)).is_not_equal(WorkShift.day_of(DAY_START))
	assert_int(WorkShift.day_of(DAY_START)).is_equal(WorkShift.day_of(DAY_START + 86399.0))


func test_the_boundary_follows_the_local_timezone() -> void:
	# 日本時間(+9 時間)なら、UTC の 15:00 が日付の境目になる。
	var jst := 9 * 3600
	var local_midnight := DAY_START + 15 * 3600.0
	assert_int(WorkShift.day_of(local_midnight - 1.0, jst)).is_not_equal(
		WorkShift.day_of(local_midnight, jst)
	)


func test_a_clock_moved_backwards_does_not_refill_the_shift() -> void:
	var wallet := _wallet()
	var shift := _shift()
	var now := _work_until_capped(shift, wallet, DAY_START + WorkShift.SECONDS_PER_DAY)

	# 前日へ戻しても、上限が戻ったりはしない。
	assert_int(shift.work(wallet, DAY_START)).is_equal(0)
	assert_int(shift.remaining_today(DAY_START)).is_equal(0)
	assert_int(wallet.cash()).is_equal(WorkShift.DAILY_CAP_YEN)
	assert_float(now).is_greater(DAY_START + WorkShift.SECONDS_PER_DAY)


func test_going_back_a_day_and_forward_again_does_not_refill() -> void:
	# 時差のある移動や 1 日ぶんの時計のずれ。戻して、また進めても上限は戻らない。
	var wallet := _wallet()
	var shift := _shift()
	var today := DAY_START + WorkShift.SECONDS_PER_DAY
	var now := _work_until_capped(shift, wallet, today)

	shift.work(wallet, DAY_START + 60.0)
	assert_int(shift.work(wallet, now + WorkShift.TASK_INTERVAL_SEC)).is_equal(0)
	assert_int(wallet.cash()).is_equal(WorkShift.DAILY_CAP_YEN)


func test_going_back_a_day_keeps_the_partial_shift() -> void:
	var wallet := _wallet()
	var shift := _shift()
	var today := DAY_START + WorkShift.SECONDS_PER_DAY
	shift.work(wallet, today)

	assert_int(shift.work(wallet, DAY_START + 60.0)).is_equal(WorkShift.YEN_PER_TASK)
	assert_int(shift.remaining_today(today + 120.0)).is_equal(
		WorkShift.DAILY_CAP_YEN - WorkShift.YEN_PER_TASK * 2
	)


func test_a_clock_that_ran_far_ahead_does_not_lock_work_forever() -> void:
	# 時計が一時的に数年先を指していた / セーブが壊れていた。
	# 直したあと、その未来の日付が来るまで働けない、という状態にしない。
	var wallet := _wallet()
	var shift := _shift()
	var far_future := DAY_START + WorkShift.SECONDS_PER_DAY * 365 * 4
	_work_until_capped(shift, wallet, far_future)

	# 時計を直した当日は、未来で使い切った残り(0)を引き継ぐ。上限は戻さない。
	assert_int(shift.work(wallet, DAY_START)).is_equal(0)
	# 翌日になれば普通に働ける。
	var tomorrow := DAY_START + WorkShift.SECONDS_PER_DAY
	assert_int(shift.work(wallet, tomorrow)).is_equal(WorkShift.YEN_PER_TASK)


func test_the_pace_follows_the_steady_clock_not_the_wall_clock() -> void:
	# 壁時計を巻き戻すたびに 1 回ぶん早く稼げる、を塞ぐ。
	# 間隔は起動からの経過時間(単調に進む時計)で測り、壁時計は日付にだけ使う。
	var wallet := _wallet()
	var shift := _shift()
	shift.work(wallet, DAY_START, 0, 100.0)
	# 壁時計は 1 時間戻ったが、実際には 1 秒しか経っていない。
	var paid := shift.work(wallet, DAY_START - 3600.0, 0, 101.0)
	assert_int(paid).is_equal(0)


func test_a_save_dated_far_in_the_future_does_not_lock_work() -> void:
	var state := PlayerState.new()
	state.daily_work_remaining = 0
	state.daily_work_date = WorkShift.day_of(DAY_START) + 5000
	var restored := WorkShift.from_state(state)

	var tomorrow := DAY_START + WorkShift.SECONDS_PER_DAY
	restored.work(_wallet(), DAY_START)
	assert_int(restored.work(_wallet(), tomorrow)).is_equal(WorkShift.YEN_PER_TASK)


## 上限に達するまで間隔どおりに叩く。最後に叩いた時刻を返す。
func _work_until_capped(shift: WorkShift, wallet: PlayerWallet, start: float) -> float:
	var now := start
	while shift.work(wallet, now) > 0:
		now += WorkShift.TASK_INTERVAL_SEC
	return now
