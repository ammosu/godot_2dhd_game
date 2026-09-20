extends SceneTree
## Static pose comparison only; live timing is covered by motion regressions.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var destination: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			destination = argument.trim_prefix("--capture-dir=")
	if DisplayServer.get_name() == "headless" or not destination.is_absolute_path() or not DirAccess.dir_exists_absolute(destination):
		push_error("Use a real renderer and --capture-dir=<existing absolute directory>")
		quit(1)
		return
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	battle.call("start_battle", {})
	battle.set("_busy", true)
	var failed: bool = false
	for pose: String in ["idle", "windup", "attack", "recover"]:
		for actor: int in range(6):
			battle.call("_pose", actor, pose)
		for frame: int in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		var path := destination.path_join("party-%s-%s.png" % [RenderingServer.get_current_rendering_method(), pose])
		if root.get_texture().get_image().save_png(path) != OK:
			failed = true
			push_error("Cannot save " + path)
	battle.free()
	state.set("battle_session", null)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if not failed:
		print("PARTY_MOTION_CAPTURE_PASS six_actors four_poses screenshots_only")
	quit(1 if failed else 0)
