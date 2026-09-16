class_name ValidationRunner
extends Node

## 設計書 3章 Phase 0 の合格基準を機械的に判定する。
##
## 充填 → 連続運転 → 静定 の 3 段階を回し、最後に PASS/FAIL を標準出力へ出して
## 終了コードで返す。ここを通過するまで他の実装に進まない。

enum Stage { FILL, SOAK, SETTLE, DONE }

## 山が静止したとみなす速度。これを超えるコインが残っていたらジッター扱い。
const JITTER_VELOCITY_EPS := 0.02
## 中心同士がこれより近いコインの組は、確実にめり込んでいる。
const INTERPENETRATION_EPS := 0.015
## 床の上面からこれだけ下にコインの中心があったら貫通。
const FLOOR_SINK_EPS := 0.10
## 120Hz を維持するための 1 フレームあたりの予算(ミリ秒)。
const FRAME_BUDGET_MS := 1000.0 / 120.0
## 連続運転に入ってからこの秒数は計測しない。
## 最初の数フレームはシェーダのコンパイル待ちで、定常性能を表さない。
const WARMUP_SECONDS := 2.0

var machine: PusherMachine
var soak_seconds := 300.0
var settle_seconds := 8.0
var fill_timeout_seconds := 180.0
var label := "run"
## 1 秒ごとに台の内部状態を吐く。原因調査用。
var trace := false

var _stage: int = Stage.FILL
var _stage_time := 0.0
var _headless := true

var _active_peak := 0
var _fill_timed_out := false
var _fill_seconds := 0.0

var _floor_penetrations := 0
var _wall_penetrations := 0
var _out_of_bounds := 0
var _geometry_timer := 0.0
var _trace_timer := 0.0

var _frame_ms: Array[float] = []
var _last_usec := 0
var _fps_min := INF
var _fps_sum := 0.0
var _fps_samples := 0

## 連続運転の終盤 1/3 に入った時点の払い出し数。初回ストロークの分だけで
## 「押し出せた」と誤判定しないための基準点。
var _payout_at_final_third := -1
var _active_at_end := 0

var _settle_awake := 0
var _settle_max_velocity := 0.0
var _interpenetrating_pairs := 0


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	print("[phase0] 検証開始 label=%s soak=%.0fs headless=%s" % [label, soak_seconds, _headless])


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_usec > 0 and _stage == Stage.SOAK and _stage_time >= WARMUP_SECONDS:
		_frame_ms.append(float(now - _last_usec) / 1000.0)
		if not _headless:
			var fps := Engine.get_frames_per_second()
			if fps > 0.0:
				_fps_min = minf(_fps_min, fps)
				_fps_sum += fps
				_fps_samples += 1
	_last_usec = now


func _physics_process(delta: float) -> void:
	_stage_time += delta
	_active_peak = maxi(_active_peak, machine.active_count())

	match _stage:
		Stage.FILL:
			if machine.active_count() >= MachineSpec.TARGET_ACTIVE:
				_enter_soak()
			elif _stage_time >= fill_timeout_seconds:
				_fill_timed_out = true
				_enter_soak()
		Stage.SOAK:
			_geometry_timer += delta
			if _geometry_timer >= 0.25:
				_geometry_timer = 0.0
				_check_geometry()
			if trace:
				_trace_timer += delta
				if _trace_timer >= 1.0:
					_trace_timer = 0.0
					_trace()
			if _payout_at_final_third < 0 and _stage_time >= soak_seconds * (2.0 / 3.0):
				_payout_at_final_third = machine.payout_count
			if _stage_time >= soak_seconds:
				_enter_settle()
		Stage.SETTLE:
			# 静定の後半だけを見る。前半は山が落ち着くまでの猶予。
			if _stage_time >= settle_seconds * 0.5:
				_sample_settle()
			if _stage_time >= settle_seconds:
				_finish()


func _enter_soak() -> void:
	_fill_seconds = _stage_time
	_stage = Stage.SOAK
	_stage_time = 0.0
	print("[phase0] 充填完了 %.1fs active=%d" % [_fill_seconds, machine.active_count()])


func _enter_settle() -> void:
	_stage = Stage.SETTLE
	_stage_time = 0.0
	_active_at_end = machine.active_count()
	machine.insert_enabled = false
	machine.pusher.running = false
	print("[phase0] 連続運転完了。プッシャーを停止して静定を待つ")


func _trace() -> void:
	var upper_count := 0
	var upper_front := -INF
	var upper_back := INF
	var lower_count := 0
	var lower_front := -INF
	var lower_back := INF
	var awake := 0
	for coin in machine.pool.active_coins():
		if not coin.sleeping:
			awake += 1
		var p := coin.global_position
		if p.y > MachineSpec.PUSHER_TOP_Y * 0.8:
			upper_count += 1
			upper_front = maxf(upper_front, p.z)
			upper_back = minf(upper_back, p.z)
		else:
			lower_count += 1
			lower_front = maxf(lower_front, p.z)
			lower_back = minf(lower_back, p.z)
	print(
		(
			"[trace] t=%5.1f pusher_front=%+.3f awake=%3d"
			+ " | 上段 %3d 枚 z=[%+.2f,%+.2f] | 下段 %3d 枚 z=[%+.2f,%+.2f] | 払出=%d 側落=%d"
		)
		% [
			_stage_time,
			machine.pusher.front_z(),
			awake,
			upper_count,
			upper_back,
			upper_front,
			lower_count,
			lower_back,
			lower_front,
			machine.payout_count,
			machine.side_loss_count,
		]
	)


## 台や壁を貫通していないか、吹き飛んでいないかを見る。
func _check_geometry() -> void:
	for coin in machine.pool.active_coins():
		var p := coin.global_position
		if (
			absf(p.x) > MachineSpec.BOUNDS_HALF_X
			or p.y < MachineSpec.BOUNDS_Y_MIN
			or p.y > MachineSpec.BOUNDS_Y_MAX
			or p.z < MachineSpec.BOUNDS_Z_MIN
			or p.z > MachineSpec.BOUNDS_Z_MAX
		):
			_out_of_bounds += 1
			continue
		# 床の footprint の内側にいながら床下に沈んでいたら貫通。
		# 落とし穴と前端は余裕をもって除外する。
		var inside_floor := (
			absf(p.x) < MachineSpec.FLOOR_HALF_WIDTH - 0.30
			and p.z > MachineSpec.FLOOR_Z_BACK + 0.30
			and p.z < MachineSpec.FLOOR_Z_FRONT - 0.50
		)
		if inside_floor and p.y < MachineSpec.FLOOR_Y - FLOOR_SINK_EPS:
			_floor_penetrations += 1
		if absf(p.x) > MachineSpec.FIELD_HALF_WIDTH + 0.06 and p.y > MachineSpec.WALL_BOTTOM_Y:
			_wall_penetrations += 1


func _sample_settle() -> void:
	var awake := 0
	var max_velocity := 0.0
	for coin in machine.pool.active_coins():
		if not coin.sleeping:
			awake += 1
		max_velocity = maxf(max_velocity, coin.linear_velocity.length())
	_settle_awake = awake
	_settle_max_velocity = max_velocity


## 山が静止した状態で、中心同士が重なっているコインの組を数える。
func _count_interpenetration() -> void:
	var coins := machine.pool.active_coins()
	var count := coins.size()
	var threshold_squared := INTERPENETRATION_EPS * INTERPENETRATION_EPS
	var pairs := 0
	for i in count:
		var a := coins[i].global_position
		for j in range(i + 1, count):
			if a.distance_squared_to(coins[j].global_position) < threshold_squared:
				pairs += 1
	_interpenetrating_pairs = pairs


func _finish() -> void:
	_stage = Stage.DONE
	set_physics_process(false)
	set_process(false)
	_count_interpenetration()
	var failures := _report()
	get_tree().quit(0 if failures == 0 else 1)


func _report() -> int:
	_frame_ms.sort()
	var frame_count := _frame_ms.size()
	var frame_total := 0.0
	for ms in _frame_ms:
		frame_total += ms
	var frame_avg := frame_total / float(frame_count) if frame_count > 0 else 0.0
	var frame_p99 := _frame_ms[int(frame_count * 0.99)] if frame_count > 0 else 0.0
	var frame_max := _frame_ms[frame_count - 1] if frame_count > 0 else 0.0

	var pool_total := machine.pool.total_count()
	var payout_per_min := float(machine.payout_count) / (soak_seconds / 60.0)
	var fps_avg := _fps_sum / float(_fps_samples) if _fps_samples > 0 else 0.0

	print("")
	print("==================================================")
	print(" Phase 0 コイン物理 検証結果  [%s]" % label)
	print("==================================================")
	print(" 充填            : %.1fs / peak %d 枚 / 終了時 %d 枚" % [
		_fill_seconds, _active_peak, _active_at_end
	])
	print(" 連続運転        : %.0fs" % soak_seconds)
	print(" 払い出し        : %d 枚 (%.1f 枚/分)" % [machine.payout_count, payout_per_min])
	print(" サイド落下      : %d 枚" % machine.side_loss_count)
	print(" 想定外の落下    : %d 枚" % machine.void_count)
	print(" プール収支      : %d / %d" % [pool_total, machine.pool_size])
	print(" 床の貫通        : %d 回" % _floor_penetrations)
	print(" 壁の貫通        : %d 回" % _wall_penetrations)
	print(" 境界外へ逸脱    : %d 回" % _out_of_bounds)
	print(" 静定時の起床数  : %d 枚 / 最大速度 %.4f m/s" % [_settle_awake, _settle_max_velocity])
	print(" めり込みの組    : %d" % _interpenetrating_pairs)
	print(" フレーム時間    : avg %.2fms / p99 %.2fms / max %.2fms (予算 %.2fms)" % [
		frame_avg, frame_p99, frame_max, FRAME_BUDGET_MS
	])
	if _headless:
		print(" 描画 fps        : 計測なし (headless)")
	else:
		print(" 描画 fps        : avg %.1f / min %.1f" % [fps_avg, _fps_min])
	print("--------------------------------------------------")

	var failures := 0
	failures += _criterion(
		"アクティブ 200 枚が山を形成した",
		_active_peak >= MachineSpec.TARGET_ACTIVE and not _fill_timed_out
	)
	failures += _criterion(
		"物理が 120Hz の予算に収まっている",
		frame_p99 <= FRAME_BUDGET_MS
	)
	if not _headless:
		failures += _criterion("描画 60fps を維持している", fps_avg >= 60.0 and _fps_min >= 55.0)
	failures += _criterion(
		"山が静止したときコインが震え続けない",
		_settle_awake == 0 and _settle_max_velocity < JITTER_VELOCITY_EPS
	)
	failures += _criterion(
		"台や他のコインを貫通しない",
		(
			_floor_penetrations == 0
			and _wall_penetrations == 0
			and machine.void_count == 0
			and _interpenetrating_pairs == 0
		)
	)
	# 初回ストロークで種まき分がこぼれただけの「動いていない台」を弾くため、
	# 終盤 1/3 でも払い出しが続いていることを要求する。
	var late_payout := machine.payout_count - maxi(_payout_at_final_third, 0)
	failures += _criterion(
		"プッシャーの前進で山が前方に押し出され続ける (終盤 %d 枚)" % late_payout,
		machine.payout_count > 0 and late_payout > 0
	)
	failures += _criterion(
		"連続運転でコインが吹き飛ぶ/消失しない",
		_out_of_bounds == 0 and pool_total == machine.pool_size
	)
	print("--------------------------------------------------")
	print(" RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	print("==================================================")
	return failures


func _criterion(description: String, passed: bool) -> int:
	print(" [%s] %s" % ["PASS" if passed else "FAIL", description])
	return 0 if passed else 1
