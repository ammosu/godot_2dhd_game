extends SceneTree
const Awareness = preload("res://scripts/gameplay/enemy_awareness.gd")
var state: Node
var field: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	state = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "east_road", "from_village")
	player = world.get_node("Player")
	player.set_physics_process(false)
	field = world.get("_map_root").get_node("FieldCombat")
	while not field.ready_for_combat:
		await physics_frame
	field.set_physics_process(false)
	_reset()
	var scout: Dictionary = field.enemies[0]
	player.position = Vector3(-4, 0.05, 7)
	assert(Awareness.detects(field, scout), "Visible player in front is detected")
	player.position = Vector3(-4, 0.05, 13)
	assert(not Awareness.detects(field, scout), "Distant player behind is unseen")
	player.position.z = 11.2
	assert(Awareness.detects(field, scout), "Close approach from behind alerts enemy")
	player.position = Vector3(-4, 0.05, 3)
	assert(not Awareness.detects(field, scout), "Sight has a bounded range")
	player.position.z = 7
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 0.3)
	shape.shape = box
	wall.add_child(shape)
	field.add_child(wall)
	wall.position = Vector3(-4, 1, 8.5)
	await physics_frame
	assert(not Awareness.detects(field, scout), "Walls block vision")
	player.position.z = 8.8
	wall.position.z = 9.4
	await physics_frame
	assert(not Awareness.detects(field, scout), "Proximity cannot detect through walls")
	wall.position = Vector3(-3, 1, 10)
	box.size = Vector3(0.3, 2, 2)
	player.position.z = 7
	await physics_frame
	Awareness.engage(field, scout)
	assert(field.enemies[1].state == "patrol", "Support cannot propagate through a wall")
	wall.position = Vector3(20, 1, 20)
	await physics_frame
	_reset()
	Awareness.update(field, scout, 0.01)
	assert(scout.state == "chase" and field.enemies[1].state == "chase", "Nearby ally joins detection")
	assert(field.enemies[2].state == "patrol", "Helpers cannot chain-pull the next pack")
	assert(field.enemies[3].state == "patrol", "Distant enemies remain idle")
	# Block the known target, then move it elsewhere behind the obstacle.
	var remembered: Vector3 = scout.last_seen
	box.size = Vector3(6, 2, 0.3)
	wall.position = Vector3(-3, 1, 8.5)
	await physics_frame
	player.position.x = -2.5
	Awareness.update(field, scout, 1.0)
	assert(scout.state == "chase" and scout.last_seen == remembered and not scout.target_visible)
	Awareness.update(field, scout, 3.1)
	assert(scout.state == "return" and scout.windup == 0.0 and not scout.warning.visible)
	wall.queue_free()
	await physics_frame
	_reset()
	player.position = Vector3(-4, 0.05, 11.2)
	Awareness.engage(field, scout)
	player.position = Vector3(-14, 0.05, 0)
	Awareness.update(field, scout, 0.01)
	assert(scout.state == "return", "Leaving territory ends chase immediately")
	_reset()
	player.position = Vector3(-4, 0.05, 13)
	field._damage_enemy(scout, 1)
	assert(scout.state == "chase" and field.enemies[1].state == "chase", "Attacking from behind alerts nearby allies")
	print("ENEMY_AWARENESS_TEST_PASS cone proximity walls assistance no_chain memory leash attacked")
	quit()

func _reset() -> void:
	var points: Array[Vector3] = [Vector3(-4, 0.05, 10), Vector3(-2, 0.05, 10), Vector3(1, 0.05, 10), Vector3(10, 1.85, 10)]
	for index: int in range(field.enemies.size()):
		var enemy: Dictionary = field.enemies[index]
		enemy.body.position = points[index]
		enemy.home = points[index]
		enemy.state = "patrol"
		enemy.facing = Vector3.FORWARD
		enemy.windup = 0.0
		enemy.lost_sight = 0.0
