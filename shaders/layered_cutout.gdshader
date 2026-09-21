shader_type canvas_item;

// Generated sheets occasionally retain alpha 1–4/255 in empty space.
// Keep the original PNG intact; remove only near-transparent residue at display.
void fragment() {
	if (COLOR.a < 0.02) {
		COLOR.a = 0.0;
	}
}
