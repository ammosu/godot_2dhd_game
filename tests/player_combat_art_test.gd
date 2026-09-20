extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var source: Texture2D
	for pose: String in ["idle", "attack", "hurt", "guard"]:
		var texture := load("res://assets/generated/wanderer_combat_%s.tres" % pose) as AtlasTexture
		if texture == null:
			push_error("Player combat pose could not load")
			quit(1)
			return
		_check(texture.get_size() == Vector2(832, 512), "Combat pose canvas changed")
		if source == null:
			source = texture.atlas
		_check(texture.atlas == source, "Combat poses must share an atlas")
		var image := texture.atlas.get_image()
		_check(image.detect_alpha() != Image.ALPHA_NONE, "Combat atlas requires alpha")
		var region := Rect2i(texture.region)
		_check(Rect2i(Vector2i.ZERO, image.get_size()).encloses(region), "Combat crop outside source")
		var bottom: int = 0
		var visible_pixels: int = 0
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x):
				if image.get_pixel(x, y).a >= 0.25:
					visible_pixels += 1
					bottom = maxi(bottom, y - region.position.y + 1)
					_check(x > region.position.x and x < region.end.x - 1 and y > region.position.y and y < region.end.y - 1, "Combat silhouette clipped")
		_check(visible_pixels > 1000, "Combat pose is empty")
		_check(is_equal_approx(float(bottom) + texture.margin.position.y, 492.0), "Combat feet not aligned")
	var battle := (load("res://scripts/ui/battle_ui.gd") as Script).new() as CanvasLayer
	root.add_child(battle)
	battle.call("start_battle", {"name": "Art test", "max_hp": 1000, "attack": 20, "defense": 0})
	await _observe_turn(battle)
	var state := root.get_node("GameState")
	var expected_damage := maxi(1, 20 - int(state.get("player_defense")))
	for action: String in ["attack", "guard", "attack"]:
		var hp_before: int = int(state.get("player_hp"))
		battle.call("choose_action", action)
		var poses_seen: Dictionary = await _observe_turn(battle)
		var guarded := action == "guard"
		_check(poses_seen.has("guard" if guarded else "attack"), "Action pose not displayed: " + action)
		_check(poses_seen.has("slash"), "Attack impact texture was not displayed")
		_check(not poses_seen.has("hurt") if guarded else poses_seen.has("hurt"), "Wrong reaction to counterattack")
		var expected := maxi(1, expected_damage / 2) if guarded else expected_damage
		_check(hp_before - int(state.get("player_hp")) == expected, "Presentation changed guard damage behavior")
		var actor := battle.get("_player_art") as TextureRect
		_check(actor.texture.resource_path.ends_with("wanderer_combat_idle.tres"), "Player must return to idle")
	battle.queue_free()
	await process_frame
	if _failures == 0:
		print("PLAYER_COMBAT_ART_TEST_PASS atlas alpha baseline attack hurt guard reset damage")
	quit(0 if _failures == 0 else 1)


func _observe_turn(battle: CanvasLayer) -> Dictionary:
	var seen: Dictionary = {}
	var actor := battle.get("_player_art") as TextureRect
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var stage := battle.get("_combat_stage") as Control
		for child: Node in stage.get_children():
			if child is TextureRect and child.name == "SwordSlash":
				_check((child as TextureRect).texture != null, "Slash texture missing")
				seen["slash"] = true
		var pose := actor.texture.resource_path.get_file().trim_prefix("wanderer_combat_").trim_suffix(".tres")
		seen[pose] = true
		if bool(battle.call("can_accept_action")):
			return seen
		await process_frame
	_check(false, "Player combat art turn timed out")
	return seen
