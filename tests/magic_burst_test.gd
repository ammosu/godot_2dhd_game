extends SceneTree
const Burst = preload("res://scripts/ui/magic_burst.gd")
const HealingBurst = preload("res://scripts/ui/healing_burst.gd")
const MoonBoltBurst = preload("res://scripts/ui/moon_bolt_burst.gd")
var hits: int = 0
var finishes: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var burst := Burst.new()
	root.add_child(burst)
	burst.set_process(false)
	burst.impact.connect(func() -> void: hits += 1)
	burst.finished.connect(func() -> void: finishes += 1)
	burst._process(0.10)
	var valid: bool = hits == 0
	burst._process(0.10)
	valid = valid and hits == 1
	burst._process(0.10)
	valid = valid and hits == 1
	var reference: WeakRef = weakref(burst)
	burst._process(0.40)
	valid = valid and hits == 1 and finishes == 1
	await process_frame
	valid = valid and reference.get_ref() == null
	valid = valid and Burst.ATLAS.get_image().detect_alpha() != Image.ALPHA_NONE
	hits = 0
	finishes = 0
	var healing := HealingBurst.new()
	root.add_child(healing)
	healing.set_process(false)
	healing.impact.connect(func() -> void: hits += 1)
	healing.finished.connect(func() -> void: finishes += 1)
	healing._process(0.15)
	valid = valid and hits == 0
	healing._process(0.02)
	valid = valid and hits == 1
	healing._process(0.30)
	valid = valid and hits == 1 and finishes == 0
	reference = weakref(healing)
	healing._process(0.20)
	valid = valid and hits == 1 and finishes == 1
	await process_frame
	valid = valid and reference.get_ref() == null
	var image: Image = HealingBurst.HEAL_ATLAS.get_image()
	valid = valid and image.detect_alpha() != Image.ALPHA_NONE
	var cell := Vector2i(image.get_size() / 2)
	for frame: int in range(4):
		var crop := image.get_region(Rect2i(Vector2i(frame % 2, frame / 2) * cell, cell))
		valid = valid and not crop.is_invisible()
		valid = valid and crop.get_pixel(0, 0).a < 0.01 and crop.get_pixel(cell.x - 1, cell.y - 1).a < 0.01
	if valid:
		var moon := MoonBoltBurst.new()
		root.add_child(moon)
		moon.set_process(false)
		hits = 0
		finishes = 0
		moon.impact.connect(func() -> void: hits += 1)
		moon.finished.connect(func() -> void: finishes += 1)
		moon._process(0.15)
		valid = valid and hits == 0
		moon._process(0.02)
		valid = valid and hits == 1
		reference = weakref(moon)
		moon._process(0.50)
		valid = valid and hits == 1 and finishes == 1
		await process_frame
		valid = valid and reference.get_ref() == null
		image = MoonBoltBurst.MOON_ATLAS.get_image()
		valid = valid and image.detect_alpha() != Image.ALPHA_NONE
		cell = Vector2i(image.get_size() / 2)
		for frame: int in range(4):
			valid = valid and not image.get_region(Rect2i(Vector2i(frame % 2, frame / 2) * cell, cell)).is_invisible()
	if valid:
		print("MAGIC_BURST_TEST_PASS frost healing moon_bolt frames alpha impact_once timing cleanup")
	else:
		push_error("Magic burst timing or alpha regression")
	quit(0 if valid else 1)
