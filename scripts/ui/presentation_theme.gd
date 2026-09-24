extends RefCounted
## Shared ink, brass and moonlight surfaces. All text uses the bundled UI font.
const INK := Color(0.035, 0.065, 0.10, 0.94)
const GOLD := Color("c9a66c")
const PAPER := Color("f3eee1")
const MUTED := Color("b0bcc8")
const MINT := Color("a1e6dd")

static func panel(padding: float = 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(padding)
	style.shadow_color = Color(0.01, 0.02, 0.04, 0.28)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style

static func apply(theme: Theme) -> void:
	theme.set_color("font_color", "Label", PAPER)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := panel(12)
		if state == "hover":
			style.bg_color = Color("243e4c")
			style.border_color = MINT
		elif state == "pressed":
			style.bg_color = Color("345563")
		elif state == "disabled":
			style.border_color = Color("43505a")
		elif state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = MINT
			style.set_border_width_all(2)
			style.shadow_size = 0
		theme.set_stylebox(state, "Button", style)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", PAPER)
	theme.set_color("font_disabled_color", "Button", Color("778592"))
