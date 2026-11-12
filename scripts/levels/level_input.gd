class_name LevelInput
extends Node

#Turns the level's extra keys into signals, so the round logic never reads the keyboard

signal interact_pressed
signal interact_released
signal debug_toggled
signal demo_toggled
#Only Enter says "ready": the jump key never does
signal ready_pressed
signal shove_pressed


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interact_pressed.emit()
	elif event.is_action_released("interact"):
		interact_released.emit()
	elif event.is_action_pressed("toggle_debug"):
		debug_toggled.emit()
	elif event.is_action_pressed("demo_route"):
		demo_toggled.emit()
	elif event.is_action_pressed("ready"):
		ready_pressed.emit()
	elif event.is_action_pressed("shove"):
		shove_pressed.emit()
