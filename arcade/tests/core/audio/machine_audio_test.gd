extends GdUnitTestSuite

## 台の音を鳴らすところ。
##
## メダルは 1 枚ずつ signal で飛んでくるが、山が崩れたときは同じ瞬間に何枚も来る。
## そのまま 1 枚ずつ鳴らすと機関銃になるので、短い窓でまとめて 1 回にする。
## その「まとめ」と「系統の選択」がここのテスト対象。
##
## 実際に鳴った音が良いかどうかは耳の領域なのでテストしない。


func _audio() -> MachineAudio:
	var audio: MachineAudio = auto_free(MachineAudio.new())
	add_child(audio)
	return audio


## 鳴らす要求を拾う。実際の再生は待たずに、何が選ばれたかだけ見る。
func _listen(audio: MachineAudio) -> Array[String]:
	var heard: Array[String] = []
	audio.sound_requested.connect(func(path: String) -> void: heard.append(path))
	return heard


# --- まとめ ---


func test_nothing_plays_while_nothing_happens() -> void:
	var audio := _audio()
	var heard := _listen(audio)
	audio._process(1.0)
	assert_array(heard).is_empty()


func test_one_medal_makes_one_sound() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_medals(1)
	audio._process(MachineAudio.BATCH_SEC)

	assert_int(heard.size()).is_equal(1)


func test_medals_in_the_same_window_collapse_into_one_sound() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	# 山が崩れた瞬間。1 枚ずつ 10 回飛んでくる。
	for i in 10:
		audio.note_medals(1)
	audio._process(MachineAudio.BATCH_SEC)

	# 10 回鳴らすと機関銃になる。1 回にまとめる。
	(
		assert_int(heard.size())
		. override_failure_message("%d 回鳴った。同じ窓の中は 1 回にまとめること" % heard.size())
		. is_equal(1)
	)


func test_a_pile_collapse_uses_the_many_layer() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	for i in MedalSoundPicker.MANY_MIN:
		audio.note_medals(1)
	audio._process(MachineAudio.BATCH_SEC)

	(
		assert_bool(heard[0].contains("/medal/many/"))
		. override_failure_message("大量のはずが %s を選んだ" % heard[0])
		. is_true()
	)


func test_a_single_medal_uses_the_single_layer() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_medals(1)
	audio._process(MachineAudio.BATCH_SEC)

	assert_bool(heard[0].contains("/medal/single/")).is_true()


func test_nothing_plays_before_the_window_closes() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_medals(1)
	audio._process(MachineAudio.BATCH_SEC * 0.5)

	assert_array(heard).is_empty()


func test_a_new_batch_starts_after_the_previous_one_fires() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_medals(1)
	audio._process(MachineAudio.BATCH_SEC)
	audio.note_medals(1)
	audio._process(MachineAudio.BATCH_SEC)

	assert_int(heard.size()).is_equal(2)


func test_the_counter_resets_between_batches() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	# 1 回目は大量
	for i in 10:
		audio.note_medals(1)
	audio._process(MachineAudio.BATCH_SEC)
	# 2 回目は 1 枚だけ。前の枚数が残っていると大量のまま鳴る。
	audio.note_medals(1)
	audio._process(MachineAudio.BATCH_SEC)

	(
		assert_bool(heard[1].contains("/medal/single/"))
		. override_failure_message("2 回目が %s。前の窓の枚数が残っている" % heard[1])
		. is_true()
	)


# --- 払い出しトレイ ---


func test_payout_uses_the_metal_bank() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_payout(1)
	audio._process(MachineAudio.BATCH_SEC)

	(
		assert_bool(heard[0].contains("impactMetal"))
		. override_failure_message("トレイの音に %s を選んだ" % heard[0])
		. is_true()
	)


func test_payout_and_medals_are_counted_separately() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_medals(1)
	audio.note_payout(1)
	audio._process(MachineAudio.BATCH_SEC)

	# 盤面の音とトレイの音は別々に鳴る。片方に吸収されない。
	assert_int(heard.size()).is_equal(2)


func test_a_burst_of_payout_sounds_heavier() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	for i in 10:
		audio.note_payout(1)
	audio._process(MachineAudio.BATCH_SEC)

	(
		assert_bool(heard[0].contains("heavy"))
		. override_failure_message("大量の払い出しに %s を選んだ" % heard[0])
		. is_true()
	)


# --- 駆動音 ---


func test_motor_is_silent_until_started() -> void:
	var audio := _audio()
	assert_bool(audio.motor_playing()).is_false()


func test_motor_runs_once_started() -> void:
	var audio := _audio()
	audio.start_motor()
	assert_bool(audio.motor_playing()).is_true()


func test_motor_stops() -> void:
	var audio := _audio()
	audio.start_motor()
	audio.stop_motor()
	assert_bool(audio.motor_playing()).is_false()


func test_motor_loops() -> void:
	# 止まると台が死んだように聞こえる。ループ指定が要る。
	var audio := _audio()
	audio.start_motor()
	(
		assert_bool(audio.motor_loops())
		. override_failure_message("駆動音がループしない。1 周で止まると台が死んで聞こえる")
		. is_true()
	)


# --- 台への接続 ---


func test_attach_connects_to_the_station_signals() -> void:
	# 台をまるごと組むと重いので、signal を持つ最小の代役で確かめる。
	var station: StationStub = auto_free(StationStub.new())
	var audio := _audio()
	audio.attach(station)

	assert_bool(station.medal_paid.is_connected(audio._on_medal_paid)).is_true()
	assert_bool(station.medal_lost.is_connected(audio._on_medal_lost)).is_true()
	assert_bool(station.medal_inserted.is_connected(audio._on_medal_inserted)).is_true()


func test_station_events_reach_the_batcher() -> void:
	var station: StationStub = auto_free(StationStub.new())
	var audio := _audio()
	var heard := _listen(audio)
	audio.attach(station)

	station.medal_lost.emit()
	audio._process(MachineAudio.BATCH_SEC)

	assert_int(heard.size()).is_equal(1)


class StationStub:
	extends Node

	signal medal_paid
	signal medal_lost
	signal medal_inserted
