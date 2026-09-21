extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
func _motion(point: Vector2, delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = delta
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)
func _run() -> void:
	var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	battle.start_battle({})
	await process_frame
	await process_frame
	var stage: Control = battle._stage
	var source: Vector2 = stage.global_position + battle._point(0) - Vector2(0, 50)
	var target: Vector2 = stage.global_position + battle._point(2) - Vector2(0, 50)
	_mouse(source, true)
	_motion(source + Vector2(20, 0), Vector2(20, 0))
	await process_frame
	_check(root.gui_is_dragging(), "Pointer motion did not start drag")
	_motion(target, target - source)
	await process_frame
	_mouse(target, false)
	await process_frame
	_check(battle.session.actors[0].row == 2 and battle.session.actors[2].row == 0, "Native pointer drop did not swap")
	_check(not root.gui_is_dragging(), "Drag remained active after release")
	if "--party-art-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/party-round-drag.png")
	battle.free()
	root.get_node("GameState").battle_session = null
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).stop_all()
	await create_timer(0.25).timeout
	if failures == 0:
		print("PARTY_DRAG_TEST_PASS native_press motion drop swap")
	quit(0 if failures == 0 else 1)
