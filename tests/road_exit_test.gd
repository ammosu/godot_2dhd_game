extends SceneTree
## Actual player movement crosses every optional road mouth, without interact().
const Routes = preload("res://scripts/gameplay/outskirts.gd")
var _failures: int = 0
var _changes: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	state.map_change_requested.connect(func(_map: String, _spawn: String) -> void: _changes += 1)
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	var directions: Dictionary = {"travel_east": Vector3.RIGHT, "travel_home": Vector3.LEFT, "travel_forest": Vector3.FORWARD, "travel_road": Vector3.BACK}
	for id: String in Routes.EXITS:
		var route: Array = Routes.EXITS[id]
		for lane: float in [-1.15, 0.0, 1.15]:
			world.call("_load_map", route[0], "default")
			var area := (world.get("_map_root") as Node).get_node(id) as Area3D
			_check(str(area.get("prompt_text")).is_empty(), "Walking exit must not advertise Space")
			_check(area.find_children("*", "Label3D", true, false).is_empty(), "Entrance must not show destination labels")
			var direction: Vector3 = directions[id]
			var lateral: Vector3 = direction.cross(Vector3.UP)
			player.position = area.position - direction * 2.3 + lateral * lane + Vector3.UP * 0.05
			await physics_frame
			await physics_frame
			var before: int = _changes
			for step: int in range(100):
				await physics_frame
				if str(state.get("current_map")) != route[0]:
					break
				player.velocity = direction * 3.5 + Vector3.DOWN * 2.0
				player.move_and_slide()
			_check(str(state.get("current_map")) == route[1], "Walking route blocked: %s lane %.2f" % [id, lane])
			await create_timer(0.15).timeout
			_check(str(world.get("_notice_label").text).begins_with("抵達・"), "Arrival must announce destination after map loads")
			_check(_changes == before + 1, "Exit repeated or arrival bounced back: " + id)
			_check(str(state.get("current_map")) == route[1], "Arrival must stay on destination map")
	# Staying on a threshold during a dialogue must cross once the lock ends.
	world.call("_load_map", "village", "default")
	state.set("mode", 1)
	player.position = Vector3(26, 0.05, 4.6)
	await create_timer(0.15).timeout
	_check(str(state.get("current_map")) == "village", "Dialogue lock must prevent travel")
	state.set("mode", 0)
	await create_timer(0.2).timeout
	_check(str(state.get("current_map")) == "east_road", "Exit must retry after dialogue closes")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failures == 0:
		print("ROAD_EXIT_TEST_PASS four_routes three_lanes real_movement no_interact no_bounce input_lock")
	quit(0 if _failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
