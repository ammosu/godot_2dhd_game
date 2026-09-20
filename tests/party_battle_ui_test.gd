extends SceneTree
var failures: int = 0
var cues: Array[StringName] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready_for_action(battle: Node) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while not bool(battle.call("can_accept_action")) and not bool(battle.call("is_resolved")) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(bool(battle.call("can_accept_action")) or bool(battle.call("is_resolved")), "Party UI action timed out")

func _run() -> void:
	var state := root.get_node("GameState")
	root.get_node("GameAudio").connect("cue_played", func(cue: StringName) -> void: cues.append(cue))
	state.call("reset_new_game", false)
	var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	battle.call("start_battle", {"max_hp": 64})
	await process_frame
	var model: RefCounted = state.get("battle_session")
	battle.call("choose_action", "attack")
	await _ready_for_action(battle)
	_check(int(model.current) == 1, "Noah did not receive second turn")
	battle.call("_select_action", "protect")
	battle.call("_select_target", 0)
	_check(not (battle.get("_cards")[0] as Button).disabled, "Support target cannot be selected")
	battle.call("choose_action", "protect")
	await _ready_for_action(battle)
	_check(int(model.current) == 2 and model.is_protected(0), "Elder turn or protection missing")
	_check((battle.get("_wards")[0] as TextureRect).visible, "Protected actor has no persistent ward")
	_check(not (battle.get("_wards")[1] as TextureRect).visible, "Ward shown on protector rather than target")
	battle.call("_select_action", "magic")
	battle.call("_select_target", 4)
	_check((battle.get("_ring") as Line2D).visible, "AoE range preview missing")
	_check((battle.get("_preview") as Label).text.contains("3 人"), "AoE preview count differs from model")
	if "--party-art-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.dream-loop/party-range-preview.png")
	(battle.get("_confirm") as Button).pressed.emit()
	battle.call("choose_action", "magic")
	_check(int(state.get("player_mp")) == 20, "MP charged before impact")
	await create_timer(0.22).timeout
	_check(int(model.actors[2].mp) == 24 and int(state.get("player_mp")) == 20, "Repeated input double-charged MP or impact missing")
	_check(cues.count(&"frost_nova") == 1 and cues.count(&"frost_impact") == 1, "AoE sound must fire once per cast, not once per target")
	_check(int(model.actors[3].hp) == 29 and int(model.actors[4].hp) == 21 and int(model.actors[5].hp) == 25, "Actual AoE targets/damage differ from preview")
	if "--party-art-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.dream-loop/party-magic-impact.png")
	await _ready_for_action(battle)
	_check(int(model.current) == 0 and int(model.round_number) == 2, "Enemy phase did not return control")
	_check(int(model.actors[5].mp) == 24, "Enemy mage never cast AoE")
	_check(int(model.actors[0].hp) < 100 and int(model.actors[1].hp) < 80 and int(model.actors[2].hp) == 65, "Enemy edge AoE did not honor range/friendly-fire rules")
	_check((battle.get("_stage") as Control).find_children("*", "Node2D", true, false).filter(func(node: Node) -> bool: return node.get_script() == load("res://scripts/ui/magic_burst.gd")).is_empty(), "Magic effects leaked after turn")
	battle.call("choose_action", "slash")
	await _ready_for_action(battle)
	_check(not (battle.get("_wards")[0] as TextureRect).visible, "Ward survived protector next turn")
	battle.call("choose_action", "attack")
	await create_timer(0.18).timeout
	var spear_hit := (battle.get("_stage") as Control).get_node_or_null("PhysicalHit") as TextureRect
	_check(spear_hit != null, "Physical hit missing at contact")
	if spear_hit != null:
		_check(spear_hit.texture.resource_path.ends_with("spear_hit.tres"), "Noah still uses sword contact")
		var expected_point: Vector2 = battle.call("_point", int(battle.get("_target")))
		_check((spear_hit.position + spear_hit.size * 0.5).is_equal_approx(expected_point - Vector2(0, 70)), "Weapon impact is not centered on target")
	if "--party-art-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.dream-loop/party-spear-impact.png")
	await _ready_for_action(battle)
	_check((battle.get("_stage") as Control).get_node_or_null("PhysicalHit") == null, "Physical hit leaked after turn")
	_check(int(model.current) == 2, "Elder healing turn missing")
	battle.call("_select_action", "heal")
	battle.call("_select_target", 0)
	var before_heal: int = model.actors[0].hp
	battle.call("choose_action", "heal")
	await create_timer(0.22).timeout
	_check(int(model.actors[0].hp) == mini(100, before_heal + 30) and int(model.actors[2].mp) == 18, "Healing impact or mana failed")
	var healing_nodes: Array[Node] = (battle.get("_stage") as Control).find_children("*", "Node2D", true, false).filter(func(node: Node) -> bool: return node.get_script() == load("res://scripts/ui/healing_burst.gd"))
	_check(healing_nodes.size() == 1, "Healing must use its own effect, not tinted offensive magic")
	if "--party-art-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.dream-loop/party-heal-impact.png")
	await _ready_for_action(battle)
	for turn: int in range(20):
		if bool(battle.call("is_resolved")):
			break
		var using_bolt: bool = int(model.current) == 2
		var mana_before: int = model.actors[2].mp
		battle.call("choose_action", "skill" if using_bolt else "attack")
		if using_bolt:
			await create_timer(0.10).timeout
			var projectile := (battle.get("_stage") as Control).get_node_or_null("MoonBoltProjectile") as TextureRect
			_check(projectile != null and int(model.actors[2].mp) == mana_before, "Moon bolt missing or mana spent before arrival")
			if projectile != null:
				_check((projectile.texture as AtlasTexture).atlas.resource_path == "res://assets/generated/moon_bolt.png", "Projectile reused unrelated art")
			if "--party-art-capture" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.dream-loop/party-bolt-flight.png")
			await create_timer(0.34).timeout
			_check(int(model.actors[2].mp) == mana_before - 5, "Moon bolt impact did not charge mana exactly once")
			_check((battle.get("_stage") as Control).get_node_or_null("MoonBoltProjectile") == null, "Projectile survived arrival")
			if "--party-art-capture" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.dream-loop/party-bolt-impact.png")
		await _ready_for_action(battle)
	_check(bool(battle.call("did_player_win")), "Party UI did not resolve victory")
	for index: int in range(3, 6):
		_check((battle.get("_portraits")[index] as TextureRect).texture.resource_path.ends_with("_defeated.tres"), "Defeated enemy is still standing")
	_check((battle.get("_stage") as Control).find_children("*", "Node2D", true, false).filter(func(node: Node) -> bool: return node.get_script() == load("res://scripts/ui/moon_bolt_burst.gd")).is_empty(), "Moon bolt impact leaked")
	_check((battle.get("_stage") as Control).find_children("*", "Node2D", true, false).filter(func(node: Node) -> bool: return node.get_script() == load("res://scripts/ui/healing_burst.gd")).is_empty(), "Healing effect leaked after battle")
	for cue: StringName in [&"moon_slash", &"moon_bolt", &"frost_nova", &"frost_impact", &"protect", &"moon_heal"]:
		_check(cues.has(cue), "Role cue missing from live party battle: " + String(cue))
	_check(cues.count(&"protect") == 1 and cues.count(&"moon_heal") == 1, "Support cue fired multiple times")
	await process_frame
	var continue_button := battle.get("_continue") as Button
	_check(continue_button.visible and root.get_visible_rect().encloses(continue_button.get_global_rect()), "Victory button outside viewport")
	if "--party-art-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.dream-loop/party-victory-defeated.png")
	battle.call("_finish_battle")
	_check(state.get("battle_session") == null and not bool(battle.call("is_active")), "Party encounter state not released")
	battle.queue_free()
	state.set("battle_session", null)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.3).timeout
	if failures == 0:
		print("PARTY_BATTLE_UI_TEST_PASS preview impact targets input_lock mana turn_order enemy_aoe cleanup")
	quit(0 if failures == 0 else 1)
