extends GdUnitTestSuite

## 7 セグ表示の点灯パターンと、桁溢れ・ゼロ消灯の扱い。
##
## メッシュの寸法や見た目は対象外。「どの数字が読めるか」だけを見る。


func _display(digits: int) -> SevenSegment:
	return auto_free(SevenSegment.create(digits))


## 表示器が実際に出している内容を文字列として読む。消灯している桁は空白。
##
## 点灯パターンから数字へ引き直しているので、
## 「a が点いているか」ではなく「3 と読めるか」を assert できる。
func _read(display: SevenSegment) -> String:
	var text := ""
	for digit_index in display._segments.size():
		text += _digit_of(_lit_flags(display, digit_index))
	return text


func _lit_flags(display: SevenSegment, digit_index: int) -> Array:
	var on := SurfacePalette.segment_on()
	var meshes: Array = display._segments[digit_index]
	var flags := []
	for segment in 7:
		flags.append(meshes[segment].material_override == on)
	return flags


## 点灯パターンを 1 文字に直す。どの数字でもなければ空白(全消灯)か "?"。
func _digit_of(flags: Array) -> String:
	for digit in SevenSegment.PATTERNS.size():
		if SevenSegment.PATTERNS[digit] == flags:
			return str(digit)
	return " " if not flags.has(true) else "?"


# --- パターン表 ---


func test_patterns_cover_every_digit() -> void:
	assert_int(SevenSegment.PATTERNS.size()).is_equal(10)


func test_every_pattern_has_seven_segments() -> void:
	for digit in SevenSegment.PATTERNS.size():
		var pattern: Array = SevenSegment.PATTERNS[digit]
		(
			assert_int(pattern.size())
			. override_failure_message(
				"%d のパターンが %d 要素。a b c d e f g の 7 つに揃える" % [digit, pattern.size()]
			)
			. is_equal(7)
		)


func test_every_digit_looks_different() -> void:
	# コピペで同じ行が並ぶと、別の数字が同じ形で出てしまう。
	for digit in SevenSegment.PATTERNS.size():
		for other in range(digit + 1, SevenSegment.PATTERNS.size()):
			(
				assert_bool(SevenSegment.PATTERNS[digit] == SevenSegment.PATTERNS[other])
				. override_failure_message("%d と %d の点灯パターンが同じ" % [digit, other])
				. is_false()
			)


func test_known_shapes_are_right() -> void:
	# 添字は a b c d e f g。1 は右の 2 本、8 は全点灯、0 は中棒だけ消灯。
	assert_array(SevenSegment.PATTERNS[1]).is_equal([false, true, true, false, false, false, false])
	assert_array(SevenSegment.PATTERNS[8]).is_equal([true, true, true, true, true, true, true])
	assert_array(SevenSegment.PATTERNS[0]).is_equal([true, true, true, true, true, true, false])


# --- 表示 ---


func test_every_digit_is_readable_on_a_single_digit_display() -> void:
	var display := _display(1)
	for digit in 10:
		display.set_value(digit)
		(
			assert_str(_read(display))
			. override_failure_message("%d を表示させたのに %s と読めた" % [digit, _read(display)])
			. is_equal(str(digit))
		)


func test_leading_zeros_are_blanked() -> void:
	var display := _display(3)
	display.set_value(42)
	# 実機の計数器と同じで、上位の余ったゼロは光らせない。
	assert_str(_read(display)).is_equal(" 42")


func test_the_last_digit_shows_zero() -> void:
	var display := _display(3)
	display.set_value(0)
	# 全桁が消えると故障と区別がつかない。最下位の 0 だけは必ず出す。
	assert_str(_read(display)).is_equal("  0")


func test_all_digits_light_up_when_full() -> void:
	var display := _display(3)
	display.set_value(999)
	assert_str(_read(display)).is_equal("999")


# --- 境界 ---


func test_overflow_pegs_at_the_maximum() -> void:
	var display := _display(3)
	display.set_value(1234)
	# ラップアラウンドして "234" とは出さない。
	# 1000 枚が 000 と出ると「メダルが消えた」としか読めないため。
	(
		assert_str(_read(display))
		. override_failure_message("桁溢れが %s と表示された。頭打ちの 999 になるはず" % _read(display))
		. is_equal("999")
	)


func test_value_just_under_overflow_is_exact() -> void:
	var display := _display(3)
	display.set_value(998)
	assert_str(_read(display)).is_equal("998")


func test_negative_values_show_zero() -> void:
	var display := _display(3)
	display.set_value(-5)
	# 計数器なので負の表示は存在しない。
	assert_str(_read(display)).is_equal("  0")


func test_setting_the_same_value_twice_keeps_the_display() -> void:
	# set_value は同じ値なら早期 return する。表示が消えないことを確かめる。
	var display := _display(3)
	display.set_value(77)
	display.set_value(77)
	assert_str(_read(display)).is_equal(" 77")


func test_display_can_count_back_down() -> void:
	var display := _display(3)
	display.set_value(100)
	display.set_value(9)
	# 減ったときに上位桁が消灯すること。消え残ると 109 に見える。
	assert_str(_read(display)).is_equal("  9")
