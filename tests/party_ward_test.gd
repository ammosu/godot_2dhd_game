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
	var ward := battle.get("_wards")[0] as TextureRect
	_check(not ward.visible, "Ward shown before protection")
	var image: Image = ward.texture.get_image()
	_check(image.detect_alpha() != Image.ALPHA_NONE, "Ward lacks transparency")
	_check(image.get_pixel(image.get_width() / 2, image.get_height() / 2).a < 0.01, "Ward center must remain transparent")
	model.current = 1
	model.resolve("protect", 0)
	battle.call("_refresh")
	_check(ward.visible, "Active protection not displayed")
	_check(ward.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Ward captures input")
	model.actors[1].hp = 0
	battle.call("_refresh")
	_check(not ward.visible, "Fallen protector left stale ward")
	model.actors[1].hp = 80
	model.actors[0].hp = 0
	battle.call("_refresh")
	_check(not ward.visible, "Fallen recipient left stale ward")
	model.actors[0].hp = 100
	battle.set("_resolved", true)
	battle.call("_refresh")
	_check(not ward.visible, "Result screen retained protection")
	battle.call("_finish_battle")
	battle.call("start_battle", {})
	_check(not ward.visible, "New encounter retained old ward")
	battle.free()
	state.set("battle_session", null)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("PARTY_WARD_TEST_PASS alpha state death resolution restart input")
	quit(0 if failures == 0 else 1)
