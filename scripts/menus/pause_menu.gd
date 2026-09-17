class_name PauseMenu
extends CanvasLayer

signal opened
signal closed

const MAIN_MENU_SCENE := "res://scenes/menus/main_menu.tscn"

@onready var _exit_button: Button = %ExitButton


func _ready() -> void:
	hide()
	_exit_button.pressed.connect(_on_exit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	opened.emit()


func close() -> void:
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
