extends GdUnitTestSuite

## クリッカー(設計書 §6.3)。
##
## 見張るのは 3 つの制約。どれも「親切心で外される」種類なので明示的にテストする。
##   - 時間を払わないと稼げない(作業の間隔)
##   - 1 日に稼げる額に上限がある(シフト制)
##   - **放置しても何も起きない**(オフライン報酬なし)

## 2026-09-17 00:00:00 UTC
const DAY_START := 1789603200.0


func _wallet() -> PlayerWallet:
	return PlayerWallet.new()


## 上限まで残っている、今日のシフト。
func _shift() -> WorkShift:
	return WorkShift.new()


# --- 1 回の作業 ---


func test_a_task_pays_the_wage() -> void:
	var wallet := _wallet()
	var paid := _shift().work(wallet, DAY_START)
	assert_int(paid).is_equal(WorkShift.YEN_PER_TASK)
	assert_int(wallet.cash()).is_equal(WorkShift.YEN_PER_TASK)


func test_clicking_faster_than_the_pace_earns_nothing() -> void:
	# 連打で時給を上げられると「1時間の労働」という重さが消える(設計書 §6.4)。
	var wallet := _wallet()
	var shift := _shift()
	shift.work(wallet, DAY_START)
	var paid := shift.work(wallet, DAY_START + WorkShift.TASK_INTERVAL_SEC * 0.5)
	assert_int(paid).is_equal(0)
	assert_int(wallet.cash()).is_equal(WorkShift.YEN_PER_TASK)


func test_the_next_task_counts_once_the_interval_passes() -> void:
	var wallet := _wallet()
	var shift := _shift()
	shift.work(wallet, DAY_START)
	var paid := shift.work(wallet, DAY_START + WorkShift.TASK_INTERVAL_SEC)
	assert_int(paid).is_equal(WorkShift.YEN_PER_TASK)


func test_an_hour_of_steady_work_earns_about_the_hourly_wage() -> void:
	# 設計書 §6.3 「時給換算 約 1,100 円」。実際に 1 時間ぶん叩いて確かめる。
	var wallet := _wallet()
	var shift := _shift()
	var now := DAY_START
	while now < DAY_START + 3600.0:
		shift.work(wallet, now)
		now += WorkShift.TASK_INTERVAL_SEC
	(
		assert_int(wallet.cash())
		. override_failure_message("1 時間で %d 円。設計書の時給換算 約 1,100 円から外れている" % wallet.cash())
		. is_between(1000, 1200)
	)


# --- 日次上限 ---


func test_work_stops_exactly_at_the_daily_cap() -> void:
	var wallet := _wallet()
	var shift := _shift()
	_work_until_capped(shift, wallet, DAY_START)

	assert_int(wallet.cash()).is_equal(WorkShift.DAILY_CAP_YEN)
	assert_int(shift.remaining_today(DAY_START + 3600.0 * 10)).is_equal(0)


func test_no_cash_after_the_cap_is_reached() -> void:
	var wallet := _wallet()
	var shift := _shift()
	var now := _work_until_capped(shift, wallet, DAY_START)

	# 同じ日のうちは、間隔を空けて何度叩いても 1 円も増えない。
	for i in 20:
		now += WorkShift.TASK_INTERVAL_SEC
		assert_int(shift.work(wallet, now)).is_equal(0)
	assert_int(wallet.cash()).is_equal(WorkShift.DAILY_CAP_YEN)


func test_a_new_day_refills_the_shift() -> void:
	var wallet := _wallet()
	var shift := _shift()
	_work_until_capped(shift, wallet, DAY_START)

	var tomorrow := DAY_START + WorkShift.SECONDS_PER_DAY
	assert_int(shift.work(wallet, tomorrow)).is_equal(WorkShift.YEN_PER_TASK)
	assert_int(shift.remaining_today(tomorrow)).is_equal(
		WorkShift.DAILY_CAP_YEN - WorkShift.YEN_PER_TASK
	)


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


# --- 放置 ---


func test_idle_time_earns_nothing() -> void:
	# オフライン報酬なし(設計書 §6.3)。**入れ忘れではなく、入れないのが仕様。**
	# 何時間空けても、次の 1 回で得られるのは 1 回ぶんだけ。
	var wallet := _wallet()
	var shift := _shift()
	shift.work(wallet, DAY_START)
	var paid := shift.work(wallet, DAY_START + 10 * 3600.0)
	assert_int(paid).is_equal(WorkShift.YEN_PER_TASK)
	assert_int(wallet.cash()).is_equal(WorkShift.YEN_PER_TASK * 2)


func test_reading_the_remaining_amount_does_not_pay() -> void:
	var wallet := _wallet()
	var shift := _shift()
	shift.remaining_today(DAY_START + 5 * 3600.0)
	assert_int(wallet.cash()).is_equal(0)


# --- 時計 ---


func test_a_clock_moved_backwards_does_not_refill_the_shift() -> void:
	var wallet := _wallet()
	var shift := _shift()
	var now := _work_until_capped(shift, wallet, DAY_START + WorkShift.SECONDS_PER_DAY)

	# 前日へ戻しても、上限が戻ったりはしない。
	assert_int(shift.work(wallet, DAY_START)).is_equal(0)
	assert_int(shift.remaining_today(DAY_START)).is_equal(0)
	assert_int(wallet.cash()).is_equal(WorkShift.DAILY_CAP_YEN)
	assert_float(now).is_greater(DAY_START)


# --- 保存 ---


func test_the_shift_survives_a_restart_on_the_same_day() -> void:
	var wallet := _wallet()
	var shift := _shift()
	shift.work(wallet, DAY_START)

	var state := PlayerState.new()
	shift.write_to(state)
	var restored := WorkShift.from_state(state)

	assert_int(restored.remaining_today(DAY_START + 60.0)).is_equal(
		WorkShift.DAILY_CAP_YEN - WorkShift.YEN_PER_TASK
	)


func test_restarting_does_not_refill_the_shift() -> void:
	# 再起動で上限が戻ると、上限そのものが意味を失う(#14 の目的)。
	var wallet := _wallet()
	var shift := _shift()
	_work_until_capped(shift, wallet, DAY_START)

	var state := PlayerState.new()
	shift.write_to(state)
	var restored := WorkShift.from_state(state)

	assert_int(restored.work(wallet, DAY_START + 7200.0)).is_equal(0)


func test_a_save_without_shift_data_starts_a_full_shift() -> void:
	# 項目が増える前のセーブ(#14 の時点)を読んだとき。
	var restored := WorkShift.from_state(PlayerState.new())
	assert_int(restored.remaining_today(DAY_START)).is_equal(WorkShift.DAILY_CAP_YEN)


func test_a_tampered_remaining_amount_is_capped() -> void:
	var state := PlayerState.new()
	state.daily_work_remaining = 999999
	state.daily_work_date = WorkShift.day_of(DAY_START)
	var restored := WorkShift.from_state(state)
	assert_int(restored.remaining_today(DAY_START)).is_equal(WorkShift.DAILY_CAP_YEN)


# --- 数字どうしの関係 ---


func test_a_day_of_work_can_buy_the_1200_yen_step() -> void:
	# 設計書 §6.2 の核心の段に、1 日働けば手が届く。
	assert_int(WorkShift.DAILY_CAP_YEN).is_greater_equal(_yen_of_step(1200))


func test_a_day_of_work_cannot_buy_the_top_step() -> void:
	# 一番上の段は 1 日では買えない。§6.4 の「現金とメダルの交換比率」というつまみが効いている状態。
	var top: int = MedalShop.OPTIONS[MedalShop.OPTIONS.size() - 1]["yen"]
	(
		assert_int(WorkShift.DAILY_CAP_YEN)
		. override_failure_message("1 日の上限 %d 円で最上段 %d 円が買えてしまう" % [WorkShift.DAILY_CAP_YEN, top])
		. is_less(top)
	)


# --- ヘルパー ---


## 上限に達するまで間隔どおりに叩く。最後に叩いた時刻を返す。
func _work_until_capped(shift: WorkShift, wallet: PlayerWallet, start: float) -> float:
	var now := start
	while shift.work(wallet, now) > 0:
		now += WorkShift.TASK_INTERVAL_SEC
	return now


func _yen_of_step(yen: int) -> int:
	for option in MedalShop.OPTIONS:
		if option["yen"] == yen:
			return yen
	return -1
