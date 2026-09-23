extends "res://scripts/gameplay/field_combat.gd"
## Final encounter adapter; shared player combat, loot, and pause rules stay intact.
const SpellVisual = preload("res://scripts/gameplay/crypt_boss_spell.gd")
var _spell_visual: Node3D
var _cast_label: Label
const BOSS_ART := "res://assets/generated/dungeon/ash_warden.png"
var _boss_frames: Array[AtlasTexture] = []
var _boss_title: Label
var _boss_health: ProgressBar

func _ready() -> void:
	var sheet: Texture2D = load(BOSS_ART)
	for i: int in range(8):
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2((i % 4) * sheet.get_width() / 4.0, (i / 4) * sheet.get_height() / 2.0, sheet.get_width() / 4.0, sheet.get_height() / 2.0)
		frame.filter_clip = true
		frame.set_meta("baseline", Grounding.foot_baseline(frame))
		_boss_frames.append(frame)
	_spell_visual = SpellVisual.new()
	add_child(_spell_visual)
	super._ready()
	var layer := CanvasLayer.new()
	layer.layer = 31
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = 118
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	panel.hide()
	_boss_title = Label.new()
	_boss_title.theme = GameState.ui_theme
	_boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_title.add_theme_font_size_override("font_size", 18)
	panel.add_child(_boss_title)
	_boss_health = ProgressBar.new()
	_boss_health.custom_minimum_size = Vector2(360, 12)
	_boss_health.show_percentage = false
	panel.add_child(_boss_health)
	_cast_label = Label.new()
	_cast_label.theme = GameState.ui_theme
	_cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_label.add_theme_color_override("font_color", Color("ffd39c"))
	panel.add_child(_cast_label)

func _spawn_enemy(spawn: Dictionary) -> void:
	super._spawn_enemy(spawn)
	var enemy: Dictionary = enemies.back()
	enemy.art = "ash_warden"
	enemy.title = "燼冠典獄長・維爾莫"
	enemy.hp = 280
	enemy.max_hp = 280
	enemy.speed = 1.7
	enemy.attack_power = 24
	enemy.enraged = false
	enemy.cycle = 0
	enemy.radius = 2.5
	enemy.spell = false
	enemy.global_kind = ""
	enemy.spell_age = -1.0
	enemy.wave_hit = false
	enemy.previous_distance = 0.0
	enemy.rain_points = []
	enemy.rain_done = []
	enemy.cast_duration = 1.25
	enemy.label.position.y = 3.75
	enemy.bar.position.y = 3.5
	enemy.cooldown = 1.5
	_art(enemy.sprite, enemy.art, "idle", Vector3.FORWARD)

func _art(sprite: Sprite3D, actor: String, pose: String, direction: Vector3) -> void:
	if actor != "ash_warden" or Art.Movement.supports(actor, pose):
		super._art(sprite, actor, pose, direction)
		return
	var index: int = int({"idle": 0, "walk_a": 1, "walk_b": 2, "windup": 3, "attack": 4, "cast": 5, "hurt": 6, "defeated": 7}.get(pose, 0))
	var frame: AtlasTexture = _boss_frames[index]
	sprite.texture = frame
	sprite.pixel_size = 3.7 / frame.get_height()
	sprite.flip_h = false
	sprite.offset.x = 0.0
	Grounding.anchor(sprite, frame, float(frame.get_meta("baseline")))

func _damage_enemy(enemy: Dictionary, damage: int) -> void:
	var casting: float = enemy.windup
	super._damage_enemy(enemy, damage)
	# The boss can be hurt, but normal attacks cannot indefinitely cancel its telegraph.
	if enemy.hp > 0 and casting > 0:
		enemy.windup = casting
		enemy.warning.visible = str(enemy.global_kind).is_empty()
	elif enemy.hp <= 0:
		enemy.spell_age = -1.0
		_spell_visual.clear()

func _advance_enemy(enemy: Dictionary, delta: float) -> void:
	_spell_visual.advance(delta)
	var body: CharacterBody3D = enemy.body
	enemy.hurt = maxf(0, float(enemy.hurt) - delta)
	enemy.swing = maxf(0, float(enemy.swing) - delta)
	enemy.cooldown = maxf(0, float(enemy.cooldown) - delta)
	enemy.bar.set_health(enemy.hp, enemy.max_hp)
	_boss_health.max_value = enemy.max_hp
	_boss_health.value = enemy.hp
	_boss_health.get_parent().visible = GameState.mode == GameState.Mode.EXPLORE and enemy.hp > 0
	if enemy.hp <= 0:
		enemy.warning.hide()
		_spell_visual.clear()
		enemy.label.hide()
		_art(enemy.sprite, enemy.art, "defeated", enemy.facing)
		enemy.presentation.advance(clock, "defeated", 0, 0, 0)
		return
	if enemy.spell_age >= 0:
		_advance_global(enemy, delta)
		if GameState.mode != GameState.Mode.EXPLORE:
			return
	if not enemy.enraged and enemy.hp <= enemy.max_hp / 2:
		enemy.enraged = true
		GameState.notification_requested.emit("維爾莫的血晶碎裂！灰燼狂怒・預警縮短")
	_boss_title.text = enemy.title + ("  ·  灰燼狂怒" if enemy.enraged else "")
	var distance: float = body.position.distance_to(player.position)
	if enemy.state == "patrol" and distance < 9.0:
		enemy.state = "chase"
	var movement := Vector3.ZERO
	if enemy.windup > 0:
		enemy.windup = maxf(0, float(enemy.windup) - delta)
		_spell_visual.charge(1.0 - float(enemy.windup) / float(enemy.cast_duration), clock)
		if enemy.windup == 0:
			_enemy_strike(enemy)
	elif enemy.state == "chase" and enemy.spell_age < 0:
		var next_global: bool = int(enemy.cycle) % 6 in [2, 5]
		if enemy.cooldown <= 0 and (next_global or can_hit(body.position, player.position, 7.0)):
			var cycle: int = int(enemy.cycle) % 6
			_begin_cast(enemy, "ash_tide" if cycle == 2 else "crystal_rain" if cycle == 5 else "eruption" if cycle % 2 == 1 else "slam")
			enemy.cycle += 1
		elif distance > 1.8:
			enemy.repath -= delta
			if enemy.repath <= 0:
				enemy.path = navigation.path(body.position, player.position)
				enemy.repath = 0.35
			var path: PackedVector3Array = enemy.path
			while not path.is_empty() and Vector2(path[0].x - body.position.x, path[0].z - body.position.z).length() < 0.25:
				path.remove_at(0)
			enemy.path = path
			if not path.is_empty():
				movement = ((path[0] - body.position) * Vector3(1, 0, 1)).normalized()
	body.velocity = movement * (2.2 if enemy.enraged else 1.7) + Vector3.DOWN * 2
	body.move_and_slide()
	if not movement.is_zero_approx():
		enemy.facing = movement
	var pose: String = "cast" if enemy.windup > 0 and enemy.spell else "windup" if enemy.windup > 0 else "attack" if enemy.swing > 0 else "hurt" if enemy.hurt > 0 else Art.Movement.walk_pose(clock * 0.7) if not movement.is_zero_approx() else "idle"
	_art(enemy.sprite, enemy.art, pose, enemy.facing)
	enemy.presentation.advance(clock, pose, enemy.hurt, enemy.windup, enemy.swing)
	var callout: String = "灰燼潮汐・閃避穿越火環" if enemy.global_kind == "ash_tide" else "血晶天墜・避開落點" if enemy.global_kind == "crystal_rain" else "灰燼爆發・離開紅圈" if enemy.spell else "斷罪重擊・遠離斧刃"
	enemy.label.text = callout if enemy.windup > 0 and str(enemy.global_kind).is_empty() else ""
	_cast_label.text = "%s  %.1f 秒" % [callout, enemy.windup] if enemy.windup > 0 else callout if enemy.spell_age >= 0 else ""

func _enemy_strike(enemy: Dictionary) -> void:
	enemy.warning.hide()
	enemy.swing = 0.4
	_spell_visual.release()
	GameAudio.play_cue(&"skill" if enemy.spell else &"impact")
	player.get_parent().get_node("CameraRig").add_combat_impact(0.12)
	if not str(enemy.global_kind).is_empty():
		enemy.spell_age = 0.0
		enemy.previous_distance = Vector2(player.position.x - enemy.aim.x, player.position.z - enemy.aim.z).length()
	else:
		_apply_spell_hit(enemy)

func _advance_global(enemy: Dictionary, delta: float) -> void:
	var previous: float = enemy.spell_age
	enemy.spell_age += delta
	if enemy.global_kind == "ash_tide":
		var distance: float = Vector2(player.position.x - enemy.aim.x, player.position.z - enemy.aim.z).length()
		# Swept relative distances catch both moving players and long physics frames.
		var before: float = float(enemy.previous_distance) - previous * 8.0
		var after: float = distance - float(enemy.spell_age) * 8.0
		if not enemy.wave_hit and minf(before, after) <= 0.65 and maxf(before, after) >= -0.65:
			enemy.wave_hit = true
			_deal_spell_damage(enemy)
		enemy.previous_distance = distance
	else:
		for i: int in range(enemy.rain_points.size()):
			var landing: float = 0.3 + float(i % 4) * 0.5
			if not enemy.rain_done[i] and enemy.spell_age >= landing:
				enemy.rain_done[i] = true
				var at: Vector3 = enemy.rain_points[i]
				if Vector2(player.position.x - at.x, player.position.z - at.z).length() < 1.15:
					_deal_spell_damage(enemy)
	if enemy.spell_age >= (3.6 if enemy.global_kind == "ash_tide" else 2.6):
		enemy.spell_age = -1.0


func _apply_spell_hit(enemy: Dictionary) -> void:
	var global_attack: bool = not str(enemy.global_kind).is_empty()
	var hit: bool = global_danger(enemy, player.position) if global_attack else can_hit(enemy.body.position, player.position, 8.0) and Vector2(player.position.x - enemy.aim.x, player.position.z - enemy.aim.z).length() < enemy.radius
	if hit:
		_deal_spell_damage(enemy)

func _deal_spell_damage(enemy: Dictionary) -> void:
	if invulnerable <= 0:
		var damage: int = maxi(1, int(enemy.attack_power) + (6 if enemy.enraged else 0) - GameState.player_defense)
		GameState.damage_player(damage)
		invulnerable = 0.45
		_number(player.position, "−%d" % damage, Color("ff9985"))
		if GameState.player_hp == 0:
			GameState.restore_after_defeat()
			automation.set_enabled(false, self)
			GameState.set_mode(GameState.Mode.TRANSITION)
			_recover.call_deferred()


func _begin_cast(enemy: Dictionary, kind: String) -> void:
	var toward_player: Vector3 = (player.position - enemy.body.position) * Vector3(1, 0, 1)
	if not toward_player.is_zero_approx():
		enemy.facing = toward_player.normalized()
	enemy.global_kind = kind if kind in ["ash_tide", "crystal_rain"] else ""
	enemy.spell = kind != "slam"
	enemy.radius = (1.8 if enemy.enraged else 1.45) if enemy.spell else 2.5
	enemy.aim = player.position if enemy.spell else enemy.body.position
	enemy.windup = 0.85 if enemy.enraged else 1.25
	enemy.cooldown = 2.1 if enemy.enraged else 2.9
	if not str(enemy.global_kind).is_empty():
		enemy.aim = enemy.body.position
		enemy.windup = 1.5 if enemy.enraged else 1.9
		enemy.cooldown = enemy.windup + 4.5
		enemy.wave_hit = false
		enemy.spell_age = -1.0
		enemy.rain_points = []
		enemy.rain_done = []
		if kind == "crystal_rain":
			# Lock all telegraphs before release; four staggered batches leave natural gaps.
			enemy.rain_points.append(Vector3(player.position.x, 0.08, player.position.z))
			for z: float in [-9, -5, -1, 3, 7]:
				for x: float in [-7, -3.5, 0, 3.5, 7]:
					var point := Vector3(x + sin(z + float(enemy.cycle)) * 0.5, 0.08, z + cos(x) * 0.4)
					if point.distance_to(enemy.rain_points[0]) > 2.4:
						enemy.rain_points.append(point)
			for point: Vector3 in enemy.rain_points:
				enemy.rain_done.append(false)
		enemy.warning.hide()
	else:
		enemy.warning.configure(enemy.radius, Color("ff543f") if enemy.spell else Color("ffbd6f"), 0.14)
		enemy.warning.position = enemy.aim + Vector3.UP * 0.06
		enemy.warning.show()
	enemy.cast_duration = enemy.windup
	_spell_visual.begin(kind, enemy.aim, enemy.radius, enemy.body.position)
	if kind == "crystal_rain":
		_spell_visual.set_rain(enemy.rain_points)
	GameAudio.play_cue(&"skill")

func global_danger(enemy: Dictionary, at: Vector3) -> bool:
	if enemy.global_kind == "ash_tide":
		return enemy.spell_age >= 0 and absf(Vector2(at.x - enemy.aim.x, at.z - enemy.aim.z).length() - float(enemy.spell_age) * 8.0) <= 0.65
	if enemy.global_kind == "crystal_rain":
		for i: int in range(enemy.rain_points.size()):
			if not enemy.rain_done[i] and at.distance_to(enemy.rain_points[i]) < 1.35:
				return true
	return false

func global_escape_direction(at: Vector3) -> Vector3:
	for enemy: Dictionary in enemies:
		if enemy.hp <= 0 or (enemy.windup <= 0 and enemy.spell_age < 0) or str(enemy.global_kind).is_empty():
			continue
		if enemy.global_kind == "ash_tide":
			var offset: Vector3 = (at - enemy.aim) * Vector3(1, 0, 1)
			var remaining: float = offset.length() - maxf(0, enemy.spell_age) * 8.0
			if enemy.spell_age >= 0 and not enemy.wave_hit and remaining <= 2.1:
				facing = -offset.normalized() if offset.length() > 0.1 else Vector3.FORWARD
				perform("dodge", true)
			return Vector3.ZERO
		if not global_danger(enemy, at):
			return Vector3.ZERO
		# Find a nearby reachable gap, rather than a permanent authored refuge.
		var best := Vector3.ZERO
		var cost: float = INF
		for id: int in navigation.graph.get_point_ids():
			var point: Vector3 = navigation.graph.get_point_position(id)
			var distance: float = at.distance_squared_to(point)
			if distance >= cost or global_danger(enemy, point):
				continue
			var path: PackedVector3Array = navigation.path(at, point)
			if path.size() < 2:
				continue
			cost = distance
			best = ((path[1] - at) * Vector3(1, 0, 1)).normalized()
		return best
	return Vector3.ZERO

func has_global_cast() -> bool:
	for enemy: Dictionary in enemies:
		if enemy.hp > 0 and (enemy.windup > 0 or enemy.spell_age >= 0) and not str(enemy.global_kind).is_empty():
			return true
	return false


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_instance_valid(_boss_health):
		_boss_health.get_parent().visible = GameState.mode == GameState.Mode.EXPLORE and not enemies.is_empty() and enemies[0].hp > 0
