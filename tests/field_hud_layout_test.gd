extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame: int in range(6):
		await process_frame

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world._test_mode = true
	var mobile: bool = "--mobile-controls" in OS.get_cmdline_user_args()
	for map_id: String in ["east_road", "ashen_crypt_1"]:
		world._load_map(map_id, "from_village" if map_id == "east_road" else "entry")
		var field: Node3D = world.player.field_combat
		while not field.ready_for_combat:
			await physics_frame
		field.set_physics_process(false)
		world.player.set_physics_process(false)
		var sizes: Array = [Vector2i(960, 540), Vector2i(1200, 540), Vector2i(960, 720)] if mobile else [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1280, 960)]
		for dimensions: Vector2i in sizes:
			root.content_scale_size = dimensions
			root.size = dimensions
			for class_id: String in ["traveler", "archer", "mage", "thief"]:
				state.player_class = class_id
				field.skill_cooldown = 12.5
				field._update_hud()
				await settle()
				world._layout_interaction_prompt()
				var panel: Rect2 = field.get_hud_rect()
				check(root.get_visible_rect().encloses(panel), "Field panel remains inside viewport")
				check(not world.get_node("HUD/TravelHints").visible, "Exploration shortcuts must not cover field combat")
				check(world._prompt_label.get_global_rect().end.y <= panel.position.y - 10.0, "Interaction prompt reserves space above field panel")
				for action: String in field._buttons:
					var button: Button = field._buttons[action]
					check(panel.encloses(button.get_global_rect()), "Every combat action stays inside panel")
					for other: String in field._buttons:
						if other != action:
							check(not button.get_global_rect().intersects(field._buttons[other].get_global_rect()), "Action buttons remain separate")
				if mobile:
					var pad: Control = world.get_node("MobileControls/ControlPad")
					check(panel.position.x > pad._joystick_center().x + pad.JOYSTICK_RADIUS * 1.45, "Field panel leaves joystick touch region clear")
					check(panel.end.x < pad._action_center().x - pad.ACTION_RADIUS * 1.2, "Field panel leaves interaction touch region clear: %s %s %s" % [class_id, dimensions, panel])
		state.set_mode(state.Mode.EQUIPMENT)
		field._physics_process(0.0)
		check(not field._hud.visible, "Equipment hides field panel")
		state.set_mode(state.Mode.EXPLORE)
		field._physics_process(0.0)
		check(field._hud.visible, "Returning from equipment restores field panel")
	world._load_map("village", "from_east_road")
	await settle()
	check(world.get_node("HUD/TravelHints").visible == not mobile, "Village restores desktop exploration shortcuts")
	check(is_equal_approx(world._prompt_label.offset_bottom, -26.0 if mobile else -74.0), "Village restores original interaction prompt position")
	world.queue_free()
	await settle()
	if failures == 0:
		print("FIELD_HUD_LAYOUT_TEST_PASS field dungeon resize classes prompt shortcuts touch_regions")
	quit(0 if failures == 0 else 1)
