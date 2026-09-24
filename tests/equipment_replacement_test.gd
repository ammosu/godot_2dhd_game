extends SceneTree
const Appearance = preload("res://scripts/gameplay/equipment_appearance.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	var combinations: Array[Dictionary] = [
		{"weapon": "traveler_blade", "armor": "traveler_coat"},
		{"weapon": "moonsteel_saber", "armor": "traveler_coat"},
		{"weapon": "traveler_blade", "armor": "moonward_cloak"},
		{"weapon": "moonsteel_saber", "armor": "moonward_cloak"},
	]
	var names: Array[String] = ["", "saber", "moonward", "moonward_saber"]
	for index: int in range(combinations.size()):
		var gear: Dictionary = combinations[index]
		var frames := Appearance.walking_frames(gear)
		for direction: StringName in Appearance.WALK.get_animation_names():
			check(frames.get_frame_texture(direction, 0) != frames.get_frame_texture(direction, 1), "Walking animation collapsed to a single frame")
			for frame: int in range(4):
				var base := Appearance.WALK.get_frame_texture(direction, frame)
				var art := frames.get_frame_texture(direction, frame) as AtlasTexture
				check(art != null, "Missing walking atlas")
				if index == 0:
					check(art == Appearance.STEADY_WALK.get_frame_texture(direction, frame), "Default loadout did not restore steady walking art")
					_check_bounds(art)
				else:
					if base.has_meta("diagonal_frame") and frame == 3:
						check(art.atlas.resource_path.ends_with("diagonal_contact_b.png") and art.get_meta("contact_variant", "") == names[index], "Wrong opposite-foot outfit")
					else:
						check(art.atlas.resource_path.ends_with(names[index] + ("_diagonal_walk.png" if base.has_meta("diagonal_frame") else "_walk.png")), "Wrong independent weapon/armor combination")
					_check_bounds(art)
		for pose: String in Appearance.POSES:
			var base := load("res://assets/generated/wanderer_combat_%s.tres" % pose) as Texture2D
			var art := Appearance.texture_for(base, pose, gear) as AtlasTexture
			if index == 0:
				check(art == base, "Original combat art changed")
			else:
				check(str(art.get_meta("variant")) == names[index], "Battle outfit variant mismatch")
				check(art.atlas != (base as AtlasTexture).atlas, "New gear still using original body atlas")
				_check_bounds(art)
				var old_ground: float = base.get_meta("ground_y", preload("res://scripts/gameplay/sprite_grounding.gd").foot_baseline(base, 0.5))
				var ratio: float = float(art.get_meta("display_height")) / art.get_height()
				check(is_equal_approx(ratio, 175.0 / base.get_height()), "Replacement changed body scale")
				check(is_equal_approx(float(art.get_meta("ground_y")) - Appearance.PAD.y, old_ground), "Replacement changed grounding origin")
	if failures == 0:
		print("EQUIPMENT_REPLACEMENT_TEST_PASS four_loadouts 128_walk_frames 28_battle_poses original_restore alpha bounds scale")
	quit(0 if failures == 0 else 1)


func _check_bounds(art: AtlasTexture) -> void:
	var image := art.atlas.get_image()
	check(image != null and image.get_pixel(0, 0).a == 0.0, "Replacement sheet has opaque background")
	check(Rect2(Vector2.ZERO, art.atlas.get_size()).encloses(art.region), "Atlas crop outside sheet: %s %s / %s" % [art.atlas.resource_path, art.region, art.atlas.get_size()])
	check(art.margin.position.x >= 0 and art.margin.position.y >= 0, "Negative crop margin")
	check(art.margin.position.x + art.region.size.x <= art.get_width() + 0.01 and art.margin.position.y + art.region.size.y <= art.get_height() + 0.01, "Invalid logical canvas")
