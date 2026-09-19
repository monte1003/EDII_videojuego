extends Control

const CHARACTER_SELECT_SCENE := "res://scenes/menus/character_select.tscn"
const OPTIONS_MENU_SCENE := "res://scenes/menus/options_menu.tscn"

@onready var _play_button: Button = %PlayButton
@onready var _exit_button: Button = %ExitButton
@onready var _options_button: Button = %OptionsButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play_button.pressed.connect(_on_play_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_options_button.pressed.connect(_on_options_pressed)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()
	
func _on_options_pressed() -> void:
	get_tree().change_scene_to_file(OPTIONS_MENU_SCENE)
