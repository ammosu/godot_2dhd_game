extends SceneTree
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _wait_pose(battle: Node, index: int, pose: String) -> void:
	var deadline := Time.get_ticks_msec() + 2500
	var portrait := battle.get("_portraits")[index] as TextureRect
	while not portrait.texture.resource_path.ends_with("_%s.tres" % pose) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(portrait.texture.resource_path.ends_with("_%s.tres" % pose), "Missing caster phase: " + pose)

func _run() -> void:
	var state := root.get_node("GameState")
	for sample: Dictionary in [
		{"caster": 2, "action": "magic", "target": 4, "mp": 24, "hp": 21},
		{"caster": 2, "action": "skill", "target": 3, "mp": 27, "hp": 976},
		{"caster": 2, "action": "heal", "target": 0, "mp": 26, "hp": 80},
		{"caster": 5, "action": "magic", "target": 0, "mp": 24, "hp": 33},
	]:
		state.call("reset_new_game", false)
		var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
		root.add_child(battle)
		battle.call("start_battle", {"max_hp": 1000})
		var model: RefCounted = state.get("battle_session")
		model.current = sample.caster
		model.actors[0].hp = 50
		state.call("sync_party_battle")
		var portrait := battle.get("_portraits")[sample.caster] as TextureRect
		for pose: String in ["windup", "recover"]:
			battle.call("_pose", sample.caster, pose)
			var texture := portrait.texture as AtlasTexture
			_check(texture.get_size() == Vector2(1120, 840), "Invalid caster canvas")
			_check(Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region), "Caster crop outside source")
			_check(texture.region.end.x < 887 if pose == "windup" else texture.region.position.x > 887, "Caster crop crosses center gutter")
			var ratio: float = portrait.size.y / texture.get_height()
			var point: Vector2 = battle.call("_point", sample.caster)
			_check(absf(portrait.position.y + Grounding.foot_baseline(texture, 0.5) * ratio - point.y) < 0.1, "Caster feet left ground")
			if "--party-art-capture" in OS.get_cmdline_user_args():
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.dream-loop/caster-%d-%s.png" % [sample.caster, pose])
		battle.call("_pose", sample.caster, "idle")
		var before_hp: int = model.actors[sample.target].hp
		# Direct execution also covers enemy presentation; the normal UI test
		# separately proves the enemy AI selects this spell during its turn.
		battle.call("_execute", sample.action, sample.target)
		await _wait_pose(battle, sample.caster, "windup")
		_check(int(model.actors[sample.caster].mp) == 32 and int(model.actors[sample.target].hp) == before_hp, "Windup resolved magic early")
		battle.call("choose_action", sample.action)
		await _wait_pose(battle, sample.caster, "attack")
		_check(not bool(battle.call("can_accept_action")), "Caster release unlocked input")
		await _wait_pose(battle, sample.caster, "recover")
		_check(int(model.actors[sample.caster].mp) == sample.mp, "Caster MP did not resolve once")
		_check(int(model.actors[sample.target].hp) == sample.hp, "Caster damage/healing did not resolve once")
		_check(not bool(battle.call("can_accept_action")), "Caster recovery unlocked input")
		var deadline := Time.get_ticks_msec() + 3000
		while bool(battle.get("_busy")) and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(not bool(battle.get("_busy")), "Caster animation did not finish")
		_check(portrait.texture.resource_path.ends_with("_idle.tres"), "Caster did not return idle")
		battle.free()
		state.set("battle_session", null)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("CASTER_MOTION_TEST_PASS atlas ground windup release recovery input_lock damage healing mana turns")
	quit(0 if failures == 0 else 1)
