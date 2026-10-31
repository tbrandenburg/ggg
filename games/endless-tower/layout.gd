extends RefCounted
## Seeded, physics-constrained chunks. Random access never needs the whole tower.

const Jump := preload("res://jump_model.gd")
const LEFT := 248.0
const RIGHT := 904.0
const START_Y := 640.0
const MEAN_GAP := 84.0
const CHUNK_SIZE := 20
const CACHE_LIMIT := 8
const LAYOUT_VERSION := 2
const BRIDGE_STEP := 125.0

static var _cache: Dictionary = {}
static var _recent: Array[String] = []


static func platform(floor_id: int, seed_value: int) -> Rect2:
	var index := maxi(0, floor_id)
	var chunk := index / CHUNK_SIZE
	return _chunk(chunk, seed_value)[index % CHUNK_SIZE]


static func floor_y(floor_id: int, seed_value: int) -> float:
	return platform(floor_id, seed_value).position.y


static func floor_at_y(world_y: float, seed_value: int) -> int:
	var altitude := maxf(0, START_Y - world_y)
	var chunk := maxi(0, floori(altitude / (MEAN_GAP * CHUNK_SIZE)))
	var floors := _chunk(chunk, seed_value)
	var result := chunk * CHUNK_SIZE
	for index in range(CHUNK_SIZE):
		if START_Y - floors[index].position.y <= altitude + 0.001:
			result = chunk * CHUNK_SIZE + index
		else:
			break
	return result


static func mean_width(chunk: int) -> float:
	# Each level is smaller on average, approaching a safe minimum instead of zero.
	return 84.0 + 136.0 * exp(-maxi(0, chunk) / 8.0)


static func clear_cache() -> void:
	_cache.clear()
	_recent.clear()


static func cache_size() -> int:
	return _cache.size()


static func _rng(seed_value: int, chunk: int, stream: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("tower-v%d:%d:%d:%s" % [LAYOUT_VERSION, seed_value, chunk, stream])
	return rng


static func _balanced(mean: float, spread: float, rng: RandomNumberGenerator) -> Array[float]:
	# Randomized strata and opposite deviations preserve the exact per-level mean.
	# A shuffle hides pairing: widths and gaps fluctuate instead of tapering in order.
	var values: Array[float] = []
	for index in range(CHUNK_SIZE / 2):
		var deviation := (index + rng.randf()) / (CHUNK_SIZE / 2.0) * spread
		values.append(mean + deviation)
		values.append(mean - deviation)
	for index in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var swap := values[index]
		values[index] = values[other]
		values[other] = swap
	return values


static func _widths(chunk: int, seed_value: int) -> Array[float]:
	var mean := mean_width(chunk)
	return _balanced(mean, mean * 0.28, _rng(seed_value, chunk, "widths"))


static func _anchor(chunk: int, seed_value: int, width: float) -> Rect2:
	if chunk == 0:
		return Rect2(LEFT + 10, START_Y, RIGHT - LEFT - 20, 16)
	var rng := _rng(seed_value, chunk, "anchor")
	var center := rng.randf_range(LEFT + width / 2 + 22, RIGHT - width / 2 - 22)
	return Rect2(center - width / 2, START_Y - chunk * CHUNK_SIZE * MEAN_GAP, width, 14)


static func _chunk(chunk: int, seed_value: int) -> Array[Rect2]:
	var key := "%d:%d" % [seed_value, chunk]
	if not _cache.has(key):
		_cache[key] = _generate(chunk, seed_value)
		_recent.append(key)
		if _recent.size() > CACHE_LIMIT:
			_cache.erase(_recent.pop_front())
	else:
		_recent.erase(key)
		_recent.append(key)
	return _cache[key]


static func _generate(chunk: int, seed_value: int) -> Array[Rect2]:
	var widths := _widths(chunk, seed_value)
	var gaps := _balanced(MEAN_GAP, 22.0, _rng(seed_value, chunk, "gaps"))
	var rng := _rng(seed_value, chunk, "placement")
	var result: Array[Rect2] = [_anchor(chunk, seed_value, widths[0])]
	var goal := _anchor(chunk + 1, seed_value, _widths(chunk + 1, seed_value)[0])
	var y := result[0].position.y
	for index in range(1, CHUNK_SIZE):
		y -= gaps[index - 1]
		var width := widths[index]
		var previous := result[index - 1]
		var previous_x := previous.get_center().x
		var remaining := CHUNK_SIZE - index
		# Reserve a conservative route to the next independent chunk's entry anchor.
		var reach := minf(245.0, 145.0 + (chunk * CHUNK_SIZE + index) * 0.8)
		var lo := maxf(LEFT + width / 2 + 12, previous_x - reach)
		var hi := minf(RIGHT - width / 2 - 12, previous_x + reach)
		lo = maxf(lo, goal.get_center().x - remaining * BRIDGE_STEP)
		hi = minf(hi, goal.get_center().x + remaining * BRIDGE_STEP)
		var chosen := Rect2()
		for attempt in range(12):
			var center := rng.randf_range(lo, hi)
			var candidate := Rect2(center - width / 2, y, width, 14)
			if (
				Jump.reachable(previous, candidate)
				and (remaining > 1 or Jump.reachable(candidate, goal))
			):
				chosen = candidate
				break
		if chosen.size.x == 0:
			# Finite fallback: advance toward the anchor, never retry forever.
			var center := clampf(move_toward(previous_x, goal.get_center().x, BRIDGE_STEP), lo, hi)
			chosen = Rect2(center - width / 2, y, width, 14)
			assert(Jump.reachable(previous, chosen), "Conservative bridge must remain jumpable")
			assert(remaining > 1 or Jump.reachable(chosen, goal))
		result.append(chosen)
	return result
