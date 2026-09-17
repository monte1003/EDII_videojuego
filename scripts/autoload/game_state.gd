extends Node

signal character_selected(player_id: int, character: CharacterData)

const PLAYER_ONE := 1

var _selected_characters: Dictionary[int, CharacterData] = {}


func select_character(player_id: int, character: CharacterData) -> void:
	_selected_characters[player_id] = character
	character_selected.emit(player_id, character)


func get_character(player_id: int) -> CharacterData:
	return _selected_characters.get(player_id)
