class_name StreetInput
extends Node

#Turns the keyboard into runner actions; the runner never reads the input itself

var enabled := false

@onready var _runner := get_parent() as StreetRunner


func _physics_process(_delta: float) -> void:
	if not enabled:
		_runner.move_axis = 0.0
		return
	_runner.move_axis = Input.get_axis("move_forward", "move_back")
	if Input.is_action_just_pressed("jump"):
		_runner.jump_requested = true
