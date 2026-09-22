extends SceneTree
const Art = preload("res://scripts/gameplay/action_sprite_library.gd")
const Model = preload("res://scripts/systems/action_battle.gd")
const Effect = preload("res://scripts/gameplay/world_combat_effect.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	for actor_id: String in ["wanderer", "noah", "elder"]:
		for armor: bool in [false, true]:
			for weapon: bool in [false, true]:
				var loadout: Dictionary = {}
				if armor:
					loadout.armor = "moonward_cloak" if actor_id == "wanderer" else "dawn_plate" if actor_id == "noah" else "astral_robe"
				if weapon:
					loadout.weapon = "moonsteel_saber" if actor_id == "wanderer" else "dawn_partisan" if actor_id == "noah" else "astral_staff"
				var variant: String = Art.Appearance.variant(loadout, actor_id)
				var expected: String = actor_id if variant.is_empty() else variant
				check(Art.DATA.has(expected), "Missing equipment action atlas: " + expected)
				if Art.DATA.has(expected):
					var selected: AtlasTexture = Art.texture_for(actor_id, "release", 2, loadout)
					check(selected.atlas.resource_path.ends_with("/" + expected + ".png"), "Equipment must retain its own casting/back art")
	# Every crop must contain one sprite and fit its actual imported texture.
	for sheet: String in Art.DATA:
		var data: Dictionary = Art.DATA[sheet]
		check(data.frames.size() == 48, sheet + " must cover all 4 x 12 poses")
		check(str(data.get("sha256", "")) == FileAccess.get_sha256("res://assets/generated/action/%s.png" % sheet), sheet + " metadata must match the actual PNG")
		var texture := load("res://assets/generated/action/%s.png" % sheet) as Texture2D
		var image: Image = texture.get_image()
		if image.is_compressed():
			image.decompress()
		check(image.detect_alpha() != Image.ALPHA_NONE, sheet + " needs genuine transparent pixels")
		for box: Array in data.frames:
			var region := Rect2i(int(box[0]), int(box[1]), int(box[2]), int(box[3]))
			check(Rect2i(Vector2i.ZERO, image.get_size()).encloses(region), sheet + " has clipped bounds")
			check(region.size.x > 20 and region.size.y > 20, sheet + " has empty/tiny pose")
	for index: int in range(4):
		var direction: Vector2 = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT][index]
		check(Art.direction(direction) == index, "Camera-relative cardinal art selection")
	var model := Model.new()
	model.setup(100, 20, 18, 4, {})
	var actor: Dictionary = model.actors[0]
	actor.position = Vector2.ZERO
	model.actors[3].position = Vector2(1.4, 0)
	model.command("attack")
	check(Art.pose(actor, false, 0) == "windup", "Windup pose precedes damage")
	for other: Dictionary in model.actors:
		other.cooldown = 100.0
	for frame: int in range(12):
		model.step(1.0 / 60.0, Vector2.ZERO)
	check(Art.pose(actor, false, 0) == "attack", "Contact pose at impact")
	var hp_after_impact: int = model.actors[3].hp
	for frame: int in range(12):
		model.step(1.0 / 60.0, Vector2.ZERO)
	check(Art.pose(actor, false, 0) == "recover", "Recovery frame must actually play")
	check(int(model.actors[3].hp) == hp_after_impact, "Recovery must not duplicate damage")
	actor.hurt = 0.2
	check(Art.pose(actor, false, 0) == "hurt", "Hit interrupts recovery presentation")
	actor.hp = 0
	check(Art.pose(actor, true, 0) == "defeated", "Death overrides walking and hurt")
	for kind: String in ["slash", "spear", "claw", "moon_slash", "bolt", "frost", "heal", "ward"]:
		var effect := Effect.new()
		root.add_child(effect)
		effect.configure(kind, Vector3.ZERO, 1.2, Vector2.RIGHT, null)
		check(effect.sprite.texture != null, kind + " texture resolves")
		var age: float = effect.age
		effect.advance(0.0)
		check(effect.age == age, "Pause must freeze effect playback")
		effect.advance(2.0)
		check(effect.is_queued_for_deletion(), "Finished effect must clean up")
	await process_frame
	if failures == 0:
		print("ACTION_ART_TEST_PASS atlas directions windup impact recovery defeat effects pause cleanup")
	quit(0 if failures == 0 else 1)
