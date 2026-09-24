class_name PartyBattleUI
extends CanvasLayer

signal battle_finished(victory: bool)
const AutoBattle = preload("res://scripts/systems/party_auto_battle.gd")
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
var _drag_handles: Array[Control] = []
var _cards: Array[Button] = []
var _stat_names: Array[Label] = []
var _hp_bars: Array[ProgressBar] = []
var _mp_bars: Array[ProgressBar] = []
var _speed_bars: Array[ProgressBar] = []
var _planners: Array[Button] = []
var _auto_button: Button
var _auto_enabled: bool = false
var _auto_generation: int = 0
var _round_button: Button
var _planning_panel: HBoxContainer
var _formation_hint: Label
var _actions: Array[Button] = []
var _row_buttons: Array[Button] = []
var _formation_panel: HBoxContainer
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
	_auto_enabled = false
	_auto_generation += 1
	session = GameState.begin_party_battle(enemy)
	_arena.build(GameState.battle_visual)
	_arena_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_resolved = false
	_busy = false
	_target = 3
	_action = "attack"
	_root.show()
	_continue.hide()
	_log.text = "先安排每位同伴的動作，再開始回合；拖曳友方角色可交換站位。"
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
	return not _auto_enabled and _can_plan()


func _can_plan() -> bool:
	return is_active() and not _preview_only and not _resolved and not _busy and not session.executing and int(session.actors[session.current].team) == 0


func _toggle_auto() -> void:
	if not is_active() or _preview_only or _resolved:
		return
	_auto_enabled = not _auto_enabled
	_auto_generation += 1
	_log.text = "自動戰鬥已開啟：自動使用技能與治療，不使用藥水。" if _auto_enabled else "自動戰鬥已關閉，本回合結束後交還操作。" if _busy else "已切回手動安排。"
	if not _auto_enabled and _can_plan():
		_select_planner(int(session.current))
	_refresh()
	if _auto_enabled:
		_schedule_auto()


func _schedule_auto() -> void:
	if not _auto_enabled or not _can_plan():
		return
	var generation: int = _auto_generation
	var encounter: RefCounted = session
	# Give the player a visible pause between rounds and time to turn auto off.
	await get_tree().create_timer(0.65).timeout
	if generation != _auto_generation or session != encounter or not _auto_enabled or not _can_plan():
		return
	var error: String = AutoBattle.plan_round(session, int(GameState.inventory.get("potion", 0)))
	if not error.is_empty():
		_auto_enabled = false
		_auto_generation += 1
		_log.text = error
		_refresh()
		return
	_run_round(true)


func choose_action(action: String) -> void:
	if not can_accept_action():
		return
	var error: String = session.plan_action(action, _target, int(GameState.inventory.get("potion", 0)))
	if not error.is_empty():
		_log.text = error
		return
	_log.text = "%s 已安排%s；全隊安排完成後按「開始回合」。" % [session.actors[session.current].name, Model.SKILLS[action].name]
	for index: int in session.living(0):
		if not session.plans.has(index):
			_select_planner(index)
			return
	_refresh()
	_round_button.grab_focus()


func _select_planner(index: int) -> void:
	if not can_accept_action() or index not in session.living(0):
		return
	session.current = index
	_action = str(session.plans[index].action) if session.plans.has(index) else "attack"
	_target = int(session.plans[index].target) if session.plans.has(index) else 3
	_select_action(_action)


func _run_round(automatic: bool = false) -> void:
	if not _can_plan() or (_auto_enabled and not automatic):
		return
	var error: String = session.begin_round(int(GameState.inventory.get("potion", 0)))
	if not error.is_empty():
		_log.text = error
		_auto_enabled = false
		_auto_generation += 1
		_refresh()
		return
	_busy = true
	_refresh()
	while int(session.winner) == -1:
		var command: Dictionary = session.next_command(int(GameState.inventory.get("potion", 0)))
		if command.is_empty():
			break
		_action = str(command.action)
		_target = int(command.target)
		await _execute(_action, _target)
	if _resolved:
		return
	session.finish_round()
	_busy = false
	for index: int in range(6):
		_pose(index, _resting_pose(index))
	_log.text = "自動戰鬥：即將安排下一回合，可點開關停止。" if _auto_enabled else "新回合：可拖曳交換一次站位，並安排全隊動作。"
	if _auto_enabled:
		_refresh()
		_schedule_auto()
	else:
		_select_planner(int(session.current))
		_confirm.grab_focus()


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


func _change_row(row: int) -> void:
	if not can_accept_action():
		return
	var error: String = session.change_row(row)
	if not error.is_empty():
		_log.text = error
		return
	for index: int in range(6):
		_pose(index, _resting_pose(index))
	_log.text = "%s 移至%s，與該排同伴交換；仍可使用指令。" % [session.actors[session.current].name, Model.ROW_NAMES[row]]
	_select_action(_action)


func _drag_actor(_position: Vector2, index: int) -> Variant:
	if not can_accept_action() or session.formation_changed or index not in session.living(0):
		return null
	var ghost := Label.new()
	ghost.theme = GameState.ui_theme
	ghost.text = "%s → 拖到同伴身上交換" % session.actors[index].name
	ghost.add_theme_font_size_override("font_size", 18)
	ghost.add_theme_constant_override("outline_size", 4)
	_root.set_drag_preview(ghost)
	return {"battle": get_instance_id(), "actor": index}


func _can_drop_actor(_position: Vector2, data: Variant, index: int) -> bool:
	return can_accept_action() and not session.formation_changed and index < 3 and data is Dictionary and data.get("battle", 0) == get_instance_id() and int(data.get("actor", -1)) in session.living(0) and int(data.actor) != index


func _drop_actor(position: Vector2, data: Variant, index: int) -> void:
	if not _can_drop_actor(position, data, index):
		return
	var error: String = session.swap_allies(int(data.actor), index)
	if not error.is_empty():
		_log.text = error
		return
	for actor: int in range(6):
		_pose(actor, _resting_pose(actor))
	_log.text = "已交換站位，本回合無法再次交換。"
	_select_action(_action)


func _world_point(index: int) -> Vector3:
	var point: Vector2 = session.actors[index].position
	return Vector3((-3.0 - point.x * WORLD_SCALE) if index < 3 else (3.0 + point.x * WORLD_SCALE), 0.0, point.y * WORLD_SCALE)


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
	_auto_enabled = false
	_auto_generation += 1
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
	var ratio: float = 175.0 / float(texture.get_meta("body_height")) if index < 3 and texture.has_meta("body_height") else float(texture.get_meta("display_height", default_height)) / texture.get_height()
	_portraits[index].texture = texture
	_portraits[index].size = texture.get_size() * ratio * Vector2(float(texture.get_meta("width_scale", 1.0)), 1.0)
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
		_auto_enabled = false
		_auto_generation += 1
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

	_busy = bool(session.executing)
	_refresh()


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
	_auto_button.visible = not _preview_only and not _resolved
	_auto_button.disabled = _preview_only or _resolved
	_auto_button.text = "自動戰鬥：開（點此停止）" if _auto_enabled else "自動戰鬥：關"
	_auto_button.set_pressed_no_signal(_auto_enabled)
	_action_panel.visible = not _resolved and not _preview_only
	_formation_panel.visible = not _resolved and not _preview_only
	_planning_panel.visible = not _resolved and not _preview_only
	_formation_hint.text = "站位：本回合已交換" if session.formation_changed else "拖曳角色交換（全隊每回合一次）"
	_round_button.disabled = not allowed or not session.ready_to_resolve()
	for index: int in range(_planners.size()):
		var plan: Dictionary = session.plans.get(index, {})
		_planners[index].disabled = not allowed or int(session.actors[index].hp) <= 0
		_planners[index].text = "%s%s：%s" % ["> " if session.current == index else "", session.actors[index].name, "倒下" if int(session.actors[index].hp) <= 0 else "待安排" if plan.is_empty() else "%s → %s" % [Model.SKILLS[plan.action].name, session.actors[int(plan.target)].name]]
	for row: int in range(_row_buttons.size()):
		_row_buttons[row].disabled = not allowed or session.formation_changed or int(session.actors[session.current].row) == row
	var order_names: PackedStringArray = []
	for index: int in session.initiative_order():
		order_names.append(str(session.actors[index].name))
	_title.text = "第 %d 回合 · %s  |  速度順序：%s" % [session.round_number, "出手中" if session.executing else "自動安排" if _auto_enabled else "安排動作", " → ".join(order_names)]
	var targets: Array[int] = []
	if allowed:
		targets = session.preview(_action, _target)
	for index: int in range(6):
		var actor: Dictionary = session.actors[index]
		_drag_handles[index].position = _point(index) - Vector2(38, 140)
		_drag_handles[index].mouse_filter = Control.MOUSE_FILTER_STOP if allowed and index < 3 else Control.MOUSE_FILTER_IGNORE
		_stat_names[index].text = "%s · %s" % [actor.name, "倒下" if int(actor.hp) == 0 else Model.ROW_NAMES[int(actor.row)]]
		_update_stat_bar(_hp_bars[index], "HP", int(actor.hp), int(actor.max_hp))
		_update_stat_bar(_mp_bars[index], "MP", int(actor.mp), int(actor.max_mp))
		_update_stat_bar(_speed_bars[index], "SPD", int(actor.speed), 30)
		(_speed_bars[index].get_node("Value") as Label).text = "速度 %d" % int(actor.speed)
		if session.is_protected(index) and int(actor.hp) > 0:
			(_mp_bars[index].get_node("Value") as Label).text += " 守護"
		_cards[index].position = _point(index) + Vector2(-82, 56 if int(actor.row) == 1 else 7)
		_cards[index].tooltip_text = session.validate(_action, index) if allowed else ""
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
		_selection_labels[index].position = _point(index) + Vector2(-70, -28)
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
	_confirm.text = "安排：%s" % Model.SKILLS[_action].name
	_preview.text = "行動演出中……" if _busy else "自動戰鬥即將開始下一回合，可點開關停止。" if _auto_enabled else "安排全隊動作 → 開始回合。"
	if allowed:
		_preview.text = "%s · MP %d · %s · 影響 %d 人 · 藥水 ×%d" % [Model.SKILLS[_action].name, Model.SKILLS[_action].cost, "範圍半徑 2" if _action == "magic" else "自身" if _action in ["guard", "potion"] else "單體", targets.size(), int(GameState.inventory.get("potion", 0))]
		_preview.text += " · 近戰射程 %d 排" % session.attack_reach(_action) if _action in ["attack", "slash"] else " · 無視前排阻擋" if _action in ["magic", "skill"] else ""
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
	_auto_enabled = false
	_auto_generation += 1
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


func _make_stat_bar(card: Button, top: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = Vector2(8, top)
	bar.size = Vector2(148, 14)
	bar.show_percentage = false
	bar.add_theme_font_size_override("font_size", 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("1a2335")
	background.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	card.add_child(bar)
	var value_label := Label.new()
	value_label.name = "Value"
	value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.add_theme_color_override("font_outline_color", Color("101622"))
	value_label.add_theme_constant_override("outline_size", 3)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(value_label)
	bar.size = Vector2(148, 14)
	return bar


func _update_stat_bar(bar: ProgressBar, stat: String, value: int, maximum: int) -> void:
	# A zero-MP actor still has an empty track; avoid a zero-sized Range.
	bar.max_value = maxi(1, maximum)
	bar.value = value
	(bar.get_node("Value") as Label).text = "%s %d/%d" % [stat, value, maximum]


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
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.add_theme_font_size_override("font_size", 18)
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
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.z_index = 2 if index % 3 == 1 else 1
		_stage.add_child(art)
		_portraits.append(art)
		# Tight body hit boxes avoid dragging a neighbour through the large
		# transparent margins of the combat atlases.
		var handle := Control.new()
		handle.size = Vector2(76, 140)
		handle.z_index = 4
		handle.mouse_default_cursor_shape = Control.CURSOR_DRAG
		handle.set_drag_forwarding(_drag_actor.bind(index), _can_drop_actor.bind(index), _drop_actor.bind(index))
		_stage.add_child(handle)
		_drag_handles.append(handle)
	_ring = Line2D.new()
	_ring.width = 2
	_ring.default_color = Color("a3eaff")
	for step: int in range(65):
		_ring.add_point(Vector2.from_angle(TAU * step / 64.0) * 2.0 * SCALE)
	_stage.add_child(_ring)
	for index: int in range(6):
		var card := Button.new()
		card.custom_minimum_size = Vector2(164, 64)
		card.add_theme_font_size_override("font_size", 14)
		card.z_index = 6
		for state: String in ["normal", "disabled", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.06, 0.08, 0.13, 0.92)
			style.border_color = Color("a3eaff") if state in ["hover", "focus"] else Color("46516a")
			style.set_border_width_all(2 if state == "focus" else 1)
			style.set_corner_radius_all(4)
			card.add_theme_stylebox_override(state, style)
		card.add_theme_color_override("font_disabled_color", Color("b8c6d7"))
		card.pressed.connect(_select_target.bind(index))
		card.set_drag_forwarding(_drag_actor.bind(index), _can_drop_actor.bind(index), _drop_actor.bind(index))
		_stage.add_child(card)
		_cards.append(card)
		var stat_name := Label.new()
		stat_name.position = Vector2(4, 3)
		stat_name.size = Vector2(156, 18)
		stat_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_name.add_theme_font_size_override("font_size", 14)
		card.add_child(stat_name)
		_stat_names.append(stat_name)
		_hp_bars.append(_make_stat_bar(card, 20.0, Color("399768")))
		_mp_bars.append(_make_stat_bar(card, 34.0, Color("386ec2")))
		_speed_bars.append(_make_stat_bar(card, 48.0, Color("a57d31")))
	_formation_panel = HBoxContainer.new()
	box.add_child(_formation_panel)
	_formation_hint = Label.new()
	_formation_hint.text = "站位交換（全隊每回合限一次）："
	_formation_panel.add_child(_formation_hint)
	for row: int in range(3):
		var button := Button.new()
		button.text = Model.ROW_NAMES[row]
		button.custom_minimum_size = Vector2(128, 44)
		button.pressed.connect(_change_row.bind(row))
		_formation_panel.add_child(button)
		_row_buttons.append(button)
	_auto_button = Button.new()
	_auto_button.toggle_mode = true
	_auto_button.custom_minimum_size = Vector2(254, 44)
	_auto_button.add_theme_font_size_override("font_size", 16)
	_auto_button.tooltip_text = "接管全隊指令，自動施法、治療與攻擊；不使用藥水、不更換站位。可隨時停止，正在執行的回合會先完成。"
	_auto_button.pressed.connect(_toggle_auto)
	_formation_panel.add_child(_auto_button)
	_planning_panel = HBoxContainer.new()
	box.add_child(_planning_panel)
	for index: int in range(3):
		var planner := Button.new()
		planner.custom_minimum_size = Vector2(278, 40)
		planner.add_theme_font_size_override("font_size", 14)
		planner.pressed.connect(_select_planner.bind(index))
		_planning_panel.add_child(planner)
		_planners.append(planner)
	_round_button = Button.new()
	_round_button.text = "開始回合"
	_round_button.custom_minimum_size = Vector2(274, 40)
	_round_button.pressed.connect(_run_round)
	_planning_panel.add_child(_round_button)
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
