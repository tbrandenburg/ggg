extends RefCounted
## Layout depends only on the floor number and seed: no growing history is required.

const LEFT := 248.0
const RIGHT := 904.0
const START_Y := 640.0
const GAP := 88.0


static func platform(floor_id: int, seed_value: int) -> Rect2:
	if floor_id == 0:
		return Rect2(LEFT + 10, START_Y, RIGHT - LEFT - 20, 16)
	var phase := fposmod(seed_value * 0.00017, TAU)
	var drift := (sin(floor_id * 0.47 + phase) - sin(phase)) * 100.0
	drift += (sin(floor_id * 0.13 + phase) - sin(phase)) * 40.0
	var center := clampf(576.0 + drift, LEFT + 120, RIGHT - 120)
	var width := 220.0 - minf(floor_id * 0.12, 60.0)
	width += sin(floor_id * 1.71 + phase) * 8.0
	return Rect2(center - width / 2, START_Y - floor_id * GAP, width, 14)
