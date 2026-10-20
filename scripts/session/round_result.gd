class_name RoundResult
extends RefCounted

#How a round ended, in what the screens need to show it

var minigame_id: StringName
var won := false
var headline := ""
var detail := ""
#Lines like ["Tiempo", "1:12"] for the round summary
var stats: Array[Array] = []


static func make(id: StringName, victory: bool, title: String, message: String, lines: Array[Array] = []) -> RoundResult:
	var result := RoundResult.new()
	result.minigame_id = id
	result.won = victory
	result.headline = title
	result.detail = message
	result.stats = lines
	return result
