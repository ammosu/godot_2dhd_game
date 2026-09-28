extends SceneTree
## Flood-fills walkable ground from each outdoor map's spawn. Every reachable
## cell must stay inside the map bounds unless it first enters a travel exit,
## so no route can walk around a threshold and off the edge of the world.
const STEP := 0.5
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await create_timer(0.5).timeout
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	var failures: int = 0
	var maps := ["village", "ruins", "east_road", "firefly_forest", "caravan_road", "starbay", "moss_steps", "wind_gorge", "moon_highland"]
	for map_id: String in maps:
		world.call("_load_map", map_id, "")
		for i in 4:
			await physics_frame
		var bounds: Rect2 = world.get("_mini_map").call("get_world_bounds")
		var exits: Array[Area3D] = []
		for node: Node in world.get("_map_root").find_children("*", "Area3D", true, false):
			if node.is_in_group("walking_exits") or str(node.get("interaction_id")).begins_with("portal"):
				exits.append(node as Area3D)
		var space := player.get_world_3d().direct_space_state
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.3
		capsule.height = 0.9
		var start := player.global_position
		var origin := Vector2(start.x, start.z)
		var seen := {}
		var heights := {}
		var queue: Array[Vector2i] = [Vector2i.ZERO]
		var h0 := _floor(space, Vector2(start.x, start.z), start.y + 1.0, player)
		heights[Vector2i.ZERO] = h0
		seen[Vector2i.ZERO] = true
		var leaks: Array[Vector2] = []
		var exit_hits := {}
		var limit: int = 60000
		while not queue.is_empty() and limit > 0:
			limit -= 1
			var cell: Vector2i = queue.pop_front()
			var at := origin + Vector2(cell) * STEP
			var y: float = heights[cell]
			var in_exit := ""
			for e: Area3D in exits:
				if _inside(e, Vector3(at.x, y + 0.6, at.y)):
					in_exit = str(e.get("interaction_id"))
			if in_exit != "":
				exit_hits[in_exit] = true
				continue
			if not bounds.grow(0.5).has_point(at):
				leaks.append(at)
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := cell + d
				if seen.has(n):
					continue
				var nat := origin + Vector2(n) * STEP
				var ny: float = _floor(space, nat, y + 0.9, player)
				if is_nan(ny) or absf(ny - y) > 0.35:
					continue
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = capsule
				q.transform.origin = Vector3(nat.x, ny + 0.72, nat.y)
				q.collision_mask = player.collision_mask
				q.exclude = [player.get_rid()]
				if not space.intersect_shape(q, 1).is_empty():
					continue
				var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x, y + 0.5, at.y), Vector3(nat.x, ny + 0.5, nat.y), player.collision_mask, [player.get_rid()])
				if not space.intersect_ray(ray).is_empty():
					continue
				seen[n] = true
				heights[n] = ny
				queue.append(n)
		var sample: Array[String] = []
		for i in range(0, leaks.size(), maxi(1, leaks.size() / 8)):
			sample.append("(%.1f,%.1f)" % [leaks[i].x, leaks[i].y])
		if not leaks.is_empty():
			failures += 1
			push_error("%s: %d walkable cells beyond bounds, e.g. %s" % [map_id, leaks.size(), " ".join(sample)])
		if exit_hits.is_empty():
			failures += 1
			push_error("%s: flood fill reached no exit" % map_id)
	if failures == 0:
		print("MAP_EXIT_LEAK_TEST_PASS maps=", maps.size())
	quit(0 if failures == 0 else 1)

func _floor(space: PhysicsDirectSpaceState3D, at: Vector2, from_y: float, player: CharacterBody3D) -> float:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x, from_y, at.y), Vector3(at.x, from_y - 3.0, at.y), player.collision_mask, [player.get_rid()])
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or Vector3(hit.normal).y < cos(player.floor_max_angle):
		return NAN
	return Vector3(hit.position).y

## Travel thresholds and portals are boxes; test the footprint only.
func _inside(area: Area3D, point: Vector3) -> bool:
	for child: Node in area.get_children():
		var c := child as CollisionShape3D
		if c == null:
			continue
		var local := c.global_transform.affine_inverse() * point
		if c.shape is BoxShape3D:
			var half: Vector3 = (c.shape as BoxShape3D).size * 0.5
			if absf(local.x) <= half.x and absf(local.z) <= half.z:
				return true
	return false
