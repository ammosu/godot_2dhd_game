extends Node3D
## Optional overworld encounter. GameState owns progression, defeat flags and loot.
const IconButton = preload("res://scripts/ui/battle_icon_button.gd")
const HudTheme = preload("res://scripts/ui/presentation_theme.gd")
const Automation = preload("res://scripts/gameplay/field_auto_battle.gd")
const Terrain = preload("res://scripts/gameplay/field_terrain.gd")
const Awareness = preload("res://scripts/gameplay/enemy_awareness.gd")
const Navigation = preload("res://scripts/gameplay/field_navigation.gd")
const Art = preload("res://scripts/gameplay/action_sprite_library.gd")
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const Presentation = preload("res://scripts/gameplay/enemy_presentation.gd")
const HealthBar = preload("res://scripts/gameplay/world_health_bar.gd")
const Ring = preload("res://scripts/gameplay/combat_ground_ring.gd")
const DeathEffect = preload("res://scripts/gameplay/enemy_death_effect.gd")
const Effect = preload("res://scripts/gameplay/world_combat_effect.gd")
const HitFeedback = preload("res://scripts/gameplay/hit_feedback.gd")
const Allies = preload("res://scripts/gameplay/field_allies.gd")
const Director = preload("res://scripts/gameplay/field_combat_director.gd")
const TimeDilation = preload("res://scripts/systems/time_dilation.gd")
const WHEEL_SLOW: StringName = &"command_wheel"
const WHEEL_TIME_SCALE: float = 0.25
const SPAWNS: Array[Dictionary] = [
	{"id": "road_wolf_west", "at": Vector3(-4, 0.05, 10), "caster": false},
	{"id": "road_wolf_ramp", "at": Vector3(2, 0.41, 10.5), "caster": false, "elite": true},
	{"id": "road_mage_terrace", "at": Vector3(10, 1.85, 10.5), "caster": true},
	{"id": "road_bat_south", "at": Vector3(-5, 0.05, 12.5), "caster": false, "art": "dusk_bat"},
]
## Hero stance. RELAXED shows the player's own sheathed eight-way exploration
## sprite; DRAWN shows the four-way combat atlas. The weapon is drawn only while
## combat is engaged, and swaps hide behind a pose change.
const STANCE_RELAXED: StringName = &"relaxed"
const STANCE_DRAWN: StringName = &"drawn"
const SHEATHE_CALM_TIME: float = 2.5
const MIN_DRAWN_TIME: float = 1.5
const HURT_ALERT_TIME: float = 3.0
## Combat 'recover' pose held while drawing or sheathing from a standstill.
const STANCE_SWAP_POSE_TIME: float = 0.12
const STANCE_SWAP_MAX_SPEED: float = 0.5
## While walking, sheathe only at the start of a step (fraction of a step).
const SHEATHE_STEP_WINDOW: float = 0.25
## Drawn walk: one contact frame per step, advanced by ground covered.
const HERO_STEP_LENGTH: float = 0.5
const HERO_WALK_FPS_MAX: float = 12.0
const HERO_RECOVERY_TIME: float = 0.14
const HERO_HURT_TIME: float = 0.22
const HERO_SHIVER_TIME: float = 0.08
## Footing while an attack is committed: rooted in windup, nearly rooted in the
## swing, half speed while recovering. Dodge cancels all of these.
const WINDUP_MOVE_SCALE: float = 0.0
const SWING_MOVE_SCALE: float = 0.15
const RECOVERY_MOVE_SCALE: float = 0.5
## Momentum kept when an attack is committed from a run.
const ATTACK_PLANT_CARRY: float = 0.25
## Melee step-in during the last part of the windup, stopping short of the target.
const STEP_IN_DISTANCE: float = 0.35
const STEP_IN_TIME: float = 0.08
const STEP_IN_CONTACT_GAP: float = 0.75
## Dodge keeps its old distance but eases out from a fast push-off.
const DODGE_TIME: float = 0.22
const DODGE_DISTANCE: float = 2.2
const DODGE_EASE: float = 1.2
const DODGE_SWITCH: float = 0.4
## Enemy strike timing: the contact frame appears when damage lands.
const ENEMY_SWING_TIME: float = 0.14
const ENEMY_RECOVERY_TIME: float = 0.18
## Decaying knockback velocity (m/s) scaled by per-enemy weight.
const KNOCKBACK_BASIC: float = 2.2
const KNOCKBACK_SKILL: float = 3.5
const KNOCKBACK_DAMPING: float = 18.0
const KNOCKBACK_WEIGHT: Dictionary = {"dusk_bat": 1.3, "moss_wolf": 1.0, "eclipse_mage": 0.9}
const KNOCKBACK_ELITE_WEIGHT: float = 0.7
## Patrol wander around home, desynchronised per enemy.
const PATROL_RADIUS_MIN: float = 1.5
const PATROL_RADIUS_MAX: float = 3.0
const PATROL_IDLE_MIN: float = 1.2
const PATROL_IDLE_MAX: float = 3.5
const PATROL_ARRIVE: float = 0.3
const PATROL_SPEED: Dictionary = {"moss_wolf": 1.05, "eclipse_mage": 0.7, "dusk_bat": 1.4}
const RETURN_SPEED: float = 1.1
## Enemy locomotion smoothing (m/s^2), braking multiplier and turn rate (1/s).
const ENEMY_ACCEL: Dictionary = {"dusk_bat": 20.0, "ash_warden": 6.0}
const ENEMY_ACCEL_DEFAULT: float = 12.0
const ENEMY_BRAKE_FACTOR: float = 2.0
const ENEMY_TURN_RATE: float = 10.0
## Distance covered per displayed walk frame (a quarter of the two-step cycle).
const ENEMY_FRAME_DISTANCE: Dictionary = {"moss_wolf": 0.22, "guardian": 0.18, "eclipse_mage": 0.19, "ash_warden": 0.3}
const ENEMY_FRAME_DISTANCE_DEFAULT: float = 0.2
const ENEMY_WALK_FPS_MIN: float = 5.0
const ENEMY_WALK_FPS_MAX: float = 12.0
const ENEMY_WALK_MIN_SPEED: float = 0.15
var spawn_list: Array[Dictionary] = SPAWNS.duplicate(true)
var build_terrain: bool = true
var area_title: String = "舊道南側狩獵地"
var compact_hud: bool = false
var camera_distance: float = 15.0
var recovery_map: String = "village"
var recovery_spawn: String = "from_east_road"
var automation := Automation.new()
var allies := Allies.new()
var director := Director.new()
var _ward_marker: MeshInstance3D
var _auto_button: Button
var _auto_settings_button: Button
var _auto_options: PanelContainer
var _auto_controls: Control
var player: CharacterBody3D
var navigation := Navigation.new()
var enemies: Array[Dictionary] = []
var loot_nodes: Dictionary = {}
var ready_for_combat: bool = false
var clock: float = 0.0
var attack_cooldown: float = 0.0
var skill_cooldown: float = 0.0
var dodge_cooldown: float = 0.0
var dodge_time: float = 0.0
var invulnerable: float = 0.0
var windup: float = 0.0
var swing: float = 0.0
## Melee attacker freeze after a landed hit; ranged classes keep moving.
var hit_stop: float = 0.0
var skill_pending: bool = false
var skill_target: Dictionary = {}
var facing := Vector3.FORWARD
var _locomotion_requested: bool = false
var dodge_direction := Vector3.FORWARD
var attack_direction := Vector3.FORWARD
var _effects: Array[Node3D] = []
var _numbers: Array[Dictionary] = []

var _hero_outline: Sprite3D
var _last_target: Dictionary = {}
var _hero_sprite: Sprite3D
var _hud: Control
var _buttons: Dictionary[String, Button] = {}
var _command_row: HBoxContainer
var _command_buttons: Dictionary[String, Button] = {}
var _wheel: Control
var _wheel_buttons: Dictionary[String, Button] = {}
var _wheel_hint: Label
var _focus_paused: bool = false
var _previous_camera_distance: float = 11.0
var _rig: Hd2dCameraRig
var _initial_physics_frames: int = 0
var stance: StringName = STANCE_RELAXED
## Hero follow-through after a swing, shown with the 'recover' frame.
var recovery: float = 0.0
var _calm_time: float = 0.0
var _drawn_time: float = 0.0
var _last_hurt_clock: float = -INF
var _hero_hurt: float = 0.0
var _hero_flash: float = 0.0
var _stance_swap_left: float = 0.0
var _sheathe_left: float = 0.0
var _hero_gait: float = 0.0
var _gait_from := Vector3.INF
var _step_in_total: float = 0.0
var _location_labels: Array[Label3D] = []

func _process(_delta: float) -> void:
	_space_numbers()
	_update_hero_outline()

func _ready() -> void:
	process_priority = 35
	if build_terrain:
		Terrain.build(self)
	_rig = player.get_parent().get_node("CameraRig") as Hd2dCameraRig
	_previous_camera_distance = float(_rig.get("_distance"))
	_rig.set("_distance", camera_distance)
	player.set("field_combat", self)
	_hero_sprite = _sprite(player)
	_update_hero_art()
	_build_hud()
	if build_terrain:
		var sign := _label(self, "南側・舊道狩獵地\n坡道通往高台", Vector3(-2, 1.4, 7))
		sign.modulate = Color("d8e9c0")
		sign.add_to_group("field_location_labels")
		_location_labels.append(sign)
	get_window().focus_exited.connect(_pause_focus)
	get_window().focus_entered.connect(_resume_focus)
	_wait_for_physics.call_deferred()

# Wait two physics frames through a signal connection rather than `await`: the
# connection drops with this node, so leaving the map early cannot resume a freed instance.
func _wait_for_physics() -> void:
	if is_inside_tree():
		get_tree().physics_frame.connect(_on_initial_physics_frame)

func _on_initial_physics_frame() -> void:
	_initial_physics_frames += 1
	if _initial_physics_frames < 2:
		return
	get_tree().physics_frame.disconnect(_on_initial_physics_frame)
	if is_inside_tree():
		_initialize()

func _initialize() -> void:
	navigation.build(get_world_3d(), player)
	for spawn: Dictionary in spawn_list:
		if not GameState.field_defeated.has(spawn.id):
			_spawn_enemy(spawn)
	_sync_loot()
	ready_for_combat = true
	automation.set_enabled(true, self)
	_update_hud()

func _spawn_enemy(spawn: Dictionary) -> void:
	var art: String = str(spawn.get("art", "eclipse_mage" if spawn.caster else "moss_wolf"))
	var body := CharacterBody3D.new()
	body.name = spawn.id
	body.collision_layer = 2
	body.collision_mask = 1
	body.floor_snap_length = 0.35
	add_child(body)
	body.position = spawn.at
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.05
	collider.shape = capsule
	collider.position.y = 0.525
	body.add_child(collider)
	body.add_collision_exception_with(player)
	Grounding.add_shadow(body, 0.32)
	var sprite := _sprite(body)
	var bar := HealthBar.new()
	body.add_child(bar)
	bar.position.y = 1.85
	bar.configure(true, art)
	var label := _label(body, "", Vector3(0, 2.1, 0))
	var warning := Ring.new()
	warning.configure(1.15 if spawn.caster else 0.95, Color("ff795e"), 0.12)
	add_child(warning)
	warning.hide()
	var presentation := Presentation.new()
	body.add_child(presentation)
	presentation.setup(body, art, sprite, label, bar)
	bar.set_meta("field_layout", true)
	var bat: bool = art == "dusk_bat"
	# Fixed encounter tiers preserve the value of leveling and better equipment.
	var elite: bool = bool(spawn.get("elite", false))
	var hp: int = 100 if elite else 42 if bat else 54 if spawn.caster else 72
	# Seeded by id: each enemy wanders on its own rhythm, reproducibly.
	var wander := RandomNumberGenerator.new()
	wander.seed = hash(str(spawn.id))
	enemies.append({"id": spawn.id, "body": body, "sprite": sprite, "bar": bar, "label": label,
		"presentation": presentation, "warning": warning, "caster": spawn.caster, "art": art,
		"title": "苔原狼・精英" if elite else "暮翼蝙蝠・輕型" if bat else "月蝕術士・術法" if spawn.caster else "苔原狼・鬥士",
		"stagger_cooldown": 0.0, "attack_cycle": 0, "charged_attack": false,
		"basic_attacks": 3 if bat else 1 if elite else 2,
		"speed": 3.15 if bat else 1.9 if spawn.caster else 2.35, "attack_power": 14 if elite else 11 if bat else 18 if spawn.caster else 13,
		"attack_windup": 0.45 if bat else 0.65 if spawn.caster else 0.60 if elite else 0.55,
		"attack_interval": 1.1 if bat else 1.7 if spawn.caster else 1.25 if elite else 1.35, "hp": hp, "max_hp": hp,
		"last_seen": spawn.at, "lost_sight": 0.0, "target_visible": false,
		"home": spawn.at, "state": "patrol", "facing": Vector3.FORWARD, "hurt": 0.0,
		"cooldown": 0.7, "windup": 0.0, "hit_stop": 0.0, "flash": 0.0, "swing": 0.0, "aim": Vector3.ZERO,
		"path": PackedVector3Array(), "repath": 0.0, "patrol": 1.0,
		"recovery": 0.0, "gait": 0.0, "knock": Vector3.ZERO, "move_velocity": Vector3.ZERO,
		"weight": KNOCKBACK_ELITE_WEIGHT if elite else float(KNOCKBACK_WEIGHT.get(art, 1.0)),
		"patrol_speed": float(PATROL_SPEED.get(art, RETURN_SPEED)),
		"wander_target": spawn.at, "wander_wait": wander.randf_range(0.3, PATROL_IDLE_MAX), "wander": wander})

func movement_velocity(requested: Vector3, delta: float = 0.0, manual_facing: Vector3 = Vector3.ZERO) -> Vector3:
	_locomotion_requested = false
	if _focus_paused or hit_stop > 0.0:
		return Vector3.ZERO
	if not requested.is_zero_approx():
		automation.set_enabled(false, self)
	else:
		requested = automation.direction(self, delta) * player.move_speed
		manual_facing = Vector3.ZERO
	_locomotion_requested = not requested.is_zero_approx()
	if not requested.is_zero_approx():
		facing = manual_facing.normalized() if not manual_facing.is_zero_approx() else requested.normalized()
	if dodge_time > 0:
		return dodge_direction * dodge_speed(dodge_time)
	return requested * _committed_move_scale()

## Ease-out dodge: a fast push-off that slows into the landing. The integral over
## DODGE_TIME equals DODGE_DISTANCE.
static func dodge_speed(time_left: float) -> float:
	var peak: float = DODGE_DISTANCE * (DODGE_EASE + 1.0) / DODGE_TIME
	return peak * pow(clampf(time_left / DODGE_TIME, 0.0, 1.0), DODGE_EASE)

func _committed_move_scale() -> float:
	if windup > 0:
		return WINDUP_MOVE_SCALE
	if swing > 0:
		return SWING_MOVE_SCALE
	if recovery > 0:
		return RECOVERY_MOVE_SCALE
	return 1.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_released("command_wheel"):
		close_command_wheel()
	if event.is_echo() or GameState.mode != GameState.Mode.EXPLORE:
		return
	if event.is_action_pressed("command_wheel"):
		if open_command_wheel():
			get_viewport().set_input_as_handled()
		return
	for id: String in Allies.COMMANDS:
		if event.is_action_pressed("command_" + id):
			command_ally(id)
			get_viewport().set_input_as_handled()
			return
	var action: String = ""
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_B:
			automation.set_enabled(not automation.enabled, self)
			get_viewport().set_input_as_handled()
			return
		match event.physical_keycode:
			KEY_J: action = "attack"
			KEY_K: action = "skill"
			KEY_SHIFT: action = "dodge"
			KEY_H: action = "potion"
	if event.is_action_pressed("battle_attack"):
		action = "attack"
	elif event.is_action_pressed("battle_skill"):
		action = "skill"
	elif event.is_action_pressed("battle_potion"):
		action = "potion"
	if not action.is_empty():
		perform(action)
		get_viewport().set_input_as_handled()

func perform(action: String, automated: bool = false) -> bool:
	if not automated:
		automation.set_enabled(false, self)
	if not ready_for_combat or _focus_paused or GameState.mode != GameState.Mode.EXPLORE or GameState.player_hp <= 0:
		return false
	if action == "potion":
		return GameState.use_potion()
	if dodge_time > 0 or windup > 0:
		return false
	if action == "dodge":
		if dodge_cooldown > 0:
			return false
		dodge_direction = facing
		# Dodging always cancels the attacker's hit stop.
		hit_stop = 0.0
		recovery = 0.0
		_step_in_total = 0.0
		dodge_time = DODGE_TIME
		invulnerable = 0.30
		_draw_weapon(false)
		dodge_cooldown = float(GameState.class_profile().dodge)
		player.get("auto_walk").cancel()
		return true
	if action not in ["attack", "skill"] or attack_cooldown > 0:
		return false
	if action == "skill" and (skill_cooldown > 0 or GameState.player_mp < int(GameState.class_profile().cost)):
		return false
	skill_target = {}
	if action == "skill" and GameState.player_class == "thief":
		var nearest: float = 2.8
		for enemy: Dictionary in enemies:
			var at: Vector3 = enemy.body.global_position
			if int(enemy.hp) > 0 and player.global_position.distance_to(at) < nearest and can_hit(player.global_position, at, 2.8):
				nearest = player.global_position.distance_to(at)
				skill_target = enemy
		if skill_target.is_empty():
			if not automated:
				GameState.notification_requested.emit("影襲需要近距離、無障礙的目標")
			return false
		invulnerable = maxf(invulnerable, 0.25)
	player.get("auto_walk").cancel()
	skill_pending = action == "skill"
	if skill_pending:
		GameState.spend_mp(int(GameState.class_profile().cost))
		skill_cooldown = float(GameState.class_profile().cooldown)
	attack_cooldown = 0.55 if skill_pending else float(GameState.class_profile().interval)
	windup = 0.18 if skill_pending else 0.12
	recovery = 0.0
	# Plant the feet: most running momentum is spent entering the windup.
	player.velocity.x *= ATTACK_PLANT_CARRY
	player.velocity.z *= ATTACK_PLANT_CARRY
	attack_direction = facing
	var aim_reach: float = maxf(3.0, float(GameState.class_profile().reach))
	var closest: float = aim_reach
	for enemy: Dictionary in enemies:
		var at: Vector3 = enemy.body.global_position
		var distance: float = player.global_position.distance_to(at)
		if int(enemy.hp) > 0 and distance < closest and can_hit(player.global_position, at, aim_reach):
			closest = distance
			attack_direction = (at - player.global_position) * Vector3(1, 0, 1)
			attack_direction = attack_direction.normalized()
	if not skill_target.is_empty():
		attack_direction = ((skill_target.body.global_position - player.global_position) * Vector3(1, 0, 1)).normalized()
		closest = player.global_position.distance_to(skill_target.body.global_position)
	# Melee swings step into the blow, stopping short of the target's body.
	_step_in_total = 0.0 if bool(GameState.class_profile().ranged) else clampf(closest - STEP_IN_CONTACT_GAP, 0.0, STEP_IN_DISTANCE)
	_draw_weapon(false)
	if GameState.player_class == "archer":
		var projectile := Effect.new()
		add_child(projectile)
		projectile.configure("piercing_arrow" if skill_pending else "arrow", player.global_position, 0.45, Vector2(attack_direction.x, attack_direction.z), get_viewport().get_camera_3d())
		projectile.launch(player.global_position, player.global_position + attack_direction * float(GameState.class_profile().reach), windup)
		_effects.append(projectile)
	facing = attack_direction
	player.call("face_world_position", player.global_position + facing)
	return true

## Order a companion; a refusal explains itself once in the notice line.
func command_ally(id: String) -> bool:
	if not ready_for_combat or _focus_paused or GameState.mode != GameState.Mode.EXPLORE:
		return false
	var reason: String = allies.command_block(self, id)
	if not reason.is_empty():
		if Allies.find_follower(self, id) != null:
			GameState.notification_requested.emit(reason)
		return false
	var done: bool = allies.command(self, id)
	close_command_wheel()
	return done


func has_companions() -> bool:
	for id: String in Allies.COMMANDS:
		if Allies.find_follower(self, id) != null:
			return true
	return false


## Holding the wheel slows the fight so an order can be chosen calmly.
func open_command_wheel() -> bool:
	if not ready_for_combat or not has_companions() or not is_engaged() or GameState.mode != GameState.Mode.EXPLORE:
		return false
	_wheel.show()
	TimeDilation.request(WHEEL_SLOW, WHEEL_TIME_SCALE)
	_update_command_hud()
	return true


func close_command_wheel() -> void:
	if is_instance_valid(_wheel):
		_wheel.hide()
	TimeDilation.release(WHEEL_SLOW)


func is_command_wheel_open() -> bool:
	return is_instance_valid(_wheel) and _wheel.visible


func can_hit(from: Vector3, to: Vector3, reach: float) -> bool:
	if absf(from.y - to.y) > 0.7 or Vector2(from.x - to.x, from.z - to.z).length() > reach:
		return false
	var ray := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.7, to + Vector3.UP * 0.7, 1, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
	director.advance_real(delta)
	var active: bool = GameState.mode == GameState.Mode.EXPLORE and not _focus_paused
	_hud.visible = GameState.mode == GameState.Mode.EXPLORE
	_auto_controls.visible = _hud.visible
	_update_hud()
	_update_readability()
	if GameState.mode == GameState.Mode.CUTSCENE:
		_present_scripted_walk(delta)
		return
	if _is_relaxed_mode(GameState.mode):
		# Dialogue and transitions show the calm exploration sprite rather than
		# freezing the combat atlas mid-stride.
		_relax_now()
		_update_hero_art()
	if not ready_for_combat or not active:
		return
	clock += delta
	_rig.advance_combat_feedback(delta)
	# Hit stop holds the attacker's swing pose and footing; cooldowns keep
	# running so the freeze adds weight without adding input latency.
	var unheld: float = HitFeedback.after_stop(hit_stop, delta)
	hit_stop = maxf(0.0, hit_stop - delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	skill_cooldown = maxf(0, skill_cooldown - delta)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	dodge_time = maxf(0, dodge_time - delta)
	invulnerable = maxf(0, invulnerable - delta)
	_hero_hurt = maxf(0, _hero_hurt - delta)
	_hero_flash = maxf(0, _hero_flash - delta)
	var swinging: bool = swing > 0
	swing = maxf(0, swing - unheld)
	if swinging and swing == 0:
		recovery = HERO_RECOVERY_TIME
	else:
		recovery = maxf(0, recovery - unheld)
	if windup > 0:
		var before: float = windup
		windup = maxf(0, windup - delta)
		_advance_step_in(before, windup)
		if windup == 0:
			_strike()
	for enemy: Dictionary in enemies:
		enemy.slow = maxf(0.0, float(enemy.get("slow", 0.0)) - delta)
		_advance_enemy(enemy, delta)
		if GameState.mode != GameState.Mode.EXPLORE:
			return
	allies.step(self, delta)
	director.step(self, delta)
	_update_readability()
	for id: String in loot_nodes.keys():
		var node: Node3D = loot_nodes[id]
		if player.global_position.distance_to(node.position) < 1.1 and can_hit(player.global_position, node.position, 1.1):
			GameState.collect_field_loot(id)
			node.queue_free()
			loot_nodes.erase(id)
	for effect: Node3D in _effects:
		effect.advance(delta)
	_effects = _effects.filter(func(effect: Node3D) -> bool: return is_instance_valid(effect) and not effect.is_queued_for_deletion())
	for number: Dictionary in _numbers:
		number.life -= delta
		number.anchor.y += delta * 0.8
		number.node.modulate.a = clampf(float(number.life) * 2.0, 0.0, 1.0)
		if number.life <= 0:
			number.node.queue_free()
	_numbers = _numbers.filter(func(number: Dictionary) -> bool: return number.life > 0)
	_space_numbers()
	_advance_hero_gait(delta)
	_update_stance(delta)
	_update_hero_art()

## Cutscenes move the traveler directly. They always use the sheathed eight-way
## exploration walk; keep the combat heading in step for when play resumes.
func _present_scripted_walk(delta: float) -> void:
	clock += delta
	var planar := Vector3(player.velocity.x, 0.0, player.velocity.z)
	_locomotion_requested = planar.length() > 0.05
	if _locomotion_requested:
		facing = planar.normalized()
	elif player.has_meta("cutscene_facing"):
		facing = player.get_meta("cutscene_facing")
	_relax_now()
	_update_hero_art()

func _is_relaxed_mode(mode: int) -> bool:
	return mode in [GameState.Mode.DIALOGUE, GameState.Mode.TRANSITION, GameState.Mode.CLASS_SELECTION, GameState.Mode.CUTSCENE]

## Test and scripting hook: set the stance immediately, without a swap pose.
func force_stance(value: StringName) -> void:
	if value == STANCE_DRAWN:
		_draw_weapon(false)
		_drawn_time = MIN_DRAWN_TIME
	else:
		_relax_now()
	_update_hero_art()

func _relax_now() -> void:
	stance = STANCE_RELAXED
	_calm_time = 0.0
	_drawn_time = 0.0
	_stance_swap_left = 0.0
	_sheathe_left = 0.0

func _draw_weapon(hold_recover: bool) -> void:
	_calm_time = 0.0
	_sheathe_left = 0.0
	if stance == STANCE_DRAWN:
		return
	if hold_recover:
		_sync_idle_facing()
	stance = STANCE_DRAWN
	_drawn_time = 0.0
	# Actions draw on their own windup/dodge/hurt silhouette. An awareness draw
	# from a standstill shows the combat 'recover' frame to cover the swap.
	_stance_swap_left = STANCE_SWAP_POSE_TIME if hold_recover else 0.0

func _hero_planar_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()

## Combat is engaged: an action is in progress, the hero was hurt recently,
## an enemy is chasing, or auto-battle has a target in sight.
func _threatened() -> bool:
	if windup > 0 or swing > 0 or recovery > 0 or dodge_time > 0 or hit_stop > 0 or attack_cooldown > 0 or _hero_hurt > 0:
		return true
	if clock - _last_hurt_clock < HURT_ALERT_TIME:
		return true
	for enemy: Dictionary in enemies:
		if int(enemy.hp) <= 0:
			continue
		if enemy.state == "chase":
			return true
		if automation.enabled and player.global_position.distance_to(enemy.body.global_position) <= Awareness.SIGHT_RANGE:
			return true
	return false

func _update_stance(delta: float) -> void:
	_stance_swap_left = maxf(0.0, _stance_swap_left - delta)
	if stance == STANCE_DRAWN:
		_drawn_time += delta
	if _threatened():
		_draw_weapon(_hero_planar_speed() < STANCE_SWAP_MAX_SPEED)
		return
	if stance == STANCE_RELAXED:
		_sync_idle_facing()
		return
	_calm_time += delta
	if _sheathe_left > 0:
		_sheathe_left = maxf(0.0, _sheathe_left - delta)
		if _sheathe_left == 0.0:
			stance = STANCE_RELAXED
			_hand_heading_to_exploration()
		return
	if _calm_time < SHEATHE_CALM_TIME or _drawn_time < MIN_DRAWN_TIME:
		return
	if _hero_planar_speed() < STANCE_SWAP_MAX_SPEED:
		_sheathe_left = STANCE_SWAP_POSE_TIME
	elif fposmod(_hero_gait, 1.0) < SHEATHE_STEP_WINDOW:
		# Mid-walk, swap at a foot contact so the exploration stride continues.
		stance = STANCE_RELAXED
		_hand_heading_to_exploration()

## Standing turns (spawn, doors, dialogue partners) change only the exploration
## heading. Adopt it while sheathed so a draw keeps the hero's heading.
func _sync_idle_facing() -> void:
	if _locomotion_requested or not player.has_method("idle_world_heading"):
		return
	var heading: Vector3 = player.call("idle_world_heading")
	if not heading.is_zero_approx():
		facing = heading

## Sheathing from a standstill keeps the drawn heading on the exploration sprite.
func _hand_heading_to_exploration() -> void:
	if _locomotion_requested or _hero_planar_speed() > 0.05 or facing.is_zero_approx():
		return
	player.call("face_world_position", player.global_position + facing)

## Drawn steps follow ground covered, so feet do not slide at any speed.
func _advance_hero_gait(delta: float) -> void:
	var at: Vector3 = player.global_position
	var travelled: float = 0.0 if _gait_from == Vector3.INF else Vector2(at.x - _gait_from.x, at.z - _gait_from.z).length()
	_gait_from = at
	if not (_locomotion_requested and _hero_planar_speed() > 0.05) or travelled > 1.0:
		# Every start begins on a contact frame.
		_hero_gait = 0.0
		return
	_hero_gait += minf(travelled / HERO_STEP_LENGTH, HERO_WALK_FPS_MAX * delta)

## Melee step-in over the last STEP_IN_TIME of the windup, easing out.
func _advance_step_in(before: float, after: float) -> void:
	if _step_in_total <= 0.0:
		return
	var remaining := func(time_left: float) -> float:
		var t: float = clampf(time_left / STEP_IN_TIME, 0.0, 1.0)
		return _step_in_total * t * t
	var distance: float = remaining.call(before) - remaining.call(after)
	if after <= 0.0:
		_step_in_total = 0.0
	if distance > 0.0001:
		player.move_and_collide(attack_direction * Vector3(1, 0, 1) * distance)

func _update_hero_art() -> void:
	var exploration: Node3D = player.get_node("Sprite3D")
	if stance == STANCE_RELAXED:
		# The player's own sheathed eight-way walk; player.gd keeps it animated.
		_hero_sprite.hide()
		exploration.show()
		return
	# While drawn, keep one body atlas throughout locomotion and combat. The
	# exploration atlas has a different silhouette and cannot be swapped per hit.
	_hero_sprite.show()
	exploration.hide()
	# Braking can outlast a standing frame in the walk cycle. Once movement
	# ends, stay idle instead of flashing another stride during deceleration.
	var moving: bool = _locomotion_requested and _hero_planar_speed() > 0.05
	# Two frames per cycle: the blade changes side once per step, not twice.
	var pose: String = ("walk_a" if posmod(int(_hero_gait), 2) == 0 else "walk_b") if moving else "idle"
	if dodge_time > 0:
		pose = "dodge_a" if dodge_time > DODGE_TIME * (1.0 - DODGE_SWITCH) else "dodge_b"
	elif _hero_hurt > 0:
		pose = "hurt"
	elif windup > 0:
		pose = "cast" if GameState.player_class == "mage" else "windup"
	elif swing > 0:
		pose = "release" if GameState.player_class == "mage" else "attack"
	elif recovery > 0 or _stance_swap_left > 0 or _sheathe_left > 0:
		pose = "recover"
	_art(_hero_sprite, "wanderer", pose, facing)
	var shiver: Vector3 = HitFeedback.tremor(_hero_hurt - (HERO_HURT_TIME - HERO_SHIVER_TIME), get_viewport().get_camera_3d())
	_hero_sprite.position.x = shiver.x
	_hero_sprite.position.z = shiver.z
	HitFeedback.apply_flash(_hero_sprite, _hero_flash / HitFeedback.FLASH_TIME)

## A landed enemy hit: flinch, flash and draw the weapon.
func _hurt_hero() -> void:
	_hero_hurt = HERO_HURT_TIME
	_hero_flash = HitFeedback.FLASH_TIME
	_last_hurt_clock = clock
	if stance == STANCE_RELAXED:
		_sync_idle_facing()
	_draw_weapon(false)

func _strike() -> void:
	swing = 0.20
	if skill_pending:
		director.on_skill(self)
	var profile := GameState.class_profile()
	var ranged: bool = bool(profile.ranged)
	var radius: float = float(profile.reach) if ranged else 2.6 if skill_pending else 1.65
	var origin: Vector3 = player.global_position
	var aim: Vector3 = origin + attack_direction * radius
	var closest: float = radius + 0.01
	for enemy: Dictionary in enemies:
		var at: Vector3 = enemy.body.global_position
		var forward: float = attack_direction.dot(((at - origin) * Vector3(1, 0, 1)).normalized())
		if int(enemy.hp) > 0 and forward > 0.7 and can_hit(origin, at, radius) and origin.distance_to(at) < closest:
			closest = origin.distance_to(at)
			aim = at
	var effect: String = str(profile.effect) if skill_pending else "arrow" if GameState.player_class == "archer" else "bolt" if ranged else "slash"
	if GameState.player_class != "archer":
		_effect(effect, skill_target.body.global_position if not skill_target.is_empty() else aim if ranged else origin, float(profile.radius) if skill_pending else radius, attack_direction)
	GameAudio.play_cue(StringName(profile.cue) if skill_pending else &"spear_thrust" if GameState.player_class == "archer" else &"moon_bolt" if ranged else &"slash")
	var landed: bool = false
	for enemy: Dictionary in enemies:
		var at: Vector3 = enemy.body.global_position
		var offset: Vector3 = at - origin
		var forward: float = attack_direction.dot((offset * Vector3(1, 0, 1)).normalized())
		var hit_reach: float = radius if ranged else maxf(radius, _contact_spacing(enemy) + 0.3)
		var hit: bool = (skill_pending or forward >= 0.15) and can_hit(origin, at, hit_reach)
		if ranged:
			var target_distance: float = at.distance_to(aim)
			if GameState.player_class == "archer" and skill_pending:
				target_distance = at.distance_to(Geometry3D.get_closest_point_to_segment(at, origin, origin + attack_direction * radius))
			hit = target_distance <= (2.2 if GameState.player_class == "mage" and skill_pending else 0.6) and can_hit(origin, at, radius)
		if skill_pending and GameState.player_class == "thief":
			hit = enemy == skill_target and can_hit(origin, at, 2.8)
		if int(enemy.hp) > 0 and hit:
			var damage: int = GameState.player_attack + (int(profile.power) if skill_pending else 0)
			if skill_pending and GameState.player_class == "traveler":
				damage = GameState.player_attack * 2
			if skill_pending and GameState.player_class == "thief":
				var behind: bool = Vector3(enemy.facing).dot(((origin - at) * Vector3(1, 0, 1)).normalized()) < -0.35
				if behind:
					damage *= 2
			if skill_pending and GameState.player_class == "mage":
				enemy.slow = 3.0
				var chill := _effect("chill", at, 0.6)
				chill.follow_target = enemy.body
			_damage_enemy(enemy, damage)
			landed = true
	# One impact per swing, however many targets an area skill catches.
	if landed:
		GameAudio.play_cue(HitFeedback.impact_cue(GameState.player_class), HitFeedback.impact_pitch())

## A companion's blow: same damage rules, pushed away from the companion and
## without freezing the traveler's own swing.
func ally_hit(enemy: Dictionary, damage: int, source: Vector3) -> void:
	_damage_enemy(enemy, damage, source)


func _damage_enemy(enemy: Dictionary, damage: int, source: Vector3 = Vector3.INF) -> void:
	if int(enemy.hp) <= 0:
		return
	var from_ally: bool = source.is_finite()
	if not from_ally:
		_last_target = enemy
	var skill: bool = skill_pending and not from_ally
	Awareness.engage(self, enemy)
	enemy.hp = maxi(0, int(enemy.hp) - damage)
	enemy.hurt = 0.25
	# The blow interrupts the stride and pushes the body away from the hero;
	# the push plays out after the hit stop.
	enemy.move_velocity = Vector3.ZERO
	var away: Vector3 = (enemy.body.global_position - (source if from_ally else player.global_position)) * Vector3(1, 0, 1)
	if not away.is_zero_approx():
		enemy.knock = away.normalized() * (KNOCKBACK_SKILL if skill else KNOCKBACK_BASIC) * float(enemy.get("weight", 1.0))
	var lethal: bool = int(enemy.hp) == 0
	var stop: float = HitFeedback.stop_time(damage, int(enemy.max_hp), skill, lethal)
	enemy.hit_stop = maxf(float(enemy.get("hit_stop", 0.0)), stop)
	enemy.flash = HitFeedback.FLASH_TIME
	if not from_ally and not bool(GameState.class_profile().ranged):
		hit_stop = maxf(hit_stop, stop)
	_rig.add_combat_impact(HitFeedback.shake_strength(damage, int(enemy.max_hp), skill, lethal))
	# Light enemies stagger to basic hits; fighters/casters require a skill.
	# Recovery also prevents fast attacks from permanently suppressing a bat.
	var interrupt: bool = (enemy.art == "dusk_bat" or skill) and float(enemy.get("stagger_cooldown", 0.0)) <= 0.0
	if interrupt and float(enemy.windup) > 0.0:
		enemy.windup = 0.0
		enemy.warning.hide()
		enemy.stagger_cooldown = 1.5
		if bool(enemy.get("charged_attack", false)):
			enemy.attack_cycle = 0
		enemy.cooldown = maxf(float(enemy.cooldown), 0.55)
	_number(enemy.body.global_position, ("槍 %d" % damage) if from_ally else str(damage), Color("9fd4ff") if from_ally else Color("fff0ad"), &"noah" if from_ally else &"hero")
	var hit_effect: String = "impact" if from_ally else "arrow_hit" if GameState.player_class == "archer" else "frost_hit" if GameState.player_class == "mage" else "shadow_hit" if GameState.player_class == "thief" else "impact"
	_effect(hit_effect, enemy.body.global_position)
	if int(enemy.hp) == 0:
		enemy.state = "dead"
		enemy.windup = 0.0
		enemy.warning.hide()
		var death := DeathEffect.new()
		add_child(death)
		death.configure(enemy.body, enemy.sprite, player)
		_effects.append(death)
		GameState.defeat_field_enemy(enemy.id, enemy.body.global_position, enemy.caster)
		_sync_loot()
		director.on_enemy_defeated(self, enemy)

func _advance_enemy(enemy: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = enemy.body
	enemy.flash = maxf(0.0, float(enemy.get("flash", 0.0)) - delta)
	if int(enemy.hp) > 0 and float(enemy.get("hit_stop", 0.0)) > 0.0:
		var unheld: float = HitFeedback.after_stop(float(enemy.hit_stop), delta)
		enemy.hit_stop = maxf(0.0, float(enemy.hit_stop) - delta)
		if unheld <= 0.0:
			_hold_enemy(enemy)
			return
		delta = unheld
	var at: Vector3 = body.global_position
	enemy.stagger_cooldown = maxf(0.0, float(enemy.get("stagger_cooldown", 0.0)) - delta)
	enemy.hurt = maxf(0, float(enemy.hurt) - delta)
	var swinging: bool = float(enemy.swing) > 0
	enemy.swing = maxf(0, float(enemy.swing) - delta)
	if swinging and float(enemy.swing) == 0:
		enemy.recovery = ENEMY_RECOVERY_TIME
	else:
		enemy.recovery = maxf(0, float(enemy.get("recovery", 0.0)) - delta)
	enemy.cooldown = maxf(0, float(enemy.cooldown) - delta)
	enemy.bar.set_health(enemy.hp, enemy.max_hp)
	if int(enemy.hp) <= 0:
		_art(enemy.sprite, enemy.art, "defeated", enemy.facing)
		enemy.presentation.advance(clock, "defeated", 0.0, 0.0, 0.0)
		enemy.sprite.position.x = 0.0
		enemy.sprite.position.z = 0.0
		HitFeedback.apply_flash(enemy.sprite, 0.0)
		enemy.label.hide()
		return
	Awareness.update(self, enemy, delta)
	enemy.taunt = maxf(0.0, float(enemy.get("taunt", 0.0)) - delta)
	var movement := Vector3.ZERO
	# Strike and follow-through root the feet; a new attack may still start.
	var committed: bool = float(enemy.swing) > 0 or float(enemy.recovery) > 0
	if float(enemy.windup) > 0:
		enemy.windup = maxf(0, float(enemy.windup) - delta)
		if float(enemy.windup) == 0:
			_enemy_strike(enemy)
	elif float(enemy.hurt) == 0:
		var target: Vector3 = enemy.home
		if enemy.state == "chase":
			# A companion's taunt overrides the traveler as the quarry.
			var taunted: Vector3 = Allies.taunt_target(enemy)
			target = taunted if taunted.is_finite() else enemy.last_seen
			var reach: float = 4.8 if enemy.caster else maxf(1.85 if enemy.art == "dusk_bat" else 1.35, _contact_spacing(enemy) + 0.3)
			var approach: Vector3 = _approach_position(enemy, target)
			var in_lane: bool = enemy.caster or at.distance_to(approach) < 0.35
			var sighted: bool = enemy.target_visible or taunted.is_finite()
			if sighted and in_lane and can_hit(at, target, reach):
				if float(enemy.cooldown) == 0:
					enemy.aim = target
					enemy.facing = (target - at).normalized()
					enemy.charged_attack = int(enemy.attack_cycle) == int(enemy.basic_attacks)
					enemy.windup = float(enemy.attack_windup) if enemy.charged_attack else 0.22 if enemy.caster else 0.16
					enemy.cooldown = float(enemy.attack_interval) * (1.2 if enemy.charged_attack else 0.85)
					enemy.recovery = 0.0
					enemy.warning.position = enemy.aim + Vector3.UP * 0.04
					enemy.warning.visible = enemy.charged_attack
				target = at
			elif not enemy.caster and sighted:
				target = approach
		elif enemy.state == "return":
			if at.distance_to(target) < 0.5:
				enemy.state = "patrol"
				enemy.hp = enemy.max_hp
				enemy.attack_cycle = 0
				enemy.charged_attack = false
				# Settle at home for a moment before wandering again.
				enemy.wander_target = at
				enemy.wander_wait = (enemy.wander as RandomNumberGenerator).randf_range(PATROL_IDLE_MIN, PATROL_IDLE_MAX)
		else:
			target = _patrol_target(enemy, at, delta)
		if not committed and at.distance_to(target) > 0.25:
			enemy.repath -= delta
			if float(enemy.repath) <= 0:
				enemy.path = navigation.path(at, target)
				enemy.repath = 0.35
				# The nearest grid node can lie behind the body; do not turn back for it.
				var fresh: PackedVector3Array = enemy.path
				if fresh.size() > 1 and ((fresh[0] - at) * Vector3(1, 0, 1)).dot((fresh[1] - fresh[0]) * Vector3(1, 0, 1)) < 0.0:
					fresh.remove_at(0)
					enemy.path = fresh
			var path: PackedVector3Array = enemy.path
			while not path.is_empty() and Vector2(path[0].x - at.x, path[0].z - at.z).length() < 0.22:
				path.remove_at(0)
			enemy.path = path
			if not path.is_empty():
				movement = ((path[0] - at) * Vector3(1, 0, 1)).normalized()
	var slow_factor: float = 0.5 if float(enemy.get("slow", 0.0)) > 0 else 1.0
	var speed: float = float(enemy.speed) if enemy.state == "chase" else float(enemy.get("patrol_speed", RETURN_SPEED)) if enemy.state == "patrol" else RETURN_SPEED
	var desired: Vector3 = movement * slow_factor * speed
	if enemy.state == "chase" and not enemy.caster and not committed and float(enemy.windup) <= 0.0 and float(enemy.hurt) <= 0.0:
		desired = _separate_enemy_velocity(enemy, desired)
	var planar: Vector3 = _smooth_enemy_velocity(enemy, desired, delta)
	var push: Vector3 = _consume_knock(enemy, delta)
	body.velocity.x = planar.x + push.x
	body.velocity.z = planar.z + push.z
	body.velocity.y = -0.5 if body.is_on_floor() else body.velocity.y - 18.0 * delta
	body.move_and_slide()
	var travelled: float = Vector2(body.global_position.x - at.x, body.global_position.z - at.z).length()
	if not movement.is_zero_approx():
		enemy.facing = turn_toward(enemy.facing, movement, 1.0 - exp(-ENEMY_TURN_RATE * delta))
	var walking: bool = push.is_zero_approx() and travelled > ENEMY_WALK_MIN_SPEED * delta
	_advance_gait(enemy, travelled, delta, walking)
	var pose: String = "hurt" if float(enemy.hurt) > 0 else ("cast" if enemy.caster else "windup") if float(enemy.windup) > 0 else "attack" if float(enemy.swing) > 0 else "recover" if float(enemy.recovery) > 0 else Art.Movement.walk_pose(float(enemy.gait) / 10.0) if walking else "idle"
	if enemy.art == "dusk_bat" and pose in ["idle", "walk_a", "walk_b"]:
		# Wings keep a steady flap whatever the ground speed.
		pose = Art.Movement.walk_pose(clock + float(enemy.home.x) * 0.17 + float(enemy.home.z) * 0.11)
	_art(enemy.sprite, enemy.art, pose, enemy.facing)
	enemy.presentation.advance(clock, pose, float(enemy.hurt), float(enemy.windup), float(enemy.swing))
	enemy.sprite.position.x = 0.0
	enemy.sprite.position.z = 0.0
	HitFeedback.apply_flash(enemy.sprite, float(enemy.flash) / HitFeedback.FLASH_TIME)
	enemy.label.text = str(enemy.title) + ("  !" if enemy.state == "chase" else "  ↩" if enemy.state == "return" else "")

## Stable slots on both sides of the traveler prevent a single pursuit pile.
func _approach_position(enemy: Dictionary, center: Vector3) -> Vector3:
	var index: int = maxi(0, enemies.find(enemy))
	var angles: Array[float] = [-60.0, 60.0, -120.0, 120.0, -90.0, 90.0]
	var radius: float = maxf(1.6 if enemy.art == "dusk_bat" else 1.1, _contact_spacing(enemy))
	var goal: Vector3 = center + Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(angles[index % angles.size()])) * radius
	return goal if navigation.contains(goal) else center

## Keep melee approach lanes apart, including when two bodies start coincident.
func _separate_enemy_velocity(enemy: Dictionary, desired: Vector3) -> Vector3:
	var result: Vector3 = desired
	for other: Dictionary in enemies:
		if other.body == enemy.body or int(other.hp) <= 0:
			continue
		var away: Vector3 = (enemy.body.global_position - other.body.global_position) * Vector3(1, 0, 1)
		var distance: float = away.length()
		var spacing: float = maxf(1.1, (_sprite_width(enemy.sprite) + _sprite_width(other.sprite)) * 0.5 + 0.12)
		if distance >= spacing + 0.25:
			continue
		var direction: Vector3 = away / distance if distance > 0.001 else Vector3.RIGHT * (1.0 if enemy.body.get_instance_id() > other.body.get_instance_id() else -1.0)
		# Remove inward motion before applying a soft outward correction.
		result -= direction * minf(result.dot(direction), 0.0)
		result += direction * maxf(0.0, spacing + 0.05 - distance) * 6.0
	var hero_away: Vector3 = (enemy.body.global_position - player.global_position) * Vector3(1, 0, 1)
	var gap: float = _contact_spacing(enemy)
	if hero_away.length() < gap:
		var direction: Vector3 = hero_away.normalized() if not hero_away.is_zero_approx() else Vector3.RIGHT
		result -= direction * minf(result.dot(direction), 0.0)
		result += direction * (gap - hero_away.length()) * 6.0
	return result.limit_length(maxf(desired.length(), 2.0))


## Wander a few metres around home, pausing between walks.
func _patrol_target(enemy: Dictionary, at: Vector3, delta: float) -> Vector3:
	var goal: Vector3 = enemy.get("wander_target", enemy.home)
	if Vector2(goal.x - at.x, goal.z - at.z).length() > PATROL_ARRIVE:
		return goal
	enemy.wander_wait = float(enemy.get("wander_wait", 0.0)) - delta
	if float(enemy.wander_wait) > 0.0:
		return at
	var rng: RandomNumberGenerator = enemy.wander
	enemy.wander_wait = rng.randf_range(PATROL_IDLE_MIN, PATROL_IDLE_MAX)
	var home: Vector3 = enemy.home
	for attempt: int in range(6):
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(PATROL_RADIUS_MIN, PATROL_RADIUS_MAX)
		var point: Vector3 = home + Vector3(cos(angle), 0, sin(angle)) * radius
		if not navigation.contains(point):
			continue
		var route: PackedVector3Array = navigation.path(at, point)
		if route.is_empty():
			continue
		var end: Vector3 = route[route.size() - 1]
		var length: float = 0.0
		for index: int in range(1, route.size()):
			length += route[index - 1].distance_to(route[index])
		# Reject points on another level or behind a wall (long detours).
		if Vector2(end.x - point.x, end.z - point.z).length() > 0.5 or length > (radius + at.distance_to(home)) * 1.6 + 0.5:
			continue
		enemy.wander_target = end
		return end
	enemy.wander_target = home
	return home

func _smooth_enemy_velocity(enemy: Dictionary, desired: Vector3, delta: float) -> Vector3:
	var current: Vector3 = enemy.get("move_velocity", Vector3.ZERO)
	var accel: float = float(ENEMY_ACCEL.get(str(enemy.art), ENEMY_ACCEL_DEFAULT))
	if desired.length() < current.length():
		accel *= ENEMY_BRAKE_FACTOR
	current = current.move_toward(desired, accel * delta)
	enemy.move_velocity = current
	return current

## Exact displacement of a linearly damped push over this step, as a velocity.
func _consume_knock(enemy: Dictionary, delta: float) -> Vector3:
	var knock: Vector3 = enemy.get("knock", Vector3.ZERO)
	var speed: float = knock.length()
	if speed <= 0.001 or delta <= 0.0:
		enemy.knock = Vector3.ZERO
		return Vector3.ZERO
	var left: float = maxf(0.0, speed - KNOCKBACK_DAMPING * delta)
	var distance: float = (speed + left) * 0.5 * minf(delta, speed / KNOCKBACK_DAMPING)
	enemy.knock = knock / speed * left
	return knock / speed * (distance / delta)

## Walk frames advance with ground covered; every start is a contact frame.
func _advance_gait(enemy: Dictionary, travelled: float, delta: float, walking: bool) -> void:
	if not walking:
		enemy.gait = 0.0
		return
	var frames: float = travelled / float(ENEMY_FRAME_DISTANCE.get(str(enemy.art), ENEMY_FRAME_DISTANCE_DEFAULT))
	enemy.gait = float(enemy.get("gait", 0.0)) + clampf(frames, ENEMY_WALK_FPS_MIN * delta, ENEMY_WALK_FPS_MAX * delta)

## Planar heading turn that also handles exact reversals.
static func turn_toward(current: Vector3, target: Vector3, weight: float) -> Vector3:
	if Vector2(current.x, current.z).is_zero_approx():
		return (target * Vector3(1, 0, 1)).normalized()
	var angle: float = lerp_angle(atan2(current.x, current.z), atan2(target.x, target.z), clampf(weight, 0.0, 1.0))
	return Vector3(sin(angle), 0.0, cos(angle))

## Frozen on contact: hold the hurt pose, flash white and shiver in place.
func _hold_enemy(enemy: Dictionary, tremor_scale: float = 1.0) -> void:
	var body: CharacterBody3D = enemy.body
	body.velocity = Vector3.ZERO
	enemy.bar.set_health(enemy.hp, enemy.max_hp)
	_art(enemy.sprite, enemy.art, "hurt", enemy.facing)
	enemy.presentation.advance(clock, "hurt", float(enemy.hurt), 0.0, 0.0)
	var shiver: Vector3 = HitFeedback.tremor(float(enemy.hit_stop), get_viewport().get_camera_3d()) * tremor_scale
	enemy.sprite.position.x = shiver.x
	enemy.sprite.position.z = shiver.z
	HitFeedback.apply_flash(enemy.sprite, float(enemy.flash) / HitFeedback.FLASH_TIME)

func _enemy_strike(enemy: Dictionary) -> void:
	enemy.warning.hide()
	enemy.swing = ENEMY_SWING_TIME
	# Count released attacks even when dodged; interrupted basics do not count.
	enemy.attack_cycle = (int(enemy.attack_cycle) + 1) % (int(enemy.basic_attacks) + 1)
	_effect("bolt" if enemy.caster else "claw", enemy.aim)
	var reach: float = 5.2 if enemy.caster else maxf(1.8, _contact_spacing(enemy) + 0.4)
	var radius: float = 1.15 if enemy.caster else 0.95
	var taunter: Variant = enemy.get("taunt_by")
	if Allies.taunt_target(enemy).is_finite() and (taunter as Node3D).global_position.distance_to(enemy.aim) < radius + 0.3:
		allies.ally_struck(self, taunter as Node3D)
	if invulnerable <= 0 and can_hit(enemy.body.global_position, player.global_position, reach) and player.global_position.distance_to(enemy.aim) < radius:
		var power: int = int(enemy.attack_power) if enemy.charged_attack else roundi(float(enemy.attack_power) * 0.75)
		var damage: int = allies.incoming_damage(maxi(1, power - GameState.player_defense))
		GameState.damage_player(damage)
		invulnerable = 0.45
		_hurt_hero()
		GameAudio.play_cue(&"impact", HitFeedback.impact_pitch() * 0.85)
		_rig.add_combat_impact(0.08 if enemy.charged_attack else 0.05)
		_number(player.global_position, "−%d" % damage, Color("ff9985"))
		if GameState.player_hp == 0:
			GameState.restore_after_defeat()
			automation.set_enabled(false, self)
			GameState.set_mode(GameState.Mode.TRANSITION)
			_recover.call_deferred()

func _recover() -> void:
	GameState.set_mode(GameState.Mode.EXPLORE)
	GameState.request_map(recovery_map, recovery_spawn)
	GameState.notification_requested.emit("在安全地帶醒來・已恢復體力，獲得的經驗與物品保留")

func _sync_loot() -> void:
	var local_ids: Array[String] = []
	for spawn: Dictionary in spawn_list:
		local_ids.append(str(spawn.id))
	for id: String in GameState.field_loot:
		if id not in local_ids:
			continue
		if loot_nodes.has(id):
			continue
		var data: Dictionary = GameState.field_loot[id]
		var at: Array = data.position
		var node := Node3D.new()
		add_child(node)
		node.position = Vector3(float(at[0]), float(at[1]), float(at[2]))
		var ring := Ring.new()
		ring.configure(0.38, Color("ffe0a0"), 0.10)
		node.add_child(ring)
		ring.position.y = 0.07
		var gem := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.24, 0.36, 0.24)
		gem.mesh = mesh
		gem.position.y = 0.3
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("9be6d1") if data.item == "moon_moss" else Color("eead92")
		gem.material_override = material
		node.add_child(gem)
		_label(node, "月苔" if data.item == "moon_moss" else "藥水", Vector3(0, 0.75, 0))
		loot_nodes[id] = node

func _sprite(parent: Node3D) -> Sprite3D:
	var sprite := Sprite3D.new()
	# Allies and enemies stand in the same vertical plane as the player.
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.3
	parent.add_child(sprite)
	return sprite

func _art(sprite: Sprite3D, actor: String, pose: String, direction: Vector3) -> void:
	var screen: Vector2 = Facing.screen_direction(direction, get_viewport().get_camera_3d())
	var column: int = Art.direction(screen)
	var texture: AtlasTexture = Art.directional_texture(actor, pose, screen, sprite, GameState.get_visual_loadout() if actor == "wanderer" else {})
	sprite.texture = texture
	sprite.pixel_size = float(texture.get_meta("pixel_size"))
	sprite.scale.x = float(texture.get_meta("width_scale", 1.0))
	if actor == "wanderer":
		var standing: AtlasTexture = Art.texture_for(actor, "idle", column, GameState.get_visual_loadout())
		sprite.pixel_size = float(player.call("presentation_height")) / float(texture.get_meta("body_height", standing.get_height()))
	Grounding.anchor(sprite, texture, float(texture.get_meta("ground_y")))
	sprite.offset.x = texture.get_width() * 0.5 - float(texture.get_meta("anchor_x"))
	sprite.flip_h = bool(texture.get_meta("flip_h", false))
	if sprite.flip_h:
		sprite.offset.x *= -1
	if actor == "wanderer":
		GameState.HeroStyle.apply_sprite(sprite, texture, GameState.player_style)

func _label(parent: Node3D, text: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.font = GameState.ui_theme.default_font
	label.text = text
	label.font_size = 32
	label.pixel_size = 0.008
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	parent.add_child(label)
	return label

## Screen-relative lanes stay readable when the camera rotates.
func _number(at: Vector3, text: String, color: Color, source: StringName = &"hero") -> void:
	var camera := get_viewport().get_camera_3d()
	var right: Vector3 = camera.global_basis.x if camera != null else Vector3.RIGHT
	var lane: float = -0.7 if source == &"noah" else 0.7 if source == &"sia" else 0.0
	var stack: int = 0
	for number: Dictionary in _numbers:
		if Vector3(number.origin).distance_to(at) < 0.8:
			stack += 1
	var label := _label(self, text, at + right * lane + Vector3.UP * (1.5 + (stack % 4) * 0.24))
	label.modulate = color
	_numbers.append({"node": label, "life": 0.8, "origin": at, "anchor": label.position})
	_space_numbers()

## Resolve projected collisions oldest first, including after camera movement.
func _space_numbers() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var bars: Array[Node] = []
	for enemy: Dictionary in enemies:
		bars.append(enemy.bar)
	# Resolve the target last: its name remains directly above the highest bar
	# in an overlapping cluster, instead of drifting above unrelated labels.
	for enemy: Dictionary in enemies:
		if enemy.label.visible:
			bars.erase(enemy.bar)
			bars.append(enemy.bar)
	var occupied: Array[Rect2] = HealthBar.space_bars(bars, camera)
	for enemy: Dictionary in enemies:
		HealthBar.attach_name(enemy.label, enemy.bar, camera, occupied)
		var status := enemy.get("slow_label") as Label3D
		if is_instance_valid(status) and status.visible:
			status.global_position = enemy.bar.global_position + Vector3.UP * 0.35
			HealthBar.space_label(status, camera, occupied)
	for number: Dictionary in _numbers:
		var label: Label3D = number.node
		if number.life <= 0.0:
			continue
		label.position = number.anchor
		HealthBar.space_label(label, camera, occupied)


func has_nearby_enemy(radius: float) -> bool:
	for enemy: Dictionary in enemies:
		if int(enemy.hp) > 0 and player.global_position.distance_to(enemy.body.global_position) <= radius:
			return true
	return false


func is_engaged() -> bool:
	return not allies._engaged(self).is_empty()

func _update_readability() -> void:
	_update_status_markers()
	var engaged: bool = is_engaged()
	for label: Label3D in _location_labels:
		label.visible = not engaged
	var nearest: Dictionary = {}
	var distance: float = INF
	for enemy: Dictionary in enemies:
		if int(enemy.hp) <= 0:
			continue
		var candidate: float = player.global_position.distance_squared_to(enemy.body.global_position)
		if candidate < distance:
			nearest = enemy
			distance = candidate
	if not _last_target.is_empty() and int(_last_target.hp) > 0 and player.global_position.distance_to(_last_target.body.global_position) < 8.0:
		nearest = _last_target
	for enemy: Dictionary in enemies:
		enemy.label.visible = GameState.mode == GameState.Mode.EXPLORE and enemy == nearest and int(enemy.hp) > 0

## Status marks follow the authoritative timers, including refreshes and death.
func _update_status_markers() -> void:
	var show_marks: bool = GameState.mode == GameState.Mode.EXPLORE
	for enemy: Dictionary in enemies:
		var marker := enemy.get("slow_marker") as MeshInstance3D
		var slowed: bool = int(enemy.hp) > 0 and float(enemy.get("slow", 0.0)) > 0.0
		if slowed and not is_instance_valid(marker):
			marker = _status_marker(0.48, Color("ffe0a0"))
			enemy.slow_marker = marker
		var status := enemy.get("slow_label") as Label3D
		if slowed and not is_instance_valid(status):
			status = _label(enemy.body, "緩", Vector3.UP * 2.15)
			status.font_size = 28
			status.pixel_size = 0.006
			status.modulate = Color("ffe0a0")
			status.no_depth_test = true
			status.render_priority = 13
			enemy.slow_label = status
		if is_instance_valid(status):
			status.visible = slowed and show_marks
		if is_instance_valid(marker):
			marker.visible = slowed and show_marks
			marker.global_position = enemy.body.global_position + Vector3.UP * 0.035
	if allies.ward_time > 0.0 and not is_instance_valid(_ward_marker):
		_ward_marker = _status_marker(0.62, Color(0.62, 0.83, 1.0, 0.55))
	if is_instance_valid(_ward_marker):
		_ward_marker.visible = allies.ward_time > 0.0 and show_marks
		_ward_marker.global_position = player.global_position + Vector3.UP * 0.035


func _status_marker(radius: float, color: Color) -> MeshInstance3D:
	var marker := preload("res://scripts/gameplay/combat_ground_ring.gd").new()
	marker.configure(radius, color, 0.045)
	add_child(marker)
	return marker


func _effect(kind: String, at: Vector3, radius: float = 1, direction: Vector3 = Vector3.FORWARD) -> Node3D:
	var effect := Effect.new()
	add_child(effect)
	effect.configure(kind, at + Vector3.UP * 0.05, radius, Vector2(direction.x, direction.z), get_viewport().get_camera_3d())
	_effects.append(effect)
	return effect

func get_hud_rect() -> Rect2:
	return _hud.get_global_rect()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	var mobile: bool = MobileControls.is_mobile_device()
	var row := HBoxContainer.new()
	_hud = row
	_hud.theme = GameState.ui_theme
	layer.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hud.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.offset_left = -172
	_hud.offset_right = 172
	_hud.offset_top = -104
	_hud.offset_bottom = -24
	if mobile:
		# Leave the joystick, auto toggle and interaction button separate.
		_hud.anchor_left = 0.0
		_hud.anchor_right = 1.0
		_hud.offset_left = 366
		_hud.offset_right = -204
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for action: String in ["attack", "skill", "dodge", "potion"]:
		var button := IconButton.new()
		button.custom_minimum_size = Vector2(80, 80)
		button.caption = {"attack": "普攻", "skill": "技能", "dodge": "閃避", "potion": "藥水"}[action]
		button.hotkey = {"attack": "J", "skill": "K", "dodge": "Shift", "potion": "H"}[action]
		button.accent = Color("e9c47f") if action == "attack" else Color("9feaff") if action == "skill" else Color("9ee6bd") if action == "potion" else Color("bbc9df")
		button.pressed.connect(func() -> void: perform(action))
		row.add_child(button)
		button.add_to_group("camera_touch_blocker")
		_buttons[action] = button

	_build_command_hud(layer, mobile)

	_auto_controls = Control.new()
	_auto_controls.theme = GameState.ui_theme
	_auto_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_auto_controls)
	_auto_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_auto_button = IconButton.new()
	_auto_button.name = "AutoBattle"
	_auto_button.glyph = "auto"
	_auto_button.hotkey = "B"
	_auto_button.toggle_mode = true
	_auto_button.pressed.connect(func() -> void: automation.set_enabled(not automation.enabled, self))
	_auto_controls.add_child(_auto_button)
	_auto_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_auto_button.offset_left = 270 if mobile else 24
	_auto_button.offset_top = -96
	_auto_button.size = Vector2(72, 72)
	_auto_button.add_to_group("camera_touch_blocker")
	_auto_settings_button = IconButton.new()
	_auto_settings_button.name = "AutoSettings"
	_auto_settings_button.glyph = "settings"
	_auto_settings_button.show_caption = false
	_auto_settings_button.hotkey = ""
	_auto_settings_button.tooltip_text = "自動戰鬥設定"
	_auto_settings_button.toggle_mode = true
	_auto_settings_button.toggled.connect(_set_auto_settings_expanded)
	_auto_controls.add_child(_auto_settings_button)
	_auto_settings_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_auto_settings_button.offset_left = 282 if mobile else 36
	_auto_settings_button.offset_top = -152
	_auto_settings_button.size = Vector2(48, 48)
	_auto_settings_button.add_to_group("camera_touch_blocker")
	_auto_options = PanelContainer.new()
	_auto_options.add_theme_stylebox_override("panel", HudTheme.panel(12))
	_auto_controls.add_child(_auto_options)
	_auto_options.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_auto_options.offset_left = 342 if mobile else 96
	_auto_options.offset_top = -328
	_auto_options.offset_right = _auto_options.offset_left + 232
	_auto_options.offset_bottom = -172
	_auto_options.add_to_group("camera_touch_blocker")
	var options := VBoxContainer.new()
	_auto_options.add_child(options)
	var title := Label.new()
	title.text = "自動戰鬥設定"
	options.add_child(title)
	var skills := CheckButton.new()
	skills.text = "使用技能"
	skills.custom_minimum_size = Vector2(208, 48)
	skills.button_pressed = automation.use_skills
	skills.focus_mode = Control.FOCUS_NONE
	skills.toggled.connect(func(value: bool) -> void: automation.use_skills = value)
	options.add_child(skills)
	var potions := CheckButton.new()
	potions.text = "低血量喝藥"
	potions.custom_minimum_size.y = 48
	potions.focus_mode = Control.FOCUS_NONE
	potions.toggled.connect(func(value: bool) -> void: automation.use_potions = value)
	options.add_child(potions)
	_auto_options.hide()
	_update_hud()

func _command_button(id: String, size: float) -> Button:
	var spec: Dictionary = Allies.COMMANDS[id]
	var button := IconButton.new()
	button.custom_minimum_size = Vector2(size, size)
	button.glyph = str(spec.glyph)
	button.caption = str(spec.name)
	button.hotkey = str(spec.hotkey)
	button.accent = spec.accent
	button.pressed.connect(func() -> void: command_ally(id))
	button.add_to_group("camera_touch_blocker")
	return button


## Companion orders sit just above the traveler's own actions; the wheel is a
## larger, slowed-time version of the same two orders.
func _build_command_hud(layer: CanvasLayer, mobile: bool) -> void:
	_command_row = HBoxContainer.new()
	_command_row.name = "CommandRow"
	_command_row.theme = GameState.ui_theme
	_command_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_command_row.add_theme_constant_override("separation", 10)
	layer.add_child(_command_row)
	_command_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_command_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_command_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_command_row.offset_left = -80
	_command_row.offset_right = 80
	_command_row.offset_top = -180
	_command_row.offset_bottom = -112
	if mobile:
		_command_row.anchor_left = 0.0
		_command_row.anchor_right = 1.0
		_command_row.offset_left = 366
		_command_row.offset_right = -204
	for id: String in Allies.COMMANDS:
		var button := _command_button(id, 64.0)
		button.name = "Command_" + id
		_command_row.add_child(button)
		_command_buttons[id] = button
	_command_row.hide()

	_wheel = Control.new()
	_wheel.name = "CommandWheel"
	_wheel.theme = GameState.ui_theme
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_wheel)
	_wheel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.07, 0.38)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var board := PanelContainer.new()
	board.add_theme_stylebox_override("panel", HudTheme.panel(16))
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	board.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	board.add_child(column)
	var title := Label.new()
	title.text = "指揮同伴"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 72)
	column.add_child(cards)
	for id: String in Allies.COMMANDS:
		var card := VBoxContainer.new()
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		cards.add_child(card)
		var button := _command_button(id, 116.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.add_child(button)
		_wheel_buttons[id] = button
		var name_label := Label.new()
		name_label.text = ("諾亞" if id == "noah" else "希雅") + "・" + str(Allies.COMMANDS[id].name)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name_label)
		var detail := Label.new()
		detail.text = "引開附近敵人，被打中會踉蹌" if id == "noah" else "立刻減速周圍敵人並回復"
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.add_theme_font_size_override("font_size", 14)
		detail.modulate = Color("c9d6e2")
		card.add_child(detail)
	_wheel_hint = Label.new()
	_wheel_hint.text = "按 Z／X 下令・放開 Tab 返回"
	_wheel_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wheel_hint.add_theme_font_size_override("font_size", 15)
	_wheel_hint.modulate = Color("afc1ce")
	column.add_child(_wheel_hint)
	_wheel.hide()


func _update_command_hud() -> void:
	if not is_instance_valid(_command_row):
		return
	var present: bool = ready_for_combat and has_companions() and GameState.mode == GameState.Mode.EXPLORE
	_command_row.visible = present
	if is_command_wheel_open() and (not present or not is_engaged()):
		close_command_wheel()
	if not present:
		return
	for id: String in Allies.COMMANDS:
		var here: bool = Allies.find_follower(self, id) != null
		var cooldown: float = allies.command_cooldown(id)
		var blocked: bool = not allies.command_block(self, id).is_empty()
		for button: Button in [_command_buttons[id], _wheel_buttons[id]]:
			button.visible = here
			button.cooldown = cooldown
			button.cooldown_fraction = clampf(cooldown / float(Allies.COMMANDS[id].cooldown), 0.0, 1.0)
			button.disabled = blocked
			button.tooltip_text = "%s・%s [%s]" % ["諾亞" if id == "noah" else "希雅", Allies.COMMANDS[id].name, Allies.COMMANDS[id].hotkey]
			button.queue_redraw()


func _set_auto_settings_expanded(expanded: bool) -> void:
	_auto_options.visible = expanded

func _update_hud() -> void:
	_update_command_hud()
	_auto_button.set_pressed_no_signal(automation.enabled)
	_auto_button.caption = "自動・開" if automation.enabled else "自動・關"
	_auto_button.accent = Color("8affce") if automation.enabled else Color("8394a7")
	_auto_button.tooltip_text = "自動戰鬥：%s [B]，點擊切換；移動或出招可接手" % ("開" if automation.enabled else "關")
	_auto_button.disabled = not ready_for_combat
	_auto_button.queue_redraw()
	var profile: Dictionary = GameState.class_profile()
	var cooldowns: Dictionary = {"attack": attack_cooldown, "skill": skill_cooldown, "dodge": dodge_cooldown, "potion": 0.0}
	var durations: Dictionary = {"attack": maxf(0.55, float(profile.interval)), "skill": float(profile.cooldown), "dodge": float(profile.dodge), "potion": 1.0}
	for action: String in _buttons:
		var button: Button = _buttons[action]
		var cooldown: float = cooldowns[action]
		button.glyph = str(profile.glyph) if action == "skill" or (action == "attack" and GameState.player_class != "traveler") else action
		button.cooldown = cooldown
		button.cooldown_fraction = clampf(cooldown / durations[action], 0.0, 1.0)
		button.badge = str(GameState.inventory.get("potion", 0)) if action == "potion" else "%d MP" % int(profile.cost) if action == "skill" else ""
		button.tooltip_text = "%s [%s]" % [button.caption, button.hotkey]
		if action == "skill":
			button.tooltip_text = "%s · %d MP [K]" % [profile.skill, profile.cost]
		button.disabled = not ready_for_combat or cooldown > 0 or (action == "skill" and GameState.player_mp < int(profile.cost)) or (action == "potion" and (GameState.player_hp == GameState.player_max_hp or int(GameState.inventory.get("potion", 0)) == 0))
		button.queue_redraw()

func _pause_focus() -> void:
	_focus_paused = true

func _resume_focus() -> void:
	_focus_paused = false

func _exit_tree() -> void:
	close_command_wheel()
	director.shutdown(self)
	if is_instance_valid(player):
		var rig := player.get_parent().get_node_or_null("CameraRig")
		if is_instance_valid(rig):
			rig.set("_distance", _previous_camera_distance)
			# Finish any shake so no offset lingers into the next map.
			rig.call("advance_combat_feedback", 1.0)
		if player.get("field_combat") == self:
			player.set("field_combat", null)
		player.get_node("Sprite3D").show()
	if is_instance_valid(_hero_outline):
		_hero_outline.queue_free()
	if is_instance_valid(_hero_sprite):
		_hero_sprite.queue_free()

## Actual current atlas frame width, including the artist's pixel size and scale.
static func _sprite_width(sprite: SpriteBase3D) -> float:
	return sprite.get_item_rect().size.x * sprite.pixel_size * absf(sprite.global_basis.get_scale().x) if _visual_texture(sprite) != null else 0.0

func _contact_spacing(enemy: Dictionary) -> float:
	var hero: SpriteBase3D = _hero_sprite if _hero_sprite.visible else player.get_node("Sprite3D") as SpriteBase3D
	return (_sprite_width(enemy.sprite) + _sprite_width(hero)) * 0.5 + 0.12

## Project all four Y-billboard corners, respecting grounding offsets and zoom.
static func _screen_bounds(sprite: SpriteBase3D, camera: Camera3D) -> Rect2:
	var rect: Rect2 = sprite.get_item_rect()
	var right: Vector3 = Vector3.UP.cross(camera.global_basis.z).normalized()
	var size: Vector3 = sprite.global_basis.get_scale()
	var bounds := Rect2()
	var first: bool = true
	for corner: Vector2 in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
		var point: Vector3 = sprite.global_position + right * corner.x * sprite.pixel_size * size.x - Vector3.UP * corner.y * sprite.pixel_size * size.y
		var projected: Vector2 = camera.unproject_position(point)
		if first:
			bounds = Rect2(projected, Vector2.ZERO)
			first = false
		else:
			bounds = bounds.expand(projected)
	return bounds

func _update_hero_outline() -> void:
	if not is_instance_valid(player) or not is_instance_valid(_hero_sprite):
		return
	var camera := get_viewport().get_camera_3d()
	var hero: SpriteBase3D = _hero_sprite if _hero_sprite.visible else player.get_node("Sprite3D") as SpriteBase3D
	var occluded: bool = false
	if camera != null and _visual_texture(hero) != null and GameState.mode == GameState.Mode.EXPLORE and not camera.is_position_behind(hero.global_position):
		var bounds: Rect2 = _screen_bounds(hero, camera)
		for enemy: Dictionary in enemies:
			var visual: Sprite3D = enemy.sprite
			if int(enemy.hp) > 0 and visual.is_visible_in_tree() and visual.texture != null and camera.to_local(visual.global_position).z > camera.to_local(hero.global_position).z + 0.01 and bounds.intersects(_screen_bounds(visual, camera)):
				occluded = true
				break
	if occluded:
		if not is_instance_valid(_hero_outline):
			_hero_outline = Sprite3D.new()
			_hero_outline.name = "OccludedTravelerOutline"
			_hero_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			player.add_child(_hero_outline)
			var shader := Shader.new()
			shader.code = HitFeedback.OUTLINE_SHADER
			var material := ShaderMaterial.new()
			material.shader = shader
			material.render_priority = 20
			_hero_outline.material_override = material
		_hero_outline.transform = hero.transform
		_hero_outline.texture = _visual_texture(hero)
		_hero_outline.pixel_size = hero.pixel_size
		_hero_outline.offset = hero.offset
		_hero_outline.flip_h = hero.flip_h
		_hero_outline.billboard = hero.billboard
		var texture: Texture2D = _visual_texture(hero)
		var atlas := texture as AtlasTexture
		(_hero_outline.material_override as ShaderMaterial).set_shader_parameter("character_texture", atlas.atlas if atlas != null else texture)
	if is_instance_valid(_hero_outline):
		_hero_outline.visible = occluded

static func _visual_texture(sprite: SpriteBase3D) -> Texture2D:
	if sprite is Sprite3D:
		return (sprite as Sprite3D).texture
	var animated := sprite as AnimatedSprite3D
	return animated.sprite_frames.get_frame_texture(animated.animation, animated.frame) if animated != null and animated.sprite_frames != null else null
