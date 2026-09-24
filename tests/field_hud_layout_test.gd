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

func click(control: Control) -> void:
	for pressed: bool in [true, false]:
		if "--mobile-controls" in OS.get_cmdline_user_args():
			var touch := InputEventScreenTouch.new()
			touch.index = 3
			touch.pressed = pressed
			touch.position = control.get_global_rect().get_center()
			root.push_input(touch, true)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = control.get_global_rect().get_center()
			root.push_input(event, true)
		await process_frame

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/wanderlight-hud-%s-%s-%s.png" % [RenderingServer.get_current_rendering_method(), "mobile" if "--mobile-controls" in OS.get_cmdline_user_args() else "desktop", label])

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world._test_mode = true
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		await create_timer(0.5).timeout
	var mobile: bool = "--mobile-controls" in OS.get_cmdline_user_args()
	for map_id: String in ["east_road", "ashen_crypt_1"]:
		world._load_map(map_id, "from_village" if map_id == "east_road" else "entry")
		var field: Node3D = world.player.field_combat
		while not field.ready_for_combat:
			await physics_frame
		field.set_physics_process(false)
		world.player.set_physics_process(false)
		field._update_hud()
		await settle()
		check(not field._auto_options.visible, "Auto settings default to collapsed on each combat map")
		check(field.automation.enabled and field._auto_button.button_pressed, "Each combat map defaults to automatic combat")
		await click(field._auto_button)
		field._update_hud()
		check(not field.automation.enabled and not field._auto_button.button_pressed, "Round auto button disables automation")
		await click(field._auto_button)
		field._update_hud()
		check(field.automation.enabled and field._auto_button.button_pressed, "Round auto button enables automation and displays its state")
		await click(field._auto_settings_button)
		check(field._auto_options.visible and field.automation.enabled, "Settings open independently of automation")
		check(root.get_visible_rect().encloses(field._auto_options.get_global_rect()), "Settings remain on screen")
		await capture(map_id + "-settings")
		await click(field._auto_settings_button)
		check(not field._auto_options.visible and field.automation.enabled, "Closing settings preserves automation")
		field.movement_velocity(Vector3.RIGHT, 0.016, Vector3.RIGHT)
		field._update_hud()
		check(not field.automation.enabled and not field._auto_button.button_pressed, "Manual movement clears the auto status")
		state.damage_player(10)
		state.spend_mp(1)
		check(world._player_status.hp.value == state.player_hp and world._player_status.mp.value == state.player_mp, "Compact HP and MP follow GameState")
		var map_ui: Node = world.get_node("MapUI")
		await click(map_ui.open_button)
		check(map_ui.visible and state.mode == state.Mode.MAP, "Clicking the mini-map opens the regional map")
		check(not world.player.auto_walk.is_active(), "Opening mini-map does not start navigation")
		map_ui.close()
		var sizes: Array = [Vector2i(960, 540), Vector2i(1200, 540), Vector2i(960, 720)] if mobile else [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1280, 960)]
		for dimensions: Vector2i in sizes:
			root.content_scale_size = dimensions
			root.size = dimensions
			for class_id: String in ["traveler", "archer", "mage", "thief"]:
				state.player_class = class_id
				world._refresh_hud()
				field.skill_cooldown = 12.5
				field._update_hud()
				await settle()
				world._layout_interaction_prompt()
				var location: Control = world.get_node("HUD/QuestPanel")
				check(location.size.y < 60 and location.size.x <= 300, "Location label stays compact")
				check(not world._quest_label.visible, "Quest details do not occupy the game view")
				var panel: Rect2 = field.get_hud_rect()
				check(not panel.intersects(field._auto_button.get_global_rect()), "Auto circle is separate from action icons")
				check(not world._player_status.get_global_rect().intersects(world._mini_map.get_global_rect()), "Compact player card stays above mini-map")
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
				if class_id == "traveler" and dimensions == sizes[0]:
					await capture(map_id + "-collapsed")
		state.set_mode(state.Mode.EQUIPMENT)
		field._physics_process(0.0)
		check(not field._hud.visible, "Equipment hides field panel")
		check(not field._auto_controls.visible, "Equipment hides automation controls")
		state.set_mode(state.Mode.EXPLORE)
		field._physics_process(0.0)
		check(field._hud.visible, "Returning from equipment restores field panel")
	world._load_map("village", "from_east_road")
	await settle()
	check(not is_instance_valid(world.player.field_combat), "Safe area removes all combat controls")
	check(world.get_node("HUD/TravelHints").visible == not mobile, "Village restores desktop exploration shortcuts")
	check(is_equal_approx(world._prompt_label.offset_bottom, -26.0 if mobile else -74.0), "Village restores original interaction prompt position")
	world.queue_free()
	await settle()
	if failures == 0:
		print("FIELD_HUD_LAYOUT_TEST_PASS field dungeon resize classes prompt shortcuts touch_regions")
	quit(0 if failures == 0 else 1)
