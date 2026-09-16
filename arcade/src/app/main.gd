extends Node3D

## エントリポイント。部屋を建てて、台を 1 台置いて、カメラを台の前に据える。
##
## 台を増やすときはここに並べる。ArcadeRoom.bay_origin(index) が設置位置を返す。
##
## 起動オプション(`--` の後ろに付ける):
##   --credit=N        手持ちメダルの初期値
##   --stations=4|6    島の席数
##   --demo            自動投入を回す(放置して挙動を見るとき)
##   --debug           検証用の計器を出す
##   --shots=DIR       スクリーンショットの出力先(絶対パス)
##   --shot-at=2,10,30 撮影する経過秒
##   --seconds=N       N 秒で自動終了

## 既定は手で遊ぶ状態。自動投入も計器も、見たいときに --demo / --debug で足す。
const DEFAULT_CREDIT := 900

var room: ArcadeRoom
var island: PusherIsland
var wallet: PlayerWallet
var camera: Camera3D


func _ready() -> void:
	var options := _parse_user_args()

	SceneEnvironment.build(self)

	room = ArcadeRoom.create()
	add_child(room)

	wallet = PlayerWallet.new()
	wallet.add_medals(int(options.get("credit", DEFAULT_CREDIT)))

	island = PusherIsland.new()
	island.name = "PusherIsland"
	island.wallet = wallet
	island.station_count = int(options.get("stations", PusherSpec.DEFAULT_STATION_COUNT))
	island.demo_running = options.has("demo")
	# プレイヤーの席が島の設置位置に来るよう、島ごとずらす。
	# 席は島の中心から半径ぶん外にあるので、その分だけ引く。
	island.position = (
		ArcadeRoom.bay_origin(0)
		- PusherSpec.station_transform(island.player_index, island.station_count).origin
	)
	add_child(island)

	camera = Camera3D.new()
	camera.name = "PlayerView"
	camera.near = 0.05
	_place_camera(options)
	add_child(camera)

	add_child(MachineControls.create(island))
	_hide_until_warm()

	# 台と部屋が揃ってから焼く。メダルの金属感はこの映り込みで決まる。
	SceneEnvironment.add_reflection_probe(
		self, ArcadeRoom.bay_origin(0) + Vector3(0.0, -1.0, 0.0), Vector3(18.0, 26.0, 22.0)
	)

	if options.has("debug"):
		add_child(DevHud.create(island.player_station()))

	if options.has("shots"):
		add_child(
			ViewportCapture.create(
				str(options["shots"]), _parse_times(str(options.get("shot-at", "5")))
			)
		)

	if options.has("seconds"):
		_quit_after(float(options["seconds"]))


## 既定は台が決める観覧位置。`--cam` / `--look` / `--fov` で上書きできる。
## 画角合わせは実際の絵を見ながらでないと決まらないので、コードを触らずに振れるようにしてある。
func _place_camera(options: Dictionary) -> void:
	var eye := PusherSpec.VIEW_EYE
	var target := PusherSpec.VIEW_TARGET
	var fov := PusherSpec.VIEW_FOV
	if options.has("cam"):
		eye = _parse_vector(str(options["cam"]), eye)
	if options.has("look"):
		target = _parse_vector(str(options["look"]), target)
	if options.has("fov"):
		fov = float(options["fov"])
	camera.fov = fov
	# 目線は「プレイヤーの席のローカル座標」で書いてある。
	# 島が回転して置かれていても、席の変換を通せばそのまま効く。
	var station := island.player_station()
	camera.transform = (
		island.transform
		* station.transform
		* Transform3D(Basis.IDENTITY, eye).looking_at(target, Vector3.UP)
	)


func _parse_vector(text: String, fallback: Vector3) -> Vector3:
	var parts := text.split(",", false)
	if parts.size() != 3:
		return fallback
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


## 盤面ができあがるまで画面を隠す。
##
## 台はメダルを上から降らせ、積もるのを待ち、盤を 1 往復させてから運転に入る。
## その準備の様子は台の中の出来事ではないので見せない。
## 実機で言えば、開店前に店員が盤面を均している時間にあたる。
func _hide_until_warm() -> void:
	var curtain := CanvasLayer.new()
	curtain.name = "WarmupCurtain"
	curtain.layer = 64

	var fill := ColorRect.new()
	fill.color = Color(0.012, 0.013, 0.018)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.add_child(fill)
	add_child(curtain)

	island.player_station().warmed_up.connect(
		func() -> void:
			var fade := create_tween()
			fade.tween_property(fill, "modulate:a", 0.0, 0.6)
			fade.tween_callback(curtain.queue_free)
	)


## 指定秒で成績を出して終了する。
##
## `--headless` と組み合わせると窓が無いので、手で投入して数字を汚す余地が無い。
## 形状だけの評価をしたいときはこの形で回す。
func _quit_after(seconds: float) -> void:
	var timer := get_tree().create_timer(seconds)
	timer.timeout.connect(
		func() -> void:
			var station := island.player_station()
			# 還元率は「払い出し / 投入」だけで足りる。
			#
			# 抽選の当たりはクレジットに足されず、ホッパーから盤面へ出るだけなので、
			# プレイヤーの手取りは前端から落ちた枚数がすべて。抽選ぶんもそこを通る。
			# 抽選の当たり枚数は還元率ではなく「盤面へいくら供給したか」として見る。
			#
			# ただしこの数字は収束が遅い。供給されたメダルが前端まで運ばれるには
			# 何往復もかかるので、短い試験では供給が場に溜まったまま終わる。
			print(
				(
					(
						"[soak] %.0f秒  場 %d枚  投入 %d  払い出し %d  横穴 %d  逸脱 %d\n"
						+ "       チェッカー %d  抽選当たり %d枚(未払出 %d)  還元率 %.0f%%"
					)
					% [
						seconds,
						station.active_count(),
						station.insert_count,
						station.payout_count,
						station.side_loss_count,
						station.void_count,
						station.chucker_count,
						station.lottery_reward,
						station.hopper.pending() if station.hopper != null else 0,
						station.lifetime_payout_ratio() * 100.0,
					]
				)
			)
			get_tree().quit()
	)


func _parse_times(text: String) -> Array[float]:
	var times: Array[float] = []
	for piece in text.split(",", false):
		times.append(float(piece))
	times.sort()
	return times


## `--key=value` と `--flag` の両方を受ける。
func _parse_user_args() -> Dictionary:
	var options := {}
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var body := argument.substr(2)
		var separator := body.find("=")
		if separator == -1:
			options[body] = true
		else:
			options[body.left(separator)] = body.substr(separator + 1)
	return options
