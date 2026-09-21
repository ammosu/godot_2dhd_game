extends SceneTree
## Exercise player movement and interaction detection against real map NPCs.
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if not value:
		_failures += 1
		push_error(message)


func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	for map_id: String in ["village", "ruins", "village"]:
		world.call("_load_map", map_id, "default")
		await physics_frame
		await physics_frame
		var map_root := world.get("_map_root") as Node3D
		var names: Array[String] = ["Elder", "Rumi", "Noah"]
		if map_id == "ruins":
			names = ["Guardian"]
		for actor_name: String in names:
			var actor := map_root.get_node(actor_name) as Area3D
			var body := actor.get_node_or_null("ActorBody") as StaticBody3D
			_check(body != null, actor_name + " has no physical body")
			if body == null:
				continue
			# Exclude scenery so a nearby wall cannot make the NPC probe pass.
			var obstacles := map_root.find_children("*", "PhysicsBody3D", true, false)
			for obstacle: Node in obstacles:
				if obstacle != body:
					player.add_collision_exception_with(obstacle as PhysicsBody3D)
			for side: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
				player.global_position = actor.global_position + side * 1.5 + Vector3.UP * 0.04
				var hit := player.move_and_collide(-side * 3.0)
				_check(hit != null and hit.get_collider() == body, actor_name + " can be walked through")
				await physics_frame
				await physics_frame
				_check(player.call("get_nearest_interactable") == actor, actor_name + " cannot be reached for interaction at contact")
				var touching: Vector3 = player.global_position
				var through := player.move_and_collide(-side * 0.25)
				_check(through != null and player.global_position.distance_to(touching) < 0.01, actor_name + " allows continued inward movement")
				_check(player.move_and_collide(side * 0.5) == null, actor_name + " traps player when retreating")
			for obstacle: Node in obstacles:
				if obstacle != body:
					player.remove_collision_exception_with(obstacle as PhysicsBody3D)
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("NPC_COLLISION_TEST_PASS blocking interaction retreat map_reload")
	quit(0 if _failures == 0 else 1)
