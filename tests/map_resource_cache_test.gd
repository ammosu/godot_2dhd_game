extends SceneTree

const Houses = preload("res://scripts/gameplay/house_catalog.gd")
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _add_batch_probes(map_root: Node3D) -> Array[WeakRef]:
	var references: Array[WeakRef] = []
	for use_override: bool in [false, true]:
		var mesh := BoxMesh.new()
		var material := StandardMaterial3D.new()
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = mesh
		batch.multimesh.instance_count = 1
		if use_override:
			batch.material_override = material
		else:
			mesh.material = material
		batch.material_overlay = StandardMaterial3D.new()
		references.append(weakref(material))
		references.append(weakref(batch.material_overlay))
		map_root.add_child(batch)
	return references


func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var original_flags: Dictionary = state.get("flags").duplicate(true)
	var original_quest: int = state.get("quest_state")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	(world.get_node("Player") as CharacterBody3D).set_physics_process(false)
	var batch_probes := _add_batch_probes(world.get("_map_root") as Node3D)
	var maps: Array[String] = ["village", "ruins"]
	for home: Dictionary in Houses.HOMES:
		maps.append(str(home.id))
	var first_material_ids: Dictionary = {}
	var first_texture_ids: Dictionary = {}
	var first_node_counts: Dictionary = {}
	var resources: Array[WeakRef] = []
	var baseline_snapshot: Dictionary = {}
	for cycle: int in range(3):
		for map_id: String in maps:
			var previous: WeakRef = weakref(world.get("_map_root"))
			world.call("_load_map", map_id, "default")
			_check(previous.get_ref() == null, "Previous map survived replacement")
			var current := world.get("_map_root") as Node
			var node_count: int = current.find_children("*", "", true, false).size()
			if cycle == 0:
				first_node_counts[map_id] = node_count
			else:
				_check(node_count == first_node_counts[map_id], "Map node count changed: " + map_id)
			var map_roots: int = 0
			for child: Node in world.get_children():
				if String(child.name).begins_with("Map_"):
					map_roots += 1
			_check(map_roots == 1, "Multiple map roots retained")
			var materials: Dictionary = world.get("_resident_materials")
			_check(materials.size() <= maps.size(), "Material cache grew beyond map count")
			for key: String in materials:
				var ids: Array[int] = []
				for material: Material in materials[key]:
					ids.append(material.get_instance_id())
				if not first_material_ids.has(key):
					first_material_ids[key] = ids
					for material: Material in materials[key]:
						resources.append(weakref(material))
				_check(ids == first_material_ids[key], "Material cache replaced or accumulated: " + key)
			var textures: Dictionary = world.get("_art_textures")
			for path: String in textures:
				var texture := textures[path] as Texture2D
				if not first_texture_ids.has(path):
					first_texture_ids[path] = texture.get_instance_id()
				_check(texture.get_instance_id() == first_texture_ids[path], "Texture identity changed: " + path)
			_check(state.get("quest_state") == original_quest, "Map rebuild changed quest")
			_check(state.get("flags") == original_flags, "Map rebuild changed flags")
		if cycle == 0:
			baseline_snapshot = world.get("_art_baselines").duplicate()
			_check(baseline_snapshot.size() == 4, "Expected three villagers and guardian baselines")
		else:
			_check(world.get("_art_baselines") == baseline_snapshot, "Cached baselines changed on map rebuild")
	_check(first_material_ids.size() == maps.size(), "Not all maps were exercised")
	for reference: WeakRef in batch_probes:
		_check(reference.get_ref() != null, "Batch material was not retained across map changes")
	world.free()
	await process_frame
	for reference: WeakRef in batch_probes:
		_check(reference.get_ref() == null, "Batch material survived world destruction")
	# Procedural materials have no external owners once the world is released.
	var released: int = 0
	for reference: WeakRef in resources:
		if reference.get_ref() == null:
			released += 1
	_check(released > 0, "World retained every cached material after destruction")
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failures == 0:
		print("MAP_RESOURCE_CACHE_TEST_PASS ten_maps three_cycles stable_resources freed_nodes quest_preserved")
	quit(0 if _failures == 0 else 1)
