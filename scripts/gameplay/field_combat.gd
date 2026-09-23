extends Node3D
## Optional overworld encounter. GameState owns progression, defeat flags and loot.
const Automation = preload("res://scripts/gameplay/field_auto_battle.gd")
const Terrain = preload("res://scripts/gameplay/field_terrain.gd")
const Navigation = preload("res://scripts/gameplay/field_navigation.gd")
const Art = preload("res://scripts/gameplay/action_sprite_library.gd")
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const Presentation = preload("res://scripts/gameplay/enemy_presentation.gd")
const HealthBar = preload("res://scripts/gameplay/world_health_bar.gd")
const Ring = preload("res://scripts/gameplay/combat_ground_ring.gd")
const Effect = preload("res://scripts/gameplay/world_combat_effect.gd")
const SPAWNS: Array[Dictionary] = [
	{"id": "road_wolf_west", "at": Vector3(-4, 0.05, 10), "caster": false},
	{"id": "road_wolf_ramp", "at": Vector3(2, 0.41, 10.5), "caster": false},
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
var facing := Vector3.FORWARD
var dodge_direction := Vector3.FORWARD
var attack_direction := Vector3.FORWARD
var _effects: Array[Node3D] = []
var _numbers: Array[Dictionary] = []
var _hero_sprite: Sprite3D
var _hud: Control
var _status: Label
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
	var hp: int = 28 if bat else 46 if spawn.caster else 38
	enemies.append({"id": spawn.id, "body": body, "sprite": sprite, "bar": bar, "label": label,
		"presentation": presentation, "warning": warning, "caster": spawn.caster, "art": art,
		"title": "暮翼蝙蝠" if bat else "月蝕術士" if spawn.caster else "苔原狼",
		"speed": 3.15 if bat else 2.35, "attack_power": 10 if bat else 16 if spawn.caster else 12,
		"attack_windup": 0.6 if bat else 1.0 if spawn.caster else 0.75,
		"attack_interval": 1.35 if bat else 2.2 if spawn.caster else 1.6, "hp": hp, "max_hp": hp,
		"home": spawn.at, "state": "patrol", "facing": Vector3.FORWARD, "hurt": 0.0,
		"cooldown": 0.7, "windup": 0.0, "swing": 0.0, "aim": Vector3.ZERO,
		"path": PackedVector3Array(), "repath": 0.0, "patrol": 1.0})

func movement_velocity(requested: Vector3, delta: float = 0.0) -> Vector3:
	if _focus_paused:
		return Vector3.ZERO
	if not requested.is_zero_approx():
		automation.set_enabled(false, self)
	else:
		requested = automation.direction(self, delta) * player.move_speed
	if not requested.is_zero_approx():
		facing = requested.normalized()
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
		dodge_cooldown = 1.0
		player.get("auto_walk").cancel()
		return true
	if action not in ["attack", "skill"] or attack_cooldown > 0:
		return false
	if action == "skill" and (skill_cooldown > 0 or GameState.player_mp < 5):
		return false
	player.get("auto_walk").cancel()
	skill_pending = action == "skill"
	if skill_pending:
		GameState.spend_mp(5)
		skill_cooldown = 3.5
	attack_cooldown = 0.55 if skill_pending else 0.38
	windup = 0.18 if skill_pending else 0.12
	attack_direction = facing
	var closest: float = 3.0
	for enemy: Dictionary in enemies:
		var at: Vector3 = enemy.body.global_position
		var distance: float = player.global_position.distance_to(at)
		if int(enemy.hp) > 0 and distance < closest and can_hit(player.global_position, at, 3.0):
			closest = distance
			attack_direction = (at - player.global_position) * Vector3(1, 0, 1)
			attack_direction = attack_direction.normalized()
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
	var moving: bool = Vector2(player.velocity.x, player.velocity.z).length() > 0.05
	var pose: String = ["walk_a", "idle", "walk_b", "idle"][int(clock * 10.0) % 4] if moving else "idle"
	if dodge_time > 0:
		pose = "dodge_a" if dodge_time > 0.11 else "dodge_b"
	elif windup > 0:
		pose = "windup"
	elif swing > 0:
		pose = "attack"
	_art(_hero_sprite, "wanderer", pose, facing)

func _strike() -> void:
	swing = 0.20
	var radius: float = 2.6 if skill_pending else 1.65
	_effect("moon_slash" if skill_pending else "slash", player.global_position, radius, attack_direction)
	GameAudio.play_cue(&"moon_slash" if skill_pending else &"slash")
	for enemy: Dictionary in enemies:
		var offset: Vector3 = enemy.body.global_position - player.global_position
		var forward: float = attack_direction.dot((offset * Vector3(1, 0, 1)).normalized())
		if int(enemy.hp) > 0 and (skill_pending or forward >= 0.15) and can_hit(player.global_position, enemy.body.global_position, radius):
			_damage_enemy(enemy, GameState.player_attack * 2 if skill_pending else GameState.player_attack)

func _damage_enemy(enemy: Dictionary, damage: int) -> void:
	if int(enemy.hp) <= 0:
		return
	enemy.hp = maxi(0, int(enemy.hp) - damage)
	enemy.hurt = 0.25
	enemy.windup = 0.0
	enemy.warning.hide()
	enemy.state = "chase"
	enemy.cooldown = maxf(float(enemy.cooldown), 0.55)
	_number(enemy.body.global_position, str(damage), Color("fff0ad"))
	_effect("impact", enemy.body.global_position)
	if int(enemy.hp) == 0:
		enemy.state = "dead"
		enemy.body.collision_layer = 0
		GameState.defeat_field_enemy(enemy.id, enemy.body.global_position, enemy.caster)
		_sync_loot()

func _advance_enemy(enemy: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = enemy.body
	var at: Vector3 = body.global_position
	enemy.hurt = maxf(0, float(enemy.hurt) - delta)
	enemy.swing = maxf(0, float(enemy.swing) - delta)
	enemy.cooldown = maxf(0, float(enemy.cooldown) - delta)
	enemy.bar.set_health(enemy.hp, enemy.max_hp)
	if int(enemy.hp) <= 0:
		_art(enemy.sprite, enemy.art, "defeated", enemy.facing)
		enemy.presentation.advance(clock, "defeated", 0.0, 0.0, 0.0)
		enemy.label.hide()
		return
	var distance: float = at.distance_to(player.global_position)
	var can_chase: bool = navigation.contains(player.global_position) and player.global_position.distance_to(enemy.home) < 9.0
	if enemy.state == "patrol" and can_chase and distance < 5.2:
		enemy.state = "chase"
	if enemy.state == "chase" and (not can_chase or at.distance_to(enemy.home) > 10.0):
		enemy.state = "return"
		enemy.windup = 0.0
		enemy.warning.hide()
	var movement := Vector3.ZERO
	if float(enemy.windup) > 0:
		enemy.windup = maxf(0, float(enemy.windup) - delta)
		if float(enemy.windup) == 0:
			_enemy_strike(enemy)
	elif float(enemy.hurt) == 0:
		var target: Vector3 = enemy.home
		if enemy.state == "chase":
			target = player.global_position
			var reach: float = 4.8 if enemy.caster else 1.35
			if can_hit(at, target, reach):
				if float(enemy.cooldown) == 0:
					enemy.aim = target if enemy.caster else at + (target - at).normalized() * 0.8
					enemy.facing = (target - at).normalized()
					enemy.windup = enemy.attack_windup
					enemy.cooldown = enemy.attack_interval
					enemy.warning.position = enemy.aim + Vector3.UP * 0.04
					enemy.warning.show()
				target = at
		elif enemy.state == "return":
			if at.distance_to(target) < 0.5:
				enemy.state = "patrol"
				enemy.hp = enemy.max_hp
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
	body.velocity.x = movement.x * (float(enemy.speed) if enemy.state == "chase" else 1.1)
	body.velocity.z = movement.z * (float(enemy.speed) if enemy.state == "chase" else 1.1)
	body.velocity.y = -0.5 if body.is_on_floor() else body.velocity.y - 18.0 * delta
	body.move_and_slide()
	var pose: String = "hurt" if float(enemy.hurt) > 0 else "cast" if enemy.caster and float(enemy.windup) > 0 else "windup" if float(enemy.windup) > 0 else "attack" if float(enemy.swing) > 0 else Art.Movement.walk_pose(clock + float(enemy.home.x) * 0.17 + float(enemy.home.z) * 0.11) if not movement.is_zero_approx() else "idle"
	if enemy.art == "dusk_bat" and pose == "idle":
		pose = ["walk_a", "idle", "walk_b", "idle"][int(clock * 10.0) % 4]
	_art(enemy.sprite, enemy.art, pose, enemy.facing)
	enemy.presentation.advance(clock, pose, float(enemy.hurt), float(enemy.windup), float(enemy.swing))
	enemy.label.text = str(enemy.title) + ("  !" if enemy.state == "chase" else "  ↩" if enemy.state == "return" else "")

func _enemy_strike(enemy: Dictionary) -> void:
	enemy.warning.hide()
	enemy.swing = 0.22
	_effect("bolt" if enemy.caster else "claw", enemy.aim)
	var reach: float = 5.2 if enemy.caster else 1.8
	var radius: float = 1.15 if enemy.caster else 0.95
	if invulnerable <= 0 and can_hit(enemy.body.global_position, player.global_position, reach) and player.global_position.distance_to(enemy.aim) < radius:
		var damage: int = maxi(1, int(enemy.attack_power) - GameState.player_defense)
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
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.3
	parent.add_child(sprite)
	return sprite

func _art(sprite: Sprite3D, actor: String, pose: String, direction: Vector3) -> void:
	var screen: Vector2 = Facing.screen_direction(direction, get_viewport().get_camera_3d())
	var column: int = Art.direction(screen)
	var texture: AtlasTexture = Art.directional_texture(actor, pose, screen, sprite, GameState.equipped if actor == "wanderer" else {})
	sprite.texture = texture
	sprite.pixel_size = float(texture.get_meta("pixel_size"))
	if actor == "wanderer":
		var standing: AtlasTexture = Art.texture_for(actor, "idle", column, GameState.equipped)
		sprite.pixel_size = float(player.call("presentation_height")) / float(standing.get_height())
	Grounding.anchor(sprite, texture, float(texture.get_meta("ground_y")))
	sprite.offset.x = texture.get_width() * 0.5 - float(texture.get_meta("anchor_x"))
	sprite.flip_h = bool(texture.get_meta("flip_h", false))
	if sprite.flip_h:
		sprite.offset.x *= -1

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

func _effect(kind: String, at: Vector3, radius: float = 1, direction: Vector3 = Vector3.FORWARD) -> void:
	var effect := Effect.new()
	add_child(effect)
	effect.configure(kind, at + Vector3.UP * 0.05, radius, Vector2(direction.x, direction.z), get_viewport().get_camera_3d())
	_effects.append(effect)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_hud = PanelContainer.new()
	_hud.add_to_group("camera_touch_blocker")
	_hud.theme = GameState.ui_theme
	_hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hud.offset_left = -260
	_hud.offset_right = 260
	_hud.offset_top = -188
	_hud.offset_bottom = -14 if compact_hud else -32
	if compact_hud:
		_hud.offset_top = -120
	layer.add_child(_hud)
	var column := VBoxContainer.new()
	_hud.add_child(column)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 17)
	column.add_child(_status)
	var options := HBoxContainer.new()
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(options)
	_auto_button = Button.new()
	_auto_button.focus_mode = Control.FOCUS_NONE
	_auto_button.pressed.connect(func() -> void: automation.set_enabled(not automation.enabled, self))
	options.add_child(_auto_button)
	var skills := CheckButton.new()
	skills.text = "使用技能"
	skills.button_pressed = automation.use_skills
	skills.focus_mode = Control.FOCUS_NONE
	skills.toggled.connect(func(value: bool) -> void: automation.use_skills = value)
	options.add_child(skills)
	var potions := CheckButton.new()
	potions.text = "低血量喝藥"
	potions.focus_mode = Control.FOCUS_NONE
	potions.toggled.connect(func(value: bool) -> void: automation.use_potions = value)
	options.add_child(potions)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for action: String in ["attack", "skill", "dodge", "potion"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(124, 36 if compact_hud else 48)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(func() -> void: perform(action))
		row.add_child(button)
		_buttons[action] = button

func _update_hud() -> void:
	_auto_button.text = "自動：開 B" if automation.enabled else "自動：關 B"
	_auto_button.disabled = not ready_for_combat
	_status.text = "Lv.%d  EXP %d/%d   HP %d/%d   MP %d/%d\n%s・月苔 ×%d" % [GameState.player_level, GameState.player_xp, GameState.xp_to_next_level(), GameState.player_hp, GameState.player_max_hp, GameState.player_mp, GameState.player_max_mp, area_title, int(GameState.inventory.get("moon_moss", 0))]
	if compact_hud:
		_status.text = "Lv.%d  HP %d/%d   MP %d/%d" % [GameState.player_level, GameState.player_hp, GameState.player_max_hp, GameState.player_mp, GameState.player_max_mp]
	var cooldowns: Dictionary = {"attack": attack_cooldown, "skill": skill_cooldown, "dodge": dodge_cooldown, "potion": 0.0}
	var labels: Dictionary = {"attack": "普攻 J / 1", "skill": "月影斬 K / 2", "dodge": "閃避 Shift", "potion": "藥水 H ×%d" % int(GameState.inventory.get("potion", 0))}
	for action: String in _buttons:
		var cooldown: float = cooldowns[action]
		_buttons[action].text = "%s %.1f" % [labels[action], cooldown] if cooldown > 0 else labels[action]
		_buttons[action].disabled = not ready_for_combat or cooldown > 0 or (action == "skill" and GameState.player_mp < 5) or (action == "potion" and (GameState.player_hp == GameState.player_max_hp or int(GameState.inventory.get("potion", 0)) == 0))

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
