class_name SurfacePalette
extends RefCounted

## 筐体に使う素材の一覧。
##
## 設計書 11 章の「リアルさの 9 割は音と光」に対応する側。
## 暗い店内に自発光の面がいくつも浮かぶ、という絵を作るための色を集めてある。
## 個々のビルダーが好き勝手に Color を書くと画面全体の統一が崩れるので、必ずここを通す。

## 生成のたびに新しい Material を作るとドローコールが分かれる。名前で使い回す。
static var _cache := {}


## 筐体の外装。艶のある濃紺の樹脂。
static func cabinet_body() -> StandardMaterial3D:
	return _opaque(&"cabinet_body", Color(0.07, 0.08, 0.12), 0.38, 0.0)


## 筐体の縁・フレーム。梨地のガンメタ。
static func cabinet_frame() -> StandardMaterial3D:
	return _opaque(&"cabinet_frame", Color(0.14, 0.14, 0.16), 0.55, 0.7)


## フィールドの床。メダルが金色に見えるよう、明るく彩度の低い面にする。
## ここを暗くするとメダルとの明度差が消えて山の形が読めなくなる。
static func playfield() -> StandardMaterial3D:
	return _opaque(&"playfield", Color(0.50, 0.51, 0.55), 0.62, 0.0)


## プッシャー盤の上面。フィールドよりわずかに暗くして境目を見せる。
static func pusher_plate() -> StandardMaterial3D:
	return _opaque(&"pusher_plate", Color(0.46, 0.47, 0.51), 0.55, 0.1)


## 側壁・後壁。半光沢の黒。
static func inner_wall() -> StandardMaterial3D:
	return _opaque(&"inner_wall", Color(0.10, 0.11, 0.14), 0.45, 0.2)


## 払い出しシュートと受け皿。使い込まれたステンレス。
## 鏡面にすると台内の照明を拾って白い塊になる。実機のシュートも
## メダルに擦られて曇っているので、粗さを上げるほうが正しい。
static func steel() -> StandardMaterial3D:
	return _opaque(&"steel", Color(0.44, 0.46, 0.50), 0.70, 0.45)


## 前面ガラス。映り込みのために少しだけ着色する。
static func glass() -> StandardMaterial3D:
	var key := &"glass"
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.72, 0.78, 0.82, 0.05)
	material.roughness = 0.05
	material.metallic = 0.0
	material.metallic_specular = 0.9
	# 裏面も描かないとガラスの厚みが消えて板に見える。
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 半透明面が山の手前に来ると並び替えが暴れるので、深度書き込みは切る。
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_cache[key] = material
	return material


## マーキーの発光面。店内で最初に目に入る色。
static func marquee_glow() -> StandardMaterial3D:
	return _emissive(&"marquee_glow", Color(0.95, 0.36, 0.18), 2.6)


## 台の縁を走るラインライト。
static func accent_glow() -> StandardMaterial3D:
	return _emissive(&"accent_glow", Color(0.28, 0.72, 1.00), 2.2)


## クレジット表示が載るヘッダー帯。実機はここが背面から光っている。
## ただの暗い板にすると、プレイ中の画面の上端がまるごと黒く沈む。
static func header_panel() -> StandardMaterial3D:
	# 7 セグより明るくしないこと。板が勝つと消灯セグメントまで光って数字が読めなくなる。
	return _emissive(&"header_panel", Color(0.26, 0.32, 0.48), 0.20)


## モニターの額縁。艶のある黒樹脂。
## 画面より暗くないと枠が勝って、画面が窪んで見えない。
static func screen_bezel() -> StandardMaterial3D:
	return _opaque(&"screen_bezel", Color(0.030, 0.032, 0.038), 0.30, 0.0)


## 7 セグ表示の消灯セグメント。点灯していない桁も薄く見えるのが実機。
static func segment_off() -> StandardMaterial3D:
	return _emissive(&"segment_off", Color(0.35, 0.05, 0.03), 0.12)


## 7 セグ表示の点灯セグメント。赤 LED。
static func segment_on() -> StandardMaterial3D:
	return _emissive(&"segment_on", Color(1.00, 0.16, 0.08), 5.0)


static func _opaque(
	key: StringName, albedo: Color, roughness: float, metallic: float
) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = metallic
	_cache[key] = material
	return material


static func _emissive(key: StringName, color: Color, energy: float) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color * 0.4
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	_cache[key] = material
	return material
