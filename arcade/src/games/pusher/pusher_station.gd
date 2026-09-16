class_name PusherStation
extends Node3D

## プッシャー島の 1 席ぶん。フィールド、プッシャー盤、投入レール、
## 払い出し口、受け皿、クレジット表示までが 1 セット。
##
## 還元率は乱数ではなく形状だけで決まる(設計書 5 章)。
## このファイルに払い出し確率や期待値の計算は一切無い。あってはならない。
##
## 前端からこぼれたメダルは消さずに受け皿へ落とし、そこに物理のまま溜める。
## プレイヤーが「回収」して初めてクレジットに乗る。実機のすくう動作にあたる。
##
## `simulated = false` の席は剛体を持たず、見た目だけの山を置く。
## 島の全席で物理を回すと 1800 剛体になって破綻するため。
##
## 入力は扱わない。操作は app 側の MachineControls が島越しに呼ぶ。

## メダルが払い出し口を通過した。音と演出の合図。
signal medal_paid
## メダルがサイドの落とし穴に落ちた。プレイヤーの損。
signal medal_lost
## メダルが投入された。
signal medal_inserted
## クレジットに乗った枚数。
signal medals_paid_out(count: int)
signal medals_consumed(count: int)
## 暖機が終わってプレイヤーに見せられる状態になった。
signal warmed_up

const SINK_PAYOUT := &"payout"
const SINK_SIDE := &"side_loss"
const SINK_VOID := &"void"
## 抽選の入口。通過を数えるだけで、メダルは消さない。
const SINK_CHUCKER := &"chucker"

## この席で物理を回すか。プレイヤーが遊んでいる席だけ true。
var simulated := true
## 席番号。乱数の種と静的な山の形を席ごとに変えるのに使う。
var station_index := 0

var wallet: PlayerWallet

## 自動投入。開発中に台の動きを見続けるためのもので、Phase 2 で外す。
var demo_running := false
## 検証用の投入ペース。実際に人が遊ぶ速さ(毎分 70 枚前後)に寄せてある。
## 遅いと盤面が定常状態に達する前に試験が終わってしまう。
var demo_interval := 0.85

## 場の枚数に上限は設けない。
##
## 投入そのものが押し出しの動力源なので、途中で投入を止める機構は台を殺す
## (Phase 0 の実測条件 3)。詰まるなら詰まったまま見せるのが正しい。
## 実効的な上限はプールの枚数(PusherSpec.POOL_SIZE)だけ。
## 場が増えすぎて描画が落ちるなら、それは形状の調整不足のサイン。

## 台の成績は「時間あたり」ではなく「投入 1 枚あたり」で測る。
##
## 手で遊ぶと投入ペースが不規則になり、手を止めている時間も混ざるので、
## 毎分の枚数は台の性質を表さない。投入枚数で正規化した払出率なら、
## 投入の速さにも途切れにも影響されず、形状だけを反映する。
## 設計書 6.4 の「毎分 8〜12 枚」は経済側(Phase 2)で人の投入ペースを決めてから換算する。
##
## 累計だけだと起動直後の「場が埋まる期間」がいつまでも残るので、
## 直近 RTP_WINDOW 枚ぶんの移動窓も併せて出す。
const RTP_WINDOW := 150

# --- 暖機(プレイヤーに見せる前の準備) ---
#
# メダルを格子状に置くと、盤の縁や床の継ぎ目にきっちり挟まった個体が残る。
# 実機の盤面は上から降ってきたメダルが自然に積もった形なので、こちらもそうする。
#
#   1. 上から降らせる(盤は止めたまま)
#   2. 静止するまで待つ
#   3. 盤を 1 往復させる  ← 挟まりや不安定な積みはここで崩れる
#   4. もう一度静止するまで待つ
#   5. 計数を 0 に戻してプレイヤーに見せる
#
# この間は盤面が落ち着いていないので、main が暗幕で隠して warmed_up を待つ。

## 落とし始める高さ。天板より下、山より上。
const DROP_HEIGHT := 2.4
## 1 物理ステップあたり何枚落とすか。多いと空中で団子になって落ち方が汚くなる。
const DROP_PER_TICK := 2
## 初期の場の枚数。
##
## 下段は 1 層ぶんで約 270 枚。1.3 層ほどしか無いと、押した力が
## メダルの隙間で途切れて前端まで繋がらない(実測 430 枚で 200 秒運転して払い出し 0)。
## 実機の盤面が働くのは 2 層以上に詰まっているからで、そこまで敷いてから始める。
const SEED_COUNT := 600
## 静止と判断する「まだ眠っていないメダル」の許容数。
const STILL_TOLERANCE := 4
## 静止待ちの上限。永久に止まらない形状のときの保険。
const SETTLE_TIMEOUT_SEC := 20.0

enum Warmup { DROPPING, SETTLING_AFTER_DROP, CYCLING, SETTLING_AFTER_CYCLE, READY }

var roulette: Roulette
var screen: RouletteScreen
var hopper: PayoutHopper

var chucker_count := 0
## 抽選が当てた枚数。**手取りではなく、ホッパーが盤面へ出した枚数**。
## ここから何枚を実際に取れるかは盤面の形状が決めるので、payout_count とは別勘定。
var lottery_reward := 0
var insert_count := 0
var payout_count := 0
var side_loss_count := 0
var void_count := 0

## 各投入時点の払い出し累計。移動窓の払出率を出すのに使う。
var _payout_at_insert: Array[int] = []
## 物理側で積んだ時間と、_physics_process が呼ばれた回数。
## 回数 / 時間 が physics_ticks_per_second に一致しないなら、
## delta が物理ステップ幅と違うということ。自動投入の間隔ずれの原因を切り分ける。
var physics_seconds := 0.0
var physics_ticks := 0
## 自動投入のタイマーが発火した回数。insert_count と食い違うなら、
## insert_medal がタイマー以外(入力など)からも呼ばれているということ。
var demo_fires := 0

var pool: MedalPool
var plate: PusherPlate
var rails: EntryRails
var audio: MachineAudio

var _sinks: Array[MedalSink] = []
var _warmup := Warmup.DROPPING
var _warmup_timer := 0.0
var _pending_release: Array[Medal] = []
var _pending_ids := {}
var _demo_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260816 + station_index
	if wallet == null:
		wallet = PlayerWallet.new()
	wallet.medals_changed.connect(_on_medals_changed)

	PusherField.build(self, simulated)
	PusherShell.build(self, simulated)

	plate = PusherPlate.create()
	add_child(plate)

	rails = EntryRails.create()
	add_child(rails)

	# 音は席ごとに持つ。AudioStreamPlayer3D なので席の位置から鳴る。
	# 遊んでいない席でも盤は動いているので、駆動音だけは鳴らす。
	audio = MachineAudio.new()
	audio.name = "Audio"
	add_child(audio)
	audio.start_motor()

	if not simulated:
		# 遊んでいない席。盤は動かすが、メダルは剛体を持たない見た目だけの山にする。
		add_child(PusherStaticPile.create(9001 + station_index * 37))
		set_physics_process(false)
		return

	# メダルの音は剛体が動いている席だけ。
	audio.attach(self)
	plate.stroke_started.connect(_on_stroke_started)

	pool = MedalPool.new()
	pool.name = "MedalPool"
	pool.pool_size = PusherSpec.POOL_SIZE
	add_child(pool)

	_build_sinks()
	_build_lottery()
	# 盤面は暖機で作る。止めた盤の上へ降らせて、積もってから 1 往復させる。
	plate.running = false
	_on_medals_changed(wallet.medals())


## この席の前に立った人の目線(席ローカル)。
func view_anchor() -> Transform3D:
	return Transform3D(Basis.IDENTITY, PusherSpec.VIEW_EYE).looking_at(
		PusherSpec.VIEW_TARGET, Vector3.UP
	)


## メダルを 1 枚投入する。手持ちが無ければ何も起きない。
##
## lane の符号が左右どちらの投入口かを表す。
## 投入そのものが押し出しの動力源なので、「場が満ちたら止める」判定は入れない。
func insert_medal(lane := 0.0) -> bool:
	if not simulated:
		return false
	if not wallet.spend_medal():
		return false
	var side := EntryRails.LEFT if lane < 0.0 else EntryRails.RIGHT
	# プールが尽きたときだけは投入できない。ここに来るのは設定ミス。
	var lean := _rng.randf_range(-PusherSpec.RAIL_SPAWN_LEAN, PusherSpec.RAIL_SPAWN_LEAN)
	var medal := pool.acquire(rails.spawn_transform(side, lean), rails.spawn_velocity(side))
	if medal == null:
		wallet.add_medals(1)
		return false
	insert_count += 1
	_payout_at_insert.append(payout_count)
	if _payout_at_insert.size() > RTP_WINDOW:
		_payout_at_insert.pop_front()
	medals_consumed.emit(1)
	medal_inserted.emit()
	return true


## 起動からの通算払出率。投入 1 枚あたり何枚返ってきたか。
func lifetime_payout_ratio() -> float:
	if insert_count == 0:
		return 0.0
	return float(payout_count) / float(insert_count)


## 直近 RTP_WINDOW 枚ぶんの払出率。場が埋まりきったあとの実力はこちらに出る。
func recent_payout_ratio() -> float:
	if _payout_at_insert.is_empty():
		return 0.0
	return float(payout_count - _payout_at_insert[0]) / float(_payout_at_insert.size())


func active_count() -> int:
	return pool.active_count() if pool != null else 0


func _physics_process(delta: float) -> void:
	# 落ちたメダルは 1 フレーム後にプールへ返す(設計書 4.5)。
	# 物理コールバックの最中にツリーから外すのは避ける。
	_flush_pending_releases()
	physics_seconds += delta
	physics_ticks += 1

	if _warmup != Warmup.READY:
		_advance_warmup(delta)
		return

	# 払い出し中の残り枚数を画面に出す。実機の「PAYOUT」表示にあたる。
	screen.set_payout_pending(hopper.pending())

	if not demo_running:
		return
	_demo_timer += delta
	if _demo_timer < demo_interval:
		return
	_demo_timer = 0.0
	demo_fires += 1
	# 人が左右の口を使い分けるのを真似る。払い出しの判定には一切関与しない。
	insert_medal(-1.0 if _rng.randf() < 0.5 else 1.0)


func _build_sinks() -> void:
	# 払い出し口の計数ゲート。ここは通過を数えるだけで、メダルは消さない。
	# 下の傾斜より上、フィールドの床より下の薄い層に置く。
	var gate_top := PusherSpec.FLOOR_Y - 0.10
	var gate_bottom := PusherSpec.RAMP_Y_BACK
	_add_sink(
		SINK_PAYOUT,
		Vector3(
			PusherSpec.LOWER_HALF_WIDTH * 2.0,
			gate_top - gate_bottom,
			PusherSpec.MOUTH_Z_FRONT - PusherSpec.MOUTH_Z_BACK
		),
		Vector3(
			0.0,
			(gate_top + gate_bottom) * 0.5,
			(PusherSpec.MOUTH_Z_FRONT + PusherSpec.MOUTH_Z_BACK) * 0.5
		)
	)

	# 横穴(アウトゾーン)。壁の穴をくぐった先、壁の裏の回収路で検出する。
	# プレイヤーからは見えない場所なので、落ちた瞬間に消えても不自然にならない。
	var chute_inner := PusherSpec.LOWER_HALF_WIDTH + PusherField.WALL_THICKNESS
	var chute_width := PusherSpec.OUT_CHUTE_HALF_WIDTH * 2.0
	var out_height := PusherSpec.OUT_SINK_Y_TOP - PusherSpec.OUT_SINK_Y_BOTTOM
	var out_depth := PusherSpec.OUT_Z_FRONT - PusherSpec.OUT_Z_BACK
	for side in [-1.0, 1.0]:
		_add_sink(
			SINK_SIDE,
			Vector3(chute_width, out_height, out_depth),
			Vector3(
				side * (chute_inner + chute_width * 0.5),
				(PusherSpec.OUT_SINK_Y_TOP + PusherSpec.OUT_SINK_Y_BOTTOM) * 0.5,
				(PusherSpec.OUT_Z_BACK + PusherSpec.OUT_Z_FRONT) * 0.5
			)
		)

	# 最終防壁。ここに落ちてきたら床を貫通したということ。
	_add_sink(
		SINK_VOID,
		Vector3(
			PusherSpec.BOUNDS_HALF_X * 2.0,
			PusherSpec.VOID_Y_TOP - PusherSpec.VOID_Y_BOTTOM,
			PusherSpec.BOUNDS_Z_MAX - PusherSpec.BOUNDS_Z_MIN
		),
		Vector3(
			0.0,
			(PusherSpec.VOID_Y_TOP + PusherSpec.VOID_Y_BOTTOM) * 0.5,
			(PusherSpec.BOUNDS_Z_MAX + PusherSpec.BOUNDS_Z_MIN) * 0.5
		)
	)


## 抽選まわり。チェッカーの検知領域、抽選そのもの、背面の画面。
##
## センサーは穴の下のシュートの中に置く。空中ではない。
## メダルは穴に入って落ちるか入らないかのどちらかで、途中に留まれない。
## だから「シュートを通った」という事実だけで判定でき、速度も姿勢も見なくて済む。
func _build_lottery() -> void:
	_add_sink(
		SINK_CHUCKER,
		Vector3(
			PusherSpec.CHUCKER_HALF_WIDTH * 2.0,
			PusherSpec.CHUCKER_SINK_Y_TOP - PusherSpec.CHUCKER_SINK_Y_BOTTOM,
			PusherSpec.CHUCKER_Z_FRONT - PusherSpec.CHUCKER_Z_BACK
		),
		Vector3(
			0.0,
			(PusherSpec.CHUCKER_SINK_Y_TOP + PusherSpec.CHUCKER_SINK_Y_BOTTOM) * 0.5,
			(PusherSpec.CHUCKER_Z_BACK + PusherSpec.CHUCKER_Z_FRONT) * 0.5
		)
	)

	screen = RouletteScreen.create()
	add_child(screen)

	hopper = PayoutHopper.create(70001 + station_index)
	hopper.pool = pool
	add_child(hopper)

	roulette = Roulette.new()
	roulette.name = "Roulette"
	add_child(roulette)
	roulette.stock_changed.connect(func(value: int) -> void: screen.set_stock(value))
	roulette.spin_started.connect(
		func(outcome: int) -> void: screen.start_spin(outcome, Roulette.SPIN_SEC)
	)
	roulette.spin_finished.connect(_on_spin_finished)


## 抽選の結果が出た。当たっていればホッパーに払い出しを予約する。
##
## クレジットには足さない。メダルは画面の下の口から実物として上段へ出てきて、
## そこから先はふつうのメダルと同じ扱いになる。押されて前端から落ちて初めて
## プレイヤーのものになるので、当たり枚数がそのまま手取りにはならない。
##
## この分離のおかげで、抽選の確率(Roulette.TABLE)と盤面の形状が
## 別々の役割のまま噛み合う。乱数は盤面の払い出しに一切触れない。
func _on_spin_finished(outcome: int, reward: int) -> void:
	screen.show_result(outcome)
	if reward <= 0:
		return
	lottery_reward += reward
	hopper.enqueue(reward)


func _add_sink(tag: StringName, size: Vector3, center: Vector3) -> void:
	var sink := MedalSink.create(tag, size, center)
	add_child(sink)
	sink.medal_sunk.connect(_on_medal_sunk)
	_sinks.append(sink)


## 暖機の 1 ステップ。プレイヤーに見せる前の盤面づくり。
## 落とす → 静まるのを待つ → 盤を 1 往復 → もう一度静まるのを待つ。
func _advance_warmup(delta: float) -> void:
	_warmup_timer += delta

	match _warmup:
		Warmup.DROPPING:
			for i in DROP_PER_TICK:
				if pool.active_count() >= SEED_COUNT:
					_enter_warmup(Warmup.SETTLING_AFTER_DROP)
					return
				_drop_one()

		Warmup.SETTLING_AFTER_DROP:
			if _is_field_still() or _warmup_timer > SETTLE_TIMEOUT_SEC:
				plate.running = true
				_enter_warmup(Warmup.CYCLING)

		Warmup.CYCLING:
			# 挟まったメダルや不安定な積みは、盤が 1 往復すれば崩れる。
			if _warmup_timer >= PusherSpec.PUSHER_CYCLE_SEC:
				plate.running = false
				_enter_warmup(Warmup.SETTLING_AFTER_CYCLE)

		Warmup.SETTLING_AFTER_CYCLE:
			if _is_field_still() or _warmup_timer > SETTLE_TIMEOUT_SEC:
				_finish_warmup()


func _enter_warmup(next: int) -> void:
	_warmup = next
	_warmup_timer = 0.0


func _finish_warmup() -> void:
	_warmup = Warmup.READY
	plate.running = true
	# 暖機中に前端からこぼれたぶんは成績ではない。計器を 0 に戻す。
	insert_count = 0
	payout_count = 0
	chucker_count = 0
	lottery_reward = 0
	side_loss_count = 0
	void_count = 0
	demo_fires = 0
	physics_seconds = 0.0
	_payout_at_insert.clear()
	warmed_up.emit()


## 盤面の上から 1 枚落とす。落とす場所はばらす。
## 上段は投入レールの下を避ける。レールに載ると転がって出てこない。
func _drop_one() -> void:
	var x_limit := PusherSpec.WALL_X_INNER - MedalSpec.RADIUS - 0.02
	var z_min: float
	var z_max: float
	# 上段と下段の面積比で振り分ける。
	if _rng.randf() < 0.28:
		z_min = PusherSpec.RAIL_Z + 0.30
		z_max = PusherSpec.PUSHER_Z_FRONT_HOME - MedalSpec.RADIUS
	else:
		z_min = PusherSpec.PUSHER_Z_FRONT_HOME + MedalSpec.RADIUS
		z_max = PusherSpec.FLOOR_Z_FRONT - PusherSpec.EDGE_DEPTH - MedalSpec.RADIUS
	if z_max <= z_min:
		return
	# 前寄りに厚く積む。均一に降らせると前端が薄いままで、
	# 押しても前端まで圧力が届かず払い出しが出ない。
	var bias := sqrt(_rng.randf())
	pool.acquire_flat(
		Vector3(
			_rng.randf_range(-x_limit, x_limit),
			DROP_HEIGHT + _rng.randf_range(0.0, 0.4),
			lerpf(z_min, z_max, bias)
		),
		_rng.randf_range(0.0, TAU)
	)


## 盤面が落ち着いたか。Jolt が眠らせた枚数で見る。
## 盤を止めているあいだしか正しく判定できない(動く盤は接触で起こし続けるため)。
func _is_field_still() -> bool:
	var moving := 0
	for medal in pool.active_medals():
		if not medal.sleeping:
			moving += 1
			if moving > STILL_TOLERANCE:
				return false
	return true


func _flush_pending_releases() -> void:
	if _pending_release.is_empty():
		return
	for medal in _pending_release:
		pool.release(medal)
	_pending_release.clear()
	_pending_ids.clear()


## 前端を越えたメダルは、その場で機械的に回収してクレジットに計上する。
##
## 実機の払い出しも、プレイヤーが皿から拾うのではなく機械が数えて計上する。
## メダルを受け皿まで物理で運んで溜めると、見えない場所に剛体が積み上がるだけで
## 負荷にしかならない。落ちた時点で数えてプールへ返す。
func _on_medal_sunk(medal: Medal, tag: StringName) -> void:
	var id := medal.get_instance_id()

	if _pending_ids.has(id):
		return
	_pending_ids[id] = true
	_pending_release.append(medal)

	# 暖機中に落ちたぶんは成績ではない。数えずにプールへ返すだけ。
	# 減った枚数は落下がまだ続いていれば補充される。
	if _warmup != Warmup.READY:
		return

	match tag:
		SINK_CHUCKER:
			# 穴に落ちたメダルはシュートを通って回収される。抽選の権利と引き換え。
			chucker_count += 1
			roulette.add_stock()
		SINK_PAYOUT:
			payout_count += 1
			wallet.add_medals(1)
			medals_paid_out.emit(1)
			medal_paid.emit()
		SINK_SIDE:
			side_loss_count += 1
			medal_lost.emit()
		SINK_VOID:
			void_count += 1


## 設計書 4.4: プッシャーが前進を開始したフレームで、前方一定範囲のメダルを起こす。
## 全メダルを走査せずに済むよう、判定は AABB ひとつで済ませる。
## プッシャー上面に載っているメダルは Jolt が接触経由で自動的に起こす。
func _on_stroke_started(front_z: float) -> void:
	var wake_zone := AABB(
		Vector3(-PusherSpec.FIELD_HALF_WIDTH, PusherSpec.FLOOR_Y - 0.2, front_z - MedalSpec.RADIUS),
		Vector3(
			PusherSpec.FIELD_HALF_WIDTH * 2.0,
			PusherSpec.WALL_TOP_Y,
			PusherSpec.WAKE_DEPTH + MedalSpec.RADIUS
		)
	)
	for medal in pool.active_medals():
		if wake_zone.has_point(medal.position):
			medal.wake()


## クレジットはモニターの右下に出す。筐体側の読み取り表示は持たない。
func _on_medals_changed(medals: int) -> void:
	if screen != null:
		screen.set_credit(medals)
