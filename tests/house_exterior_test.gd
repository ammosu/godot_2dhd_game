extends SceneTree

const Exterior = preload("res://scripts/gameplay/house_exterior.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var wood := StandardMaterial3D.new()
	var themes: Dictionary = {"house_01": "weaving", "house_02": "garden", "house_03": "moon", "house_04": "pottery", "house_05": "quilt", "house_06": "compass", "house_07": "herbs", "house_08": "book"}
	for id: String in themes:
		var house := Node3D.new()
		root.add_child(house)
		Exterior.build(house, id, wood)
		var decor := house.get_node_or_null("ExteriorDressing")
		assert(decor.get_meta("theme") == themes[id])
		if id not in ["house_02", "house_04"]:
			var emblem := decor.get_node("GableEmblem") as Node3D
			assert(emblem.position.is_equal_approx(Vector3(0, 2.43, -1.78)))
			assert(emblem.get_meta("kind") == themes[id])
			if id == "house_06":
				var rose := emblem.get_node("CompassRose") as MeshInstance3D
				var arrays: Array = rose.mesh.surface_get_arrays(0)
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				assert(normals.size() == 48)
				for normal: Vector3 in normals:
					assert(normal.z < 0.0)
			elif id == "house_08":
				assert(emblem.has_node("LeftLeaf/Pages") and emblem.has_node("RightLeaf/Pages"))
				assert(emblem.has_node("Bookmark"))
			elif id == "house_01":
				assert(emblem.has_node("Warp6") and emblem.has_node("Weft3_6"))
			elif id == "house_03":
				assert(emblem.has_node("FullMoon") and emblem.has_node("WaxingMoon") and emblem.has_node("WaningMoon"))
				for label: String in ["WaxingMoon", "WaningMoon"]:
					var crescent := emblem.get_node(label) as MeshInstance3D
					var arrays: Array = crescent.mesh.surface_get_arrays(0)
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					assert(normals.size() == 114)
					for normal: Vector3 in normals:
						assert(normal.is_finite() and normal.z < -0.99)
			elif id == "house_05":
				assert(emblem.has_node("Patch3") and emblem.has_node("Stitch3_2"))
			elif id == "house_07":
				assert(emblem.has_node("Stem") and emblem.has_node("HerbLeaf5"))
			_check_emblem_bounds(emblem)
		else:
			var flowers: int = 0
			var pots: int = 0
			for child: Node in decor.get_children():
				assert(not child is CollisionObject3D)
				var position: Vector3 = (child as Node3D).position
				assert(absf(position.x) > 0.80, "Keep central entrance clear")
				if child is Sprite3D:
					flowers += 1
					assert((child as Sprite3D).texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
				elif str(child.name).begins_with("DisplayPot"):
					pots += 1
					assert(is_equal_approx(position.y, 0.76))
			assert(flowers == (6 if id == "house_02" else 0))
			assert(pots == (6 if id == "house_04" else 0))
		house.free()
	print("HOUSE_EXTERIOR_TEST_PASS eight_themes entrance_clear")
	if "--emblem-capture" in OS.get_cmdline_user_args():
		root.get_node("GameState").get("flags")["intro_seen"] = true
		change_scene_to_file("res://scenes/main.tscn")
		await scene_changed
		var player := current_scene.get_node("Player") as Node3D
		player.set_physics_process(false)
		for id: String in ["house_01", "house_03", "house_05", "house_06", "house_07", "house_08"]:
			var home: Dictionary = preload("res://scripts/gameplay/house_catalog.gd").find_home(id)
			player.position = home.position + Basis(Vector3.UP, home.yaw) * Vector3(0, 0.024, -2.8)
			current_scene.get_node("CameraRig").set("_target_yaw", home.yaw + deg_to_rad(225))
			current_scene.get_node("CameraRig").set("_distance", 9.5)
			for frame: int in range(90):
				await process_frame
			await RenderingServer.frame_post_draw
			for controller: Node in get_nodes_in_group("foreground_cutaways"):
				if controller.get("active"):
					var house := controller.get_parent() as Node3D
					print("CUTAWAY_CAPTURE ", id, " blocker=", house.position, " tiles=", house.get_node("ArchitecturalDetails/SlateRoofTiles").get("cast_shadow"))
			root.get_texture().get_image().save_png("res://.dream-loop/emblem-%s-%s.png" % [id, RenderingServer.get_current_rendering_method()])
	if "--exterior-capture" in OS.get_cmdline_user_args():
		root.get_node("GameState").get("flags")["intro_seen"] = true
		change_scene_to_file("res://scenes/main.tscn")
		await scene_changed
		var player := current_scene.get_node("Player") as Node3D
		player.position = Vector3(8, 0.1, 6)
		current_scene.get_node("CameraRig").set("_target_yaw", deg_to_rad(-45))
		for frame: int in range(90):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.dream-loop/pottery-exterior.png")
	quit()


func _check_emblem_bounds(node: Node) -> void:
	assert(not node is CollisionObject3D and not node is CollisionShape3D)
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		assert(bounds.position.y > 2.1, "Emblem stays above doorway canopy")
		assert(bounds.end.y < 2.85 and bounds.position.x > -0.4 and bounds.end.x < 0.4)
	for child: Node in node.get_children():
		_check_emblem_bounds(child)
