extends Sprite3D
## Front-facing idle art for stationary city hosts; never used for patrols.
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
var visible_height: float = 1.4


func _ready() -> void:
	pixel_size = visible_height / float(texture.get_meta("reference_height"))
	Grounding.anchor(self, texture, float(texture.get_meta("ground_y")))


func turn_to(partner: Node3D) -> void:
	# The host remains a front-facing billboard until directional art is authored.
	partner.call("face_world_position", get_parent_node_3d().global_position)
