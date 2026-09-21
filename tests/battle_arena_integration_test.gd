extends SceneTree
const Layout = preload("res://scripts/systems/battle_arena_layout.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var state := root.get_node("GameState")
	var original_mode: int = state.mode
	var original_hp: int = state.player_hp
	var original_inventory: Dictionary = state.inventory.duplicate(true)
	var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	for theme: String in ["village", "forest", "ruins", "moon_spring", "eclipse"]:
		battle.call("show_arena_preview", Layout.generate(theme, 42))
		await process_frame
		var viewport: SubViewport = battle.get("_arena_viewport")
		_check(viewport.own_world_3d and viewport.world_3d != root.world_3d, "Arena world leaks into exploration")
		_check(not battle.call("can_accept_action"), "Gallery allows combat mutation")
		for index: int in range(6):
			var anchor: Vector2 = battle.call("_point", index)
			_check(Rect2(0, 0, 1120, 380).has_point(anchor), "Actor ground anchor outside stage")
			var portrait: TextureRect = battle.get("_portraits")[index]
			_check(portrait.texture != null and portrait.position.y >= 0.0, "Actor art missing or cropped above stage")
		var range_points: PackedVector2Array = battle.call("_projected_range", 4, 2.0)
		_check(range_points.size() == 65 and absf(range_points[16].y) < absf(range_points[0].x), "AoE preview does not project onto ground")
	_check(state.mode == original_mode and state.player_hp == original_hp and state.inventory == original_inventory and state.battle_session == null, "Preview changed authoritative gameplay state")
	battle.free()
	battle = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	battle.call("start_battle", {"arena_theme": "forest", "visual_seed": 42})
	_check((battle.get("_arena_viewport") as SubViewport).render_target_update_mode != SubViewport.UPDATE_DISABLED, "Combat arena failed to render")
	battle.call("_execute", "attack", 3)
	await create_timer(0.18).timeout
	var hit := (battle.get("_stage") as Control).get_node_or_null("PhysicalHit") as TextureRect
	_check(hit != null, "Physical impact missing")
	if hit != null:
		for portrait: TextureRect in battle.get("_portraits"):
			_check(hit.z_index > portrait.z_index, "Physical impact hidden behind actor")
	var deadline := Time.get_ticks_msec() + 2000
	while not battle.call("can_accept_action") and Time.get_ticks_msec() < deadline:
		await process_frame
	battle.session.winner = 0
	battle.set("_resolved", true)
	battle.call("_finish_battle")
	_check((battle.get("_arena_viewport") as SubViewport).render_target_update_mode == SubViewport.UPDATE_DISABLED, "Closed battle still renders")
	_check(state.battle_session == null and not battle.call("is_active"), "Battle lifecycle not released")
	battle.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.2).timeout
	if failures == 0:
		print("BATTLE_ARENA_INTEGRATION_TEST_PASS isolation projection preview_state lifecycle five_themes")
	quit(0 if failures == 0 else 1)
