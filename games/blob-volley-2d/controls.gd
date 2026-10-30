extends RefCounted

var depth_enabled := false


func setup(in_depth: bool) -> void:
	depth_enabled = in_depth
	var bindings := {
		"p1_left": KEY_A,
		"p1_right": KEY_D,
		"p2_left": KEY_LEFT,
		"p2_right": KEY_RIGHT,
		"p1_jump": KEY_SPACE if in_depth else KEY_W,
		"p2_jump": KEY_ENTER if in_depth else KEY_UP,
		"serve": KEY_F,
		"pause": KEY_P,
		"restart": KEY_R,
		"leave": KEY_ESCAPE,
	}
	if in_depth:
		bindings.merge(
			{"p1_forward": KEY_W, "p1_back": KEY_S, "p2_forward": KEY_UP, "p2_back": KEY_DOWN}
		)
	else:
		bindings.merge({"p1_dive": KEY_S, "p2_dive": KEY_DOWN})
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)


func moves() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for index in range(2):
		var prefix := "p%d_" % (index + 1)
		var across := Input.get_axis(prefix + "left", prefix + "right")
		var depth := Input.get_axis(prefix + "forward", prefix + "back") if depth_enabled else 0.0
		result.append(Vector2(across, depth))
	return result


func jumps() -> Array[bool]:
	var result: Array[bool] = [
		Input.is_action_just_pressed("p1_jump"), Input.is_action_just_pressed("p2_jump")
	]
	return result


func dives() -> Array[bool]:
	var result: Array[bool] = [false, false]
	if not depth_enabled:
		result[0] = Input.is_action_pressed("p1_dive")
		result[1] = Input.is_action_pressed("p2_dive")
	return result


func handle(event: InputEvent, rules, tree: SceneTree) -> void:
	if event.is_action_pressed("leave"):
		tree.quit()
	elif event.is_action_pressed("restart"):
		rules.reset()
	elif event.is_action_pressed("serve") and rules.phase == rules.Phase.READY:
		rules.serve()
	elif (
		event.is_action_pressed("pause")
		and not event.is_echo()
		and rules.phase != rules.Phase.MATCH_OVER
	):
		rules.paused = not rules.paused
