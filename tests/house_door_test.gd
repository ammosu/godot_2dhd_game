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
		await _wait_until(func() -> bool: return player.get("_door_pose") == 1)
		_check(is_zero_approx(hinge.rotation.y), "Hand must reach before door moves")
		_check_facing(world, (entrance.get_parent() as Node3D).global_position, "Reach must face door")
		var local_player := (entrance.get_parent() as Node3D).to_local(player.global_position)
		_check(absf(local_player.z + 2.24 * Houses.EXTERIOR_SCALE.z) < 0.06, "Player must approach within arm reach")
		await create_timer(0.30).timeout
		_check(state.get("current_map") == "village", "Repeated input skipped opening")
		_check(hinge.rotation.y < 0.0 and hinge.rotation.y > -PI * 0.48, "Door must swing away progressively after contact")
		await _wait_until(func() -> bool: return state.get("current_map") == home.id)
		_check(not bool(player.get("_door_facing_locked")), "Indoor arrival must not turn back to close door")
		_check(player.get("_door_pose") == -1, "Indoor arrival must finish the entry action")
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
		await _wait_until(func() -> bool: return player.get("_door_pose") == 1)
		_check(is_zero_approx(exit_hinge.rotation.y), "Exit hand must reach before door moves")
		await create_timer(0.30).timeout
		_check(state.get("current_map") == home.id, "Repeated exit skipped opening")
		_check(exit_hinge.rotation.y < 0.0 and exit_hinge.rotation.y > -PI * 0.48, "Interior door must swing progressively")
		await _wait_until(func() -> bool: return state.get("current_map") == "village")
		await _wait_until(func() -> bool: return player.get("_door_pose") == 1)
		_check(state.call("is_input_locked"), "Arrival closing must retain input lock")
		_check(bool(player.get("_door_facing_locked")), "Arrival must turn back to close door")
		var returned_hinge: Node3D
		for house: Node in world.get("_map_root").get_children():
			if house.get_meta("house_id", "") == home.id:
				returned_hinge = house.get_node("ArchitecturalDetails/DoorHinge") as Node3D
		_check(returned_hinge != null and returned_hinge.rotation.y < 0.0, "Arrival door must visibly close")
		await _wait_until(func() -> bool: return not state.call("is_input_locked"))
		_check(returned_hinge != null and is_zero_approx(returned_hinge.rotation.y), "Arrival door must finish closed")
		_check(player.get("_door_pose") == -1, "Door action must restore walking art")
		_check(state.get("current_map") == "village", "Exit must return to village")
		_check(not state.call("is_input_locked"), "Exit must restore controls")
		_check_facing(world, player.global_position + Vector3.FORWARD.rotated(Vector3.UP, float(home.yaw)), "Arrival outside must face away from house")
		_check(not bool(player.get("_door_facing_locked")), "Door facing must release after arrival")
	await _check_automatic_doors(world, state)
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failures == 0:
		print("HOUSE_DOOR_TEST_PASS eight_homes approach hand_contact animated_open walk_in delayed_entry repeat_guard residents input_unlock exit automatic_entry automatic_exit arrival_guard")
	quit(0 if _failures == 0 else 1)


func _settle() -> void:
	for frame: int in range(4):
		await physics_frame
		await process_frame


func _check_automatic_doors(world: Node, state: Node) -> void:
	var player := world.get_node("Player") as Node3D
	for home_id: String in ["house_02", "house_city_01"]:
		var parent_map: String = Houses.parent_map(home_id)
		world.call("_load_map", parent_map, "from_" + home_id)
		await _settle()
		var entrance: Interactable3D
		for candidate: Node in get_nodes_in_group("house_entrances"):
			if candidate.get("interaction_id") == "enter_" + home_id:
				entrance = candidate as Interactable3D
		var approach := (entrance.global_basis * entrance.facing_direction).normalized()
		player.global_position = entrance.global_position - approach * 0.55
		player.global_position.y = 0.1
		for angle: float in [PI, PI / 2.0, -PI / 2.0]:
			player.call("face_world_position", player.global_position + approach.rotated(Vector3.UP, angle))
			await _settle()
			_check(not state.call("is_input_locked"), "Close door must reject back/side facing automatically")
		player.call("face_world_position", player.global_position + approach)
		await _settle()
		_check(state.call("is_input_locked"), "Close facing door must open without a button")
		await _wait_until(func() -> bool: return not state.call("is_input_locked"))
		_check(state.get("current_map") == home_id, "Automatic entry must reach correct house")
		if state.get("current_map") != home_id:
			return
		await create_timer(0.9).timeout
		_check(state.get("current_map") == home_id and not state.call("is_input_locked"), "Arrival must not bounce out")
		player.call("face_world_position", player.global_position + Vector3.BACK)
		await _settle()
		_check(not state.call("is_input_locked"), "Facing exit from arrival distance must not trigger")
		# Simulate loading at a clipped exit: remain blocked until leaving its zone.
		player.global_position = Vector3(0, 0.1, 3.0)
		player.call("reset_automatic_interaction")
		await _settle()
		_check(not state.call("is_input_locked"), "Loading beside door must not auto-transition")
		player.global_position = Vector3(0, 0.1, 1.9)
		await _settle()
		player.global_position = Vector3(0, 0.1, 2.45)
		player.call("face_world_position", player.global_position + Vector3.FORWARD)
		await _settle()
		_check(not state.call("is_input_locked"), "Close indoor exit must reject back-facing")
		player.call("face_world_position", player.global_position + Vector3.BACK)
		await _settle()
		_check(state.call("is_input_locked"), "Close indoor exit must open without a button")
		await _wait_until(func() -> bool: return not state.call("is_input_locked"))
		_check(state.get("current_map") == parent_map, "Automatic exit must return to correct map")
		await _wait_until(func() -> bool: return not state.call("is_input_locked"))
		_check(state.get("current_map") == parent_map and not state.call("is_input_locked"), "Return must not bounce back inside")


func _check_facing(world: Node, target: Vector3, message: String) -> void:
	var player := world.get_node("Player") as Node3D
	var direction := Facing.screen_direction(target - player.global_position, root.get_camera_3d())
	var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
	_check(sprite.animation == Facing.ANIMATIONS[Facing.direction_index(direction)], message)


func _check_door_input(player: Node3D, door: Node3D, state: Node) -> void:
	var original_position := player.global_position
	var approach: Vector3 = (door.global_basis * (door as Interactable3D).facing_direction).normalized()
	# At and just beyond the trigger center, the point-to-player vector vanishes
	# or reverses. Door-facing must remain stable on both sides of that point.
	for depth: float in [-0.15, 0.0, 0.15]:
		player.global_position = door.global_position + approach * depth
		player.global_position.y = original_position.y
		player.call("face_world_position", player.global_position + approach)
		_check(player.call("get_nearest_interactable") == door, "Facing door while touching or clipping must allow interaction")
		_check(player.call("get_interaction_prompt") == door.get("prompt_text"), "Touching door must retain its prompt")
		player.call("face_world_position", player.global_position - approach)
		_check(player.call("get_nearest_interactable") != door, "Touching door must not allow back-facing interaction")
	player.global_position = original_position
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


func _wait_until(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(condition.call(), "Door choreography timed out")
