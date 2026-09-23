extends SceneTree
## Exercise viewport dispatch so UI hit testing participates in this regression.
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func touch(point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)


func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	# A blocking HUD underneath the dialogue must never swallow its taps.
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(hud)
	var dialogue: CanvasLayer = load("res://scripts/ui/dialogue_ui.gd").new()
	root.add_child(dialogue)
	var lines: Array = []
	for index: int in range(20):
		lines.append({"speaker": "測試", "text": "觸控對話測試 %d" % index})
	dialogue.show_dialogue(lines)
	await process_frame
	await process_frame
	var panel: Control = dialogue._root.get_child(2)
	var points: Array[Vector2] = [
		dialogue._speaker_label.get_global_rect().get_center(),
		dialogue._body_label.get_global_rect().get_center(),
		dialogue._hint_label.get_global_rect().get_center(),
		panel.get_global_rect().position + Vector2(5, 5),
		root.get_visible_rect().size * Vector2(0.5, 0.3),
		Vector2(5, 5),
	]
	for point: Vector2 in points:
		var before: int = dialogue._line_index
		touch(point, true)
		check(dialogue._line_index == before + 1, "Tap must advance exactly once at %s" % point)
		touch(point, false)
		check(dialogue._line_index == before + 1, "Release must not advance")
	var before: int = dialogue._line_index
	touch(points[0], true, true)
	check(dialogue._line_index == before, "Canceled touch must not advance")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	root.push_input(key, true)
	check(dialogue._line_index == before + 1, "Space still advances")
	key.pressed = false
	root.push_input(key, true)
	dialogue.show_dialogue([{"text": "最後一頁"}])
	touch(points[0], true)
	check(not dialogue.is_open() and state.mode == state.Mode.EXPLORE, "Final tap closes dialogue")
	touch(points[0], false)
	dialogue.queue_free()
	hud.queue_free()
	await process_frame
	if failures == 0:
		print("DIALOGUE_TOUCH_TEST_PASS panel text hint background release cancel keyboard finish")
	quit(1 if failures else 0)
