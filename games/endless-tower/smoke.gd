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
	game.last_landing = 0
	game.score = 0
	game._break_combo()
	game._award_floor(1)
	assert(not game.flow_active and game.score == 10, "A one-floor jump scores without flow")
	game._award_floor(3)
	assert(game.flow_active and game.combo_steps == 2 and game.flow_burst > 0)
	game._tick_flow(0.1)
	assert(game.flow_trail.size() == 1)
	var burst: float = game.flow_burst
	game._award_floor(6)
	assert(game.combo_steps == 5 and game.combo_multiplier() == 2 and game.score == 90)
	assert(game.flow_burst == burst, "Continuing a combo must not repeat the activation burst")
	game._award_floor(7)
	assert(not game.flow_active and game.combo_steps == 0 and game.score == 100)
	assert(game.flow_trail.is_empty() and game.flow_burst == 0)
	game._award_floor(9)
	var earned: int = game.score
	game._award_floor(9)
	assert(not game.flow_active, "A same-floor landing must break flow")
	game._award_floor(11)
	earned = game.score
	game._award_floor(4)
	assert(not game.flow_active and game.last_landing == 4 and game.score == earned)
	game._award_floor(6)
	assert(game.flow_active and game.combo_steps == 2 and game.score == earned)
	assert(game.highest_landing == 11, "Revisiting old floors must not farm points")
	var strength: float = game.player.jump_strength()
	game._break_combo()
	assert(game.player.jump_strength() == strength, "Flow must not change jump physics")
	game._award_floor(8)
	game._tick_flow(0.1)
	# Exercise actual pause/journal handlers, freezing both combo time and effects.
	for action in ["pause", "journal"]:
		game._unhandled_input(_action(action))
		var frozen_top: float = game.camera_top
		var frozen_time: float = game.elapsed
		var frozen_combo: float = game.combo_time
		var frozen_burst: float = game.flow_burst
		var frozen_trail: Array = game.flow_trail.duplicate(true)
		game._physics_process(1.0)
		assert(game.camera_top == frozen_top and game.elapsed == frozen_time)
		assert(game.combo_time == frozen_combo and game.flow_burst == frozen_burst)
		assert(game.flow_trail == frozen_trail and game.flow_active)
		assert(not game.player.is_physics_processing() and not game.labels["flow"].visible)
		assert(game.journal.visible == (action == "journal"))
		game._unhandled_input(_action(action))
		assert(game.labels["flow"].visible)
	game.player.set_physics_process(false)
	for index in range(100):
		game._tick_flow(0.001)
	assert(game.flow_trail.size() <= 24, "Trail memory must stay bounded")
	game._tick_flow(game.COMBO_WINDOW)
	assert(not game.flow_active and game.combo_steps == 0 and game.flow_trail.is_empty())
	game._award_floor(10)
	assert(game.flow_active and game.combo_steps == 2, "An expired combo starts afresh")
	game._award_floor(50)
	assert(game.combo_multiplier() == 8, "Score multiplier is capped")
	game._tick_flow(0.1)
	game._finish()
	assert(not game.flow_active and game.flow_trail.is_empty() and game.flow_burst == 0)
	game._restart()
	game.player.set_physics_process(false)
	game._award_floor(3)
	game._tick_flow(0.1)
	game._restart()
	assert(game.last_landing == 0 and not game.flow_active and game.combo_time == 0)
	assert(game.flow_trail.is_empty() and game.flow_burst == 0 and not game.labels["flow"].visible)
	game.player.set_physics_process(false)
	var layout_checks = preload("res://layout_smoke.gd")
	layout_checks.run(game)
	await layout_checks.engine_transfers(game)
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
	game.player.position.y = game.Layout.floor_y(20, game.seed_value) - 10
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
		"PASS Endless Tower: physics movement/jumps, momentum, wall bounce, one-way landing, multi-floor flow activation/breaks/scoring/effects, pause/journal, 15000 motion-validated randomized floors, 1024 biome regions, bounded streaming, camera/fall, replay, all 16 motifs"
	)
