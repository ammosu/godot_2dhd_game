extends Node3D
## World adapter: existing map physics, navigation and presentation for ActionBattle.
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const Ring = preload("res://scripts/gameplay/combat_ground_ring.gd")
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
const Art = preload("res://scripts/gameplay/action_sprite_library.gd")
const Presentation = preload("res://scripts/gameplay/enemy_presentation.gd")
const HealthBar = preload("res://scripts/gameplay/world_health_bar.gd")
const DeathEffect = preload("res://scripts/gameplay/enemy_death_effect.gd")
const Effects = preload("res://scripts/gameplay/world_combat_effect.gd")
const COURT := Rect2(-8.0, -13.0, 16.0, 14.0)
const CELL: float = 0.5
var session: RefCounted
var player: CharacterBody3D
var rig: Node3D
var guardian: Node3D
var reward_position := Vector3.ZERO
var bodies: Array[CharacterBody3D] = []
var sprites: Array[Sprite3D] = []
var labels: Array[Label3D] = []
var enemy_presentations: Array[Node3D] = []
var health_bars: Array[Node3D] = []
var warnings: Array[MeshInstance3D] = []
var warning_labels: Array[Label3D] = []
var selections: Array[MeshInstance3D] = []
var poses: Array[String] = []
var _navigation := AStarGrid2D.new()
var _query_shape := CapsuleShape3D.new()
var _player_layer: int
var _player_mask: int
var _player_processing: bool
var _guardian_layer: int = 0
var _finished: bool = false
var _clock: float = 0.0
var _paths: Dictionary = {}
var _numbers: Array[Dictionary] = []
var _last_positions: Array[Vector2] = []
var _effects: Array[Node3D] = []
var _defeated: Dictionary = {}
var _charges: Array[Sprite3D] = []

func setup(model: RefCounted, traveler: CharacterBody3D, camera_rig: Node3D, original: Node3D) -> void:
	session = model
	player = traveler
	rig = camera_rig
	guardian = original
	session.bounds = COURT
	_query_shape.radius = 0.36
	_query_shape.height = 1.1
	_player_layer = player.collision_layer
	_player_mask = player.collision_mask
	_player_processing = player.is_physics_processing()
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.collision_layer = 2
	player.collision_mask = 1
	player.get_node("Sprite3D").hide()
	if is_instance_valid(guardian):
		guardian.hide()
		var original_body := guardian.get_node_or_null("ActorBody") as StaticBody3D
		if original_body != null:
			_guardian_layer = original_body.collision_layer
			original_body.collision_layer = 0
	_build_navigation()
	var origin: Vector3 = guardian.global_position if is_instance_valid(guardian) else Vector3(0, 0.1, -8.2)
	reward_position = origin
	var positions: Array[Vector3] = [player.global_position, player.global_position + Vector3(-1.3, 0, 1.0), player.global_position + Vector3(1.4, 0, 1.6), origin, origin + Vector3(-2.5, 0, -0.5), origin + Vector3(2.5, 0, -2.0)]
	for index: int in range(6):
		var body: CharacterBody3D
		if index == 0:
			body = player
		else:
			body = CharacterBody3D.new()
			body.name = str(session.actors[index].art)
			body.collision_layer = 2
			body.collision_mask = 1
			var shape := CollisionShape3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.3
			capsule.height = 1.05
			shape.shape = capsule
			shape.position.y = 0.525
			body.add_child(shape)
			add_child(body)
			var spawn: Vector2 = _open_point(Vector2(positions[index].x, positions[index].z))
			body.global_position = Vector3(spawn.x, 0.10, spawn.y)
			Grounding.add_shadow(body, 0.32)
		bodies.append(body)
		var actor: Dictionary = session.actors[index]
		actor.position = Vector2(body.global_position.x, body.global_position.z)
		actor.facing = Vector2(0, -1) if index < 3 else Vector2(0, 1)
		_last_positions.append(actor.position)
		var sprite := Sprite3D.new()
		sprite.name = "CombatArt"
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_scissor_threshold = 0.35
		body.add_child(sprite)
		sprites.append(sprite)
		poses.append("")
		var charge := Sprite3D.new()
		charge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		charge.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		charge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		charge.hide()
		add_child(charge)
		_charges.append(charge)
		var label := Label3D.new()
		label.font = GameState.ui_theme.default_font
		label.font_size = 40
		label.pixel_size = 0.007
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = 2.0 if index != 3 else 2.4
		label.outline_size = 10
		body.add_child(label)
		labels.append(label)
		var health_bar := HealthBar.new()
		body.add_child(health_bar)
		health_bar.position.y = label.position.y - 0.24
		health_bar.configure(index >= 3, str(actor.art))
		health_bars.append(health_bar)
		var presentation: Node3D = null
		if index >= 3:
			presentation = Presentation.new()
			body.add_child(presentation)
			presentation.setup(body, str(actor.art), sprite, label, health_bar)
		enemy_presentations.append(presentation)
		var warning := Ring.new()
		warning.configure(1.0, Color("ff746a"), 0.10)
		add_child(warning)
		warnings.append(warning)
		var warning_label := Label3D.new()
		warning_label.font = GameState.ui_theme.default_font
		warning_label.font_size = 36
		warning_label.pixel_size = 0.007
		warning_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		warning_label.text = "危險"
		warning_label.outline_size = 10
		warning_label.modulate = Color("ffbaa5")
		add_child(warning_label)
		warning_labels.append(warning_label)
		var selection := Ring.new()
		selection.configure(0.48, Color("9feaff"), 0.065)
		body.add_child(selection)
		selection.position.y = 0.015
		selections.append(selection)
	_build_boundary()
	session.movement_resolver = _move_body
	session.steering_resolver = _steer
	session.visibility_resolver = _visible
	rig.begin_combat_shot(bodies[0])
	refresh(0.0)

func _build_boundary() -> void:
	# A thin visible seal matches the actual rectangular movement limit.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("77aec8")
	for edge: int in range(4):
		var beam := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var horizontal: bool = edge < 2
		mesh.size = Vector3(COURT.size.x, 0.025, 0.055) if horizontal else Vector3(0.055, 0.025, COURT.size.y)
		beam.mesh = mesh
		beam.material_override = material
		add_child(beam)
		beam.position = Vector3(COURT.get_center().x, 0.09, COURT.position.y if edge == 0 else COURT.end.y) if horizontal else Vector3(COURT.position.x if edge == 2 else COURT.end.x, 0.09, COURT.get_center().y)

func _build_navigation() -> void:
	_navigation.region = Rect2i(0, 0, int(COURT.size.x / CELL) + 1, int(COURT.size.y / CELL) + 1)
	_navigation.cell_size = Vector2.ONE * CELL
	_navigation.offset = COURT.position
	_navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_navigation.update()
	for x: int in range(_navigation.region.size.x):
		for y: int in range(_navigation.region.size.y):
			var cell := Vector2i(x, y)
			var point: Vector2 = _navigation.get_point_position(cell)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = _query_shape
			query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, 0.8, point.y))
			query.collision_mask = 1
			_navigation.set_point_solid(cell, not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty())

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(((point - COURT.position) / CELL).round()).clamp(Vector2i.ZERO, _navigation.region.size - Vector2i.ONE)

func _open_cell(point: Vector2) -> Vector2i:
	var center: Vector2i = _cell(point)
	if not _navigation.is_point_solid(center):
		return center
	for distance: int in range(1, 12):
		for x: int in range(-distance, distance + 1):
			for y: int in range(-distance, distance + 1):
				var candidate: Vector2i = center + Vector2i(x, y)
				if _navigation.region.has_point(candidate) and not _navigation.is_point_solid(candidate):
					return candidate
	return center

func _open_point(point: Vector2) -> Vector2:
	return _navigation.get_point_position(_open_cell(point))

func _clear_corridor(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _query_shape
	query.transform = Transform3D(Basis.IDENTITY, Vector3(from.x, 0.8, from.y))
	query.motion = Vector3(to.x - from.x, 0, to.y - from.y)
	query.collision_mask = 1
	var result: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
	return result.size() == 2 and result[0] >= 0.999

func _steer(index: int, target: int) -> Vector2:
	var from: Vector2 = session.actors[index].position
	var to: Vector2 = session.actors[target].position
	if _clear_corridor(from, to):
		return (to - from).normalized()
	var destination: Vector2i = _open_cell(to)
	var cached: Dictionary = _paths.get(index, {})
	if cached.is_empty() or cached.target != destination or _clock - float(cached.time) > 0.4:
		cached = {"target": destination, "time": _clock, "points": _navigation.get_point_path(_open_cell(from), destination)}
		_paths[index] = cached
	var points: PackedVector2Array = cached.points
	while points.size() > 1 and from.distance_to(points[0]) < 0.3:
		points.remove_at(0)
	cached.points = points
	return (points[0] - from).normalized() if not points.is_empty() else Vector2.ZERO

func _move_body(index: int, target: Vector2) -> Vector2:
	var body: CharacterBody3D = bodies[index]
	var motion := Vector3(target.x - body.global_position.x, 0, target.y - body.global_position.z)
	var collision: KinematicCollision3D = body.move_and_collide(motion)
	if collision != null:
		var slide: Vector3 = collision.get_remainder().slide(collision.get_normal())
		slide.y = 0.0
		body.move_and_collide(slide)
	body.global_position.y = maxf(0.1, body.global_position.y)
	return Vector2(body.global_position.x, body.global_position.z)

func _ray_clear(from: Vector2, to: Vector2) -> bool:
	if from.distance_squared_to(to) < 0.0001:
		return true
	var query := PhysicsRayQueryParameters3D.create(Vector3(from.x, 0.75, from.y), Vector3(to.x, 0.75, to.y), 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _visible(source: int, target: int, aim: Vector2) -> bool:
	return _ray_clear(session.actors[source].position, aim) and _ray_clear(aim, session.actors[target].position)

func input_direction(input: Vector2) -> Vector2:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var right: Vector3 = camera.global_basis.x
	var back: Vector3 = camera.global_basis.z
	right.y = 0.0
	back.y = 0.0
	var direction: Vector3 = right.normalized() * input.x + back.normalized() * input.y
	return Vector2(direction.x, direction.z).limit_length()

func refresh(delta: float) -> void:
	if _finished:
		return
	_clock += delta
	rig.set_combat_target(bodies[int(session.controlled)])
	var camera: Camera3D = get_viewport().get_camera_3d()
	for index: int in range(6):
		var actor: Dictionary = session.actors[index]
		if index >= 3 and int(actor.hp) <= 0 and not _defeated.has(index):
			_defeated[index] = true
			var death := DeathEffect.new()
			add_child(death)
			death.configure(bodies[index], sprites[index], player)
			_effects.append(death)
		var motion: Vector2 = Vector2(actor.position) - _last_positions[index]
		var facing: Vector2 = Facing.screen_direction(Vector3(actor.facing.x, 0, actor.facing.y), camera)
		var pose: String = Art.pose(actor, motion.length() > 0.002, _clock)
		var art: AtlasTexture = Art.directional_texture(str(actor.art), pose, facing, sprites[index], GameState.get_visual_loadout(str(actor.art)) if index < 3 else {})
		poses[index] = pose
		sprites[index].texture = art
		sprites[index].pixel_size = float(art.get_meta("pixel_size"))
		sprites[index].scale.x = float(art.get_meta("width_scale", 1.0))
		Grounding.anchor(sprites[index], art, float(art.get_meta("ground_y")))
		sprites[index].offset.x = art.get_width() * 0.5 - float(art.get_meta("anchor_x"))
		sprites[index].flip_h = bool(art.get_meta("flip_h", false))
		if sprites[index].flip_h:
			sprites[index].offset.x *= -1.0
		_last_positions[index] = actor.position
		_update_charge(index, actor, facing)
		sprites[index].modulate = Color("737a8c") if int(actor.hp) <= 0 else Color(2.2, 2.2, 2.2) if float(actor.hurt) > 0.10 else Color("b2efff") if float(actor.invulnerable) > 0 else Color.WHITE
		if index == 0:
			GameState.HeroStyle.apply_sprite(sprites[index], art, GameState.player_style)
		if enemy_presentations[index] != null:
			enemy_presentations[index].advance(_clock, pose, float(actor.hurt), float(actor.windup), float(actor.swing))
		labels[index].text = ("▶ " if index == int(session.controlled) else "") + str(actor.name)
		labels[index].modulate = Color("a5eaff") if index == int(session.controlled) else Color("f4e7cf") if index >= 3 else Color.WHITE
		labels[index].visible = int(actor.hp) > 0
		health_bars[index].set_health(int(actor.hp), int(actor.max_hp))
		selections[index].visible = int(actor.hp) > 0 and (index == int(session.controlled) or float(actor.ward) > 0.0)
		warnings[index].visible = int(actor.hp) > 0 and (float(actor.windup) > 0.0 or float(actor.swing) > 0.0)
		warnings[index].position = Vector3(actor.aim.x, 0.12, actor.aim.y)
		warnings[index].scale = Vector3.ONE * float(actor.radius)
		(warnings[index].material_override as StandardMaterial3D).albedo_color = Color("ff746a") if index >= 3 else Color("b1edff")
		warning_labels[index].visible = index >= 3 and warnings[index].visible
		warning_labels[index].position = warnings[index].position + Vector3.UP * 0.15
	advance_effects(delta)
	reward_position = bodies[3].global_position

func advance_effects(delta: float) -> void:
	rig.advance_combat_feedback(delta)
	for entry: Dictionary in _numbers:
		entry.life = float(entry.life) - delta
		var label: Label3D = entry.label
		label.position.y += delta * 0.75
		label.modulate.a = clampf(float(entry.life) / 0.22, 0.0, 1.0)
		label.scale = Vector3.ONE * (1.0 + 0.3 * clampf((float(entry.life) - 0.5) / 0.2, 0.0, 1.0))
		if float(entry.life) <= 0.0:
			label.queue_free()
	_numbers = _numbers.filter(func(entry: Dictionary) -> bool: return float(entry.life) > 0.0)
	for effect: Node3D in _effects:
		if is_instance_valid(effect):
			effect.advance(delta)
	_effects = _effects.filter(func(effect: Node3D) -> bool: return is_instance_valid(effect) and not effect.is_queued_for_deletion())

func _update_charge(index: int, actor: Dictionary, facing: Vector2) -> void:
	var charge: Sprite3D = _charges[index]
	charge.visible = (index in [2, 5] or (index == 0 and GameState.player_class == "mage")) and int(actor.hp) > 0 and float(actor.windup) > 0.0
	if not charge.visible:
		return
	var frost: bool = index in [0, 2] and actor.intent == "skill"
	var sheet: Texture2D = preload("res://assets/generated/frost_nova.png") if frost else preload("res://assets/generated/moon_bolt.png")
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = Rect2(Vector2.ZERO, sheet.get_size() * 0.5)
	texture.filter_clip = true
	charge.texture = texture
	charge.pixel_size = (float(actor.radius) * 2.0 if frost else 1.1) / texture.get_width()
	charge.flip_h = facing.x < 0
	charge.modulate = Color("dbaaff") if index == 5 else Color.WHITE
	var target := Vector3(actor.aim.x, 0.86, actor.aim.y)
	var source: Vector3 = bodies[index].position + Vector3.UP * 1.0
	var progress: float = clampf(1.0 - float(actor.windup) / 0.16, 0.0, 1.0)
	charge.position = target if frost else source.lerp(target, progress)

func _effect(kind: String, point: Vector2, radius: float = 1.0, direction: Vector2 = Vector2.RIGHT) -> void:
	if _effects.size() >= 32:
		for oldest: Node3D in _effects:
			if is_instance_valid(oldest) and not oldest is DeathEffect:
				_effects.erase(oldest)
				oldest.queue_free()
				break
	var effect := Effects.new()
	add_child(effect)
	effect.configure(kind, Vector3(point.x, 0.16, point.y), radius, direction, get_viewport().get_camera_3d())
	_effects.append(effect)

func show_event(event: Dictionary) -> void:
	var index: int = int(event.index)
	if event.kind == "projectile":
		var effect := Effects.new()
		add_child(effect)
		var from := Vector3(event.origin.x, 0.16, event.origin.y)
		var to := Vector3(event.aim.x, 0.16, event.aim.y)
		effect.configure("piercing_arrow" if event.piercing else "arrow", from, 0.45, (Vector2(event.aim) - Vector2(event.origin)).normalized(), get_viewport().get_camera_3d())
		effect.launch(from, to, float(event.duration))
		_effects.append(effect)
		return
	if event.kind == "chill":
		_effect("chill", session.actors[index].position, 0.6, Vector2.RIGHT)
		_effects.back().follow_target = bodies[index]
		return
	if event.kind == "swing":
		var kind: String = "frost" if index == 2 and event.intent == "skill" else "bolt" if index in [2, 5] else "moon_slash" if index == 0 and event.intent == "skill" else "spear" if index == 1 else "claw" if index == 4 else "slash"
		if index == 0 and GameState.player_class != "traveler":
			kind = str(GameState.class_profile().effect) if event.intent == "skill" else "arrow" if GameState.player_class == "archer" else "bolt" if GameState.player_class == "mage" else "slash"
		if index == 0 and GameState.player_class == "archer":
			return
		_effect(kind, event.aim, float(event.radius), event.facing)
		return
	if event.kind == "hit":
		var hit_effect: String = "impact"
		if int(event.get("source", -1)) == 0:
			hit_effect = "arrow_hit" if GameState.player_class == "archer" else "frost_hit" if GameState.player_class == "mage" else "shadow_hit" if GameState.player_class == "thief" else "impact"
		_effect(hit_effect, session.actors[index].position)
		if index == int(session.controlled) or index >= 3:
			rig.add_combat_impact(clampf(float(event.amount) / 140.0, 0.035, 0.12))
	if event.kind == "ward":
		for ally: int in session.living(0):
			_effect("ward", session.actors[ally].position)
	elif event.kind == "heal":
		_effect("heal", session.actors[index].position)
	var label := Label3D.new()
	label.font = GameState.ui_theme.default_font
	label.font_size = 52
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 12
	label.text = "守護" if event.kind == "ward" else ("+" if event.kind == "heal" else "−") + str(event.amount)
	label.modulate = Color("b1ffc4") if event.kind != "hit" else Color("fff0af")
	add_child(label)
	label.global_position = bodies[int(event.index)].global_position + Vector3.UP * 1.8
	_numbers.append({"label": label, "life": 0.7})

func finish() -> void:
	if _finished:
		return
	_finished = true
	if session != null:
		session.detach_world()
	if is_instance_valid(player):
		player.collision_layer = _player_layer
		player.collision_mask = _player_mask
		player.velocity = Vector3.ZERO
		player.set_physics_process(_player_processing)
		player.get_node("Sprite3D").show()
		if not sprites.is_empty() and is_instance_valid(sprites[0]):
			sprites[0].queue_free()
		if not labels.is_empty() and is_instance_valid(labels[0]):
			labels[0].queue_free()
		if not health_bars.is_empty() and is_instance_valid(health_bars[0]):
			health_bars[0].queue_free()
		if not selections.is_empty() and is_instance_valid(selections[0]):
			selections[0].queue_free()
	if is_instance_valid(guardian):
		guardian.show()
		var body := guardian.get_node_or_null("ActorBody") as StaticBody3D
		if body != null:
			body.collision_layer = _guardian_layer
	if is_instance_valid(rig):
		rig.end_combat_shot()

func _exit_tree() -> void:
	finish()
