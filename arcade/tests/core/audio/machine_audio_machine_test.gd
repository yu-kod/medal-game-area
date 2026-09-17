extends GdUnitTestSuite

## 台の音のうち、衝突以外のもの: 払い出しトレイ、駆動音、台への接続。
##
## 盤面の衝突の音は machine_audio_test.gd。

const SOURCE_A := 1001
const AT := Vector3(0.5, 0.0, -1.0)


func _audio() -> MachineAudio:
	var audio: MachineAudio = auto_free(MachineAudio.new())
	add_child(audio)
	return audio


func _listen(audio: MachineAudio) -> Array:
	var heard: Array = []
	audio.sound_requested.connect(
		func(path: String, at: Vector3, volume_db: float, pitch_scale: float) -> void:
			heard.append({"path": path, "at": at, "volume_db": volume_db, "pitch": pitch_scale})
	)
	return heard


# --- 払い出しトレイ ---


func test_payout_uses_the_metal_bank() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	audio.note_payout(1)
	audio._process(MachineAudio.TRAY_BATCH_SEC)

	assert_str(heard[0]["path"]).contains("impactMetal")


func test_a_burst_of_payout_sounds_heavier() -> void:
	var audio := _audio()
	var heard := _listen(audio)

	for i in 10:
		audio.note_payout(1)
	audio._process(MachineAudio.TRAY_BATCH_SEC)

	assert_str(heard[0]["path"]).contains("heavy")


# --- 駆動音 ---


func test_motor_is_silent_until_started() -> void:
	assert_bool(_audio().motor_playing()).is_false()


func test_motor_runs_and_stops() -> void:
	var audio := _audio()
	audio.start_motor()
	assert_bool(audio.motor_playing()).is_true()
	audio.stop_motor()
	assert_bool(audio.motor_playing()).is_false()


func test_motor_loops() -> void:
	var audio := _audio()
	audio.start_motor()
	assert_bool(audio.motor_loops()).is_true()


# --- 台への接続 ---


func test_attach_listens_to_strikes_and_payouts_only() -> void:
	# 投入・横穴のイベントで代わりに鳴らすのはやめた。どちらも衝突として実際に聞こえる。
	var station := _station()
	var audio := _audio()
	audio.attach(station)

	assert_bool(station.pool.medal_struck.is_connected(audio._on_medal_struck)).is_true()
	assert_bool(station.medal_paid.is_connected(audio._on_medal_paid)).is_true()


func test_pool_strikes_reach_the_speaker() -> void:
	var station := _station()
	var audio := _audio()
	var heard := _listen(audio)
	audio.attach(station)

	station.pool.medal_struck.emit(6.0, AT, SOURCE_A)
	audio._process(0.016)

	assert_int(heard.size()).is_equal(1)


# --- ヘルパー ---


func _station() -> StationStub:
	var station: StationStub = auto_free(StationStub.new())
	station.pool = auto_free(PoolStub.new())
	return station


class StationStub:
	extends Node

	signal medal_paid

	var pool: PoolStub


class PoolStub:
	extends Node

	signal medal_struck(approach: float, at: Vector3, source_id: int)
