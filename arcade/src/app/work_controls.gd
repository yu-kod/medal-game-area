class_name WorkControls
extends Node

## 検証用の「働く」キー。`--debug` のときだけ置く。
##
## 本番の画面(#5 の残り)ができるまで、作業の間隔と 1 日の上限を
## 手で確かめて調整するためのもの。
##
## 台の操作(MachineControls)には混ぜない。あちらは「台に対してできること」だけを持つ。

const WORK_KEY := KEY_W

var wallet: PlayerWallet
var shift: WorkShift
## 日付を決める壁時計。テストで差し替えられるように外に出してある。
var clock: Callable
## 作業の間隔を測る、単調に進む時計(秒)。
var steady_clock: Callable


static func create(target_wallet: PlayerWallet, target_shift: WorkShift) -> WorkControls:
	var controls := WorkControls.new()
	controls.name = "WorkControls"
	controls.wallet = target_wallet
	controls.shift = target_shift
	controls.clock = Time.get_unix_time_from_system
	controls.steady_clock = func() -> float: return Time.get_ticks_msec() / 1000.0
	return controls


## いまの日本時間などの時差(秒)。日付の境目をその土地の 0 時に合わせる。
##
## Windows では bias に夏時間が含まれないので、夏時間のある地域では境目が 1 時間ずれる。
## 日本には夏時間が無いので、いまは気にしない。
static func local_utc_offset_sec() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func _unhandled_input(event: InputEvent) -> void:
	# キーリピートは弾く。押しっぱなしで自動連打にしない。
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != WORK_KEY:
		return
	shift.work(wallet, clock.call(), local_utc_offset_sec(), steady_clock.call())
