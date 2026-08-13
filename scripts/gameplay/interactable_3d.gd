class_name Interactable3D
extends Area3D

signal activated(interaction_id: String)

@export var interaction_id: String = ""
@export var prompt_text: String = "互動"


func interact() -> void:
	activated.emit(interaction_id)
