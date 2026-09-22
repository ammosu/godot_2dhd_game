class_name Interactable3D
extends Area3D

signal activated(interaction_id: String)

@export var interaction_id: String = ""
@export var prompt_text: String = "互動"
## Required approach direction in local space; zero allows any facing.
@export var facing_direction: Vector3 = Vector3.ZERO
@export var automatic_distance: float = 0.0


func _ready() -> void:
	if automatic_distance > 0.0:
		add_to_group("proximity_interactables")


func interact() -> void:
	activated.emit(interaction_id)
