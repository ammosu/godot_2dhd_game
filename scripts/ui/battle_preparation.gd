extends AcceptDialog
const Presentation = preload("res://scripts/ui/presentation_theme.gd")
## One encounter's automation choices; the combat model owns the applied values.
signal options_confirmed(options: Dictionary)
var auto_mode: CheckButton
var skills: CheckButton
var potions: CheckButton
var threshold: OptionButton

func _ready() -> void:
	title = "戰鬥準備"
	borderless = true
	exclusive = true
	unresizable = true
	dialog_close_on_escape = false
	ok_button_text = "開始戰鬥"
	theme = theme.duplicate()
	theme.set_stylebox("panel", "AcceptDialog", Presentation.ornate_panel(24))
	# Primary action: brass-rimmed teal, brighter on hover/focus.
	var button_style := Presentation.panel(12)
	button_style.bg_color = Color("2f5e57")
	get_ok_button().add_theme_stylebox_override("normal", button_style)
	var hover: StyleBoxFlat = button_style.duplicate()
	hover.bg_color = Color("3f7a70")
	hover.border_color = Presentation.MINT
	get_ok_button().add_theme_stylebox_override("hover", hover)
	get_ok_button().add_theme_stylebox_override("pressed", hover)
	get_ok_button().add_theme_stylebox_override("focus", hover)
	get_ok_button().add_theme_font_size_override("font_size", 20)
	get_ok_button().custom_minimum_size = Vector2(180, 48)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(500, 360)
	list.add_theme_constant_override("separation", 10)
	add_child(list)
	var heading := Label.new()
	heading.theme_type_variation = &"TitleLabel"
	heading.text = "戰鬥準備"
	heading.add_theme_font_size_override("font_size", 26)
	list.add_child(heading)
	var description := Label.new()
	description.text = "選好作戰方式，再開始遺跡試煉。"
	list.add_child(description)
	auto_mode = _add_toggle(list, "開場啟用自動戰鬥")
	skills = _add_toggle(list, "自動使用技能（含同伴治療）")
	potions = _add_toggle(list, "自動喝藥水（目前操控角色）")
	var row := HBoxContainer.new()
	list.add_child(row)
	var caption := Label.new()
	caption.text = "喝藥門檻　HP ≤ "
	row.add_child(caption)
	threshold = OptionButton.new()
	threshold.custom_minimum_size = Vector2(150, 44)
	for percent: int in [30, 50, 70]:
		threshold.add_item("%d%%" % percent, percent)
	row.add_child(threshold)
	var note := Label.new()
	note.text = "藥水每瓶恢復最多 35 HP，消耗共享庫存。\n技能設定適用同伴 AI；喝藥僅在自動戰鬥時啟用。\n戰鬥中按 B 切換自動，移動或手動出招即可接手。"
	note.add_theme_font_size_override("font_size", 16)
	list.add_child(note)
	potions.toggled.connect(func(enabled: bool) -> void: threshold.disabled = not enabled)
	confirmed.connect(func() -> void:
		options_confirmed.emit({"auto": auto_mode.button_pressed, "skills": skills.button_pressed, "potions": potions.button_pressed, "threshold": float(threshold.get_selected_id()) / 100.0})
	)

func open_choices() -> void:
	auto_mode.set_pressed_no_signal(true)
	skills.set_pressed_no_signal(true)
	potions.set_pressed_no_signal(false)
	threshold.select(0)
	threshold.disabled = true
	popup_centered()
	auto_mode.grab_focus()

func _add_toggle(parent: VBoxContainer, text: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.custom_minimum_size.y = 48
	parent.add_child(toggle)
	return toggle
