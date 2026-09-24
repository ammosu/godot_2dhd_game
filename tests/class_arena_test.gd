extends SceneTree
var failures: Array[String] = []

func _init() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	var state: Node = root.get_node("GameState")
	for id: String in ["archer", "mage", "thief"]:
		state.reset_new_game(false, id, "ember" if "--style-capture" in OS.get_cmdline_user_args() else "original", "female" if "--female" in OS.get_cmdline_user_args() else "male")
		state.flags.intro_seen = true
		var world: Node3D = load("res://scenes/main.tscn").instantiate()
		root.add_child(world)
		world._test_mode = true
		world._load_map("ruins", "from_village")
		world.player.position = Vector3(0, 0.1, -5.5)
		world.get_node("CameraRig").snap_to_target()
		await physics_frame
		world._start_guardian_battle()
		var ui: CanvasLayer = world.battle_ui
		ui.set_physics_process(false)
		ui.confirm_preparation()
		for index: int in range(6):
			var at := Vector2(0, -5.5) if index == 0 else Vector2(0, -7.0 if id == "thief" else -9.0) if index == 3 else Vector2(4, -3 + index)
			ui.session.actors[index].position = at
			ui.encounter.bodies[index].position = Vector3(at.x, 0.1, at.y)
			ui.session.actors[index].cooldown = 100.0 if index > 0 else 0.0
			ui.session.actors[index].facing = Vector2.UP
		ui.encounter.refresh(0.0)
		await physics_frame
		check(ui.session.command("skill"), "Arena skill rejected: " + id)
		for frame: int in range(5):
			ui.advance_combat(0.05, Vector2.ZERO)
		ui._refresh()
		check(ui._buttons.skill.caption == str(state.class_profile().skill), "Skill caption mismatch")
		check(ui._buttons.skill.glyph == str(state.class_profile().glyph), "Class glyph mismatch")
		check(str(ui.encounter.sprites[0].texture.get_meta("variant")) == "class_" + ("female_" if "--female" in OS.get_cmdline_user_args() else "") + id, "Arena wardrobe missing")
		check(ui.session.actors[3].hp < ui.session.actors[3].max_hp, "Arena skill missed")
		if id == "mage":
			check(float(ui.session.actors[3].slow) > 0, "Arena frost slow missing")
		if "--class-capture" in OS.get_cmdline_user_args():
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/wanderlight-class-arena-%s.png" % id)
		world.queue_free()
		await process_frame
		state.clear_party_battle()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.2).timeout
	if failures.is_empty():
		print("CLASS_ARENA_TEST_PASS wardrobe projectile frost shadow costs glyphs")
	quit(0 if failures.is_empty() else 1)
