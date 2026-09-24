extends SceneTree
## Real viewport input and responsive layout; no normal save is read or written.
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame: int in range(5):
		await process_frame

func click(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	var before: Dictionary = state._serialize()
	var ui: CanvasLayer = load("res://scripts/ui/class_selection.gd").new()
	root.add_child(ui)
	await settle()
	for id: String in state.HeroClasses.ORDER:
		await click(ui._choices[id])
		check(ui.selected_class == id, "Mouse failed to select " + id)
		for other: String in state.HeroClasses.ORDER:
			check(ui._choices[other].button_pressed == (other == id), "Selection indicator mismatch")
	await click(ui._bodies.female)
	check(ui.selected_body == "female", "Body button blocked")
	await click(ui._styles.ember)
	check(ui.selected_style == "ember", "Palette button blocked")
	await click(ui._motions.walk)
	check(ui.selected_action == "walk", "Motion button blocked")
	await click(ui._directions[2])
	check(ui.selected_facing == 2, "Facing button blocked")
	await click(ui._pause)
	check(not ui._preview.playing, "Pause button blocked")
	check(state._serialize() == before, "UI inputs changed persistent game state")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 720), Vector2i(540, 900), Vector2i(390, 844)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		await settle()
		var scroll: ScrollContainer = find_scroll(ui)
		check(scroll != null, "Missing scroll container")
		if scroll == null:
			continue
		check(scroll.get_h_scroll_bar().max_value <= scroll.size.x + 1.0, "Horizontal overflow at " + str(dimensions))
		if dimensions == Vector2i(1280, 720):
			check(scroll.get_v_scroll_bar().max_value <= scroll.size.y + 1.0, "Desktop opening should show primary action without scrolling")
		scroll.ensure_control_visible(ui._start)
		await settle()
		var rect: Rect2 = ui._start.get_global_rect()
		check(root.get_visible_rect().encloses(rect), "Start button unreachable at " + str(dimensions))
		check(rect.size.y >= 44, "Start touch target too small")
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/wanderlight-class-layout-%dx%d.png" % [dimensions.x, dimensions.y])
	# Keyboard activation from an explicitly focused primary action commits the draft.
	ui._start.grab_focus()
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	check(state.player_class == "thief" and state.player_body == "female" and state.player_style == "ember", "Keyboard start did not commit draft")
	if is_instance_valid(ui):
		ui.queue_free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await process_frame
	if failures.is_empty():
		print("CLASS_SELECTION_LAYOUT_TEST_PASS mouse keyboard responsive draft")
	quit(0 if failures.is_empty() else 1)

func find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node as ScrollContainer
	for child: Node in node.get_children():
		var result: ScrollContainer = find_scroll(child)
		if result != null:
			return result
	return null
