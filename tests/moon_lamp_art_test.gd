extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _hits(mesh: MeshInstance3D, start: Vector3, end: Vector3) -> int:
	var vertices := mesh.mesh.get_faces()
	var hits: int = 0
	for index: int in range(0, vertices.size(), 3):
		var a: Vector3 = mesh.global_transform * vertices[index]
		var b: Vector3 = mesh.global_transform * vertices[index + 1]
		var c: Vector3 = mesh.global_transform * vertices[index + 2]
		if Geometry3D.segment_intersects_triangle(start, end, a, b, c) != null:
			hits += 1
	return hits


func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var lamp := (world.get("_map_root") as Node3D).get_node("MoonLamp") as Area3D
	var art := lamp.get_node("MoonLampArt") as Node3D
	var core := art.find_child("MoonLampCore", true, false) as MeshInstance3D
	var metal := art.find_child("MoonLampBronzework", true, false) as MeshInstance3D
	var plinth := art.find_child("MoonLampPlinth", true, false) as MeshInstance3D
	_check(art.find_children("*", "MeshInstance3D", true, false).size() == 4, "Lamp should contain four meshes")
	var triangles: int = 0
	var canopy := art.find_child("MoonLampPatinaPanels", true, false) as MeshInstance3D
	for mesh: MeshInstance3D in [core, metal, plinth, canopy]:
		triangles += mesh.mesh.get_faces().size() / 3
		var material := mesh.material_override as StandardMaterial3D
		_check(material.albedo_texture != null, "Lamp has an untextured surface")
		var expected_filter: int = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_check(material.texture_filter == expected_filter, "Lamp lost nearest sampling or minification mip levels")
	_check(triangles < 3000, "Lamp exceeds geometry budget")
	var stone_material := plinth.material_override as StandardMaterial3D
	_check(stone_material.detail_enabled and stone_material.detail_albedo is NoiseTexture2D, "Stone weathering missing")
	var fixture_light := lamp.get_node("FixtureLight") as OmniLight3D
	_check(fixture_light.light_cull_mask == 2 and fixture_light.light_energy < 0.5, "Fixture fill leaks into plaza or overexposes frame")
	_check(is_equal_approx(core.global_position.y, 1.64), "Core pivot moved from halo center")
	var base_bounds := plinth.mesh.get_aabb()
	_check(base_bounds.size.x <= 1.65 and base_bounds.size.z <= 1.65, "Plinth expanded footprint")
	_check(base_bounds.position.y >= 0.006 and base_bounds.position.y < 0.02, "Plinth floats or intersects plaza")
	_check(_hits(metal, Vector3(0, 1.70, -2), Vector3(0, 1.70, 2)) == 0, "Halo center should remain open")
	_check(metal.mesh.get_aabb().size.y > 1.1, "Lunar ring is incomplete")
	_check((metal.material_override as StandardMaterial3D).emission_enabled, "Golden ring lost illumination")
	_check(canopy.mesh.get_aabb().end.y < 1.5, "Support blocks the open halo")
	_check(lamp.collision_layer == 8 and lamp.collision_mask == 0, "Lamp interaction layer changed")
	var collider := lamp.get_child(0) as CollisionShape3D
	_check(collider.shape is SphereShape3D and is_equal_approx((collider.shape as SphereShape3D).radius, 0.9), "Interaction radius changed")
	_check(art.find_children("*", "CollisionObject3D", true, false).is_empty(), "Visual asset unexpectedly added collision")
	var material := core.material_override as StandardMaterial3D
	var facet_colors: PackedColorArray = core.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	_check(facet_colors.size() > 0 and material.vertex_color_use_as_albedo, "Moonstone facet shading missing")
	var shade_min: float = 1.0
	var shade_max: float = 0.0
	for color: Color in facet_colors:
		shade_min = minf(shade_min, color.r)
		shade_max = maxf(shade_max, color.r)
	_check(shade_max - shade_min > 0.4, "Exporter lost varied facet shades in COLOR_0")
	var texture := material.albedo_texture
	_check(material.emission_texture == texture, "Core emission has no mineral texture")
	_check(material.emission_energy_multiplier < 1.0, "Lamp should start dim")
	var rotation_before: float = core.rotation.y
	world.call("_process", 0.2)
	_check(core.rotation.y != rotation_before and is_equal_approx(core.global_position.y, 1.64), "Core rotation displaced pivot")
	state.set("quest_state", 3)
	world.call("_update_moon_lamp_state")
	_check(material.emission_energy_multiplier > 1.0 and material.emission_energy_multiplier < 2.0 and material.albedo_texture == texture, "Restoration lost bounded textured emission")
	_check(((world.get("_moon_lamp_light") as OmniLight3D).light_cull_mask & metal.layers) == 0, "Plaza fill overexposes the lamp itself")
	_check((world.get("_moon_lamp_light") as OmniLight3D).light_energy > 3.0, "Restored lamp does not illuminate plaza")
	_check(fixture_light.light_energy > 0.15 and fixture_light.light_energy < 0.5, "Restored fixture fill outside art budget")
	var old_core: WeakRef = weakref(core)
	world.call("_load_map", "ruins", "default")
	await process_frame
	_check(old_core.get_ref() == null, "Old lamp survives map change")
	world.call("_load_map", "village", "default")
	await process_frame
	_check(((world.get("_moon_lamp_core") as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier > 1.0, "Restored state lost on map return")
	world.queue_free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.3).timeout
	if _failures == 0:
		print("MOON_LAMP_ART_TEST_PASS meshes textures open_halo pivot interaction restored cleanup triangles=", triangles)
	quit(0 if _failures == 0 else 1)
