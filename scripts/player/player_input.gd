class_name PlayerInput
extends Node

var enabled := true

@onready var _player := get_parent() as Player


func _physics_process(_delta: float) -> void:
	if not enabled:
		_player.move_input = Vector2.ZERO
		return
	_player.move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Input.is_action_just_pressed("jump"):
		_player.jump_requested = true
