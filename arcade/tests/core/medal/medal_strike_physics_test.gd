extends GdUnitTestSuite

## 実際に Jolt でメダルを落として、衝突が報告されるところまでを通す。
##
## 物理の挙動(跳ね方や止まり方)そのものは固定しない。見るのは配線だけ。
##   - 床に落ちたら struck が出る
##   - 止まったあとは出ない(静止中の見かけの接近速度で鳴り続けない)


func _floor() -> StaticBody3D:
	var body: StaticBody3D = auto_free(StaticBody3D.new())
	body.collision_layer = PhysicsLayers.FIELD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 0.2, 4)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -0.1, 0)
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


func test_a_dropped_medal_reports_the_landing() -> void:
	_floor()
	var medal := _medal()
	var strikes: Array = []
	medal.struck.connect(func(approach: float, at: Vector3) -> void: strikes.append([approach, at]))

	medal.launch(Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 0.5, 0)))
	await _wait_physics(60)

	assert_int(strikes.size()).override_failure_message("床に落ちても衝突が報告されない").is_greater(0)
	# 0.5 の高さからの落下(重力 98)は約 9.9 で当たる。
	assert_float(strikes[0][0]).is_greater(5.0)
	# 当たった位置は床の上面あたり。
	assert_float(strikes[0][1].y).is_between(-0.1, 0.2)


func test_a_resting_medal_stays_silent() -> void:
	_floor()
	var medal := _medal()
	medal.launch(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await _wait_physics(90)

	var strikes := 0
	medal.struck.connect(func(_approach: float, _at: Vector3) -> void: strikes += 1)
	await _wait_physics(120)

	assert_int(strikes).override_failure_message("止まっているメダルが %d 回鳴った" % strikes).is_equal(0)


func test_contacts_reach_the_script_without_the_contact_monitor() -> void:
	# 接触の中身を _integrate_forces に届けるのは max_contacts_reported。
	# contact_monitor(signal 用)は設計書 4.3 どおりオフのまま。オンにすると
	# 管理のコストだけが増えて音には使わない(#27 で実測)。
	# 上の 2 つのテストは、このオフの状態で実際に衝突を拾えていることを確かめている。
	var medal := _medal()
	assert_bool(medal.contact_monitor).is_false()
	assert_int(medal.max_contacts_reported).is_equal(MedalStrike.MAX_CONTACTS_REPORTED)
