extends SceneTree
var failures: int = 0
var cues: Array[StringName] = []
var phases: Dictionary = {0: [], 1: [], 2: [], 3: [], 4: [], 5: []}

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _wait(battle: Node) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while not bool(battle.call("can_accept_action")) and Time.get_ticks_msec() < deadline:
		for index: int in phases:
			var path: String = (battle.get("_portraits")[index] as TextureRect).texture.resource_path
			var pose: String = path.get_file().get_basename().get_slice("_", path.get_file().get_basename().get_slice_count("_") - 1)
			if phases[index].is_empty() or phases[index].back() != pose:
				phases[index].append(pose)
		await process_frame
	_check(bool(battle.call("can_accept_action")), "Weapon audio turn timed out")

func _run() -> void:
	var state := root.get_node("GameState")
	var audio := root.get_node("GameAudio")
	audio.connect("cue_played", func(cue: StringName) -> void: cues.append(cue))
	state.call("reset_new_game", false)
	var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	battle.call("start_battle", {})
	var model: RefCounted = state.get("battle_session")
	# Force the mage's existing zero-MP fallback, so every actor uses a weapon.
	model.actors[5].mp = 0
	for index: int in range(3):
		_check(int(model.current) == index, "Weapon test turn order changed")
		battle.call("choose_action", "attack")
		await _wait(battle)
	_check(int(model.current) == 0 and int(model.round_number) == 2, "Weapon round did not complete")
	var expected := {&"slash": 2, &"spear_thrust": 1, &"claw_swipe": 1, &"staff_strike": 2, &"impact": 6}
	for cue: StringName in expected:
		_check(cues.count(cue) == int(expected[cue]), "Wrong live weapon cue count: " + String(cue))
	_check(not cues.has(&"frost_nova"), "Zero-MP mage cast a spell")
	_check(audio.get_child_count() == 8, "Weapon sounds expanded the bounded voice pool")
	for index: int in phases:
		var motion: Array = phases[index].filter(func(pose: String) -> bool: return pose in ["windup", "attack", "recover"])
		_check(motion == ["windup", "attack", "recover"], "Weapon motion phase order: " + str(phases[index]))
		var point: Vector2 = battle.call("_point", index)
		_check((battle.get("_shadows")[index] as Polygon2D).position.is_equal_approx(point), "Weapon recovery displaced shadow")
	battle.free()
	state.set("battle_session", null)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("PARTY_WEAPON_AUDIO_TEST_PASS six_actors sword spear claw staff contact_once voice_limit")
	quit(0 if failures == 0 else 1)
