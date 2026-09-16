class_name MachineAudio
extends Node3D

## 台が出す音をまとめて受け持つ。
##
## メダルは 1 枚ずつ signal で飛んでくるが、山が崩れた瞬間には同じフレームに
## 何枚も来る。そのまま 1 枚ずつ鳴らすと機関銃になるので、短い窓でまとめて
## 1 回にし、**まとめた枚数で音の系統を選ぶ**(設計書 §11 の 3 系統)。
##
## 音の良し悪しは耳で決める領域。ここが持つのは「いつ・どの系統を」だけで、
## どのファイルが良い音かの判断は持たない。

## 鳴らす音が決まった。実際の再生とは別に出しているので、
## 何が選ばれたかをテストから観測できる。
signal sound_requested(path: String)

## この窓の中に来たメダルを 1 回の音にまとめる。
##
## 長くすると山崩れが 1 発の音に潰れて迫力が出ず、
## 短くすると 1 枚ずつ鳴って機関銃になる。実機の聞こえ方に合わせて詰める値。
const BATCH_SEC := 0.12

## 同時に鳴らせる数。これを超えたら古いものから使い回す。
const VOICE_COUNT := 8

const MOTOR_ASSET := "res://assets/audio/motor/machine_11.ogg"
## 駆動音は場に馴染ませる。前に出ると台がうるさくなる。
const MOTOR_DB := -18.0

var _medal_picker: MedalSoundPicker
var _tray_picker: MedalSoundPicker

var _pending_medals := 0
var _pending_payout := 0
var _timer := 0.0

var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0
var _motor: AudioStreamPlayer3D


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


## 台の signal につなぐ。台側は音のことを知らないままでいい。
func attach(station: Node) -> void:
	station.medal_paid.connect(_on_medal_paid)
	station.medal_lost.connect(_on_medal_lost)
	station.medal_inserted.connect(_on_medal_inserted)


## 盤面でメダルが動いた。窓が閉じるまで溜める。
func note_medals(count := 1) -> void:
	_pending_medals += count


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
	if _pending_medals == 0 and _pending_payout == 0:
		return
	_timer += delta
	if _timer < BATCH_SEC:
		return
	_flush()


## 溜まったぶんを鳴らして窓を開け直す。
func _flush() -> void:
	if _pending_medals > 0:
		_play(_medal_picker.pick(_pending_medals))
	if _pending_payout > 0:
		_play(_tray_picker.pick(_pending_payout))
	_pending_medals = 0
	_pending_payout = 0
	_timer = 0.0


func _play(path: String) -> void:
	if path.is_empty():
		return
	sound_requested.emit(path)
	if _voices.is_empty():
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = load(path)
	voice.play()


func _on_medal_paid() -> void:
	# 払い出しは盤面から落ちる音とトレイに当たる音の両方が鳴る。
	note_payout(1)


func _on_medal_lost() -> void:
	note_medals(1)


func _on_medal_inserted() -> void:
	note_medals(1)
