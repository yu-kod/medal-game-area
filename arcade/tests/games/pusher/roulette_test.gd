extends GdUnitTestSuite

## チェッカー抽選の振る舞いと、抽選表そのものの健全性。
##
## 盤面の払い出しは形状だけで決まっていて乱数に触れない(設計書 5 章)。
## ここで見張るのは「獲得量の調整つまみ」としての抽選表のほうだけ。

const SEED := 20260816


func _roulette(seed_value: int = SEED) -> Roulette:
	return auto_free(Roulette.new(seed_value))


# --- 保留 ---


func test_starts_with_no_stock() -> void:
	assert_int(_roulette().stock).is_equal(0)


func test_stock_accumulates() -> void:
	var roulette := _roulette()
	roulette.add_stock()
	roulette.add_stock()
	assert_int(roulette.stock).is_equal(2)


func test_stock_saturates_at_the_lamp_count() -> void:
	var roulette := _roulette()
	for i in Roulette.STOCK_MAX + 5:
		roulette.add_stock()
	# 境界: ランプの数を超えて溜まらない。超えたぶんは黙って捨てる。
	assert_int(roulette.stock).is_equal(Roulette.STOCK_MAX)


func test_stock_changed_is_silent_once_saturated() -> void:
	var roulette := _roulette()
	for i in Roulette.STOCK_MAX:
		roulette.add_stock()

	var count := 0
	roulette.stock_changed.connect(func(_stock: int) -> void: count += 1)
	roulette.add_stock()

	assert_int(count).is_equal(0)


# --- 抽選の順序 ---


func test_spin_consumes_one_stock_and_decides_immediately() -> void:
	var roulette := _roulette()
	roulette.add_stock()

	var started: Array[int] = []
	roulette.spin_started.connect(func(outcome: int) -> void: started.append(outcome))
	roulette._process(0.016)

	# 回り始めた時点で当落は確定している。回しながら結果を探すのではない。
	assert_array(started).has_size(1)
	assert_int(roulette.stock).is_equal(0)
	assert_bool(roulette.spinning).is_true()


func test_nothing_spins_without_stock() -> void:
	var roulette := _roulette()
	roulette._process(1.0)
	assert_bool(roulette.spinning).is_false()


func test_spin_finishes_after_the_drum_time() -> void:
	var roulette := _roulette()
	roulette.add_stock()
	roulette._process(0.016)

	var finished: Array = []
	roulette.spin_finished.connect(
		func(outcome: int, reward: int) -> void: finished.append([outcome, reward])
	)
	roulette._process(Roulette.SPIN_SEC)

	assert_array(finished).has_size(1)
	assert_bool(roulette.spinning).is_false()
	# 演出で出した結果と、確定していた結果が一致する
	assert_int(finished[0][0]).is_equal(roulette.last_outcome)


func test_hold_blocks_the_next_spin() -> void:
	var roulette := _roulette()
	roulette.add_stock()
	roulette.add_stock()
	roulette._process(0.016)
	roulette._process(Roulette.SPIN_SEC)

	# 止まった直後は間を置く。保留が残っていても即座には回らない。
	roulette._process(0.016)
	assert_bool(roulette.spinning).is_false()

	# 間を消化するティックはそこで return する。回り始めるのは次のティック。
	roulette._process(Roulette.HOLD_SEC_WIN)
	assert_bool(roulette.spinning).is_false()

	roulette._process(0.016)
	assert_bool(roulette.spinning).is_true()


# --- 決定性 ---


func test_same_seed_gives_the_same_sequence() -> void:
	# バランス検証を回すには抽選が再現できることが前提になる。
	var first := _collect_outcomes(_roulette(), 40)
	var second := _collect_outcomes(_roulette(), 40)
	assert_array(first).is_equal(second)


func test_different_seed_gives_a_different_sequence() -> void:
	var first := _collect_outcomes(_roulette(SEED), 60)
	var second := _collect_outcomes(_roulette(SEED + 1), 60)
	assert_array(first).is_not_equal(second)


# --- 抽選表そのもの ---


func test_every_outcome_appears_in_the_table() -> void:
	var listed: Array[int] = []
	for entry in Roulette.TABLE:
		listed.append(entry["outcome"])
	for outcome in Roulette.Outcome.values():
		(
			assert_bool(listed.has(outcome))
			. override_failure_message("Outcome %s が抽選表にない" % outcome)
			. is_true()
		)


func test_weights_are_positive() -> void:
	for entry in Roulette.TABLE:
		(
			assert_int(entry["weight"])
			. override_failure_message("%s の重みが 0 以下。抽選から漏れる" % entry["outcome"])
			. is_greater(0)
		)


func test_only_lose_pays_nothing() -> void:
	for entry in Roulette.TABLE:
		if entry["outcome"] == Roulette.Outcome.LOSE:
			assert_int(entry["reward"]).is_equal(0)
		else:
			assert_int(entry["reward"]).is_greater(0)


func test_rarer_outcomes_pay_more() -> void:
	# 重みの降順 = 配当の昇順。逆転していたら表の書き間違い。
	var previous_weight := Roulette.TABLE[0]["weight"] + 1
	var previous_reward := -1
	for entry in Roulette.TABLE:
		assert_int(entry["weight"]).is_less(previous_weight)
		assert_int(entry["reward"]).is_greater(previous_reward)
		previous_weight = entry["weight"]
		previous_reward = entry["reward"]


func test_expected_reward_per_spin_stays_in_the_designed_band() -> void:
	# 抽選 1 回あたりの期待払い出し枚数。表を触ったときの歯止め。
	# 数字は調整してよいが、桁が飛んだら投入と釣り合わなくなる。
	var total_weight := 0
	var expected := 0.0
	for entry in Roulette.TABLE:
		total_weight += int(entry["weight"])
	for entry in Roulette.TABLE:
		expected += float(entry["weight"]) / float(total_weight) * float(entry["reward"])

	(
		assert_float(expected)
		. override_failure_message("抽選 1 回あたりの期待払い出しが %s 枚。想定帯(1〜10 枚)から外れている" % expected)
		. is_between(1.0, 10.0)
	)


func test_jackpot_is_rare_but_reachable() -> void:
	var total_weight := 0
	var jackpot_weight := 0
	for entry in Roulette.TABLE:
		total_weight += int(entry["weight"])
		if entry["outcome"] == Roulette.Outcome.JACKPOT:
			jackpot_weight = int(entry["weight"])
	var rate := float(jackpot_weight) / float(total_weight)
	assert_float(rate).is_between(0.0001, 0.02)


# --- ヘルパー ---


## 抽選を count 回ぶん回し、出た結果を順に並べて返す。
func _collect_outcomes(roulette: Roulette, count: int) -> Array[int]:
	var outcomes: Array[int] = []
	while outcomes.size() < count:
		roulette.add_stock()
		roulette._process(0.016)
		if not roulette.spinning:
			continue
		outcomes.append(roulette.last_outcome)
		roulette._process(Roulette.SPIN_SEC)
		roulette._process(Roulette.HOLD_SEC_WIN)
	return outcomes
