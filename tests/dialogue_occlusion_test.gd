extends SceneTree
const Occlusion = preload("res://scripts/gameplay/dialogue_occlusion.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenery := Node3D.new()
	root.add_child(scenery)
	var material := StandardMaterial3D.new()
	var blocker := MeshInstance3D.new()
	blocker.mesh = BoxMesh.new()
	blocker.mesh.size = Vector3(2, 3, 1)
	blocker.mesh.material = material
	blocker.position = Vector3(0, 1, 0)
	scenery.add_child(blocker)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 2, 5)
	camera.look_at(Vector3(0, 0.8, -3))
	var player := Node3D.new()
	root.add_child(player)
	player.position = Vector3(6, 0, -3)
	var partner := Node3D.new()
	root.add_child(partner)
	partner.position = Vector3(0, 0, -3)
	var fade := Occlusion.new()
	root.add_child(fade)
	fade.configure(scenery, camera)
	assert(fade.blocks_subject(partner), "Visual geometry without a collider blocks speaker ray")
	assert(not fade.blocks_subject(player), "Unobstructed hero ray remains clear")
	var tree := Sprite3D.new()
	tree.name = "TreeArt"
	var pixels := Image.create(200, 300, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	tree.texture = ImageTexture.create_from_image(pixels)
	tree.pixel_size = 0.01
	tree.position = Vector3(0, 1.5, 1)
	scenery.add_child(tree)
	var trees := preload("res://scripts/gameplay/tree_visibility.gd").new()
	root.add_child(trees)
	trees.configure(scenery, player, camera)
	camera.set_meta("dialogue_subjects", [partner])
	assert(trees.obstructs(tree), "Speaker canopy fades even with hero outside canopy")
	trees._process(0.3)
	assert(tree.modulate.a < 0.2)
	camera.set_meta("dialogue_subjects", [])
	trees._process(0.5)
	assert(is_equal_approx(tree.modulate.a, 1.0), "Canopy restores after conversation")
	trees.free()
	tree.free()
	for projection: int in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]:
		camera.projection = projection
		fade.update([player, partner], 0.2)
		assert(blocker.get_active_material(0) != material, "Partner occlusion must fade independently of player")
		assert(is_equal_approx(blocker.get_active_material(0).albedo_color.a, 0.12))
		assert(material.albedo_color.a == 1.0, "Shared material changed")
		fade.update([], 0.1)
		assert(blocker.get_surface_override_material(0) != null, "Restore delay missing")
		fade.update([], 0.3)
		assert(blocker.get_surface_override_material(0) == null, "Original material not restored")
		partner.position.z = 3.0
		fade.update([partner], 0.2)
		assert(blocker.get_surface_override_material(0) == null, "Object behind actor faded")
		partner.position.z = -3.0
		fade.update([partner], 0.2)
		fade.restore()
		assert(blocker.get_surface_override_material(0) == null)
	# A cutaway registered after configure must fade its root mesh for the partner.
	var gate := MeshInstance3D.new()
	gate.mesh = BoxMesh.new()
	gate.mesh.size = Vector3(2, 3, 1)
	gate.material_override = material
	root.add_child(gate)
	gate.position = Vector3(0, 1, 0)
	var controller := preload("res://scripts/gameplay/foreground_cutaway.gd").new()
	gate.add_child(controller)
	controller.configure(gate, player, camera, &"gate_cutaways")
	fade.update([partner], 0.2)
	assert(gate.material_override != material and is_equal_approx(gate.material_override.albedo_color.a, 0.12), "late gate cutaway fades for speaker while hero is elsewhere")
	fade.restore()
	assert(gate.material_override == material, "gate material restores after dialogue")
	gate.free()
	fade.update([partner], 0.2)
	scenery.free()
	fade.update([], 0.3)
	# A close lampshade between the speakers misses both rays, yet must fade.
	var lamps := Node3D.new()
	root.add_child(lamps)
	var lamp: Node3D = preload("res://scripts/gameplay/street_lantern.gd").build(lamps, Vector3(0, 0, 2))
	var other: Node3D = preload("res://scripts/gameplay/street_lantern.gd").build(lamps, Vector3(20, 0, 2))
	var panes := lamp.get_node("FrostedGlass") as MeshInstance3D
	var metal := lamp.get_node("Metalwork") as MeshInstance3D
	var original_glass: Material = panes.material_override
	var original_metal: Material = metal.material_override
	camera.position = Vector3(0, 1.42, 3)
	camera.look_at(Vector3(0, 1.42, -3))
	camera.size = 1.8
	player.position = Vector3(-2, 0, -3)
	partner.position = Vector3(2, 0, -3)
	fade.configure(lamps, camera)
	for projection: int in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]:
		camera.projection = projection
		lamp.position.z = 2.0
		assert(not fade.blocks_subject(player) and not fade.blocks_subject(partner), "central lamp fixture misses both subject rays")
		fade.update([player, partner], 0.2)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		assert(panes.material_override != original_glass, "large central shader lampshade fades")
		assert(is_equal_approx(panes.material_override.get_shader_parameter("dialogue_alpha"), 0.12), "glass fades in both render projections")
		assert(metal.material_override != original_metal, "lamp frame fades with glass")
		assert(other.get_node("FrostedGlass").material_override == original_glass, "shared glass untouched on other lamp")
		fade.update([], 0.4)
		assert(panes.material_override == original_glass and metal.material_override == original_metal, "original lamp shader and metal restored")
		lamp.position.z = -6.0
		fade.update([player, partner], 0.2)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		assert(panes.material_override == original_glass, "background lamp remains opaque")
		# Put the fixture directly across the speaker ray as a separate case.
		var endpoint: Vector3 = partner.position + Vector3.UP * 1.4
		var origin: Vector3 = camera.project_ray_origin(camera.unproject_position(endpoint)) if projection == Camera3D.PROJECTION_ORTHOGONAL else camera.position
		lamp.position = origin.lerp(endpoint, 0.5) - Vector3.UP * 1.42
		fade.update([partner], 0.2)
		assert(panes.material_override != original_glass, "shader glass also fades on direct speaker occlusion")
		fade.restore()
		lamp.position = Vector3(0, 0, 2)
	lamps.free()
	fade.restore()
	fade.free()
	player.free()
	partner.free()
	camera.free()
	print("DIALOGUE_OCCLUSION_TEST_PASS both_subjects perspective orthographic shared_material restore map_cleanup")
	quit()
