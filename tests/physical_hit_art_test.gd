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
	var expected: Array[String] = ["sword_slash.png", "spear_hit.tres", "staff_hit.tres", "sword_slash.png", "claw_hit.tres", "staff_hit.tres"]
	for index: int in range(6):
		var texture: Texture2D = battle.call("_physical_texture", index, "attack")
		_check(texture.resource_path.ends_with(expected[index]), "Wrong weapon contact art for actor %d" % index)
	_check((battle.call("_physical_texture", 0, "slash") as Texture2D).resource_path.ends_with("moon_slash_hit.tres"), "Empowered slash has no distinct art")
	for id: String in ["spear_hit", "claw_hit", "staff_hit", "moon_slash_hit"]:
		var texture := load("res://assets/generated/%s.tres" % id) as AtlasTexture
		var image := texture.atlas.get_image().get_region(Rect2i(texture.region))
		_check(image.get_size() == Vector2i(627, 627), "Incorrect hit crop dimensions")
		_check(not image.is_invisible() and image.detect_alpha() != Image.ALPHA_NONE, "Hit texture missing transparency or content")
		_check(image.get_pixel(0, 0).a < 0.01 and image.get_pixel(626, 626).a < 0.01, "Hit crop touches corners")
	battle.free()
	state.set("battle_session", null)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("PHYSICAL_HIT_ART_TEST_PASS weapon_mapping empowered_slash alpha crops")
	quit(0 if failures == 0 else 1)
