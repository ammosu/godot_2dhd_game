extends Node2D
const Actor = preload("res://scripts/gameplay/layered_combat_actor.gd")
const FONT: Font = preload("res://assets/fonts/Cubic_11.ttf")
var actors: Array[Node2D] = []
var separated: bool = false
var bare: bool = false
var fingers: bool = true
var weapons: bool = true
var light_background: bool = false
var actor_id: String = "wanderer"
const NAMES: Dictionary = {"wanderer":"旅人", "noah":"諾亞", "elder":"長老"}


func _ready() -> void:
	get_window().title = "Wanderlight — 分層角色換裝"
	get_window().size = Vector2i(1280, 850)
	get_window().content_scale_size = Vector2i(1280, 850)
	separated = "--layers-separated" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--layers-actor="):
			var selected := argument.get_slice("=", 1)
			if NAMES.has(selected):
				actor_id = selected
	for index: int in range(3):
		var id: String = ["wanderer", "noah", "elder"][index]
		var button := Button.new()
		button.text = str(index+1) + " " + str(NAMES[id])
		button.position = Vector2(950+index*100,17)
		button.size = Vector2(90,34)
		button.add_theme_font_override("font", FONT)
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(func() -> void: actor_id = id; _refresh())
		add_child(button)
	for row: int in range(4):
		for col: int in range(4):
			var actor := Actor.new()
			add_child(actor)
			actors.append(actor)
	_refresh()
	if "--layers-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var path := "/tmp/wanderlight-layers-" + ("" if actor_id == "wanderer" else actor_id + "-") + ("separated-" if separated else "") + RenderingServer.get_current_rendering_method() + ".png"
		var result := get_viewport().get_texture().get_image().save_png(path)
		assert(result == OK)
		print("LAYERED_EQUIPMENT_CAPTURE ", path)
		for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
			get_node("/root/" + singleton).call("stop_all")
		get_tree().quit()


func _refresh() -> void:
	for row: int in range(4):
		for col: int in range(4):
			var actor: Node2D = actors[row*4+col]
			actor.position = Vector2(65+col*300, (105 + (23 if row == 3 else 0) if actor_id == "wanderer" else 120) + row*158)
			actor.scale = Vector2.ONE * (0.20 if separated else 0.30 if actor_id == "wanderer" else 0.25)
			actor.configure(Actor.POSES[row], "" if bare else "coat" if col < 2 else "moonward", "" if bare or not weapons else "blade" if col % 2 == 0 else "saber", separated, fingers, actor_id)
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: actor_id = "wanderer"
			KEY_2: actor_id = "noah"
			KEY_3: actor_id = "elder"
			KEY_E: separated = not separated
			KEY_B: bare = not bare
			KEY_H: fingers = not fingers
			KEY_W: weapons = not weapons
			KEY_SPACE: light_background = not light_background
			KEY_ESCAPE: get_tree().quit()
		_refresh()


func _draw() -> void:
	draw_rect(Rect2(0,0,1600,1200), Color("111a27"))
	draw_string(FONT, Vector2(30,40), "分層角色換裝 / " + str(NAMES[actor_id]), HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("efe2bd"))
	draw_string(FONT, Vector2(30,73), "共用身體與手掌 ＋ 獨立服裝 ＋ 獨立武器  →  即時組合 16 個外觀",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("b5c5d5"))
	var labels: Array[String] = ["旅人長衣 / 短刃", "旅人長衣 / 月鋼彎刀", "月守披風 / 短刃", "月守披風 / 月鋼彎刀"]
	if actor_id == "noah":
		labels = ["守門甲衣 / 長槍", "守門甲衣 / 曙光翼槍", "曙光鎧甲 / 長槍", "曙光鎧甲 / 曙光翼槍"]
	elif actor_id == "elder":
		labels = ["長老法袍 / 引燈木杖", "長老法袍 / 星月法杖", "星辰祭袍 / 引燈木杖", "星辰祭袍 / 星月法杖"]
	var poses: Array[String] = ["待機","攻擊","受傷","防禦"]
	for col: int in range(4):
		draw_string(FONT, Vector2(60+col*300,110),labels[col],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
		for row: int in range(4):
			draw_rect(Rect2(32+col*300,121+row*158,288,152),Color("999d9f") if light_background else Color("202e3e"))
	for row: int in range(4):
		draw_string(FONT,Vector2(35,143+row*158),poses[row],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a4b8ca"))
	draw_string(FONT,Vector2(30,793),"E：拆開圖層   B：角色底圖   W：武器   H：前景手掌   空白：底色   Esc：關閉",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("efe2bd"))
	draw_string(FONT,Vector2(30,825),"戰鬥四姿勢換裝測試；行走與其餘姿勢仍使用既有素材。",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("b5c5d5"))
