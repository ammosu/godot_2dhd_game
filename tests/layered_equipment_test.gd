extends SceneTree
const Actor = preload("res://scripts/gameplay/layered_combat_actor.gd")
const Portrait = preload("res://scripts/ui/equipment_portrait.gd")
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	check("--layered-equipment" in OS.get_cmdline_user_args(), "Pass -- --layered-equipment for integration checks")
	var state := root.get_node("GameState")
	var saved: Dictionary = state.get("equipped").duplicate(true)
	var companions: Dictionary = state.get("companion_equipped").duplicate(true)
	var actor := Actor.new()
	root.add_child(actor)
	var portrait := Portrait.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(portrait)
	for id: String in ["wanderer", "noah", "elder"]:
		var shared: Texture2D = load(Actor.art_path(id, "base"))
		for layer: String in ["base", "coat", "moonward", "blade", "saber"]:
			var tex: Texture2D = load(Actor.art_path(id, layer))
			check(tex.get_size() == Vector2(1254,1254), "Source size: " + id + layer)
			check(tex.get_image().get_pixel(0,0).a < 0.02, "Transparent corner exceeds cutout threshold: " + id + layer)
		for pose: String in Actor.POSES:
			for armor: String in ["coat", "moonward"]:
				for weapon: String in ["blade", "saber"]:
					actor.configure(pose, armor, weapon, false, true, id)
					check(actor.get_node("SharedHead").texture == shared and actor.get_node("GripFingers").texture == shared, "Identity: " + id)
					check(actor.get_node("Clothing").texture.resource_path == Actor.art_path(id, armor), "Armor independence")
					check(actor.get_node("Weapon").texture.resource_path == Actor.art_path(id, weapon), "Weapon independence")
					check(actor.get_node("GripFingers").get_index() > actor.get_node("Weapon").get_index(), "Hand occlusion")
					if id == "noah" and pose in ["attack", "guard"]:
						var fitting: Dictionary = Actor.profile(id)
						var index: int = Actor.POSES.find(pose)
						var anchors: PackedVector2Array = Actor.points(fitting.weapon_anchors[weapon][index])
						var targets: PackedVector2Array = Actor.points([fitting.grips[index], fitting.secondary[index]])
						var shaft: Polygon2D = actor.get_node("Weapon")
						for grip: int in range(2):
							check((shaft.transform * (anchors[grip] - Actor.ORIGINS[index])).distance_to(targets[grip] - Actor.ORIGINS[index]) < 0.01, "Two-handed grip alignment")
			var base: Texture2D = load("res://assets/generated/" + id + "_combat_" + pose + ".tres")
			portrait.dress(base, pose, {}, id)
			portrait.size = Vector2(450,320)
			check(portrait._layered.visible and portrait._layered.actor_id == id, "Portrait actor")
			check(portrait.texture.get_size() == base.get_size() + Vector2(96,80), "Cross-actor canvas cache")
			check(portrait.texture.has_meta("ground_y"), "Ground metadata")
		for pose: String in ["windup", "recover", "defeated"]:
			var base: Texture2D = load("res://assets/generated/" + id + "_combat_" + pose + ".tres")
			portrait.dress(base, pose, {}, id)
			check(not portrait._layered.visible and portrait.texture == base, "Fallback: " + id + pose)
		actor.configure("idle", "", "", false, true, id)
		check(not actor.has_node("Clothing") and not actor.has_node("Weapon") and actor.has_node("Body"), "Empty slots")
	actor.hide()
	portrait.hide()
	check(state.get("equipped") == saved, "Visual test mutated inventory")
	var ui: Node = load("res://scripts/ui/equipment_ui.gd").new()
	root.add_child(ui)
	state.call("set_mode", 0)
	ui.open()
	var upgrades: Dictionary = {
		"wanderer": {"armor":"moonward_cloak","weapon":"moonsteel_saber"},
		"noah": {"armor":"dawn_plate","weapon":"dawn_partisan"},
		"elder": {"armor":"astral_robe","weapon":"astral_staff"}
	}
	for id: String in upgrades:
		ui.select_actor(id)
		ui.select_item(upgrades[id].armor)
		ui.select_item(upgrades[id].weapon)
		for pose: String in Actor.POSES:
			ui.set_preview_pose(pose)
			check(ui._portrait.texture.get_meta("layered", false) and ui._portrait._layered.actor_id == id, "Equipment UI actor")
			await capture("ui-" + id + "-" + pose)
	check(state.get("equipped") == saved and state.get("companion_equipped") == companions, "Try-on mutated equipment")
	ui.close()
	check(state.get("equipped") == saved, "Cancel changed equipment")
	check(state.get("companion_equipped") == companions, "Cancel changed companion equipment")
	ui.queue_free()
	var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	battle.start_battle({"name":"圖層測試", "max_hp":1000, "attack":14, "defense":3})
	for pose: String in Actor.POSES:
		for index: int in range(3):
			battle._pose(index, pose)
			var live: TextureRect = battle.get("_portraits")[index]
			check(live.texture.get_meta("layered", false) and live._layered.visible, "Battle layers")
			check(live._layered.actor_id == ["wanderer","noah","elder"][index], "Battle identity")
		await capture("battle-" + pose)
	battle.queue_free()
	state.set("battle_session", null)
	state.call("set_mode", 0)
	actor.queue_free()
	portrait.queue_free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await process_frame
	if failures.is_empty():
		print("LAYERED_EQUIPMENT_TEST_PASS three_actors 48_combinations shared_identity independent_gear portrait_cache fallback preview_cancel battle")
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	if "--layers-ui-capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("/tmp/wanderlight-layers-" + label + "-" + RenderingServer.get_current_rendering_method() + ".png") == OK, "Capture failed")
