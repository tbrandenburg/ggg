extends Node2D
## Local two-player Pong. Everything needed to learn from it lives in this folder.
## Try changing paddle_speed, START_SPEED, or WINNING_SCORE, then play another round.

enum Phase { READY, PLAYING, POINT, MATCH_OVER }

const COURT := Rect2(32, 144, 1088, 464)
const PADDLE_SIZE := Vector2(18, 104)
const BALL_RADIUS := 10.0
const START_SPEED := 440.0
const MAX_SPEED := 950.0
const WINNING_SCORE := 7
const MINT := Color("77e5ce")
const CORAL := Color("ffa48c")
const INK := Color("102d3e")

@export var paddle_speed := 430.0

var paddles: Array[Vector2] = [Vector2(82, 376), Vector2(1070, 376)]
var scores: Array[int] = [0, 0]
var ball := COURT.get_center()
var ball_velocity := Vector2.ZERO
var phase := Phase.READY
var paused := false
var serve_direction := 1.0
var point_delay := 0.0
var trail: Array[Vector2] = []
var score_labels: Array[Label] = []
var message: Label
var subtitle: Label


func _ready() -> void:
	_setup_input()
	RenderingServer.set_default_clear_color(INK)
	_build_hud()
	_restart()
	if "--smoke-test" in OS.get_cmdline_user_args():
		set_physics_process(false)
		call_deferred("_smoke_test")


func _setup_input() -> void:
	var bindings := {
		"p1_left": KEY_A,
		"p1_right": KEY_D,
		"p1_up": KEY_W,
		"p1_down": KEY_S,
		"p2_left": KEY_LEFT,
		"p2_right": KEY_RIGHT,
		"p2_up": KEY_UP,
		"p2_down": KEY_DOWN,
		"serve_pause": KEY_SPACE,
		"restart": KEY_R,
		"leave": KEY_ESCAPE,
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)


func _label(text: String, at: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _build_hud() -> void:
	_label("PONG / TWO PLAYERS", Vector2(32, 28), Vector2(260, 32), 18, MINT)
	_label("FIRST TO SEVEN", Vector2(870, 28), Vector2(250, 32), 16, CORAL)
	score_labels.append(_label("0", Vector2(410, 32), Vector2(120, 85), 64, MINT))
	score_labels.append(_label("0", Vector2(622, 32), Vector2(120, 85), 64, CORAL))
	_label(":", Vector2(546, 42), Vector2(60, 70), 48, Color("597481"))
	_label("PLAYER 1", Vector2(48, 100), Vector2(150, 28), 15, MINT)
	_label("PLAYER 2", Vector2(954, 100), Vector2(150, 28), 15, CORAL)
	message = _label("", Vector2(230, 290), Vector2(692, 55), 30, Color("f5f4ed"))
	subtitle = _label("", Vector2(230, 350), Vector2(692, 45), 19, Color("b4c9cd"))
	_label("PLAYER 1  ·  W A S D", Vector2(32, 636), Vector2(360, 30), 18, MINT)
	_label("PLAYER 2  ·  ARROW KEYS", Vector2(760, 636), Vector2(360, 30), 18, CORAL)
	_label(
		"Space  Serve / Pause     ·     R  Restart     ·     Esc  Gallery",
		Vector2(176, 683),
		Vector2(800, 28),
		15,
		Color("b4c9cd")
	)


func _restart() -> void:
	scores.assign([0, 0])
	paddles.assign([Vector2(82, 376), Vector2(1070, 376)])
	ball = COURT.get_center()
	ball_velocity = Vector2.ZERO
	trail.clear()
	phase = Phase.READY
	paused = false
	serve_direction = 1.0
	point_delay = 0.0
	_update_hud()
	queue_redraw()


func _serve() -> void:
	ball = COURT.get_center()
	# Alternate the initial vertical direction to keep serves fair and predictable.
	var slope := 0.3 if (scores[0] + scores[1]) % 2 == 0 else -0.3
	ball_velocity = Vector2(serve_direction, slope).normalized() * START_SPEED
	trail.clear()
	phase = Phase.PLAYING
	paused = false
	_update_hud()


func _physics_process(delta: float) -> void:
	if paused or phase == Phase.MATCH_OVER:
		return
	_move_paddles(delta)
	if phase == Phase.POINT:
		point_delay -= delta
		if point_delay <= 0.0:
			_serve()
	elif phase == Phase.PLAYING:
		_advance_ball(delta)
		trail.push_front(ball)
		if trail.size() > 12:
			trail.pop_back()
	queue_redraw()


func _move_paddles(delta: float) -> void:
	for index in range(2):
		var prefix := "p%d_" % (index + 1)
		var movement := Input.get_vector(
			prefix + "left", prefix + "right", prefix + "up", prefix + "down"
		)
		paddles[index] += movement * paddle_speed * delta
		# Each player can move in four directions, but stays on their own side.
		var min_x := 50.0 if index == 0 else 752.0
		var max_x := 400.0 if index == 0 else 1102.0
		paddles[index].x = clampf(paddles[index].x, min_x, max_x)
		paddles[index].y = clampf(
			paddles[index].y, COURT.position.y + PADDLE_SIZE.y / 2, COURT.end.y - PADDLE_SIZE.y / 2
		)


func _advance_ball(delta: float) -> void:
	# Small steps prevent a fast ball from jumping completely through a paddle.
	var steps := maxi(1, ceili(ball_velocity.length() * delta / (BALL_RADIUS * 0.75)))
	var step_delta := delta / steps
	for step in range(steps):
		ball += ball_velocity * step_delta
		if ball.y < COURT.position.y + BALL_RADIUS:
			ball.y = COURT.position.y + BALL_RADIUS
			ball_velocity.y = absf(ball_velocity.y)
		elif ball.y > COURT.end.y - BALL_RADIUS:
			ball.y = COURT.end.y - BALL_RADIUS
			ball_velocity.y = -absf(ball_velocity.y)
		for index in range(2):
			var approaching := ball_velocity.x < 0 if index == 0 else ball_velocity.x > 0
			var paddle_rect := Rect2(paddles[index] - PADDLE_SIZE / 2, PADDLE_SIZE).grow(
				BALL_RADIUS
			)
			if approaching and paddle_rect.has_point(ball):
				_bounce(index)
		if ball.x < COURT.position.x - BALL_RADIUS:
			_point(1)
			return
		if ball.x > COURT.end.x + BALL_RADIUS:
			_point(0)
			return


func _bounce(index: int) -> void:
	var direction := 1.0 if index == 0 else -1.0
	var impact := clampf((ball.y - paddles[index].y) / (PADDLE_SIZE.y / 2), -1.0, 1.0)
	var angle := impact * 0.95
	var speed := minf(ball_velocity.length() * 1.06, MAX_SPEED)
	ball_velocity = Vector2(direction * cos(angle), sin(angle)) * speed
	ball.x = paddles[index].x + direction * (PADDLE_SIZE.x / 2 + BALL_RADIUS + 0.5)


func _point(winner: int) -> void:
	scores[winner] += 1
	ball = COURT.get_center()
	ball_velocity = Vector2.ZERO
	trail.clear()
	serve_direction = -1.0 if winner == 1 else 1.0
	phase = Phase.MATCH_OVER if scores[winner] >= WINNING_SCORE else Phase.POINT
	point_delay = 1.0
	_update_hud()


func _update_hud() -> void:
	for index in range(2):
		score_labels[index].text = str(scores[index])
	if paused:
		message.text = "TAKE A BREATHER"
		subtitle.text = "Space to resume"
	elif phase == Phase.READY:
		message.text = "READY FOR A RALLY?"
		subtitle.text = "Space to serve · Move with WASD and arrow keys"
	elif phase == Phase.POINT:
		message.text = "NICE SHOT!"
		subtitle.text = "Next serve in a moment…"
	elif phase == Phase.MATCH_OVER:
		message.text = "PLAYER %d WINS!" % (1 if scores[0] > scores[1] else 2)
		subtitle.text = "R for a rematch · Esc to return to the gallery"
	else:
		message.text = ""
		subtitle.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("leave"):
		get_tree().quit()
	elif event.is_action_pressed("restart"):
		_restart()
	elif event.is_action_pressed("serve_pause") and not event.is_echo():
		if phase == Phase.READY:
			_serve()
		elif phase in [Phase.PLAYING, Phase.POINT]:
			paused = not paused
			_update_hud()


func _draw() -> void:
	draw_rect(COURT, Color("143849"))
	draw_line(COURT.position, Vector2(COURT.end.x, COURT.position.y), Color("42616e"), 2)
	draw_line(Vector2(COURT.position.x, COURT.end.y), COURT.end, Color("42616e"), 2)
	for y in range(int(COURT.position.y) + 8, int(COURT.end.y), 24):
		draw_line(Vector2(576, y), Vector2(576, y + 10), Color("2c5060"), 3)
	for index in range(trail.size()):
		draw_circle(
			trail[index],
			BALL_RADIUS * (1.0 - float(index) / 14.0),
			Color(0.96, 0.91, 0.74, 0.16 * (1.0 - float(index) / 12.0))
		)
	for index in range(2):
		var style := StyleBoxFlat.new()
		style.bg_color = MINT if index == 0 else CORAL
		style.set_corner_radius_all(6)
		draw_style_box(style, Rect2(paddles[index] - PADDLE_SIZE / 2, PADDLE_SIZE))
	if phase == Phase.PLAYING or phase == Phase.READY:
		draw_circle(ball, BALL_RADIUS, Color("ffe7a4"))


func _smoke_test() -> void:
	# All eight physical keys must drive independent, bounded paddles.
	var expected_keys := [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
	var actions := [
		"p1_left", "p1_right", "p1_up", "p1_down", "p2_left", "p2_right", "p2_up", "p2_down"
	]
	for index in range(actions.size()):
		assert(
			InputMap.action_get_events(actions[index])[0].physical_keycode == expected_keys[index]
		)
		_restart()
		var player_index := 0 if index < 4 else 1
		var start := paddles[player_index]
		Input.action_press(actions[index])
		_move_paddles(0.1)
		Input.action_release(actions[index])
		var movement := paddles[player_index] - start
		var expected: Vector2 = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN][index % 4]
		assert(movement.dot(expected) > 0)
		assert(
			(
				paddles[1 - player_index] == Vector2(1070, 376)
				if player_index == 0
				else paddles[0] == Vector2(82, 376)
			)
		)
	_restart()
	Input.action_press("p1_up")
	Input.action_press("p2_down")
	_move_paddles(10.0)
	Input.action_release("p1_up")
	Input.action_release("p2_down")
	assert(paddles[0].y == COURT.position.y + PADDLE_SIZE.y / 2)
	assert(paddles[1].y == COURT.end.y - PADDLE_SIZE.y / 2)
	Input.action_press("p1_right")
	Input.action_press("p2_left")
	_move_paddles(10.0)
	Input.action_release("p1_right")
	Input.action_release("p2_left")
	assert(paddles[0].x == 400 and paddles[1].x == 752)
	_restart()
	_serve()
	var event := InputEventAction.new()
	event.action = "serve_pause"
	event.pressed = true
	_unhandled_input(event)
	var before := ball
	_physics_process(0.2)
	assert(paused and ball == before)
	_unhandled_input(event)
	assert(not paused)
	ball = Vector2(576, COURT.position.y + BALL_RADIUS + 1)
	ball_velocity = Vector2(200, -400)
	_advance_ball(0.02)
	assert(ball_velocity.y > 0)
	ball = Vector2(576, COURT.end.y - BALL_RADIUS - 1)
	ball_velocity = Vector2(200, 400)
	_advance_ball(0.02)
	assert(ball_velocity.y < 0)
	for index in range(2):
		ball = paddles[index] + Vector2(90 if index == 0 else -90, 0)
		ball_velocity = Vector2(-MAX_SPEED if index == 0 else MAX_SPEED, 0)
		_advance_ball(0.15)
		assert(ball_velocity.x > 0 if index == 0 else ball_velocity.x < 0)
		assert(is_equal_approx(ball_velocity.length(), MAX_SPEED))
	_restart()
	_serve()
	ball = Vector2(COURT.position.x - BALL_RADIUS - 1, 180)
	_advance_ball(0.001)
	assert(scores == [0, 1] and phase == Phase.POINT)
	_physics_process(1.1)
	assert(phase == Phase.PLAYING and ball_velocity.x < 0)
	ball = Vector2(COURT.end.x + BALL_RADIUS + 1, 180)
	_advance_ball(0.001)
	assert(scores == [1, 1])
	scores[0] = WINNING_SCORE - 1
	_point(0)
	assert(phase == Phase.MATCH_OVER and message.text == "PLAYER 1 WINS!")
	before = ball
	_physics_process(1.0)
	assert(ball == before and scores[0] == WINNING_SCORE)
	_restart()
	assert(scores == [0, 0] and phase == Phase.READY and not paused)
	print(
		"PASS Pong: eight keys, independent movement, bounds, pause, walls, fast paddle collisions, scoring, serve, victory, restart"
	)
	get_tree().quit()
