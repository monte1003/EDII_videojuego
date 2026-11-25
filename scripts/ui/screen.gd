class_name Screen
extends Control

#Seconds the confirm key is ignored after opening, so a held key never skips the screen
const CONFIRM_GUARD := 0.5

@export var screen_id: StringName

var _confirm_armed := false


func _ready() -> void:
	ScreenFlow.mark_current(screen_id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().create_timer(CONFIRM_GUARD).timeout.connect(_arm_confirm)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back"):
		#Mark before changing screen: then this node has no viewport
		get_viewport().set_input_as_handled()
		ScreenFlow.back()


#Whether this screen takes a confirmation
func accepts_confirm() -> bool:
	return _confirm_armed


#A selected button handles confirm itself; the screen only when nothing is selected
func confirm_is_free() -> bool:
	return not get_viewport().gui_get_focus_owner() is BaseButton


func _arm_confirm() -> void:
	_confirm_armed = true
