extends SceneTree

const Catalog = preload("res://scripts/systems/party_equipment.gd")
const Appearance = preload("res://scripts/gameplay/equipment_appearance.gd")
var failures: Array[String] = []
var capture: bool = false
var upgrades: Dictionary = {
	"wanderer": {"weapon": "moonsteel_saber", "armor": "moonward_cloak"},
	"noah": {"weapon": "dawn_partisan", "armor": "dawn_plate"},
	"elder": {"weapon": "astral_staff", "armor": "astral_robe"},
}


func _init() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func screenshot(label: String) -> void:
	if not capture:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/wanderlight-party-equipment-%s.png" % label
	check(root.get_texture().get_image().save_png(path) == OK, "Capture failed")
	print(path)


func run() -> void:
	capture = "--equipment-capture" in OS.get_cmdline_user_args()
	var state: Node = root.get_node("GameState")
	state.call("reset_new_game", false)
	check(state.get("owned_equipment").size() == 12, "Expected 12 equipment items")
	for actor: String in Catalog.ACTORS:
		var original: Dictionary = state.call("get_loadout", actor)
		check(original == Catalog.defaults(actor), "Wrong defaults: " + actor)
		check(state.call("equipment_for_slot", "weapon", actor).size() == 2, "Wrong weapon choices")
		check(state.call("equipment_for_slot", "armor", actor).size() == 2, "Wrong armor choices")
		var copy: Dictionary = state.call("get_loadout", actor)
		copy.weapon = "invalid"
		check(state.call("get_loadout", actor) == original, "Loadout getter leaked mutable authority")
		for other: String in Catalog.ACTORS:
			if actor != other:
				check(not state.call("equip_item", upgrades[other].weapon, actor), "Cross-character weapon accepted")
		check(not state.call("equip_loadout", {"weapon": upgrades[actor].weapon, "armor": "invalid"}, actor), "Invalid loadout accepted")
		check(state.call("get_loadout", actor) == original, "Rejected loadout partly committed")
		for mask: int in range(4):
			var loadout := original.duplicate(true)
			if mask & 1:
				loadout.weapon = upgrades[actor].weapon
			if mask & 2:
				loadout.armor = upgrades[actor].armor
			check(state.call("equip_loadout", loadout, actor), "Valid combination rejected")
			for pose: String in Appearance.POSES:
				var base := load("res://assets/generated/%s_combat_%s.tres" % [actor, pose]) as Texture2D
				var texture := Appearance.texture_for(base, pose, loadout, actor)
				check(texture != null, "Missing replacement texture")
				if mask == 0:
					check(texture == base, "Original art not restored")
				else:
					var atlas := texture as AtlasTexture
					check(atlas.atlas != (base as AtlasTexture).atlas, "Original atlas retained")
					check(atlas.region.position.x >= 0 and atlas.region.position.y >= 0 and atlas.region.end.x <= atlas.atlas.get_width() and atlas.region.end.y <= atlas.atlas.get_height(), "Crop outside sheet")
					check(atlas.atlas.get_image().get_pixel(0, 0).a == 0, "Opaque background")
					check(str(texture.get_meta("variant", "")) == Appearance.variant(loadout, actor), "Wrong variant")
			if actor != "wanderer":
				var base := load("res://assets/generated/%s.tres" % actor) as Texture2D
				var texture := Appearance.texture_for(base, "npc", loadout, actor)
				check((texture == base) == (mask == 0), "NPC replacement/restore failed")
	var save_path := "user://party_equipment_test_%d.json" % Time.get_ticks_usec()
	check(state.call("save_game", save_path, false), "Save failed")
	state.call("reset_new_game", false)
	check(state.call("load_game", save_path, false), "Load failed")
	for actor: String in Catalog.ACTORS:
		check(state.call("get_loadout", actor) == upgrades[actor], "Saved loadout lost: " + actor)
	var malformed: Dictionary = state.call("_serialize")
	malformed.companion_equipped.noah = 5
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(malformed))
	file.close()
	check(not state.call("load_game", save_path, false), "Malformed companion save accepted")
	check(state.call("get_loadout", "elder") == upgrades.elder, "Rejected save mutated state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var ui: Node = world.get_node("EquipmentUI")
	ui.call("open")
	ui.call("select_actor", "noah")
	ui.call("select_item", "dawn_partisan")
	check(state.call("get_loadout", "noah") == Catalog.defaults("noah"), "Preview committed companion gear")
	ui.call("select_actor", "elder")
	ui.call("select_item", "astral_robe")
	ui.call("select_actor", "noah")
	check(str(ui.get("pending").weapon) == "dawn_partisan", "Tab switch lost preview")
	ui.call("close")
	ui.call("open")
	check(ui.get("pending") == Catalog.defaults("noah"), "Close failed to discard drafts")
	for actor: String in Catalog.ACTORS:
		ui.call("select_actor", actor)
		for item_id: String in ui.get("_buttons"):
			var button: Button = ui.get("_buttons")[item_id]
			check(button.visible == bool(state.call("equipment_matches_actor", item_id, actor)), "Wrong character items visible")
		ui.call("select_item", upgrades[actor].weapon)
		await screenshot(actor + "-weapon")
		ui.call("select_item", upgrades[actor].armor)
		await screenshot(actor + "-both")
		ui.call("confirm_equipment")
		check(state.call("get_loadout", actor) == upgrades[actor], "UI confirmation failed")
		if actor != "wanderer":
			var npc: Node = world.get("_map_root").get_node(actor.capitalize() + "/CharacterArt")
			check(str(npc.get("texture").get_meta("variant", "")) == Appearance.variant(upgrades[actor], actor), "Village NPC did not update")
	ui.call("close")
	await screenshot("village")
	# The legacy turn-based UI is tested independently of the action-world HUD.
	world.queue_free()
	await process_frame
	var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	battle.call("start_battle", {"name": "隊伍換裝測試", "max_hp": 1000, "attack": 14, "defense": 3})
	for index: int in range(3):
		var actor := Catalog.ACTORS[index]
		var stats: Vector2i = state.call("equipment_stats", upgrades[actor], actor)
		check(int(state.get("battle_session").actors[index].attack) == stats.x and int(state.get("battle_session").actors[index].defense) == stats.y, "Battle stats did not inherit gear")
		check(not state.call("equip_item", Catalog.DEFAULTS[actor].weapon, actor), "Battle equipment lock bypassed")
		for pose: String in Appearance.POSES:
			battle.call("_pose", index, pose)
			var texture: Texture2D = battle.get("_portraits")[index].texture
			check(str(texture.get_meta("variant", "")) == Appearance.variant(upgrades[actor], actor), "Battle animation reverted gear")
		battle.call("_pose", index, "idle")
	await screenshot("battle")
	# Exercise the real asynchronous attack flow, not only direct pose selection.
	for index: int in range(3):
		var actor := Catalog.ACTORS[index]
		var deadline := Time.get_ticks_msec() + 5000
		while not battle.call("can_accept_action") and Time.get_ticks_msec() < deadline:
			await process_frame
		state.get("battle_session").current = index
		var hp_before := int(state.get("battle_session").actors[3].hp)
		battle.call("_execute", "attack", int(battle.get("_target")))
		for phase: String in ["windup", "attack", "recover", "idle"]:
			deadline = Time.get_ticks_msec() + 5000
			var art: TextureRect = battle.get("_portraits")[index]
			while str(art.texture.get_meta("pose", "")) != phase and Time.get_ticks_msec() < deadline:
				await process_frame
			check(str(art.texture.get_meta("pose", "")) == phase, "Missing live phase: " + actor + " " + phase)
			check(str(art.texture.get_meta("variant", "")) == Appearance.variant(upgrades[actor], actor), "Live attack reverted gear")
		check(int(state.get("battle_session").actors[3].hp) < hp_before, "Attack did not deal damage")
	var round_deadline := Time.get_ticks_msec() + 12000
	while not battle.call("can_accept_action") and Time.get_ticks_msec() < round_deadline:
		await process_frame
	check(battle.call("can_accept_action"), "Enemy round failed to finish")
	if capture:
		await gallery()
	battle.queue_free()
	await process_frame
	state.set("battle_session", null)
	state.call("reset_new_game", false)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	if failures.is_empty():
		print("PARTY_EQUIPMENT_TEST_PASS three_actors twelve_loadouts 84_battle_poses npc save stats drafts locks live_attacks")
	quit(0 if failures.is_empty() else 1)


func gallery() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 110
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("182737")
	canvas.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for actor: String in ["noah", "elder"]:
		var nodes: Array[Node] = []
		for index: int in range(7):
			var pose := Appearance.POSES[index]
			var base := load("res://assets/generated/%s_combat_%s.tres" % [actor, pose]) as Texture2D
			var art := TextureRect.new()
			art.texture = Appearance.texture_for(base, pose, upgrades[actor], actor)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var ratio := 245.0 / base.get_height()
			art.size = art.texture.get_size() * ratio
			art.position = Vector2(160 + (index % 4) * 320 - art.size.x / 2, 60 + (index / 4) * 330 - Appearance.PAD.y * ratio)
			canvas.add_child(art)
			nodes.append(art)
			var label := Label.new()
			label.text = actor + " " + pose
			label.position = Vector2(80 + (index % 4) * 320, 20 + (index / 4) * 330)
			canvas.add_child(label)
			nodes.append(label)
		await screenshot(actor + "-poses")
		for node: Node in nodes:
			node.queue_free()
		await process_frame
	canvas.queue_free()
	await process_frame
