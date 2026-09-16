class_name DebugOverlay
extends CanvasLayer

## Phase 0 の挙動確認用に、台の内部状態を画面へ出すだけのオーバーレイ。
##
## 設計書 1章が排除している「演出」ではなく検証用の計器なので、
## `--hud` を付けたときだけ現れる。製品のシーンには絶対に載せない。

## 文字の基準位置。ツリー投入前に offset で置いた場合、実測で 25px ほど
## 上にずれて描画されるため、上端で切れないよう余裕を持たせてある。
const TEXT_ORIGIN := Vector2(24.0, 56.0)

var machine: PusherMachine

var _label: Label
var _elapsed := 0.0


## ラベルはツリーに入る前にここで組む。_ready() 内で add_child すると描画されない。
static func create(target: PusherMachine) -> DebugOverlay:
	var overlay := DebugOverlay.new()
	overlay.name = "DebugOverlay"
	overlay.machine = target

	var label := Label.new()
	label.name = "Readout"
	label.offset_left = TEXT_ORIGIN.x
	label.offset_top = TEXT_ORIGIN.y
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 8)
	overlay.add_child(label)
	overlay._label = label

	return overlay


func _process(delta: float) -> void:
	_elapsed += delta
	_label.text = (
		"%.0f 秒 / 場のメダル %d 枚 / 物理 %d Hz / 払い出し %d 枚 / サイド落下 %d 枚"
		% [
			_elapsed,
			machine.active_count(),
			Engine.physics_ticks_per_second,
			machine.payout_count,
			machine.side_loss_count,
		]
	)
