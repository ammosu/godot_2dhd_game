extends Node

signal state_changed
signal map_change_requested(map_id: String, spawn_id: String)
signal notification_requested(message: String)

enum Mode { EXPLORE, DIALOGUE, BATTLE }
enum QuestState { NOT_STARTED, ACTIVE, READY_TO_TURN_IN, COMPLETE }

const SAVE_VERSION := 1
const SAVE_PATH := "user://wanderlight_save.json"

var mode: Mode = Mode.EXPLORE
var current_map: String = "village"
var spawn_id: String = "default"
var saved_position: Vector3 = Vector3.ZERO
var has_saved_position: bool = false

var quest_state: QuestState = QuestState.NOT_STARTED
var inventory: Dictionary = {"potion": 2}
var flags: Dictionary = {}

var player_max_hp: int = 100
var player_hp: int = 100
var player_max_mp: int = 20
var player_mp: int = 20
var player_attack: int = 18
var player_defense: int = 4


func reset_new_game(announce: bool = true) -> void:
	mode = Mode.EXPLORE
	current_map = "village"
	spawn_id = "default"
	saved_position = Vector3.ZERO
	has_saved_position = false
	quest_state = QuestState.NOT_STARTED
	inventory = {"potion": 2}
	flags = {}
	player_hp = player_max_hp
	player_mp = player_max_mp
	state_changed.emit()
	if announce:
		notification_requested.emit("已開始新的旅程")


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	state_changed.emit()


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
	notification_requested.emit("接受任務：月光碎片")
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
	match quest_state:
		QuestState.NOT_STARTED:
			return "主線：與村莊長老交談"
		QuestState.ACTIVE:
			return "主線：前往北境遺跡，擊敗守衛"
		QuestState.READY_TO_TURN_IN:
			return "主線：將月光碎片交給村莊長老"
		QuestState.COMPLETE:
			return "主線完成：月光重新照耀村莊"
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
	if not parsed is Dictionary or int(parsed.get("version", 0)) != SAVE_VERSION:
		if announce:
			notification_requested.emit("存檔格式不相容")
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
		"flags": flags.duplicate(true),
		"player_hp": player_hp,
		"player_mp": player_mp,
	}


func _apply_save(data: Dictionary) -> void:
	mode = Mode.EXPLORE
	current_map = str(data.get("current_map", "village"))
	spawn_id = str(data.get("spawn_id", "default"))
	quest_state = clampi(int(data.get("quest_state", 0)), QuestState.NOT_STARTED, QuestState.COMPLETE) as QuestState
	inventory = Dictionary(data.get("inventory", {"potion": 2})).duplicate(true)
	flags = Dictionary(data.get("flags", {})).duplicate(true)
	player_hp = clampi(int(data.get("player_hp", player_max_hp)), 1, player_max_hp)
	player_mp = clampi(int(data.get("player_mp", player_max_mp)), 0, player_max_mp)
	has_saved_position = bool(data.get("has_saved_position", false))
	var position_data: Array = data.get("saved_position", [0.0, 0.0, 0.0])
	if position_data.size() == 3:
		saved_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	else:
		has_saved_position = false
