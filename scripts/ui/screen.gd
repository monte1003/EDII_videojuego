class_name Screen
extends Control

#Seconds a screen ignores the confirm key after it opens, so a key still held from the screen before never skips it
const CONFIRM_GUARD := 0.5

@export var screen_id: StringName

var _confirm_armed := false


func _ready() -> void:
	ScreenFlow.mark_current(screen_id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().create_timer(CONFIRM_GUARD).timeout.connect(_arm_confirm)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back"):
		#Marcar antes de cambiar de pantalla: despues este nodo ya no tiene viewport
		get_viewport().set_input_as_handled()
		ScreenFlow.back()


#Whether this screen already takes a confirmation (a key or its main button)
func accepts_confirm() -> bool:
	return _confirm_armed


func _arm_confirm() -> void:
	_confirm_armed = true
