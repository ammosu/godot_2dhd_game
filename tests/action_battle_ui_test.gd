extends SceneTree
var failures: int = 0

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
	ui.session.paused = false
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
		print("ACTION_BATTLE_UI_TEST_PASS same_map camera collision dodge obstruction navigation pause switching automatic_exit cleanup")
	quit(0 if failures == 0 else 1)
