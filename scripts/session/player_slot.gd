class_name PlayerSlot
extends RefCounted

#Who sits in a place of the lobby: the id every system uses for this player

var player_id: int
var display_name: String
var character: CharacterData
var ready := false


func _init(id: int, shown_name: String, chosen: CharacterData) -> void:
	player_id = id
	display_name = shown_name
	character = chosen
