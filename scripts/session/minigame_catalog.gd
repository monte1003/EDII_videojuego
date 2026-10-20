class_name MinigameCatalog
extends RefCounted

#Every minigame of the game; a session only draws from the ones that are ready.
#To add one: a MinigameInfo in resources/minigames and one line in ENTRIES.

const PLANNED := 6
const ENTRIES: Array[MinigameInfo] = [
	preload("res://resources/minigames/level_01.tres"),
	preload("res://resources/minigames/street_game.tres"),
]


static func ready_entries() -> Array[MinigameInfo]:
	var list: Array[MinigameInfo] = []
	for info in ENTRIES:
		if info.ready and ResourceLoader.exists(info.scene_path):
			list.append(info)
	return list


static func find(id: StringName) -> MinigameInfo:
	for info in ENTRIES:
		if info.id == id:
			return info
	return null
