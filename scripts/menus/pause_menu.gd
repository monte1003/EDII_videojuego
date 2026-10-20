class_name PauseMenu
extends CanvasLayer

#Pause panel of every round: one centered stack of buttons that all share width and height

signal opened
signal closed
signal help_requested

const DOOR := preload("res://assets/ui/icons/door.svg")

#Whether this round has a help to open from the pause
@export var allow_help := false

var _restart_button: GameButton
var _help_button: GameButton
var _first_button: GameButton


func _ready() -> void:
	hide()
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(Palette.NIGHT, 0.6)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", UiKit.STACK_GAP)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(stack)

	var title := UiKit.heading("PAUSA", 56, Palette.PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Palette.CORAL)
	title.add_theme_constant_override("outline_size", 14)
	stack.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(gap)

	_first_button = UiKit.game_button("CONTINUAR")
	_first_button.pressed.connect(close)
	stack.add_child(_first_button)
	_restart_button = UiKit.game_button("REINICIAR RONDA", false)
	_restart_button.pressed.connect(_on_restart)
	stack.add_child(_restart_button)
	_help_button = UiKit.game_button("AYUDA", false)
	_help_button.pressed.connect(help_requested.emit)
	stack.add_child(_help_button)
	var exit_button := UiKit.game_button("SALIR", false)
	exit_button.icon = DOOR
	exit_button.pressed.connect(GameSession.abandon)
	stack.add_child(exit_button)


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
