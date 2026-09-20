extends SceneTree
const Burst = preload("res://scripts/ui/magic_burst.gd")
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
	if valid:
		print("MAGIC_BURST_TEST_PASS alpha impact_once timing cleanup")
	else:
		push_error("Magic burst timing or alpha regression")
	quit(0 if valid else 1)
