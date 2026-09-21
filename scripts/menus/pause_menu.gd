class_name PauseMenu
extends CanvasLayer

signal opened
signal closed

@onready var _exit_button: Button = %ExitButton


func _ready() -> void:
	hide()
	_exit_button.pressed.connect(ScreenFlow.go_to_root)


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

