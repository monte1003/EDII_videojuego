class_name PlayerSlot
extends RefCounted

#Who sits in a lobby place

var player_id: int
var display_name: String
var character: CharacterData
var ready := false
#In a room, false while this player is disconnected
var connected := true


func _init(id: int, shown_name: String, chosen: CharacterData) -> void:
	player_id = id
	display_name = shown_name
	character = chosen
