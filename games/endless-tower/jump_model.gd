extends RefCounted
## A conservative motion witness, not a horizontal-distance-only approximation.
## Generation uses a rest start and no momentum/biome jump bonus.

const Climber := preload("res://player.gd")
const STEP := 1.0 / 60.0
const HALF_HEIGHT := 21.0
const LANDING_MARGIN := 6.0
const WORST_WIND := 25.0
const MIN_FRICTION := 0.55


static func steering(x: float, velocity_x: float, target_x: float) -> float:
	var distance := target_x - x
	if absf(distance) < 3.0 and absf(velocity_x) < 45:
		return 0.0
	var braking_distance := velocity_x * velocity_x / (2 * Climber.ACCELERATION)
	if (
		signf(velocity_x) == signf(distance)
		and absf(distance) <= braking_distance + absf(velocity_x) * STEP
	):
		return -signf(velocity_x)
	return signf(distance)


static func flight_time(rise: float) -> float:
	var discriminant := Climber.BASE_JUMP * Climber.BASE_JUMP - 2 * Climber.GRAVITY * rise
	if discriminant <= 0:
		return 0.0
	return (Climber.BASE_JUMP + sqrt(discriminant)) / Climber.GRAVITY


static func landing(source: Rect2, target: Rect2, wind: float = 0.0) -> Dictionary:
	var rise := source.position.y - target.position.y
	if rise <= 0 or flight_time(rise) == 0:
		return {"reachable": false}
	var x := source.get_center().x
	var feet := source.position.y
	var velocity_x := 0.0
	var velocity_y := -Climber.BASE_JUMP
	var goal := target.get_center().x
	for frame in range(100):
		var direction := steering(x, velocity_x, goal)
		if direction != 0:
			velocity_x = move_toward(
				velocity_x, direction * Climber.MAX_SPEED, Climber.ACCELERATION * STEP
			)
		else:
			velocity_x = move_toward(velocity_x, 0, Climber.DRAG * MIN_FRICTION * STEP)
		velocity_x = clampf(velocity_x + wind * STEP, -Climber.MAX_SPEED, Climber.MAX_SPEED)
		# Applying gravity on the first step slightly underestimates the real jump.
		velocity_y += Climber.GRAVITY * STEP
		var previous_feet := feet
		x += velocity_x * STEP
		feet += velocity_y * STEP
		if velocity_y > 0 and previous_feet <= target.position.y and feet >= target.position.y:
			var stop_x := (
				x + signf(velocity_x) * velocity_x * velocity_x / (2 * Climber.ACCELERATION)
			)
			var inset := Climber.HALF_WIDTH + LANDING_MARGIN
			var left := target.position.x + inset
			var right := target.end.x - inset
			return {
				"reachable": x >= left and x <= right and stop_x >= left and stop_x <= right,
				"x": x,
				"velocity_x": velocity_x,
				"frames": frame + 1
			}
	return {"reachable": false}


static func reachable(source: Rect2, target: Rect2) -> bool:
	for wind in [-WORST_WIND, 0.0, WORST_WIND]:
		if not landing(source, target, wind)["reachable"]:
			return false
	return true
