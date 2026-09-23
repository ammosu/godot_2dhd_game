extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func drag(index: int, point: Vector2, movement: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = movement
	root.push_input(event, true)

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags["intro_seen"] = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world._test_mode = true
	world._load_map("ruins", "from_village")
	world.player.global_position = Vector3(0, 0.1, -5.5)
	var rig: Node3D = world.get_node("CameraRig")
	rig.snap_to_target()
	var pad: Control = world.get_node("MobileControls/ControlPad")
	pad._mobile_device = true
	pad.set_process_input(true)
	pad.set_process_unhandled_input(true)
	pad.set_process(true)
	for frame: int in range(3):
		await process_frame
	var field := Vector2(700, 380)
	var yaw: float = rig._target_yaw
	touch(1, field, true)
	check(pad._camera_touch_index == 1, "Unclaimed world touch owns camera gesture")
	drag(1, field + Vector2(4, 0), Vector2(4, 0))
	check(is_equal_approx(rig._target_yaw, yaw), "Touch jitter below deadzone does not rotate")
	drag(1, field + Vector2(84, 0), Vector2(80, 0))
	check(rig._target_yaw < yaw, "Horizontal drag rotates continuously")
	touch(1, field, false)
	check(pad._camera_touch_index == -1, "Lifting camera finger releases ownership")
	yaw = rig._target_yaw
	touch(1, field, true)
	drag(1, field + Vector2(0, 60), Vector2(0, 60))
	drag(1, field + Vector2(80, 60), Vector2(80, 0))
	check(is_equal_approx(yaw, rig._target_yaw), "Vertical swipe cannot turn into a camera drag")
	touch(1, field, false)
	# Exploration HUD is protected even if a passive panel leaves touch unhandled.
	var minimap: Vector2 = world._mini_map.get_global_rect().get_center()
	touch(1, minimap, true)
	drag(1, minimap + Vector2(80, 0), Vector2(80, 0))
	check(is_equal_approx(yaw, rig._target_yaw), "Minimap touch never rotates camera")
	touch(1, minimap, false)
	# Cancel, mode transition, focus loss, and orientation changes discard old touches.
	touch(1, field, true)
	touch(1, field, false, true)
	check(pad._camera_touch_index == -1, "OS touch cancellation releases camera")
	touch(1, field, true)
	state.set_mode(state.Mode.DIALOGUE)
	state.set_mode(state.Mode.EXPLORE)
	drag(1, field + Vector2(80, 0), Vector2(80, 0))
	check(is_equal_approx(yaw, rig._target_yaw), "Returning from dialogue cannot resume stale drag")
	touch(1, field, false)
	touch(1, field, true)
	root.focus_exited.emit()
	check(pad._camera_touch_index == -1, "Focus loss releases camera")
	touch(1, field, false)
	touch(1, field, true)
	pad._landscape = false
	pad._process(0.0)
	check(pad._camera_touch_index == -1, "Portrait orientation releases camera")
	pad._landscape = true
	touch(1, field, false)
	world._start_guardian_battle()
	var ui: CanvasLayer = world.battle_ui
	ui.set_physics_process(false)
	yaw = rig._target_yaw
	touch(1, field, true)
	drag(1, field + Vector2(80, 0), Vector2(80, 0))
	check(is_equal_approx(yaw, rig._target_yaw), "Preparation blocks camera")
	touch(1, field, false)
	ui._preparation.confirmed.emit()
	for frame: int in range(2):
		await process_frame
	ui.session.paused = false
	ui._refresh()
	# One finger moves, another rotates, a third uses a skill through actual input dispatch.
	var stick: Vector2 = pad._joystick_center() + Vector2(50, 0)
	touch(0, stick, true)
	touch(1, field, true)
	drag(1, field + Vector2(-100, 0), Vector2(-100, 0))
	check(rig._target_yaw > yaw and Input.is_action_pressed("move_right"), "Camera drag coexists with movement finger")
	var skill: Vector2 = ui._buttons.skill.get_global_rect().get_center()
	touch(2, skill, true)
	check(float(ui.session.actors[0].skill_cd) > 0 and pad._camera_touch_index == 1, "Third-finger skill keeps movement and camera ownership")
	touch(2, skill, false)
	touch(1, field, false)
	touch(0, stick, false)
	check(not Input.is_action_pressed("move_right"), "Movement release does not stick")
	yaw = rig._target_yaw
	touch(2, skill, true)
	drag(2, skill + Vector2(-100, 0), Vector2(-100, 0))
	touch(2, skill, false)
	var portrait: Vector2 = ui._party_rows[0].portrait.get_global_rect().get_center()
	touch(2, portrait, true)
	drag(2, portrait + Vector2(-100, 0), Vector2(-100, 0))
	touch(2, portrait, false)
	check(is_equal_approx(yaw, rig._target_yaw), "Skills and portraits cannot begin camera rotation")
	touch(1, field, true)
	ui._toggle_pause()
	pad._process(0.0)
	ui._toggle_pause()
	drag(1, field + Vector2(80, 0), Vector2(80, 0))
	touch(1, field, false)
	check(is_equal_approx(yaw, rig._target_yaw), "Pause discards gesture until a new press")
	ui._open_layout_settings()
	touch(1, field, true)
	drag(1, field + Vector2(80, 0), Vector2(80, 0))
	touch(1, field, false)
	check(is_equal_approx(yaw, rig._target_yaw), "Layout settings block camera")
	ui._layout_editor.hide()
	ui.encounter.finish()
	world.queue_free()
	for frame: int in range(6):
		await process_frame
	if failures == 0:
		print("MOBILE_CAMERA_GESTURE_TEST_PASS world_drag multitouch ui_exclusion pause cancellation focus")
	quit(0 if failures == 0 else 1)
