class_name DevHud
extends CanvasLayer

## 開発中に台の内部状態を見るための計器。
##
## 設計書 1 章が排除している「演出 UI」ではなく検証用の計器なので、
## `--debug` を付けたときだけ現れる。製品の画面には絶対に載せない。

const TEXT_ORIGIN := Vector2(24.0, 52.0)

var machine: PusherStation

var _label: Label
var _elapsed := 0.0
var _worst_frame := 0.0


## ラベルはツリーに入る前にここで組む。_ready() 内で add_child すると描画されない。
static func create(target: PusherStation) -> DevHud:
	var hud := DevHud.new()
	hud.name = "DevHud"
	hud.machine = target

	var label := Label.new()
	label.name = "Readout"
	label.offset_left = TEXT_ORIGIN.x
	label.offset_top = TEXT_ORIGIN.y
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 8)
	hud.add_child(label)
	hud._label = label

	return hud


func _process(delta: float) -> void:
	_elapsed += delta
	_worst_frame = maxf(_worst_frame, delta)
	# 成績は投入枚数で正規化する。時間あたりにすると、手で遊んだときの
	# 投入ペースの揺れと手を止めている時間が混ざって台の性質が読めなくなる。
	_label.text = (
		(
			"%.0f 秒 (物理 %.0f 秒 / 自動投入 %d 回)  fps %d (最悪 %.1f ms)\n"
			+ "場 %d 枚  手持ち %d 枚\n"
			+ "投入 %d  払い出し %d  サイド落下 %d  逸脱 %d\n"
			+ "払出率  通算 %.0f%%  直近%d枚 %.0f%%\n"
			+ "チェッカー %d  保留 %d  抽選当たり %d 枚(未払出 %d)"
		)
		% [
			_elapsed,
			machine.physics_seconds,
			machine.demo_fires,
			Engine.get_frames_per_second(),
			_worst_frame * 1000.0,
			machine.active_count(),
			machine.wallet.medals(),
			machine.insert_count,
			machine.payout_count,
			machine.side_loss_count,
			machine.void_count,
			machine.lifetime_payout_ratio() * 100.0,
			PusherStation.RTP_WINDOW,
			machine.recent_payout_ratio() * 100.0,
			machine.chucker_count,
			machine.roulette.stock if machine.roulette != null else 0,
			machine.lottery_reward,
			machine.hopper.pending() if machine.hopper != null else 0,
		]
	)
