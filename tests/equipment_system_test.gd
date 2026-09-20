extends SceneTree

var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.call("reset_new_game", false)
	_check(int(state.get("player_attack")) == 18, "Starter weapon did not preserve attack baseline")
	_check(int(state.get("player_defense")) == 4, "Starter armor did not preserve defense baseline")
	_check(state.call("equipment_for_slot", "weapon") == ["traveler_blade", "moonsteel_saber"], "Weapon inventory is incorrect")
	_check(bool(state.call("equip_item", "moonsteel_saber")), "Owned weapon could not be equipped")
	_check(int(state.get("player_attack")) == 22, "Weapon bonus did not update attack")
	_check(bool(state.call("equip_item", "moonward_cloak")), "Owned armor could not be equipped")
	_check(int(state.get("player_defense")) == 7, "Armor bonus did not update defense")
	_check(not bool(state.call("equip_item", "missing_item")), "Unknown equipment was accepted")
	state.get("owned_equipment").erase("traveler_blade")
	_check(not bool(state.call("equip_item", "traveler_blade")), "Unowned equipment was accepted")
	state.get("owned_equipment").append("traveler_blade")
	var before: Dictionary = state.get("equipped").duplicate(true)
	_check(not bool(state.call("equip_loadout", {"weapon": "traveler_coat", "armor": "traveler_blade"})), "Wrong-slot loadout accepted")
	_check(state.get("equipped") == before, "Rejected loadout was partially applied")

	var save_path := "user://equipment_system_test.json"
	_check(bool(state.call("save_game", save_path, false)), "Equipment save failed")
	state.call("reset_new_game", false)
	_check(bool(state.call("load_game", save_path, false)), "Equipment load failed")
	_check(str(state.get("equipped").weapon) == "moonsteel_saber", "Saved weapon was not restored")
	_check(str(state.get("equipped").armor) == "moonward_cloak", "Saved armor was not restored")
	_check(int(state.get("player_attack")) == 22 and int(state.get("player_defense")) == 7, "Loaded equipment stats were not rebuilt")

	var legacy := {"version": 1, "current_map": "village", "spawn_id": "default", "saved_position": [0.0, 0.0, 0.0], "has_saved_position": false, "quest_state": 0, "inventory": {"potion": 1}, "flags": {}, "player_hp": 80, "player_mp": 10}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	_check(bool(state.call("load_game", save_path, false)), "Version 1 save migration failed")
	_check(str(state.get("equipped").weapon) == "traveler_blade", "Legacy save did not receive starter weapon")
	_check(int(state.get("player_attack")) == 18 and int(state.get("player_defense")) == 4, "Legacy save baseline stats changed")
	legacy["version"] = 2
	legacy["owned_equipment"] = ["moonsteel_saber", "invalid", "moonsteel_saber"]
	legacy["equipped"] = {"weapon": "moonsteel_saber", "armor": "traveler_blade"}
	file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	_check(bool(state.call("load_game", save_path, false)), "Recoverable equipment save rejected")
	_check(state.call("equipment_for_slot", "weapon") == ["moonsteel_saber"] and state.call("equipment_for_slot", "armor") == ["traveler_coat"], "Equipment sanitization broke traveler ownership")
	_check(state.call("equipment_for_slot", "weapon", "noah") == ["watch_spear", "dawn_partisan"], "Version 2 migration did not grant companion starter gear")
	_check(str(state.get("equipped").armor) == "traveler_coat", "Wrong-slot saved equipment not repaired")
	legacy["owned_equipment"] = 42
	file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	before = state.get("equipped").duplicate(true)
	_check(not bool(state.call("load_game", save_path, false)), "Malformed equipment save accepted")
	_check(state.get("equipped") == before, "Malformed load mutated equipment")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	if _failures.is_empty():
		print("EQUIPMENT_SYSTEM_TEST_PASS catalog slots stats validation save migration")
		quit(0)
	else:
		quit(1)
