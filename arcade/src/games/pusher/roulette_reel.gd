class_name RouletteReel
extends Control

## 抽選モニターの中身。3 ドラムのルーレットと、その周りの表示。
##
## 結果は回り始める前に決まっている。ここがやるのは、決まっている目まで
## 3 つのドラムを順に止めることだけ。回転中に結果を探しはしない。
##
## 止まる順は左 → 中 → 右。2 つ揃って最後の 1 つが回っている状態が「リーチ」で、
## ハズレのときもときどきリーチを作る。当落が変わるわけではなく、見せ方の問題。
##
## 保留・クレジット・払い出し中の枚数も、外付けのランプではなくここに描く。
## 描くものを増やすだけで演出を足せるので、実機の液晶と同じ位置付けにしてある。

## 絵柄。揃えば当たり。ハズレ用の絵柄も同じ扱いで並べる。
enum Symbol { SMALL, BIG, JACKPOT, BLANK_A, BLANK_B, BLANK_C }

const DRUM_COUNT := 3
## ドラムに巻いてある絵柄の並び。1 周ぶん。
const STRIP := [
	Symbol.BLANK_A,
	Symbol.SMALL,
	Symbol.BLANK_B,
	Symbol.BIG,
	Symbol.BLANK_C,
	Symbol.SMALL,
	Symbol.BLANK_A,
	Symbol.JACKPOT,
	Symbol.BLANK_B,
	Symbol.SMALL,
	Symbol.BLANK_C,
	Symbol.BIG,
]

const CELL_HEIGHT := 104.0
const DRUM_WIDTH := 210.0
const DRUM_GAP := 30.0
## 止まるまでに回す周回数。右のドラムほど長く回す。
const BASE_LAPS := 3
## 各ドラムが止まる時刻。回転時間に対する割合。
## 左と中を早めに揃えるほど、リーチの間が長く取れる。
const STOP_AT := [0.34, 0.58, 1.0]

# --- 画面の割り付け(VIEW_SIZE = 1024 x 576 が前提) ---
const HEADER_HEIGHT := 62.0
const FOOTER_TOP := 452.0
const MARGIN := 34.0

const COLOR_BACK := Color(0.020, 0.025, 0.045)
const COLOR_PANEL := Color(0.048, 0.058, 0.098)
const COLOR_WINDOW := Color(0.072, 0.082, 0.130)
const COLOR_LINE := Color(0.20, 0.24, 0.34)
const COLOR_DIM := Color(0.50, 0.57, 0.70)
const COLOR_TEXT := Color(0.90, 0.94, 1.00)
const COLOR_ACCENT := Color(1.00, 0.82, 0.42)

var _offset := [0.0, 0.0, 0.0]
var _from := [0.0, 0.0, 0.0]
var _to := [0.0, 0.0, 0.0]
var _stopped := [true, true, true]
var _elapsed := 0.0
var _duration := 0.0
var _spinning := false
var _flash := 0.0
var _result := -1
var _stock := 0
var _credit := 0
var _payout_pending := 0
var _pulse := 0.0
var _rng := RandomNumberGenerator.new()
var _font: Font


static func create(view_size: Vector2i) -> RouletteReel:
	var reel := RouletteReel.new()
	reel.name = "Reel"
	reel.size = Vector2(view_size)
	reel._rng.seed = 991
	return reel


func _ready() -> void:
	_font = ThemeDB.fallback_font


## 決まっている結果の目まで回して止める。
func start(outcome: int, duration: float) -> void:
	var target := _target_symbols(outcome)
	var lap := CELL_HEIGHT * STRIP.size()
	for drum in DRUM_COUNT:
		var index := _pick_cell(target[drum])
		var goal := index * CELL_HEIGHT
		var minimum: float = _offset[drum] + lap * (BASE_LAPS + drum)
		while goal < minimum:
			goal += lap
		_from[drum] = _offset[drum]
		_to[drum] = goal
		_stopped[drum] = false
	_elapsed = 0.0
	_duration = duration
	_spinning = true
	_result = -1
	_flash = 0.0


func show_result(outcome: int) -> void:
	_result = outcome
	_flash = 1.0


func set_stock(stock: int) -> void:
	_stock = stock


func set_credit(credit: int) -> void:
	_credit = credit


func set_payout_pending(count: int) -> void:
	_payout_pending = count


## リーチ中か。左と中が揃っていて、右がまだ回っている状態。
##
## いまは枠を明滅させて文字を出すだけ。長い演出はここを起点に足していく。
func is_reach() -> bool:
	if not _spinning or _stopped[DRUM_COUNT - 1]:
		return false
	if not (_stopped[0] and _stopped[1]):
		return false
	return _landed_symbol(0) == _landed_symbol(1)


## 結果に対応する 3 つの絵柄。当たりは 3 つ揃い、ハズレは揃えない。
func _target_symbols(outcome: int) -> Array:
	match outcome:
		Roulette.Outcome.SMALL:
			return [Symbol.SMALL, Symbol.SMALL, Symbol.SMALL]
		Roulette.Outcome.BIG:
			return [Symbol.BIG, Symbol.BIG, Symbol.BIG]
		Roulette.Outcome.JACKPOT:
			return [Symbol.JACKPOT, Symbol.JACKPOT, Symbol.JACKPOT]

	# ハズレ。3 回に 1 回はリーチ(左と中が揃って右だけ外す)にして緊張を作る。
	# 当落はもう決まっているので、これは見せ方でしかない。
	if _rng.randf() < 0.34:
		var hit: int = [Symbol.SMALL, Symbol.BIG, Symbol.JACKPOT][_rng.randi_range(0, 2)]
		return [hit, hit, Symbol.BLANK_A]
	return [Symbol.BLANK_A, Symbol.SMALL, Symbol.BLANK_B]


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta, 10.0)
	if _spinning:
		_elapsed += delta
		var done := 0
		for drum in DRUM_COUNT:
			var span: float = _duration * STOP_AT[drum]
			var t := clampf(_elapsed / maxf(span, 0.001), 0.0, 1.0)
			# 終盤で急に減速する。実機のドラムの止まり方。
			var eased := 1.0 - pow(1.0 - t, 3.0)
			_offset[drum] = lerpf(_from[drum], _to[drum], eased)
			if t >= 1.0:
				_offset[drum] = _to[drum]
				_stopped[drum] = true
				done += 1
		if done == DRUM_COUNT:
			_spinning = false
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 0.8, 0.0)
	queue_redraw()


## そのドラムが止まる目。
func _landed_symbol(drum: int) -> int:
	var index := int(round(_to[drum] / CELL_HEIGHT))
	return STRIP[posmod(index, STRIP.size())]


## その絵柄が巻かれているコマをひとつ選ぶ。
func _pick_cell(symbol: int) -> int:
	for index in STRIP.size():
		if STRIP[index] == symbol:
			return index
	return 0


func _draw() -> void:
	var view := size
	draw_rect(Rect2(Vector2.ZERO, view), COLOR_BACK)

	# リールを先に描く。窓からはみ出したコマを隠す帯が上下に伸びるので、
	# あとから帯を描かないと、その覆いに文字が塗り潰される。
	_draw_reels(Rect2(0.0, HEADER_HEIGHT, view.x, FOOTER_TOP - HEADER_HEIGHT))
	_draw_header(Rect2(0.0, 0.0, view.x, HEADER_HEIGHT))
	_draw_footer(Rect2(0.0, FOOTER_TOP, view.x, view.y - FOOTER_TOP))
	_draw_scanlines(view)


## 上の帯。台の名前と、いま何をしているか。
func _draw_header(bar: Rect2) -> void:
	draw_rect(bar, COLOR_PANEL)
	draw_line(Vector2(0.0, bar.end.y), Vector2(bar.end.x, bar.end.y), COLOR_LINE, 2.0)
	draw_string(
		_font,
		Vector2(MARGIN, bar.position.y + 43.0),
		"MEDAL CHANCE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		34,
		COLOR_ACCENT
	)

	var state := "WAITING"
	var lit := false
	if _spinning:
		state = "REACH!!" if is_reach() else "SPINNING"
		lit = true
	elif _result > Roulette.Outcome.LOSE:
		state = ["", "SMALL WIN", "BIG WIN", "JACKPOT!!"][_result]
		lit = true
	draw_string(
		_font,
		Vector2(bar.end.x - 340.0 - MARGIN, bar.position.y + 42.0),
		state,
		HORIZONTAL_ALIGNMENT_RIGHT,
		340.0,
		30,
		COLOR_TEXT if lit else COLOR_DIM
	)


func _draw_reels(area: Rect2) -> void:
	var total := DRUM_COUNT * DRUM_WIDTH + (DRUM_COUNT - 1) * DRUM_GAP
	var left := area.position.x + (area.size.x - total) * 0.5
	var window_h := CELL_HEIGHT * 3.0
	var top := area.position.y + (area.size.y - window_h) * 0.5

	for drum in DRUM_COUNT:
		var x := left + drum * (DRUM_WIDTH + DRUM_GAP)
		_draw_drum(Rect2(x, top, DRUM_WIDTH, window_h), _offset[drum])

	_draw_payline(Rect2(left, top + CELL_HEIGHT, total, CELL_HEIGHT))


## ドラム 1 本ぶん。窓の中に 3 コマ見える。
func _draw_drum(window: Rect2, offset: float) -> void:
	draw_rect(window, COLOR_WINDOW)

	var center_y := window.position.y + window.size.y * 0.5
	var base := int(floor(offset / CELL_HEIGHT))
	for step in range(-2, 3):
		var index := base + step
		var y := center_y - (offset - index * CELL_HEIGHT) - CELL_HEIGHT * 0.5
		if y > window.end.y or y + CELL_HEIGHT < window.position.y:
			continue
		_draw_symbol(
			Rect2(window.position.x, y, window.size.x, CELL_HEIGHT),
			STRIP[posmod(index, STRIP.size())]
		)

	# 窓の外に出たぶんを隠す。上下の帯で切る。
	draw_rect(
		Rect2(window.position.x, window.position.y - CELL_HEIGHT, window.size.x, CELL_HEIGHT),
		COLOR_BACK
	)
	draw_rect(Rect2(window.position.x, window.end.y, window.size.x, CELL_HEIGHT), COLOR_BACK)
	draw_rect(window, COLOR_LINE, false, 3.0)


func _draw_symbol(cell: Rect2, symbol: int) -> void:
	var middle := cell.get_center()
	var radius := minf(cell.size.x, cell.size.y) * 0.30
	match symbol:
		Symbol.SMALL:
			draw_circle(middle, radius, Color(0.45, 0.78, 1.0))
		Symbol.BIG:
			draw_circle(middle, radius, Color(1.0, 0.66, 0.22))
			draw_arc(middle, radius * 1.35, 0.0, TAU, 32, Color(1.0, 0.82, 0.40), 5.0)
		Symbol.JACKPOT:
			draw_circle(middle, radius * 1.1, Color(1.0, 0.26, 0.30))
			draw_arc(middle, radius * 1.55, 0.0, TAU, 40, Color(1.0, 0.92, 0.60), 7.0)
		_:
			# ハズレ用の絵柄。控えめな図形にして、当たりの絵柄と一目で区別が付くようにする。
			var box := Vector2(radius * 0.9, radius * 0.9)
			draw_rect(Rect2(middle - box * 0.5, box), Color(0.28, 0.31, 0.38))


## 中央の当たりライン。当たりのときとリーチのときだけ光らせる。
func _draw_payline(line: Rect2) -> void:
	var tint := COLOR_LINE
	var width := 3.0
	if _result > Roulette.Outcome.LOSE:
		tint = COLOR_ACCENT.lerp(Color(1.0, 0.32, 0.28), _flash)
		width = 7.0
	elif is_reach():
		# 明滅させる。長い演出を足すならここを起点にする。
		tint = COLOR_LINE.lerp(Color(1.0, 0.40, 0.30), 0.5 + 0.5 * sin(_pulse * 12.0))
		width = 6.0
	draw_rect(line.grow(8.0), tint, false, width)


## 下の帯。保留・払い出し中・クレジット。
func _draw_footer(bar: Rect2) -> void:
	draw_rect(bar, COLOR_PANEL)
	draw_line(Vector2(0.0, bar.position.y), Vector2(bar.end.x, bar.position.y), COLOR_LINE, 2.0)

	_draw_stock(bar)
	_draw_payout(bar)
	_draw_credit(bar)


## 保留。溜まっている数だけ点く。実機のランプをそのまま画面に移したもの。
func _draw_stock(bar: Rect2) -> void:
	draw_string(
		_font,
		Vector2(MARGIN, bar.position.y + 34.0),
		"STOCK",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		22,
		COLOR_DIM
	)

	var pip := 26.0
	var gap := 12.0
	var top := bar.position.y + 52.0
	for index in PusherSpec.STOCK_LAMP_COUNT:
		var box := Rect2(MARGIN + index * (pip + gap), top, pip, pip)
		if index < _stock:
			draw_rect(box, COLOR_ACCENT)
			draw_rect(box.grow(3.0), Color(COLOR_ACCENT, 0.5), false, 2.0)
		else:
			draw_rect(box, Color(0.11, 0.13, 0.19))
			draw_rect(box, COLOR_LINE, false, 2.0)


## 払い出し中の残り枚数。出し切ったら消える。
func _draw_payout(bar: Rect2) -> void:
	if _payout_pending <= 0:
		return
	var blink := 0.55 + 0.45 * sin(_pulse * 8.0)
	draw_string(
		_font,
		Vector2(bar.size.x * 0.5 - 170.0, bar.position.y + 62.0),
		"PAYOUT  %d" % _payout_pending,
		HORIZONTAL_ALIGNMENT_CENTER,
		340.0,
		36,
		Color(1.0, 0.72, 0.30, blink)
	)


## クレジット。右下に小さく。台の主役ではないので目立たせない。
func _draw_credit(bar: Rect2) -> void:
	var right := bar.end.x - MARGIN
	draw_string(
		_font,
		Vector2(right - 260.0, bar.position.y + 34.0),
		"CREDIT",
		HORIZONTAL_ALIGNMENT_RIGHT,
		260.0,
		22,
		COLOR_DIM
	)
	draw_string(
		_font,
		Vector2(right - 260.0, bar.position.y + 80.0),
		str(_credit),
		HORIZONTAL_ALIGNMENT_RIGHT,
		260.0,
		40,
		COLOR_TEXT
	)


## 走査線。うっすら横縞を重ねると、板ではなくモニターに見える。
func _draw_scanlines(view: Vector2) -> void:
	var tint := Color(0.0, 0.0, 0.0, 0.16)
	var y := 0.0
	while y < view.y:
		draw_rect(Rect2(0.0, y, view.x, 2.0), tint)
		y += 4.0
