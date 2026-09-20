extends SceneTree

const Interactable = preload("res://scripts/gameplay/interactable_3d.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var portal := world.get("_village_gate_portal") as Area3D
	assert(portal.get_node("MoonSeal").position.z > 0.0)
	assert(portal.get_node("MoonSealCore").position.z > 0.0)
	var shape := portal.get_child(0) as CollisionShape3D
	assert((shape.shape as BoxShape3D).size == Vector3(2.2, 1.6, 0.6))
	assert(portal.monitoring and portal.collision_layer == 8 and portal.collision_mask == 1)
	for label: String in ["LeftDoorHinge", "RightDoorHinge"]:
		var hinge := portal.get_node(label) as Node3D
		assert(hinge.get_child_count() == 7)
		var leaf := hinge.get_child(0) as MeshInstance3D
		var material := leaf.material_override as StandardMaterial3D
		assert(material.albedo_texture.resource_path.ends_with("timber_albedo.png"))
		assert(is_zero_approx(hinge.rotation.y))
	var wall_count: int = 0
	for child: Node in (world.get("_map_root") as Node).get_children():
		if child is StaticBody3D and child.get_child_count() == 2 and child.get_child(0) is MeshInstance3D and (child.get_child(0) as MeshInstance3D).material_override is ShaderMaterial:
			var candidate := (child.get_child(0) as MeshInstance3D).material_override as ShaderMaterial
			if not candidate.shader.resource_path.ends_with("coursed_stone.gdshader"):
				continue
			wall_count += 1
			var visual := child.get_child(0) as MeshInstance3D
			assert((visual.material_override as ShaderMaterial).shader.resource_path.ends_with("coursed_stone.gdshader"))
			assert((visual.mesh as BoxMesh).size == ((child.get_child(1) as CollisionShape3D).shape as BoxShape3D).size)
	assert(wall_count == 4)
	state.set("quest_state", 1)
	world.call("_update_village_gate_state")
	await create_timer(0.85).timeout
	assert(is_equal_approx((portal.get_node("LeftDoorHinge") as Node3D).rotation.y, -1.22))
	assert(is_equal_approx((portal.get_node("MoonSeal") as MeshInstance3D).transparency, 1.0))
	world.call("_load_map", "ruins", "from_village")
	var found: bool = false
	for child: Node in (world.get("_map_root") as Node).get_children():
		if child is Interactable and child.interaction_id == "portal_to_village":
			assert(child.get_node("MoonSeal").position.z < 0.0)
			found = true
	assert(found)
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("GATE_ART_TEST_PASS masonry timber two_sided approach seal_open collision_preserved")
	quit()
