extends GdUnitTestSuite

## セーブの中身そのもの。ファイルには触らない。
##
## 読み込みは**外から来た壊れたデータ**を相手にする。
## 起動できないより初期値で始まるほうがましなので、何を渡しても落ちないことを見る。

# --- 既定値 ---


func test_a_fresh_state_starts_empty() -> void:
	var state := PlayerState.new()
	assert_int(state.cash).is_equal(0)
	assert_int(state.stored_last_visit).is_equal(0)


# --- 往復 ---


func test_a_state_survives_a_round_trip() -> void:
	var state := PlayerState.new()
	state.cash = 1234
	state.stored_last_visit = 1_700_000_000

	var restored := PlayerState.from_dict(state.to_dict())

	assert_int(restored.cash).is_equal(1234)
	assert_int(restored.stored_last_visit).is_equal(1_700_000_000)


func test_the_format_carries_a_version() -> void:
	# 後から形を変えたときに、古いセーブだと気づけるようにする。
	assert_int(PlayerState.new().to_dict()["version"]).is_equal(PlayerState.VERSION)


# --- 壊れた入力 ---


func test_an_empty_dict_gives_defaults() -> void:
	var state := PlayerState.from_dict({})
	assert_int(state.cash).is_equal(0)


func test_missing_keys_give_defaults() -> void:
	# 項目が増える前のセーブを読んでも落ちない。
	var state := PlayerState.from_dict({"version": 1})
	assert_int(state.cash).is_equal(0)


func test_json_floats_become_ints() -> void:
	# JSON.parse_string は数値をすべて float で返す。
	# int(...) を通していないとここで型が崩れる。
	var state := PlayerState.from_dict({"cash": 100.0})
	assert_int(state.cash).is_equal(100)


func test_a_fractional_amount_is_truncated_not_rejected() -> void:
	var state := PlayerState.from_dict({"cash": 100.7})
	assert_int(state.cash).is_equal(100)


func test_a_non_numeric_amount_falls_back_to_zero() -> void:
	assert_int(PlayerState.from_dict({"cash": "abc"}).cash).is_equal(0)
	assert_int(PlayerState.from_dict({"cash": null}).cash).is_equal(0)
	assert_int(PlayerState.from_dict({"cash": []}).cash).is_equal(0)


func test_negative_amounts_are_clamped() -> void:
	# 負の所持金は存在しない。書き換えられたセーブで借金状態にしない。
	assert_int(PlayerState.from_dict({"cash": -500}).cash).is_equal(0)


func test_unknown_keys_are_ignored() -> void:
	var state := PlayerState.from_dict({"cash": 10, "something_new": 99})
	assert_int(state.cash).is_equal(10)


# --- 経済の前提を破らない ---


func test_carried_medals_are_never_restored() -> void:
	# 設計書 §12 の PlayerState に手持ちメダルの項目は無い。
	# §8 のとおり、セッションを跨いで残る資産は預かりメダルだけ。
	# 手で書き足したセーブからメダルが湧かないことを明示的に見張る。
	var state := PlayerState.from_dict({"cash": 0, "medals": 500, "stored_medals": 500})
	(
		assert_bool(state.to_dict().has("medals"))
		. override_failure_message("手持ちメダルがセーブに載っている。セッションを跨いで残るのは預かりだけ(設計書 §8)")
		. is_false()
	)
	assert_int(state.cash).is_equal(0)


func test_loading_never_invents_cash() -> void:
	# メダルを現金に換算して復元する経路を作らない(設計書 §6.1)。
	var state := PlayerState.from_dict({"medals": 9999})
	assert_int(state.cash).is_equal(0)


# --- 来店日 ---


func test_stamping_a_visit_records_the_given_time() -> void:
	# 時刻は外から渡す。Time を直接呼ぶと決定的にテストできない。
	var state := PlayerState.new()
	state.stamp_visit(1_700_000_000)
	assert_int(state.stored_last_visit).is_equal(1_700_000_000)


func test_days_since_the_last_visit() -> void:
	var state := PlayerState.new()
	state.stamp_visit(1_700_000_000)
	assert_int(state.days_since_visit(1_700_000_000)).is_equal(0)
	assert_int(state.days_since_visit(1_700_000_000 + PlayerState.SECONDS_PER_DAY * 30)).is_equal(
		30
	)


func test_a_state_that_never_visited_reports_no_days() -> void:
	# 未訪問(0)を 1970 年からの経過日数として扱わない。失効判定が即座に走ってしまう。
	var state := PlayerState.new()
	assert_int(state.days_since_visit(1_700_000_000)).is_equal(0)


func test_a_clock_moved_backwards_does_not_report_negative_days() -> void:
	var state := PlayerState.new()
	state.stamp_visit(1_700_000_000)
	assert_int(state.days_since_visit(1_600_000_000)).is_equal(0)


# --- シフト(#5) ---


func test_shift_fields_survive_a_round_trip() -> void:
	var state := PlayerState.new()
	state.daily_work_remaining = 1234
	state.daily_work_date = 20713

	var restored := PlayerState.from_dict(state.to_dict())

	assert_int(restored.daily_work_remaining).is_equal(1234)
	assert_int(restored.daily_work_date).is_equal(20713)


func test_a_save_from_before_shifts_existed_still_loads() -> void:
	# #14 の時点のセーブにはシフトの項目が無い。
	var restored := PlayerState.from_dict({"version": 1, "cash": 500, "stored_last_visit": 1})
	assert_int(restored.cash).is_equal(500)
	assert_int(restored.daily_work_remaining).is_equal(0)
	assert_int(restored.daily_work_date).is_equal(0)


func test_negative_shift_values_are_clamped() -> void:
	var restored := PlayerState.from_dict({"daily_work_remaining": -50, "daily_work_date": -3})
	assert_int(restored.daily_work_remaining).is_equal(0)
	assert_int(restored.daily_work_date).is_equal(0)
