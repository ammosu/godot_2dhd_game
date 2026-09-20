extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	state.call("start_quest")
	state.call("defeat_guardian")
	var elder := world.find_child("Elder", true, false).get_node("CharacterArt") as Sprite3D
	var original: Texture2D = elder.texture
	world.call("_complete_main_quest")
	var seals := get_nodes_in_group("moon_seal_presentations")
	assert(seals.size() == 1)
	var seal := seals[0] as Node3D
	var dialogue := world.get_node("DialogueUI")
	var picture := dialogue.get_node("DialogueRoot/MemoryIllustration") as TextureRect
	assert(not picture.visible and picture.texture == null)
	assert(not seal.visible)
	dialogue.call("advance")
	assert(not seal.visible)
	dialogue.call("advance")
	assert(seal.visible)
	assert(seal.get("pose_index") == 0)
	assert(elder.texture != original)
	seal.call("_process", 0.25)
	assert(seal.get("pose_index") == 1)
	seal.call("_process", 0.25)
	assert(seal.get("pose_index") == 2)
	assert(seal.find_children("*", "CollisionObject3D").is_empty())
	assert(state.get("quest_state") == 3)
	assert(not state.get("inventory").has("moon_shard"))
	if "--seal-capture" in OS.get_cmdline_user_args():
		for frame: int in range(45):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/wanderlight-seal-" + RenderingServer.get_current_rendering_method() + ".png")
	dialogue.call("advance")
	assert(seal.visible)
	dialogue.call("advance")
	assert(not seal.visible)
	assert(elder.texture == original)
	assert(picture.visible and picture.texture.resource_path.ends_with("fog_awakening.png"))
	assert(picture.material is ShaderMaterial)
	assert(is_zero_approx(float((picture.material as ShaderMaterial).get_shader_parameter("openness"))))
	dialogue.call("_process", 0.8)
	var half_open: float = (picture.material as ShaderMaterial).get_shader_parameter("openness")
	assert(half_open > 0.0 and half_open < 1.0)
	dialogue.call("advance")
	assert(picture.visible)
	assert(is_equal_approx(float((picture.material as ShaderMaterial).get_shader_parameter("openness")), half_open))
	dialogue.call("_process", 1.0)
	assert(is_equal_approx(float((picture.material as ShaderMaterial).get_shader_parameter("openness")), 1.0))
	dialogue.call("advance")
	assert(not picture.visible and picture.texture == null)
	assert(picture.material == null)
	for page: int in range(16):
		if dialogue.call("is_open"):
			dialogue.call("advance")
	await process_frame
	assert(get_nodes_in_group("moon_seal_presentations").is_empty())
	assert(dialogue.get_signal_connection_list("page_shown").is_empty())
	state.get("flags")["ruin_tablet_read"] = true
	world.call("_complete_main_quest")
	seal = get_nodes_in_group("moon_seal_presentations")[0] as Node3D
	for page: int in range(4):
		dialogue.call("advance")
	assert(seal.visible) # Tablet callback page still discusses the seal.
	assert(not picture.visible)
	dialogue.call("advance")
	assert(not seal.visible) # Fog awakening is no longer a seal presentation.
	assert(picture.visible and picture.texture != null)
	if "--awakening-capture" in OS.get_cmdline_user_args():
		for frame: int in range(30):
			await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("/tmp/wanderlight-awakening-" + RenderingServer.get_current_rendering_method() + ".png") == OK)
	world.call("_load_map", "ruins", "from_village")
	assert(not picture.visible and picture.texture == null)
	assert(get_nodes_in_group("moon_seal_presentations").is_empty())
	assert(dialogue.get_signal_connection_list("page_shown").is_empty())
	for page: int in range(16):
		if dialogue.call("is_open"):
			dialogue.call("advance")
	# Interrupt while the hand is still raising, not only after fog has begun.
	world.call("_load_map", "village", "default")
	elder = world.find_child("Elder", true, false).get_node("CharacterArt") as Sprite3D
	original = elder.texture
	var original_offset: Vector2 = elder.offset
	var original_size: float = elder.pixel_size
	world.call("_complete_main_quest")
	seal = get_nodes_in_group("moon_seal_presentations")[0] as Node3D
	dialogue.call("advance")
	dialogue.call("advance")
	assert(elder.texture != original)
	seal.queue_free()
	await process_frame
	assert(elder.texture == original and elder.offset == original_offset)
	assert(is_equal_approx(elder.pixel_size, original_size))
	assert(dialogue.get_signal_connection_list("page_shown").is_empty())
	# Merge regression: cinematic poses must not replace persistent loadouts.
	while dialogue.call("is_open"):
		dialogue.call("advance")
	for weapon: String in ["lantern_staff", "astral_staff"]:
		for armor: String in ["sage_robe", "astral_robe"]:
			var loadout := {"weapon": weapon, "armor": armor}
			assert(state.call("equip_loadout", loadout, "elder"))
			var equipped_texture: Texture2D = elder.texture
			var equipped_offset: Vector2 = elder.offset
			world.call("_complete_main_quest")
			dialogue.call("advance")
			dialogue.call("advance")
			for frame: int in range(2):
				await process_frame
			assert(state.call("get_loadout", "elder") == loadout)
			while dialogue.call("is_open"):
				dialogue.call("advance")
			await process_frame
			assert(elder.texture == equipped_texture and elder.offset == equipped_offset)
			assert(state.call("get_loadout", "elder") == loadout)
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("MOON_SEAL_TEST_PASS ending reward dialogue_cleanup map_cleanup")
	quit()
