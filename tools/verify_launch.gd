extends SceneTree
## Graphical integration check. Launches and closes each discovered game.
## Run with the launcher's --path and normal --source/--library-root/--godot args.


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var gallery := scene.instantiate()
	root.add_child(gallery)
	current_scene = gallery
	assert(gallery.games.size() >= 2)
	for game in gallery.games:
		gallery._launch(game)
		var pid: int = gallery.running_pid
		assert(pid > 0, "Game process must start")
		gallery._launch(game)
		assert(gallery.running_pid == pid, "A second launch must be blocked")
		await create_timer(1.5).timeout
		assert(OS.is_process_running(pid), "Game must remain running")
		# An external signal lets the gallery reap its own child normally.
		OS.execute("/bin/kill", ["-TERM", str(pid)])
		for frame in range(120):
			await process_frame
			if gallery.running_pid == -1:
				break
		assert(gallery.running_pid == -1, "Gallery must detect the game closing")
	print("PASS integration: launched both games, blocked double launch, restored gallery")
	quit()
