extends RefCounted
## This game's entire ruleset. Coordinates are meters: X across the net, Y up, Z depth.
## The 2D version locks Z to zero. Each game owns its own independent copy.

enum Phase { READY, PLAYING, POINT, MATCH_OVER }

const HALF_WIDTH := 8.0
const HALF_DEPTH := 4.0
const NET_HEIGHT := 2.4
const NET_HALF_THICKNESS := 0.10
const BLOB_RADIUS := 0.85
const HEAD_HEIGHT := 0.45
const BALL_RADIUS := 0.36
const GRAVITY := 14.0
const MOVE_SPEED := 5.8
const JUMP_SPEED := 7.8
const WINNING_SCORE := 11

var depth_enabled := false
var players: Array[Vector3] = [Vector3(-4.5, 0, 0), Vector3(4.5, 0, 0)]
var velocities: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var scores: Array[int] = [0, 0]
var ball := Vector3(-4.5, 3.5, 0)
var ball_velocity := Vector3.ZERO
var phase := Phase.READY
var paused := false
var server := 0
var last_touch := 0
var touch_count := 0
var touching: Array[bool] = [false, false]
var point_delay := 0.0
var point_reason := ""


func reset() -> void:
	scores.assign([0, 0])
	server = 0
	last_touch = 0
	phase = Phase.READY
	paused = false
	point_delay = 0.0
	point_reason = ""
	_reset_positions()


func _reset_positions() -> void:
	players.assign([Vector3(-4.5, 0, 0), Vector3(4.5, 0, 0)])
	velocities.assign([Vector3.ZERO, Vector3.ZERO])
	ball = players[server] + Vector3(0, 3.5, 0)
	ball_velocity = Vector3.ZERO
	touching.assign([false, false])
	touch_count = 0
	last_touch = server


func serve() -> void:
	ball = players[server] + Vector3(0, 3.5, 0)
	ball_velocity = Vector3(5.5 if server == 0 else -5.5, 6.5, 0)
	touching.assign([false, false])
	touch_count = 0
	last_touch = server
	phase = Phase.PLAYING
	paused = false


func tick(delta: float, moves: Array[Vector2], jumps: Array[bool], dives: Array[bool]) -> void:
	if paused or phase == Phase.MATCH_OVER:
		return
	if phase == Phase.POINT:
		point_delay -= delta
		if point_delay <= 0:
			serve()
		return
	for index in range(2):
		var direction := moves[index].limit_length(1.0)
		velocities[index].x = direction.x * MOVE_SPEED
		velocities[index].z = direction.y * MOVE_SPEED if depth_enabled else 0.0
		if jumps[index] and players[index].y <= 0.001:
			velocities[index].y = JUMP_SPEED
	# Substeps cover both a fast ball and a jumping/moving blob.
	var speed := maxf(ball_velocity.length(), MOVE_SPEED + JUMP_SPEED)
	var steps := maxi(1, ceili(speed * delta / (BALL_RADIUS * 0.45)))
	var step_delta := delta / steps
	for step in range(steps):
		for index in range(2):
			velocities[index].y -= GRAVITY * step_delta * (2.2 if dives[index] else 1.0)
			players[index] += velocities[index] * step_delta
			if players[index].y <= 0:
				players[index].y = 0
				velocities[index].y = 0
			players[index].x = (
				clampf(
					players[index].x, -HALF_WIDTH + BLOB_RADIUS, -BLOB_RADIUS - NET_HALF_THICKNESS
				)
				if index == 0
				else clampf(
					players[index].x, BLOB_RADIUS + NET_HALF_THICKNESS, HALF_WIDTH - BLOB_RADIUS
				)
			)
			players[index].z = (
				clampf(players[index].z, -HALF_DEPTH + BLOB_RADIUS, HALF_DEPTH - BLOB_RADIUS)
				if depth_enabled
				else 0.0
			)
		if phase == Phase.PLAYING:
			_step_ball(step_delta)
			if phase != Phase.PLAYING:
				break
	if phase == Phase.READY:
		ball = players[server] + Vector3(0, 3.5, 0)


func _step_ball(delta: float) -> void:
	var before := ball
	ball_velocity.y -= GRAVITY * delta
	ball += ball_velocity * delta
	if not depth_enabled:
		ball.z = 0
		ball_velocity.z = 0
	for index in range(2):
		var center := players[index] + Vector3(0, HEAD_HEIGHT, 0)
		var offset := ball - center
		var distance := offset.length()
		var contact_distance := BLOB_RADIUS + BALL_RADIUS
		if distance > contact_distance + 0.05:
			touching[index] = false
		elif distance < contact_distance:
			var normal := offset.normalized() if distance > 0.001 else Vector3.UP
			ball = center + normal * (contact_distance + 0.01)
			if not touching[index] and (ball_velocity - velocities[index]).dot(normal) < 0:
				touching[index] = true
				_hit(index, normal)
				if phase != Phase.PLAYING:
					return
	# The net is a box: bounce off its top or reflect off its side.
	var net_edge := NET_HALF_THICKNESS + BALL_RADIUS
	if (
		absf(ball.x) < net_edge
		and ball.y < NET_HEIGHT + BALL_RADIUS
		and absf(ball.z) <= HALF_DEPTH + BALL_RADIUS
	):
		if before.y >= NET_HEIGHT + BALL_RADIUS and ball_velocity.y < 0:
			ball.y = NET_HEIGHT + BALL_RADIUS
			ball_velocity.y = absf(ball_velocity.y) * 0.55
		else:
			var side := -1.0 if before.x < 0 else 1.0
			ball.x = side * net_edge
			ball_velocity.x = side * absf(ball_velocity.x) * 0.65
	if (
		absf(ball.x) > HALF_WIDTH + BALL_RADIUS
		or (depth_enabled and absf(ball.z) > HALF_DEPTH + BALL_RADIUS)
	):
		award_point(1 - last_touch, "OUT OF BOUNDS")
	elif ball.y <= BALL_RADIUS:
		award_point(1 if ball.x < 0 else 0, "BALL DOWN")


func _hit(index: int, normal: Vector3) -> void:
	if last_touch == index:
		touch_count += 1
	else:
		last_touch = index
		touch_count = 1
	if touch_count > 3:
		award_point(1 - index, "FOUR TOUCHES")
		return
	var toward_opponent := 1.0 if index == 0 else -1.0
	ball_velocity.x = toward_opponent * clampf(5.7 + normal.x * toward_opponent * 1.5, 4.2, 7.2)
	ball_velocity.y = 7.8 + maxf(velocities[index].y, 0) * 0.25
	ball_velocity.z = (
		clampf(normal.z * 3.5 + velocities[index].z * 0.6, -4, 4) if depth_enabled else 0.0
	)


func award_point(winner: int, reason: String) -> void:
	scores[winner] += 1
	server = winner
	point_reason = "PLAYER %d · %s" % [winner + 1, reason]
	var enough_points := scores[winner] >= WINNING_SCORE
	var clear_lead := scores[winner] - scores[1 - winner] >= 2
	phase = Phase.MATCH_OVER if enough_points and clear_lead else Phase.POINT
	point_delay = 1.2
	_reset_positions()


func heading() -> String:
	if paused:
		return "PAUSED"
	if phase == Phase.READY:
		return "READY TO VOLLEY?"
	if phase == Phase.MATCH_OVER:
		return "PLAYER %d WINS!" % (1 if scores[0] > scores[1] else 2)
	if phase == Phase.POINT:
		return point_reason
	return ""


func instruction() -> String:
	if paused:
		return "P to resume"
	if phase == Phase.READY:
		return "F to serve · First to 11, win by two"
	if phase == Phase.MATCH_OVER:
		return "R for a rematch · Esc for the gallery"
	if phase == Phase.POINT:
		return "Next serve in a moment…"
	return ""
