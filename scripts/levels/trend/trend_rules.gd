class_name TrendRules
extends RefCounted

#The rules of the trend war with no nodes and by player id: five trends, each a chain of kinds to fetch in order before its clock
#runs out. Whoever completes it sooner gets more points; whoever does not complete it gets none. Every change is told with a signal

enum Phase { WAITING, REVEAL, RUN, REST, DONE }

signal trend_revealed(index: int, chain: Array[int], limit: float)
signal run_started(index: int)
signal item_collected(player_id: int, slot: int, kind: int)
signal item_lost(player_id: int, slot: int, kind: int)
signal trend_completed(player_id: int, place: int, points: int)
signal round_ended(index: int)
signal finished

class PlayerState:
	var id: int
	#How many kinds of the chain it already has
	var collected := 0
	var done := false
	var place := 0
	var round_points := 0
	var total := 0
	var completed := 0
	var best := 0
	#Seconds of the fastest possible way to this trend from where it stood when the clock started
	var par := 0.0

	func _init(player_id: int) -> void:
		id = player_id


var settings: TrendSettings
var sheet: ScoreSheet
var players: Dictionary = {}
var phase := Phase.WAITING
var round_index := -1
var chain: Array[int] = []
#Seconds left of the phase that is running
var time_left := 0.0

var _rng := RandomNumberGenerator.new()
var _finishers := 0


func _init(round_settings: TrendSettings, score_sheet: ScoreSheet, ids: Array[int], seed_value: int) -> void:
	settings = round_settings
	sheet = score_sheet
	_rng.seed = seed_value
	for id in ids:
		players[id] = PlayerState.new(id)


func round_count() -> int:
	return mini(settings.limits.size(), settings.lengths.size())


func limit_of(index: int) -> float:
	return settings.limits[clampi(index, 0, settings.limits.size() - 1)]


func state_of(player_id: int) -> PlayerState:
	return players.get(player_id)


#The first trend is shown
func start() -> void:
	if phase == Phase.WAITING:
		_reveal(0)


func tick(delta: float) -> void:
	if phase == Phase.WAITING or phase == Phase.DONE:
		return
	time_left -= delta
	if time_left > 0.0:
		return
	match phase:
		Phase.REVEAL:
			phase = Phase.RUN
			time_left = limit_of(round_index)
			run_started.emit(round_index)
		Phase.RUN:
			_end_round()
		Phase.REST:
			if round_index + 1 >= round_count():
				phase = Phase.DONE
				finished.emit()
			else:
				_reveal(round_index + 1)


#The scene says how long the fastest way is for each player once the clock starts
func set_par(player_id: int, seconds: float) -> void:
	var state := state_of(player_id)
	if state != null:
		state.par = seconds


#The kind this player has to fetch now; -1 when it is done or no trend is running
func needed(player_id: int) -> int:
	var state := state_of(player_id)
	if phase != Phase.RUN or state == null or state.done or state.collected >= chain.size():
		return -1
	return chain[state.collected]


#A player touches a bubble of "kind": it only counts when it is the one it needs now
func collect(player_id: int, kind: int) -> bool:
	if kind < 0 or needed(player_id) != kind:
		return false
	var state := state_of(player_id)
	state.collected += 1
	item_collected.emit(player_id, state.collected - 1, kind)
	if state.collected >= chain.size():
		_complete(state)
	return true


#A shove or a hater takes the last item of a player that has not completed the trend; returns its kind, or -1 when it had none
func strike(player_id: int) -> int:
	var state := state_of(player_id)
	if phase != Phase.RUN or state == null or state.done or state.collected <= 0:
		return -1
	state.collected -= 1
	var kind := chain[state.collected]
	item_lost.emit(player_id, state.collected, kind)
	return kind


#Share of the time between the par and the limit that is still left for a player: 1 at the par or sooner, 0 at the limit
func left_share(player_id: int) -> float:
	var state := state_of(player_id)
	var limit := limit_of(round_index)
	if state == null or limit - state.par <= 0.01:
		return 0.0
	return clampf(time_left / (limit - state.par), 0.0, 1.0)


func total_of(player_id: int) -> int:
	var state := state_of(player_id)
	return state.total if state != null else 0


func totals() -> Dictionary:
	var result: Dictionary = {}
	for id: int in players:
		result[id] = (players[id] as PlayerState).total
	return result


#A chain of kinds for a trend: no kind twice in a row, and from "repeat_from" on the first one comes back once
static func make_chain(length: int, repeats: bool, rng: RandomNumberGenerator) -> Array[int]:
	var made: Array[int] = []
	var pool: Array[int] = []
	for kind in TrendCatalog.COUNT:
		pool.append(kind)
	while made.size() < length:
		var pick := pool[rng.randi() % pool.size()]
		pool.erase(pick)
		made.append(pick)
	if repeats and length >= 3:
		made[2 + rng.randi() % (length - 2)] = made[0]
	return made


func _reveal(index: int) -> void:
	round_index = index
	phase = Phase.REVEAL
	time_left = settings.reveal_seconds
	chain = make_chain(settings.lengths[index], index >= settings.repeat_from, _rng)
	_finishers = 0
	for state: PlayerState in players.values():
		state.collected = 0
		state.done = false
		state.place = 0
		state.round_points = 0
		state.par = 0.0
	trend_revealed.emit(index, chain, limit_of(index))


func _complete(state: PlayerState) -> void:
	_finishers += 1
	state.done = true
	state.place = _finishers
	state.round_points = sheet.trend_points(left_share(state.id), state.place if players.size() > 1 else 1)
	state.total += state.round_points
	state.completed += 1
	state.best = maxi(state.best, state.round_points)
	trend_completed.emit(state.id, state.place, state.round_points)
	if _finishers >= players.size():
		_end_round()


func _end_round() -> void:
	if phase != Phase.RUN:
		return
	phase = Phase.REST
	time_left = settings.rest_seconds
	round_ended.emit(round_index)
