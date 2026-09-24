extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	var map: Node3D = world.get("_map_root")
	var surfaces: Array[Dictionary] = []
	for node: Node in map.get_children():
		if node.get_child_count() == 0:
			continue
		var surface := node.get_child(0) as MeshInstance3D
		if surface == null or not surface.mesh is BoxMesh:
			continue
		var material := surface.material_override as ShaderMaterial
		if material == null or material.shader != preload("res://shaders/village_surface.gdshader"):
			continue
		var size: Vector3 = (surface.mesh as BoxMesh).size
		var center: Vector3 = surface.global_position
		surfaces.append({"bounds": Rect2(Vector2(center.x, center.z) - Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z)), "top": center.y + size.y * 0.5, "material": material})
	var intersections: int = 0
	for i: int in range(surfaces.size()):
		for j: int in range(i + 1, surfaces.size()):
			var a: Dictionary = surfaces[i]
			var b: Dictionary = surfaces[j]
			if absf(float(a.top) - float(b.top)) >= 0.0001:
				continue
			var overlap: Rect2 = Rect2(a.bounds).intersection(b.bounds)
			if not overlap.has_area():
				continue
			intersections += 1
			for fraction: Vector2 in [Vector2(0.1, 0.1), Vector2(0.5, 0.5), Vector2(0.9, 0.9)]:
				var point: Vector2 = overlap.position + overlap.size * fraction
				var owners: int = 0
				for candidate: Dictionary in surfaces:
					if absf(float(a.top) - float(candidate.top)) >= 0.0001 or not Rect2(candidate.bounds).has_point(point):
						continue
					var material: ShaderMaterial = candidate.material
					var excluded: bool = false
					var rects: PackedVector4Array = material.get_shader_parameter("overlap_rects")
					for index: int in range(int(material.get_shader_parameter("overlap_count"))):
						var bounds: Vector4 = rects[index]
						excluded = excluded or Rect2(Vector2(bounds.x, bounds.y), Vector2(bounds.z - bounds.x, bounds.w - bounds.y)).has_point(point)
					if not excluded:
						owners += 1
				if owners != 1:
					failures += 1
					push_error("Road intersection at %s has %d visible owners" % [point, owners])
	if intersections < 10:
		failures += 1
		push_error("Expected plaza, crossroads, garden and approach overlaps")
	var player: Node3D = world.get_node("Player")
	player.set_physics_process(false)
	player.position = Vector3(18.5, 0.1, 4.6)
	world.get_node("CameraRig").call("snap_to_target")
	if DisplayServer.get_name() != "headless":
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/village-road-overlap-" + RenderingServer.get_current_rendering_method() + ".png")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("VILLAGE_ROAD_OVERLAP_TEST_PASS intersections=", intersections)
	quit(0 if failures == 0 else 1)
