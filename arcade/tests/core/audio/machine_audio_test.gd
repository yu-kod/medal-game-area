extends GdUnitTestSuite

## 台の音を鳴らすところ。
##
## 盤面の音は**衝突 1 回につき 1 回**鳴らす。まとめない。
## 山が崩れたときに何発も続けて聞こえること自体が本物らしさなので、
## 窓でまとめて 1 発にすると潰れてしまう。
##
## 実際に鳴った音が良いかどうかは耳の領域なのでテストしない。
## 見るのは、いつ・どこで・どの音量と音程で鳴らすかだけ。

const SOURCE_A := 1001
const SOURCE_B := 1002
const AT := Vector3(0.5, 0.0, -1.0)


func _audio() -> MachineAudio:
	var audio: MachineAudio = auto_free(MachineAudio.new())
	add_child(audio)
	return audio


## 鳴らす要求を拾う。実際の再生は待たずに、何が選ばれたかだけ見る。
func _listen(audio: MachineAudio) -> Array:
	var heard: Array = []
	audio.sound_requested.connect(
		func(path: String, at: Vector3, volume_db: float, pitch_scale: float) -> void:
			heard.append({"path": path, "at": at, "volume_db": volume_db, "pitch": pitch_scale})
	)
	return heard


# --- 衝突 1 回 ---


func test_nothing_plays_while_nothing_happens() -> void:
	var audio := _audio()
	var heard := _listen(audio)
	audio._process(1.0)
	assert_array(heard).is_empty()


func test_a_strike_plays_one_coin_hit() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_strike(6.0, AT, SOURCE_A, 0)
	audio._process(0.016)

	assert_int(heard.size()).is_equal(1)
	assert_str(heard[0]["path"]).contains("/medal/single/")


func test_the_strike_plays_where_it_happened() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_strike(6.0, AT, SOURCE_A, 0)
	audio._process(0.016)

	assert_vector(heard[0]["at"]).is_equal(AT)


func test_the_volume_comes_from_the_strike() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_strike(3.0, AT, SOURCE_A, 0)
	audio._process(0.016)

	assert_float(heard[0]["volume_db"]).is_equal_approx(MedalStrike.volume_db(3.0), 0.001)


func test_the_pitch_varies_within_the_jitter() -> void:
	# 1 つの音源を、音程を少しずつ変えて鳴らす。同じ音の繰り返しに聞こえないように。
	var audio := _audio()
	var heard := _listen(audio)

	for i in 30:
		audio.note_strike(6.0, AT, SOURCE_A + i, 0)
		audio._process(0.016)

	var pitches := {}
	for entry in heard:
		assert_float(entry["pitch"]).is_between(
			1.0 - MachineAudio.PITCH_JITTER, 1.0 + MachineAudio.PITCH_JITTER
		)
		pitches[snappedf(entry["pitch"], 0.001)] = true
	assert_int(pitches.size()).override_failure_message("音程が変わっていない").is_greater(10)


func test_the_same_seed_gives_the_same_pitches() -> void:
	# 乱数は種を指定して持つ(グローバルの randf は使わない)。
	var first := _pitches(_audio())
	var second := _pitches(_audio())
	assert_array(first).is_equal(second)


func test_an_inaudible_strike_is_ignored() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_strike(MedalStrike.AUDIBLE_APPROACH * 0.5, AT, SOURCE_A, 0)
	audio._process(0.016)

	assert_array(heard).is_empty()


# --- 連続して届く同じ衝突 ---


func test_one_impact_reported_over_several_steps_plays_once() -> void:
	# 1 回の衝突は 2〜3 物理ステップにまたがって届く(1 ステップ ≒ 5.6 ms)。
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_strike(9.2, AT, SOURCE_A, 0)
	audio.note_strike(3.6, AT, SOURCE_A, 6)
	audio.note_strike(12.3, AT, SOURCE_A, 11)
	audio._process(0.016)

	assert_int(heard.size()).is_equal(1)


func test_the_same_medal_can_strike_again_after_the_rest() -> void:
	# 跳ね返って、もう一度当たった。本物の跳ね返りは鳴らす。
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_strike(9.0, AT, SOURCE_A, 0)
	audio._process(0.016)
	audio.note_strike(4.0, AT, SOURCE_A, MachineAudio.PER_SOURCE_REST_MSEC)
	audio._process(0.016)

	assert_int(heard.size()).is_equal(2)


func test_different_medals_striking_together_all_play() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_strike(6.0, AT, SOURCE_A, 0)
	audio.note_strike(6.0, AT, SOURCE_B, 0)
	audio._process(0.016)

	assert_int(heard.size()).is_equal(2)


# --- 山が崩れたとき ---


func test_a_collapse_plays_the_loudest_hits_first() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	for i in MachineAudio.HITS_PER_FRAME + 3:
		audio.note_strike(2.0 + i, AT, SOURCE_A + i, 0)
	audio._process(0.016)

	var hits := heard.filter(_is_hit)
	assert_int(hits.size()).is_equal(MachineAudio.HITS_PER_FRAME)
	# 取りこぼしたのは静かなほう。いちばん大きい衝突は必ず鳴っている。
	var loudest := MedalStrike.volume_db(2.0 + MachineAudio.HITS_PER_FRAME + 2)
	var played_loudest := false
	for entry in hits:
		if is_equal_approx(entry["volume_db"], loudest):
			played_loudest = true
	assert_bool(played_loudest).is_true()


func test_hits_beyond_the_budget_become_one_rumble() -> void:
	# 同じフレームに鳴らしきれない衝突は捨てずに、数枚ぶん・大量ぶんの音 1 つにまとめる。
	var audio := _audio()
	var heard := _listen(audio)

	for i in MachineAudio.HITS_PER_FRAME + MedalSoundPicker.MANY_MIN:
		audio.note_strike(6.0, Vector3(i, 0, 0), SOURCE_A + i, 0)
	audio._process(0.016)

	var rumbles := heard.filter(
		func(entry: Dictionary) -> bool: return "/medal/many/" in entry["path"]
	)
	assert_int(rumbles.size()).is_equal(1)


func test_a_single_leftover_hit_does_not_rumble() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	for i in MachineAudio.HITS_PER_FRAME + 1:
		audio.note_strike(6.0, AT, SOURCE_A + i, 0)
	audio._process(0.016)

	assert_int(heard.size()).is_equal(MachineAudio.HITS_PER_FRAME)


func test_strikes_do_not_carry_over_to_the_next_frame() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_strike(6.0, AT, SOURCE_A, 0)
	audio._process(0.016)
	audio._process(0.016)

	assert_int(heard.size()).is_equal(1)


# --- ヘルパー ---


func _is_hit(entry: Dictionary) -> bool:
	return "/medal/single/" in entry["path"]


func _pitches(audio: MachineAudio) -> Array:
	var heard := _listen(audio)
	for i in 10:
		audio.note_strike(6.0, AT, SOURCE_A + i, 0)
		audio._process(0.016)
	var pitches: Array = []
	for entry in heard:
		pitches.append(entry["pitch"])
	return pitches
