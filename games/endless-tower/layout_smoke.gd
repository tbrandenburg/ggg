extends RefCounted

const Jump := preload("res://jump_model.gd")


static func run(game) -> void:
	for family in range(game.Biomes.FAMILIES.size()):
		var biome: Dictionary = game.Biomes.at_floor(family * 20)
		assert(float(biome["friction"]) >= Jump.MIN_FRICTION)
		assert(absf(float(biome["wind"])) <= Jump.WORST_WIND)
		assert(float(biome["jump_bonus"]) >= 0)
	var air_gaps := 0
	var narrowest := INF
	var widest := 0.0
	var shortest_gap := INF
	var tallest_gap := 0.0
	for route_seed in [1, 12345, 987654321]:
		var previous: Rect2 = game.Layout.platform(0, route_seed)
		for floor_id in range(1, 5001):
			var rect: Rect2 = game.Layout.platform(floor_id, route_seed)
			assert(rect == game.Layout.platform(floor_id, route_seed))
			assert(rect.position.x >= game.Layout.LEFT and rect.end.x <= game.Layout.RIGHT)
			assert(
				Jump.reachable(previous, rect),
				"Every edge, including a chunk seam, needs a jump witness"
			)
			var rise := previous.position.y - rect.position.y
			assert(rise >= 61.8 and rise <= 106.2)
			assert(rect.size.x >= 60 and rect.size.x <= 282)
			if rect.position.x >= previous.end.x or previous.position.x >= rect.end.x:
				air_gaps += 1
			narrowest = minf(narrowest, rect.size.x)
			widest = maxf(widest, rect.size.x)
			shortest_gap = minf(shortest_gap, rise)
			tallest_gap = maxf(tallest_gap, rise)
			previous = rect
	assert(air_gaps > 300, "Random placement must include genuine gaps, not only overlap")
	assert(widest - narrowest > 160 and tallest_gap - shortest_gap > 40)
	print(
		(
			"LAYOUT STATS: air gaps=%d widths=%.1f..%.1f rises=%.1f..%.1f"
			% [air_gaps, narrowest, widest, shortest_gap, tallest_gap]
		)
	)
	# Balanced shuffled widths enforce smaller means while preserving local fluctuation.
	var previous_mean := 1000.0
	for level in range(1, 17):
		var sum_width := 0.0
		var low := INF
		var high := 0.0
		for offset in range(20):
			var width: float = game.Layout.platform(level * 20 + offset, 12345).size.x
			sum_width += width
			low = minf(low, width)
			high = maxf(high, width)
		var mean := sum_width / 20
		assert(is_equal_approx(mean, game.Layout.mean_width(level)))
		assert(mean < previous_mean)
		assert(high - low > mean * 0.45)
		previous_mean = mean
	# Distant access and cache eviction must not change an earlier seed's route.
	var saved: Rect2 = game.Layout.platform(99, 12345)
	for index in range(40):
		game.Layout.platform(100000 + index * 20, 1)
		assert(game.Layout.cache_size() <= game.Layout.CACHE_LIMIT)
	assert(saved == game.Layout.platform(99, 12345))
	assert(game.Layout.platform(9, 1) != game.Layout.platform(9, 12345))
	for floor_id in [0, 1, 19, 20, 21, 39, 40, 99, 1000, 100000]:
		var y: float = game.Layout.floor_y(floor_id, 12345)
		assert(game.Layout.floor_at_y(y - 1, 12345) == floor_id)
	assert(not Jump.reachable(Rect2(300, 640, 100, 14), Rect2(300, 400, 100, 14)))
	assert(not Jump.reachable(Rect2(260, 640, 70, 14), Rect2(820, 550, 70, 14)))
	print(
		"PASS randomized layout: 15000 motion-validated edges, shrinking level means, varied widths/rises, real air gaps, deterministic seams, height lookup, bounded cache"
	)


static func engine_transfers(game) -> void:
	# This independent check uses the real CharacterBody2D, not the analytical model.
	for case_index in range(8):
		var floor_id: int = [0, 18, 19, 20, 63, 125, 299, 500][case_index]
		game.seed_value = 12345 if case_index % 2 == 0 else 987654321
		game._restart()
		game.player.set_physics_process(false)
		var source: Rect2 = game.Layout.platform(floor_id, game.seed_value)
		var target: Rect2 = game.Layout.platform(floor_id + 1, game.seed_value)
		game.camera_top = source.position.y - 640
		game._update_platforms()
		for entry in game.platforms:
			if entry["id"] not in [floor_id, floor_id + 1]:
				entry["body"].collision_layer = 0
		game.player.position = Vector2(source.get_center().x, source.position.y - 23)
		game.player.velocity = Vector2.ZERO
		game.player.friction_factor = Jump.MIN_FRICTION
		game.player.biome_jump_bonus = 0
		game.player.wind = -Jump.WORST_WIND if case_index % 2 == 0 else Jump.WORST_WIND
		game.player.set_physics_process(true)
		for frame in range(12):
			await game.get_tree().physics_frame
		assert(game.player.is_on_floor())
		Input.action_press("jump")
		var airborne := false
		var landed := false
		for frame in range(100):
			var direction := Jump.steering(
				game.player.position.x, game.player.velocity.x, target.get_center().x
			)
			Input.action_release("move_left")
			Input.action_release("move_right")
			if direction < 0:
				Input.action_press("move_left")
			elif direction > 0:
				Input.action_press("move_right")
			if frame == 2:
				Input.action_release("jump")
			await game.get_tree().physics_frame
			if not game.player.is_on_floor():
				airborne = true
			if airborne and game.player.is_on_floor():
				landed = game.highest_landing == floor_id + 1
				break
		Input.action_release("jump")
		Input.action_release("move_left")
		Input.action_release("move_right")
		assert(landed, "Real physics must land on generated transfer %d" % floor_id)
		print("PASS real jump transfer ", floor_id)
	game.seed_value = 12345
	game._restart()
	game.player.set_physics_process(false)
