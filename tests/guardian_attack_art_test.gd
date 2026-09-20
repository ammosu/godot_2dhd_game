extends SceneTree
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
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
	var portrait := battle.get("_portraits")[3] as TextureRect
	var idle_ratio: float = portrait.size.y / portrait.texture.get_height()
	for pose: String in ["windup", "attack", "recover", "idle"]:
		battle.call("_pose", 3, pose)
		var texture := portrait.texture as AtlasTexture
		var ratio: float = portrait.size.y / texture.get_height()
		_check(is_equal_approx(ratio, idle_ratio), "Guardian pose changed body pixel scale: " + pose)
		var point: Vector2 = battle.call("_point", 3)
		var foot: float = portrait.position.y + Grounding.foot_baseline(texture, 0.5) * ratio
		_check(absf(foot - point.y) < 0.1, "Guardian feet left the ground: " + pose)
		if pose in ["windup", "recover"]:
			_check(texture.get_size() == Vector2(1120, 736), "Guardian transition canvas changed")
			_check(Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region), "Guardian crop exceeds source")
			_check(texture.region.end.x < 887 if pose == "windup" else texture.region.position.x > 887, "Guardian crop crosses atlas gutter")
			_check(absf(Grounding.foot_baseline(texture, 0.5) - 700.0) <= 1.0, "Guardian transition baseline changed")
		if "--party-art-capture" in OS.get_cmdline_user_args():
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.dream-loop/guardian-" + pose + ".png")
	battle.free()
	state.set("battle_session", null)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("GUARDIAN_ATTACK_ART_TEST_PASS canvas crops gutter body_scale grounded_feet")
	quit(0 if failures == 0 else 1)
