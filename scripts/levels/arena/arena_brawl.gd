class_name ArenaBrawl
extends RefCounted

#The shoves between players, with no nodes and by player id: how long a shove rests, the grace after being struck and the shield
#that takes one blow. Who is in front of whom is worked out from positions that the round passes in

enum Outcome { IGNORED, BLOCKED, STRUCK }

#Seconds a shove rests, seconds nobody can strike the same player again, how far a shove reaches and how wide it is (cosine of half its angle)
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


#Starts the rest of a shove; false while the last one still rests
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


#A blow lands on a player: nothing during the grace, the shield takes it if there is one, and otherwise it counts and the grace starts
func strike(player_id: int) -> Outcome:
	if not _grace_left.has(player_id) or in_grace(player_id):
		return Outcome.IGNORED
	if has_shield(player_id):
		_shield_left[player_id] = 0.0
		_grace_left[player_id] = grace * 0.5
		return Outcome.BLOCKED
	_grace_left[player_id] = grace
	return Outcome.STRUCK


#Who a shove hits: the closest one within reach and in front of "facing"; -1 when there is nobody. "others" is {player id: position}
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
