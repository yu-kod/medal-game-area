class_name SevenSegment
extends Node3D

## 筐体に付く 7 セグ表示。
##
## 画面に重ねる UI ではなく、台に実在する部品として立体で組む。
## 設計書 1 章が排除しているのは「情報を増やす UI」であって、
## 実機の筐体に付いている表示器はリアリティの側にある。

const DIGIT_WIDTH := 0.26
const DIGIT_HEIGHT := 0.46
const STROKE := 0.05
const DIGIT_GAP := 0.09

## a b c d e f g の点灯パターン。添字が数字そのもの。
const PATTERNS := [
	[true, true, true, true, true, true, false],      # 0
	[false, true, true, false, false, false, false],  # 1
	[true, true, false, true, true, false, true],     # 2
	[true, true, true, true, false, false, true],     # 3
	[false, true, true, false, false, true, true],    # 4
	[true, false, true, true, false, true, true],     # 5
	[true, false, true, true, true, true, true],      # 6
	[true, true, true, false, false, false, false],   # 7
	[true, true, true, true, true, true, true],       # 8
	[true, true, true, true, false, true, true],      # 9
]

var _segments: Array = []
var _value := -1


## digits 桁ぶんの表示器を組む。原点は表示全体の中心。
static func create(digits: int) -> SevenSegment:
	var display := SevenSegment.new()
	display.name = "SevenSegment"
	var pitch := DIGIT_WIDTH + DIGIT_GAP
	var origin_x := -(digits - 1) * pitch * 0.5
	for index in digits:
		display._segments.append(display._build_digit(origin_x + index * pitch))
	display.set_value(0)
	return display


## 表示を更新する。桁数を超える値は下位桁だけを出す(実機と同じ挙動)。
func set_value(value: int) -> void:
	if value == _value:
		return
	_value = value
	var digits := _segments.size()
	var remaining := clampi(value, 0, int(pow(10, digits)) - 1)
	var on := SurfacePalette.segment_on()
	var off := SurfacePalette.segment_off()
	# 下位桁から埋める。上位の余ったゼロは消灯させる(最下位桁だけは 0 を出す)。
	for index in range(digits - 1, -1, -1):
		var digit := remaining % 10
		remaining /= 10
		var blank := digit == 0 and remaining == 0 and index != digits - 1
		var pattern: Array = PATTERNS[digit]
		var meshes: Array = _segments[index]
		for segment in 7:
			meshes[segment].material_override = on if (not blank and pattern[segment]) else off


func _build_digit(center_x: float) -> Array:
	var half_w := DIGIT_WIDTH * 0.5
	var half_h := DIGIT_HEIGHT * 0.5
	var vertical := Vector3(STROKE, DIGIT_HEIGHT * 0.5 - STROKE, STROKE)
	var horizontal := Vector3(DIGIT_WIDTH - STROKE, STROKE, STROKE)
	var vx := half_w - STROKE * 0.5
	var vy := DIGIT_HEIGHT * 0.25

	# 添字の順は PATTERNS と同じ a b c d e f g。
	var layout := [
		[horizontal, Vector3(center_x, half_h, 0.0)],   # a 上
		[vertical, Vector3(center_x + vx, vy, 0.0)],    # b 右上
		[vertical, Vector3(center_x + vx, -vy, 0.0)],   # c 右下
		[horizontal, Vector3(center_x, -half_h, 0.0)],  # d 下
		[vertical, Vector3(center_x - vx, -vy, 0.0)],   # e 左下
		[vertical, Vector3(center_x - vx, vy, 0.0)],    # f 左上
		[horizontal, Vector3(center_x, 0.0, 0.0)],      # g 中
	]

	var meshes := []
	for entry in layout:
		var mesh := BoxMesh.new()
		mesh.size = entry[0]
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.position = entry[1]
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(visual)
		meshes.append(visual)
	return meshes
