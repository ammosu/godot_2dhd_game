extends SceneTree
var failures: Array[String] = []
func _init() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	if "--narrow" in OS.get_cmdline_user_args():
		root.content_scale_size = Vector2i(540, 900)
		root.size = Vector2i(540, 900)
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	var before: Dictionary = state._serialize()
	var ui: CanvasLayer = load("res://scripts/ui/class_selection.gd").new()
	root.add_child(ui)
	await process_frame
	ui._preview.set_process(false)
	for body: String in state.HERO_BODIES:
		ui.select_body(body)
		for vocation: String in state.HeroClasses.ORDER:
			ui.select_class(vocation)
			for style: String in state.HeroStyle.ORDER:
				ui.select_style(style)
				for direction: int in range(4):
					ui.select_facing(direction)
					for action: String in ui.Preview.SEQUENCES:
						ui.select_action(action)
						var poses: Array = ui.Preview.SEQUENCES[action]
						for frame: int in range(poses.size()):
							ui._preview.elapsed = (frame + 0.1) / 6.0
							ui._preview._refresh()
							check(ui._preview.current_pose == poses[frame], "Preview pose missing")
							check(ui._preview._sprite.texture != null, "Preview texture missing")
							if body == "female":
								var texture: AtlasTexture = ui._preview._sprite.texture
								check(texture.atlas.resource_path.begins_with("res://assets/generated/heroines/"), "Female preview uses male art")
								check(texture.region.has_area() and texture.region.end.x <= texture.atlas.get_width() and texture.region.end.y <= texture.atlas.get_height(), "Invalid female crop")
						check((ui._preview._sprite.material != null) == (style != "original"), "Palette not applied")
	check(state._serialize() == before, "Preview changed saved progress")
	ui._toggle_pause()
	var elapsed: float = ui._preview.elapsed
	ui._preview._process(0.3)
	check(ui._preview.elapsed == elapsed, "Pause still advances animation")
	ui.select_body("female")
	ui.select_class("mage")
	ui.select_action("idle")
	ui.select_facing(0)
	ui.select_style("ember")
	if "--capture" in OS.get_cmdline_user_args():
		for style: String in state.HeroStyle.ORDER:
			ui.select_style(style)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/wanderlight-selection-%s.png" % style)
	ui.select_style("ember")
	ui.start_journey()
	check(state.player_class == "mage" and state.player_style == "ember" and state.player_body == "female", "Start did not commit appearance")
	var path := "user://hero_selection_test_%d.json" % Time.get_ticks_usec()
	check(state.save_game(path, false), "Save failed")
	state.reset_new_game(false)
	check(state.load_game(path, false) and state.player_style == "ember" and state.player_body == "female", "Appearance roundtrip failed")
	var battle: RefCounted = state.begin_action_battle({"max_hp": 100})
	check(battle.actors[0].hero_style == "ember" and battle.actors[0].hero_body == "female", "Battle lost style")
	state.set_mode(state.Mode.EXPLORE)
	var old: Dictionary = state._serialize()
	old.version = 7
	old.erase("player_style")
	write_save(path, old)
	check(state.load_game(path, false) and state.player_style == "original" and state.player_body == "male", "v7 migration failed")
	old = state._serialize()
	old.version = 8
	old.player_style = "frost"
	old.erase("player_body")
	write_save(path, old)
	check(state.load_game(path, false) and state.player_body == "male" and state.player_style == "frost", "v8 migration lost appearance")
	var invalid: Dictionary = state._serialize()
	invalid.player_style = "bad"
	write_save(path, invalid)
	var prior: Dictionary = state._serialize()
	check(not state.load_game(path, false) and state._serialize() == prior, "Invalid style changed state")
	invalid = state._serialize()
	invalid.player_body = "invalid"
	write_save(path, invalid)
	check(not state.load_game(path, false) and state._serialize() == prior, "Invalid body changed state")
	var equipment: CanvasLayer = load("res://scripts/ui/equipment_ui.gd").new()
	root.add_child(equipment)
	for vocation: String in state.HeroClasses.ORDER:
		state.reset_new_game(false, vocation, "original", "male")
		var stats := Vector4(state.player_max_hp, state.player_max_mp, state.player_attack, state.player_defense)
		state.reset_new_game(false, vocation, "original", "female")
		check(stats == Vector4(state.player_max_hp, state.player_max_mp, state.player_attack, state.player_defense), "Body changed combat stats")
		check(not state.get_loadout().has("hero_body"), "Body polluted equipment")
		equipment.open()
		check(equipment._portrait.texture.atlas.resource_path.begins_with("res://assets/generated/heroines/"), "Equipment lost female art")
		if "--capture" in OS.get_cmdline_user_args():
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/wanderlight-female-equipment-%s.png" % vocation)
		equipment.close()
	equipment.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await process_frame
	if failures.is_empty():
		print("HERO_SELECTION_TEST_PASS actions directions pause palettes save migration")
	state.battle_session = null
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await process_frame
	quit(0 if failures.is_empty() else 1)
func write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
