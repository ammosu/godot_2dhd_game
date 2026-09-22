extends SceneTree
const City = preload("res://scripts/gameplay/city_house_catalog.gd")
const Residents = preload("res://scripts/gameplay/city_resident_catalog.gd")
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CITY_RESIDENT_ART_TEST_FAIL " + message)


func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	var seen: Dictionary = {}
	for index: int in range(City.POSITIONS.size()):
		var address := City.address(index)
		var person := City.resident(address)
		world.call("_load_map", address, "default")
		await process_frame
		var actor: Node3D = world.get("_map_root").get_node("HouseResident")
		var art := actor.get_node("CharacterArt") as Sprite3D
		var texture := art.texture as AtlasTexture
		check(texture != null, address + " atlas loaded")
		check(art.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, address + " nearest sampling")
		check(is_equal_approx(art.pixel_size * float(texture.get_meta("reference_height")),
			1.4 * preload("res://scripts/gameplay/house_catalog.gd").INTERIOR_CHARACTER_SCALE), address + " height")
		check(texture.region.size.x > 100 and texture.region.size.y > 250, address + " complete body")
		check(str(person.text).contains(str(Residents.RESIDENTS[Residents.HOUSE_IDENTITIES[index]].line)), address + " introduction")
		if "--capture" in OS.get_cmdline_user_args() and index == 5:
			world.get_node("CameraRig").call("snap_to_target")
			await create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/city-npc-" + RenderingServer.get_current_rendering_method() + ".png")
		world.call("_handle_interaction", "house_resident")
		check(state.get("mode") == state.Mode.DIALOGUE, address + " conversation opens")
		while world.get_node("DialogueUI").call("is_open"):
			world.get_node("DialogueUI").call("advance")
		seen[person.art] = true
	check(seen.size() == 16, "all 16 designs used")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("CITY_RESIDENT_ART_TEST_PASS 16 designs 26 homes dialogue scale")
	quit(0 if failures == 0 else 1)
