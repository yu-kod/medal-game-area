class_name RouletteScreen
extends Node3D

## 抽選のモニター。
##
## メダルを撃ち出している場所の後ろ ── 後方デッキの前面に嵌めた 16:9 の画面。
## 中身は SubViewport に 2D で描いたもので、それを板に貼って自発光させている。
## 3D のリールを回すより軽く、演出を足すのも 2D のほうが速い。
##
## 保留もクレジットもこの中に描く。外付けのランプや表示器は付けない。
## 画面が 1 枚あれば、あとは描くものを増やすだけで演出を足せる。

## 16:9。板の縦横比(SCREEN_HALF_WIDTH / SCREEN_Y_*)と必ず揃えること。
## ずれると画面の中の丸が楕円になる。
const VIEW_SIZE := Vector2i(1024, 576)

var _reel: RouletteReel


static func create() -> RouletteScreen:
	var screen := RouletteScreen.new()
	screen.name = "RouletteScreen"
	return screen


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.name = "ScreenViewport"
	viewport.size = VIEW_SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	_reel = RouletteReel.create(VIEW_SIZE)
	viewport.add_child(_reel)

	_build_monitor(viewport.get_texture())


## 抽選開始。結果はこの時点で確定しているので、そこへ向けて回すだけ。
func start_spin(outcome: int, duration: float) -> void:
	_reel.start(outcome, duration)


func show_result(outcome: int) -> void:
	_reel.show_result(outcome)


func set_stock(stock: int) -> void:
	_reel.set_stock(stock)


func set_credit(credit: int) -> void:
	_reel.set_credit(credit)


## 払い出し中の残り枚数。0 なら表示を消す。
func set_payout_pending(count: int) -> void:
	_reel.set_payout_pending(count)


## モニター本体。黒い額縁に画面を嵌めて、筐体に付いている部品として見せる。
func _build_monitor(texture: Texture2D) -> void:
	var height := PusherSpec.SCREEN_Y_TOP - PusherSpec.SCREEN_Y_BOTTOM
	var center_y := (PusherSpec.SCREEN_Y_TOP + PusherSpec.SCREEN_Y_BOTTOM) * 0.5
	var margin := PusherSpec.SCREEN_BEZEL_MARGIN

	# 筐体側の座金。額縁の裏に一回り大きい板を入れて、壁から生えて見えないようにする。
	PropBuilder.decor_box(
		self,
		"ScreenMount",
		Vector3(
			PusherSpec.SCREEN_HALF_WIDTH * 2.0 + margin * 3.0,
			height + margin * 3.0,
			PusherSpec.SCREEN_BEZEL_DEPTH * 0.5
		),
		Vector3(0.0, center_y, PusherSpec.SCREEN_Z - PusherSpec.SCREEN_BEZEL_DEPTH * 0.25),
		SurfacePalette.cabinet_frame()
	)

	# 額縁。画面より一回り大きく、手前に張り出させて厚みを見せる。
	PropBuilder.decor_box(
		self,
		"ScreenBezel",
		Vector3(
			PusherSpec.SCREEN_HALF_WIDTH * 2.0 + margin * 2.0,
			height + margin * 2.0,
			PusherSpec.SCREEN_BEZEL_DEPTH
		),
		Vector3(0.0, center_y, PusherSpec.SCREEN_Z + PusherSpec.SCREEN_BEZEL_DEPTH * 0.5),
		SurfacePalette.screen_bezel()
	)

	var mesh := QuadMesh.new()
	mesh.size = Vector2(PusherSpec.SCREEN_HALF_WIDTH * 2.0, height)

	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	# 画面は自分で光っている。台内照明の陰影を受けさせない。
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var panel := MeshInstance3D.new()
	panel.name = "ScreenPanel"
	panel.mesh = mesh
	panel.material_override = material
	# 額縁の前面よりわずかに手前。奥にすると枠に食われて縁が欠ける。
	panel.position = Vector3(
		0.0, center_y, PusherSpec.SCREEN_Z + PusherSpec.SCREEN_BEZEL_DEPTH + 0.005
	)
	add_child(panel)
