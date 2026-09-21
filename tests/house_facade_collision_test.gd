extends SceneTree
## Test the real player capsule against each outward-facing window planter.
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	var obstacles: Array[Node] = (world.get("_map_root") as Node).find_children("*", "PhysicsBody3D", true, false)
	var colliders := get_nodes_in_group("house_facade_collisions")
	_check(colliders.size() == 64, "Eight solid window fixtures required per house")
	for node: Node in colliders:
		var collider := node as CollisionShape3D
		var body := collider.get_parent() as StaticBody3D
		for obstacle: Node in obstacles:
			if obstacle != body:
				player.add_collision_exception_with(obstacle as PhysicsBody3D)
		var shape := collider.shape as BoxShape3D
		_check(collider.global_basis.get_scale().is_equal_approx(Vector3.ONE), "Collider must not inherit visual scale")
		var outward: Vector3 = collider.get_meta("outward")
		var direction := collider.global_basis * outward
		var edge := collider.to_global(outward * shape.size * 0.5)
		var start := edge + direction * 0.36
		start.y = 0.05
		var hit := KinematicCollision3D.new()
		var blocked := player.test_move(Transform3D(Basis.IDENTITY, start), -direction * 0.24, hit)
		var hit_fixture: bool = false
		if blocked and hit.get_collider() == body:
			hit_fixture = hit.get_collider_shape() == collider
		_check(hit_fixture, "Player must hit the fixture before the wall: " + str(body.get_meta("house_id")) + " " + str(collider.position))
		for obstacle: Node in obstacles:
			player.remove_collision_exception_with(obstacle as PhysicsBody3D)
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failures == 0:
		print("HOUSE_FACADE_COLLISION_TEST_PASS eight_homes 64_fixtures player_capsule unscaled_physics")
	quit(0 if _failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
