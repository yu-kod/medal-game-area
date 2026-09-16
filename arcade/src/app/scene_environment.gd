class_name SceneEnvironment
extends RefCounted

## 画面全体の絵作り。設計書 11 章の「光」の土台。
##
## 店内は暗く、明るいのは台の中と自発光だけ、という関係を作る。
## ここを明るくすると台の照明が効かなくなり、一気に嘘くさくなる。


static func build(parent: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.013, 0.018)

	# 空も反射プローブも無い状態で金属を置くと真っ黒に潰れる。
	# 弱い環境光で下限を作り、質感そのものは反射プローブに任せる。
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.17, 0.19, 0.26)
	environment.ambient_light_energy = 1.05

	# 発光面のにじみ。暗い店内の光り物はこれが無いとただの明るい板になる。
	#
	# 閾値は必ず金属の鏡面より上に置くこと。1.05 まで下げると、
	# 照明を浴びた金メダルの反射がまとめて滲んで盤面が真っ白に潰れる。
	# 光らせたいのはマーキーと LED であって、メダルではない。
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 1.70
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN

	# メダルの山にコントラストを付ける。平坦な面が接する場所ほど効く。
	environment.ssao_enabled = true
	environment.ssao_radius = 0.35
	environment.ssao_intensity = 1.6
	environment.ssao_power = 1.8

	# 画面空間反射は切ってある。盤面が金属メダルで埋まると、メダル同士が
	# 互いの反射を足し合わせて中央が白く飽和する。負荷も重い。
	# 金属感は反射プローブ(add_reflection_probe)のほうで出す。
	environment.ssr_enabled = false

	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	# 白とみなす明るさ。低いとハイライトがすぐ飽和して階調が消える。
	environment.tonemap_white = 6.0
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.04

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	parent.add_child(world_environment)


## 台のまわりの映り込みを焼く。metallic の高いメダルはこれが無いと黒い円盤になる。
## 台と部屋を組み終わってから呼ぶこと。
static func add_reflection_probe(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var probe := ReflectionProbe.new()
	probe.name = "MachineReflection"
	probe.position = center
	probe.size = size
	probe.origin_offset = Vector3.ZERO
	probe.max_distance = 24.0
	probe.intensity = 1.0
	# 台も部屋も動かないので 1 度焼けば足りる。
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.interior = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
	parent.add_child(probe)
