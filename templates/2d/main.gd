extends Node2D
## Coin Garden: movement, collisions, arrays, loops, and a little celebration.
const Player := preload("res://player.gd")
const COIN_POSITIONS := [
	Vector2(160, 557),
	Vector2(340, 457),
	Vector2(520, 367),
	Vector2(720, 277),
	Vector2(910, 397),
	Vector2(1050, 557)
]

var player: CharacterBody2D
var coins: Array[Vector2] = []
var score := 0
var elapsed := 0.0
var won := false
var hud: Label
var message: Label


func _ready() -> void:
	_setup_input()
	RenderingServer.set_default_clear_color(Color("102d3e"))
	for rect in [
		Rect2(0, 600, 1152, 120),
		Rect2(250, 500, 180, 22),
		Rect2(440, 410, 160, 22),
		Rect2(650, 320, 160, 22),
		Rect2(840, 440, 160, 22)
	]:
		_platform(rect)
	player = Player.new()
	add_child(player)
	_build_hud()
	_reset()
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("_smoke_test")


func _setup_input() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"restart": [KEY_R],
		"leave": [KEY_ESCAPE]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


func _platform(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array(
		[
			rect.position,
			rect.position + Vector2(rect.size.x, 0),
			rect.end,
			rect.position + Vector2(0, rect.size.y)
		]
	)
	visual.color = Color("29616a")
	add_child(visual)
	var grass := Line2D.new()
	grass.points = PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0)])
	grass.width = 5
	grass.default_color = Color("77e5ce")
	add_child(grass)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(36, 24)
	hud.add_theme_font_size_override("font_size", 24)
	layer.add_child(hud)
	var help := Label.new()
	help.text = "COIN GARDEN  /  2D LAB\nA D or ← →  Move    ·    Space  Jump    ·    R  Restart    ·    Esc  Gallery"
	help.position = Vector2(36, 650)
	help.add_theme_font_size_override("font_size", 17)
	layer.add_child(help)
	message = Label.new()
	message.position = Vector2(180, 120)
	message.size = Vector2(792, 110)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 32)
	layer.add_child(message)


func _reset() -> void:
	player.position = Vector2(75, 560)
	player.velocity = Vector2.ZERO
	coins.assign(COIN_POSITIONS)
	score = 0
	elapsed = 0.0
	won = false
	message.text = "Collect all six sun coins!"
	_update_hud()
	queue_redraw()


func _physics_process(delta: float) -> void:
	elapsed += delta
	player.position.x = clampf(player.position.x, 20, 1132)
	if player.position.y > 800:
		_reset()
	if not won:
		_check_pickups()
	if elapsed > 3.0 and not won:
		message.text = ""
	queue_redraw()


func _check_pickups() -> void:
	for index in range(coins.size() - 1, -1, -1):
		if player.position.distance_to(coins[index]) < 34:
			coins.remove_at(index)
			score += 1
			_update_hud()
	if coins.is_empty():
		won = true
		message.text = "A pocket full of sunshine!\nPress R to play again."


func _update_hud() -> void:
	hud.text = "☀  %d / %d" % [score, COIN_POSITIONS.size()]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_reset()
	if event.is_action_pressed("leave"):
		get_tree().quit()


func _draw() -> void:
	# A tiny landscape made entirely in code: no asset downloads required.
	for index in range(35):
		var point := Vector2((index * 167) % 1152, 100 + (index * 71) % 430)
		draw_circle(point, 2, Color("2a4d60"))
	draw_circle(Vector2(1000, 125), 47, Color("eecb73"))
	for index in range(coins.size()):
		var point := coins[index] + Vector2(0, sin(elapsed * 3 + index) * 4)
		draw_circle(point, 19, Color(1, 0.8, 0.35, 0.10))
		draw_circle(point, 12, Color("f7c85c"))
		draw_circle(point, 7, Color("ffe7a4"), false, 2)
	if won:
		for index in range(50):
			var point := Vector2((index * 97) % 1152, fmod(elapsed * 70 + index * 37, 620))
			draw_rect(
				Rect2(point, Vector2(5, 9)), Color("77e5ce") if index % 2 else Color("f7c85c")
			)


func _smoke_test() -> void:
	for frame in range(30):
		await get_tree().physics_frame
	assert(player.is_on_floor(), "Player must land on the floor")
	var start := player.position.x
	Input.action_press("move_right")
	for frame in range(12):
		await get_tree().physics_frame
	Input.action_release("move_right")
	assert(player.position.x > start + 20, "Movement must respond to input")
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	assert(player.velocity.y < 0, "Jump must lift the player")
	for coin in COIN_POSITIONS:
		player.position = coin
		_check_pickups()
	assert(won and score == 6)
	_reset()
	assert(not won and score == 0 and coins.size() == 6)
	print("PASS 2D: floor collision, movement, jump, pickups, win, restart")
	get_tree().quit()
