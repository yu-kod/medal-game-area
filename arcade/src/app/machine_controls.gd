class_name MachineControls
extends Node

## 台の操作。入力を台の内部に持ち込まないための薄い層。
##
## 実機の操作は 2 つしかない。左の口に入れる、右の口に入れる。
## 払い出しは機械が数えてクレジットに乗せるので、拾う操作は無い。
## 投入位置を狙うつまみは無い ── 口は左右の 2 つに固定されていて、
## 選べるのは「どちらの口か」と「プッシャーのどの位相で入れるか」だけ。
## 説明 UI は出さない(設計書 1 章)。目の前の物を触れば分かる。
##
## 店内移動(Phase 3)が入ったら、いま操作している台を差し替えるだけで済む。

var machine: PusherIsland

## 直前に使った口。スペースキーはこちらに入れる。
var _last_side := 1.0


static func create(target: PusherIsland) -> MachineControls:
	var controls := MachineControls.new()
	controls.name = "MachineControls"
	controls.machine = target
	return controls


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# 画面の左半分を押したら左の口、右半分なら右の口。
			# 台に映っている投入口の位置と画面上の位置が一致する。
			var center := get_viewport().get_visible_rect().size.x * 0.5
			_insert(-1.0 if event.position.x < center else 1.0)
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_A, KEY_LEFT:
			_insert(-1.0)
		KEY_D, KEY_RIGHT:
			_insert(1.0)
		KEY_SPACE:
			_insert(_last_side)


func _insert(side: float) -> void:
	_last_side = side
	machine.insert_medal(side)
