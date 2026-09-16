extends GdUnitTestSuite

## PlayerWallet の振る舞い。
##
## 設計書 6.1 の「メダルは現金に戻せない」を守れているかも、ここで見張る。


func test_new_wallet_is_empty() -> void:
	assert_int(PlayerWallet.new().medals()).is_equal(0)


func test_spend_fails_when_empty() -> void:
	var wallet := PlayerWallet.new()
	assert_bool(wallet.spend_medal()).is_false()
	assert_int(wallet.medals()).is_equal(0)


func test_spend_succeeds_and_decrements() -> void:
	var wallet := PlayerWallet.new()
	wallet.add_medals(2)
	assert_bool(wallet.spend_medal()).is_true()
	assert_int(wallet.medals()).is_equal(1)


func test_spend_drains_to_exactly_zero_then_refuses() -> void:
	var wallet := PlayerWallet.new()
	wallet.add_medals(1)
	assert_bool(wallet.spend_medal()).is_true()
	assert_int(wallet.medals()).is_equal(0)
	# 境界: 0 枚になった直後にもう 1 度使おうとする
	assert_bool(wallet.spend_medal()).is_false()
	assert_int(wallet.medals()).is_equal(0)


func test_add_ignores_zero_and_negative() -> void:
	var wallet := PlayerWallet.new()
	wallet.add_medals(5)
	wallet.add_medals(0)
	wallet.add_medals(-3)
	# 負数を渡しても減らない。ここが通らなくなったら逆両替の穴が開いている。
	assert_int(wallet.medals()).is_equal(5)


func test_medals_changed_fires_on_add_and_spend() -> void:
	var wallet := PlayerWallet.new()
	var seen: Array[int] = []
	wallet.medals_changed.connect(func(medals: int) -> void: seen.append(medals))

	wallet.add_medals(3)
	wallet.spend_medal()

	assert_array(seen).is_equal([3, 2])


func test_medals_changed_stays_silent_on_ignored_calls() -> void:
	var wallet := PlayerWallet.new()
	var count := 0
	wallet.medals_changed.connect(func(_medals: int) -> void: count += 1)

	wallet.add_medals(0)
	wallet.add_medals(-1)
	wallet.spend_medal()  # 空なので失敗する

	assert_int(count).is_equal(0)


func test_wallet_has_no_way_back_to_cash() -> void:
	# 設計書 6.1 の絶対条件。逆両替の関数が生えたらここで落ちる。
	var wallet := PlayerWallet.new()
	for forbidden in ["to_cash", "cash_out", "refund", "exchange_to_cash", "sell_medals"]:
		(
			assert_bool(wallet.has_method(forbidden))
			. override_failure_message("逆両替にあたる %s() が生えている。設計書 6.1 で禁止されている" % forbidden)
			. is_false()
		)
