extends RefCounted


static func _frames(game, count: int) -> void:
	for index in range(count):
		await game.get_tree().physics_frame


static func _action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


static func run(game) -> void:
	game.seed_value = 12345
	game._restart()
	game.elapsed = 5000.0
	assert(game.scroll_speed() == 10.0, "Reading the intro must not increase difficulty")
	await _frames(game, 40)
	assert(game.player.is_on_floor(), "The climber must settle on the starting floor")
	assert(game.platforms.size() < 32)
	var initial_x: float = game.player.position.x
	Input.action_press("move_right")
	await _frames(game, 12)
	assert(game.player.position.x > initial_x + 10 and game.player.velocity.x > 200)
	Input.action_press("jump")
	await _frames(game, 2)
	Input.action_release("jump")
	Input.action_release("move_right")
	assert(game.player.velocity.y < -600 and game.started, "Jump must lift the actual physics body")
	game.player.velocity.x = 0
	var standing_jump: float = game.player.jump_strength()
	game.player.velocity.x = game.Climber.MAX_SPEED
	assert(game.player.jump_strength() > standing_jump + 250, "Momentum must give a higher jump")
	game._restart()
	await _frames(game, 25)
	game.player.position.x = game.Layout.RIGHT - game.Climber.HALF_WIDTH + 3
	game.player.velocity.x = 600
	await _frames(game, 3)
	assert(game.player.position.x <= game.Layout.RIGHT - game.Climber.HALF_WIDTH + 0.1)
	assert(game.player.velocity.x < 0, "Walls must reflect horizontal momentum")
	# Pass through the underside, then land on the top of the very same one-way floor.
	game._restart()
	await _frames(game, 3)
	var first: Rect2 = game.Layout.platform(1, game.seed_value)
	game.player.position = Vector2(first.get_center().x, first.position.y + 60)
	game.player.velocity = Vector2(0, -680)
	await _frames(game, 10)
	assert(game.player.position.y < first.position.y, "One-way floors must allow upward passage")
	await _frames(game, 85)
	assert(
		game.player.is_on_floor() and game.highest_landing >= 1, "Descending must land and score"
	)
	game.player.set_physics_process(false)
	game.highest_landing = 0
	game.score = 0
	game.combo_steps = 0
	game.combo_time = 0
	game._award_floor(3)
	game._award_floor(7)
	assert(game.combo_steps == 7 and game.score > 70)
	var earned: int = game.score
	game._award_floor(7)
	game._award_floor(2)
	assert(game.score == earned, "Revisiting floors must not farm points")
	game._physics_process(3.0)
	assert(game.combo_steps == 0)
	# Exercise actual pause/journal handlers, including the player's process state.
	game._unhandled_input(_action("pause"))
	var frozen_top: float = game.camera_top
	var frozen_time: float = game.elapsed
	game._physics_process(1.0)
	assert(game.paused and game.camera_top == frozen_top and game.elapsed == frozen_time)
	assert(not game.player.is_physics_processing())
	game._unhandled_input(_action("pause"))
	game._unhandled_input(_action("journal"))
	assert(game.journal.visible and not game.player.is_physics_processing())
	game._unhandled_input(_action("journal"))
	assert(not game.journal.visible)
	game.player.set_physics_process(false)
	# A repeatable route with overlap between adjacent floors, even far up the tower.
	for route_seed in [1, 12345, 987654321]:
		var previous: Rect2 = game.Layout.platform(0, route_seed)
		for floor_id in range(1, 5001):
			var rect: Rect2 = game.Layout.platform(floor_id, route_seed)
			assert(rect == game.Layout.platform(floor_id, route_seed))
			assert(rect.position.x >= game.Layout.LEFT and rect.end.x <= game.Layout.RIGHT)
			assert(rect.position.x < previous.end.x and rect.end.x > previous.position.x)
			var gap := previous.position.y - rect.position.y
			var minimum_jump_height: float = (
				pow(game.Climber.BASE_JUMP, 2) / (2 * game.Climber.GRAVITY)
			)
			assert(gap > 0 and gap < minimum_jump_height - 20)
			previous = rect
	assert(game.Layout.platform(9, 1) != game.Layout.platform(9, 12345))
	# Generated regions keep distinct identities beyond all 16 hand-authored families.
	var names := {}
	for region in range(1024):
		var data: Dictionary = game.Biomes.at_floor(region * game.Biomes.FLOORS_PER_BIOME)
		assert(not names.has(data["name"]))
		names[data["name"]] = true
		assert(data["family_id"] == region % 16)
		assert(data["friction"] >= 0.5 and data["jump_bonus"] >= 0)
	assert(game.Biomes.at_floor(0)["name"] != game.Biomes.at_floor(320)["name"])
	game.reached_floor = 0
	game.player.position.y = game.Layout.START_Y - 20.5 * game.Layout.GAP
	game._track_height()
	assert(game.reached_floor == 20 and game.biome["family_id"] == 1)
	game.player.position.y = game.Layout.START_Y - 40
	game._track_height()
	assert(game.reached_floor == 20, "A short fall must not revoke a biome discovery")
	# Streaming must remain small and skip directly to a distant visible range.
	for index in range(24):
		game.camera_top = -float(index) * 10000
		game._update_platforms()
		assert(game.platforms.size() < 32)
		await game.get_tree().process_frame
	game.camera_top = -1000000.0
	game._update_platforms()
	assert(game.platforms.size() < 32 and game.next_floor > 11000)
	await game.get_tree().process_frame
	# Camera pressure, fall failure, and same-seed replay are part of the real loop.
	game._restart()
	game.player.set_physics_process(false)
	game.started = true
	game.player.position.y = 200
	game._physics_process(0.1)
	assert(game.camera_top < 0 and game.scroll_speed() <= 62)
	game.player.position.y = game.camera_top + 900
	game._physics_process(0.01)
	assert(game.game_over and not game.player.is_physics_processing())
	game._unhandled_input(_action("restart"))
	assert(not game.game_over and game.seed_value == 12345 and game.score == 0)
	assert(game.Layout.platform(1, game.seed_value) == first)
	game.player.set_physics_process(false)
	# Every visual motif and its HUD can be selected without changing the platform.
	for region in range(16):
		game.biome = game.Biomes.at_floor(region * 20)
		game._update_hud()
		game.queue_redraw()
		await game.get_tree().process_frame
	game.biome = game.Biomes.at_floor(0)
	game._update_hud()
	print(
		"PASS Endless Tower: physics movement/jumps, momentum, wall bounce, one-way landing, combos, pause/journal, 15000 reachable seeded floors, 1024 biome regions, bounded streaming, camera/fall, replay, all 16 motifs"
	)
