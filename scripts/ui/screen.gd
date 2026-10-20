class_name Screen
extends Control

@export var screen_id: StringName


func _ready() -> void:
	ScreenFlow.mark_current(screen_id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back"):
		#Marcar antes de cambiar de pantalla: despues este nodo ya no tiene viewport
		get_viewport().set_input_as_handled()
		ScreenFlow.back()
