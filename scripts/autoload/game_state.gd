extends Node

signal character_selected(player_id: int, character: CharacterData)

const PLAYER_ONE := 1
const MAX_NAME_LENGTH := 12

var _selected_characters: Dictionary[int, CharacterData] = {}
var _names: Dictionary[int, String] = {}


func select_character(player_id: int, character: CharacterData) -> void:
	_selected_characters[player_id] = character
	character_selected.emit(player_id, character)


func get_character(player_id: int) -> CharacterData:
	return _selected_characters.get(player_id)


func set_player_name(player_id: int, shown_name: String) -> void:
	_names[player_id] = shown_name.strip_edges().left(MAX_NAME_LENGTH)


func get_player_name(player_id: int) -> String:
	var shown: String = _names.get(player_id, "")
	return shown if not shown.is_empty() else "JUGADOR %d" % player_id
