extends SceneTree
## Procedural acting: beats move the sprite and hand it back exactly at rest,
## interrupted beats do not drift, nods go through BodyLife, emote bubbles pop,
## fade and use glyphs the bundled font can draw.

const FPS: int = 60

var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition and not _failed:
		_failed = true
		push_error(message)


func _step(nodes: Array[Node], seconds: float) -> void:
	for frame: int in range(roundi(seconds * FPS)):
		for node: Node in nodes:
			node.call("_process", 1.0 / FPS)


func _run() -> void:
	var Acting: GDScript = load("res://scripts/gameplay/actor_acting.gd")
	var BodyLife: GDScript = load("res://scripts/gameplay/body_life.gd")
	var actor := Node3D.new()
	root.add_child(actor)
	var sprite := Sprite3D.new()
	sprite.texture = load("res://assets/generated/elder_combat_idle.tres")
	sprite.pixel_size = 0.004
	actor.add_child(sprite)
	# Feet at the actor origin, as every in-game character is anchored.
	load("res://scripts/gameplay/sprite_grounding.gd").anchor(sprite, sprite.texture)
	var life: Node = BodyLife.new()
	life.set("breathing", false)
	sprite.add_child(life)
	var acting: Node = Acting.ensure(sprite)
	_check(Acting.ensure(sprite) == acting, "ensure must reuse the existing component")
	_check(Acting.find(sprite) == acting, "find must return the component")
	for node: Node in [life, acting]:
		node.set_process(false)
	var nodes: Array[Node] = [life, acting]
	var rest: Vector3 = sprite.position

	# Every beat moves the sprite and returns it exactly to rest.
	for beat: StringName in Acting.BEATS:
		if beat == &"nod":
			continue
		acting.call("act", beat, &"none")
		var moved: bool = false
		for frame: int in range(roundi(float(Acting.BEATS[beat]) * FPS) + 2):
			acting.call("_process", 1.0 / FPS)
			moved = moved or not sprite.position.is_equal_approx(rest)
		_check(moved, "Beat %s must move the sprite" % beat)
		_check(sprite.position == rest, "Beat %s must end exactly at rest" % beat)
		_check(acting.call("current_beat") == &"", "Beat %s must finish" % beat)
	_check(sprite.position.y >= rest.y - 0.0001, "Beats must not sink below the ground")

	# Restarting mid-beat keeps the captured rest instead of the lifted pose.
	acting.call("act", &"joy", &"none")
	_step(nodes, 0.12)
	acting.call("act", &"surprise", &"none")
	_step(nodes, 0.1)
	acting.call("act", &"hop", &"none")
	_step(nodes, 1.0)
	_check(sprite.position == rest, "Interrupted beats must not drift")
	acting.call("act", &"shiver", &"none")
	_step(nodes, 0.2)
	acting.call("clear")
	_check(sprite.position == rest and not acting.call("is_acting"), "clear must restore rest immediately")

	# Nods dip through BodyLife (twice) and leave scale.y at rest.
	acting.call("act", &"nod", &"none")
	var dips: int = 0
	var dipping: bool = false
	for frame: int in range(FPS):
		_step(nodes, 1.0 / FPS)
		var low: bool = sprite.scale.y < 0.999
		if low and not dipping:
			dips += 1
		dipping = low
	_check(dips == 2, "Nod must dip twice through BodyLife (got %d)" % dips)
	_check(sprite.scale.y == 1.0 and sprite.position == rest, "Nod must hand scale and position back")

	# Surprise pops its default bubble above the head, which then fades away.
	acting.call("act", &"surprise")
	var bubble: Label3D = actor.get_node("Emote")
	_check(acting.call("current_emote") == &"exclaim" and bubble.text == "!", "Surprise must show an exclamation")
	var head: float = float(acting.call("_head_height"))
	var texture_top: float = (sprite.offset.y + sprite.texture.get_height() * 0.5) * sprite.pixel_size
	_check(head > 0.4 and head < texture_top - 0.05, "Head height must skip transparent margins (got %f of %f)" % [head, texture_top])
	_check(bubble.position.y > head and bubble.position.y < head + 0.6, "Bubble must sit just above the head")
	_check(bubble.scale.x < 0.05, "Bubble must start small and pop open")
	_step(nodes, 0.3)
	_check(is_equal_approx(bubble.scale.x, 1.0), "Bubble must pop open and settle")
	_step(nodes, float(Acting.EMOTE_SECONDS))
	_check(not bubble.visible and acting.call("current_emote") == &"", "Bubble must disappear after its time")
	acting.call("act", &"laugh", &"heart")
	_check(acting.call("current_emote") == &"heart", "Callers must override the default bubble")
	acting.call("act", &"", &"question")
	_check(acting.call("current_emote") == &"question" and acting.call("current_beat") == &"laugh", "Emote-only acting must leave the running beat alone")
	_step(nodes, 1.0)
	acting.call("act", &"", &"ellipsis")
	_step(nodes, 0.1)
	_check(acting.call("current_beat") == &"" and sprite.position == rest, "Emote-only acting must not move the body")
	_check(actor.get_children().filter(func(child: Node) -> bool: return child is Label3D).size() == 1, "Bubbles must be reused")

	# Every emote glyph must exist in the bundled font (the Web build has no fallback).
	var font: Font = Acting.FONT
	for kind: StringName in Acting.EMOTES:
		for glyph: String in str(Acting.EMOTES[kind][0]):
			_check(font.has_char(glyph.unicode_at(0)), "Bundled font lacks emote glyph %s (%s)" % [glyph, kind])

	actor.free()
	await create_timer(0.1).timeout
	if _failed:
		quit(1)
		return
	print("ACTOR_ACTING_TEST_PASS beats rest interrupt clear nod bubble glyphs")
	quit()
