extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	battle.call("start_battle", {})
	var model: RefCounted = state.get("battle_session")
	for index: int in range(6):
		model.actors[index].hp = 0
		_check(battle.call("_resting_pose", index) == "defeated", "Zero HP still uses standing hurt pose")
		battle.call("_pose", index, "defeated")
		var portrait := battle.get("_portraits")[index] as TextureRect
		var texture := portrait.texture as AtlasTexture
		_check(texture != null and texture.resource_path.ends_with("_defeated.tres"), "Defeated art not bound")
		_check(texture.get_size() == Vector2(1200, 1000), "Prone canvas changed")
		_check(float(texture.get_meta("ground_y", 0)) == 900.0, "Prone body contact metadata missing")
		var image := texture.atlas.get_image().get_region(Rect2i(texture.region))
		_check(not image.is_invisible() and image.detect_alpha() != Image.ALPHA_NONE, "Invalid prone alpha crop")
		var point: Vector2 = battle.call("_point", index)
		_check(is_equal_approx(portrait.position.y + 900.0 * portrait.size.y / 1000.0, point.y), "Prone body is floating")
	battle.call("_refresh")
	if "--party-art-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.dream-loop/party-defeated-gallery.png")
	for index: int in range(6):
		model.actors[index].hp = 1
		_check(battle.call("_resting_pose", index) == "idle", "Living actor retained fallen pose")
		battle.call("_pose", index, "idle")
		_check((battle.get("_shadows")[index] as Polygon2D).scale == Vector2.ONE, "Prone shadow survived recovery")
	model.actors[0].hp = 0
	model.actors[3].hp = 0
	model.actors[4].hp = 0
	model.current = 2
	battle.set("_target", 5)
	battle.call("choose_action", "attack")
	var deadline := Time.get_ticks_msec() + 5000
	while not bool(battle.call("is_resolved")) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(bool(battle.call("did_player_win")) and int(state.get("player_hp")) == 1, "Existing traveler recovery rule changed")
	_check((battle.get("_portraits")[0] as TextureRect).texture.resource_path.ends_with("_idle.tres"), "Recovered traveler still uses prone art")
	battle.free()
	state.set("battle_session", null)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("PARTY_DEFEATED_ART_TEST_PASS six_actors alpha body_contact victory_recovery shadows")
	quit(0 if failures == 0 else 1)
