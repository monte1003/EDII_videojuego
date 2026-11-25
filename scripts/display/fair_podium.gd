class_name FairPodium
extends PodiumCeremony

#Podium ceremony on the fair screen, unskippable, with the final totals from the server

signal done

#Seconds posing on the stage after the last crown
const LAST_SHOT := 4.5

#{"id", "name", "character", "total", "best"} of everybody in the room
var players: Array[Dictionary] = []


func _ready() -> void:
	super()
	_skip_hint.visible = false
	_prompt.visible = false


func _unhandled_input(_event: InputEvent) -> void:
	pass


func _gather() -> AVLTree:
	var tree := AVLTree.new()
	for player in players:
		tree.insert(int(player.get("total", 0)), int(player.get("id", 0)), int(player.get("best", 0)))
	return tree


func _character_of(player_id: int) -> CharacterData:
	return GameSession.character_by_id(StringName(str(_player(player_id).get("character", "fire"))))


func _name_of(player_id: int) -> String:
	return str(_player(player_id).get("name", "JUGADOR"))


func _finale() -> void:
	super()
	_prompt.visible = false
	if await _hold(LAST_SHOT):
		return
	done.emit()


func _leave() -> void:
	pass


func _player(player_id: int) -> Dictionary:
	for player in players:
		if int(player.get("id", 0)) == player_id:
			return player
	return {}
