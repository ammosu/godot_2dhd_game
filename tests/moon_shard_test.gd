extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true) # Reward presentation must not touch normal saves.
	state.call("start_quest")
	state.call("defeat_guardian")
	world.call("_on_battle_finished", true)
	var shards := get_nodes_in_group("moon_shard_presentations")
	assert(shards.size() == 1)
	var shard := shards[0] as Node3D
	assert(shard.get_parent() == world.get("_map_root"))
	var relic := shard.get_node("Relic")
	assert(relic.get_child_count() == 2)
	for child: Node in relic.get_children():
		assert(child is MeshInstance3D)
		var visual := child as MeshInstance3D
		var arrays: Array = visual.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		assert(vertices.size() == (72 if child.name == "FacetedShard" else 1044))
		for index: int in range(vertices.size()):
			assert(vertices[index].is_finite() and normals[index].is_finite())
			assert(normals[index].length() > 0.99)
		for index: int in range(0, vertices.size(), 3):
			var center := (vertices[index] + vertices[index + 1] + vertices[index + 2]) / 3.0
			if child.name == "FacetedShard":
				assert(normals[index].dot(center - Vector3(0, 0.02, 0)) > 0.0)
			elif index < 1008: # Tube faces, excluding the two tangent end caps.
				var axis := Vector3(center.x, center.y, 0).normalized() * 0.255 + Vector3(0, 0, -0.02)
				assert(normals[index].dot(center - axis) > 0.0)
	assert(int(state.get("inventory").get("moon_shard", 0)) == 1)
	if "--shard-capture" in OS.get_cmdline_user_args():
		for frame: int in range(60):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.dream-loop/moon-shard-%s.png" % RenderingServer.get_current_rendering_method())
	var dialogue := world.get_node("DialogueUI")
	dialogue.call("advance")
	assert(get_nodes_in_group("moon_shard_presentations").size() == 1)
	dialogue.call("advance")
	await process_frame
	assert(get_nodes_in_group("moon_shard_presentations").is_empty())
	assert(int(state.get("inventory").get("moon_shard", 0)) == 1)
	# Leaving the map before dialogue ends also releases the transient model.
	world.call("_on_battle_finished", true)
	world.call("_load_map", "village", "from_ruins")
	assert(get_nodes_in_group("moon_shard_presentations").is_empty())
	dialogue.call("advance")
	dialogue.call("advance")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("MOON_SHARD_TEST_PASS geometry reward_once dialogue_cleanup map_cleanup")
	quit()
