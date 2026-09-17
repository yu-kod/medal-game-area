class_name WorkShift
extends RefCounted

## クリッカー。現金を稼ぐ唯一の手段(設計書 §6.3)。
##
## > 意図的に退屈な作業として設計する。楽しくしてはいけない。
##
## 楽しいと、メダルゲームで遊ぶ理由が消える。ここは「遊ぶための原資を、
## 時間を払って得る」手続きであって、それ自体がゲームになってはいけない。
##
## 経済を守る制約が 3 つあり、どれも親切心で外されやすいのでテストで固定してある。
##
## - **作業には間隔がある。** 連打で時給を上げられると「1時間の労働 ≒ 10分の遊び」
##   (§6.4)という重さが消える。稼ぎは叩いた回数ではなく、費やした時間で決まる
## - **1 日の上限がある(シフト制)。** 日付が変わると戻る。最後に叩いてから 24 時間ではない
## - **放置しても何も起きない(オフライン報酬なし)。** 入れ忘れではなく、入れないのが仕様
##
## 時刻はすべて外から渡す。日付の絡む挙動を決定的にテストするため。

## 時給換算。設計書 §6.3 「約 1,100 円」。**調整はここから。**
const HOURLY_WAGE_YEN := 1100
## 1 回の作業で得る額。
const YEN_PER_TASK := 1
## 次の作業を受け付けるまでの秒数。時給と 1 回の額から決まる(約 3.27 秒)。
const TASK_INTERVAL_SEC := 3600.0 * YEN_PER_TASK / HOURLY_WAGE_YEN
## 1 日のシフトの長さ。
##
## 1 日働けば 1200 円の段(設計書 §6.2 の核心)に手が届き、
## 最上段の 5000 円には届かない長さにしてある。work_shift_test.gd が両方を見張る。
const SHIFT_HOURS := 3
## 1 日に稼げる上限。
const DAILY_CAP_YEN := HOURLY_WAGE_YEN * SHIFT_HOURS

const SECONDS_PER_DAY := 86400
## 浮動小数の足し算で「ちょうど間隔ぶん」が僅かに足りなくなるのを吸収する。
## 1 ミリ秒はプレイヤーには区別できない。
const PACE_TOLERANCE_SEC := 0.001

## 今日の残り(円)。
var remaining := DAILY_CAP_YEN
## remaining がどの日のものか。day_of() の値。0 はまだ働いていない。
var work_day := 0

## 最後に稼いだ時刻。**単調に進む時計**で持つ(壁時計ではない)。
var _last_task_steady := -1.0


## その時刻が属する日。time zone のぶんずらしてから日で割る。
##
## シフト制なので日付で区切る。最後に叩いてから 24 時間、にはしない。
## それだとプレイヤーが前回の時刻を覚えていないと次に働ける時刻が分からない。
static func day_of(now_unix: float, utc_offset_sec := 0) -> int:
	return floori((now_unix + utc_offset_sec) / SECONDS_PER_DAY)


## セーブから復元する。書き換えられていても上限を超えては戻さない。
static func from_state(state: PlayerState) -> WorkShift:
	var shift := WorkShift.new()
	shift.work_day = state.daily_work_date
	# 0 日目(未就労)なら次に叩いた日に満タンで始まるので、残りの値は使わない。
	if shift.work_day > 0:
		shift.remaining = mini(state.daily_work_remaining, DAILY_CAP_YEN)
	return shift


func write_to(state: PlayerState) -> void:
	state.daily_work_remaining = remaining
	state.daily_work_date = work_day


## 1 回働く。得た額を返す(稼げなかったら 0)。
##
## 時計を 2 つ受け取る。
## - now_unix: 壁時計。**日付を決めるためだけ**に使う
## - steady_sec: 起動からの経過秒など、単調に進む時計。**作業の間隔**に使う。
##   省略すると now_unix で代用する(テストで 1 本の時計だけ回すとき)
##
## 間隔を壁時計で測ると、時計を巻き戻すたびに 1 回ぶん早く稼げてしまう。
##
## 稼げなかった呼び出しでも日付の繰り上げは起きるが、それは保存しない。
## 保存は現金が動いたときだけで、読み直せば同じ繰り上げがもう一度起きるだけなので害は無い。
func work(wallet: PlayerWallet, now_unix: float, utc_offset_sec := 0, steady_sec := -1.0) -> int:
	var steady := steady_sec if steady_sec >= 0.0 else now_unix
	_roll_day(now_unix, utc_offset_sec)
	if _too_soon(steady):
		return 0
	if remaining <= 0:
		return 0
	var pay := mini(YEN_PER_TASK, remaining)
	# 現金を足すと cash_changed 経由で保存が走る。残りを先に減らしておかないと、
	# 減る前の残りが保存されてしまう。
	remaining -= pay
	_last_task_steady = steady
	wallet.add_cash(pay)
	return pay


## 今日あと何円稼げるか。読むだけで状態は変えない。
func remaining_today(now_unix: float, utc_offset_sec := 0) -> int:
	if day_of(now_unix, utc_offset_sec) > work_day:
		return DAILY_CAP_YEN
	return remaining


## 日付が進んでいたらシフトを満タンに戻す。
##
## 時計が巻き戻っていたら上限は戻さない。戻すと、日付をいじるだけで上限が復活する。
##
## ただし記録の日付が 2 日以上先にある場合は、日付だけを今日に引き戻す(残りはそのまま)。
## 時計が一時的に数年先を指していた・セーブが壊れていた、というときに、
## その未来の日が来るまで働けなくなるのを防ぐ。1 日ぶんの余裕は時差のある移動のため。
##
## この引き戻しには代償がある。時計を 2 日以上戻してから元に戻すと、上限が 1 回戻る。
## 一人で遊ぶゲームで時計を手でいじるのは自分をだますだけなので、
## 正直なプレイヤーが締め出されないほうを取った。
func _roll_day(now_unix: float, utc_offset_sec: int) -> void:
	var today := day_of(now_unix, utc_offset_sec)
	if today > work_day:
		work_day = today
		remaining = DAILY_CAP_YEN
	elif work_day > today + 1:
		work_day = today


func _too_soon(steady: float) -> bool:
	if _last_task_steady < 0.0 or steady < _last_task_steady:
		return false
	return steady - _last_task_steady < TASK_INTERVAL_SEC - PACE_TOLERANCE_SEC
