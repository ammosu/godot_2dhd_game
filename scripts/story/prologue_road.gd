extends Node3D
## Prologue staging on the east road: cold lamps, a thick murk that thins toward the
## village, the fog that turns the traveler back east, and the moonlit trail west.
## Lives under the map root, so leaving the map removes it with the rest of the scene.

## Past this x the fog closes in and returns the traveler to where they woke.
const EAST_FOG_X: float = 12.6
## The fog is thickest where the traveler wakes and thins toward the village mouth.
const FOG_THICK: float = 0.085
const FOG_THIN: float = 0.012
const FOG_WEST_X: float = -12.0
const FOG_EAST_X: float = 6.0
## Moonlit patches on the road west, from the sign toward the village.
const TRAIL: Array[Vector3] = [Vector3(-7.6, 0.06, 4.8), Vector3(-9.6, 0.06, 5.3), Vector3(-11.6, 0.06, 4.9), Vector3(-13.2, 0.06, 5.0)]
const HALFWAY_X: float = -9.0
## Compatibility's depth fog reads thinner than Forward+ at the same density.
const COMPATIBILITY_FOG_SCALE: float = 1.8

var world: Node3D
var lit: bool = false
var _environment: Environment
var _bouncing: bool = false
var _halfway_said: bool = false
var _fog_scale: float = 1.0


func _ready() -> void:
	name = "PrologueRoad"
	_environment = world.get("_environment")
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_fog_scale = COMPATIBILITY_FOG_SCALE
	for lantern: Node3D in _lanterns():
		_set_lantern(lantern, false)
	# Set even under a film: the waking shot thins its murk toward this density.
	_environment.fog_density = FOG_THICK * _fog_scale


func _physics_process(_delta: float) -> void:
	_apply_fog()
	var player := world.get_node("Player") as Node3D
	if GameState.is_input_locked() or _bouncing:
		return
	if player.global_position.x > EAST_FOG_X:
		_turn_back(player)
	elif lit and not _halfway_said and player.global_position.x < HALFWAY_X:
		_halfway_said = true
		GameState.notification_requested.emit("旅人：" + str(load("res://scripts/story/prologue_lines.gd").SCENES.halfway[0].text))


func _apply_fog() -> void:
	if GameState.mode == GameState.Mode.CUTSCENE:
		return # Films set their own murk (the waking shot thins it on camera).
	var x: float = (world.get_node("Player") as Node3D).global_position.x
	var thinning: float = clampf(inverse_lerp(FOG_EAST_X, FOG_WEST_X, x), 0.0, 1.0) if lit else 0.0
	_environment.fog_density = lerpf(FOG_THICK, FOG_THIN, thinning) * _fog_scale


## The fog swallows the road east; the traveler finds themself back at the start.
func _turn_back(player: Node3D) -> void:
	_bouncing = true
	GameState.set_mode(GameState.Mode.TRANSITION)
	(player as CharacterBody3D).velocity = Vector3.ZERO
	var murk := create_tween()
	murk.tween_method(_set_fog, FOG_THICK * _fog_scale, 0.3, 0.6)
	await murk.finished
	var prologue: GDScript = load("res://scripts/story/prologue.gd")
	player.global_position = world.call("cutscene_ground", prologue.WAKE)
	player.call("face_world_position", prologue.WAKE + Vector3.LEFT)
	world.get_node("CameraRig").call("snap_to_target")
	var clearing := create_tween()
	clearing.tween_method(_set_fog, 0.3, FOG_THICK * _fog_scale, 0.8)
	await clearing.finished
	GameState.set_mode(GameState.Mode.EXPLORE)
	_bouncing = false
	prologue.play_lines(world, "east_fog")


func _set_fog(density: float) -> void:
	_environment.fog_density = density


## Moonlight falls on the road west and the lamps at the village mouth answer.
## `animate` is false when restoring the state (a reload or a skipped film).
func light_the_way(animate: bool) -> void:
	if lit:
		return
	lit = true
	var beam := MeshInstance3D.new()
	beam.name = "Moonbeam"
	var shaft := CylinderMesh.new()
	shaft.top_radius = 1.6
	shaft.bottom_radius = 0.9
	shaft.height = 18.0
	beam.mesh = shaft
	beam.material_override = _glow_material(Color(0.72, 0.84, 1.0, 0.16))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beam.global_position = Vector3(-13.6, 9.0, 5.0)
	var patches: Array[Node3D] = []
	for at: Vector3 in TRAIL:
		var patch := MeshInstance3D.new()
		patch.name = "MoonPatch"
		var disc := PlaneMesh.new()
		disc.size = Vector2(2.2, 2.2)
		patch.mesh = disc
		var pool := _glow_material(Color(0.74, 0.86, 1.0, 0.38))
		pool.albedo_texture = _soft_disc()
		patch.material_override = pool
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(patch)
		patch.global_position = world.call("cutscene_ground", at) - Vector3.UP * 0.06
		patches.append(patch)
	var mouth_lamps: Array[Node3D] = []
	for lantern: Node3D in _lanterns():
		if lantern.global_position.x < -13.0:
			mouth_lamps.append(lantern)
	if not animate:
		for lantern: Node3D in mouth_lamps:
			_set_lantern(lantern, true)
		return
	beam.scale = Vector3(0.05, 1.0, 0.05)
	var reveal := create_tween()
	reveal.tween_property(beam, "scale", Vector3.ONE, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for index: int in range(patches.size()):
		patches[index].scale = Vector3.ZERO
		reveal.parallel().tween_property(patches[index], "scale", Vector3.ONE, 0.6).set_delay(0.5 + index * 0.35)
	reveal.tween_callback(func() -> void:
		for lantern: Node3D in mouth_lamps:
			_set_lantern(lantern, true))


func _lanterns() -> Array[Node3D]:
	var found: Array[Node3D] = []
	for lantern: Node in get_tree().get_nodes_in_group("street_lanterns"):
		if get_parent().is_ancestor_of(lantern):
			found.append(lantern as Node3D)
	return found


## Moonlit mouth lamps glow cool white; every other lamp on the road stays cold.
func _set_lantern(lantern: Node3D, on: bool) -> void:
	var light := lantern.get_node_or_null("RoadLight") as OmniLight3D
	if light != null:
		light.visible = on
		light.light_color = Color("cfe4ff")
		light.light_energy = 3.0
	var glass := lantern.get_node_or_null("FrostedGlass") as MeshInstance3D
	if glass != null:
		var pane := StandardMaterial3D.new()
		pane.albedo_color = Color("cfe4ff") if on else Color("3a3d40")
		pane.roughness = 0.9
		if on:
			pane.emission_enabled = true
			pane.emission = Color("b8d6ff")
			pane.emission_energy_multiplier = 1.6
		glass.material_override = pane


## A radial falloff so moonlight pools have no hard rim.
func _soft_disc() -> GradientTexture2D:
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1, 1, 1, 1))
	falloff.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = falloff
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.no_depth_test = false
	return material
