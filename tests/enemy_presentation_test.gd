extends SceneTree
## Presentation must be deterministic, grounded, and independent of combat state.
const Presentation = preload("res://scripts/gameplay/enemy_presentation.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const Art = preload("res://scripts/gameplay/action_sprite_library.gd")
const HealthBar = preload("res://scripts/gameplay/world_health_bar.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for species: String in ["moss_wolf", "dusk_bat", "eclipse_mage", "guardian"]:
		var body := Node3D.new()
		root.add_child(body)
		Grounding.add_shadow(body, 0.32)
		var sprite := Sprite3D.new()
		body.add_child(sprite)
		var label := Label3D.new()
		body.add_child(label)
		var bar := HealthBar.new()
		body.add_child(bar)
		bar.configure(true, species)
		var view := Presentation.new()
		body.add_child(view)
		view.setup(body, species, sprite, label, bar)
		assert(label.alpha_cut == Label3D.ALPHA_CUT_DISCARD)
		assert(label.position.y > bar.position.y)
		for facing: int in range(4):
			var texture: AtlasTexture = Art.texture_for(species, "idle", facing)
			sprite.texture = texture
			Grounding.anchor(sprite, texture, float(texture.get_meta("ground_y")))
			view.advance(1.5, "idle", 0.0, 0.0, 0.0)
			var frozen_transform: Transform3D = sprite.transform
			for frame: int in range(60):
				Grounding.anchor(sprite, texture, float(texture.get_meta("ground_y")))
				view.advance(1.5, "idle", 0.0, 0.0, 0.0)
			assert(sprite.transform.is_equal_approx(frozen_transform), "Paused presentation must not drift")
			assert(sprite.position.y > 0.4 if species == "dusk_bat" else is_equal_approx(sprite.position.y, 0.012))
			Grounding.anchor(sprite, texture, float(texture.get_meta("ground_y")))
			view.advance(2.0, "windup", 0.0, 0.3, 0.0)
			assert(sprite.scale.y < 1.0, "Windup has anticipation")
			Grounding.anchor(sprite, texture, float(texture.get_meta("ground_y")))
			view.advance(2.1, "attack", 0.0, 0.0, 0.2)
			assert(sprite.scale.x > 1.0, "Strike has follow-through")
			Grounding.anchor(sprite, texture, float(texture.get_meta("ground_y")))
			view.advance(2.2, "defeated", 0.2, 0.0, 0.0)
			assert(sprite.scale == Vector3.ONE and is_equal_approx(sprite.position.y, 0.012))
			if view.aura != null:
				assert(not view.aura.visible, "Dead mage has no aura")
		bar.set_health(50, 100)
		assert(is_equal_approx(bar._fill.region_rect.size.x, 50.0))
		assert(is_equal_approx(bar._fill.offset.x, -25.0), "Damage empties health from the right")
		bar.set_health(0, 100)
		assert(not bar.visible)
		body.queue_free()
	await process_frame
	print("ENEMY_PRESENTATION_TEST_PASS four_species directions pause grounding anticipation defeat health")
	quit()
