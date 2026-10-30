extends Control
## The gallery only launches known Godot projects or fixed exported game paths.

const PAGE_SIZE := 8
const INK := Color("172d36")
const MUTED := Color("647779")
const PAPER := Color("f5f4ed")
const GREEN := Color("186d58")

var library_root := ""
var godot_binary := ""
var source_mode := false
var games: Array[Dictionary] = []
var filtered: Array[Dictionary] = []
var page := 0
var dimension := "all"
var search_text := ""
var running_pid := -1
var running_title := ""
var grid: GridContainer
var page_label: Label
var status: Label
var previous: Button
var next: Button
var subtitle: Label
var error_count := 0
var smoke_mode := false
var filter_buttons: Dictionary = {}
var search_box: LineEdit


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	source_mode = "--source" in args
	smoke_mode = "--smoke-test" in args
	var base := OS.get_executable_path().get_base_dir()
	if base.ends_with("/Contents/MacOS"):
		base = base.path_join("../../..").simplify_path()
	library_root = (
		ProjectSettings.globalize_path("res://..").simplify_path()
		if OS.has_feature("editor")
		else base
	)
	for index in range(args.size() - 1):
		if args[index] == "--library-root":
			library_root = args[index + 1]
		if args[index] == "--godot":
			godot_binary = args[index + 1]
	if OS.has_feature("editor") and godot_binary.is_empty():
		godot_binary = OS.get_executable_path()
		source_mode = true
	_build_ui()
	_refresh()
	if smoke_mode:
		call_deferred("_smoke_test")


func _style(color: Color, radius: int = 14, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _label(text: String, size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, action: Callable, filled := false) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color.WHITE if filled else INK)
	button.add_theme_color_override("font_disabled_color", Color("89958c"))
	button.add_theme_stylebox_override("disabled", _style(Color("e7e9df"), 10))
	button.add_theme_stylebox_override("normal", _style(GREEN if filled else Color.WHITE, 10))
	button.add_theme_stylebox_override(
		"hover", _style(Color("28816b") if filled else Color("e2ece5"), 10)
	)
	button.add_theme_stylebox_override("pressed", _style(Color("b5d6c8"), 10))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 10, GREEN))
	button.pressed.connect(action)
	return button


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = PAPER
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override(
			"margin_" + side, 32 if side in ["left", "right"] else 22
		)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var brand_row := HBoxContainer.new()
	layout.add_child(brand_row)
	brand_row.add_child(_label("◈  GoDot Game Gallery", 19))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_row.add_child(spacer)
	brand_row.add_child(_label("YOUR PERSONAL GAME WORKSHOP", 12, MUTED))
	var hero := HBoxContainer.new()
	hero.custom_minimum_size.y = 106
	layout.add_child(hero)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(heading)
	heading.add_child(_label("Small games. Big ideas.", 40))
	heading.add_child(_label("Make a little world. Learn something new. Press play.", 17, MUTED))
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", _style(Color("e3ebdf"), 14))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(badge)
	badge.add_child(_label("2D + 3D\nONE CURIOUS MIND", 15, GREEN))
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	layout.add_child(toolbar)
	for value in ["all", "2d", "3d"]:
		var text: String = "All games" if value == "all" else value.to_upper()
		var filter_button := _button(text, _select_dimension.bind(value))
		filter_buttons[value] = filter_button
		toolbar.add_child(filter_button)
	var search := LineEdit.new()
	search_box = search
	search.placeholder_text = "Find a game…"
	search.accessibility_name = "Search games"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.add_theme_stylebox_override("normal", _style(Color.WHITE, 10))
	search.add_theme_color_override("font_color", INK)
	search.add_theme_color_override("font_placeholder_color", MUTED)
	search.text_changed.connect(_search_changed)
	toolbar.add_child(search)
	toolbar.add_child(_button("Refresh  ↻", _refresh))
	subtitle = _label("", 13, MUTED)
	layout.add_child(subtitle)
	grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	layout.add_child(grid)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)
	status = _label("Choose a game and make it yours.", 14, MUTED)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(status)
	previous = _button("← Previous", _change_page.bind(-1))
	footer.add_child(previous)
	page_label = _label("", 14)
	footer.add_child(page_label)
	next = _button("Next →", _change_page.bind(1))
	footer.add_child(next)
	var hint := _label(
		"F5  Refresh library     ·     Esc  Back to your games     ·     Create a game: python3 ggg.py new my-game --dimension 3d",
		12,
		MUTED
	)
	if not source_mode:
		hint.text = "Your games, all in one place.     ·     Close a game to return here.     ·     F5  Refresh library"
	layout.add_child(hint)


func _select_dimension(value: String) -> void:
	dimension = value
	page = 0
	_filter()


func _search_changed(value: String) -> void:
	search_text = value.to_lower()
	page = 0
	_filter()


func _change_page(amount: int) -> void:
	page = clampi(page + amount, 0, maxi(0, ceili(filtered.size() / 8.0) - 1))
	_render()


func _sort_games(a: Dictionary, b: Dictionary) -> bool:
	return a["title"].naturalnocasecmp_to(b["title"]) < 0


func _refresh() -> void:
	games.clear()
	error_count = 0
	var directory := DirAccess.open(library_root.path_join("games"))
	if directory == null:
		status.text = "No games folder found. Open the gallery with python3 ggg.py gallery."
		_filter()
		return
	for folder in directory.get_directories():
		if folder.begins_with(".") or directory.is_link(folder):
			continue
		var path := library_root.path_join("games").path_join(folder)
		if not FileAccess.file_exists(path.path_join("game.json")):
			continue
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(path.path_join("game.json"))
		)
		if not _valid_manifest(parsed, folder):
			error_count += 1
			continue
		var data: Dictionary = parsed
		data["folder"] = path
		games.append(data)
	games.sort_custom(_sort_games)
	_filter()
	if error_count > 0:
		status.text = (
			"%d invalid game(s) skipped. Run python3 ggg.py check for details." % error_count
		)
	else:
		status.text = "Choose a game and make it yours."


func _valid_manifest(data: Variant, folder: String) -> bool:
	if not data is Dictionary or data.size() != 7:
		return false
	for key in ["id", "title", "description", "dimension", "thumbnail", "controls"]:
		if not data.has(key) or not data[key] is String or data[key].strip_edges().is_empty():
			return false
	if data.get("schema_version") != 1 or data["id"] != folder:
		return false
	var slug := RegEx.new()
	slug.compile("^[a-z0-9]+(-[a-z0-9]+)*$")
	if slug.search(folder) == null:
		return false
	if (
		data["title"].length() > 60
		or data["description"].length() > 240
		or data["controls"].length() > 180
	):
		return false
	for character in data["title"]:
		if character.unicode_at(0) < 32:
			return false
	var thumbnail: String = data["thumbnail"]
	if thumbnail.is_absolute_path() or ".." in thumbnail.split("/") or "\\" in thumbnail:
		return false
	var path := library_root.path_join("games").path_join(folder)
	if not FileAccess.file_exists(path.path_join(thumbnail)):
		return false
	if source_mode and not FileAccess.file_exists(path.path_join("project.godot")):
		return false
	return (
		data["dimension"] in ["2d", "3d"]
		and thumbnail.get_extension().to_lower() in ["svg", "png", "jpg"]
	)


func _filter() -> void:
	for value in filter_buttons:
		var selected: bool = value == dimension
		filter_buttons[value].add_theme_stylebox_override(
			"normal", _style(GREEN if selected else Color.WHITE, 10)
		)
		filter_buttons[value].add_theme_color_override(
			"font_color", Color.WHITE if selected else INK
		)
		filter_buttons[value].add_theme_color_override("font_hover_color", INK)
	filtered.clear()
	for game in games:
		if dimension != "all" and game["dimension"] != dimension:
			continue
		if (
			not search_text.is_empty()
			and search_text not in (game["title"] + " " + game["description"]).to_lower()
		):
			continue
		filtered.append(game)
	page = clampi(page, 0, maxi(0, ceili(filtered.size() / 8.0) - 1))
	_render()


func _render() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	subtitle.text = (
		"%02d GAMES IN YOUR LIBRARY   /   %s"
		% [games.size(), "READY TO EXPLORE" if not filtered.is_empty() else "NO MATCHING GAMES"]
	)
	for slot in range(PAGE_SIZE):
		var index := page * PAGE_SIZE + slot
		if index < filtered.size():
			grid.add_child(_card(filtered[index]))
		else:
			var placeholder := PanelContainer.new()
			placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
			placeholder.custom_minimum_size = Vector2(0, 206)
			placeholder.add_theme_stylebox_override(
				"panel", _style(Color("eeeee6"), 14, Color("e2e4da"))
			)
			var text := _label("+\nRoom for an idea", 16, Color("91a096"))
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			placeholder.add_child(text)
			grid.add_child(placeholder)
	var pages := maxi(1, ceili(filtered.size() / 8.0))
	page_label.text = "%d / %d" % [page + 1, pages]
	previous.disabled = page == 0
	next.disabled = page + 1 >= pages


func _card(game: Dictionary) -> Button:
	var button := _button("", _launch.bind(game))
	button.custom_minimum_size = Vector2(0, 206)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.tooltip_text = game["description"] + "\n" + game["controls"]
	button.accessibility_name = "Play " + game["title"]
	var inset := MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.add_theme_constant_override("margin_left", 12)
	inset.add_theme_constant_override("margin_right", 12)
	inset.add_theme_constant_override("margin_top", 12)
	inset.add_theme_constant_override("margin_bottom", 12)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inset)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 5)
	inset.add_child(layout)
	var image := TextureRect.new()
	image.custom_minimum_size.y = 112
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var loaded := Image.new()
	if loaded.load(game["folder"].path_join(game["thumbnail"])) == OK:
		image.texture = ImageTexture.create_from_image(loaded)
	layout.add_child(image)
	var title := _label(game["title"], 18)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(title)
	var detail := _label(game["dimension"].to_upper() + "   ·   PLAY & EXPERIMENT   →", 11, GREEN)
	layout.add_child(detail)
	return button


func _launch(game: Dictionary) -> void:
	if running_pid > 0:
		status.text = "Close %s before starting another game." % running_title
		return
	var path: String = game["folder"]
	if source_mode:
		if godot_binary.is_empty() or not FileAccess.file_exists(path.path_join("project.godot")):
			status.text = "Cannot start this project. Run python3 ggg.py doctor."
			return
		running_pid = OS.create_process(godot_binary, ["--path", path])
	elif OS.get_name() == "macOS":
		running_pid = OS.create_process("/usr/bin/open", ["-W", "-n", path.path_join("Game.app")])
	else:
		running_pid = OS.create_process(path.path_join("game.x86_64"), [])
	if running_pid <= 0:
		status.text = "Could not start the game. Check the console for details."
		return
	running_title = game["title"]
	status.text = "Playing %s · close its window to return." % running_title
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


func _process(_delta: float) -> void:
	if running_pid > 0 and not OS.is_process_running(running_pid):
		running_pid = -1
		status.text = "Welcome back. What will you make next?"
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_move_to_foreground()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			_refresh()
		elif event.keycode == KEY_ESCAPE:
			search_box.clear()
			search_text = ""
			dimension = "all"
			page = 0
			_filter()


func _smoke_test() -> void:
	assert(games.size() >= 2, "Starter games must be discovered")
	assert(grid.get_child_count() == 8, "Gallery must always have eight slots")
	dimension = "3d"
	_filter()
	assert(filtered.size() >= 1 and filtered[0]["dimension"] == "3d")
	search_text = "no-game-with-this-name"
	_filter()
	assert(filtered.is_empty() and next.disabled and previous.disabled)
	dimension = "all"
	search_text = ""
	var sample := games[0].duplicate()
	for index in range(9):
		games.append(sample.duplicate())
	_filter()
	assert(not next.disabled)
	page = 1
	_render()
	assert(not previous.disabled)
	assert(grid.get_child_count() == 8)
	await get_tree().process_frame
	print("PASS gallery: discovery, filters, empty state, pagination")
	get_tree().quit()
