extends SceneTree
## Developer helper: run with --script /absolute/path/to/tools/capture.gd
## and pass -- --output /absolute/path.png plus normal project arguments.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output := ""
	for index in range(args.size() - 1):
		if args[index] == "--output":
			output = args[index + 1]
	if output.is_empty():
		push_error("Pass --output /absolute/path.png")
		quit(1)
		return
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var instance := scene.instantiate()
	root.add_child(instance)
	current_scene = instance
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output)
	if result != OK:
		push_error("Could not save screenshot")
		quit(1)
		return
	print("Captured ", output)
	quit()
