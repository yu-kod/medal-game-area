class_name PusherIsland
extends ArcadeMachine

## プッシャーの島。中央のタワーを 4 席または 6 席が囲む、日本のメダルコーナーの標準形。
##
## 席(PusherStation)は完全に独立していて、フィールドもプッシャー盤も払い出しも別々。
## 島が持っているのは中央塔と基壇、つまり見た目と、いずれ載るジャックポットだけ。
##
## 物理を回すのはプレイヤーが座っている 1 席だけ。残りは見た目の山を置く。
## 全席で回すと 1 席 300 枚 × 6 = 1800 剛体になって成立しない。
##
## ArcadeMachine の契約(insert_medal / medals_paid_out)はプレイヤーの席へ素通しする。
## 店内から見れば島がひとつの「台」で、席はその内部構造という扱い。

## 席数。4 と 6 のどちらでも組める。
var station_count := PusherSpec.DEFAULT_STATION_COUNT
## プレイヤーが座っている席。ここだけ物理を回す。
var player_index := 0
var wallet: PlayerWallet
var demo_running := false

var stations: Array[PusherStation] = []


func _ready() -> void:
	machine_name = "PUSHER"
	if wallet == null:
		wallet = PlayerWallet.new()

	for index in station_count:
		var station := PusherStation.new()
		station.name = "Station%d" % index
		station.station_index = index
		station.simulated = index == player_index
		station.transform = PusherSpec.station_transform(index, station_count)
		if station.simulated:
			station.wallet = wallet
			station.demo_running = demo_running
		add_child(station)
		stations.append(station)

	_build_tower()


## プレイヤーが座っている席。
func player_station() -> PusherStation:
	return stations[player_index]


## 島の原点から見たプレイヤーの目線。
func view_anchor() -> Transform3D:
	var station := player_station()
	return station.transform * station.view_anchor()


func insert_medal(lane := 0.0) -> bool:
	return player_station().insert_medal(lane)


## 中央塔。席の外装の上に出る部分だけが看板として見える。
## いまは光る帯だけで、ジャックポットの数字は載せていない。
## 存在しない抽選の数字を出すのは、設計書 1 章が禁じている「嘘の情報」になる。
func _build_tower() -> void:
	var apothem := PusherSpec.station_apothem(station_count)

	# 基壇。席の足元をぐるりと繋ぐ。
	_add_prism(
		"TowerPlinth",
		apothem + 0.45,
		PusherSpec.CABINET_Y_BOTTOM,
		PusherSpec.CABINET_Y_BOTTOM + 1.4,
		SurfacePalette.cabinet_frame()
	)

	# 支柱。席のあいだから立ち上がる本体。
	_add_prism(
		"TowerShaft",
		apothem * 0.92,
		PusherSpec.CABINET_Y_BOTTOM,
		PusherSpec.TOWER_SHAFT_Y_TOP,
		SurfacePalette.cabinet_body()
	)

	# 光る帯。暗い店内で島の位置を示す、いちばん目立つ面。
	_add_prism(
		"TowerBand",
		apothem * 0.96,
		PusherSpec.TOWER_BAND_Y_BOTTOM,
		PusherSpec.TOWER_BAND_Y_TOP,
		SurfacePalette.accent_glow()
	)

	# 冠。上に張り出した看板。
	_add_prism(
		"TowerCrown",
		apothem * 1.22,
		PusherSpec.TOWER_SHAFT_Y_TOP,
		PusherSpec.TOWER_CROWN_Y_TOP,
		SurfacePalette.marquee_glow()
	)

	# 冠を照らす灯り。看板面が自発光だけだと平らに見える。
	var crown_lamp := OmniLight3D.new()
	crown_lamp.name = "CrownLamp"
	crown_lamp.position = Vector3(
		0.0, (PusherSpec.TOWER_SHAFT_Y_TOP + PusherSpec.TOWER_CROWN_Y_TOP) * 0.5, 0.0
	)
	crown_lamp.light_color = Color(1.0, 0.62, 0.34)
	crown_lamp.light_energy = 6.0
	crown_lamp.omni_range = apothem * 5.0
	crown_lamp.shadow_enabled = false
	add_child(crown_lamp)

	# 冠の下から席を照らす下向きの灯り。実機の島も中央から手元を照らしている。
	# これが無いと外から見たとき筐体の外装が真っ黒で、島の輪郭しか見えない。
	var wash := OmniLight3D.new()
	wash.name = "TowerWash"
	wash.position = Vector3(0.0, PusherSpec.TOWER_BAND_Y_BOTTOM - 0.5, 0.0)
	wash.light_color = Color(0.72, 0.82, 1.0)
	wash.light_energy = 7.0
	wash.omni_range = apothem + PusherSpec.station_radius(station_count) + 8.0
	wash.shadow_enabled = false
	add_child(wash)

	_add_tower_signs(apothem * 1.22)


## 各席の正面に台名を掲げる。席の数だけ面があるので、面ごとに 1 枚ずつ。
func _add_tower_signs(radius: float) -> void:
	var sign_y := (PusherSpec.TOWER_SHAFT_Y_TOP + PusherSpec.TOWER_CROWN_Y_TOP) * 0.5
	for index in station_count:
		var basis := Basis(Vector3.UP, TAU * float(index) / float(station_count))
		var label := Label3D.new()
		label.name = "TowerSign%d" % index
		label.text = machine_name
		label.font_size = 220
		label.pixel_size = 0.0075
		label.modulate = Color(1.0, 0.97, 0.90)
		label.outline_size = 24
		label.outline_modulate = Color(0.25, 0.05, 0.0)
		label.transform = Transform3D(basis, basis * Vector3(0.0, sign_y, radius + 0.06))
		add_child(label)


## 席と同じ角数の角柱。面がちょうど各席に正対する向きに回してある。
func _add_prism(
	node_name: String, radius: float, y_bottom: float, y_top: float, material: Material
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	# 引数は内接半径。角柱の面をその位置に置くには外接半径に直す必要がある。
	var circumradius := radius / cos(PI / float(station_count))
	mesh.top_radius = circumradius
	mesh.bottom_radius = circumradius
	mesh.height = y_top - y_bottom
	mesh.radial_segments = station_count
	mesh.rings = 0

	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.material_override = material
	visual.position = Vector3(0.0, (y_top + y_bottom) * 0.5, 0.0)
	# 既定では頂点が角度 0 に来る。半ピッチ回して面の中心を席の方向に合わせる。
	visual.rotation = Vector3(0.0, PI / float(station_count), 0.0)
	add_child(visual)
	return visual
