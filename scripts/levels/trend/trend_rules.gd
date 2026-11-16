class_name TrendRules
extends RefCounted

#The rules of the trend war with no nodes and by player id: five rounds, one in each zone. Every player always follows one trend, a kind
#drawn at random; touching a bubble of that kind completes it, counts one and draws the next. The viral bubble is the trend of everybody
#and counts more. More trends, more points. Every change is told with a signal

enum Phase { WAITING, REVEAL, RUN, DONE }

#The kind of the viral bubble, after the six kinds of the catalog
const VIRAL := TrendCatalog.COUNT

signal zone_announced(index: int, seconds: float)
signal zone_started(index: int)
signal trend_drawn(player_id: int, kind: int)
signal trend_completed(player_id: int, kind: int, value: int, total: int)
signal finished

class PlayerState:
	var id: int
	#The kind it follows now, and how many trends it completed
	var trend := -1
	var completed := 0
	var virals := 0

	func _init(player_id: int) -> void:
		id = player_id


var settings: TrendSettings
var sheet: ScoreSheet
var players: Dictionary = {}
var phase := Phase.WAITING
#The round being played (its index in the order of the zones) and the seconds left of it
var round_index := -1
var time_left := 0.0
#Trends a good player completes in the whole round: the scene works it out from the zones and the players
var par := 1.0

var _rng := RandomNumberGenerator.new()
var _announced := -1


func _init(round_settings: TrendSettings, score_sheet: ScoreSheet, ids: Array[int], seed_value: int) -> void:
	settings = round_settings
	sheet = score_sheet
	_rng.seed = seed_value
	for id in ids:
		players[id] = PlayerState.new(id)


func round_count() -> int:
	return TrendLayout.ZONE_COUNT


func state_of(player_id: int) -> PlayerState:
	return players.get(player_id)


#The first zone is announced; every player gets its first trend
func start() -> void:
	if phase != Phase.WAITING:
		return
	phase = Phase.REVEAL
	round_index = 0
	time_left = settings.reveal_seconds
	_announced = 0
	zone_announced.emit(0, time_left)
	for state: PlayerState in players.values():
		_draw(state)


func tick(delta: float) -> void:
	if phase == Phase.WAITING or phase == Phase.DONE:
		return
	time_left -= delta
	match phase:
		Phase.REVEAL:
			if time_left <= 0.0:
				phase = Phase.RUN
				time_left = settings.zone_seconds
				zone_started.emit(round_index)
		Phase.RUN:
			if round_index + 1 < round_count() and _announced <= round_index and time_left <= settings.next_notice:
				_announced = round_index + 1
				zone_announced.emit(round_index + 1, time_left)
			if time_left <= 0.0:
				if round_index + 1 >= round_count():
					phase = Phase.DONE
					time_left = 0.0
					finished.emit()
				else:
					round_index += 1
					time_left = settings.zone_seconds
					zone_started.emit(round_index)


#The kind this player follows; -1 while no zone is being played
func needed(player_id: int) -> int:
	var state := state_of(player_id)
	if phase != Phase.RUN or state == null:
		return -1
	return state.trend


#Whether a bubble of "kind" is a trend for this player now: its own kind, or the viral one
func wants(player_id: int, kind: int) -> bool:
	var need := needed(player_id)
	return need >= 0 and (kind == need or kind == VIRAL)


#A player touches a bubble of "kind": it only counts when it is its trend or the viral one; then it draws the next trend
func collect(player_id: int, kind: int) -> bool:
	if not wants(player_id, kind):
		return false
	var state := state_of(player_id)
	var value := settings.viral_value if kind == VIRAL else 1
	state.completed += value
	if kind == VIRAL:
		state.virals += 1
	trend_completed.emit(player_id, kind, value, state.completed)
	if kind != VIRAL:
		_draw(state)
	return true


#How far the round of the zone is, from 0 when it starts to 1 when it ends
func zone_share() -> float:
	if phase != Phase.RUN:
		return 0.0
	return clampf(1.0 - time_left / settings.zone_seconds, 0.0, 1.0)


func points_of(player_id: int) -> int:
	var state := state_of(player_id)
	return sheet.trend_score(state.completed if state != null else 0, par)


func totals() -> Dictionary:
	var result: Dictionary = {}
	for id: int in players:
		result[id] = points_of(id)
	return result


#A new trend: any kind but the one it just completed
func _draw(state: PlayerState) -> void:
	var kind := _rng.randi() % TrendCatalog.COUNT
	if kind == state.trend:
		kind = (kind + 1 + _rng.randi() % (TrendCatalog.COUNT - 1)) % TrendCatalog.COUNT
	state.trend = kind
	trend_drawn.emit(state.id, kind)
