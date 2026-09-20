extends SceneTree
const Dressing = preload("res://scripts/gameplay/house_dressing.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.get_node("Player").set_physics_process(false)
	_check(Dressing.ARRANGEMENTS.size() == 8, "Expected eight house arrangements")
	for crop: Rect2 in Dressing.CROPS:
		_check(Rect2(Vector2.ZERO, Dressing.PRINTS.get_size()).encloses(crop), "Print crop outside atlas")
	for id: String in Dressing.ARRANGEMENTS:
		world.call("_load_map", id, "entry")
		# Physics is disabled for static art capture; place feet on the real
		# board/collision top rather than leaving the player at spawn clearance.
		(world.get_node("Player") as Node3D).position.y = 0.024
		await process_frame
		var room := (world.get("_map_root") as Node).get_node("HouseInterior")
		var decor := room.get_node("RoomDressing")
		var config: Dictionary = Dressing.ARRANGEMENTS[id]
		_check(decor.get_meta("theme") == config.theme, "House theme not applied")
		_check(decor.find_children("*", "CollisionObject3D", true, false).is_empty(), "Decoration introduced collision")
		for pair: Array in [["BookStack", "books"], ["Scroll", "scrolls"], ["TablePot", "pots"]]:
			var count: int = decor.get_children().filter(func(child: Node) -> bool: return String(child.name).begins_with(pair[0])).size()
			_check(count == int(config[pair[1]]), "Wrong prop count in " + id + ": " + pair[0])
		var wall := room.get("_walls")[1] as Node3D
		var frame := wall.get_node("WallPrint") as Node3D
		var print_mesh := frame.get_node("Print") as MeshInstance3D
		_check(int(print_mesh.get_meta("print_cell")) == config.wall, "Wrong wall print")
		var material := print_mesh.material_override as StandardMaterial3D
		_check(material.albedo_texture == Dressing.PRINTS and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Print texture/filter changed")
		var crop: Rect2 = Dressing.CROPS[config.wall]
		_check(is_equal_approx(material.uv1_scale.x, crop.size.x / Dressing.PRINTS.get_width()), "Print UV scale lost crop")
		_check(is_equal_approx(material.uv1_offset.y, crop.position.y / Dressing.PRINTS.get_height()), "Print UV offset lost cell")
		wall.hide()
		_check(not frame.is_visible_in_tree(), "Wall print floats after cutaway")
		wall.show()
		_check(frame.is_visible_in_tree(), "Wall print fails to return with wall")
		var paper := decor.get_node("TablePaper") as MeshInstance3D
		_check(int(paper.get_meta("print_cell")) == config.paper and absf(paper.position.y - 0.912) < 0.001, "Table paper wrong theme or height")
		for index: int in range(config.books):
			var book := decor.get_node("BookStack%d" % index) as Node3D
			_check(absf(book.position.y - 0.032 - (0.91 + index * 0.064)) < 0.001, "Book stack floats above support")
		if "--house-art-capture" in OS.get_cmdline_user_args() and id in ["house_02", "house_04", "house_06", "house_08"]:
			for tick: int in range(45):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.dream-loop/dressing-" + id + ".png")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("HOUSE_DRESSING_TEST_PASS eight_themes props crops filters cutaway table_contact no_collision")
	quit(0 if failures == 0 else 1)
