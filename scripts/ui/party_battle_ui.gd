class_name PartyBattleUI
extends CanvasLayer

signal battle_finished(victory: bool)
const Model = preload("res://scripts/systems/party_battle.gd")
const Burst = preload("res://scripts/ui/magic_burst.gd")
const HealingBurst = preload("res://scripts/ui/healing_burst.gd")
const MoonBoltBurst = preload("res://scripts/ui/moon_bolt_burst.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const SCALE: float = 56.0
const WORLD_SCALE: float = 1.25
const Arena3D = preload("res://scripts/gameplay/battle_arena_3d.gd")
const EquipmentPortrait = preload("res://scripts/ui/equipment_portrait.gd")
var session: RefCounted
var _root: Control
var _stage: Control
var _arena_viewport: SubViewport
var _arena: Node3D
var _preview_only: bool = false
var _title: Label
var _log: Label
var _preview: Label
var _confirm: Button
var _action_panel: Control
var _continue: Button
var _portraits: Array[TextureRect] = []
var _cards: Array[Button] = []
var _actions: Array[Button] = []
var _shadows: Array[Polygon2D] = []
var _wards: Array[TextureRect] = []
var _selection_marks: Array[Line2D] = []
var _selection_labels: Array[Label] = []
var _baseline_cache: Dictionary = {}
var _ring: Line2D
var _busy: bool = false
var _resolved: bool = false
var _target: int = 3
var _action: String = "attack"


func _ready() -> void:
	layer = 70
	_build()
	_root.hide()


func start_battle(enemy: Dictionary) -> void:
	if is_active():
		return
	_preview_only = false
	session = GameState.begin_party_battle(enemy)
	_arena.build(GameState.battle_visual)
	_arena_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_resolved = false
	_busy = false
	_target = 3
	_action = "attack"
	_root.show()
	_continue.hide()
	_log.text = "旅人、諾亞與長老並肩迎敵。選技能 → 選目標 → 確認。"
	for index: int in range(6):
		_pose(index, _resting_pose(index))
		_portraits[index].modulate = Color.WHITE
	_refresh()
	_confirm.grab_focus()


func is_active() -> bool:
	return _root.visible


func is_resolved() -> bool:
	return is_active() and _resolved


func did_player_win() -> bool:
	return session != null and int(session.winner) == 0


func can_accept_action() -> bool:
	return is_active() and not _preview_only and not _resolved and not _busy and int(session.actors[session.current].team) == 0


func choose_action(action: String) -> void:
	if not can_accept_action():
		return
	var error: String = session.validate(action, _target)
	if action == "potion" and int(GameState.inventory.get("potion", 0)) <= 0:
		error = "藥水已用完。"
	if not error.is_empty():
		_log.text = error
		return
	_execute(action, _target)


func _select_action(action: String) -> void:
	if not can_accept_action() or not session.available_actions().has(action):
		return
	_action = action
	if session.preview(action, _target).is_empty():
		for index: int in range(6):
			if not session.preview(action, index).is_empty():
				_target = index
				if session.validate(action, index).is_empty():
					break
	_refresh()


func _select_slot(slot: int) -> void:
	if can_accept_action() and slot < session.available_actions().size():
		_select_action(session.available_actions()[slot])


func _select_target(index: int) -> void:
	if not can_accept_action() or session.preview(_action, index).is_empty():
		return
	_target = index
	_refresh()


func _world_point(index: int) -> Vector3:
	var point: Vector2 = session.actors[index].position
	return Vector3((-7.0 if index < 3 else 3.0) + point.x * WORLD_SCALE, 0.0, point.y * WORLD_SCALE)


func _point(index: int) -> Vector2:
	return _arena.camera.unproject_position(_world_point(index))


func _projected_range(index: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center := _world_point(index)
	for step: int in range(65):
		var offset := Vector2.from_angle(TAU * step / 64.0) * radius * WORLD_SCALE
		points.append(_arena.camera.unproject_position(center + Vector3(offset.x, 0.0, offset.y)) - _point(index))
	return points


func show_arena_preview(descriptor: Dictionary) -> void:
	# Gallery state is local: no combat session, quest, inventory or save mutation.
	_preview_only = true
	session = Model.new()
	session.setup(100, 20, 18, 4, {"max_hp": 64})
	_arena.build(descriptor)
	_arena_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_resolved = false
	_busy = false
	_root.show()
	_continue.hide()
	for index: int in range(6):
		_pose(index, "idle")
	_refresh()
	_title.text = "戰鬥場景預覽"
	_preview.text = "立體場景 · 六人站位 · 相同種子重現相同配置"
	_log.text = "預覽不會進行戰鬥或變更存檔。"


func _texture(index: int, pose: String) -> Texture2D:
	var id: String = session.actors[index].art
	if id in ["wanderer", "noah", "elder"]:
		return load("res://assets/generated/%s_combat_%s.tres" % [id, pose]) as Texture2D
	return load("res://assets/generated/%s_%s.tres" % [id, pose]) as Texture2D


func _pose(index: int, pose: String) -> void:
	var texture := _texture(index, pose)
	if index < 3:
		var actor := str(session.actors[index].art)
		_portraits[index].call("dress", texture, pose, GameState.get_loadout(actor), actor)
		texture = _portraits[index].texture
	var texture_key := texture.get_instance_id()
	if not _baseline_cache.has(texture_key):
		# Prone art has dropped weapons below the body contact line.
		_baseline_cache[texture_key] = float(texture.get_meta("ground_y")) if texture.has_meta("ground_y") else Grounding.foot_baseline(texture, 0.5)
	# Raised weapons need extra canvas without shrinking the actor body.
	var default_height: float = 145.0 if session.actors[index].art == "moss_wolf" else 175.0
	var ratio: float = float(texture.get_meta("display_height", default_height)) / texture.get_height()
	_portraits[index].texture = texture
	_portraits[index].size = texture.get_size() * ratio
	_portraits[index].position = _point(index) - Vector2(_portraits[index].size.x * 0.5, float(_baseline_cache[texture_key]) * ratio)
	_shadows[index].position = _point(index)
	_shadows[index].scale = Vector2(1.8, 0.8) if pose == "defeated" else Vector2.ONE


func _physical_kind(index: int, action: String) -> String:
	if action == "slash":
		return "moon_slash"
	match str(session.actors[index].art):
		"noah": return "spear"
		"moss_wolf": return "claw"
		"elder", "eclipse_mage": return "staff"
	return "sword"


func _physical_texture(index: int, action: String) -> Texture2D:
	var kind := _physical_kind(index, action)
	var file: String = "sword_slash.png" if kind == "sword" else "%s_hit.tres" % kind
	return load("res://assets/generated/" + file) as Texture2D


func _physical_cue(index: int, action: String) -> StringName:
	var cues := {"sword": &"slash", "moon_slash": &"moon_slash", "spear": &"spear_thrust", "claw": &"claw_swipe", "staff": &"staff_strike"}
	return cues[_physical_kind(index, action)]


func _execute(action: String, target: int) -> void:
	_busy = true
	_ring.hide()
	_refresh()
	var caster: int = session.current
	_log.text = "%s 施展 %s……" % [session.actors[caster].name, Model.SKILLS[action].name]
	_pose(caster, "attack")
	if action in ["magic", "skill", "heal"]:
		_pose(caster, "windup")
		var cue: StringName = &"moon_heal" if action == "heal" else &"frost_nova" if action == "magic" else &"moon_bolt"
		GameAudio.play_cue(cue)
		if action == "skill":
			# Split the existing 220 ms launch/flight window without moving impact.
			await get_tree().create_timer(0.06).timeout
			_pose(caster, "attack")
			var bolt := TextureRect.new()
			bolt.name = "MoonBoltProjectile"
			bolt.z_index = 10
			bolt.texture = MoonBoltBurst.projectile_texture()
			bolt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bolt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			bolt.size = Vector2(104, 104)
			bolt.position = _point(caster) - Vector2(88, 142)
			bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stage.add_child(bolt)
			var flight := create_tween()
			flight.tween_property(bolt, "position", _point(target) - Vector2(88, 122), 0.16)
			await flight.finished
			bolt.queue_free()
		var burst: Node2D = HealingBurst.new() if action == "heal" else MoonBoltBurst.new() if action == "skill" else Burst.new()
		burst.position = _point(target)
		if action == "skill":
			burst.position.y -= 70.0
		burst.radius = float(Model.SKILLS[action].radius) * SCALE if action == "magic" else 72.0 if action == "heal" else 56.0
		if action == "magic":
			var ground_range := _projected_range(target, float(Model.SKILLS[action].radius))
			burst.scale = Vector2(absf(ground_range[0].x), absf(ground_range[16].y)) / burst.radius
		_stage.add_child(burst)
		await burst.impact
		_pose(caster, "attack")
		_apply(action, target)
		await burst.finished
		_pose(caster, "recover")
		await get_tree().create_timer(0.10).timeout
	elif action in ["guard", "potion", "protect"]:
		GameAudio.play_cue(&"heal" if action == "potion" else &"protect" if action == "protect" else &"guard")
		if action != "potion":
			_pose(caster, "guard")
		_apply(action, target)
		await get_tree().create_timer(0.22).timeout
	else:
		GameAudio.play_cue(_physical_cue(caster, action))
		var phased: bool = session.actors[caster].art in ["wanderer", "noah", "moss_wolf", "guardian", "elder", "eclipse_mage"]
		if phased:
			_pose(caster, "windup")
			await get_tree().create_timer(0.06).timeout
			_pose(caster, "attack")
		var home := _portraits[caster].position
		var direction: float = 26.0 if caster < 3 else -26.0
		var duration: float = 0.07 if phased else 0.13
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_portraits[caster], "position:x", home.x + direction, duration)
		tween.tween_property(_shadows[caster], "position:x", _point(caster).x + direction, duration)
		await tween.finished
		_apply(action, target)
		var slash := TextureRect.new()
		slash.name = "PhysicalHit"
		slash.z_index = 10
		slash.texture = _physical_texture(caster, action)
		slash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slash.size = Vector2.ONE * (130.0 if action == "slash" else 100.0)
		slash.flip_h = caster >= 3
		slash.position = _point(target) - slash.size * 0.5 - Vector2(0, 70)
		slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(slash)
		await get_tree().create_timer(0.16).timeout
		slash.queue_free()
		if phased:
			_pose(caster, "recover")
			var recovery_home := _portraits[caster].position
			_portraits[caster].position.x += direction
			_shadows[caster].position.x += direction
			var recovery := create_tween().set_parallel(true)
			recovery.tween_property(_portraits[caster], "position", recovery_home, 0.10)
			recovery.tween_property(_shadows[caster], "position", _point(caster), 0.10)
			await recovery.finished
		else:
			_portraits[caster].position = home
	for index: int in range(6):
		_pose(index, _resting_pose(index))
	if int(session.winner) != -1:
		_resolved = true
		_busy = false
		GameMusic.resolve_battle()
		GameAudio.play_cue(&"victory" if did_player_win() else &"defeat")
		if did_player_win():
			# Defeated companions recover between encounters; the traveler rises
			# at 1 HP on victory so exploration/save data never contains a dead lead.
			if GameState.player_hp == 0:
				session.actors[0].hp = 1
				GameState.sync_party_battle()
				_pose(0, _resting_pose(0))
			GameState.defeat_guardian()
		_log.text = "敵方全數倒下，獲得月光碎片！" if did_player_win() else "隊伍全數倒下……返回村莊休整。"
		_continue.text = "勝利！繼續" if did_player_win() else "戰敗…返回村莊"
		_continue.show()
		_refresh()
		_continue.grab_focus()
		return
	session.advance()
	for index: int in range(6):
		_pose(index, _resting_pose(index))
	_busy = false
	_action = "attack"
	var foes: Array[int] = session.living(1)
	if not foes.has(_target):
		_target = foes[0]
	_refresh()
	if int(session.actors[session.current].team) == 1:
		_busy = true
		_refresh()
		await get_tree().create_timer(0.3).timeout
		var allies: Array[int] = session.living(0)
		var selected: int = allies[(int(session.round_number) - 1) % allies.size()]
		var enemy_action := "magic" if session.actors[session.current].art == "eclipse_mage" and int(session.actors[session.current].mp) >= 8 else "attack"
		_execute(enemy_action, selected)
	else:
		_confirm.grab_focus()


func _resting_pose(index: int) -> String:
	if int(session.actors[index].hp) <= 0:
		return "defeated"
	if bool(session.actors[index].guard):
		return "guard"
	for actor: Dictionary in session.actors:
		if int(actor.protected_by) == index and int(actor.hp) > 0:
			return "guard"
	return "idle"


func _apply(action: String, target: int) -> void:
	var result: Dictionary = GameState.resolve_party_action(action, target)
	if result.has("error"):
		_log.text = result.error
		return
	if not result.damage.is_empty():
		GameAudio.play_cue(&"frost_impact" if action == "magic" else &"impact")
		for offset: int in range(result.targets.size()):
			var index: int = result.targets[offset]
			_pose(index, "hurt")
			_floating_text(index, "−%d" % int(result.damage[offset]), Color("fff0af"))
	elif int(result.healing) > 0:
		_floating_text(result.targets[0], "+%d" % int(result.healing), Color("9affb6"))
	elif action == "protect":
		_floating_text(target, "守護", Color("9ceaff"))
	_log.text = "%s：%s，影響 %d 名角色。" % [session.actors[session.current].name, Model.SKILLS[action].name, result.targets.size()]
	_refresh()


func _floating_text(index: int, text: String, color: Color) -> void:
	var number := Label.new()
	number.text = text
	number.position = _point(index) - Vector2(20, 120)
	number.add_theme_font_size_override("font_size", 28)
	number.add_theme_color_override("font_color", color)
	number.add_theme_constant_override("outline_size", 6)
	number.z_index = 20
	_stage.add_child(number)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(number, "position:y", number.position.y - 30, 0.55)
	tween.tween_property(number, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(number.queue_free)


func _refresh() -> void:
	var allowed := can_accept_action()
	_action_panel.visible = not _resolved and not _preview_only
	_title.text = "第 %d 回合  /  %s 行動" % [session.round_number, session.actors[session.current].name]
	var targets: Array[int] = []
	if allowed:
		targets = session.preview(_action, _target)
	for index: int in range(6):
		var actor: Dictionary = session.actors[index]
		_cards[index].text = "%s%s%s\nHP %d/%d  MP %d" % ["> " if session.current == index and not _resolved else "", actor.name, " [倒下]" if int(actor.hp) == 0 else (" [命中]" if targets.has(index) else ""), actor.hp, actor.max_hp, actor.mp]
		if session.is_protected(index) and int(actor.hp) > 0:
			_cards[index].text += " 守護"
		_cards[index].disabled = not allowed or _action in ["guard", "potion"] or session.preview(_action, index).is_empty()
		_portraits[index].modulate = Color("686473") if int(actor.hp) <= 0 else Color.WHITE
		_wards[index].visible = not _resolved and int(actor.hp) > 0 and session.is_protected(index)
		_wards[index].position = _point(index) - _wards[index].size * Vector2(0.5, 0.8)
		_shadows[index].color = Color(0.02, 0.02, 0.04, 0.5)
		var selected: bool = targets.has(index)
		var acting: bool = allowed and session.current == index
		var marked: bool = allowed and int(actor.hp) > 0 and (selected or acting)
		_selection_marks[index].visible = marked
		_selection_labels[index].visible = marked
		_selection_marks[index].position = _point(index)
		_selection_marks[index].points = PackedVector2Array([Vector2(-36, 0), Vector2(0, -11), Vector2(36, 0), Vector2(0, 11), Vector2(-36, 0)]) if selected else PackedVector2Array([Vector2(-28, 8), Vector2(-28, 13), Vector2(28, 13), Vector2(28, 8)])
		var selection_color := Color("a3eaff") if selected else Color("f1d39a")
		_selection_marks[index].default_color = selection_color
		_selection_labels[index].add_theme_color_override("font_color", selection_color)
		_selection_labels[index].position = _point(index) + Vector2(-70, 16)
		_selection_labels[index].text = ("治療" if _action == "heal" else "守護" if _action == "protect" else "自身" if _action in ["guard", "potion"] else "目標") if selected else "行動"
	for index: int in range(_actions.size()):
		var available: Array[String] = session.available_actions()
		_actions[index].visible = index < available.size()
		_actions[index].disabled = not allowed
		if index < available.size():
			var id: String = available[index]
			_actions[index].text = "%d %s%s  MP %d" % [index + 1, "> " if id == _action else "", Model.SKILLS[id].name, Model.SKILLS[id].cost]
	var error: String = session.validate(_action, _target)
	if _action == "potion" and int(GameState.inventory.get("potion", 0)) <= 0:
		error = "藥水已用完。"
	_confirm.disabled = not allowed or not error.is_empty()
	_confirm.text = "確認：%s" % Model.SKILLS[_action].name
	_preview.text = "行動演出中……" if _busy else "選技能 → 點卡片選目標 → 確認。"
	if allowed:
		_preview.text = "%s · MP %d · %s · 影響 %d 人 · 藥水 ×%d（Tab／Enter 操作）" % [Model.SKILLS[_action].name, Model.SKILLS[_action].cost, "範圍半徑 2" if _action == "magic" else "自身" if _action in ["guard", "potion"] else "單體", targets.size(), int(GameState.inventory.get("potion", 0))]
		if not error.is_empty():
			_preview.text = error
		elif _action in ["heal", "protect"]:
			_preview.text += " · 點選友方卡片"
	_ring.visible = allowed and _action == "magic"
	if _ring.visible:
		_ring.position = _point(_target)
		_ring.points = _projected_range(_target, float(Model.SKILLS.magic.radius))


func _finish_battle() -> void:
	if not is_resolved():
		return
	var victory := did_player_win()
	_root.hide()
	_arena_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	GameState.battle_session = null
	GameState.set_mode(GameState.Mode.EXPLORE)
	battle_finished.emit(victory)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active() or event.is_echo() or not event is InputEventKey or not event.pressed:
		return
	var key := event as InputEventKey
	if can_accept_action() and key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_6:
		_select_slot(key.physical_keycode - KEY_1)
		if not _confirm.disabled:
			_confirm.grab_focus()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.theme = GameState.ui_theme
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.color = Color("111321")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1120, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	box.add_child(_title)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(1120, 380)
	_stage.clip_contents = true
	box.add_child(_stage)
	var surface := SubViewportContainer.new()
	surface.name = "BattleArenaSurface"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(surface)
	_arena_viewport = SubViewport.new()
	_arena_viewport.name = "BattleArenaViewport"
	_arena_viewport.size = Vector2i(1120, 380)
	_arena_viewport.own_world_3d = true
	_arena_viewport.gui_disable_input = true
	_arena_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	surface.add_child(_arena_viewport)
	_arena = Arena3D.new()
	_arena_viewport.add_child(_arena)
	for index: int in range(6):
		var shadow := Polygon2D.new()
		var points := PackedVector2Array()
		for step: int in range(32):
			points.append(Vector2.from_angle(TAU * step / 32.0) * Vector2(30, 7))
		shadow.polygon = points
		_stage.add_child(shadow)
		_shadows.append(shadow)
		var selection := Line2D.new()
		selection.width = 2.0
		selection.hide()
		_stage.add_child(selection)
		_selection_marks.append(selection)
		var selection_label := Label.new()
		selection_label.size = Vector2(140, 24)
		selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		selection_label.add_theme_font_size_override("font_size", 14)
		selection_label.add_theme_constant_override("outline_size", 4)
		selection_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_label.z_index = 5
		selection_label.hide()
		_stage.add_child(selection_label)
		_selection_labels.append(selection_label)
		var ward := TextureRect.new()
		ward.texture = load("res://assets/generated/moon_ward.png") as Texture2D
		ward.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ward.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ward.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ward.size = Vector2(216, 216)
		ward.modulate.a = 0.85
		ward.z_index = 3
		ward.hide()
		_stage.add_child(ward)
		_wards.append(ward)
		var art: TextureRect = EquipmentPortrait.new() if index < 3 else TextureRect.new()
		art.size = Vector2(210, 175)
		var origin := Vector2(150, 215) if index < 3 else Vector2(650, 215)
		var offset := Vector2((index % 3) * 1.6, 0.8 if index % 3 == 1 else 0.0) * SCALE
		art.position = origin + offset - Vector2(105, 165)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.z_index = 2 if index % 3 == 1 else 1
		_stage.add_child(art)
		_portraits.append(art)
	_ring = Line2D.new()
	_ring.width = 2
	_ring.default_color = Color("a3eaff")
	for step: int in range(65):
		_ring.add_point(Vector2.from_angle(TAU * step / 64.0) * 2.0 * SCALE)
	_stage.add_child(_ring)
	var status := HBoxContainer.new()
	box.add_child(status)
	for index: int in range(6):
		var card := Button.new()
		card.custom_minimum_size = Vector2(180, 64)
		card.add_theme_font_size_override("font_size", 16)
		card.add_theme_color_override("font_disabled_color", Color("b8c6d7"))
		card.pressed.connect(_select_target.bind(index))
		status.add_child(card)
		_cards.append(card)
	_preview = Label.new()
	box.add_child(_preview)
	var actions := GridContainer.new()
	_action_panel = actions
	actions.columns = 4
	box.add_child(actions)
	for slot: int in range(6):
		var button := Button.new()
		button.custom_minimum_size = Vector2(274, 44)
		button.pressed.connect(_select_slot.bind(slot))
		actions.add_child(button)
		_actions.append(button)
	_confirm = Button.new()
	_confirm.custom_minimum_size = Vector2(274, 44)
	_confirm.pressed.connect(func() -> void: choose_action(_action))
	actions.add_child(_confirm)
	_log = Label.new()
	_log.custom_minimum_size.y = 34
	box.add_child(_log)
	_continue = Button.new()
	_continue.custom_minimum_size.y = 48
	_continue.pressed.connect(_finish_battle)
	box.add_child(_continue)
