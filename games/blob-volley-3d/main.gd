extends Node3D

const Rules := preload("res://rules.gd")
const Controls := preload("res://controls.gd")
const Hud := preload("res://hud.gd")
const Smoke := preload("res://smoke.gd")

var rules := Rules.new()
var controls := Controls.new()
var hud: CanvasLayer
var blobs: Array[Node3D] = []
var ball_mesh: MeshInstance3D
var ball_shadow: MeshInstance3D


func _ready() -> void:
	rules.depth_enabled = true
	controls.setup(true)
	rules.reset()
	_build_court()
	for index in range(2):
		blobs.append(_blob(Color("77e5ce") if index == 0 else Color("ffa48c")))
	ball_mesh = _sphere(Rules.BALL_RADIUS, Color("ffe7a4"))
	add_child(ball_mesh)
	var stripe := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = Rules.BALL_RADIUS - 0.015
	ring.outer_radius = Rules.BALL_RADIUS + 0.015
	stripe.mesh = ring
	stripe.material_override = _material(Color("fffdf4"))
	ball_mesh.add_child(stripe)
	ball_shadow = _sphere(0.36, Color("6aa8a4"))
	ball_shadow.scale = Vector3(1, 0.015, 1)
	add_child(ball_shadow)
	hud = Hud.new()
	add_child(hud)
	hud.setup(true)
	_sync_visuals()
	if "--smoke-test" in OS.get_cmdline_user_args():
		set_physics_process(false)
		call_deferred("_smoke_test")


func _material(color: Color) -> ShaderMaterial:
	# Controlled toon shading keeps the palette readable on different graphics drivers.
	var material := ShaderMaterial.new()
	material.shader = preload("res://palette.gdshader")
	material.set_shader_parameter("tint", color)
	return material


func _box(at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = _material(color)
	add_child(mesh)


func _sphere(radius: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	mesh.mesh = sphere
	mesh.material_override = _material(color)
	return mesh


func _blob(color: Color) -> Node3D:
	var blob := Node3D.new()
	add_child(blob)
	var body := _sphere(Rules.BLOB_RADIUS, color)
	body.position.y = 0.5
	body.scale.y = 0.8
	blob.add_child(body)
	for offset in [-0.26, 0.26]:
		var eye := _sphere(0.18, Color("fffdf4"))
		eye.position = Vector3(offset, 0.82, 0.7)
		blob.add_child(eye)
		var pupil := _sphere(0.075, Color("173e4e"))
		pupil.position = Vector3(offset + 0.025, 0.82, 0.85)
		blob.add_child(pupil)
	return blob


func _build_court() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("dbe9ed")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("eef5ff")
	environment.ambient_light_energy = 0.35
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -25, 0)
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	add_child(sun)
	_box(Vector3(0, -0.3, 0), Vector3(34, 0.4, 26), Color("e8ddc2"))
	_box(Vector3(0, -0.1, 0), Vector3(16.4, 0.2, 8.4), Color("81bcb8"))
	for x in [-8.0, 0.0, 8.0]:
		_box(Vector3(x, 0.015, 0), Vector3(0.06, 0.025, 8), Color("f8f8e9"))
	for z in [-4.0, 4.0]:
		_box(Vector3(0, 0.015, z), Vector3(16, 0.025, 0.06), Color("f8f8e9"))
	for z in [-4.15, 4.15]:
		_box(Vector3(0, 1.25, z), Vector3(0.14, 2.5, 0.14), Color("f8f8e9"))
	# A visible mesh net; the rules handle collision with the corresponding volume.
	for index in range(21):
		_box(Vector3(0, 1.2, -4 + index * 0.4), Vector3(0.025, 2.4, 0.025), Color("557879"))
	for index in range(7):
		_box(Vector3(0, index * 0.4, 0), Vector3(0.025, 0.025, 8), Color("557879"))
	_box(Vector3(0, Rules.NET_HEIGHT, 0), Vector3(0.09, 0.09, 8.3), Color("f8f8e9"))
	var camera := Camera3D.new()
	camera.position = Vector3(10, 13, 22)
	camera.fov = 38
	add_child(camera)
	camera.look_at(Vector3(0, 0.6, 0))


func _physics_process(delta: float) -> void:
	rules.tick(delta, controls.moves(), controls.jumps(), controls.dives())
	if not rules.paused and rules.phase == Rules.Phase.PLAYING:
		ball_mesh.rotate_x(delta * 1.5)
		ball_mesh.rotate_z(delta)
	_sync_visuals()


func _sync_visuals() -> void:
	for index in range(2):
		blobs[index].position = rules.players[index]
	ball_mesh.position = rules.ball
	ball_shadow.position = Vector3(rules.ball.x, 0.025, rules.ball.z)
	hud.refresh(rules)


func _unhandled_input(event: InputEvent) -> void:
	controls.handle(event, rules, get_tree())


func _smoke_test() -> void:
	Smoke.run(rules, controls, true)
	_physics_process(1.0 / 60.0)
	_sync_visuals()
	assert(blobs[0].position == rules.players[0] and ball_mesh.position == rules.ball)
	get_tree().quit()
