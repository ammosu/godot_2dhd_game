extends Control
## Asset review only: does not start combat or modify GameState.

const ENEMIES: Array[Dictionary] = [
	{"name": "苔背狼", "prefix": "moss_wolf"},
	{"name": "月蝕術士", "prefix": "eclipse_mage"},
]
const POSES: Array[String] = ["idle", "attack", "hurt"]
const LABELS: Array[String] = ["待機", "攻擊", "受擊"]


func _ready() -> void:
	theme = GameState.ui_theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("202333")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	var title := Label.new()
	title.text = "角色戰鬥素材預覽 · 非遭遇戰"
	title.add_theme_font_size_override("font_size", 26)
	rows.add_child(title)
	for enemy: Dictionary in ENEMIES:
		var heading := Label.new()
		heading.text = enemy.name
		rows.add_child(heading)
		var columns := HBoxContainer.new()
		columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rows.add_child(columns)
		for index: int in range(POSES.size()):
			var card := VBoxContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			columns.add_child(card)
			var art := TextureRect.new()
			art.texture = load("res://assets/generated/%s_%s.tres" % [enemy.prefix, POSES[index]]) as Texture2D
			art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.size_flags_vertical = Control.SIZE_EXPAND_FILL
			card.add_child(art)
			var caption := Label.new()
			caption.text = LABELS[index]
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(caption)
