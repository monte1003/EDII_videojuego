class_name ScoreBook
extends RefCounted

#The best scores of this computer: one per minigame and the best whole game. A missing or broken file is the same as an empty book

const DEFAULT_PATH := "user://scores.json"

var path := DEFAULT_PATH

var _rounds: Dictionary = {}
var _session := 0


func _init(file_path := DEFAULT_PATH) -> void:
	path = file_path
	_read()


func best_round(id: StringName) -> int:
	return _rounds.get(String(id), 0)


func best_session() -> int:
	return _session


#Keeps the points of a round when they beat the best ones; true when they did
func submit_round(id: StringName, points: int) -> bool:
	if points <= best_round(id):
		return false
	_rounds[String(id)] = points
	_write()
	return true


func submit_session(total: int) -> bool:
	if total <= _session:
		return false
	_session = total
	_write()
	return true


#Anything that is not what the game wrote is dropped piece by piece, so one bad value never takes the rest with it
func _read() -> void:
	_rounds.clear()
	_session = 0
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return
	var data: Dictionary = parser.data
	if _is_number(data.get("session")):
		_session = maxi(int(data["session"]), 0)
	if data.get("rounds") is Dictionary:
		var rounds: Dictionary = data["rounds"]
		for key: Variant in rounds:
			if key is String and _is_number(rounds[key]):
				_rounds[key] = clampi(int(rounds[key]), 0, ScoreSheet.MAX_POINTS)


#The only place that writes the file
func _write() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"version": 1, "session": _session, "rounds": _rounds}, "\t"))


func _is_number(value: Variant) -> bool:
	return value is float or value is int
