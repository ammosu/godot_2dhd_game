extends SceneTree
var failures: int = 0
const ControlLayout = preload("res://scripts/systems/battle_control_layout.gd")

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func place(ui: CanvasLayer, index: int, point: Vector2) -> void:
	ui.session.actors[index].position = point
	ui.encounter.bodies[index].global_position = Vector3(point.x, 0.1, point.y)

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags["intro_seen"] = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world._test_mode = true
	world._load_map("ruins", "from_village")
	var player: CharacterBody3D = world.player
	player.global_position = Vector3(0, 0.1, -5.5)
	var rig: Node3D = world.get_node("CameraRig")
	rig.snap_to_target()
	for frame: int in range(3):
		await physics_frame
	var exploration_distance: float = rig._distance
	var map: Node3D = world._map_root
	var camera: Camera3D = root.get_camera_3d()
	var before: Vector3 = player.global_position
	world._start_guardian_battle()
	var ui: CanvasLayer = world.battle_ui
	ui.set_physics_process(false)
	ui._control_layout.settings_path = "user://battle_layout_test_%d.cfg" % OS.get_process_id()
	ui._control_layout.load_preferences()
	ui._skill_dock.apply_layout(ui._control_layout.values)
	check(ui._preparing and ui.session.paused, "Preparation must freeze the encounter before confirmation")
	var prepared_positions: Array = ui.session.actors.duplicate(true)
	ui.advance_combat(0.05, Vector2.RIGHT)
	ui._toggle_pause()
	check(ui.session.actors == prepared_positions and ui.session.paused, "Preparation blocks combat and pause shortcuts")
	ui._preparation.confirmed.emit()
	check(not ui._preparing and not ui.session.paused and not ui.session.auto_enabled, "Manual confirmation releases combat")
	# Reopen only the preparation gate to exercise the real option-to-model signal.
	ui._preparing = true
	ui.session.paused = true
	ui._preparation.open_choices()
	ui._preparation.auto_mode.button_pressed = true
	ui._preparation.skills.button_pressed = false
	ui._preparation.potions.button_pressed = true
	ui._preparation.threshold.select(1)
	check(not ui._preparation.threshold.disabled, "Potion toggle enables threshold choice")
	ui._preparation.confirmed.emit()
	check(ui.session.auto_enabled and not ui.session.auto_use_skills and ui.session.auto_use_potions and is_equal_approx(ui.session.auto_potion_threshold, 0.5), "Popup choices reach the combat model")
	ui.session.configure_automation({})

	check(ui.is_active() and state.mode == state.Mode.BATTLE, "World encounter must start")
	check(world._map_root == map and root.get_camera_3d() == camera, "Combat must retain map and exploration camera")
	check(ui.find_children("*", "SubViewport", true, false).is_empty(), "Combat HUD must not own a separate rendered world")
	check(player.global_position.is_equal_approx(before) and ui.encounter.bodies[0] == player, "Starting combat must retain actual traveler body and position")
	check(not player.is_physics_processing(), "Exploration must not also move the combat body")
	var positions: Array[Vector2] = []
	for actor: Dictionary in ui.session.actors:
		positions.append(actor.position)
	# Actual ruin column blocks both walking and dash sweeps.
	place(ui, 0, Vector2(-4.4, -8.8))
	for index: int in range(40):
		ui.session._move(0, Vector2(-0.15, 0))
	check(float(ui.session.actors[0].position.x) > -6.0, "Walking cannot pass through original ruin column")
	ui.session.actors[0].facing = Vector2.LEFT
	ui.session.command("dodge")
	for frame: int in range(15):
		ui.advance_combat(1.0 / 60.0, Vector2.LEFT)
	check(float(ui.session.actors[0].position.x) > -6.0, "Dodge cannot tunnel through original column")
	# A skill whose radius overlaps the opposite side still cannot hit through stone.
	place(ui, 0, Vector2(-4.8, -8.8))
	place(ui, 3, Vector2(-7.5, -8.8))
	ui.session.actors[0].aim = Vector2(-5.8, -8.8)
	ui.session.actors[0].radius = 2.2
	ui.session.actors[0].intent = "skill"
	ui.session.actors[3].invulnerable = 0.0
	var hp: int = ui.session.actors[3].hp
	ui.session._impact(0)
	check(int(ui.session.actors[3].hp) == hp, "Melee and area damage cannot cross solid scenery")
	check(not ui.encounter._visible(0, 3, ui.session.actors[3].position), "Ranged targeting also checks map occlusion")
	# Enemy pursuit must route around the physical column, not merely press into it.
	place(ui, 3, Vector2(-4.4, -8.8))
	place(ui, 0, Vector2(-7.5, -8.8))
	place(ui, 1, Vector2(5, -2))
	place(ui, 2, Vector2(6, -2))
	ui.session.actors[3].cooldown = 100.0
	for frame: int in range(480):
		ui.session._ai(3, 1.0 / 60.0)
		ui.encounter.refresh(1.0 / 60.0)
	check(Vector2(ui.session.actors[3].position).distance_to(ui.session.actors[0].position) < 1.8, "Enemy AI must reach target by going around column")
	check(float(ui.session.actors[3].position.x) < -6.2, "Enemy must navigate to the other side of obstruction")
	# Pause, camera-relative control and switching stay on the original camera.
	var pause := InputEventKey.new()
	pause.physical_keycode = KEY_ESCAPE
	pause.pressed = true
	ui._input(pause)
	before = player.global_position
	ui.advance_combat(0.05, Vector2.RIGHT)
	check(ui.session.paused and player.global_position == before, "Pause freezes world combat")
	ui._input(pause)
	var direction: Vector2 = ui.encounter.input_direction(Vector2.RIGHT)
	var right: Vector3 = camera.global_basis.x
	check(direction.dot(Vector2(right.x, right.z).normalized()) > 0.99, "Movement remains relative to actual exploration camera")
	ui.choose_action("switch")
	ui.encounter.refresh(0.0)
	check(rig._combat_target == ui.encounter.bodies[1], "Switching allies updates camera follow target")
	ui.choose_action("skill")
	check(ui._buttons.skill.disabled, "HUD reports per-character skill cooldown")
	# A second touch can trigger a skill while the original exploration stick is held.
	var pad: Control = world.get_node("MobileControls/ControlPad")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = pad._joystick_center() + Vector2(55, 0)
	pad._handle_touch(touch)
	check(Input.get_action_strength("move_right") > 0.0, "Original touch joystick remains active in combat")
	ui.session.actors[ui.session.controlled].skill_cd = 0.0
	ui.session.actors[ui.session.controlled].cooldown = 0.0
	ui._refresh()
	await process_frame # Let containers apply the new button text/minimum sizes.
	var status_rect: Rect2 = ui._root.get_node("PartyStatus").get_global_rect()
	var dock_rect: Rect2 = ui._root.get_node("SkillDock").get_global_rect()
	check(status_rect.position.x > ui._root.size.x * 0.5 and status_rect.position.y < 30.0, "Party status is anchored at top right")
	check(dock_rect.position.x > ui._root.size.x * 0.5 and dock_rect.end.y <= ui._root.size.y, "Skills stay inside bottom right")
	check(not status_rect.intersects(dock_rect), "Status and skills must not overlap")
	check(not world._mini_map.visible, "Exploration minimap leaves room for battle status")
	check(ui._party_rows.size() == 3, "All three party members have live status bars")
	for index: int in range(3):
		check(int(ui._party_rows[index].hp.value) == int(ui.session.actors[index].hp), "Party HP reflects authoritative combat state")
		check(int(ui._party_rows[index].mp.value) == int(ui.session.actors[index].mp), "Party MP reflects authoritative combat state")
		var portrait: AtlasTexture = ui._party_rows[index].portrait.texture
		check(portrait.atlas.resource_path.ends_with("%s_combat.png" % ui.session.actors[index].art), "Each portrait belongs to the displayed actor")
		check(portrait.get_image().get_used_rect().has_area(), "Portrait crop contains visible character art")
	var card_actor: Dictionary = ui.session.actors[0].duplicate(true)
	ui.session.actors[0].hp = 1
	ui.session.actors[0].ward = 0.0
	ui._refresh()
	check(ui._party_rows[0].status.text == "危急" and ui._party_rows[ui.session.controlled].title.text.begins_with("▶"), "Low HP and controlled actor remain distinguishable")
	ui.session.actors[0].ward = 1.0
	ui._refresh()
	check(ui._party_rows[0].status.text == "守護", "Portrait card reflects protection")
	ui.session.actors[0].hp = 0
	ui._refresh()
	check(ui._party_rows[0].status.text == "倒下" and ui._party_rows[0].portrait.modulate != Color.WHITE, "Defeated portraits dim and show state text")
	ui.session.actors[0] = card_actor
	ui._refresh()
	ui.session.paused = false
	var skill_touch := InputEventScreenTouch.new()
	skill_touch.index = 1
	skill_touch.pressed = true
	skill_touch.position = ui._buttons.skill.get_global_rect().get_center()
	ui._input(skill_touch)
	check(float(ui.session.actors[ui.session.controlled].skill_cd) > 0.0 and Input.get_action_strength("move_right") > 0.0, "Skill touch must work without releasing movement finger")
	touch.pressed = false
	pad._handle_touch(touch)
	check(Input.get_action_strength("move_right") == 0.0, "Touch release clears movement")
	var auto_key := InputEventKey.new()
	auto_key.physical_keycode = KEY_B
	auto_key.pressed = true
	ui._input(auto_key)
	check(ui.session.auto_enabled and ui._auto_button.button_pressed, "B enables auto and updates button state")
	ui.choose_action("switch")
	check(ui.session.auto_enabled, "Tab retains auto while changing followed character")
	ui.choose_action("attack")
	check(not ui.session.auto_enabled, "Manual attack takes control from auto")
	ui._toggle_pause()
	var auto_touch := InputEventScreenTouch.new()
	auto_touch.index = 1
	auto_touch.pressed = true
	auto_touch.position = ui._auto_button.get_global_rect().get_center()
	ui._input(auto_touch)
	check(ui.session.auto_enabled and ui.session.paused, "Auto touch toggle works without resuming paused battle")
	ui._toggle_pause()
	# Layout settings pause combat, preview drafts, and save only isolated preferences.
	ui.session.paused = false
	ui._open_layout_settings()
	check(ui._layout_editor.visible and ui.session.paused, "Layout editor pauses combat")
	var frozen: Array = ui.session.actors.duplicate(true)
	ui.advance_combat(0.1, Vector2.RIGHT)
	ui.choose_action("switch")
	ui._toggle_pause()
	check(ui.session.actors == frozen and ui.session.paused, "Layout editor blocks gameplay and pause shortcuts")
	var original_layout: Dictionary = ui._skill_dock.layout.duplicate(true)
	ui._layout_editor.sliders.size.value = 0.85
	ui._layout_editor._swap_slot(0, 2)
	check(ui._layout_editor.draft.order[0] == "skill" and ui._layout_editor.draft.order[2] == "potion", "Changing a slot swaps actions without duplicates")
	check(ui._skill_dock.layout == original_layout, "Draft edits do not affect active layout before save")
	if DisplayServer.get_name() != "headless":
		for frame: int in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		ui._layout_editor.get_texture().get_image().save_png("/tmp/wanderlight-control-settings.png")
	ui._layout_editor.hide()
	check(ui._skill_dock.layout == original_layout and not FileAccess.file_exists(ui._control_layout.settings_path), "Cancel discards draft without writing preferences")
	check(not ui.session.paused, "Closing settings restores running combat")
	ui.session.paused = true
	ui._open_layout_settings()
	ui._layout_editor.sliders.radius.value = 202.0
	ui._layout_editor._swap_slot(0, 2)
	ui._layout_editor.save_draft()
	check(not ui._layout_editor.visible and ui.session.paused, "Saving preserves an already paused encounter")
	var reloaded := ControlLayout.new()
	reloaded.settings_path = ui._control_layout.settings_path
	reloaded.load_preferences()
	check(reloaded.values == ui._skill_dock.layout and reloaded.values.order[0] == "skill", "Saved order and size survive loading a new preferences instance")
	ui._open_layout_settings()
	ui._layout_editor.reset_draft()
	check(ui._layout_editor.draft == ControlLayout.DEFAULTS, "Restore defaults previews original arc")
	ui._layout_editor.hide()
	check(ui._skill_dock.layout == reloaded.values, "Cancelling reset retains saved layout")
	DirAccess.remove_absolute(ui._control_layout.settings_path)
	ui._control_layout.values = ControlLayout.DEFAULTS.duplicate(true)
	ui._skill_dock.apply_layout(ui._control_layout.values)
	ui.session.paused = false
	# Every supported size/spacing extreme keeps the circular targets separate and on-screen.
	for radius: float in [174.0, 218.0]:
		for diameter: float in [0.8, 1.05]:
			var layout: Dictionary = ControlLayout.DEFAULTS.duplicate(true)
			layout.radius = radius
			layout.size = diameter
			layout.inset_x = 32.0
			layout.inset_y = 32.0
			ui._skill_dock.apply_layout(layout)
			for action: String in ui._buttons:
				var button: Button = ui._buttons[action]
				var rect: Rect2 = button.get_global_rect()
				check(Rect2(Vector2.ZERO, ui._root.size).encloses(rect), "Round controls stay inside viewport at layout extremes")
				check(not status_rect.intersects(rect), "Round controls do not cover party status")
				check(not button.contains_screen_point(rect.position + Vector2.ONE), "Transparent square corners do not trigger round buttons")
				for other_action: String in ui._buttons:
					if other_action == action:
						continue
					var other: Rect2 = ui._buttons[other_action].get_global_rect()
					check(rect.get_center().distance_to(other.get_center()) > (rect.size.x + other.size.x) * 0.5, "Circular hit targets never overlap")
	ui._skill_dock.apply_layout(ControlLayout.DEFAULTS)
	var sanitized: Dictionary = ControlLayout.sanitize({"size": NAN, "radius": "bad", "order": ["skill", "skill", "skill", "skill"]})
	check(sanitized == ControlLayout.DEFAULTS, "Invalid preferences fall back to safe defaults")
	# Reset positions and show a real terrain warning for native visual inspection.
	for index: int in range(6):
		place(ui, index, positions[index])
		ui.session.actors[index].hp = ui.session.actors[index].max_hp
		ui.session.actors[index].windup = 0.0
		ui.session.actors[index].dash = 0.0
		ui.session.actors[index].hurt = 0.0
		ui.session.actors[index].swing = 0.0
		ui.session.actors[index].ward = 0.0
		ui.session.actors[index].mp = ui.session.actors[index].max_mp
		ui.session.actors[index].cooldown = 0.0
		ui.session.actors[index].skill_cd = 0.0
	ui.session.controlled = 0
	ui.session._start_attack(3, false)
	ui.encounter.refresh(0.0)
	ui._refresh()
	for frame: int in range(45):
		rig._process(1.0 / 60.0)
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/wanderlight-world-battle.png")
	if DisplayServer.get_name() != "headless":
		ui.encounter._effect("moon_slash", ui.session.actors[3].position, 2.2)
		ui.encounter._effect("frost", ui.session.actors[5].position, 2.2)
		ui.encounter._effect("heal", ui.session.actors[2].position, 1.0)
		ui.encounter.advance_effects(0.12)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/wanderlight-battle-effects-%s.png" % RenderingServer.get_current_rendering_method())
	ui.session.paused = false
	ui.session.set_auto_enabled(true)
	var potions: int = int(state.inventory.get("potion", 0))
	for frame: int in range(7200):
		ui.advance_combat(1.0 / 60.0, Vector2.ZERO)
		if ui.is_resolved():
			break
	before = player.global_position
	check(int(state.inventory.get("potion", 0)) == potions, "Full automatic world battle never consumes potions")
	check(not ui.session.auto_enabled, "Victory disables auto")
	check(ui.is_resolved() and ui.did_player_win(), "Victory resolves without a separate result screen")
	check(state.flags.get("guardian_defeated", false) and int(state.inventory.get("moon_shard", 0)) == 1, "Victory grants original quest reward once")
	await create_timer(1.4).timeout
	check(not ui.is_active() and state.battle_session == null, "Victory automatically leaves combat without Continue")
	check(world._map_root == map and player.global_position.distance_to(before) < 0.15, "Victory keeps same map instance and traveler location")
	check(player.is_physics_processing() and player.collision_layer == 1 and player.get_node("Sprite3D").visible, "Exploration physics and art restore")
	check(not player.has_node("CombatArt") and not map.has_node("WorldCombat"), "Temporary combat art and bodies clean up")
	check(rig._combat_target == null and is_equal_approx(rig._distance, exploration_distance), "Camera restores original exploration zoom")
	check(not map.has_node("Guardian"), "Defeated guardian is removed without reloading terrain")
	world.queue_free()
	for frame: int in range(6):
		await process_frame
	for audio_player: Node in root.find_children("*", "AudioStreamPlayer", true, false):
		audio_player.stop()
	await create_timer(0.15).timeout
	if failures == 0:
		print("ACTION_BATTLE_UI_TEST_PASS same_map camera collision dodge obstruction navigation pause switching automatic_exit cleanup radial_settings")
	quit(0 if failures == 0 else 1)
