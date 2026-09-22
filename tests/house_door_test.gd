extends SceneTree
## Verify delayed entry and repeated interaction protection for every home.

const Houses = preload("res://scripts/gameplay/house_catalog.gd")
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for home: Dictionary in Houses.HOMES:
		world.call("_load_map", "village", "from_" + str(home.id))
		await physics_frame
		await physics_frame
		print("DOOR_TEST_HOME ", home.id)
		var entrance: Node3D
		for candidate: Node in get_nodes_in_group("house_entrances"):
			if candidate.get("interaction_id") == "enter_" + str(home.id):
				entrance = candidate as Node3D
		var hinge := entrance.get_parent().get_node("ArchitecturalDetails/DoorHinge") as Node3D
		_check(is_zero_approx(hinge.rotation.y), "Door must start closed")
		var player := world.get_node("Player") as Node3D
		_check_door_input(player, entrance, state)
		_press_interact(player)
		_check(state.get("current_map") == "village", "Entry must wait for opening")
		_check(state.call("is_input_locked"), "Opening must lock controls")
		# A second activation cannot skip the animation or enter a different house.
		world.call("_handle_interaction", "enter_house_02")
		await create_timer(0.15).timeout
		_check_facing(world, (entrance.get_parent() as Node3D).global_position, "Retreat must keep facing door")
		await create_timer(0.3).timeout
		_check(state.get("current_map") == "village", "Repeated input skipped opening")
		var local_player := (entrance.get_parent() as Node3D).to_local(player.global_position)
		_check(local_player.z < -3.05 * Houses.EXTERIOR_SCALE.z, "Player must retreat beyond the door swing")
		_check(hinge.rotation.y > 0.0 and hinge.rotation.y < PI * 0.48, "Door must swing progressively")
		_check_facing(world, (entrance.get_parent() as Node3D).global_position, "Entry opening must face door")
		await create_timer(1.7).timeout
		_check(state.get("current_map") == home.id, "Opening entered wrong home")
		_check(not state.call("is_input_locked"), "Entry must restore controls")
		_check_facing(world, player.global_position + Vector3.FORWARD, "Arrival indoors must face into room")
		if state.get("current_map") != home.id:
			print("DOOR_TEST_BLOCKED ", player.global_position)
			break
		var resident: Node = world.get("_map_root").get_node("HouseResident")
		_check(resident.has_node("ResidentBody"), "Resident needs physical collision")
		resident.call("interact")
		var dialogue: Node = world.get("dialogue_ui")
		_check(dialogue.call("is_open"), "Resident must open dialogue")
		dialogue.call("advance")
		_check(not state.call("is_input_locked"), "Resident conversation must release controls")
		var exit_hinge := world.get("_map_root").get_node("HouseInterior/Wall2/DoorHinge") as Node3D
		var exit_door: Node3D
		for candidate: Node in world.get("_map_root").find_children("*", "Area3D", true, false):
			if candidate is Interactable3D and candidate.interaction_id == "leave_house":
				exit_door = candidate as Node3D
		player.global_position = Vector3(0, 0, 2.0)
		await physics_frame
		await physics_frame
		_check_door_input(player, exit_door, state)
		_press_interact(player)
		_check(state.get("current_map") == home.id, "Exit must wait for opening")
		_check(state.call("is_input_locked"), "Exit opening must lock controls")
		world.call("_handle_interaction", "leave_house")
		await create_timer(0.3).timeout
		_check(state.get("current_map") == home.id, "Repeated exit skipped opening")
		_check(exit_hinge.rotation.y > 0.0 and exit_hinge.rotation.y < PI * 0.48, "Interior door must swing progressively")
		_check_facing(world, Vector3(0, 0, 3.37), "Exit opening must face door")
		await create_timer(0.55).timeout
		_check(state.get("current_map") == "village", "Exit must return to village")
		_check(not state.call("is_input_locked"), "Exit must restore controls")
		_check_facing(world, player.global_position + Vector3.FORWARD.rotated(Vector3.UP, float(home.yaw)), "Arrival outside must face away from house")
		_check(not bool(player.get("_door_facing_locked")), "Door facing must release after arrival")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failures == 0:
		print("HOUSE_DOOR_TEST_PASS eight_homes retreat animated_open walk_in delayed_entry repeat_guard residents input_unlock exit")
	quit(0 if _failures == 0 else 1)


func _check_facing(world: Node, target: Vector3, message: String) -> void:
	var player := world.get_node("Player") as Node3D
	var direction := Facing.screen_direction(target - player.global_position, root.get_camera_3d())
	var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
	_check(sprite.animation == Facing.ANIMATIONS[Facing.direction_index(direction)], message)


func _check_door_input(player: Node3D, door: Node3D, state: Node) -> void:
	var toward := door.global_position - player.global_position
	toward.y = 0.0
	for angle: float in [PI, PI / 2.0, -PI / 2.0]:
		player.call("face_world_position", player.global_position + toward.rotated(Vector3.UP, angle))
		_check(player.call("get_nearest_interactable") != door, "Door behind or beside player must not be selectable")
		_check(player.call("get_interaction_prompt") != door.get("prompt_text"), "Unavailable door must not show its prompt")
		# Other nearby interactions (such as the resident) remain available.
		if player.call("get_nearest_interactable") == null:
			_press_interact(player)
		_check(not state.call("is_input_locked"), "Facing away must not start door animation")
	player.call("face_world_position", door.global_position)
	_check(player.call("get_nearest_interactable") == door, "Facing door must allow interaction")
	_check(player.call("get_interaction_prompt") == door.get("prompt_text"), "Facing door must show prompt")


func _press_interact(player: Node) -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	player.call("_unhandled_input", event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
