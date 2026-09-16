class_name PusherMachine
extends Node3D

## プッシャー 1 台ぶんの組み立てと運転。
##
## Phase 0 の検証シーンなので、ゲーム要素(所持枚数・購入・XP)は一切持たない。
## 落ちたコインはすべてプールへ戻して再投入し、常に一定枚数を場に保つ。

var pool: CoinPool
var pusher: Pusher

var payout_count := 0
var side_loss_count := 0
var void_count := 0

var insert_enabled := true
## 投入そのものが押し出しの動力源。場が満ちたら投入を止める設計にすると台も止まる。
## 上限はプールを溢れさせないための安全弁であって、平常時に効いてはいけない。
var insert_ceiling := MachineSpec.POOL_SIZE - 60
## 投入間隔。Phase 0 は物理の耐久試験なので、台が常時動き続ける 30 枚/分で回す。
## この速度では流入(30 枚/分)が流出(実測 9 枚/分)を上回り、場は増え続ける。
## 5 分の試験内では釣り合わない。長時間放置すると insert_ceiling で投入が止まる。
## 設計書 6.4 の消費速度(毎分 8〜12 枚)への追い込みは経済を組む Phase 2 の仕事。
var insert_interval := 2.0
var pool_size := MachineSpec.POOL_SIZE

var _sinks: Array[CoinSink] = []
var _pending_release: Array[Coin] = []
var _pending_ids := {}
var _insert_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260815
	FieldBuilder.build(self)

	pusher = Pusher.create()
	add_child(pusher)
	pusher.stroke_started.connect(_on_stroke_started)

	pool = CoinPool.new()
	pool.name = "CoinPool"
	pool.pool_size = pool_size
	add_child(pool)

	_build_sinks()
	_seed_field()


func active_count() -> int:
	return pool.active_count()


func _build_sinks() -> void:
	var sink_height := MachineSpec.SINK_Y_TOP - MachineSpec.SINK_Y_BOTTOM
	var sink_center_y := (MachineSpec.SINK_Y_TOP + MachineSpec.SINK_Y_BOTTOM) * 0.5
	var floor_depth := MachineSpec.FLOOR_Z_FRONT - MachineSpec.FLOOR_Z_BACK
	var floor_center_z := (MachineSpec.FLOOR_Z_FRONT + MachineSpec.FLOOR_Z_BACK) * 0.5

	# 払い出し口。前端を越えて落ちたコインを拾う。
	_add_sink(
		CoinSink.Kind.PAYOUT,
		Vector3(MachineSpec.FIELD_HALF_WIDTH * 2.4, sink_height, 1.2),
		Vector3(0.0, sink_center_y, MachineSpec.FLOOR_Z_FRONT + 0.6)
	)

	# サイドの落とし穴。床の縁と側壁のあいだ。
	for side in [-1.0, 1.0]:
		_add_sink(
			CoinSink.Kind.SIDE_LOSS,
			Vector3(MachineSpec.SIDE_GAP, sink_height, floor_depth),
			Vector3(
				side * (MachineSpec.FLOOR_HALF_WIDTH + MachineSpec.SIDE_GAP * 0.5),
				sink_center_y,
				floor_center_z
			)
		)

	# 最終防壁。ここに落ちてきたら床を貫通したということ。
	_add_sink(
		CoinSink.Kind.VOID,
		Vector3(
			MachineSpec.BOUNDS_HALF_X * 2.0,
			MachineSpec.VOID_Y_TOP - MachineSpec.VOID_Y_BOTTOM,
			MachineSpec.BOUNDS_Z_MAX - MachineSpec.BOUNDS_Z_MIN
		),
		Vector3(
			0.0,
			(MachineSpec.VOID_Y_TOP + MachineSpec.VOID_Y_BOTTOM) * 0.5,
			(MachineSpec.BOUNDS_Z_MAX + MachineSpec.BOUNDS_Z_MIN) * 0.5
		)
	)


func _add_sink(kind: int, size: Vector3, center: Vector3) -> void:
	var sink := CoinSink.create(kind, size, center)
	add_child(sink)
	sink.coin_sunk.connect(_on_coin_sunk)
	_sinks.append(sink)


func _physics_process(delta: float) -> void:
	# 設計書 4.5: 落ちたコインは 1 フレーム後にプールへ返却する。
	# 物理コールバックの最中にツリーから外すのは避ける。
	_flush_pending_releases()

	if not insert_enabled:
		return
	_insert_timer += delta
	if _insert_timer < insert_interval:
		return
	_insert_timer = 0.0
	if pool.active_count() < insert_ceiling:
		_insert()


## 実機は場にメダルが載った状態で稼働している。空の台から始めると山が前端に届かず、
## 押し出しそのものを観測できない。上下 2 段に 1 層ぶんを敷いてから運転を始める。
func _seed_field() -> void:
	var pitch := MachineSpec.COIN_RADIUS * 2.0 + 0.005
	var upper_back := MachineSpec.DECK_Z_FRONT + MachineSpec.COIN_RADIUS
	var upper_front := MachineSpec.PUSHER_Z_FRONT_HOME
	# 上段は後方デッキの壁に密着させたうえで 2 層積む。ここが離れていたり薄かったりすると、
	# 山はプッシャーと一緒に前後するだけで相対的に前へ進まない。
	# 壁が後退を止め、厚みが前へこぼれる圧力を生む。この 2 つが押し出しの正体。
	_seed_layer(MachineSpec.PUSHER_TOP_Y + 0.05, upper_back, upper_front, pitch, 0.0)
	_seed_layer(
		MachineSpec.PUSHER_TOP_Y + 0.10, upper_back + pitch * 0.5, upper_front, pitch, pitch * 0.5
	)
	# 下段はプッシャー前面に密着させる。ここが切れていると前面が空を押す。
	_seed_layer(
		MachineSpec.FLOOR_Y + 0.05,
		MachineSpec.PUSHER_Z_FRONT_HOME + MachineSpec.COIN_RADIUS,
		MachineSpec.FLOOR_Z_FRONT - MachineSpec.COIN_RADIUS,
		pitch,
		0.0
	)


func _seed_layer(y: float, z_start: float, z_end: float, pitch: float, x_offset: float) -> void:
	var x_limit := MachineSpec.FLOOR_HALF_WIDTH - MachineSpec.COIN_RADIUS
	var z := z_start
	while z <= z_end:
		var x := -x_limit + x_offset
		while x <= x_limit:
			pool.acquire(Vector3(x, y, z), _rng.randf_range(0.0, TAU))
			x += pitch
		z += pitch


func _insert() -> void:
	var origin := Vector3(
		_rng.randf_range(-MachineSpec.CHUTE_HALF_SPREAD, MachineSpec.CHUTE_HALF_SPREAD),
		MachineSpec.CHUTE_Y,
		MachineSpec.CHUTE_Z
	)
	pool.acquire(origin, _rng.randf_range(0.0, TAU))


func _flush_pending_releases() -> void:
	if _pending_release.is_empty():
		return
	for coin in _pending_release:
		pool.release(coin)
	_pending_release.clear()
	_pending_ids.clear()


func _on_coin_sunk(coin: Coin, kind: int) -> void:
	var id := coin.get_instance_id()
	if _pending_ids.has(id):
		return
	_pending_ids[id] = true
	_pending_release.append(coin)

	match kind:
		CoinSink.Kind.PAYOUT:
			payout_count += 1
		CoinSink.Kind.SIDE_LOSS:
			side_loss_count += 1
		CoinSink.Kind.VOID:
			void_count += 1


## 設計書 4.4: プッシャーが前進を開始したフレームで、前方一定範囲のコインを起こす。
## 全コインを走査せずに済むよう、判定は AABB ひとつで済ませる。
## プッシャー上面に載っているコインは Jolt が接触経由で自動的に起こす。
func _on_stroke_started(front_z: float) -> void:
	var wake_zone := AABB(
		Vector3(
			-MachineSpec.FIELD_HALF_WIDTH,
			MachineSpec.FLOOR_Y - 0.2,
			front_z - MachineSpec.COIN_RADIUS
		),
		Vector3(
			MachineSpec.FIELD_HALF_WIDTH * 2.0,
			MachineSpec.WALL_TOP_Y,
			MachineSpec.WAKE_DEPTH + MachineSpec.COIN_RADIUS
		)
	)
	for coin in pool.active_coins():
		if wake_zone.has_point(coin.position):
			coin.wake()
