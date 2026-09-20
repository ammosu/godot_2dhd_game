extends SceneTree
## Capture real, advancing effects; no forced poses, elapsed times or damage.
## Test fixture selects the caster/target and raises HP to keep all actors alive.

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	var destination: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			destination = argument.trim_prefix("--capture-dir=")
	if DisplayServer.get_name() == "headless" or not destination.is_absolute_path() or not DirAccess.dir_exists_absolute(destination):
		push_error("Use a real renderer and --capture-dir=<existing absolute directory>")
		quit(1)
		return
	var state: Node = root.get_node("GameState")
	var samples: Array[Dictionary] = []
	for target: int in range(6):
		samples.append({"caster": 5 if target < 3 else 2, "action": "magic", "target": target, "script": "magic_burst"})
	samples.append({"caster": 2, "action": "heal", "target": 0, "script": "healing_burst"})
	samples.append({"caster": 2, "action": "skill", "target": 5, "script": "moon_bolt_burst"})
	for sample: Dictionary in samples:
		state.call("reset_new_game", false)
		var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
		root.add_child(battle)
		battle.call("start_battle", {})
		var model: RefCounted = state.get("battle_session")
		for actor: Dictionary in model.actors:
			actor.max_hp = 1000
			actor.hp = 500
		model.current = sample.caster
		state.call("sync_party_battle")
		battle.call("_refresh")
		await process_frame
		var stage: Control = battle.get("_stage")
		var effect_script: Script = load("res://scripts/ui/%s.gd" % sample.script)
		var captured: Array[int] = []
		var effect_id: int = 0
		var sheet: Image = Image.create(int(stage.size.x), int(stage.size.y) * 4, false, Image.FORMAT_RGBA8)
		var prefix: String = "%s-%s-target%d" % [RenderingServer.get_current_rendering_method(), sample.action, sample.target]
		battle.call("_execute", sample.action, sample.target)
		var deadline: int = Time.get_ticks_msec() + 5000
		while captured.size() < 4 and Time.get_ticks_msec() < deadline:
			await RenderingServer.frame_post_draw
			for child: Node in stage.get_children():
				if child.get_script() != effect_script:
					continue
				if effect_id == 0:
					effect_id = child.get_instance_id()
				if child.get_instance_id() != effect_id:
					continue
				var phase: int = mini(3, int(float(child.get("_elapsed")) / 0.16))
				if captured.has(phase):
					continue
				var screenshot: Image = root.get_texture().get_image()
				_check(screenshot.save_png(destination.path_join("%s-phase%d.png" % [prefix, phase])) == OK, "Cannot save effect phase")
				screenshot.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(screenshot, Rect2i(stage.get_global_rect()), Vector2i(0, phase * int(stage.size.y)))
				captured.append(phase)
		_check(captured.size() == 4, "Missing live effect phases: " + prefix)
		_check(sheet.save_png(destination.path_join(prefix + "-stages.png")) == OK, "Cannot save stage comparison")
		# Drain the real action and automatic enemy turns before freeing the UI.
		deadline = Time.get_ticks_msec() + 10000
		while not bool(battle.call("can_accept_action")) and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(bool(battle.call("can_accept_action")), "Action did not finish: " + prefix)
		_check(stage.get_children().filter(func(node: Node) -> bool: return node.get_script() == effect_script).is_empty(), "Effect survived action: " + prefix)
		battle.free()
		state.set("battle_session", null)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("PARTY_EFFECT_CAPTURE_PASS eight_cases four_live_phases screenshots_require_review")
	quit(0 if failures == 0 else 1)
