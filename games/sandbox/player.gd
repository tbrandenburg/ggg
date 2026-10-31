extends CharacterBody3D

const MaterialCatalog = preload("res://material_catalog.gd")

@export_range(1.0, 15.0, 0.1) var walk_speed := 5.5
@export_range(1.0, 20.0, 0.1) var sprint_speed := 9.0
@export_range(1.0, 50.0, 0.1) var acceleration := 22.0
@export_range(1.0, 50.0, 0.1) var deceleration := 28.0
@export_range(1.0, 15.0, 0.1) var jump_speed := 7.0
@export_range(1.0, 40.0, 0.1) var gravity := 20.0
@export_range(0.001, 0.02, 0.001) var mouse_sensitivity := 0.004
@export_range(4.0, 18.0, 0.5) var camera_distance := 10.0
@export_range(-80.0, 10.0, 1.0) var kill_plane := -80.0
@export_range(2.0, 12.0, 0.5) var digging_range := 7.0
@export_range(0.1, 2.0, 0.1) var digging_cooldown := 0.35

@onready var camera: Camera3D = get_parent().get_node("Camera3D")
@onready var inventory: Node = get_node("Inventory")
@onready var terrain: Node = get_parent().get_node("Terrain")

var camera_yaw := 0.0
var camera_pitch := deg_to_rad(28.0)
var spawn_position := Vector3.ZERO
var target_hit: Dictionary = {}
var target_marker: MeshInstance3D
var last_dig_msec := -10000
var ignore_mouse_until_msec := 0


func _ready() -> void:
	floor_snap_length = 0.3
	spawn_position = global_position
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("_smoke_test")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		ignore_mouse_until_msec = Time.get_ticks_msec() + 750
	_setup_target_marker()


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
	var direction := (right * input_vector.x - forward * input_vector.y).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var horizontal_rate := acceleration if direction.length_squared() > 0.0 else deceleration
	velocity.x = move_toward(velocity.x, direction.x * speed, horizontal_rate * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, horizontal_rate * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
		if velocity.y > 0.0 and not Input.is_action_pressed("jump"):
			velocity.y -= gravity * 1.8 * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed
	move_and_slide()
	_update_camera(delta)
	_update_targeting()
	if global_position.y < kill_plane:
		_respawn()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				_try_dig()
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				ignore_mouse_until_msec = Time.get_ticks_msec() + 250
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(4.0, camera_distance - 1.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(18.0, camera_distance + 1.0)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Time.get_ticks_msec() >= ignore_mouse_until_msec and event.relative.length() < 80.0:
			_rotate_camera(event.relative.limit_length(50.0))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and event.keycode == KEY_C:
		_craft_stone_pick()


func _setup_target_marker() -> void:
	target_marker = MeshInstance3D.new()
	target_marker.name = "DigTargetMarker"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.5
	target_marker.mesh = ring
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.9, 0.92, 0.45, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	target_marker.material_override = material
	target_marker.visible = false
	get_parent().add_child.call_deferred(target_marker)


func _update_targeting() -> void:
	var center := get_viewport().get_visible_rect().size * 0.5 - Vector2(0.0, 25.0)
	var ray_origin := camera.project_ray_origin(center)
	var ray_length := camera.global_position.distance_to(global_position) + digging_range
	var ray_end := ray_origin + camera.project_ray_normal(center) * ray_length
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	target_hit = get_world_3d().direct_space_state.intersect_ray(query)
	if (
		not target_hit.is_empty()
		and target_hit.position.distance_to(global_position) > digging_range
	):
		target_hit.clear()
	var collider: Object = target_hit.get("collider")
	target_marker.visible = collider is StaticBody3D
	if target_marker.visible:
		target_marker.global_position = target_hit.position + target_hit.normal * 0.04
		target_marker.global_basis = Basis(Quaternion(Vector3.UP, target_hit.normal))


func _try_dig() -> void:
	if target_hit.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - last_dig_msec < roundi(digging_cooldown * 1000.0):
		return
	last_dig_msec = now
	var result: Dictionary = terrain.dig_at(
		target_hit.position, 1 if inventory.count("stone_pick") > 0 else 0
	)
	if result.is_empty():
		get_parent().get_node("HUD").show_notification("This layer cannot be dug further.")
		return
	var material_id: String = result["material_id"]
	var amount: int = result["amount"]
	inventory.add_item(material_id, amount)
	var material_name := MaterialCatalog.display_name(material_id)
	get_parent().get_node("HUD").show_notification("Collected %d %s" % [amount, material_name])


func _craft_stone_pick() -> void:
	if inventory.count("stone_pick") > 0:
		get_parent().get_node("HUD").show_notification("You already have a stone pick.")
		return
	var required_stone := 3
	var owned_stone: int = inventory.count("stone")
	if owned_stone < required_stone:
		get_parent().get_node("HUD").show_notification(
			"Stone Pick needs %d more stone." % (required_stone - owned_stone)
		)
		return
	inventory.remove_item("stone", required_stone)
	inventory.add_item("stone_pick")
	get_parent().get_node("HUD").show_notification("Crafted a Stone Pick. Digging is faster.")


func _rotate_camera(relative_motion: Vector2) -> void:
	camera_yaw -= relative_motion.x * mouse_sensitivity
	camera_pitch = clampf(
		camera_pitch - relative_motion.y * mouse_sensitivity, deg_to_rad(5), deg_to_rad(70)
	)


func _update_camera(delta: float) -> void:
	var target := global_position + Vector3(0, 0.65, 0)
	var horizontal := camera_distance * cos(camera_pitch)
	var offset := Vector3(
		sin(camera_yaw) * horizontal,
		sin(camera_pitch) * camera_distance,
		cos(camera_yaw) * horizontal
	)
	var desired := target + offset
	var query := PhysicsRayQueryParameters3D.create(target, desired)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + hit.normal * 0.25
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-12.0 * delta))
	camera.look_at(target)


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _smoke_test() -> void:
	for frame in range(40):
		await get_tree().physics_frame
	if not is_on_floor():
		push_error(
			"Player missed the desert floor at %s with velocity %s" % [global_position, velocity]
		)
		get_tree().quit(1)
		return
	var terrain: Node = get_parent().get_node("Terrain")
	if not inventory.items.is_empty():
		push_error("A fresh survival world must start with an empty inventory")
		get_tree().quit(1)
		return
	if terrain.chunks.size() < 4:
		push_error("Nearby terrain chunks did not stream in")
		get_tree().quit(1)
		return
	_update_targeting()
	if target_hit.is_empty():
		push_error("The center aim ray must find terrain within digging range")
		get_tree().quit(1)
		return
	var dig_position: Vector3 = target_hit.position
	var old_height: float = terrain.sample_height(dig_position.x, dig_position.z)
	_try_dig()
	if (
		inventory.items.is_empty()
		or terrain.sample_height(dig_position.x, dig_position.z) >= old_height
	):
		push_error("Digging must deform terrain and add the extracted material to inventory")
		get_tree().quit(1)
		return
	_craft_stone_pick()
	if inventory.count("stone_pick") != 0:
		push_error("The Stone Pick must not be craftable without its stone recipe")
		get_tree().quit(1)
		return
	inventory.add_item("stone", 3)
	_craft_stone_pick()
	if inventory.count("stone") != 0 or inventory.count("stone_pick") != 1:
		push_error("Crafting must consume the required stone and create one Stone Pick")
		get_tree().quit(1)
		return
	var original_yaw := camera_yaw
	var original_pitch := camera_pitch
	_rotate_camera(Vector2(40.0, -25.0))
	if is_equal_approx(camera_yaw, original_yaw) or is_equal_approx(camera_pitch, original_pitch):
		push_error("Relative mouse motion must rotate the camera on both axes")
		get_tree().quit(1)
		return
	var east_chunk = terrain.chunks.get(Vector2i(1, 0))
	if (
		not is_instance_valid(east_chunk)
		or not is_equal_approx(
			east_chunk.sample_height(terrain.chunk_size, 12.0),
			terrain.sample_height(terrain.chunk_size, 12.0)
		)
	):
		push_error("Adjacent chunks must use matching deterministic edge heights")
		get_tree().quit(1)
		return
	var seam_position := Vector3(
		terrain.chunk_size, terrain.sample_height(terrain.chunk_size, 12.0), 12.0
	)
	var seam_height: float = terrain.sample_height(seam_position.x, seam_position.z)
	var seam_drop: Dictionary = terrain.dig_at(seam_position, 1)
	var west_chunk = terrain.chunks.get(Vector2i(0, 0))
	if (
		seam_drop.is_empty()
		or terrain.sample_height(seam_position.x, seam_position.z) >= seam_height
		or not is_equal_approx(
			west_chunk.sample_height(seam_position.x, seam_position.z),
			east_chunk.sample_height(seam_position.x, seam_position.z)
		)
	):
		push_error("Digging across a chunk edge must deform both chunks without a seam")
		get_tree().quit(1)
		return
	inventory.add_item(seam_drop["material_id"], seam_drop["amount"])
	var start := global_position.z
	Input.action_press("move_forward")
	for frame in range(24):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	if global_position.z >= start - 0.5:
		push_error("Player did not move forward: %s -> %s" % [start, global_position.z])
		get_tree().quit(1)
		return
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	if velocity.y <= 0:
		push_error("Player did not jump")
		get_tree().quit(1)
		return
	Input.action_release("jump")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for frame in range(30):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")
	if Vector2(velocity.x, velocity.z).length() <= walk_speed:
		push_error("Sprint did not exceed walking speed")
		get_tree().quit(1)
		return
	global_position.y = kill_plane - 1.0
	await get_tree().physics_frame
	if global_position.distance_to(spawn_position) > 0.1:
		push_error("Falling below the kill plane must respawn at the desert start")
		get_tree().quit(1)
		return
	print(
		"PASS Sandbox: empty start, digging, inventory, stone tool recipe, seam edits, streaming, movement, camera, respawn"
	)
	get_tree().quit()
