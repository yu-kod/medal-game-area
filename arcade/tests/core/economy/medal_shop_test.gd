extends GdUnitTestSuite

## メダル購入の段階レート(設計書 §6.2)。
##
## 見張るのは 2 つ。買ったときに正しく現金と枚数が動くことと、
## **レート表の歪みが保たれていること**。後者がこの画面の設計の核心。


func _wallet() -> PlayerWallet:
	return PlayerWallet.new()


# --- レート表そのもの ---


func test_table_matches_the_design() -> void:
	var expected := [[100, 15], [500, 90], [1000, 200], [1200, 300], [3000, 900], [5000, 1700]]
	assert_int(MedalShop.OPTIONS.size()).is_equal(expected.size())
	for index in expected.size():
		var option: Dictionary = MedalShop.OPTIONS[index]
		assert_int(option["yen"]).is_equal(expected[index][0])
		assert_int(option["medals"]).is_equal(expected[index][1])


func test_amounts_and_medals_both_increase() -> void:
	var previous_yen := 0
	var previous_medals := 0
	for option in MedalShop.OPTIONS:
		assert_int(option["yen"]).is_greater(previous_yen)
		assert_int(option["medals"]).is_greater(previous_medals)
		previous_yen = option["yen"]
		previous_medals = option["medals"]


func test_buying_more_is_never_worse_per_medal() -> void:
	# 段が上がるほど単価は安くなる。逆転していたら表の書き間違い。
	var previous := INF
	for option in MedalShop.OPTIONS:
		var unit := float(option["yen"]) / float(option["medals"])
		assert_float(unit).is_less(previous)
		previous = unit


func test_the_1200_yen_step_is_the_sweetest_deal() -> void:
	# 設計の核心。1000 円を選ぼうとした瞬間に強い引力が働くのは、
	# **追加分の単価**がこの段だけ突出して安いから。
	# ここが崩れたら購入画面が体験装置として死ぬ。
	var marginal := _marginal_unit_prices()
	var sweet_index := _index_of_yen(1200)

	for index in marginal.size():
		if index == sweet_index:
			continue
		(
			assert_float(marginal[sweet_index])
			. override_failure_message(
				(
					"1200円の追加分単価 %.2f 円が、%d円の段の %.2f 円より安くない。設計書 §6.2 の歪みが失われている"
					% [marginal[sweet_index], MedalShop.OPTIONS[index]["yen"], marginal[index]]
				)
			)
			. is_less(marginal[index])
		)


func test_the_sweet_step_is_an_odd_amount() -> void:
	# 端数であることも設計の一部。1000 円のすぐ隣にあるから引力が働く。
	assert_int(MedalShop.OPTIONS[_index_of_yen(1200)]["yen"] % 1000).is_not_equal(0)


# --- 購入 ---


func test_purchase_moves_cash_into_medals() -> void:
	var wallet := _wallet()
	wallet.add_cash(1200)

	assert_bool(MedalShop.purchase(wallet, _index_of_yen(1200))).is_true()
	assert_int(wallet.cash()).is_equal(0)
	assert_int(wallet.medals()).is_equal(300)


func test_purchase_with_exact_cash_succeeds() -> void:
	# 境界: 所持金がちょうど段の金額と同じ。
	var wallet := _wallet()
	wallet.add_cash(500)
	assert_bool(MedalShop.purchase(wallet, _index_of_yen(500))).is_true()
	assert_int(wallet.cash()).is_equal(0)
	assert_int(wallet.medals()).is_equal(90)


func test_purchase_fails_one_yen_short() -> void:
	# 境界: 1 円足りない。
	var wallet := _wallet()
	wallet.add_cash(499)

	assert_bool(MedalShop.purchase(wallet, _index_of_yen(500))).is_false()
	assert_int(wallet.cash()).is_equal(499)
	assert_int(wallet.medals()).is_equal(0)


func test_failed_purchase_changes_nothing() -> void:
	var wallet := _wallet()
	wallet.add_cash(100)
	MedalShop.purchase(wallet, _index_of_yen(5000))
	# 現金も枚数も動かない。片方だけ動くのが最悪の壊れ方。
	assert_int(wallet.cash()).is_equal(100)
	assert_int(wallet.medals()).is_equal(0)


func test_every_option_is_purchasable_with_enough_cash() -> void:
	for index in MedalShop.OPTIONS.size():
		var option: Dictionary = MedalShop.OPTIONS[index]
		var wallet := _wallet()
		wallet.add_cash(option["yen"])

		(
			assert_bool(MedalShop.purchase(wallet, index))
			. override_failure_message("%d円の段が買えない" % option["yen"])
			. is_true()
		)
		assert_int(wallet.medals()).is_equal(option["medals"])
		assert_int(wallet.cash()).is_equal(0)


func test_out_of_range_option_is_refused() -> void:
	var wallet := _wallet()
	wallet.add_cash(100000)
	assert_bool(MedalShop.purchase(wallet, -1)).is_false()
	assert_bool(MedalShop.purchase(wallet, MedalShop.OPTIONS.size())).is_false()
	assert_int(wallet.cash()).is_equal(100000)


func test_affordable_options_reflect_the_purse() -> void:
	var wallet := _wallet()
	wallet.add_cash(1000)
	var affordable := MedalShop.affordable_indices(wallet.cash())
	# 100 / 500 / 1000 の 3 段だけ買える。
	assert_int(affordable.size()).is_equal(3)
	assert_bool(affordable.has(_index_of_yen(1200))).is_false()


# --- 現金を持たせる口 ---


func test_wallet_starts_with_no_cash() -> void:
	assert_int(_wallet().cash()).is_equal(0)


func test_add_cash_ignores_zero_and_negative() -> void:
	var wallet := _wallet()
	wallet.add_cash(300)
	wallet.add_cash(0)
	wallet.add_cash(-100)
	assert_int(wallet.cash()).is_equal(300)


func test_cash_changed_fires_only_on_real_change() -> void:
	var wallet := _wallet()
	var seen: Array[int] = []
	wallet.cash_changed.connect(func(cash: int) -> void: seen.append(cash))

	wallet.add_cash(500)
	wallet.add_cash(0)
	MedalShop.purchase(wallet, _index_of_yen(500))

	assert_array(seen).is_equal([500, 0])


# --- 一方通行であること ---


func test_shop_has_no_way_to_sell_medals_back() -> void:
	# 設計書 §6.1 の絶対条件。現金 → メダルの一方通行を店側でも守る。
	# PlayerWallet 側は player_wallet_test.gd が見張っている。
	var shop := MedalShop.new()
	for forbidden in ["sell", "sell_medals", "refund", "buy_back", "exchange_to_cash", "cash_out"]:
		(
			assert_bool(shop.has_method(forbidden))
			. override_failure_message("逆両替にあたる %s() が生えている。設計書 §6.1 で禁止されている" % forbidden)
			. is_false()
		)


func test_purchase_never_increases_cash() -> void:
	# どの段をどう叩いても現金が増えることはない。
	for index in range(-1, MedalShop.OPTIONS.size() + 1):
		var wallet := _wallet()
		wallet.add_cash(2000)
		MedalShop.purchase(wallet, index)
		(
			assert_int(wallet.cash())
			. override_failure_message("添字 %d の購入で現金が増えた" % index)
			. is_less_equal(2000)
		)


# --- ヘルパー ---


## 前の段から 1 枚増やすのに何円かかるか。最初の段は単価そのもの。
func _marginal_unit_prices() -> Array[float]:
	var prices: Array[float] = []
	var previous_yen := 0
	var previous_medals := 0
	for option in MedalShop.OPTIONS:
		var extra_yen := float(option["yen"] - previous_yen)
		var extra_medals := float(option["medals"] - previous_medals)
		prices.append(extra_yen / extra_medals)
		previous_yen = option["yen"]
		previous_medals = option["medals"]
	return prices


func _index_of_yen(yen: int) -> int:
	for index in MedalShop.OPTIONS.size():
		if MedalShop.OPTIONS[index]["yen"] == yen:
			return index
	return -1
