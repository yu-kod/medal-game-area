extends GdUnitTestSuite

## 検証用の「働く」キー。
##
## 本番の画面ができるまで、ペースと上限を手で確かめるためのもの。
## 台の操作(MachineControls)とは混ぜない。


func _key(keycode: Key, pressed := true, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event


func _controls(wallet: PlayerWallet, shift: WorkShift) -> WorkControls:
	var controls: WorkControls = auto_free(WorkControls.create(wallet, shift))
	add_child(controls)
	return controls


func test_the_work_key_earns_a_task() -> void:
	var wallet := PlayerWallet.new()
	var controls := _controls(wallet, WorkShift.new())

	controls._unhandled_input(_key(WorkControls.WORK_KEY))

	assert_int(wallet.cash()).is_equal(WorkShift.YEN_PER_TASK)


func test_holding_the_key_does_not_repeat() -> void:
	# キーリピートで自動連打にならないこと。間隔の制約とは別に、入力側でも弾く。
	var wallet := PlayerWallet.new()
	var controls := _controls(wallet, WorkShift.new())

	controls._unhandled_input(_key(WorkControls.WORK_KEY))
	controls._unhandled_input(_key(WorkControls.WORK_KEY, true, true))

	assert_int(wallet.cash()).is_equal(WorkShift.YEN_PER_TASK)


func test_other_keys_do_nothing() -> void:
	var wallet := PlayerWallet.new()
	var controls := _controls(wallet, WorkShift.new())

	controls._unhandled_input(_key(KEY_A))
	controls._unhandled_input(_key(KEY_SPACE))
	controls._unhandled_input(_key(WorkControls.WORK_KEY, false))

	assert_int(wallet.cash()).is_equal(0)
