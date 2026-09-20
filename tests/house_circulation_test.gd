extends SceneTree
## Move the actual player collider through each furnished home, without saves.

const Houses = preload("res://scripts/gameplay/house_catalog.gd")
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	var route: Array[Vector2] = [
		Vector2(-0.8, 1.9), Vector2(-2.5, 1.9), Vector2(-2.5, 0.5),
		Vector2(-0.6, 0.5), Vector2(-0.6, -1.2), Vector2(0.2, -1.2),
		Vector2(0.2, -2.1), Vector2(-0.6, -2.1), Vector2(-0.6, 1.9), Vector2(0, 1.9),
	]
	for home: Dictionary in Houses.HOMES:
		world.call("_load_map", str(home.id), "default")
		for destination: Vector2 in route:
			var reached: bool = false
			for step: int in range(180):
				await physics_frame
				var delta: float = 1.0 / Engine.physics_ticks_per_second
				var planar := Vector2(player.position.x, player.position.z)
				var offset: Vector2 = destination - planar
				if offset.length() < 0.06 and player.is_on_floor():
					reached = true
					break
				var direction: Vector2 = offset.normalized()
				var speed: float = minf(3.0, offset.length() / delta)
				player.velocity = Vector3(direction.x * speed, -2.0, direction.y * speed)
				player.move_and_slide()
			if not reached:
				_failures += 1
				push_error("House circulation blocked: %s target=%s actual=%s" % [home.id, destination, player.position])
				break
		if player.position.y < -0.01 or player.position.y > 0.1:
			_failures += 1
			push_error("House circulation lost floor contact: " + str(home.id))
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failures == 0:
		print("HOUSE_CIRCULATION_TEST_PASS eight_homes ten_waypoints real_player_collision floor_contact")
	quit(0 if _failures == 0 else 1)
