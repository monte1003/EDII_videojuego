class_name RoundResult
extends RefCounted

#How a round ended, in what the screens need to show it

var minigame_id: StringName
var won := false
var headline := ""
var detail := ""
#Lines like ["Tiempo", "1:12"] for the round summary
var stats: Array[Array] = []
#Points and medal of the player of this screen
var score: RoundScore
#Points of every player of the round, by player id
var points_by_player: Dictionary = {}


static func make(id: StringName, victory: bool, title: String, message: String, lines: Array[Array] = []) -> RoundResult:
	var result := RoundResult.new()
	result.minigame_id = id
	result.won = victory
	result.headline = title
	result.detail = message
	result.stats = lines
	return result


#Adds the score of the player of this screen and the points of everybody
func with_score(local_score: RoundScore, everybody: Dictionary) -> RoundResult:
	score = local_score
	points_by_player = everybody
	return self


func points_of(player_id: int) -> int:
	return points_by_player.get(player_id, 0)
