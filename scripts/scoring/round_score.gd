class_name RoundScore
extends RefCounted

#What a round was worth for one player: points from 0 to 1000, the medal they earn and how they add up

var points := 0
var medal := ScoreSheet.Medal.NONE
#Set by the session when these points beat the best ones kept for that minigame
var record := false
#What was measured, in one line, as in "Llegaste en 84 s"
var metric := ""
#Up to three lines like ["Tiempo", "+412"]
var breakdown: Array[Array] = []


static func make(sheet: ScoreSheet, earned: int, measured: String, lines: Array[Array] = []) -> RoundScore:
	var score := RoundScore.new()
	score.points = clampi(earned, 0, ScoreSheet.MAX_POINTS)
	score.medal = sheet.medal_for(score.points)
	score.metric = measured
	score.breakdown = lines.slice(0, 3)
	return score


func medal_name() -> String:
	return ScoreSheet.MEDAL_NAMES[medal]
