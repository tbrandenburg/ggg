extends Node3D

const TerrainChunk = preload("res://terrain_chunk.gd")

const WORLD_WIDTH := 1_000_000.0
const SAVE_PATH := "user://sandbox_world.json"
const DIG_RADIUS := 2.8
const DIG_STEP := 0.85
const MAX_DIG_DEPTH := 8.0

@export_range(16.0, 128.0, 1.0) var chunk_size := 48.0
@export_range(8, 64, 1) var chunk_resolution := 24
@export_range(1, 8, 1) var view_distance_chunks := 3
@export var world_seed := 374_921
@export var randomize_seed_on_launch := false
@export var debug_overlay := true

@onready var player: CharacterBody3D = get_node("../Player")

var terrain_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var biome_noise := FastNoiseLite.new()
var clay_noise := FastNoiseLite.new()
var ore_noise := FastNoiseLite.new()
var chunks: Dictionary = {}
var generation_queue: Array[Vector2i] = []
var chunks_to_unload: Array[Vector2i] = []
var terrain_deltas: Dictionary = {}
var last_center := Vector2i(2147483647, 2147483647)
var last_generation_ms := 0.0
var debug_label: Label
var saved_player_position: Variant = null
var smoke_test := false


func _ready() -> void:
	smoke_test = "--smoke-test" in OS.get_cmdline_user_args()
	var loaded_save := false
	if not smoke_test:
		loaded_save = _load_save()
	if not loaded_save and randomize_seed_on_launch:
		world_seed = randi()
	_configure_noise()
	_setup_debug_overlay()
	if saved_player_position != null:
		player.global_position = saved_player_position
	else:
		player.global_position = Vector3.ZERO
	var start_chunk := _chunk_coordinate(player.global_position)
	_create_chunk(start_chunk)
	if saved_player_position == null:
		player.global_position.y = sample_height(0.0, 0.0) + 1.05
	if loaded_save:
		player.get_node("Inventory").set_items(_loaded_inventory)
	_update_streaming(true)
	if not smoke_test:
		get_tree().root.close_requested.connect(_save_world)


var _loaded_inventory: Dictionary = {}


func _process(_delta: float) -> void:
	_update_streaming(false)
	if debug_overlay and debug_label != null:
		debug_label.text = (
			(
				"SEED  %d    CHUNKS  %d    GEN  %.1f ms\n"
				% [world_seed, chunks.size(), last_generation_ms]
			)
			+ (
				"POS  %d, %d    BIOME  %s    RAM  %.0f MB"
				% [
					roundi(player.global_position.x),
					roundi(player.global_position.z),
					_biome_at_player(),
					Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
				]
			)
		)
	_enforce_world_bounds()


func sample_height(world_x: float, world_z: float) -> float:
	return _sample_base_height(world_x, world_z) + _sample_terrain_delta(world_x, world_z)


func _load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or int(data.get("version", 0)) != 1:
		push_warning("Sandbox save is invalid or unsupported; starting a fresh world.")
		return false
	world_seed = int(data.get("world_seed", world_seed))
	var edits: Variant = data.get("terrain_deltas", [])
	if edits is Array:
		for edit in edits:
			if edit is Array and edit.size() == 3:
				var delta := float(edit[2])
				if delta < 0.0:
					terrain_deltas[Vector2i(int(edit[0]), int(edit[1]))] = clampf(
						delta, -MAX_DIG_DEPTH, 0.0
					)
	var position_data: Variant = data.get("player_position", [])
	if position_data is Array and position_data.size() == 3:
		saved_player_position = Vector3(
			float(position_data[0]), float(position_data[1]), float(position_data[2])
		)
	var saved_items: Variant = data.get("inventory", {})
	if saved_items is Dictionary:
		_loaded_inventory = saved_items
	return true


func _save_world() -> void:
	if smoke_test:
		return
	var edits: Array = []
	for coordinate in terrain_deltas:
		edits.append([coordinate.x, coordinate.y, terrain_deltas[coordinate]])
	var position_3d := player.global_position
	var save_data := {
		"version": 1,
		"world_seed": world_seed,
		"player_position": [position_3d.x, position_3d.y, position_3d.z],
		"inventory": player.get_node("Inventory").items.duplicate(),
		"terrain_deltas": edits,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save Sandbox world: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(save_data))
	file.close()


func sample_base_height(world_x: float, world_z: float) -> float:
	return _sample_base_height(world_x, world_z)


func biome_for_position(world_x: float, world_z: float) -> String:
	if Vector2(world_x, world_z).length() < 30.0:
		return "desert"
	var value := biome_noise.get_noise_2d(world_x, world_z)
	if value < -0.25:
		return "desert"
	if value > 0.35:
		return "highlands"
	return "grassland"


func terrain_color(world_x: float, world_z: float) -> Color:
	var depth := _sample_base_height(world_x, world_z) - sample_height(world_x, world_z)
	var material_id := _material_for_depth(world_x, world_z, depth)
	var color: Color
	match material_id:
		"sand":
			color = Color(0.54, 0.36, 0.2)
		"soil":
			color = Color(0.18, 0.3, 0.13)
		"clay":
			color = Color(0.43, 0.28, 0.2)
		"copper_ore":
			color = Color(0.48, 0.26, 0.16)
		"iron_ore":
			color = Color(0.35, 0.32, 0.3)
		_:
			color = Color(0.38, 0.37, 0.34)
	var variation := detail_noise.get_noise_2d(world_x, world_z) * 0.06
	return Color(color.r + variation, color.g + variation, color.b + variation, 1.0)


func dig_at(hit_position: Vector3, tool_quality: int = 0) -> Dictionary:
	var depth := (
		_sample_base_height(hit_position.x, hit_position.z)
		- sample_height(hit_position.x, hit_position.z)
	)
	if depth >= MAX_DIG_DEPTH - 0.05:
		return {}
	var material_id := _material_for_depth(hit_position.x, hit_position.z, depth)
	var spacing := chunk_size / float(chunk_resolution)
	var grid_radius := ceili(DIG_RADIUS / spacing) + 1
	var center_x := roundi(hit_position.x / spacing)
	var center_z := roundi(hit_position.z / spacing)
	var removed_volume := 0.0
	var edited := false
	var dig_step := DIG_STEP * (1.8 if tool_quality > 0 else 1.0)
	for z_offset in range(-grid_radius, grid_radius + 1):
		for x_offset in range(-grid_radius, grid_radius + 1):
			var coordinate := Vector2i(center_x + x_offset, center_z + z_offset)
			var world_x := coordinate.x * spacing
			var world_z := coordinate.y * spacing
			var distance := Vector2(world_x - hit_position.x, world_z - hit_position.z).length()
			if distance >= DIG_RADIUS:
				continue
			if (
				player.is_on_floor()
				and (
					(
						Vector2(
							world_x - player.global_position.x, world_z - player.global_position.z
						)
						. length()
					)
					< 1.15
				)
			):
				continue
			var weight := 1.0 - distance / DIG_RADIUS
			var old_delta := float(terrain_deltas.get(coordinate, 0.0))
			var new_delta := maxf(-MAX_DIG_DEPTH, old_delta - dig_step * weight * weight)
			var lowering := old_delta - new_delta
			if lowering <= 0.0001:
				continue
			terrain_deltas[coordinate] = new_delta
			removed_volume += lowering * spacing * spacing
			edited = true
	if not edited:
		return {}
	_rebuild_affected_chunks(hit_position.x, hit_position.z)
	return {"material_id": material_id, "amount": maxi(1, floori(removed_volume / 6.0))}


func _configure_noise() -> void:
	terrain_noise.seed = world_seed
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain_noise.fractal_octaves = 4
	terrain_noise.frequency = 0.008
	detail_noise.seed = world_seed ^ 0x5F3759DF
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 2
	detail_noise.frequency = 0.035
	biome_noise.seed = world_seed ^ 0x2C9277B5
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	biome_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	biome_noise.fractal_octaves = 3
	biome_noise.frequency = 0.00075
	clay_noise.seed = world_seed ^ 0x6A09E667
	clay_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	clay_noise.frequency = 0.018
	ore_noise.seed = world_seed ^ 0x3C6EF372
	ore_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ore_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	ore_noise.fractal_octaves = 2
	ore_noise.frequency = 0.025


func _setup_debug_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DebugOverlay"
	add_child(layer)
	debug_label = Label.new()
	debug_label.position = Vector2(18, 18)
	debug_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	debug_label.add_theme_color_override("font_shadow_color", Color(0.12, 0.1, 0.08))
	debug_label.add_theme_constant_override("shadow_offset_x", 2)
	debug_label.add_theme_constant_override("shadow_offset_y", 2)
	debug_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(debug_label)
	debug_label.visible = debug_overlay


func _update_streaming(force: bool) -> void:
	var center := _chunk_coordinate(player.global_position)
	if not force and center == last_center:
		if not generation_queue.is_empty():
			_create_chunk(generation_queue.pop_front())
		if generation_queue.is_empty():
			_unload_distant_chunks()
		return
	last_center = center
	var wanted: Dictionary = {}
	var candidates: Array[Vector2i] = []
	for z_offset in range(-view_distance_chunks, view_distance_chunks + 1):
		for x_offset in range(-view_distance_chunks, view_distance_chunks + 1):
			var coordinate := center + Vector2i(x_offset, z_offset)
			var distance_squared := x_offset * x_offset + z_offset * z_offset
			if distance_squared <= view_distance_chunks * view_distance_chunks:
				wanted[coordinate] = true
				if not chunks.has(coordinate):
					candidates.append(coordinate)
	chunks_to_unload.clear()
	for coordinate in chunks.keys():
		if not wanted.has(coordinate):
			chunks_to_unload.append(coordinate)
	generation_queue.clear()
	candidates.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return a.distance_squared_to(center) < b.distance_squared_to(center)
	)
	generation_queue.assign(candidates)
	if force and not generation_queue.is_empty():
		_create_chunk(generation_queue.pop_front())
	if not generation_queue.is_empty():
		_create_chunk(generation_queue.pop_front())
	if generation_queue.is_empty():
		_unload_distant_chunks()


func _unload_distant_chunks() -> void:
	for coordinate in chunks_to_unload:
		if chunks.has(coordinate):
			chunks[coordinate].queue_free()
			chunks.erase(coordinate)
	chunks_to_unload.clear()


func _create_chunk(coordinate: Vector2i) -> void:
	if chunks.has(coordinate):
		return
	var started := Time.get_ticks_usec()
	var chunk = TerrainChunk.new()
	chunk.name = "Chunk_%d_%d" % [coordinate.x, coordinate.y]
	chunk.position = Vector3(coordinate.x * chunk_size, 0.0, coordinate.y * chunk_size)
	chunk.configure(chunk_size, chunk_resolution, self)
	chunk.build()
	add_child(chunk)
	chunks[coordinate] = chunk
	last_generation_ms = (Time.get_ticks_usec() - started) / 1000.0


func _chunk_coordinate(position_3d: Vector3) -> Vector2i:
	return Vector2i(floori(position_3d.x / chunk_size), floori(position_3d.z / chunk_size))


func _sample_base_height(world_x: float, world_z: float) -> float:
	var height := terrain_noise.get_noise_2d(world_x, world_z) * 5.0
	height += detail_noise.get_noise_2d(world_x, world_z) * 0.8
	var biome := biome_noise.get_noise_2d(world_x, world_z)
	if biome > 0.28:
		height += maxf(0.0, biome - 0.28) * 12.0
	return height


func _sample_terrain_delta(world_x: float, world_z: float) -> float:
	var spacing := chunk_size / float(chunk_resolution)
	var grid_x := world_x / spacing
	var grid_z := world_z / spacing
	var x0 := floori(grid_x)
	var z0 := floori(grid_z)
	var x_weight := grid_x - x0
	var z_weight := grid_z - z0
	var top_left := float(terrain_deltas.get(Vector2i(x0, z0), 0.0))
	var top_right := float(terrain_deltas.get(Vector2i(x0 + 1, z0), 0.0))
	var bottom_left := float(terrain_deltas.get(Vector2i(x0, z0 + 1), 0.0))
	var bottom_right := float(terrain_deltas.get(Vector2i(x0 + 1, z0 + 1), 0.0))
	return lerpf(
		lerpf(top_left, top_right, x_weight), lerpf(bottom_left, bottom_right, x_weight), z_weight
	)


func _material_for_depth(world_x: float, world_z: float, depth: float) -> String:
	var biome := biome_for_position(world_x, world_z)
	if depth < 1.5:
		if biome == "desert":
			return "sand"
		if biome == "grassland":
			return "soil"
		return "stone"
	if depth < 3.5:
		if clay_noise.get_noise_2d(world_x, world_z) > 0.35:
			return "clay"
		return "stone"
	var ore := ore_noise.get_noise_2d(world_x, world_z)
	if depth >= 5.0 and ore > 0.62:
		return "copper_ore"
	if depth >= 6.0 and ore < -0.64:
		return "iron_ore"
	return "stone"


func _rebuild_affected_chunks(world_x: float, world_z: float) -> void:
	var minimum_x := floori((world_x - DIG_RADIUS) / chunk_size)
	var maximum_x := floori((world_x + DIG_RADIUS) / chunk_size)
	var minimum_z := floori((world_z - DIG_RADIUS) / chunk_size)
	var maximum_z := floori((world_z + DIG_RADIUS) / chunk_size)
	for z_index in range(minimum_z, maximum_z + 1):
		for x_index in range(minimum_x, maximum_x + 1):
			var chunk = chunks.get(Vector2i(x_index, z_index))
			if is_instance_valid(chunk):
				chunk.rebuild()


func _enforce_world_bounds() -> void:
	var half_width := WORLD_WIDTH * 0.5
	var bounded_x := clampf(player.global_position.x, -half_width, half_width)
	var bounded_z := clampf(player.global_position.z, -half_width, half_width)
	if bounded_x != player.global_position.x:
		player.global_position.x = bounded_x
		player.velocity.x = 0.0
	if bounded_z != player.global_position.z:
		player.global_position.z = bounded_z
		player.velocity.z = 0.0


func _biome_at_player() -> String:
	var position_3d := player.global_position
	if Vector2(position_3d.x, position_3d.z).length() < 30.0:
		return "desert"
	var value := biome_noise.get_noise_2d(position_3d.x, position_3d.z)
	if value < -0.25:
		return "desert"
	if value > 0.35:
		return "rocky highlands"
	return "grassland"


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		debug_overlay = not debug_overlay
		if debug_label != null:
			debug_label.visible = debug_overlay
