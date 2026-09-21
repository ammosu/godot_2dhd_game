extends SceneTree
const Trees = preload("res://scripts/gameplay/tree_variants.gd")
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Trees._prepare()
	_check(Trees._textures.size() == 15, "Five species need three distinct textures each")
	for index: int in range(15):
		var texture: Texture2D = Trees._textures[index]
		_check(Trees._visible_heights[index] > 100, "Tree crop must contain usable art")
		_check(Trees._baselines[index] <= texture.get_height(), "Root must remain inside crop")
		if index % 3 != 0:
			var pixels := texture.get_image()
			for x: int in range(pixels.get_width()):
				_check(pixels.get_pixel(x, 0).a < 0.5 and pixels.get_pixel(x, pixels.get_height() - 1).a < 0.5, "Atlas row bleed or clipped crown/root")
			for y: int in range(pixels.get_height()):
				_check(pixels.get_pixel(0, y).a < 0.5 and pixels.get_pixel(pixels.get_width() - 1, y).a < 0.5, "Atlas column bleed or clipped branches")
	var previous: Array[int] = []
	for pass_index: int in range(2):
		var map := Node3D.new()
		root.add_child(map)
		var variants: Array[int] = []
		for index: int in range(3):
			var tree := Node3D.new()
			tree.position = Vector3(20, 0, -10 - index * 2)
			tree.add_to_group("village_trees")
			map.add_child(tree)
			Trees.decorate(tree, tree.position)
			_check(tree.get_meta("tree_species") == "willow", "Pond trees must retain species")
			var variant: int = tree.get_meta("tree_variant")
			_check(not variants.has(variant), "Nearby willows must use different authored silhouettes")
			variants.append(variant)
			var sprite := tree.get_node("TreeArt") as Sprite3D
			_check(is_equal_approx(sprite.position.y, 0.012), "Roots must stay grounded")
		if pass_index == 1:
			_check(variants == previous, "Reload must preserve each tree's identity")
		previous = variants
		map.free()
	if _failures == 0:
		print("TREE_VARIANTS_TEST_PASS fifteen_silhouettes alpha_bounds neighboring_variety deterministic_reload grounding")
	quit(0 if _failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
