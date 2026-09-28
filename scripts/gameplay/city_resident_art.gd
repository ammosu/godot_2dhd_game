extends Sprite3D
const Proportions = preload("res://scripts/gameplay/character_proportions.gd")
## Front-facing idle art for stationary city hosts; never used for patrols.
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const BodyLife = preload("res://scripts/gameplay/body_life.gd")
var visible_height: float = Proportions.HEIGHT


func _ready() -> void:
	Proportions.apply(self, texture, float(texture.get_meta("reference_height")), visible_height)
	Grounding.anchor(self, texture, float(texture.get_meta("ground_y")))
	add_child(BodyLife.new())


func turn_to(partner: Node3D) -> void:
	# The host remains a front-facing billboard until directional art is authored;
	# a short acknowledging dip stands in for the turn.
	partner.call("face_world_position", get_parent_node_3d().global_position)
	var life := BodyLife.find(self)
	if life != null:
		life.call("acknowledge")
