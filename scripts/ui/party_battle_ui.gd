class_name PartyBattleUI
extends CanvasLayer

signal battle_finished(victory: bool)
const Model = preload("res://scripts/systems/party_battle.gd")
const Burst = preload("res://scripts/ui/magic_burst.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const SCALE: float = 56.0
var session: RefCounted
var _root: Control
var _stage: Control
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
	session = GameState.begin_party_battle(enemy)
	_resolved = false
	_busy = false
	_target = 3
	_action = "attack"
	_root.show()
	_continue.hide()
	_log.text = "旅人、諾亞與長老並肩迎敵。選技能 → 選目標 → 確認。"
	for index: int in range(6):
		_pose(index, "idle")
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
	return is_active() and not _resolved and not _busy and int(session.actors[session.current].team) == 0


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
	if not can_accept_action():
		return
	_action = action
	_refresh()


func _select_target(index: int) -> void:
	if not can_accept_action() or index < 3 or int(session.actors[index].hp) <= 0:
		return
	_target = index
	_refresh()


func _point(index: int) -> Vector2:
	var origin := Vector2(150, 215) if index < 3 else Vector2(650, 215)
	return origin + Vector2(session.actors[index].position) * SCALE


func _texture(index: int, pose: String) -> Texture2D:
	var id: String = session.actors[index].art
	if id == "noah" or id == "elder":
		return load("res://assets/generated/%s.tres" % id) as Texture2D
	if id == "wanderer":
		return load("res://assets/generated/wanderer_combat_%s.tres" % pose) as Texture2D
	return load("res://assets/generated/%s_%s.tres" % [id, pose]) as Texture2D


func _pose(index: int, pose: String) -> void:
	var texture := _texture(index, pose)
	if not _baseline_cache.has(texture.resource_path):
		_baseline_cache[texture.resource_path] = Grounding.foot_baseline(texture, 0.5)
	var ratio: float = (145.0 if session.actors[index].art == "moss_wolf" else 175.0) / texture.get_height()
	_portraits[index].texture = texture
	_portraits[index].size = texture.get_size() * ratio
	_portraits[index].position = _point(index) - Vector2(_portraits[index].size.x * 0.5, float(_baseline_cache[texture.resource_path]) * ratio)
	_shadows[index].position = _point(index)


func _execute(action: String, target: int) -> void:
	_busy = true
	_ring.hide()
	_refresh()
	var caster: int = session.current
	_log.text = "%s 施展 %s……" % [session.actors[caster].name, Model.SKILLS[action].name]
	_pose(caster, "attack")
	if action == "magic" or action == "skill":
		GameAudio.play_cue(&"skill")
		if action == "skill":
			var bolt := TextureRect.new()
			var texture := AtlasTexture.new()
			texture.atlas = Burst.ATLAS
			texture.region = Rect2(Vector2.ZERO, Burst.ATLAS.get_size() * 0.5)
			bolt.texture = texture
			bolt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bolt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			bolt.size = Vector2(80, 80)
			bolt.position = _point(caster) - Vector2(40, 110)
			bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stage.add_child(bolt)
			var flight := create_tween()
			flight.tween_property(bolt, "position", _point(target) - Vector2(40, 100), 0.22)
			await flight.finished
			bolt.queue_free()
		var burst := Burst.new()
		burst.position = _point(target)
		burst.radius = float(Model.SKILLS[action].radius) * SCALE if action == "magic" else 48.0
		_stage.add_child(burst)
		await burst.impact
		_apply(action, target)
		await burst.finished
	elif action == "guard" or action == "potion":
		GameAudio.play_cue(&"guard" if action == "guard" else &"heal")
		_apply(action, target)
		await get_tree().create_timer(0.22).timeout
	else:
		GameAudio.play_cue(&"slash")
		var home := _portraits[caster].position
		var tween := create_tween()
		tween.tween_property(_portraits[caster], "position:x", home.x + (26 if caster < 3 else -26), 0.13)
		await tween.finished
		_apply(action, target)
		var slash := TextureRect.new()
		slash.texture = load("res://assets/generated/sword_slash.png") as Texture2D
		slash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slash.size = Vector2(100, 100)
		slash.position = _point(target) - Vector2(50, 100)
		slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(slash)
		await get_tree().create_timer(0.16).timeout
		slash.queue_free()
		_portraits[caster].position = home
	for index: int in range(6):
		_pose(index, "idle" if int(session.actors[index].hp) > 0 else "hurt")
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
			GameState.defeat_guardian()
		_log.text = "敵方全數倒下，獲得月光碎片！" if did_player_win() else "隊伍全數倒下……返回村莊休整。"
		_continue.text = "勝利！繼續" if did_player_win() else "戰敗…返回村莊"
		_continue.show()
		_refresh()
		_continue.grab_focus()
		return
	session.advance()
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


func _apply(action: String, target: int) -> void:
	var result: Dictionary = GameState.resolve_party_action(action, target)
	if result.has("error"):
		_log.text = result.error
		return
	if action != "guard" and action != "potion":
		GameAudio.play_cue(&"impact")
		for offset: int in range(result.targets.size()):
			var index: int = result.targets[offset]
			_pose(index, "hurt")
			var number := Label.new()
			number.text = "−%d" % int(result.damage[offset])
			number.position = _point(index) - Vector2(20, 120)
			number.add_theme_font_size_override("font_size", 28)
			number.add_theme_color_override("font_color", Color("fff0af"))
			number.add_theme_constant_override("outline_size", 6)
			number.z_index = 20
			_stage.add_child(number)
			var tween := create_tween().set_parallel(true)
			tween.tween_property(number, "position:y", number.position.y - 30, 0.55)
			tween.tween_property(number, "modulate:a", 0.0, 0.55)
			tween.chain().tween_callback(number.queue_free)
	_log.text = "%s：%s，影響 %d 名角色。" % [session.actors[session.current].name, Model.SKILLS[action].name, result.targets.size()]
	_refresh()


func _refresh() -> void:
	var allowed := can_accept_action()
	_action_panel.visible = not _resolved
	_title.text = "第 %d 回合  /  %s 行動" % [session.round_number, session.actors[session.current].name]
	var targets: Array[int] = []
	if allowed:
		targets = session.preview(_action, _target)
	for index: int in range(6):
		var actor: Dictionary = session.actors[index]
		_cards[index].text = "%s%s%s\nHP %d/%d  MP %d" % ["▶ " if session.current == index and not _resolved else "", actor.name, " [倒下]" if int(actor.hp) == 0 else (" [命中]" if targets.has(index) else ""), actor.hp, actor.max_hp, actor.mp]
		_cards[index].disabled = not allowed or index < 3 or int(actor.hp) <= 0
		_portraits[index].modulate = Color("686473") if int(actor.hp) <= 0 else Color.WHITE
		_shadows[index].color = Color(0.4, 0.85, 1.0, 0.6) if targets.has(index) else Color(0.02, 0.02, 0.04, 0.5)
	for index: int in range(_actions.size()):
		_actions[index].disabled = not allowed
	_confirm.disabled = not allowed or not session.validate(_action, _target).is_empty()
	_confirm.text = "確認：%s" % Model.SKILLS[_action].name
	_preview.text = "選技能 → 點敵方卡片選目標 → 確認；霜星爆依站位命中半徑內敵人。"
	if allowed:
		_preview.text = "%s · MP %d · %s · 影響 %d 人 · 藥水 ×%d（Tab／Enter 操作）" % [Model.SKILLS[_action].name, Model.SKILLS[_action].cost, "範圍半徑 2" if _action == "magic" else "自身" if _action in ["guard", "potion"] else "單體", targets.size(), int(GameState.inventory.get("potion", 0))]
	_ring.visible = allowed and _action == "magic"
	if _ring.visible:
		_ring.position = _point(_target)


func _finish_battle() -> void:
	if not is_resolved():
		return
	var victory := did_player_win()
	_root.hide()
	GameState.battle_session = null
	GameState.set_mode(GameState.Mode.EXPLORE)
	battle_finished.emit(victory)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active() or event.is_echo() or not event is InputEventKey or not event.pressed:
		return
	var key := event as InputEventKey
	var shortcuts := {KEY_1: "attack", KEY_2: "skill", KEY_3: "potion", KEY_4: "guard", KEY_5: "magic"}
	if can_accept_action() and shortcuts.has(key.physical_keycode):
		_select_action(shortcuts[key.physical_keycode])
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
	var background := TextureRect.new()
	background.texture = load("res://assets/generated/ruins_battle_background.png") as Texture2D
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(background)
	for index: int in range(6):
		var shadow := Polygon2D.new()
		var points := PackedVector2Array()
		for step: int in range(32):
			points.append(Vector2.from_angle(TAU * step / 32.0) * Vector2(30, 7))
		shadow.polygon = points
		_stage.add_child(shadow)
		_shadows.append(shadow)
		var art := TextureRect.new()
		art.size = Vector2(210, 175)
		var origin := Vector2(150, 215) if index < 3 else Vector2(650, 215)
		var offset := Vector2((index % 3) * 1.6, 0.8 if index % 3 == 1 else 0.0) * SCALE
		art.position = origin + offset - Vector2(105, 165)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	actions.columns = 3
	box.add_child(actions)
	for id: String in ["attack", "skill", "magic", "guard", "potion"]:
		var button := Button.new()
		button.text = "%s  MP %d" % [Model.SKILLS[id].name, Model.SKILLS[id].cost]
		button.custom_minimum_size = Vector2(368, 44)
		button.pressed.connect(_select_action.bind(id))
		actions.add_child(button)
		_actions.append(button)
	_confirm = Button.new()
	_confirm.custom_minimum_size = Vector2(368, 44)
	_confirm.pressed.connect(func() -> void: choose_action(_action))
	actions.add_child(_confirm)
	_log = Label.new()
	_log.custom_minimum_size.y = 34
	box.add_child(_log)
	_continue = Button.new()
	_continue.custom_minimum_size.y = 48
	_continue.pressed.connect(_finish_battle)
	box.add_child(_continue)
