extends Node3D
## Sky Steps: build a world with vectors, shapes, materials, and simple physics.
const Player := preload("res://player.gd")
const STARS := [
	Vector3(0, 1.3, 3),
	Vector3(-2, 1.3, -6),
	Vector3(2, 1.3, -6),
	Vector3(3, 1.8, -13),
	Vector3(-2, 2.3, -20),
	Vector3(1, 2.3, -20)
]

var player: CharacterBody3D
var camera: Camera3D
var stars: Array[MeshInstance3D] = []
var hud: Label
var message: Label
var score := 0
var falls := 0
var won := false


func _ready() -> void:
	_setup_input()
	_build_world()
	player = Player.new()
	add_child(player)
	camera = Camera3D.new()
	camera.fov = 55
	add_child(camera)
	_build_hud()
	_reset()
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("_smoke_test")


func _setup_input() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
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


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("b9d9e6")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("e0efff")
	settings.ambient_light_energy = 0.35
	environment.environment = settings
	add_child(environment)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-55, -30, 0)
	sunlight.light_energy = 0.6
	sunlight.shadow_enabled = true
	add_child(sunlight)
	_island(Vector3(0, -0.5, 3), Vector3(10, 1, 10), Color("479b91"))
	_island(Vector3(0, -0.5, -6), Vector3(7, 1, 6), Color("6bafa1"))
	_island(Vector3(3, 0, -13), Vector3(6, 1, 6), Color("479b91"))
	_island(Vector3(-1, 0.5, -20), Vector3(7, 1, 6), Color("6bafa1"))
	# Decorative floating clouds have no collision shapes.
	for index in range(12):
		var cloud := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(5 + index % 3, 0.4, 2.5)
		cloud.mesh = box
		cloud.material_override = _material(Color("e5f0ef"))
		cloud.position = Vector3(-16 if index % 2 else 16, -3 - index % 3, 8 - index * 4)
		add_child(cloud)


func _island(at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	body.add_child(mesh)
	add_child(body)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(36, 24)
	hud.add_theme_color_override("font_color", Color("153c50"))
	hud.add_theme_font_size_override("font_size", 24)
	layer.add_child(hud)
	var help := Label.new()
	help.text = "SKY STEPS  /  3D LAB\nWASD or Arrows  Move    ·    Space  Jump    ·    R  Restart    ·    Esc  Gallery"
	help.position = Vector2(36, 650)
	help.add_theme_color_override("font_color", Color("153c50"))
	help.add_theme_font_size_override("font_size", 17)
	layer.add_child(help)
	message = Label.new()
	message.position = Vector2(180, 90)
	message.size = Vector2(792, 100)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_color", Color("153c50"))
	message.add_theme_font_size_override("font_size", 28)
	layer.add_child(message)


func _reset() -> void:
	for star in stars:
		remove_child(star)
		star.queue_free()
	stars.clear()
	for at in STARS:
		var star := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.3
		sphere.height = 0.6
		star.mesh = sphere
		star.material_override = _material(Color("ffd275"))
		star.position = at
		add_child(star)
		stars.append(star)
	score = 0
	falls = 0
	won = false
	_respawn()
	message.text = "Hop between islands. Find all six sky sparks!"
	_update_hud()


func _respawn() -> void:
	player.position = Vector3(0, 1.4, 5)
	player.velocity = Vector3.ZERO
	camera.position = player.position + Vector3(9, 12, 15)
	camera.look_at(player.position + Vector3(0, 0, -3))


func _physics_process(delta: float) -> void:
	if player.position.y < -7:
		falls += 1
		_respawn()
		_update_hud()
	_check_pickups()
	camera.position = camera.position.lerp(player.position + Vector3(9, 12, 15), 4 * delta)
	camera.look_at(player.position + Vector3(0, 0, -3))
	for star in stars:
		star.rotate_y(delta * 2)


func _check_pickups() -> void:
	for index in range(stars.size() - 1, -1, -1):
		if player.position.distance_to(stars[index].position) < 1.1:
			var star := stars[index]
			stars.remove_at(index)
			star.queue_free()
			score += 1
			_update_hud()
	if stars.is_empty():
		won = true
		message.text = "You found your feet in a new dimension!\nPress R to try again."


func _update_hud() -> void:
	hud.text = "SKY SPARKS  %d / 6     ·     FALLS  %d" % [score, falls]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_reset()
	if event.is_action_pressed("leave"):
		get_tree().quit()


func _smoke_test() -> void:
	for frame in range(40):
		await get_tree().physics_frame
	assert(player.is_on_floor(), "Player must land on the starting island")
	var start := player.position.z
	Input.action_press("move_forward")
	for frame in range(12):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	assert(player.position.z < start - 0.5)
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	assert(player.velocity.y > 0)
	for at in STARS:
		player.position = at
		_check_pickups()
	assert(won and score == 6)
	_reset()
	assert(not won and stars.size() == 6 and falls == 0)
	player.position.y = -10
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(falls == 1 and player.position.y > 0)
	print("PASS 3D: floor collision, movement, jump, pickups, win, restart, respawn")
	get_tree().quit()
