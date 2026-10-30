extends Node2D
## An original momentum climber. All generation, artwork, and progression live here.

const Biomes := preload("res://biomes.gd")
const Layout := preload("res://layout.gd")
const Climber := preload("res://player.gd")
const Smoke := preload("res://smoke.gd")
const VIEW_HEIGHT := 720.0
const INK := Color("142d46")
const PAPER := Color("eef4ed")

var player: CharacterBody2D
var camera: Camera2D
var platforms: Array[Dictionary] = []
var next_floor := 0
var seed_value := 20261030
var camera_top := 0.0
var elapsed := 0.0
var climb_time := 0.0
var started := false
var paused := false
var journal_open := false
var game_over := false
var reached_floor := 0
var highest_landing := 0
var best_floor := 0
var best_score := 0
var score := 0
var combo_steps := 0
var combo_time := 0.0
var biome: Dictionary
var labels: Dictionary = {}
var trail_labels: Array[Label] = []
var speed_bar: ProgressBar
var combo_bar: ProgressBar
var journal: PanelContainer
var journal_text: Label
var smoke_mode := false


func _ready() -> void:
	smoke_mode = "--smoke-test" in OS.get_cmdline_user_args()
	_setup_input()
	_load_stats()
	biome = Biomes.at_floor(0)
	camera = Camera2D.new()
	add_child(camera)
	player = Climber.new()
	add_child(player)
	player.jumped.connect(_on_jump)
	player.landed.connect(_on_landing)
	_build_hud()
	_restart()
	if smoke_mode:
		set_physics_process(false)
		call_deferred("_smoke_test")


func _setup_input() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"pause": [KEY_P],
		"journal": [KEY_B],
		"restart": [KEY_R],
		"new_route": [KEY_N],
		"leave": [KEY_ESCAPE],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


func _restart() -> void:
	_persist()
	for entry in platforms:
		entry["body"].queue_free()
	platforms.clear()
	next_floor = 0
	camera_top = 0.0
	elapsed = 0.0
	climb_time = 0.0
	started = false
	paused = false
	journal_open = false
	game_over = false
	reached_floor = 0
	highest_landing = 0
	score = 0
	combo_steps = 0
	combo_time = 0.0
	biome = Biomes.at_floor(0)
	player.position = Vector2(576, Layout.START_Y - 32)
	player.velocity = Vector2.ZERO
	player.coyote = 0
	player.jump_buffer = 0
	player.friction_factor = biome["friction"]
	player.wind = 0
	player.biome_jump_bonus = 0
	player.set_physics_process(true)
	camera.position = Vector2(576, VIEW_HEIGHT / 2)
	_update_platforms()
	_update_hud()
	queue_redraw()


func _update_platforms() -> void:
	# Jump straight to the visible range if the camera is moved very far for testing.
	var first_visible := maxi(
		0, floori((Layout.START_Y - (camera_top + VIEW_HEIGHT + 180)) / Layout.GAP)
	)
	next_floor = maxi(next_floor, first_visible)
	while Layout.START_Y - next_floor * Layout.GAP > camera_top - 450:
		var rect := Layout.platform(next_floor, seed_value)
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		body.set_meta("floor_id", next_floor)
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		collision.one_way_collision = true
		collision.one_way_collision_margin = 6.0
		body.add_child(collision)
		add_child(body)
		platforms.append({"id": next_floor, "rect": rect, "body": body})
		next_floor += 1
	for index in range(platforms.size() - 1, -1, -1):
		var rect: Rect2 = platforms[index]["rect"]
		if rect.position.y > camera_top + VIEW_HEIGHT + 180:
			platforms[index]["body"].queue_free()
			platforms.remove_at(index)


func _physics_process(delta: float) -> void:
	if paused or journal_open or game_over:
		return
	elapsed += delta
	combo_time = maxf(0, combo_time - delta)
	if combo_time == 0:
		combo_steps = 0
	_track_height()
	player.friction_factor = biome["friction"]
	player.biome_jump_bonus = biome["jump_bonus"]
	player.wind = sin(elapsed * 0.8) * float(biome["wind"])
	if started:
		climb_time += delta
		camera_top -= scroll_speed() * delta
		camera_top = minf(camera_top, player.position.y - 300)
	camera.position = Vector2(576, camera_top + VIEW_HEIGHT / 2)
	_update_platforms()
	if player.position.y > camera_top + VIEW_HEIGHT + 90:
		_finish()
	_update_hud()
	queue_redraw()


func scroll_speed() -> float:
	return minf(62.0, 10.0 + climb_time * 0.12)


func _track_height() -> void:
	var altitude := maxi(0, floori((Layout.START_Y - player.position.y) / Layout.GAP))
	reached_floor = maxi(reached_floor, altitude)
	best_floor = maxi(best_floor, reached_floor)
	biome = Biomes.at_floor(reached_floor)


func _on_jump() -> void:
	started = true


func _on_landing() -> void:
	for index in range(player.get_slide_collision_count()):
		var collision := player.get_slide_collision(index)
		var body: Object = collision.get_collider()
		if body != null and body.has_meta("floor_id") and collision.get_normal().y < -0.5:
			_award_floor(int(body.get_meta("floor_id")))
			return


func _award_floor(floor_id: int) -> void:
	if floor_id <= highest_landing:
		return
	var gained := floor_id - highest_landing
	combo_steps = combo_steps + gained if combo_time > 0 else gained
	combo_time = 2.5
	highest_landing = floor_id
	score += gained * 10 * mini(8, 1 + combo_steps / 5)
	best_score = maxi(best_score, score)


func _finish() -> void:
	game_over = true
	player.set_physics_process(false)
	_persist()


func _load_stats() -> void:
	if smoke_mode:
		return
	var config := ConfigFile.new()
	if config.load("user://tower_save.cfg") != OK:
		return
	var saved_floor: Variant = config.get_value("records", "floor", 0)
	var saved_score: Variant = config.get_value("records", "score", 0)
	if saved_floor is int:
		best_floor = maxi(0, saved_floor)
	if saved_score is int:
		best_score = maxi(0, saved_score)


func _persist() -> void:
	if smoke_mode:
		return
	var config := ConfigFile.new()
	config.set_value("records", "floor", best_floor)
	config.set_value("records", "score", best_score)
	config.save("user://tower_save.cfg")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_persist()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("leave"):
		_persist()
		get_tree().quit()
	elif event.is_action_pressed("restart") and not event.is_echo():
		_restart()
	elif event.is_action_pressed("new_route") and not event.is_echo():
		seed_value = int(Time.get_ticks_usec() % 2147483647)
		_restart()
	elif event.is_action_pressed("pause") and not event.is_echo() and not game_over:
		paused = not paused
		_sync_pause()
	elif event.is_action_pressed("journal") and not event.is_echo():
		journal_open = not journal_open
		_sync_pause()


func _sync_pause() -> void:
	player.set_physics_process(not paused and not journal_open and not game_over)
	_update_hud()
	queue_redraw()


func _label(
	layer: Node,
	key: String,
	text: String,
	at: Vector2,
	size: Vector2,
	font_size: int,
	color := PAPER
) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	layer.add_child(label)
	labels[key] = label
	return label


func _bar(layer: Node, at: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.size = Vector2(196, 8)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	var background := fill.duplicate()
	background.bg_color = Color("304756")
	bar.add_theme_stylebox_override("background", background)
	layer.add_child(bar)
	return bar


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label(layer, "brand", "ENDLESS\nTOWER", Vector2(24, 24), Vector2(200, 80), 28)
	var name_label := _label(
		layer, "biome", "", Vector2(24, 110), Vector2(196, 70), 16, Color("a8d9df")
	)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(layer, "altitude_title", "HIGHEST FLOOR", Vector2(24, 192), Vector2(196, 24), 12)
	_label(layer, "altitude", "0", Vector2(24, 214), Vector2(196, 56), 42)
	_label(layer, "score_title", "SCORE", Vector2(24, 290), Vector2(196, 24), 12)
	_label(layer, "score", "0", Vector2(24, 312), Vector2(196, 42), 30)
	_label(layer, "best", "", Vector2(24, 368), Vector2(196, 26), 13, Color("a8d9df"))
	_label(layer, "combo", "", Vector2(24, 415), Vector2(196, 25), 14)
	combo_bar = _bar(layer, Vector2(24, 448), Color("f5ce70"))
	_label(layer, "momentum", "MOMENTUM", Vector2(24, 480), Vector2(196, 24), 12)
	speed_bar = _bar(layer, Vector2(24, 510), Color("7de2c6"))
	_label(
		layer,
		"controls",
		"A/D or ←/→ · Run\nSpace / W / ↑ · Jump\nHold Jump · Chain hops\nP · Pause     B · Journal\nR · Same route\nN · New route\nEsc · Gallery",
		Vector2(24, 548),
		Vector2(200, 150),
		13,
		Color("b8cbd0")
	)
	_label(layer, "trail_title", "BIOME TRAIL", Vector2(936, 30), Vector2(196, 30), 18)
	_label(layer, "reach", "", Vector2(936, 70), Vector2(196, 30), 14, Color("a8d9df"))
	for index in range(Biomes.FAMILIES.size()):
		var label := _label(
			layer, "family_%d" % index, "", Vector2(936, 122 + index * 25), Vector2(196, 24), 12
		)
		trail_labels.append(label)
	var upcoming := _label(
		layer, "next", "", Vector2(936, 570), Vector2(196, 78), 13, Color("b8cbd0")
	)
	upcoming.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(layer, "seed", "", Vector2(936, 674), Vector2(196, 22), 11, Color("9cb3bd"))
	var overlay := _label(layer, "overlay", "", Vector2(300, 225), Vector2(552, 190), 24)
	overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	journal = PanelContainer.new()
	journal.position = Vector2(288, 116)
	journal.size = Vector2(576, 492)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172d40")
	style.set_corner_radius_all(18)
	style.set_content_margin_all(26)
	journal.add_theme_stylebox_override("panel", style)
	layer.add_child(journal)
	journal_text = Label.new()
	journal_text.add_theme_font_size_override("font_size", 17)
	journal_text.add_theme_color_override("font_color", PAPER)
	journal.add_child(journal_text)


func _update_hud() -> void:
	labels["biome"].text = biome["name"]
	labels["altitude"].text = str(reached_floor)
	labels["score"].text = str(score)
	labels["best"].text = "BEST  %d floors · %d pts" % [best_floor, best_score]
	labels["combo"].text = (
		"CHAIN  %d · x%d" % [combo_steps, mini(8, 1 + combo_steps / 5)]
		if combo_steps > 0
		else "LAND HIGHER. KEEP GOING."
	)
	combo_bar.value = combo_time / 2.5 * 100
	speed_bar.value = absf(player.velocity.x) / Climber.MAX_SPEED * 100
	var region: int = biome["region"]
	labels["reach"].text = "REGION %d · REACH %d" % [region + 1, int(biome["cycle"]) + 1]
	var known_region := best_floor / Biomes.FLOORS_PER_BIOME
	for index in range(trail_labels.size()):
		var known := index <= known_region
		trail_labels[index].text = ("● " if known else "○ ") + str(Biomes.FAMILIES[index][0])
		trail_labels[index].add_theme_color_override(
			"font_color",
			(
				biome["accent"]
				if index == int(biome["family_id"])
				else (PAPER if known else Color("748d9c"))
			)
		)
	var next_biome := Biomes.at_floor((region + 1) * Biomes.FLOORS_PER_BIOME)
	labels["next"].text = (
		"NEXT\n%s\nin %d floors"
		% [next_biome["name"], (region + 1) * Biomes.FLOORS_PER_BIOME - reached_floor]
	)
	labels["seed"].text = "ROUTE  %d" % seed_value
	labels["overlay"].text = ""
	if game_over:
		labels["overlay"].text = "MISSED A STEP.\nTHE TOWER KEEPS GOING.\n\nR to retry · N for a new route"
	elif paused:
		labels["overlay"].text = "TAKE A BREATHER\n\nP to resume"
	elif not started:
		labels["overlay"].text = "RUN. JUMP. EXPLORE.\n\nHold Jump to chain hops.\nBuild speed for bigger jumps."
	journal.visible = journal_open
	var lines := "EXPEDITION JOURNAL\n16 families · endless remixed reaches\n\n"
	var last_region := best_floor / Biomes.FLOORS_PER_BIOME
	for index in range(maxi(0, last_region - 7), last_region + 1):
		lines += "%d. %s\n" % [index + 1, Biomes.at_floor(index * Biomes.FLOORS_PER_BIOME)["name"]]
	lines += "\nEach region lasts 20 floors.\nHigher reaches remix names and palettes.\n\nB to close · Esc for the gallery"
	journal_text.text = lines


func _draw() -> void:
	if biome.is_empty():
		return
	var bg: Color = biome["background"]
	var accent: Color = biome["accent"]
	for band in range(18):
		draw_rect(
			Rect2(0, camera_top + band * 40, 1152, 40), bg.lerp(bg.darkened(0.25), band / 18.0)
		)
	_draw_motif(str(biome["motif"]), accent)
	_draw_weather(str(biome["weather"]), accent)
	for x in [230.0, 904.0]:
		draw_rect(Rect2(x, camera_top, 18, VIEW_HEIGHT), bg.lightened(0.12))
		for index in range(16):
			var y := floorf(camera_top / 56) * 56 + index * 56
			draw_line(Vector2(x, y), Vector2(x + 18, y), accent.darkened(0.55), 2)
	for entry in platforms:
		var rect: Rect2 = entry["rect"]
		var skin := Biomes.at_floor(int(entry["id"]))
		draw_rect(rect, skin["platform"])
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), skin["accent"], 4)
		if int(entry["id"]) % Biomes.FLOORS_PER_BIOME == 0 and int(entry["id"]) > 0:
			draw_circle(rect.position + Vector2(10, -10), 4, skin["accent"])
	draw_rect(Rect2(0, camera_top, 230, VIEW_HEIGHT), Color(0.04, 0.08, 0.12, 0.84))
	draw_rect(Rect2(922, camera_top, 230, VIEW_HEIGHT), Color(0.04, 0.08, 0.12, 0.84))


func _draw_motif(motif: String, accent: Color) -> void:
	var color := Color(accent, 0.12)
	for index in range(7):
		var x := 292.0 + fposmod(index * 113.0 + seed_value % 97, 558.0)
		var y := camera_top + 160 + fposmod(index * 131.0 - camera_top * 0.13, 500.0)
		var center := Vector2(x, y)
		match motif:
			"forest":
				draw_colored_polygon(
					PackedVector2Array(
						[
							center + Vector2(0, -80),
							center + Vector2(-42, 36),
							center + Vector2(42, 36)
						]
					),
					color
				)
			"dunes":
				draw_circle(center + Vector2(0, 90), 98, color)
			"crystal":
				draw_colored_polygon(
					PackedVector2Array(
						[
							center + Vector2(0, -60),
							center + Vector2(-25, 0),
							center + Vector2(0, 62),
							center + Vector2(25, 0)
						]
					),
					color
				)
			"mushroom":
				draw_line(center, center + Vector2(0, 70), color, 10)
				draw_arc(center, 42, PI, TAU, 24, color, 17)
			"gears":
				draw_arc(center, 33, 0, TAU, 32, color, 9)
				for spoke in range(8):
					var angle := spoke * TAU / 8 + elapsed * 0.06
					draw_line(center, center + Vector2(cos(angle), sin(angle)) * 47, color, 6)
			"bamboo", "ruins":
				draw_rect(Rect2(center - Vector2(9, 85), Vector2(18, 170)), color)
				for segment in range(4):
					draw_line(
						center + Vector2(-15, -60 + segment * 40),
						center + Vector2(15, -60 + segment * 40),
						color,
						5
					)
			"clouds":
				for puff in range(3):
					draw_circle(center + Vector2(puff * 23 - 23, absf(puff - 1) * 8), 29, color)
			"volcano":
				draw_colored_polygon(
					PackedVector2Array(
						[
							center + Vector2(-60, 65),
							center + Vector2(-12, -35),
							center + Vector2(16, -35),
							center + Vector2(65, 65)
						]
					),
					color
				)
			"aurora":
				var points := PackedVector2Array()
				for step in range(30):
					points.append(
						center + Vector2(step * 8 - 120, sin(step * 0.2 + elapsed * 0.2) * 35)
					)
				draw_polyline(points, color, 12)
			"stars":
				draw_line(center - Vector2(30, 20), center + Vector2(40, 30), color, 2)
				draw_circle(center - Vector2(30, 20), 5, color)
				draw_circle(center + Vector2(40, 30), 5, color)
			_:
				draw_arc(center, 26 + index * 3, 0, TAU, 32, color, 3)
				if motif in ["planets", "orbits"]:
					draw_line(center - Vector2(50, 10), center + Vector2(50, 10), color, 5)


func _draw_weather(weather: String, accent: Color) -> void:
	for index in range(42):
		var x := 258 + fposmod(index * 137.0 + sin(elapsed + index) * 12, 636)
		var drift := -elapsed * 18 if weather in ["bubbles", "embers", "spores"] else elapsed * 25
		var y := camera_top + fposmod(index * 79.0 + drift, VIEW_HEIGHT)
		var point := Vector2(x, y)
		var color := Color(accent, 0.3)
		match weather:
			"rain":
				draw_line(point, point + Vector2(-3, 12), color, 1)
			"bubbles":
				draw_arc(point, 3 + index % 4, 0, TAU, 14, color, 1)
			"leaves", "petals":
				draw_line(point, point + Vector2(4, 6), color, 3)
			_:
				draw_circle(point, 1.5 + index % 2, color)


func _smoke_test() -> void:
	await Smoke.run(self)
	get_tree().quit()
