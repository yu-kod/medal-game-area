extends GdUnitTestSuite

## 実際に Jolt でメダルを動かして、衝突が報告されるところまでを通す。
##
## 物理の挙動(跳ね方や止まり方)そのものは固定しない。見るのは配線だけ。
##   - 床に落ちたら struck が出る。位置はワールド座標
##   - 止まったあとは出ない(静止中の見かけの接近速度で鳴り続けない)
##   - メダル同士の衝突は、どちらか一方だけが出す

## 原点に置くと、ローカル座標とワールド座標を取り違えても気づけない。ずらして置く。
const ORIGIN := Vector3(10.0, 5.0, 0.0)


func _floor() -> StaticBody3D:
	var body: StaticBody3D = auto_free(StaticBody3D.new())
	body.collision_layer = PhysicsLayers.FIELD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 0.2, 4)
	shape.shape = box
	body.add_child(shape)
	body.position = ORIGIN + Vector3(0, -0.1, 0)
	add_child(body)
	return body


func _medal() -> Medal:
	var medal: Medal = auto_free(
		Medal.create(
			MedalGeometry.build_collision_shape(),
			MedalGeometry.build_mesh(),
			MedalGeometry.build_material(),
			MedalGeometry.build_physics_material()
		)
	)
	add_child(medal)
	return medal


func _wait_physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func test_a_dropped_medal_reports_the_landing_in_world_space() -> void:
	_floor()
	var medal := _medal()
	var strikes: Array = []
	medal.struck.connect(func(approach: float, at: Vector3) -> void: strikes.append([approach, at]))

	medal.launch(Transform3D(Basis(Vector3.RIGHT, 0.3), ORIGIN + Vector3(0, 0.5, 0)))
	await _wait_physics(60)

	assert_int(strikes.size()).override_failure_message("床に落ちても衝突が報告されない").is_greater(0)
	# 0.5 の高さからの落下(重力 98)は約 9.9 で当たる。
	assert_float(strikes[0][0]).is_greater(5.0)
	# 当たった位置は床の上面あたり。ワールド座標で届く。
	var at: Vector3 = strikes[0][1]
	assert_float(at.y).is_between(ORIGIN.y - 0.1, ORIGIN.y + 0.2)
	assert_float(at.x).is_between(ORIGIN.x - 0.3, ORIGIN.x + 0.3)


func test_a_resting_medal_stays_silent_while_awake() -> void:
	# 眠ったメダルは _integrate_forces が呼ばれないので、眠らせたまま黙っていても
	# しきい値を確かめたことにならない。起こしたまま聞く。
	_floor()
	var medal := _medal()
	medal.can_sleep = false
	medal.launch(Transform3D(Basis.IDENTITY, ORIGIN + Vector3(0, 0.05, 0)))
	await _wait_physics(90)

	var strikes := 0
	medal.struck.connect(func(_approach: float, _at: Vector3) -> void: strikes += 1)
	await _wait_physics(120)

	assert_bool(medal.sleeping).override_failure_message("メダルが眠ってしまい、何も確かめていない").is_false()
	assert_int(strikes).override_failure_message("止まっているメダルが %d 回鳴った" % strikes).is_equal(0)


func test_two_medals_meeting_report_the_strike_once() -> void:
	# どちらも速く動いている状態で正面からぶつける(床なし、空中)。
	# 両方の剛体が同じ接触を見るので、報告を片方に絞れていないと 2 回鳴る。
	var lower := _medal()
	var upper := _medal()
	var reports: Array = []
	lower.struck.connect(
		func(approach: float, _at: Vector3) -> void:
			reports.append([Engine.get_physics_frames(), "lower", approach])
	)
	upper.struck.connect(
		func(approach: float, _at: Vector3) -> void:
			reports.append([Engine.get_physics_frames(), "upper", approach])
	)

	lower.launch(Transform3D(Basis.IDENTITY, ORIGIN + Vector3(0, 0.0, 0)), Vector3(0, 5, 0))
	upper.launch(Transform3D(Basis.IDENTITY, ORIGIN + Vector3(0, 0.4, 0)), Vector3(0, -5, 0))
	await _wait_physics(30)

	assert_int(reports.size()).override_failure_message("正面衝突が報告されない").is_greater(0)
	var first_frame: int = reports[0][0]
	var at_impact := reports.filter(func(entry: Array) -> bool: return entry[0] == first_frame)
	(
		assert_int(at_impact.size())
		. override_failure_message("同じ衝突が %d 回報告された: %s" % [at_impact.size(), str(at_impact)])
		. is_equal(1)
	)
	assert_float(at_impact[0][2]).is_greater(MedalStrike.AUDIBLE_APPROACH)


func test_medals_are_configured_to_report_contacts_without_the_contact_monitor() -> void:
	# 設定の見張り。接触が実際に届くことは上のテストが確かめている。
	#
	# 接触の中身を _integrate_forces に届けるのは max_contacts_reported。
	# contact_monitor(signal 用)は設計書 4.3 どおりオフのまま。オンにすると
	# 管理のコストだけが増えて音には使わない(#27 で実測)。
	var medal := _medal()
	assert_bool(medal.contact_monitor).is_false()
	assert_int(medal.max_contacts_reported).is_equal(MedalStrike.MAX_CONTACTS_REPORTED)
