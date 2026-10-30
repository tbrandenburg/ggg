extends CharacterBody2D
## Try changing these three numbers. What happens to the jump's shape?
@export var speed := 310.0
@export var jump_speed := 570.0
@export var gravity := 1450.0

var facing := 1.0


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30, 42)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed
	if direction != 0:
		facing = direction
	if not is_on_floor():
		velocity.y += gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -jump_speed
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	draw_style_box(_body_style(), Rect2(-17, -23, 34, 46))
	draw_circle(Vector2(6 * facing, -7), 4, Color("142c3c"))
	draw_line(Vector2(-9, 11), Vector2(9, 11), Color("218d85"), 3)


func _body_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("77e5ce")
	style.set_corner_radius_all(9)
	return style
