extends SceneTree
## Staggered two-key release through the real player input path, no save writes.
const INPUTS: Array[Vector2] = [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]
const DIRECTIONS: Array[StringName] = [&"down_left", &"down_right", &"up_left", &"up_right"]
const ACTIONS: Array[Array] = [[&"move_left", &"move_back"], [&"move_right", &"move_back"], [&"move_left", &"move_forward"], [&"move_right", &"move_forward"]]
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func tick(player: CharacterBody3D, count: int) -> void:
	for index: int in range(count):
		player.call("_physics_process", 1.0 / 60.0)

func _run() -> void:
	root.get_node("GameState").call("reset_new_game", false, "archer")
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	player.set_physics_process(false)
	var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
	for direction: int in range(4):
		for released: int in range(2):
			for gap: int in [1, 3, 5]:
				for action: StringName in ACTIONS[direction]:
					Input.action_press(action)
				tick(player, 8)
				check(sprite.animation == DIRECTIONS[direction], "Diagonal input was not selected")
				Input.action_release(ACTIONS[direction][released])
				tick(player, gap)
				Input.action_release(ACTIONS[direction][1 - released])
				tick(player, 20)
				check(sprite.animation == DIRECTIONS[direction] and sprite.frame == 0, "Staggered release changed idle facing: %s / first key %d / gap %d" % [DIRECTIONS[direction], released, gap])
				check(Vector2(player.velocity.x, player.velocity.z).is_zero_approx(), "Facing grace delayed stopping")
			# Holding the remaining key is an intentional turn; movement responds immediately.
			for action: StringName in ACTIONS[direction]:
				Input.action_press(action)
			tick(player, 8)
			Input.action_release(ACTIONS[direction][released])
			tick(player, 20)
			var expected: StringName = (&"down" if INPUTS[direction].y > 0 else &"up") if released == 0 else (&"left" if INPUTS[direction].x < 0 else &"right")
			check(sprite.animation == expected, "Sustained single-key turn was ignored")
			Input.action_release(ACTIONS[direction][1 - released])
			tick(player, 20)
	# A new single-key input after stopping must turn immediately.
	Input.action_press(&"move_right")
	tick(player, 1)
	check(sprite.animation == &"right", "Fresh movement was delayed")
	Input.action_release(&"move_right")
	player.queue_free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("PLAYER_STOP_FACING_TEST_PASS staggered_release four_diagonals both_orders stop turn restart")
	quit(0 if failures == 0 else 1)
