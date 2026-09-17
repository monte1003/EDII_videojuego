extends Control

const CHARACTER_SELECT_SCENE := "res://scenes/menus/character_select.tscn"

@onready var _play_button: Button = %PlayButton
@onready var _exit_button: Button = %ExitButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play_button.pressed.connect(_on_play_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()
