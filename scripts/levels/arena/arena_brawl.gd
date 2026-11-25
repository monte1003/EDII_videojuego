class_name ArenaBrawl
extends RefCounted

#Shoves between players by id with no nodes: rest, grace after a hit and a one-blow shield

enum Outcome { IGNORED, BLOCKED, STRUCK }

#A shove throws the victim about 3.9 m and dazes it; the shover steps back about 0.4 m
const SHOVE_PUSH := 11.7
const SHOVE_STUN := 0.6
const SHOVE_RECOIL := 3.8

#Shove rest, hit grace, reach and width (cosine of half its angle)
var shove_rest := 0.8
var grace := 1.5
var reach := 1.9
var cone := 0.35

var _rest_left: Dictionary = {}
var _grace_left: Dictionary = {}
var _shield_left: Dictionary = {}


func add(player_id: int) -> void:
	_rest_left[player_id] = 0.0
	_grace_left[player_id] = 0.0
	_shield_left[player_id] = 0.0


func tick(delta: float) -> void:
	for table: Dictionary in [_rest_left, _grace_left, _shield_left]:
		for id: int in table:
			table[id] = maxf(float(table[id]) - delta, 0.0)


func can_shove(player_id: int) -> bool:
	return _rest_left.has(player_id) and float(_rest_left[player_id]) <= 0.0


#Starts a shove rest; false while the last one still rests
func use_shove(player_id: int) -> bool:
	if not can_shove(player_id):
		return false
	_rest_left[player_id] = shove_rest
	return true


func rest_left(player_id: int) -> float:
	return _rest_left.get(player_id, 0.0)


func in_grace(player_id: int) -> bool:
	return float(_grace_left.get(player_id, 0.0)) > 0.0


func give_shield(player_id: int, seconds: float) -> void:
	if _shield_left.has(player_id):
		_shield_left[player_id] = seconds


func has_shield(player_id: int) -> bool:
	return float(_shield_left.get(player_id, 0.0)) > 0.0


#A blow: ignored in the grace, taken by the shield, or it counts and starts the grace
func strike(player_id: int) -> Outcome:
	if not _grace_left.has(player_id) or in_grace(player_id):
		return Outcome.IGNORED
	if has_shield(player_id):
		_shield_left[player_id] = 0.0
		_grace_left[player_id] = grace * 0.5
		return Outcome.BLOCKED
	_grace_left[player_id] = grace
	return Outcome.STRUCK


#Closest player in reach in front of "facing", or -1; "others" is {id: position}
func pick_victim(origin: Vector3, facing: Vector3, others: Dictionary) -> int:
	var best := -1
	var best_distance := INF
	var forward := Vector3(facing.x, 0.0, facing.z).normalized()
	for id: int in others:
		var offset: Vector3 = others[id] - origin
		if absf(offset.y) > 1.2:
			continue
		offset.y = 0.0
		var distance := offset.length()
		if distance > reach or distance < 0.01 or offset.normalized().dot(forward) < cone:
			continue
		if distance < best_distance:
			best_distance = distance
			best = id
	return best
