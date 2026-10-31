extends StaticBody3D

var chunk_size := 48.0
var resolution := 24
var terrain_world: Node


func configure(size: float, segments: int, world: Node) -> void:
	chunk_size = size
	resolution = segments
	terrain_world = world


func build() -> void:
	var terrain_mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spacing := chunk_size / float(resolution)
	for z_index in range(resolution):
		for x_index in range(resolution):
			var x0 := x_index * spacing
			var x1 := (x_index + 1) * spacing
			var z0 := z_index * spacing
			var z1 := (z_index + 1) * spacing
			var p00 := _point(x0, z0)
			var p10 := _point(x1, z0)
			var p01 := _point(x0, z1)
			var p11 := _point(x1, z1)
			_add_triangle(surface, p00, p10, p01)
			_add_triangle(surface, p10, p11, p01)
	surface.generate_normals()
	surface.commit(terrain_mesh)
	var terrain := MeshInstance3D.new()
	terrain.name = "TerrainMesh"
	terrain.mesh = terrain_mesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	terrain.material_override = material
	add_child(terrain)
	var collision := CollisionShape3D.new()
	collision.name = "TerrainCollision"
	var heightmap := HeightMapShape3D.new()
	heightmap.map_width = resolution + 1
	heightmap.map_depth = resolution + 1
	var heights := PackedFloat32Array()
	for z_index in range(resolution + 1):
		for x_index in range(resolution + 1):
			heights.append(_point(x_index * spacing, z_index * spacing).y / spacing)
	heightmap.map_data = heights
	collision.shape = heightmap
	collision.position = Vector3(chunk_size * 0.5, 0.0, chunk_size * 0.5)
	collision.scale = Vector3(spacing, spacing, spacing)
	add_child(collision)


func rebuild() -> void:
	for child_name in ["TerrainMesh", "TerrainCollision"]:
		var old_child := get_node_or_null(child_name)
		if old_child != null:
			remove_child(old_child)
			old_child.queue_free()
	build()


func sample_height(world_x: float, world_z: float) -> float:
	return terrain_world.sample_height(world_x, world_z)


func biome_at(world_x: float, world_z: float) -> String:
	return terrain_world.biome_for_position(world_x, world_z)


func _point(local_x: float, local_z: float) -> Vector3:
	var world_x := position.x + local_x
	var world_z := position.z + local_z
	return Vector3(local_x, sample_height(world_x, world_z), local_z)


func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point in [a, b, c]:
		surface.set_color(_color_at(position.x + point.x, position.z + point.z))
		surface.add_vertex(point)


func _color_at(world_x: float, world_z: float) -> Color:
	return terrain_world.terrain_color(world_x, world_z)
