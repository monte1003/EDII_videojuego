class_name PauseMenu
extends CanvasLayer

#Pause of every round: a small title and a plain list of text buttons

signal opened
signal closed
signal help_requested

#Whether this round has a help to open from the pause
@export var allow_help := false

var _restart_button: TextButton
var _help_button: TextButton
var _first_button: TextButton
var _stack: VBoxContainer


func _ready() -> void:
	hide()
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(Palette.NIGHT, 0.62)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(stack)
	_stack = stack

	var title := UiKit.label("PAUSA", UiKit.BUTTON_FONT, 20, Color(Palette.PAPER, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(gap)

	_first_button = _option("CONTINUAR", Palette.PILL)
	_first_button.pressed.connect(close)
	_restart_button = _option("REINICIAR RONDA", Palette.TEAL)
	_restart_button.pressed.connect(_on_restart)
	_help_button = _option("AYUDA", Palette.TEAL)
	_help_button.pressed.connect(help_requested.emit)
	var exit_button := _option("SALIR", Palette.AMBER)
	exit_button.pressed.connect(GameSession.abandon)


func _option(text: String, accent: Color) -> TextButton:
	var button := UiKit.text_button(text, accent, 26)
	button.light = true
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stack.add_child(button)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	_help_button.visible = allow_help
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_first_button.grab_focus()
	opened.emit()


func close() -> void:
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


#Inside a session the round starts again; on its own the scene is loaded again
func _on_restart() -> void:
	if GameSession.is_playing_round():
		GameSession.restart_round()
	else:
		ScreenFlow.reload_current()
