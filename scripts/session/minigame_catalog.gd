class_name MinigameCatalog
extends RefCounted

#Every minigame; to add one: a MinigameInfo in resources/minigames and a line in ENTRIES

const PLANNED := 5
const ENTRIES: Array[MinigameInfo] = [
	preload("res://resources/minigames/level_01.tres"),
	preload("res://resources/minigames/street_game.tres"),
	preload("res://resources/minigames/social_drop.tres"),
	preload("res://resources/minigames/trend_war.tres"),
	preload("res://resources/minigames/perfect_selfie.tres"),
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
