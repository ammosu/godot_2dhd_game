extends Node

signal state_changed
signal map_change_requested(map_id: String, spawn_id: String)
signal notification_requested(message: String)

enum Mode { EXPLORE, DIALOGUE, BATTLE, EQUIPMENT, TRANSITION, MAP }
enum QuestState { NOT_STARTED, ACTIVE, READY_TO_TURN_IN, COMPLETE }

const SAVE_VERSION := 3
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
		for stat: String in ["attack", "defense", "max_hp", "max_mp"]:
			battle_session.actors[index][stat] = initial[index][stat]
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
		ThemeDB.fallback_font = ui_font


func reset_new_game(announce: bool = true) -> void:
	clear_party_battle()
	_last_battle_layout.clear()
	mode = Mode.EXPLORE
	current_map = "village"
	spawn_id = "default"
	saved_position = Vector3.ZERO
	has_saved_position = false
	quest_state = QuestState.NOT_STARTED
	inventory = {"potion": 2}
	owned_equipment = _starter_equipment()
	equipped = {"weapon": "traveler_blade", "armor": "traveler_coat"}
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
	return catalog


func _starter_equipment() -> Array[String]:
	var result: Array[String] = []
	result.assign(_equipment_catalog().keys())
	return result


func get_loadout(actor: String = "wanderer") -> Dictionary:
	return equipped.duplicate(true) if actor == "wanderer" else Dictionary(companion_equipped.get(actor, {})).duplicate(true)


func can_equip(item_id: String, actor: String) -> bool:
	return actor in PartyEquipment.ACTORS and item_id in owned_equipment and EQUIPMENT_CATALOG.has(item_id) and str(EQUIPMENT_CATALOG[item_id].get("actor", "wanderer")) == actor


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
	for slot: String in EQUIPMENT_SLOTS:
		var item: Dictionary = EQUIPMENT_CATALOG.get(str(loadout.get(slot, "")), {})
		if str(item.get("slot", "")) == slot and str(item.get("actor", "wanderer")) == actor:
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


func _refresh_equipment_stats() -> void:
	player_attack = BASE_ATTACK
	player_defense = BASE_DEFENSE
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
	if not parsed is Dictionary or int(parsed.get("version", 0)) not in [1, 2, SAVE_VERSION]:
		if announce:
			notification_requested.emit("存檔格式不相容")
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
	_apply_save(parsed)
	state_changed.emit()
	map_change_requested.emit(current_map, "saved_position" if has_saved_position else spawn_id)
	if announce:
		notification_requested.emit("存檔已讀取")
	return true


func _serialize() -> Dictionary:
	return {
		"version": SAVE_VERSION,
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
	clear_party_battle()
	_last_battle_layout.clear()
	mode = Mode.EXPLORE
	current_map = str(data.get("current_map", "village"))
	spawn_id = str(data.get("spawn_id", "default"))
	quest_state = clampi(int(data.get("quest_state", 0)), QuestState.NOT_STARTED, QuestState.COMPLETE) as QuestState
	inventory = Dictionary(data.get("inventory", {"potion": 2})).duplicate(true)
	var saved_owned: Array = data.get("owned_equipment", ["traveler_blade", "moonsteel_saber", "traveler_coat", "moonward_cloak"])
	owned_equipment.clear()
	for item_id: Variant in saved_owned:
		var typed_id := str(item_id)
		if EQUIPMENT_CATALOG.has(typed_id) and typed_id not in owned_equipment:
			owned_equipment.append(typed_id)
	equipped = Dictionary(data.get("equipped", {"weapon": "traveler_blade", "armor": "traveler_coat"})).duplicate(true)
	for slot: String in EQUIPMENT_SLOTS:
		var item_id := str(equipped.get(slot, ""))
		if not can_equip(item_id, "wanderer") or str(Dictionary(EQUIPMENT_CATALOG.get(item_id, {})).get("slot", "")) != slot:
			equipped[slot] = "traveler_blade" if slot == "weapon" else "traveler_coat"
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
