class_name ContactMaterials
extends RefCounted

## 面と面が擦れたときの係数。
##
## 静的ボディに PhysicsMaterial を与えないと Godot の既定 friction = 1.0 が使われる。
## Jolt は摩擦を幾何平均で合成するので、メダル 0.19 に対して台が 1.0 だと
## 実効 √(0.19 × 1.0) = 0.44 になり、狙いの倍以上に効いてしまう。
## 台側にも必ず材質を与えること。
##
## 合成則(Jolt の既定):
##   摩擦     = sqrt(a × b)
##   反発係数 = max(a, b)
## 反発が max なので、金属同士だけをよく跳ねさせたい場合は金属側に高い値を置く。
##
## 実物の目安(乾燥・使い込まれた面):
##   真鍮メダル同士          μ ≈ 0.19
##   メダル対 アクリル/ABS   μ ≈ 0.22
##   メダル対 ステンレス     μ ≈ 0.18
##   メダル対 ガラス         μ ≈ 0.14

static var _cache := {}


## フィールドの盤面。アクリルの印刷パネル。
## 実効 sqrt(0.14 × 0.35) = 0.22。メダル同士の値を動かしても
## 盤面との摩擦が変わらないよう、ここで逆算して据え置いている。
static func playfield() -> PhysicsMaterial:
	return _make(&"playfield", 0.35, 0.10)


## プッシャー盤の上面。山を前へ運ぶ面なので、盤面よりわずかに食いつかせる。
## ここが滑ると山がその場で足踏みして前に出なくなる。実効 sqrt(0.14 × 0.64) = 0.30。
static func pusher_plate() -> PhysicsMaterial:
	return _make(&"pusher_plate", 0.64, 0.08)


## 払い出しシュートと受け皿。ステンレス。
## 反発を高めにしてある。受け皿でメダルが跳ねて鳴るのがこの台の気持ち良さの半分。
static func steel() -> PhysicsMaterial:
	return _make(&"steel", 0.23, 0.22)


## 前面ガラス。当たっても滑って落ちるだけの面。
static func glass() -> PhysicsMaterial:
	return _make(&"glass", 0.14, 0.18)


## 筐体・壁の樹脂。既定として使う。
static func plastic() -> PhysicsMaterial:
	return _make(&"plastic", 0.30, 0.10)


## 床のカーペット。メダルがこぼれても転がらない。
static func carpet() -> PhysicsMaterial:
	return _make(&"carpet", 0.90, 0.02)


static func _make(key: StringName, friction: float, bounce: float) -> PhysicsMaterial:
	if _cache.has(key):
		return _cache[key]
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.bounce = bounce
	_cache[key] = material
	return material
