extends GdUnitTestSuite

## メダルのオブジェクトプール(設計書 4.5)の収支と境界。
##
## ここが崩れても症状が出るのは数十秒後で、「メダルが出てこない」という
## 遠い形でしか現れない。取りこぼしをその場で捕まえるためのテスト。

## 枯渇の境界を安く踏むための枚数。既定の 700 枚は要らない。
const POOL_SIZE := 5


## ツリーに入れて初めて中身が作られる。pool_size は入れる前に上書きする。
func _pool(size: int = POOL_SIZE) -> MedalPool:
	var pool: MedalPool = auto_free(MedalPool.new())
	pool.pool_size = size
	add_child(pool)
	return pool


# --- 初期状態 ---


func test_pool_is_filled_on_entering_the_tree() -> void:
	var pool := _pool()
	assert_int(pool.idle_count()).is_equal(POOL_SIZE)
	assert_int(pool.active_count()).is_equal(0)


# --- 枯渇 ---


func test_acquire_returns_a_medal_while_stock_remains() -> void:
	var pool := _pool()
	assert_object(pool.acquire(Transform3D.IDENTITY)).is_not_null()
	assert_int(pool.active_count()).is_equal(1)
	assert_int(pool.idle_count()).is_equal(POOL_SIZE - 1)


func test_acquire_returns_null_once_exhausted() -> void:
	var pool := _pool()
	for i in POOL_SIZE:
		assert_object(pool.acquire(Transform3D.IDENTITY)).is_not_null()

	# 境界: 在庫を使い切った直後。例外でも停止でもなく null で返ること。
	assert_object(pool.acquire(Transform3D.IDENTITY)).is_null()
	assert_int(pool.active_count()).is_equal(POOL_SIZE)
	assert_int(pool.idle_count()).is_equal(0)


func test_exhausted_pool_recovers_after_release() -> void:
	var pool := _pool()
	var taken: Array[Medal] = []
	for i in POOL_SIZE:
		taken.append(pool.acquire(Transform3D.IDENTITY))
	assert_object(pool.acquire(Transform3D.IDENTITY)).is_null()

	assert_bool(pool.release(taken[0])).is_true()
	assert_object(pool.acquire(Transform3D.IDENTITY)).is_not_null()


# --- 返却 ---


func test_release_moves_the_medal_back_to_idle() -> void:
	var pool := _pool()
	var medal := pool.acquire(Transform3D.IDENTITY)

	assert_bool(pool.release(medal)).is_true()
	assert_int(pool.active_count()).is_equal(0)
	assert_int(pool.idle_count()).is_equal(POOL_SIZE)


func test_releasing_twice_is_refused() -> void:
	var pool := _pool()
	var medal := pool.acquire(Transform3D.IDENTITY)
	assert_bool(pool.release(medal)).is_true()

	# ここが通ってしまうと同じメダルが待機列に 2 枚積まれ、
	# 1 枚のメダルが 2 枚に見える状態になる。
	assert_bool(pool.release(medal)).is_false()
	assert_int(pool.idle_count()).is_equal(POOL_SIZE)
	assert_int(pool.total_count()).is_equal(POOL_SIZE)


func test_releasing_a_foreign_medal_is_refused() -> void:
	var pool := _pool()
	var outsider: Medal = auto_free(
		Medal.create(
			MedalGeometry.build_collision_shape(),
			MedalGeometry.build_mesh(),
			MedalGeometry.build_material(),
			MedalGeometry.build_physics_material()
		)
	)

	assert_bool(pool.release(outsider)).is_false()
	assert_int(pool.total_count()).is_equal(POOL_SIZE)


# --- 収支 ---


func test_balance_holds_across_repeated_acquire_and_release() -> void:
	var pool := _pool()
	for round_index in 20:
		var taken: Array[Medal] = []
		for i in 3:
			var medal := pool.acquire(Transform3D.IDENTITY)
			if medal != null:
				taken.append(medal)
		for medal in taken:
			pool.release(medal)

		# 何度回しても 1 枚も増えず、1 枚も消えない。
		(
			assert_int(pool.total_count())
			. override_failure_message(
				"%d 巡目でプールの収支が %d 枚(本来 %d 枚)" % [round_index, pool.total_count(), POOL_SIZE]
			)
			. is_equal(POOL_SIZE)
		)
		assert_int(pool.active_count() + pool.idle_count()).is_equal(POOL_SIZE)


func test_acquire_flat_keeps_the_same_balance() -> void:
	var pool := _pool()
	var medal := pool.acquire_flat(Vector3.ZERO, 0.0)

	assert_object(medal).is_not_null()
	assert_int(pool.active_count()).is_equal(1)
	assert_int(pool.total_count()).is_equal(POOL_SIZE)


func test_active_medals_lists_exactly_what_was_acquired() -> void:
	var pool := _pool()
	var first := pool.acquire(Transform3D.IDENTITY)
	var second := pool.acquire(Transform3D.IDENTITY)

	var active := pool.active_medals()
	assert_int(active.size()).is_equal(2)
	assert_bool(active.has(first)).is_true()
	assert_bool(active.has(second)).is_true()

	pool.release(first)
	assert_bool(pool.active_medals().has(first)).is_false()
