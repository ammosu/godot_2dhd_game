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
	_physical_weight()
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
		print("ACTION_BATTLE_TEST_PASS movement range windup dodge pause cooldown resources control victory hit_stop knockback rooting step_in dash_ease gait facing")
	quit(0 if failures == 0 else 1)

## Hit stop, decaying knockback, rooted swings, melee step-in, eased dodge,
## distance-driven ally gait and ally facing hysteresis.
func _physical_weight() -> void:
	var model: RefCounted = fresh()
	model.actors[0].position = Vector2.ZERO
	model.actors[3].position = Vector2(1.4, 0)
	model.command("attack")
	var before_step: Vector2 = model.actors[0].position
	var frames: int = 0
	while int(model.actors[3].hp) == 64 and frames < 30:
		advance(model, 1)
		frames += 1
	var victim: Dictionary = model.actors[3]
	var hero: Dictionary = model.actors[0]
	check(float(victim.hit_stop) > 0.0 and float(hero.hit_stop) > 0.0, "Melee contact must freeze victim and striker")
	check(Vector2(hero.position).x > before_step.x + 0.1 and Vector2(hero.position).x <= before_step.x + Model.STEP_IN_DISTANCE + 0.001, "Melee strike must carry a short step-in")
	var held_at: Vector2 = victim.position
	var held_hurt: float = float(victim.hurt)
	advance(model, 2)
	check(Vector2(victim.position) == held_at and float(victim.hurt) == held_hurt, "Hit stop must hold position and timers")
	while float(victim.hit_stop) > 0.0:
		advance(model, 1)
	var pushes: Array[float] = []
	for frame: int in range(20):
		var last: Vector2 = victim.position
		advance(model, 1)
		pushes.append(Vector2(victim.position).distance_to(last))
	check(pushes[0] > pushes[3] and pushes[3] > 0.0 and pushes[0] < 0.1, "Knockback must decay over several steps, not teleport")
	check(absf(Vector2(victim.position).x - held_at.x - 0.30) < 0.05, "Basic knockback keeps its ~0.30 m total push")
	# Swinging roots the feet; recovery only slows them.
	model = fresh()
	model.actors[0].position = Vector2.ZERO
	model.actors[0].swing = 0.1
	advance(model, 1, Vector2.DOWN)
	check(Vector2(model.actors[0].position).is_zero_approx(), "Controlled actor must not slide during swing")
	model.actors[0].swing = 0.0
	model.actors[0].recovery = 0.2
	advance(model, 1, Vector2.DOWN)
	check(is_equal_approx(Vector2(model.actors[0].position).y, 4.5 * Model.RECOVERY_MOVE_SCALE / 60.0), "Recovery halves walking speed")
	# Dodge bursts out and decelerates over the same distance.
	model = fresh()
	model.actors[0].position = Vector2.ZERO
	model.actors[0].facing = Vector2.DOWN
	model.command("dodge")
	var steps: Array[float] = []
	for frame: int in range(16):
		var last: Vector2 = model.actors[0].position
		advance(model, 1)
		steps.append(Vector2(model.actors[0].position).distance_to(last))
	check(steps[0] > steps[6] and steps[6] > steps[11], "Dodge speed must ease out")
	check(absf(Vector2(model.actors[0].position).y - Model.DASH_DISTANCE) < 0.01, "Dodge distance unchanged")
	# Ally walk frames follow distance, not the clock.
	var adapter: Node3D = load("res://scripts/gameplay/world_action_battle.gd").new()
	adapter.session = fresh()
	for index: int in range(6):
		adapter._gaits.append(0.0)
		adapter._still_time.append(0.0)
		adapter._facing_sectors.append(-1)
	for frame: int in range(60):
		adapter._advance_gait(1, "noah", 1.4 / 60.0, 1.0 / 60.0)
		adapter._advance_gait(2, "elder", 2.8 / 60.0, 1.0 / 60.0)
	check(absf(adapter._gaits[2] - adapter._gaits[1] * 2.0) < 0.01, "Walk cadence must scale with speed")
	check(absf(adapter._gaits[1] - 1.4 * 2.0 / adapter.WALK_STEP_LENGTH) < 0.01, "Two frames per step length")
	for frame: int in range(10):
		adapter._advance_gait(1, "noah", 0.0, 1.0 / 60.0)
	check(adapter._gaits[1] == 0.0, "Standing restarts the walk on a contact frame")
	# An AI ally steering along a sector edge keeps its facing column.
	var edge: float = PI / 8.0
	var first: Vector2 = adapter._steady_facing(1, Vector2.from_angle(edge - 0.05))
	var wobble: Vector2 = adapter._steady_facing(1, Vector2.from_angle(edge + 0.05))
	check(first.is_equal_approx(wobble), "Ally facing must not flicker across a sector edge")
	var turned: Vector2 = adapter._steady_facing(1, Vector2.from_angle(edge + adapter.FACING_HYSTERESIS + 0.05))
	check(not turned.is_equal_approx(first), "Ally facing turns once clearly past the edge")
	adapter.free()
