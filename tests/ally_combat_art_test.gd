extends SceneTree
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")

func _initialize() -> void:
	var failures: int = 0
	for id: String in ["noah", "elder"]:
		for pose: String in ["idle", "attack", "hurt", "guard"]:
			var texture := load("res://assets/generated/%s_combat_%s.tres" % [id, pose]) as AtlasTexture
			if texture == null or texture.get_size() != Vector2(800, 640):
				push_error("Invalid companion atlas canvas: " + id + "/" + pose)
				failures += 1
				continue
			if not Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region):
				push_error("Companion crop outside atlas")
				failures += 1
			if absf(Grounding.foot_baseline(texture, 0.5) - 616.0) > 1.0:
				push_error("Companion pose foot baseline changed: " + id + "/" + pose)
				failures += 1
	if failures == 0:
		print("ALLY_COMBAT_ART_TEST_PASS eight_poses crops canvas grounded_feet")
	quit(0 if failures == 0 else 1)
