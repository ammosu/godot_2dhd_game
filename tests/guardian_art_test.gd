extends SceneTree
## Verifies guardian texture alignment and presentation transitions, without saves.

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var source: Texture2D
	for pose: String in ["front", "idle", "attack", "hurt"]:
		var texture := load("res://assets/generated/guardian_%s.tres" % pose) as AtlasTexture
		if texture == null:
			push_error("Guardian pose could not load: " + pose)
			quit(1)
			return
		_check(texture.get_size() == Vector2(960, 640), "Guardian pose canvas changed")
		if source == null:
			source = texture.atlas
		_check(texture.atlas == source, "Guardian poses must share one source atlas")
		var image := texture.atlas.get_image()
		_check(image.detect_alpha() != Image.ALPHA_NONE, "Guardian atlas requires alpha")
		var region := Rect2i(texture.region)
		_check(Rect2i(Vector2i.ZERO, image.get_size()).encloses(region), "Guardian crop outside source")
		var visible_pixels: int = 0
		var bottom: int = 0
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x):
				if image.get_pixel(x, y).a >= 0.25:
					visible_pixels += 1
					bottom = maxi(bottom, y - region.position.y + 1)
					_check(x > region.position.x and x < region.end.x - 1 and y > region.position.y and y < region.end.y - 1, "Guardian silhouette clipped")
		_check(visible_pixels > 1000, "Guardian pose empty")
		_check(is_equal_approx(float(bottom) + texture.margin.position.y, 620.0), "Guardian foot baseline changed")
	var battle := (load("res://scripts/ui/battle_ui.gd") as Script).new() as CanvasLayer
	root.add_child(battle)
	var stage := battle.get("_combat_stage") as Control
	var backdrop := stage.get_node("RuinBackdrop") as TextureRect
	_check(backdrop.texture != null, "Battle background did not load")
	_check(backdrop.get_index() == 0 and backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Background must remain behind actors and ignore input")
	_check(backdrop.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Background must preserve image proportions")
	battle.call("start_battle", {"name": "Art test", "max_hp": 1000, "attack": 1, "defense": 0})
	if not await _wait_ready(battle):
		quit(1)
		return
	var actor := battle.get("_enemy_art") as TextureRect
	battle.call("choose_action", "attack")
	var seen_hurt: bool = false
	var seen_attack: bool = false
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var path := actor.texture.resource_path
		seen_hurt = seen_hurt or path.ends_with("guardian_hurt.tres")
		seen_attack = seen_attack or path.ends_with("guardian_attack.tres")
		if bool(battle.call("can_accept_action")):
			break
		await process_frame
	_check(bool(battle.call("can_accept_action")), "Guardian animation did not finish")
	_check(seen_hurt and seen_attack, "Guardian hit and counterattack poses must both appear")
	_check(actor.texture.resource_path.ends_with("guardian_idle.tres"), "Guardian must return to idle")
	_check(actor.modulate.is_equal_approx(Color.WHITE), "Legacy purple tint returned")
	_check(not actor.flip_h, "Guardian battle art must face left without mirroring")
	battle.queue_free()
	await process_frame
	if _failures == 0:
		print("GUARDIAN_ART_TEST_PASS atlas alpha baseline hit counterattack idle")
	quit(0 if _failures == 0 else 1)


func _wait_ready(battle: CanvasLayer) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if bool(battle.call("can_accept_action")):
			return true
		await process_frame
	push_error("Guardian battle intro timed out")
	return false
