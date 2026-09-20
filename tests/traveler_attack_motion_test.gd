extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _wait_pose(battle: Node, pose: String) -> void:
	var deadline := Time.get_ticks_msec() + 2000
	var portrait := battle.get("_portraits")[0] as TextureRect
	while not portrait.texture.resource_path.ends_with("_%s.tres" % pose) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(portrait.texture.resource_path.ends_with("_%s.tres" % pose), "Attack phase missing: " + pose)

func _capture(action: String, pose: String) -> void:
	if "--party-art-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.dream-loop/traveler-%s-%s.png" % [action, pose])

func _run() -> void:
	var state := root.get_node("GameState")
	for action: String in ["attack", "slash"]:
		state.call("reset_new_game", false)
		var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
		root.add_child(battle)
		battle.call("start_battle", {"max_hp": 1000})
		var model: RefCounted = state.get("battle_session")
		battle.call("_select_action", action)
		# Static pose previews are separate from the live timing assertions.
		# GPU startup/readback may exceed a 60 ms animation phase.
		if "--party-art-capture" in OS.get_cmdline_user_args():
			for pose: String in ["windup", "recover"]:
				battle.call("_pose", 0, pose)
				await _capture(action, pose)
			battle.call("_pose", 0, "idle")
		battle.call("choose_action", action)
		await _wait_pose(battle, "windup")
		_check(int(model.actors[3].hp) == 1000 and int(model.actors[0].mp) == 20, "Windup applied damage or mana early")
		battle.call("choose_action", action)
		await _wait_pose(battle, "attack")
		_check(not bool(battle.call("can_accept_action")), "Attack phase unlocked input")
		await _wait_pose(battle, "recover")
		_check(int(model.actors[3].hp) == (985 if action == "attack" else 971), "Attack impact did not apply damage once")
		_check(int(model.actors[0].mp) == (20 if action == "attack" else 15), "Attack mana charged more than once")
		await _wait_pose(battle, "idle")
		_check(int(model.current) == 1, "Recovery did not advance to Noah")
		var point: Vector2 = battle.call("_point", 0)
		_check((battle.get("_shadows")[0] as Polygon2D).position.is_equal_approx(point), "Lunge left shadow displaced")
		battle.free()
		state.set("battle_session", null)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("TRAVELER_ATTACK_MOTION_TEST_PASS windup attack recovery idle impact_once mana input_lock shadow")
	quit(0 if failures == 0 else 1)
