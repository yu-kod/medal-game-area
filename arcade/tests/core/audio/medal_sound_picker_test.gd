extends GdUnitTestSuite

## 枚数から鳴らす音を選ぶところ。
##
## 設計書 §11 が要求しているのは 2 つ。
##   「1枚 / 数枚 / 大量 の3系統をランダム選択」
## 系統の切り替わりと、同じ音が続かないことを見る。
##
## 音そのものの良し悪しは耳の領域なのでテストしない。


## 実物のファイル名に依存しない合成の音源表。
## 素材を差し替えてもこのテストは壊れない。
func _banks() -> Dictionary:
	return {
		MedalSoundPicker.Layer.SINGLE: ["one_a", "one_b", "one_c"],
		MedalSoundPicker.Layer.FEW: ["few_a", "few_b"],
		MedalSoundPicker.Layer.MANY: ["many_a", "many_b", "many_c"],
	}


func _picker(seed_value: int = 20260916) -> MedalSoundPicker:
	return MedalSoundPicker.new(_banks(), seed_value)


# --- 系統の切り替わり ---


func test_a_single_medal_uses_the_single_layer() -> void:
	assert_int(MedalSoundPicker.layer_for(1)).is_equal(MedalSoundPicker.Layer.SINGLE)


func test_layer_boundaries() -> void:
	# 境界: 数枚の下限の 1 つ手前 / ちょうど
	assert_int(MedalSoundPicker.layer_for(MedalSoundPicker.FEW_MIN - 1)).is_equal(
		MedalSoundPicker.Layer.SINGLE
	)
	assert_int(MedalSoundPicker.layer_for(MedalSoundPicker.FEW_MIN)).is_equal(
		MedalSoundPicker.Layer.FEW
	)
	# 境界: 大量の下限の 1 つ手前 / ちょうど
	assert_int(MedalSoundPicker.layer_for(MedalSoundPicker.MANY_MIN - 1)).is_equal(
		MedalSoundPicker.Layer.FEW
	)
	assert_int(MedalSoundPicker.layer_for(MedalSoundPicker.MANY_MIN)).is_equal(
		MedalSoundPicker.Layer.MANY
	)


func test_a_huge_pile_stays_in_the_many_layer() -> void:
	assert_int(MedalSoundPicker.layer_for(500)).is_equal(MedalSoundPicker.Layer.MANY)


func test_zero_and_negative_fall_back_to_single() -> void:
	# 呼び出し側の数え間違いで音が消えるより、1 枚ぶん鳴るほうがまし。
	assert_int(MedalSoundPicker.layer_for(0)).is_equal(MedalSoundPicker.Layer.SINGLE)
	assert_int(MedalSoundPicker.layer_for(-3)).is_equal(MedalSoundPicker.Layer.SINGLE)


# --- 選ばれる音 ---


func test_pick_returns_a_sound_from_the_matching_layer() -> void:
	var picker := _picker()
	assert_bool(picker.pick(1).begins_with("one_")).is_true()
	assert_bool(picker.pick(3).begins_with("few_")).is_true()
	assert_bool(picker.pick(20).begins_with("many_")).is_true()


func test_the_same_sound_never_plays_twice_in_a_row() -> void:
	# 設計書 §11 の要求。同じサンプルが続くと即座に嘘だとバレる。
	var picker := _picker()
	var previous := ""
	for i in 200:
		var current := picker.pick(1)
		assert_str(current).override_failure_message("%d 回目で %s が連続した" % [i, current]).is_not_equal(
			previous
		)
		previous = current


func test_avoidance_is_per_layer_not_global() -> void:
	# 系統をまたぐときは直前の音と同じか比べない(そもそも別の音源表)。
	var picker := _picker()
	for i in 50:
		assert_bool(picker.pick(1).begins_with("one_")).is_true()
		assert_bool(picker.pick(10).begins_with("many_")).is_true()


func test_a_single_sound_bank_keeps_working() -> void:
	# 音源が 1 つしかない系統では「連続させない」を満たせない。
	# 無限ループに落ちず、その 1 つを返すこと。
	var picker := MedalSoundPicker.new({MedalSoundPicker.Layer.SINGLE: ["only"]}, 1)
	assert_str(picker.pick(1)).is_equal("only")
	assert_str(picker.pick(1)).is_equal("only")


func test_an_empty_bank_returns_nothing_instead_of_crashing() -> void:
	var picker := MedalSoundPicker.new({MedalSoundPicker.Layer.SINGLE: []}, 1)
	assert_str(picker.pick(1)).is_empty()


func test_a_missing_bank_returns_nothing() -> void:
	var picker := MedalSoundPicker.new({}, 1)
	assert_str(picker.pick(1)).is_empty()


# --- 決定性 ---


func test_the_same_seed_gives_the_same_sequence() -> void:
	var first := _collect(_picker(), 60)
	var second := _collect(_picker(), 60)
	assert_array(first).is_equal(second)


func test_a_different_seed_gives_a_different_sequence() -> void:
	var first := _collect(_picker(20260916), 60)
	var second := _collect(_picker(20260917), 60)
	assert_array(first).is_not_equal(second)


# --- 実物の音源 ---


func test_the_shipped_assets_cover_every_layer() -> void:
	# docs/audio-credits.md の対応表どおりに置かれているか。
	# 素材を入れ替えても、系統が空になったらここで気づける。
	var picker := MedalSoundPicker.from_assets()
	for layer in [
		MedalSoundPicker.Layer.SINGLE, MedalSoundPicker.Layer.FEW, MedalSoundPicker.Layer.MANY
	]:
		var bank: Array = picker.bank(layer)
		(
			assert_int(bank.size())
			. override_failure_message(
				"系統 %d の音源が %d 個。2 個以上ないと『連続させない』を満たせない" % [layer, bank.size()]
			)
			. is_greater_equal(2)
		)


func test_shipped_sounds_actually_load() -> void:
	var picker := MedalSoundPicker.from_assets()
	var path := picker.pick(1)
	assert_str(path).is_not_empty()
	assert_object(load(path)).is_not_null()


# --- ヘルパー ---


func _collect(picker: MedalSoundPicker, count: int) -> Array[String]:
	var picked: Array[String] = []
	for i in count:
		picked.append(picker.pick(1 if i % 3 == 0 else (3 if i % 3 == 1 else 12)))
	return picked
