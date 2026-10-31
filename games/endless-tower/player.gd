extends CharacterBody2D
## Horizontal speed makes jumps higher. Hold jump to chain hops after landing.

signal jumped
signal landed

const MAX_SPEED := 700.0
const ACCELERATION := 2200.0
const DRAG := 1000.0
const GRAVITY := 1750.0
const BASE_JUMP := 680.0
const MOMENTUM_BONUS := 300.0
const HALF_WIDTH := 14.0

var friction_factor := 1.0
var wind := 0.0
var biome_jump_bonus := 0.0
var left_wall := 248.0
var right_wall := 904.0
var coyote := 0.0
var jump_buffer := 0.0
var facing := 1.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 42)
	collision.shape = shape
	add_child(collision)


func jump_strength() -> float:
	return BASE_JUMP + absf(velocity.x) / MAX_SPEED * MOMENTUM_BONUS + biome_jump_bonus


func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
		facing = direction
	else:
		velocity.x = move_toward(velocity.x, 0, DRAG * friction_factor * delta)
	if not grounded:
		velocity.x = clampf(velocity.x + wind * delta, -MAX_SPEED, MAX_SPEED)
		velocity.y += GRAVITY * delta
	coyote = 0.1 if grounded else maxf(0, coyote - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	if Input.is_action_just_pressed("jump") or (grounded and Input.is_action_pressed("jump")):
		jump_buffer = 0.12
	if jump_buffer > 0 and coyote > 0:
		velocity.y = -jump_strength()
		jump_buffer = 0
		coyote = 0
		jumped.emit()
	move_and_slide()
	if position.x < left_wall + HALF_WIDTH:
		position.x = left_wall + HALF_WIDTH
		velocity.x = absf(velocity.x) * 0.92
	elif position.x > right_wall - HALF_WIDTH:
		position.x = right_wall - HALF_WIDTH
		velocity.x = -absf(velocity.x) * 0.92
	if not grounded and is_on_floor():
		landed.emit()
	queue_redraw()


func _draw() -> void:
	# An original little mountaineer, drawn in code rather than using borrowed sprites.
	draw_set_transform(Vector2.ZERO, clampf(velocity.x / MAX_SPEED, -1, 1) * 0.12)
	draw_line(Vector2(-9, -2), Vector2(-9 - facing * 15, 3), Color("ffa875"), 5)
	draw_rect(Rect2(-13, -5, 26, 23), Color("7de2c6"))
	draw_rect(Rect2(-13, 15, 11, 7), Color("193b4e"))
	draw_rect(Rect2(2, 15, 11, 7), Color("193b4e"))
	draw_circle(Vector2(0, -12), 12, Color("f6d4b7"))
	draw_arc(Vector2(0, -13), 12, PI, TAU, 20, Color("f5ce70"), 9)
	draw_line(Vector2(-14, -14), Vector2(14, -14), Color("f5ce70"), 5)
	draw_circle(Vector2(facing * 5, -10), 2.3, Color("193b4e"))
	draw_set_transform(Vector2.ZERO)
