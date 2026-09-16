extends Node3D

## Phase 0 検証シーンのエントリポイント。
##
## 引数なしで起動すると台がただ動き続ける。以下を付けると合格基準の自動判定が走る:
##   -- --validate --soak=300 --label=baseline

const DEFAULT_SOAK_SECONDS := 300.0

var machine: PusherMachine


func _ready() -> void:
	var options := _parse_user_args()

	machine = PusherMachine.new()
	machine.name = "PusherMachine"
	if OS.has_feature("web"):
		_apply_web_budget(machine)
	if options.has("coins"):
		machine.pool_size = int(options["coins"])
		machine.insert_ceiling = machine.pool_size - 60
	if options.has("feed"):
		machine.insert_interval = float(options["feed"])
	add_child(machine)
	_build_view()

	if options.has("hud"):
		add_child(DebugOverlay.create(machine))

	if options.has("seconds"):
		_quit_after(float(options["seconds"]))

	if not options.has("validate"):
		return
	var runner := ValidationRunner.new()
	runner.name = "ValidationRunner"
	runner.machine = machine
	runner.soak_seconds = float(options.get("soak", DEFAULT_SOAK_SECONDS))
	runner.label = str(options.get("label", "run"))
	runner.trace = options.has("trace")
	add_child(runner)


## 指定秒数で自動終了する。`--write-movie` での録画を決まった尺で切り上げるのに使う。
func _quit_after(seconds: float) -> void:
	var timer := get_tree().create_timer(seconds)
	timer.timeout.connect(func() -> void: get_tree().quit())


## ブラウザ(WASM)はネイティブより一桁遅く、スマホならさらに落ちる。
## 見た目の確認が目的なので、物理レートと場の枚数を落として動く状態を優先する。
## デスクトップの検証値(120Hz / 700 枚)はここでは使わない。
func _apply_web_budget(target: PusherMachine) -> void:
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 60
	target.pool_size = 320
	target.insert_ceiling = target.pool_size - 40
	target.insert_interval = 1.0


## 台はほぼ固定カメラで見る(設計書 2章)。
func _build_view() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.03, 0.04)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.52, 0.53, 0.60)
	environment.ambient_light_energy = 1.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	key_light.light_energy = 2.0
	add_child(key_light)

	# 反射環境が無いぶんを補う起こし光。これが無いとメダルの下半分が黒く潰れる。
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
	fill_light.light_energy = 0.7
	fill_light.shadow_enabled = false
	add_child(fill_light)

	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.position = Vector3(0.0, 2.8, 4.6)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.25, -0.35), Vector3.UP)
	add_child(camera)


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
