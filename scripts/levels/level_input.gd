class_name LevelInput
extends Node

#Turns the level's extra keys into signals, so the round logic never reads the keyboard

signal interact_pressed
signal help_pressed
signal debug_toggled
signal demo_toggled


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interact_pressed.emit()
	elif event.is_action_pressed("help"):
		help_pressed.emit()
	elif event.is_action_pressed("toggle_debug"):
		debug_toggled.emit()
	elif event.is_action_pressed("demo_route"):
		demo_toggled.emit()
