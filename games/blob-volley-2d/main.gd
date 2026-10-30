extends Node2D

const Rules := preload("res://rules.gd")
const Controls := preload("res://controls.gd")
const Hud := preload("res://hud.gd")
const Smoke := preload("res://smoke.gd")
const SCALE := 61.25
const FLOOR_Y := 590.0

var rules := Rules.new()
var controls := Controls.new()
var hud: CanvasLayer


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("102d3e"))
	controls.setup(false)
	rules.reset()
	hud = Hud.new()
	add_child(hud)
	hud.setup(false)
	hud.refresh(rules)
	if "--smoke-test" in OS.get_cmdline_user_args():
		set_physics_process(false)
		call_deferred("_smoke_test")


func _physics_process(delta: float) -> void:
	rules.tick(delta, controls.moves(), controls.jumps(), controls.dives())
	hud.refresh(rules)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	controls.handle(event, rules, get_tree())


func _screen(point: Vector3) -> Vector2:
	return Vector2(576 + point.x * SCALE, FLOOR_Y - point.y * SCALE)


func _draw() -> void:
	draw_circle(Vector2(1030, 220), 45, Color("eecb73"))
	for index in range(22):
		draw_circle(
			Vector2(50 + (index * 137) % 1050, 200 + (index * 73) % 300), 2, Color("2c5060")
		)
	draw_rect(Rect2(60, FLOOR_Y, 1032, 130), Color("234d5a"))
	draw_line(Vector2(86, FLOOR_Y), Vector2(1066, FLOOR_Y), Color("a9d4ca"), 5)
	var net_top := _screen(Vector3(0, Rules.NET_HEIGHT, 0))
	draw_line(Vector2(576, FLOOR_Y), net_top, Color("e5f0e5"), 9)
	draw_circle(net_top, 6, Color("f8e5b0"))
	for index in range(2):
		var base := _screen(rules.players[index])
		var ground := _screen(Vector3(rules.players[index].x, 0, 0))
		_draw_oval(ground, Vector2(45, 6), Color(0, 0, 0, 0.16))
		var points := PackedVector2Array()
		for step in range(25):
			var angle := PI * step / 24.0
			points.append(base + Vector2(cos(angle) * 52, -sin(angle) * 77))
		draw_colored_polygon(points, Color("77e5ce") if index == 0 else Color("ffa48c"))
		var facing := 1.0 if index == 0 else -1.0
		for offset in [-13.0, 13.0]:
			var eye := base + Vector2(offset, -43)
			draw_circle(eye, 11, Color("fffdf4"))
			draw_circle(eye + Vector2(3.5 * facing, -1), 5, Color("173e4e"))
		draw_arc(base + Vector2(0, -26), 12, 0.2, PI - 0.2, 14, Color("173e4e"), 2)
	var ball_at := _screen(rules.ball)
	draw_circle(ball_at, Rules.BALL_RADIUS * SCALE, Color("ffe7a4"))
	draw_arc(ball_at, 15, 0.3, PI + 0.3, 20, Color("d3a754"), 3)
	draw_arc(ball_at, 15, PI + 0.3, TAU + 0.3, 20, Color("fff7d3"), 3)


func _draw_oval(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * index / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)


func _smoke_test() -> void:
	Smoke.run(rules, controls, false)
	_physics_process(1.0 / 60.0)
	get_tree().quit()
