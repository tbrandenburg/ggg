extends CharacterBody3D
## Change speed and jump_speed, then experiment with the gaps between islands.
@export var speed := 6.5
@export var jump_speed := 9.0
@export var gravity := 22.0


func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.4
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.4
	mesh.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("faac7d")
	material.roughness = 0.65
	mesh.material_override = material
	add_child(mesh)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	velocity.x = input.x * speed
	velocity.z = input.y * speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_speed
	move_and_slide()
