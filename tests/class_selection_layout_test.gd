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

func key(keycode: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
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
	check(ui.auto_cycle and ui.selected_action == "idle", "Preview should open on the motion carousel")
	ui._process(2.1)
	check(ui.selected_action == "walk", "Carousel did not advance")
	await click(ui._choices.mage)
	check(ui.selected_action == "cast" and ui._preview.entrance < 1.0, "Class switch should replay entrance and signature motion")
	await click(ui._choices.traveler)
	for id: String in state.HeroClasses.ORDER:
		await click(ui._choices[id])
		check(ui.selected_class == id, "Mouse failed to select " + id)
		for other: String in state.HeroClasses.ORDER:
			check(ui._choices[other].button_pressed == (other == id), "Selection indicator mismatch")
	check(not ui._bodies.female.is_visible_in_tree(), "Appearance step should start hidden")
	await click(ui._steps[1])
	check(ui._step == 1 and ui._bodies.female.is_visible_in_tree(), "Appearance tab blocked")
	await click(ui._bodies.female)
	check(ui.selected_body == "female", "Body button blocked")
	await click(ui._styles.ember)
	check(ui.selected_style == "ember", "Palette button blocked")
	await click(ui._motions.walk)
	check(ui.selected_action == "walk" and not ui.auto_cycle, "Motion button should pick by hand and stop the carousel")
	ui._process(5.0)
	check(ui.selected_action == "walk", "Carousel kept running after a manual pick")
	await click(ui._cycle)
	check(ui.auto_cycle and ui.selected_action == "idle", "Carousel button blocked")
	await click(ui._motions.walk)
	await click(ui._directions[2])
	check(ui.selected_facing == 2, "Facing button blocked")
	await click(ui._pause)
	check(not ui._preview.playing, "Pause button blocked")
	await key(KEY_E)
	check(ui.selected_facing == 3, "E should rotate the preview")
	await key(KEY_Q)
	check(ui.selected_facing == 2, "Q should rotate the preview back")
	await key(KEY_ESCAPE)
	check(ui._step == 0 and ui._choices.thief.has_focus(), "Esc should return to the vocation step")
	await key(KEY_ENTER)
	check(ui._step == 1 and ui.selected_class == "thief", "Enter on the roster should advance to appearance")
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
	await key(KEY_ENTER)
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
