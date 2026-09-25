extends Node

signal state_changed
signal map_change_requested(map_id: String, spawn_id: String)
signal notification_requested(message: String)

enum Mode { EXPLORE, DIALOGUE, BATTLE, EQUIPMENT, TRANSITION, MAP, CLASS_SELECTION, CUTSCENE }
enum QuestState { NOT_STARTED, ACTIVE, READY_TO_TURN_IN, COMPLETE }

const SAVE_VERSION := 9
const HERO_BODIES: Array[String] = ["male", "female"]
var player_body: String = "male"
const HeroStyle = preload("res://scripts/gameplay/hero_style.gd")
var player_style: String = "original"
const ClassEquipment = preload("res://scripts/systems/class_equipment.gd")
const HeroClasses = preload("res://scripts/systems/hero_classes.gd")
var player_class: String = "traveler"
const PartyEquipment = preload("res://scripts/systems/party_equipment.gd")
const SAVE_PATH := "user://wanderlight_save.json"
const BASE_ATTACK := 14
const BASE_DEFENSE := 2
const EQUIPMENT_SLOTS: Array[String] = ["weapon", "armor"]
const TRAVELER_EQUIPMENT: Dictionary = {
	"traveler_blade": {"name": "旅人短刃", "slot": "weapon", "attack": 4, "defense": 0, "description": "熟悉而可靠的短刃，適合長途旅行。"},
	"moonsteel_saber": {"name": "月鋼彎刀", "slot": "weapon", "attack": 8, "defense": 0, "description": "刀身映著冷藍月色，出手輕快。"},
	"traveler_coat": {"name": "旅人長衣", "slot": "armor", "attack": 0, "defense": 2, "description": "耐磨的厚布長衣，陪伴旅人走過風霧。"},
	"moonward_cloak": {"name": "月守披風", "slot": "armor", "attack": 0, "defense": 5, "description": "縫有月紋護符的披風，能偏轉衝擊。"},
}
var EQUIPMENT_CATALOG: Dictionary = _equipment_catalog()

var mode: Mode = Mode.EXPLORE
var current_map: String = "village"
var spawn_id: String = "default"
var saved_position: Vector3 = Vector3.ZERO
var has_saved_position: bool = false

var quest_state: QuestState = QuestState.NOT_STARTED
var inventory: Dictionary = {"potion": 2}
var owned_equipment: Array[String] = _starter_equipment()
var equipped: Dictionary = {"weapon": "traveler_blade", "armor": "traveler_coat"}
var companion_equipped: Dictionary = {"noah": PartyEquipment.defaults("noah"), "elder": PartyEquipment.defaults("elder")}
var flags: Dictionary = {}

var player_level: int = 1
var player_xp: int = 0
var field_defeated: Dictionary = {}
var field_loot: Dictionary = {}

var player_max_hp: int = 100
var player_hp: int = 100
var player_max_mp: int = 20
var player_mp: int = 20
var player_attack: int = 18
var player_defense: int = 4
var ui_theme: Theme
var title_font: Font = preload("res://assets/fonts/SourceHanSerifTW-SemiBold.otf")
const ActionBattle = preload("res://scripts/systems/action_battle.gd")
const PartyBattle = preload("res://scripts/systems/party_battle.gd")
const BattleArenaLayout = preload("res://scripts/systems/battle_arena_layout.gd")
var battle_session: RefCounted
# Transient presentation data; battle saves are not supported by this save schema.
var battle_visual: Dictionary = {}
var _battle_visual_rng := RandomNumberGenerator.new()
var _last_battle_layout: Dictionary = {}


func begin_party_battle(enemy: Dictionary) -> RefCounted:
	_prepare_battle_visual(enemy)
	battle_session = PartyBattle.new()
	battle_session.setup(player_hp, player_mp, player_attack, player_defense, enemy)
	for index: int in [1, 2]:
		var actor := str(battle_session.actors[index].art)
		var stats := equipment_stats(get_loadout(actor), actor)
		battle_session.actors[index].attack = stats.x
		battle_session.actors[index].defense = stats.y
	battle_session.actors[0].hero_class = player_class
	battle_session.actors[0].hero_style = player_style
	battle_session.actors[0].hero_body = player_body
	battle_session.actors[0].name = str(class_profile().name)
	battle_session.actors[0].speed = 26 if player_class == "thief" else 18
	battle_session.actors[0].max_hp = player_max_hp
	battle_session.actors[0].max_mp = player_max_mp
	set_mode(Mode.BATTLE)
	return battle_session


func begin_action_battle(enemy: Dictionary) -> RefCounted:
	begin_party_battle(enemy)
	var initial: Array[Dictionary] = battle_session.actors
	battle_session = ActionBattle.new()
	battle_session.setup(player_hp, player_mp, player_attack, player_defense, enemy)
	for index: int in range(3):
		for stat: String in ["attack", "defense", "max_hp", "max_mp", "name", "speed"]:
			battle_session.actors[index][stat] = initial[index][stat]
	battle_session.actors[0].hero_class = player_class
	battle_session.actors[0].hero_style = player_style
	battle_session.actors[0].hero_body = player_body
	return battle_session


func advance_action_battle(delta: float, movement: Vector2) -> void:
	if not battle_session is ActionBattle:
		return
	# Manual movement takes over before any consumable can be spent this frame.
	if not movement.is_zero_approx():
		battle_session.set_auto_enabled(false)
	if battle_session.wants_auto_potion():
		use_action_potion()
	battle_session.step(delta, movement)


func use_action_potion() -> bool:
	if not battle_session is ActionBattle or int(inventory.get("potion", 0)) <= 0:
		return false
	if not battle_session.use_potion():
		return false
	inventory["potion"] = int(inventory.get("potion", 0)) - 1
	sync_party_battle()
	return true


func _prepare_battle_visual(enemy: Dictionary) -> void:
	var default_theme := "village" if current_map == "village" or current_map.begins_with("house_") else "ruins"
	var requested_theme: Variant = enemy.get("arena_theme", default_theme)
	var theme := BattleArenaLayout.normalize_theme(requested_theme if requested_theme is String else default_theme)
	var requested_seed: Variant = enemy.get("visual_seed")
	var has_override: bool = requested_seed is int
	var visual_seed: int = requested_seed if has_override else int(_battle_visual_rng.randi())
	battle_visual = BattleArenaLayout.generate(theme, visual_seed)
	# Explicit preview seeds reproduce exactly; ordinary encounters vary layouts.
	if not has_override and int(_last_battle_layout.get(theme, -1)) == int(battle_visual.layout_index):
		visual_seed += _battle_visual_rng.randi_range(1, BattleArenaLayout.LAYOUT_COUNT - 1)
		battle_visual = BattleArenaLayout.generate(theme, visual_seed)
	_last_battle_layout[theme] = int(battle_visual.layout_index)


func clear_party_battle() -> void:
	battle_session = null
	battle_visual = {}


func sync_party_battle() -> void:
	if battle_session == null:
		return
	player_hp = int(battle_session.actors[0].hp)
	player_mp = int(battle_session.actors[0].mp)
	state_changed.emit()


func resolve_party_action(action: String, target: int) -> Dictionary:
	if battle_session == null:
		return {"error": "沒有進行中的戰鬥。"}
	if action == "potion" and int(inventory.get("potion", 0)) <= 0:
		return {"error": "藥水已用完。"}
	var result: Dictionary = battle_session.resolve(action, target)
	if not result.has("error"):
		if action == "potion":
			inventory["potion"] = int(inventory.get("potion", 0)) - 1
		sync_party_battle()
	return result


func _ready() -> void:
	_battle_visual_rng.randomize()
	var ui_font := load("res://assets/fonts/SourceHanSansTW-Regular.otf") as Font
	if ui_font != null:
		ui_theme = Theme.new()
		ui_theme.default_font = ui_font
		ui_theme.default_font_size = 16
		ui_theme.set_type_variation("TitleLabel", "Label")
		ui_theme.set_font("font", "TitleLabel", title_font)
		preload("res://scripts/ui/presentation_theme.gd").apply(ui_theme)
		ThemeDB.fallback_font = ui_font


func reset_new_game(announce: bool = true, class_id: String = "traveler", style_id: String = "original", body_id: String = "male") -> void:
	player_body = body_id if body_id in HERO_BODIES else "male"
	player_style = style_id if HeroStyle.DATA.has(style_id) else "original"
	player_class = class_id if HeroClasses.DATA.has(class_id) else "traveler"
	clear_party_battle()
	_last_battle_layout.clear()
	mode = Mode.EXPLORE
	current_map = "village"
	spawn_id = "default"
	saved_position = Vector3.ZERO
	has_saved_position = false
	quest_state = QuestState.NOT_STARTED
	inventory = {"potion": 2}
	player_level = 1
	player_xp = 0
	field_defeated = {}
	field_loot = {}
	owned_equipment = _starter_equipment()
	equipped = ClassEquipment.defaults(player_class)
	companion_equipped = {"noah": PartyEquipment.defaults("noah"), "elder": PartyEquipment.defaults("elder")}
	_refresh_equipment_stats()
	flags = {}
	player_hp = player_max_hp
	player_mp = player_max_mp
	state_changed.emit()
	if announce:
		notification_requested.emit("已開始新的旅程")


func set_mode(new_mode: Mode) -> void:
	if mode == Mode.BATTLE and new_mode != Mode.BATTLE:
		clear_party_battle()
	mode = new_mode
	state_changed.emit()


func _equipment_catalog() -> Dictionary:
	var catalog := TRAVELER_EQUIPMENT.duplicate(true)
	catalog.merge(PartyEquipment.ITEMS)
	catalog.merge(ClassEquipment.ITEMS)
	return catalog


func _starter_equipment() -> Array[String]:
	var result: Array[String] = []
	for item_id: String in _equipment_catalog():
		if not ClassEquipment.ITEMS.has(item_id) or str(ClassEquipment.ITEMS[item_id].get("class", "")) == player_class:
			result.append(item_id)
	return result


## Presentation-only metadata, kept out of owned equipment and stat calculations.
func visual_loadout(loadout: Dictionary, actor: String = "wanderer") -> Dictionary:
	var result := loadout.duplicate(true)
	if actor == "wanderer":
		result["hero_body"] = player_body
	return result


func get_visual_loadout(actor: String = "wanderer") -> Dictionary:
	return visual_loadout(get_loadout(actor), actor)


func get_loadout(actor: String = "wanderer") -> Dictionary:
	return equipped.duplicate(true) if actor == "wanderer" else Dictionary(companion_equipped.get(actor, {})).duplicate(true)


func can_equip(item_id: String, actor: String) -> bool:
	return item_id in owned_equipment and equipment_matches_actor(item_id, actor)


func equipment_matches_actor(item_id: String, actor: String) -> bool:
	if actor not in PartyEquipment.ACTORS or not EQUIPMENT_CATALOG.has(item_id):
		return false
	var item: Dictionary = EQUIPMENT_CATALOG[item_id]
	if str(item.get("actor", "wanderer")) != actor:
		return false
	return actor != "wanderer" or str(item.get("class", "traveler")) == player_class


func equipment_for_slot(slot: String, actor: String = "wanderer") -> Array[String]:
	var result: Array[String] = []
	if slot not in EQUIPMENT_SLOTS:
		return result
	for item_id: String in owned_equipment:
		var item: Dictionary = EQUIPMENT_CATALOG.get(item_id, {})
		if str(item.get("slot", "")) == slot and can_equip(item_id, actor):
			result.append(item_id)
	return result


func equip_item(item_id: String, actor: String = "wanderer") -> bool:
	if mode not in [Mode.EXPLORE, Mode.EQUIPMENT]:
		return false
	if not can_equip(item_id, actor):
		return false
	var item: Dictionary = EQUIPMENT_CATALOG[item_id]
	var slot := str(item.get("slot", ""))
	if slot not in EQUIPMENT_SLOTS:
		return false
	var loadout := get_loadout(actor)
	loadout[slot] = item_id
	return equip_loadout(loadout, actor)


func get_equipment_item(item_id: String) -> Dictionary:
	return Dictionary(EQUIPMENT_CATALOG.get(item_id, {})).duplicate(true)


func equipment_stats(loadout: Dictionary, actor: String = "wanderer") -> Vector2i:
	var result: Vector2i = PartyEquipment.BASE_STATS.get(actor, Vector2i.ZERO)
	if actor == "wanderer":
		var profile := class_profile()
		result = Vector2i(int(profile.attack) + (player_level - 1) * 2, int(profile.defense) + player_level - 1)
	for slot: String in EQUIPMENT_SLOTS:
		var item: Dictionary = EQUIPMENT_CATALOG.get(str(loadout.get(slot, "")), {})
		if str(item.get("slot", "")) == slot and equipment_matches_actor(str(loadout.get(slot, "")), actor):
			result += Vector2i(int(item.get("attack", 0)), int(item.get("defense", 0)))
	return result


func equip_loadout(loadout: Dictionary, actor: String = "wanderer") -> bool:
	if mode not in [Mode.EXPLORE, Mode.EQUIPMENT]:
		return false
	for slot: String in EQUIPMENT_SLOTS:
		var item_id := str(loadout.get(slot, ""))
		if not can_equip(item_id, actor) or str(get_equipment_item(item_id).get("slot", "")) != slot:
			return false
	var selected := {"weapon": str(loadout.weapon), "armor": str(loadout.armor)}
	if actor == "wanderer":
		equipped = selected
	else:
		companion_equipped[actor] = selected
	_refresh_equipment_stats()
	state_changed.emit()
	notification_requested.emit("裝備已更新")
	return true


func class_profile() -> Dictionary:
	return HeroClasses.profile(player_class)


func _refresh_equipment_stats() -> void:
	var profile := class_profile()
	player_max_hp = int(profile.hp) + (player_level - 1) * 12
	player_max_mp = int(profile.mp) + (player_level - 1) * 3
	player_attack = int(profile.attack) + (player_level - 1) * 2
	player_defense = int(profile.defense) + (player_level - 1)
	for slot: String in EQUIPMENT_SLOTS:
		var item_id := str(equipped.get(slot, ""))
		var item: Dictionary = EQUIPMENT_CATALOG.get(item_id, {})
		player_attack += int(item.get("attack", 0))
		player_defense += int(item.get("defense", 0))


func is_input_locked() -> bool:
	return mode != Mode.EXPLORE


func request_map(map_id: String, target_spawn_id: String) -> void:
	current_map = map_id
	spawn_id = target_spawn_id
	has_saved_position = false
	map_change_requested.emit(map_id, target_spawn_id)
	state_changed.emit()


func remember_player_position(position: Vector3) -> void:
	saved_position = position
	has_saved_position = true


func start_quest() -> void:
	if quest_state != QuestState.NOT_STARTED:
		return
	quest_state = QuestState.ACTIVE
	notification_requested.emit("接受主線：熄滅的月燈")
	state_changed.emit()


func defeat_guardian() -> void:
	flags["guardian_defeated"] = true
	inventory["moon_shard"] = 1
	if quest_state == QuestState.ACTIVE:
		quest_state = QuestState.READY_TO_TURN_IN
	notification_requested.emit("獲得：月光碎片")
	state_changed.emit()


func complete_quest() -> void:
	if quest_state != QuestState.READY_TO_TURN_IN:
		return
	quest_state = QuestState.COMPLETE
	inventory.erase("moon_shard")
	inventory["potion"] = int(inventory.get("potion", 0)) + 3
	player_hp = player_max_hp
	player_mp = player_max_mp
	notification_requested.emit("任務完成！獲得 3 瓶藥水")
	state_changed.emit()


func get_quest_text() -> String:
	if current_map == "ashen_crypt_1":
		return "B1・探索左右環路與側室 → 北端下降 B2"
	if current_map == "ashen_crypt_2":
		return "B2・穿越沉灰牢廊 → 北端燼冠王座"
	if current_map == "ashen_crypt":
		return "墓窟已淨化・沿南側傳送門返回" if flags.get("crypt_cleared", false) else "擊敗燼冠典獄長・維爾莫 → 調查血晶祭壇"
	if current_map.begins_with("house_city_"):
		return "拜訪屋主、查看屋內陳設；南側門口可返回星灣城。"
	if current_map == "caravan_road":
		return "沿商道北行抵達星灣城；南端可返回東行舊道。"
	if current_map == "starbay":
		return "探索星灣城・市集茶棚可休息，南門通往暮光村。"
	if current_map in ["east_road", "firefly_forest"]:
		return "支線：在森林找回包裹，交給舊道旅人" if bool(flags.get("parcel_requested", false)) and not bool(flags.get("road_traveler", false)) else "探索：藍色記號是小事件；沿路標可返回暮光村繼續主線"
	if current_map.begins_with("house_") and quest_state != QuestState.COMPLETE:
		return "主線：從室內南側出口返回村莊，繼續旅程"
	match quest_state:
		QuestState.NOT_STARTED:
			return "主線：與月燈旁的艾爾交談，取得月印"
		QuestState.ACTIVE:
			if current_map == "village":
				return "主線：穿過北方月紋門，前往遺跡"
			return "主線：沿月紋石路向北，與守衛交談"
		QuestState.READY_TO_TURN_IN:
			if current_map == "ruins":
				return "主線：帶著碎片穿過南門，返回暮光村"
			return "主線：將月光碎片交給月燈旁的艾爾"
		QuestState.COMPLETE:
			return "序章完成：月燈復燃、古道甦醒，可自由探索"
	return ""


func damage_player(amount: int) -> void:
	player_hp = clampi(player_hp - maxi(amount, 0), 0, player_max_hp)
	state_changed.emit()


func heal_player(amount: int) -> void:
	player_hp = clampi(player_hp + maxi(amount, 0), 0, player_max_hp)
	state_changed.emit()


func spend_mp(amount: int) -> bool:
	if player_mp < amount:
		return false
	player_mp -= amount
	state_changed.emit()
	return true


func use_potion() -> bool:
	var potion_count := int(inventory.get("potion", 0))
	if potion_count <= 0 or player_hp >= player_max_hp:
		return false
	inventory["potion"] = potion_count - 1
	heal_player(35)
	return true


func restore_after_defeat() -> void:
	restore_player()


func restore_player() -> void:
	player_hp = player_max_hp
	player_mp = player_max_mp
	state_changed.emit()


func has_save_file(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func save_game(path: String = SAVE_PATH, announce: bool = true) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		if announce:
			notification_requested.emit("存檔失敗")
		return false
	file.store_string(JSON.stringify(_serialize(), "\t"))
	file.close()
	if announce:
		notification_requested.emit("遊戲已儲存")
	return true


func load_game(path: String = SAVE_PATH, announce: bool = true) -> bool:
	if not FileAccess.file_exists(path):
		if announce:
			notification_requested.emit("尚無存檔")
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or int(parsed.get("version", 0)) not in [1, 2, 3, 4, 5, 6, 7, 8, SAVE_VERSION]:
		if announce:
			notification_requested.emit("存檔格式不相容")
		return false
	if int(parsed.version) >= 9 and (not parsed.get("player_body") is String or str(parsed.player_body) not in HERO_BODIES):
		return false
	if int(parsed.version) >= 8 and (not parsed.get("player_style") is String or not HeroStyle.DATA.has(parsed.player_style)):
		return false
	if int(parsed.version) >= 6 and (not parsed.get("player_class") is String or not HeroClasses.DATA.has(parsed.player_class)):
		return false
	if not parsed.get("owned_equipment", []) is Array or not parsed.get("equipped", {}) is Dictionary:
		if announce:
			notification_requested.emit("存檔裝備資料格式不相容")
		return false
	if not parsed.get("companion_equipped", {}) is Dictionary:
		return false
	for actor: String in ["noah", "elder"]:
		if not Dictionary(parsed.get("companion_equipped", {})).get(actor, {}) is Dictionary:
			return false
	if not parsed.get("field_defeated", {}) is Dictionary or not parsed.get("field_loot", {}) is Dictionary:
		return false
	for entry: Variant in parsed.get("field_loot", {}).values():
		if not entry is Dictionary or str(entry.get("item", "")) not in ["potion", "moon_moss"]:
			return false
		var at: Variant = entry.get("position")
		if not at is Array or at.size() != 3:
			return false
		for coordinate: Variant in at:
			if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)):
				return false
	_apply_save(parsed)
	state_changed.emit()
	map_change_requested.emit(current_map, "saved_position" if has_saved_position else spawn_id)
	if announce:
		notification_requested.emit("存檔已讀取")
	return true


func _serialize() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player_class": player_class,
		"player_style": player_style,
		"player_body": player_body,
		"player_level": player_level,
		"player_xp": player_xp,
		"field_defeated": field_defeated.duplicate(true),
		"field_loot": field_loot.duplicate(true),
		"current_map": current_map,
		"spawn_id": spawn_id,
		"saved_position": [saved_position.x, saved_position.y, saved_position.z],
		"has_saved_position": has_saved_position,
		"quest_state": int(quest_state),
		"inventory": inventory.duplicate(true),
		"owned_equipment": owned_equipment.duplicate(),
		"equipped": equipped.duplicate(true),
		"companion_equipped": companion_equipped.duplicate(true),
		"flags": flags.duplicate(true),
		"player_hp": player_hp,
		"player_mp": player_mp,
	}


func _apply_save(data: Dictionary) -> void:
	# v1–v7 retain their existing original palette.
	player_body = str(data.get("player_body", "male")) if int(data.get("version", 1)) >= 9 else "male"
	player_style = str(data.get("player_style", "original")) if int(data.get("version", 1)) >= 8 else "original"
	# v1–v5 retain the original traveler stats and equipment.
	player_class = str(data.get("player_class", "traveler")) if int(data.get("version", 1)) >= 6 else "traveler"
	clear_party_battle()
	_last_battle_layout.clear()
	mode = Mode.EXPLORE
	current_map = str(data.get("current_map", "village"))
	spawn_id = str(data.get("spawn_id", "default"))
	# v1–v3 migrate to level 1 and an untouched field encounter.
	player_level = clampi(int(data.get("player_level", 1)), 1, 99)
	player_xp = clampi(int(data.get("player_xp", 0)), 0, xp_to_next_level() - 1)
	field_defeated = Dictionary(data.get("field_defeated", {})).duplicate(true)
	field_loot = Dictionary(data.get("field_loot", {})).duplicate(true)
	quest_state = clampi(int(data.get("quest_state", 0)), QuestState.NOT_STARTED, QuestState.COMPLETE) as QuestState
	inventory = Dictionary(data.get("inventory", {"potion": 2})).duplicate(true)
	var saved_owned: Array = data.get("owned_equipment", ["traveler_blade", "moonsteel_saber", "traveler_coat", "moonward_cloak"])
	owned_equipment.clear()
	for item_id: Variant in saved_owned:
		var typed_id := str(item_id)
		if EQUIPMENT_CATALOG.has(typed_id) and typed_id not in owned_equipment:
			owned_equipment.append(typed_id)
	# v6 vocations shared traveler gear. Grant their proper starting wardrobe.
	if int(data.get("version", 1)) < 7 and player_class != "traveler":
		for item_id: String in ClassEquipment.ITEMS:
			if str(ClassEquipment.ITEMS[item_id].get("class", "")) == player_class and item_id not in owned_equipment:
				owned_equipment.append(item_id)
	equipped = Dictionary(data.get("equipped", {"weapon": "traveler_blade", "armor": "traveler_coat"})).duplicate(true)
	for slot: String in EQUIPMENT_SLOTS:
		var item_id := str(equipped.get(slot, ""))
		if not can_equip(item_id, "wanderer") or str(Dictionary(EQUIPMENT_CATALOG.get(item_id, {})).get("slot", "")) != slot:
			equipped[slot] = ClassEquipment.defaults(player_class)[slot]
			if str(equipped[slot]) not in owned_equipment:
				owned_equipment.append(str(equipped[slot]))
	# v1/v2 did not contain companion equipment. Grant the new starter choices
	# deliberately, without changing the traveler's existing ownership/loadout.
	if int(data.get("version", 1)) < 3:
		for item_id: String in PartyEquipment.ITEMS:
			if item_id not in owned_equipment:
				owned_equipment.append(item_id)
	companion_equipped = {}
	for actor: String in ["noah", "elder"]:
		var selected: Dictionary = Dictionary(data.get("companion_equipped", {})).get(actor, PartyEquipment.defaults(actor)).duplicate(true)
		for slot: String in EQUIPMENT_SLOTS:
			var item_id := str(selected.get(slot, ""))
			if not can_equip(item_id, actor) or str(get_equipment_item(item_id).get("slot", "")) != slot:
				selected[slot] = PartyEquipment.DEFAULTS[actor][slot]
				if str(selected[slot]) not in owned_equipment:
					owned_equipment.append(str(selected[slot]))
		companion_equipped[actor] = selected
	_refresh_equipment_stats()
	flags = Dictionary(data.get("flags", {})).duplicate(true)
	player_hp = clampi(int(data.get("player_hp", player_max_hp)), 1, player_max_hp)
	player_mp = clampi(int(data.get("player_mp", player_max_mp)), 0, player_max_mp)
	has_saved_position = bool(data.get("has_saved_position", false))
	var position_data: Array = data.get("saved_position", [0.0, 0.0, 0.0])
	if position_data.size() == 3:
		saved_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	else:
		has_saved_position = false

	# v5 splits the old combined dungeon into two floors and a boss room.
	if int(data.get("version", 1)) < 5:
		if current_map == "ashen_crypt":
			current_map = "ashen_crypt_1"
			spawn_id = "entry"
			has_saved_position = false
		for floor_id: String in preload("res://scripts/gameplay/crypt_layout.gd").FLOOR_SPAWNS:
			for spawn: Dictionary in preload("res://scripts/gameplay/crypt_layout.gd").FLOOR_SPAWNS[floor_id]:
				if field_loot.has(spawn.id):
					field_loot[spawn.id].position = [spawn.at.x, spawn.at.y, spawn.at.z]


func resolve_outskirts_event(event_id: String) -> String:
	var event_maps := {"road_sign": "east_road", "road_traveler": "east_road", "forest_parcel": "firefly_forest", "forest_herb": "firefly_forest", "forest_rest": "firefly_forest"}
	if mode != Mode.EXPLORE or str(event_maps.get(event_id, "")) != current_map:
		return "現在無法進行這個事件。"
	if bool(flags.get(event_id, false)) and event_id != "forest_rest":
		return "這裡的事情已經處理好了。謝謝你的幫忙。"
	var message := ""
	match event_id:
		"road_sign":
			message = "你扶正了鬆動的路標：西往暮光村，北入螢光森林，東經風丘商道通往星灣城。底座旁留著一瓶給過路人的藥水。獲得藥水 ×1。"
			inventory["potion"] = int(inventory.get("potion", 0)) + 1
		"road_traveler":
			if int(inventory.get("lost_parcel", 0)) == 0:
				flags["parcel_requested"] = true
				state_changed.emit()
				return "我在森林西側岔路丟了一個包裹，裡面是送給村裡的種子。若你找到它，請帶回來給我。"
			inventory.erase("lost_parcel")
			inventory["potion"] = int(inventory.get("potion", 0)) + 2
			message = "正是我的種子！這兩瓶藥水請收下。等月光回來，我會把種子送進村裡。獲得藥水 ×2。"
		"forest_parcel":
			inventory["lost_parcel"] = 1
			flags["parcel_requested"] = true
			message = "你在樹根旁找到繫著藍布的包裹。紙籤寫著『村用種子・驛路旅人』，帶回東行舊道問問吧。"
		"forest_herb":
			inventory["potion"] = int(inventory.get("potion", 0)) + 1
			message = "你只摘下成熟的月露草，留下新芽，調製成一瓶藥水。獲得藥水 ×1。"
		"forest_rest":
			player_hp = player_max_hp
			player_mp = player_max_mp
			message = "螢光在樹根的晶石間流動。你聽著葉聲休息片刻，體力與魔力完全恢復。"
	flags[event_id] = true
	state_changed.emit()
	return message


func xp_to_next_level() -> int:
	return 30 + (player_level - 1) * 20


func defeat_field_enemy(id: String, at: Vector3, caster: bool) -> bool:
	if field_defeated.has(id):
		return false
	field_defeated[id] = true
	var reward: int = 24 if caster else 18
	player_xp += reward
	var levels: int = 0
	while player_level < 99 and player_xp >= xp_to_next_level():
		player_xp -= xp_to_next_level()
		player_level += 1
		levels += 1
	player_xp = mini(player_xp, xp_to_next_level() - 1)
	_refresh_equipment_stats()
	if levels > 0:
		player_hp = mini(player_max_hp, player_hp + levels * 12)
		player_mp = mini(player_max_mp, player_mp + levels * 3)
	field_loot[id] = {"position": [at.x, at.y, at.z], "item": "moon_moss" if caster else "potion"}
	state_changed.emit()
	notification_requested.emit("經驗 +%d%s" % [reward, "・升至 Lv.%d！" % player_level if levels > 0 else ""])
	return true


func collect_field_loot(id: String) -> bool:
	if not field_loot.has(id):
		return false
	var item: String = str(field_loot[id].item)
	inventory[item] = int(inventory.get(item, 0)) + 1
	field_loot.erase(id)
	state_changed.emit()
	notification_requested.emit("拾取・%s ×1" % ("月苔" if item == "moon_moss" else "藥水"))
	return true


func claim_crypt_reward() -> bool:
	if current_map != "ashen_crypt" or mode != Mode.EXPLORE:
		return false
	if bool(flags.get("crypt_cleared", false)):
		notification_requested.emit("灰燼墓窟已淨化・獎勵已領取")
		return false
	if not field_defeated.has("crypt_ash_warden"):
		notification_requested.emit("血晶仍受典獄長封印・先擊敗維爾莫")
		return false
	flags["crypt_cleared"] = true
	inventory["potion"] = int(inventory.get("potion", 0)) + 3
	inventory["moon_moss"] = int(inventory.get("moon_moss", 0)) + 2
	state_changed.emit()
	notification_requested.emit("灰燼墓窟淨化！藥水 ×3・月苔 ×2")
	return true


func resolve_crypt_event(id: String) -> String:
	var map_ids := {"crypt_spring_1": "ashen_crypt_1", "crypt_lore_1": "ashen_crypt_1", "crypt_cache_2": "ashen_crypt_2", "crypt_lore_2": "ashen_crypt_2"}
	if mode != Mode.EXPLORE or map_ids.get(id, "") != current_map:
		return ""
	if id.begins_with("crypt_lore"):
		flags[id] = true
		state_changed.emit()
		return "典獄長維爾莫曾守護墓窟。他將最後的月光封入胸前血晶，如今只記得阻止生者。" if id == "crypt_lore_1" else "銘文：斧刃升起時退開；赤焰鎖定後離開原地。血晶半碎之時，典獄長將失去最後的理智。"
	if flags.get(id, false):
		return "泉水已沉寂。" if id == "crypt_spring_1" else "補給箱已經空了。"
	flags[id] = true
	if id == "crypt_spring_1":
		restore_player()
	else:
		inventory["potion"] = int(inventory.get("potion", 0)) + 2
	state_changed.emit()
	return "月露泉恢復了生命與魔力。" if id == "crypt_spring_1" else "獲得守衛留下的藥水 ×2。"
