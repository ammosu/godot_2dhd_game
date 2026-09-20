extends SceneTree
const AreaSkill = preload("res://scripts/gameplay/area_skill.gd")

func _initialize() -> void:
	var actors: Array[Dictionary] = [
		{"team": 0, "hp": 80, "position": Vector2.ZERO},
		{"team": 1, "hp": 30, "position": Vector2(1, 0)},
		{"team": 1, "hp": 30, "position": Vector2(2, 0)},
		{"team": 1, "hp": 30, "position": Vector2(2.01, 0)},
		{"team": 1, "hp": 0, "position": Vector2.ZERO},
		{"team": 1, "hp": 30, "position": Vector2(NAN, 0)},
	]
	var before := actors.duplicate(true)
	var valid: bool = AreaSkill.enemy_indices(actors, 0, Vector2.ZERO, 2.0) == [1, 2]
	valid = valid and AreaSkill.enemy_indices(actors, 0, Vector2.ZERO, -1).is_empty()
	valid = valid and AreaSkill.enemy_indices(actors, 0, Vector2.ZERO, INF).is_empty()
	valid = valid and AreaSkill.enemy_indices(actors, 0, Vector2(INF, 0), 2).is_empty()
	valid = valid and AreaSkill.enemy_indices([], 0, Vector2.ZERO, 2).is_empty()
	valid = valid and int(actors[1].hp) == int(before[1].hp)
	if valid:
		print("AREA_SKILL_TEST_PASS enemies radius boundary defeated allies invalid no_mutation")
	else:
		push_error("Area targeting regression")
	quit(0 if valid else 1)
