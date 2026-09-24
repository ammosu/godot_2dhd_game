extends SceneTree
## Bounds checks use the actual canvas scale. Optional captures require a renderer.
var failures: int = 0
var capture_dir: String = ""

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) == OK, "Screenshot could not be written")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags["intro_seen"] = true
	var world: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world._test_mode = true
	var mobile: bool = "--mobile-controls" in OS.get_cmdline_user_args()
	var prefix: String = "mobile" if mobile else "desktop"
	var sizes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1440, 900)]
	if mobile:
		sizes = [Vector2i(844, 390), Vector2i(667, 375)]
	for dimensions: Vector2i in sizes:
		root.size = dimensions
		await create_timer(0.4).timeout
		var bounds := root.get_visible_rect()
		var panel: Control = world._map_label.get_parent().get_parent()
		var map_button: Control = world.get_node("HUD/MiniMap/OpenMap")
		check(bounds.encloses(panel.get_global_rect()), "Quest panel outside viewport")
		check(not panel.get_global_rect().intersects(world._mini_map.get_global_rect()), "Quest overlaps map")
		check(bounds.encloses(map_button.get_global_rect()), "Map button outside viewport")
		check(map_button.get_global_rect().is_equal_approx(world._mini_map.get_global_rect()), "Map open target must match mini-map bounds")
		await capture("%s-%dx%d" % [prefix, dimensions.x, dimensions.y])
		world.dialogue_ui.show_dialogue([{"speaker": "艾爾", "text": "月燈的光正在漸漸微弱。沿著月紋石路向北走，穿過村莊的月紋門，就能找到北境遺跡。願月光照亮你的旅程。"}])
		await process_frame
		await process_frame
		check(bounds.encloses(world.dialogue_ui._panel.get_global_rect()), "Dialogue outside viewport")
		check(world.dialogue_ui._panel.get_global_rect().encloses(world.dialogue_ui._body_label.get_global_rect()), "Dialogue text outside panel")
		await capture("%s-dialogue-%dx%d" % [prefix, dimensions.x, dimensions.y])
		world.dialogue_ui.advance()
	world._load_map("ruins", "from_village")
	world.player.global_position = Vector3(0, 0.1, -5.5)
	world.get_node("CameraRig").snap_to_target()
	world._start_guardian_battle()
	world.battle_ui._preparation.confirmed.emit()
	world.battle_ui.session.paused = true
	await process_frame
	await process_frame
	await create_timer(3.0).timeout
	var party: Control = world.battle_ui._root.get_node("PartyStatus")
	var boss: Control = world.battle_ui._root.get_node("BossStatus")
	check(not party.get_global_rect().intersects(boss.get_global_rect()), "Party overlaps boss")
	check(root.get_visible_rect().encloses(party.get_global_rect()), "Party outside viewport")
	if mobile:
		var physical_scale: float = float(root.size.y) / root.get_visible_rect().size.y
		check(world.get_node("HUD/MiniMap/OpenMap").size.y * physical_scale >= 44, "Map touch target below 44 physical pixels")
	print("UI_PRESENTATION_RENDER_FPS %s" % Performance.get_monitor(Performance.TIME_FPS))
	await capture(prefix + "-battle")
	if mobile:
		root.size = Vector2i(390, 844)
		await create_timer(0.3).timeout
		check(not world.get_node("MobileControls/ControlPad")._landscape, "Portrait guidance missing")
		check(world.get_node("MobileControls").layer > world.battle_ui.layer, "Portrait notice must cover battle controls")
		await capture("mobile-portrait")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("UI_PRESENTATION_TEST_PASS bounds quest map dialogue orientation")
	quit(1 if failures else 0)
