extends SceneTree
const Model = preload("res://scripts/systems/action_battle.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func fresh() -> RefCounted:
	var model := Model.new()
	model.setup(100, 20, 18, 4, {})
	for index: int in range(1, 6):
		model.actors[index].cooldown = 100.0
	return model

func advance(model: RefCounted, frames: int, movement: Vector2 = Vector2.ZERO) -> void:
	for frame: int in range(frames):
		model.step(1.0 / 60.0, movement)

func _run() -> void:
	var model: RefCounted = fresh()
	var start: Vector2 = model.actors[0].position
	advance(model, 60, Vector2.LEFT)
	check(model.actors[0].position.x == -8.0 and model.actors[0].position.y == start.y, "Movement must stop at arena boundary")
	model = fresh()
	model.actors[0].position = Vector2.ZERO
	model.actors[3].position = Vector2(1.4, 0)
	model.command("attack")
	check(int(model.actors[3].hp) == 64, "Attack must have a windup")
	advance(model, 13)
	check(int(model.actors[3].hp) == 49, "Spatial attack must hit once for attack minus armor")
	check(not model.command("attack"), "Cooldown must reject attack spam")
	model = fresh()
	model.actors[0].position = Vector2.ZERO
	model.actors[3].position = Vector2(-1.4, 0)
	model.command("attack")
	advance(model, 13)
	check(int(model.actors[3].hp) == 64, "Enemies behind the attack must not be hit")
	model = fresh()
	model.actors[0].position = Vector2.ZERO
	model.actors[3].position = Vector2(1.4, 0)
	model._start_attack(3, false)
	var aim: Vector2 = model.actors[3].aim
	advance(model, 40, Vector2.UP)
	check(model.actors[3].aim == aim, "Enemy warning must not track player after committing")
	advance(model, 15)
	check(int(model.actors[0].hp) == 100, "Walking out of warning must evade attack")
	model = fresh()
	model.actors[0].position = Vector2.ZERO
	model.actors[3].position = Vector2(1, 0)
	model._start_attack(3, false)
	model.actors[3].windup = 0.02
	check(model.command("dodge"), "Dodge must start")
	advance(model, 2)
	check(int(model.actors[0].hp) == 100, "Dodge invulnerability must block damage")
	check(not model.command("dodge"), "Dodge cannot be spammed")
	model = fresh()
	model.paused = true
	var snapshot: Array[Dictionary] = model.actors.duplicate(true)
	advance(model, 120, Vector2.RIGHT)
	check(model.actors == snapshot and not model.command("skill"), "Pause must freeze AI, movement, timers and commands")
	model.paused = false
	check(model.command("skill") and int(model.actors[0].mp) == 15, "Skill spends MP once")
	check(not model.command("skill") and int(model.actors[0].mp) == 15, "Rejected skill must not spend MP")
	model = fresh()
	model.actors[0].mp = 0
	check(not model.command("skill") and model.command("attack"), "Basic attack remains usable without MP")
	model = fresh()
	model.actors[1].hp = 0
	model.switch_actor()
	check(model.controlled == 2, "Switch must skip fallen companions")
	model.actors[2].hp = 0
	advance(model, 1)
	check(model.controlled == 0, "Death must transfer control to surviving ally")
	for index: int in [3, 4, 5]:
		model.actors[index].hp = 0
	advance(model, 1)
	check(model.winner == 0, "All enemies defeated must win")
	snapshot = model.actors.duplicate(true)
	advance(model, 60, Vector2.RIGHT)
	check(model.actors == snapshot and not model.command("attack"), "Resolved battle must stop simulation")
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	model = state.begin_action_battle({})
	check(not state.use_action_potion() and int(state.inventory.potion) == 2, "Full HP must not consume potion")
	model.actors[0].hp = 40
	check(state.use_action_potion() and int(state.inventory.potion) == 1 and state.player_hp == 75, "Potion must sync HP and inventory through GameState")
	check(not state.use_action_potion() and int(state.inventory.potion) == 1, "Potion cooldown prevents duplicate spending")
	state.set_mode(state.Mode.EXPLORE)
	check(state.battle_session == null, "Leaving combat clears transient state")
	if failures == 0:
		print("ACTION_BATTLE_TEST_PASS movement range windup dodge pause cooldown resources control victory")
	quit(0 if failures == 0 else 1)
