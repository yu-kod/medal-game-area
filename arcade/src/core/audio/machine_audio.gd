class_name MachineAudio
extends Node3D

## 台が出す音をまとめて受け持つ。
##
## 盤面の音は**実際の衝突から**鳴らす(#27)。メダルが何かに当たるたびに、
## その位置で、その強さに応じた音量で、1 回鳴らす。
## 払い出しが上段に落ちる、上段から下段へ落ちる、メダル同士が当たる、は
## どれも落下検出を通らないので、イベントを代わりに使う方式では鳴らせなかった。
##
## 1 枚の音は 1 つの打音を、音程を少しずつ変えて鳴らす。同じ音の繰り返しに聞こえないように。
## 乱数は種を指定して持つ。`AudioStreamRandomizer` は種を指定できないので使わない。
##
## 音の良し悪しは耳で決める領域。ここが持つのは「いつ・どこで・どの強さで」だけ。

## 鳴らす音が決まった。実際の再生とは別に出しているので、
## 何が選ばれたかをテストから観測できる。
signal sound_requested(path: String, at: Vector3, volume_db: float, pitch_scale: float)

## 1 フレームに鳴らす衝突の数。これを超えたぶんは大きい順に残し、
## 残りは 1 つの「数枚・大量」の音にまとめる。
const HITS_PER_FRAME := 6
## 同じメダルからの報告は、この時間のあいだは 1 回として扱う。
##
## 1 回の衝突は 2〜3 物理ステップ(1 ステップ ≒ 5.6 ms)にまたがって届く。
## 本当の跳ね返りは実測で 90 ms 以上あとに来るので、それは別の音として鳴らす。
const PER_SOURCE_REST_MSEC := 40
## 音程のゆらぎ。1.0 を中心に上下この割合まで。
const PITCH_JITTER := 0.08
## 払い出しトレイの音をまとめる窓。トレイは落下検出の瞬間に場から外れるので、
## 衝突ではなく払い出しの数で鳴らす。
const TRAY_BATCH_SEC := 0.12

## 同時に鳴らせる数。これを超えたら古いものから使い回す。
const VOICE_COUNT := 16
const RANDOM_SEED := 20260917

const MOTOR_ASSET := "res://assets/audio/motor/machine_11.ogg"
## 駆動音は場に馴染ませる。前に出ると台がうるさくなる。
const MOTOR_DB := -18.0

var _medal_picker: MedalSoundPicker
var _tray_picker: MedalSoundPicker
var _rng := RandomNumberGenerator.new()

## このフレームに届いた衝突。{approach, at}
var _pending_strikes: Array[Dictionary] = []
## メダルごとに最後に受け付けた時刻(ミリ秒)。
var _last_strike_msec := {}

var _pending_payout := 0
var _tray_timer := 0.0

var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0
var _motor: AudioStreamPlayer3D


func _init() -> void:
	_rng.seed = RANDOM_SEED


func _ready() -> void:
	_medal_picker = MedalSoundPicker.from_assets()
	_tray_picker = MedalSoundPicker.from_tray_assets()

	for index in VOICE_COUNT:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Voice%d" % index
		add_child(voice)
		_voices.append(voice)

	_motor = AudioStreamPlayer3D.new()
	_motor.name = "Motor"
	_motor.volume_db = MOTOR_DB
	_motor.stream = load(MOTOR_ASSET)
	# 1 周で止まると台が死んだように聞こえる。
	if _motor.stream is AudioStreamOggVorbis:
		_motor.stream.loop = true
	add_child(_motor)


## 台につなぐ。台側は音のことを知らないままでいい。
##
## 投入や横穴への落下のイベントで代わりに鳴らすのはやめた。
## 投入したメダルは盤面に落ちて、横穴へ落ちるメダルは縁に当たって、衝突として鳴る。
func attach(station: Node) -> void:
	station.medal_paid.connect(_on_medal_paid)
	station.pool.medal_struck.connect(_on_medal_struck)


## メダルが何かに当たった。このフレームの終わりに鳴らす。
func note_strike(approach: float, at: Vector3, source_id: int, now_msec: int) -> void:
	if not MedalStrike.is_audible(approach):
		return
	if (
		_last_strike_msec.has(source_id)
		and now_msec - int(_last_strike_msec[source_id]) < PER_SOURCE_REST_MSEC
	):
		return
	_last_strike_msec[source_id] = now_msec
	_pending_strikes.append({"approach": approach, "at": at})


## 払い出し口からトレイへ落ちた。
func note_payout(count := 1) -> void:
	_pending_payout += count


func start_motor() -> void:
	if _motor != null and not _motor.playing:
		_motor.play()


func stop_motor() -> void:
	if _motor != null:
		_motor.stop()


func motor_playing() -> bool:
	return _motor != null and _motor.playing


func motor_loops() -> bool:
	return _motor != null and _motor.stream is AudioStreamOggVorbis and _motor.stream.loop


func _process(delta: float) -> void:
	_flush_strikes()
	_advance_tray(delta)


## このフレームの衝突を鳴らす。まとめない。
##
## 山が崩れて一度に来たときは大きい順に HITS_PER_FRAME まで鳴らし、
## 残りが 2 枚以上なら「数枚・大量」の音 1 つにまとめて、その重心で鳴らす。
func _flush_strikes() -> void:
	if _pending_strikes.is_empty():
		return
	_pending_strikes.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a["approach"] > b["approach"]
	)

	var played := mini(HITS_PER_FRAME, _pending_strikes.size())
	for index in played:
		var strike := _pending_strikes[index]
		_play(
			_medal_picker.pick(1),
			strike["at"],
			MedalStrike.volume_db(strike["approach"]),
			_jittered_pitch()
		)

	var leftover := _pending_strikes.size() - played
	if leftover >= MedalSoundPicker.FEW_MIN:
		var centroid := Vector3.ZERO
		for index in range(played, _pending_strikes.size()):
			centroid += _pending_strikes[index]["at"]
		centroid /= leftover
		_play(
			_medal_picker.pick(leftover),
			centroid,
			MedalStrike.volume_db(_pending_strikes[played]["approach"]),
			_jittered_pitch()
		)

	_pending_strikes.clear()


func _advance_tray(delta: float) -> void:
	if _pending_payout == 0:
		return
	_tray_timer += delta
	if _tray_timer < TRAY_BATCH_SEC:
		return
	_play(_tray_picker.pick(_pending_payout), global_position, 0.0, 1.0)
	_pending_payout = 0
	_tray_timer = 0.0


func _jittered_pitch() -> float:
	return _rng.randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)


func _play(path: String, at: Vector3, volume_db: float, pitch_scale: float) -> void:
	if path.is_empty():
		return
	sound_requested.emit(path, at, volume_db, pitch_scale)
	if _voices.is_empty():
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = load(path)
	voice.global_position = at
	voice.volume_db = volume_db
	voice.pitch_scale = pitch_scale
	voice.play()


func _on_medal_struck(approach: float, at: Vector3, source_id: int) -> void:
	note_strike(approach, at, source_id, Time.get_ticks_msec())


func _on_medal_paid() -> void:
	note_payout(1)
