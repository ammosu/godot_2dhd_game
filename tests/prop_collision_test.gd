extends SceneTree
## Probe real scenery with the player's capsule from every horizontal side.
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	var checked: int = 0
	for map_id: String in ["village", "ruins"]:
		world.call("_load_map", map_id, "default")
		await physics_frame
		await physics_frame
		var obstacles: Array[Node] = (world.get("_map_root") as Node).find_children("*", "PhysicsBody3D", true, false)
		if map_id == "village":
			var trees := get_nodes_in_group("village_trees")
			_check(not trees.is_empty(), "Village trees missing")
			for tree: Node in trees:
				_check(tree.has_node("PropBody/Shape"), "Tree trunk needs collision")
		var bodies := get_nodes_in_group("solid_scenery")
		_check(bodies.size() >= 5, "Missing scenery bodies in " + map_id)
		for node: Node in bodies:
			var body := node as StaticBody3D
			# Isolate the target from adjacent props during each contact probe.
			for obstacle: Node in obstacles:
				if obstacle != body:
					player.add_collision_exception_with(obstacle as PhysicsBody3D)
			var collider := body.get_node("Shape") as CollisionShape3D
			var size: Vector3
			if collider.shape is BoxShape3D:
				size = (collider.shape as BoxShape3D).size
			else:
				var cylinder := collider.shape as CylinderShape3D
				size = Vector3(cylinder.radius * 2, cylinder.height, cylinder.radius * 2)
			for side: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
				var edge := collider.position + side * size * 0.5
				edge.y = collider.position.y - size.y * 0.5 + 0.05
				var direction := (body.global_basis * side).normalized()
				var start := body.to_global(edge) + direction * 0.34
				var hit := KinematicCollision3D.new()
				var blocked := player.test_move(Transform3D(Basis.IDENTITY, start), -direction * 0.20, hit)
				_check(blocked and hit.get_collider() == body, "%s/%s does not block capsule from %s" % [map_id, body.get_parent().name, side])
				checked += 1
			if body.get_parent().is_in_group("village_trees"):
				var canopy_start := body.global_position + Vector3(0.95, 0.05, -0.8)
				_check(not player.test_move(Transform3D(Basis.IDENTITY, canopy_start), Vector3(0, 0, 1.6)), "Tree canopy must leave room beside the trunk")
			for obstacle: Node in obstacles:
				player.remove_collision_exception_with(obstacle as PhysicsBody3D)
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failures == 0:
		print("PROP_COLLISION_TEST_PASS village ruins player_capsule four_sides probes=", checked)
	quit(0 if _failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
