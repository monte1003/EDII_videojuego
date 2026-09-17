extends Node3D

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

#Used when the scene runs without going through character select
@export var default_character: CharacterData

@onready var _spawn_point: Marker3D = $SpawnPoint
@onready var _pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	var character := GameState.get_character(GameState.PLAYER_ONE)
	if character == null:
		character = default_character

	var player := PLAYER_SCENE.instantiate() as Player
	player.player_id = GameState.PLAYER_ONE
	add_child(player)
	player.global_transform = _spawn_point.global_transform
	player.set_character(character)

	_pause_menu.opened.connect(player.set_input_enabled.bind(false))
	_pause_menu.closed.connect(player.set_input_enabled.bind(true))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
