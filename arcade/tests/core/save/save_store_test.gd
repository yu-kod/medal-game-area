extends GdUnitTestSuite

## セーブファイルの読み書き。
##
## 読むのは**前回の自分が書いたとは限らないファイル**。壊れていても、
## 途中で切れていても、人が手で書き換えていても、起動できなくならないこと。

const TEST_PATH := "user://test_save_store.json"


func after_test() -> void:
	# 実ファイルを使うので毎回片付ける。
	for path in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_raw(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# --- 往復 ---


func test_a_saved_state_comes_back() -> void:
	var state := PlayerState.new()
	state.cash = 4200
	state.stamp_visit(1_700_000_000)

	assert_bool(SaveStore.save(state, TEST_PATH)).is_true()
	var loaded := SaveStore.load_state(TEST_PATH)

	assert_int(loaded.cash).is_equal(4200)
	assert_int(loaded.stored_last_visit).is_equal(1_700_000_000)


func test_saving_twice_overwrites_rather_than_appends() -> void:
	var first := PlayerState.new()
	first.cash = 100
	SaveStore.save(first, TEST_PATH)

	var second := PlayerState.new()
	second.cash = 200
	SaveStore.save(second, TEST_PATH)

	assert_int(SaveStore.load_state(TEST_PATH).cash).is_equal(200)


func test_no_temporary_file_is_left_behind() -> void:
	# 書き込みは .tmp に出してから置き換える。片付け漏れがあると次回それを読む。
	SaveStore.save(PlayerState.new(), TEST_PATH)
	assert_bool(FileAccess.file_exists(TEST_PATH + ".tmp")).is_false()


# --- 壊れた入力 ---


func test_a_missing_file_starts_from_defaults() -> void:
	# 初回起動。落ちずに初期状態で始まる。
	var state := SaveStore.load_state("user://definitely_not_here.json")
	assert_object(state).is_not_null()
	assert_int(state.cash).is_equal(0)


func test_garbage_starts_from_defaults() -> void:
	_write_raw("this is not json at all {{{")
	assert_int(SaveStore.load_state(TEST_PATH).cash).is_equal(0)


func test_an_empty_file_starts_from_defaults() -> void:
	_write_raw("")
	assert_int(SaveStore.load_state(TEST_PATH).cash).is_equal(0)


func test_a_truncated_file_starts_from_defaults() -> void:
	# 書き込み中に電源が落ちた形。
	_write_raw('{"version": 1, "cash": 12')
	assert_int(SaveStore.load_state(TEST_PATH).cash).is_equal(0)


func test_valid_json_that_is_not_an_object_starts_from_defaults() -> void:
	_write_raw("[1, 2, 3]")
	assert_int(SaveStore.load_state(TEST_PATH).cash).is_equal(0)
	_write_raw('"just a string"')
	assert_int(SaveStore.load_state(TEST_PATH).cash).is_equal(0)


func test_a_hand_edited_file_cannot_grant_medals() -> void:
	# 経済の前提(設計書 §6.1 / §8)はセーブ経由でも破れない。
	_write_raw('{"version": 1, "cash": 0, "medals": 9999, "stored_medals": 9999}')
	var state := SaveStore.load_state(TEST_PATH)
	assert_int(state.cash).is_equal(0)
	assert_bool(state.to_dict().has("medals")).is_false()


func test_a_readable_file_survives_a_bad_one() -> void:
	# 壊れたファイルを読んだあとでも、書き直せば普通に戻る。
	_write_raw("broken")
	SaveStore.load_state(TEST_PATH)

	var state := PlayerState.new()
	state.cash = 50
	assert_bool(SaveStore.save(state, TEST_PATH)).is_true()
	assert_int(SaveStore.load_state(TEST_PATH).cash).is_equal(50)
