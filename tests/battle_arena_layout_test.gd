extends SceneTree

const Layout = preload("res://scripts/systems/battle_arena_layout.gd")
var failures: int = 0


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var first := Layout.generate("forest", 481)
	_check(first == Layout.generate("forest", 481), "Fixed seed failed to reproduce arena")
	_check(first.props != Layout.generate("forest", 482).props, "Different seeds did not vary dressing")
	_check(Layout.generate("nonsense", -51).theme == "ruins", "Invalid theme fallback failed")
	_check(Layout.normalize_theme(" VILLAGE ") == "village", "Theme normalization failed")
	_check(Layout.generate("forest", 481, 900) == first, "Invalid layout should use seeded default")
	for theme: String in Layout.THEMES:
		for visual_seed: int in range(128):
			var descriptor := Layout.generate(theme, visual_seed)
			_check(int(descriptor.layout_version) == 1 and int(descriptor.layout_index) in range(4), "Invalid layout metadata")
			_check(descriptor.props.size() >= 2 and descriptor.props.size() <= 7, "Arena dressing density outside authored limits")
			var placed: Array[Dictionary] = []
			for prop: Dictionary in descriptor.props:
				_check(Layout.is_safe_prop(prop, placed), "Unsafe arena dressing: %s seed %s" % [theme, visual_seed])
				_check(prop.kind in Layout.POOLS[theme].rear or prop.kind in Layout.POOLS[theme].low, "Prop leaked between biomes")
				var position: Vector3 = prop.position
				_check(position.z <= -3.5 or (absf(position.x) >= 8.0 and position.z >= 3.5), "Prop entered battle lane")
				for other: Dictionary in placed:
					var minimum: float = float(Layout.RADII[prop.kind]) * float(prop.scale) + float(Layout.RADII[other.kind]) * float(other.scale) + 0.25
					_check(position.distance_to(other.position) >= minimum, "Overlapping footprint")
				placed.append(prop)
	var rejected := {"kind": "pillar", "position": Vector3.ZERO, "scale": 1.0, "rotation": 0.0}
	_check(not Layout.is_safe_prop(rejected, []), "Central blocking pillar was accepted")
	rejected.position = Vector3(8.5, 0, 3.65)
	_check(not Layout.is_safe_prop(rejected, []), "Tall front pillar was accepted")
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	seed(5711)
	var expected_first := randi()
	var expected_second := randi()
	seed(5711)
	_check(randi() == expected_first, "Global RNG test setup failed")
	Layout.generate("ruins", 71)
	state.call("begin_party_battle", {})
	_check(randi() == expected_second, "Arena setup consumed gameplay global RNG")
	_check(state.get("battle_visual").theme == "village", "Village encounter default incorrect")
	state.call("set_mode", 0)
	_check(state.get("battle_visual").is_empty() and state.get("battle_session") == null, "Battle exit kept stale visual/session")
	state.set("current_map", "ruins")
	state.call("begin_party_battle", {})
	_check(state.get("battle_visual").theme == "ruins", "Ruins encounter default incorrect")
	var last: int = state.get("battle_visual").layout_index
	for index: int in range(24):
		state.call("begin_party_battle", {})
		var current_visual: Dictionary = state.get("battle_visual")
		_check(current_visual == Layout.generate(current_visual.theme, current_visual.visual_seed), "Normal encounter cannot reconstruct from its seed")
		var current: int = current_visual.layout_index
		_check(current != last, "Consecutive encounters repeated layout")
		last = current
	state.call("begin_party_battle", {"arena_theme": "moon_spring", "visual_seed": 808})
	var preview: Dictionary = state.get("battle_visual").duplicate(true)
	state.call("begin_party_battle", {"arena_theme": "moon_spring", "visual_seed": 808})
	_check(state.get("battle_visual") == preview, "Explicit encounter seed changed on repeat")
	_check(preview == Layout.generate("moon_spring", 808), "State descriptor differs from pure generator")
	state.call("begin_party_battle", {"arena_theme": [], "visual_seed": {}})
	_check(state.get("battle_visual").theme == "ruins", "Malformed enemy visual overrides were not ignored")
	var save_data: Dictionary = state.call("_serialize")
	_check(not save_data.has("battle_visual") and int(save_data.version) == 3, "Transient arena changed save schema")
	state.call("_apply_save", save_data)
	_check(state.get("battle_visual").is_empty() and state.get("battle_session") == null, "Load retained stale battle")
	state.call("begin_party_battle", {})
	state.call("reset_new_game", false)
	_check(state.get("battle_visual").is_empty() and state.get("battle_session") == null, "New game retained battle state")
	_check(state.get("_last_battle_layout").is_empty(), "New game retained layout history")
	if failures == 0:
		print("BATTLE_ARENA_LAYOUT_TEST_PASS reproducible variation themes clearance spacing rng lifecycle")
	quit(0 if failures == 0 else 1)
