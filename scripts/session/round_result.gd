class_name RoundResult
extends RefCounted

#How a round ended, for the screens

var minigame_id: StringName
var won := false
var headline := ""
var detail := ""
#Summary lines like ["Tiempo", "1:12"]
var stats: Array[Array] = []
#Points and medal of this screen's player
var score: RoundScore
#Points of every player by id
var points_by_player: Dictionary = {}


static func make(id: StringName, victory: bool, title: String, message: String, lines: Array[Array] = []) -> RoundResult:
	var result := RoundResult.new()
	result.minigame_id = id
	result.won = victory
	result.headline = title
	result.detail = message
	result.stats = lines
	return result


#Adds this screen's score and everybody's points
func with_score(local_score: RoundScore, everybody: Dictionary) -> RoundResult:
	score = local_score
	points_by_player = everybody
	return self


func points_of(player_id: int) -> int:
	return points_by_player.get(player_id, 0)
