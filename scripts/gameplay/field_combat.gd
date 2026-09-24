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
const SPAWNS: Array[Dictionary] = [
	{"id": "road_wolf_west", "at": Vector3(-4, 0.05, 10), "caster": false},
	{"id": "road_wolf_ramp", "at": Vector3(2, 0.41, 10.5), "caster": false, "elite": true},
	{"id": "road_mage_terrace", "at": Vector3(10, 1.85, 10.5), "caster": true},
	{"id": "road_bat_south", "at": Vector3(-5, 0.05, 12.5), "caster": false, "art": "dusk_bat"},
]
var spawn_list: Array[Dictionary] = SPAWNS.duplicate(true)
var build_terrain: bool = true
var area_title: String = "舊道南側狩獵地"
var compact_hud: bool = false
var camera_distance: float = 15.0
var recovery_map: String = "village"
var recovery_spawn: String = "from_east_road"
var automation := Automation.new()
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
var skill_pending: bool = false
var skill_target: Dictionary = {}
var facing := Vector3.FORWARD
var _locomotion_requested: bool = false
var dodge_direction := Vector3.FORWARD
var attack_direction := Vector3.FORWARD
var _effects: Array[Node3D] = []
var _numbers: Array[Dictionary] = []
var _hero_sprite: Sprite3D
var _hud: Control
var _buttons: Dictionary[String, Button] = {}
var _focus_paused: bool = false
var _previous_camera_distance: float = 11.0

func _ready() -> void:
	if build_terrain:
		Terrain.build(self)
	var rig := player.get_parent().get_node("CameraRig")
	_previous_camera_distance = float(rig.get("_distance"))
	rig.set("_distance", camera_distance)
	player.set("field_combat", self)
	_hero_sprite = _sprite(player)
	_update_hero_art()
	_build_hud()
	if build_terrain:
		var sign := _label(self, "南側・舊道狩獵地\n坡道通往高台", Vector3(-2, 1.4, 7))
		sign.modulate = Color("d8e9c0")
	get_window().focus_exited.connect(_pause_focus)
	get_window().focus_entered.connect(_resume_focus)
	_initialize.call_deferred()

func _initialize() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
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
	var bat: bool = art == "dusk_bat"
	# Fixed encounter tiers preserve the value of leveling and better equipment.
	var elite: bool = bool(spawn.get("elite", false))
	var hp: int = 100 if elite else 42 if bat else 54 if spawn.caster else 72
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
		"cooldown": 0.7, "windup": 0.0, "swing": 0.0, "aim": Vector3.ZERO,
		"path": PackedVector3Array(), "repath": 0.0, "patrol": 1.0})

func movement_velocity(requested: Vector3, delta: float = 0.0, manual_facing: Vector3 = Vector3.ZERO) -> Vector3:
	_locomotion_requested = false
	if _focus_paused:
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
		return dodge_direction * 10.0
	return requested * (0.45 if windup > 0 else 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or GameState.mode != GameState.Mode.EXPLORE:
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
		dodge_time = 0.22
		invulnerable = 0.30
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
	if GameState.player_class == "archer":
		var projectile := Effect.new()
		add_child(projectile)
		projectile.configure("piercing_arrow" if skill_pending else "arrow", player.global_position, 0.45, Vector2(attack_direction.x, attack_direction.z), get_viewport().get_camera_3d())
		projectile.launch(player.global_position, player.global_position + attack_direction * float(GameState.class_profile().reach), windup)
		_effects.append(projectile)
	facing = attack_direction
	player.call("face_world_position", player.global_position + facing)
	return true

func can_hit(from: Vector3, to: Vector3, reach: float) -> bool:
	if absf(from.y - to.y) > 0.7 or Vector2(from.x - to.x, from.z - to.z).length() > reach:
		return false
	var ray := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.7, to + Vector3.UP * 0.7, 1, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
	var active: bool = GameState.mode == GameState.Mode.EXPLORE and not _focus_paused
	_hud.visible = GameState.mode == GameState.Mode.EXPLORE
	_auto_controls.visible = _hud.visible
	_update_hud()
	if not ready_for_combat or not active:
		return
	clock += delta
	attack_cooldown = maxf(0, attack_cooldown - delta)
	skill_cooldown = maxf(0, skill_cooldown - delta)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	dodge_time = maxf(0, dodge_time - delta)
	invulnerable = maxf(0, invulnerable - delta)
	swing = maxf(0, swing - delta)
	if windup > 0:
		windup = maxf(0, windup - delta)
		if windup == 0:
			_strike()
	for enemy: Dictionary in enemies:
		enemy.slow = maxf(0.0, float(enemy.get("slow", 0.0)) - delta)
		_advance_enemy(enemy, delta)
		if GameState.mode != GameState.Mode.EXPLORE:
			return
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
		number.node.position.y += delta * 0.8
		number.node.modulate.a = clampf(float(number.life) * 2.0, 0.0, 1.0)
		if number.life <= 0:
			number.node.queue_free()
	_numbers = _numbers.filter(func(number: Dictionary) -> bool: return number.life > 0)
	_update_hero_art()

func _update_hero_art() -> void:
	# Keep the same body proportions throughout locomotion and combat. The
	# exploration atlas has a different silhouette and cannot be swapped per hit.
	_hero_sprite.show()
	player.get_node("Sprite3D").hide()
	# Braking can outlast a standing frame in the walk cycle. Once movement
	# ends, stay idle instead of flashing another stride during deceleration.
	var moving: bool = _locomotion_requested and Vector2(player.velocity.x, player.velocity.z).length() > 0.05
	var pose: String = ["walk_a", "idle", "walk_b", "idle"][int(clock * 10.0) % 4] if moving else "idle"
	if dodge_time > 0:
		pose = "dodge_a" if dodge_time > 0.11 else "dodge_b"
	elif windup > 0:
		pose = "cast" if GameState.player_class == "mage" else "windup"
	elif swing > 0:
		pose = "release" if GameState.player_class == "mage" else "attack"
	_art(_hero_sprite, "wanderer", pose, facing)

func _strike() -> void:
	swing = 0.20
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
	for enemy: Dictionary in enemies:
		var at: Vector3 = enemy.body.global_position
		var offset: Vector3 = at - origin
		var forward: float = attack_direction.dot((offset * Vector3(1, 0, 1)).normalized())
		var hit: bool = (skill_pending or forward >= 0.15) and can_hit(origin, at, radius)
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

func _damage_enemy(enemy: Dictionary, damage: int) -> void:
	if int(enemy.hp) <= 0:
		return
	Awareness.engage(self, enemy)
	enemy.hp = maxi(0, int(enemy.hp) - damage)
	enemy.hurt = 0.25
	# Light enemies stagger to basic hits; fighters/casters require a skill.
	# Recovery also prevents fast attacks from permanently suppressing a bat.
	var interrupt: bool = (enemy.art == "dusk_bat" or skill_pending) and float(enemy.get("stagger_cooldown", 0.0)) <= 0.0
	if interrupt and float(enemy.windup) > 0.0:
		enemy.windup = 0.0
		enemy.warning.hide()
		enemy.stagger_cooldown = 1.5
		if bool(enemy.get("charged_attack", false)):
			enemy.attack_cycle = 0
		enemy.cooldown = maxf(float(enemy.cooldown), 0.55)
	_number(enemy.body.global_position, str(damage), Color("fff0ad"))
	var hit_effect: String = "arrow_hit" if GameState.player_class == "archer" else "frost_hit" if GameState.player_class == "mage" else "shadow_hit" if GameState.player_class == "thief" else "impact"
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

func _advance_enemy(enemy: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = enemy.body
	var at: Vector3 = body.global_position
	enemy.stagger_cooldown = maxf(0.0, float(enemy.get("stagger_cooldown", 0.0)) - delta)
	enemy.hurt = maxf(0, float(enemy.hurt) - delta)
	enemy.swing = maxf(0, float(enemy.swing) - delta)
	enemy.cooldown = maxf(0, float(enemy.cooldown) - delta)
	enemy.bar.set_health(enemy.hp, enemy.max_hp)
	if int(enemy.hp) <= 0:
		_art(enemy.sprite, enemy.art, "defeated", enemy.facing)
		enemy.presentation.advance(clock, "defeated", 0.0, 0.0, 0.0)
		enemy.label.hide()
		return
	Awareness.update(self, enemy, delta)
	var movement := Vector3.ZERO
	if float(enemy.windup) > 0:
		enemy.windup = maxf(0, float(enemy.windup) - delta)
		if float(enemy.windup) == 0:
			_enemy_strike(enemy)
	elif float(enemy.hurt) == 0:
		var target: Vector3 = enemy.home
		if enemy.state == "chase":
			target = enemy.last_seen
			var reach: float = 4.8 if enemy.caster else 1.35
			if enemy.target_visible and can_hit(at, target, reach):
				if float(enemy.cooldown) == 0:
					enemy.aim = target if enemy.caster else at + (target - at).normalized() * 0.8
					enemy.facing = (target - at).normalized()
					enemy.charged_attack = int(enemy.attack_cycle) == int(enemy.basic_attacks)
					enemy.windup = float(enemy.attack_windup) if enemy.charged_attack else 0.22 if enemy.caster else 0.16
					enemy.cooldown = float(enemy.attack_interval) * (1.2 if enemy.charged_attack else 0.85)
					enemy.warning.position = enemy.aim + Vector3.UP * 0.04
					enemy.warning.visible = enemy.charged_attack
				target = at
		elif enemy.state == "return":
			if at.distance_to(target) < 0.5:
				enemy.state = "patrol"
				enemy.hp = enemy.max_hp
				enemy.attack_cycle = 0
				enemy.charged_attack = false
		else:
			target += Vector3(0, 0, float(enemy.patrol) * 0.8)
			if at.distance_to(target) < 0.45:
				enemy.patrol = -float(enemy.patrol)
		if at.distance_to(target) > 0.25:
			enemy.repath -= delta
			if float(enemy.repath) <= 0:
				enemy.path = navigation.path(at, target)
				enemy.repath = 0.35
			var path: PackedVector3Array = enemy.path
			while not path.is_empty() and Vector2(path[0].x - at.x, path[0].z - at.z).length() < 0.22:
				path.remove_at(0)
			enemy.path = path
			if not path.is_empty():
				movement = ((path[0] - at) * Vector3(1, 0, 1)).normalized()
				enemy.facing = movement
	var slow_factor: float = 0.5 if float(enemy.get("slow", 0.0)) > 0 else 1.0
	body.velocity.x = movement.x * slow_factor * (float(enemy.speed) if enemy.state == "chase" else 1.1)
	body.velocity.z = movement.z * slow_factor * (float(enemy.speed) if enemy.state == "chase" else 1.1)
	body.velocity.y = -0.5 if body.is_on_floor() else body.velocity.y - 18.0 * delta
	body.move_and_slide()
	var pose: String = "hurt" if float(enemy.hurt) > 0 else "cast" if enemy.caster and enemy.charged_attack and float(enemy.windup) > 0 else "windup" if enemy.charged_attack and float(enemy.windup) > 0 else "attack" if float(enemy.windup) > 0 or float(enemy.swing) > 0 else Art.Movement.walk_pose(clock + float(enemy.home.x) * 0.17 + float(enemy.home.z) * 0.11) if not movement.is_zero_approx() else "idle"
	if enemy.art == "dusk_bat" and pose == "idle":
		pose = ["walk_a", "idle", "walk_b", "idle"][int(clock * 10.0) % 4]
	_art(enemy.sprite, enemy.art, pose, enemy.facing)
	enemy.presentation.advance(clock, pose, float(enemy.hurt), float(enemy.windup) if enemy.charged_attack else 0.0, float(enemy.swing))
	enemy.label.text = str(enemy.title) + ("  !" if enemy.state == "chase" else "  ↩" if enemy.state == "return" else "")

func _enemy_strike(enemy: Dictionary) -> void:
	enemy.warning.hide()
	enemy.swing = 0.22
	# Count released attacks even when dodged; interrupted basics do not count.
	enemy.attack_cycle = (int(enemy.attack_cycle) + 1) % (int(enemy.basic_attacks) + 1)
	_effect("bolt" if enemy.caster else "claw", enemy.aim)
	var reach: float = 5.2 if enemy.caster else 1.8
	var radius: float = 1.15 if enemy.caster else 0.95
	if invulnerable <= 0 and can_hit(enemy.body.global_position, player.global_position, reach) and player.global_position.distance_to(enemy.aim) < radius:
		var power: int = int(enemy.attack_power) if enemy.charged_attack else roundi(float(enemy.attack_power) * 0.75)
		var damage: int = maxi(1, power - GameState.player_defense)
		GameState.damage_player(damage)
		invulnerable = 0.45
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

func _number(at: Vector3, text: String, color: Color) -> void:
	var label := _label(self, text, at + Vector3.UP * 1.5)
	label.modulate = color
	_numbers.append({"node": label, "life": 0.8})

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

func _set_auto_settings_expanded(expanded: bool) -> void:
	_auto_options.visible = expanded

func _update_hud() -> void:
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
	if is_instance_valid(player):
		var rig := player.get_parent().get_node_or_null("CameraRig")
		if is_instance_valid(rig):
			rig.set("_distance", _previous_camera_distance)
		if player.get("field_combat") == self:
			player.set("field_combat", null)
		player.get_node("Sprite3D").show()
	if is_instance_valid(_hero_sprite):
		_hero_sprite.queue_free()
