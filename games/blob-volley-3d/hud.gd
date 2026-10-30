extends CanvasLayer

var score_labels: Array[Label] = []
var title: Label
var hint: Label
var touches: Label


func _label(text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func setup(depth_enabled: bool) -> void:
	var ink := Color("173e4e") if depth_enabled else Color("f5f4ed")
	var muted := Color("466575") if depth_enabled else Color("b7cdd2")
	_label(
		"BLOB VOLLEY / " + ("3D" if depth_enabled else "2D"),
		Vector2(24, 26),
		Vector2(280, 30),
		19,
		ink
	)
	_label("FIRST TO 11 · WIN BY TWO", Vector2(835, 28), Vector2(290, 30), 14, muted)
	score_labels.append(_label("0", Vector2(420, 20), Vector2(110, 75), 56, ink))
	score_labels.append(_label("0", Vector2(622, 20), Vector2(110, 75), 56, ink))
	_label(":", Vector2(546, 30), Vector2(60, 60), 40, muted)
	title = _label("", Vector2(226, 110), Vector2(700, 40), 25, ink)
	hint = _label("", Vector2(226, 152), Vector2(700, 30), 17, muted)
	touches = _label("", Vector2(376, 600), Vector2(400, 28), 14, muted)
	var p1 := (
		"P1 · WASD MOVE · SPACE JUMP" if depth_enabled else "P1 · A/D MOVE · W JUMP · S FAST FALL"
	)
	var p2 := (
		"P2 · ARROWS MOVE · ENTER JUMP" if depth_enabled else "P2 · ←/→ MOVE · ↑ JUMP · ↓ FAST FALL"
	)
	_label(p1, Vector2(20, 642), Vector2(510, 30), 16, ink)
	_label(p2, Vector2(622, 642), Vector2(510, 30), 16, ink)
	_label(
		"F  Serve    ·    P  Pause    ·    R  Restart    ·    Esc  Gallery",
		Vector2(176, 684),
		Vector2(800, 28),
		15,
		muted
	)


func refresh(rules) -> void:
	for index in range(2):
		score_labels[index].text = str(rules.scores[index])
	title.text = rules.heading()
	hint.text = rules.instruction()
	touches.text = (
		"P%d TOUCHES  %d / 3" % [rules.last_touch + 1, rules.touch_count]
		if rules.phase == rules.Phase.PLAYING
		else ""
	)
