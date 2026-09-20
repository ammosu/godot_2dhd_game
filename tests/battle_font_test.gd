extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var font := (load("res://assets/fonts/Cubic_11.ttf") as FontFile).duplicate() as FontFile
	font.allow_system_fallback = false
	font.fallbacks = []
	var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	battle.call("start_battle", {"max_hp": 64})
	var model: RefCounted = root.get_node("GameState").get("battle_session")
	var missing: Dictionary = {}
	for actor: int in range(3):
		model.current = actor
		for action: String in model.available_actions():
			battle.call("_select_action", action)
			for node: Node in battle.find_children("*", "Control", true, false):
				if node is Label or node is Button:
					var value: String = node.text
					for index: int in range(value.length()):
						var code: int = value.unicode_at(index)
						if code > 32 and not font.has_char(code):
							missing[value[index]] = code
	battle.free()
	root.get_node("GameState").set("battle_session", null)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if not missing.is_empty():
		push_error("Bundled battle font lacks glyphs: " + str(missing))
		quit(1)
		return
	print("BATTLE_FONT_TEST_PASS three_roles all_actions no_system_fallback")
	quit()
