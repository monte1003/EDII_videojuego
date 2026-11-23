class_name FairPodium
extends PodiumCeremony

#The podium ceremony of the game on the fair screen, the same as on the computers of the players but with no way to skip it: no key hint,
#no key at all, and nothing after it but the signal that it is over. The players and their totals are the ones the server counted at
#the end of the game ("final"), since this screen did not play

signal done

#Seconds everybody stays posing on the stage after the last crown
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
