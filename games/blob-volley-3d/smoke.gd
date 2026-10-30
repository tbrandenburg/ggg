extends RefCounted


static func run(rules, controls, depth_enabled: bool) -> void:
	var still: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	var no: Array[bool] = [false, false]
	rules.reset()
	rules.tick(0.01, controls.moves(), controls.jumps(), controls.dives())
	assert(rules.phase == rules.Phase.READY and rules.scores == [0, 0])
	# Physical bindings are separate for each player; depth movement is real in 3D.
	var names := ["p1_left", "p1_right", "p2_left", "p2_right", "p1_jump", "p2_jump"]
	var keys := [
		KEY_A,
		KEY_D,
		KEY_LEFT,
		KEY_RIGHT,
		KEY_SPACE if depth_enabled else KEY_W,
		KEY_ENTER if depth_enabled else KEY_UP
	]
	for index in range(names.size()):
		assert(InputMap.action_get_events(names[index])[0].physical_keycode == keys[index])
	Input.action_press("p1_right")
	Input.action_press("p2_left")
	rules.tick(0.1, controls.moves(), no, no)
	Input.action_release("p1_right")
	Input.action_release("p2_left")
	assert(rules.players[0].x > -4.5 and rules.players[1].x < 4.5)
	if depth_enabled:
		var depth_names := ["p1_forward", "p1_back", "p2_forward", "p2_back"]
		var depth_keys := [KEY_W, KEY_S, KEY_UP, KEY_DOWN]
		for index in range(depth_names.size()):
			assert(
				(
					InputMap.action_get_events(depth_names[index])[0].physical_keycode
					== depth_keys[index]
				)
			)
		Input.action_press("p1_forward")
		rules.tick(0.1, controls.moves(), no, no)
		Input.action_release("p1_forward")
		assert(rules.players[0].z < 0 and rules.players[1].z == 0)
	else:
		assert(InputMap.action_get_events("p1_dive")[0].physical_keycode == KEY_S)
		assert(InputMap.action_get_events("p2_dive")[0].physical_keycode == KEY_DOWN)
	rules.reset()
	var jumping: Array[bool] = [true, true]
	rules.tick(0.1, still, jumping, no)
	assert(rules.players[0].y > 0 and rules.players[1].y > 0)
	rules.tick(1.5, still, no, no)
	assert(rules.players[0].y == 0 and rules.players[1].y == 0)
	var inward: Array[Vector2] = [Vector2(1, 1), Vector2(-1, -1)]
	rules.tick(3.0, inward, no, no)
	assert(rules.players[0].x <= -0.9499 and rules.players[1].x >= 0.9499)
	assert(absf(rules.players[0].z) <= 3.1501)
	if not depth_enabled:
		assert(rules.players[0].z == 0 and rules.players[1].z == 0)
	rules.reset()
	rules.serve()
	assert(rules.phase == rules.Phase.PLAYING and rules.ball_velocity.x > 0)
	var before: Vector3 = rules.ball
	rules.paused = true
	rules.tick(0.2, inward, jumping, no)
	assert(rules.ball == before and rules.players[0].y == 0)
	rules.paused = false
	# A falling ball hits the head once, then separates rather than adding touches every frame.
	rules.ball = (
		rules.players[0]
		+ Vector3(0, rules.HEAD_HEIGHT + rules.BLOB_RADIUS + rules.BALL_RADIUS - 0.02, 0)
	)
	rules.ball_velocity = Vector3(0, -4, 0)
	rules.tick(0.01, still, no, no)
	assert(rules.ball_velocity.y > 0 and rules.ball_velocity.x > 0 and rules.touch_count == 1)
	rules.tick(0.01, still, no, no)
	assert(rules.touch_count == 1)
	# Very fast ball still contacts a blob because the solver subdivides its motion.
	rules.reset()
	rules.serve()
	rules.ball = Vector3(-6.5, 1.0, 0)
	rules.ball_velocity = Vector3(80, 0, 0)
	rules.tick(0.04, still, no, no)
	assert(rules.touch_count == 1 and rules.last_touch == 0 and rules.ball_velocity.y > 0)
	# Net side and tape collisions are different responses.
	rules.reset()
	rules.serve()
	rules.ball = Vector3(-0.5, 1.8, 0)
	rules.ball_velocity = Vector3(5, 0, 0)
	rules.tick(0.04, still, no, no)
	assert(rules.ball_velocity.x < 0 and rules.ball.x < 0)
	rules.ball = Vector3(0, 2.9, 0)
	rules.ball_velocity = Vector3(0, -5, 0)
	rules.tick(0.04, still, no, no)
	assert(rules.ball_velocity.y > 0)
	for loser in range(2):
		rules.reset()
		rules.serve()
		rules.ball = Vector3(-2 if loser == 0 else 2, 0.2, 0)
		rules.ball_velocity = Vector3.ZERO
		rules.tick(0.01, still, no, no)
		assert(rules.scores[1 - loser] == 1 and rules.phase == rules.Phase.POINT)
		var delay: float = rules.point_delay
		rules.paused = true
		rules.tick(0.2, still, no, no)
		assert(rules.point_delay == delay)
		rules.paused = false
		rules.tick(1.3, still, no, no)
		assert(rules.phase == rules.Phase.PLAYING and rules.server == 1 - loser)
	rules.reset()
	rules.serve()
	rules.ball = Vector3(8.6, 3, 0)
	rules.ball_velocity = Vector3.ZERO
	rules.tick(0.01, still, no, no)
	assert(rules.scores == [0, 1])
	if depth_enabled:
		rules.reset()
		rules.serve()
		rules.ball = Vector3(-2, 3, 4.6)
		rules.ball_velocity = Vector3.ZERO
		rules.tick(0.01, still, no, no)
		assert(rules.scores == [0, 1])
	rules.reset()
	rules.serve()
	for hit in range(3):
		rules._hit(0, Vector3.UP)
	assert(rules.phase == rules.Phase.PLAYING and rules.touch_count == 3)
	rules._hit(0, Vector3.UP)
	assert(rules.scores == [0, 1] and "FOUR TOUCHES" in rules.point_reason)
	rules.reset()
	rules.scores.assign([10, 10])
	rules.award_point(0, "TEST")
	assert(rules.phase == rules.Phase.POINT)
	rules.award_point(0, "TEST")
	assert(rules.phase == rules.Phase.MATCH_OVER and rules.scores == [12, 10])
	rules.reset()
	assert(rules.scores == [0, 0] and rules.phase == rules.Phase.READY)
	print(
		(
			"PASS Blob Volley %s: controls, simultaneous movement, jump, limits, head hits, contact debounce, fast ball, net, scoring, serves, three-touch rule, deuce, restart"
			% ("3D" if depth_enabled else "2D")
		)
	)
