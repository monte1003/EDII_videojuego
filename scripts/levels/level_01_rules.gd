class_name Level01Rules
extends RefCounted

#The rules of level 1 with no nodes: a race of up to four racers, time, attempts, abilities and the end, with one state per id

signal block_changed(active: bool)
signal player_fell(player_id: int, attempts_left: int)
signal racer_finished(player_id: int, place: int)
signal racer_eliminated(player_id: int)
signal window_opened(seconds: float)
signal outcome_decided(outcome: int)

enum Outcome { RUNNING, WON, LOST_TIME, LOST_ATTEMPTS }
enum Ability { BLOCK, SILENCE, REFUGE }
enum Use { OK, COOLDOWN }


#What belongs to one racer
class PlayerState:
	var id: int
	var attempts_left: int
	var checkpoint: StringName
	#1 for the first to arrive, and so on; 0 while it has not arrived
	var place := 0
	var finish_time := 0.0
	var eliminated := false
	#How far it is from the goal (lower is closer); the level keeps it up to date
	var progress := INF
	var respawn_left := 0.0
	var hit_immunity_left := 0.0
	var block_left := 0.0
	var block_cooldown := 0.0
	var silence_left := 0.0
	var silence_cooldown := 0.0
	var refuge_left := 0.0
	var refuge_cooldown := 0.0

	func _init(player_id: int, attempts: int, start: StringName) -> void:
		id = player_id
		attempts_left = attempts
		checkpoint = start

	func reached_goal() -> bool:
		return place > 0

	func is_racing() -> bool:
		return place == 0 and not eliminated


var settings: Level01Settings
var outcome := Outcome.RUNNING
var time_left := 0.0
#Seconds since the round started
var elapsed := 0.0
#Seconds left for the rest to arrive once somebody did; negative while nobody has
var window_left := -1.0
var players: Dictionary = {}

var _block_was_on := false
var _arrived := 0


func _init(config: Level01Settings, player_ids: Array[int], start: StringName) -> void:
	settings = config
	time_left = settings.time_limit
	for id in player_ids:
		players[id] = PlayerState.new(id, settings.attempts, start)


func state_of(player_id: int) -> PlayerState:
	return players.get(player_id)


func is_running() -> bool:
	return outcome == Outcome.RUNNING


#Advances the round; it does nothing once the round is decided
func tick(delta: float) -> void:
	if not is_running():
		return
	elapsed += delta
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_close_race(Outcome.LOST_TIME)
		return
	if window_left >= 0.0:
		window_left -= delta
		if window_left < 0.0:
			window_left = 0.0
			_close_race(Outcome.LOST_TIME)
			return
	for state: PlayerState in players.values():
		_tick_player(state, delta)
	var on := block_active()
	if on != _block_was_on:
		_block_was_on = on
		block_changed.emit(on)


#The bridge stays closed to the bots while any player has Bloquear active
func block_active() -> bool:
	for state: PlayerState in players.values():
		if state.block_left > 0.0:
			return true
	return false


func use_ability(player_id: int, ability: int) -> int:
	var state := state_of(player_id)
	if state == null or not is_running() or not state.is_racing():
		return Use.COOLDOWN
	match ability:
		Ability.BLOCK:
			if state.block_cooldown > 0.0:
				return Use.COOLDOWN
			state.block_cooldown = settings.block_cooldown
			state.block_left = settings.block_duration
		Ability.SILENCE:
			if state.silence_cooldown > 0.0:
				return Use.COOLDOWN
			state.silence_cooldown = settings.silence_cooldown
			state.silence_left = settings.silence_duration
		Ability.REFUGE:
			if state.refuge_cooldown > 0.0:
				return Use.COOLDOWN
			state.refuge_cooldown = settings.refuge_cooldown
			state.refuge_left = settings.refuge_duration
	return Use.OK


#Seconds until the ability can be used again; 0 when it is ready
func cooldown_left(player_id: int, ability: int) -> float:
	var state := state_of(player_id)
	if state == null:
		return 0.0
	match ability:
		Ability.BLOCK:
			return state.block_cooldown
		Ability.SILENCE:
			return state.silence_cooldown
	return state.refuge_cooldown


#Seconds the effect of the ability still lasts; 0 when it is not active
func active_left(player_id: int, ability: int) -> float:
	var state := state_of(player_id)
	if state == null:
		return 0.0
	match ability:
		Ability.BLOCK:
			return state.block_left
		Ability.SILENCE:
			return state.silence_left
	return state.refuge_left


#Leaving the shelter ends its protection early
func leave_refuge(player_id: int) -> void:
	var state := state_of(player_id)
	if state != null:
		state.refuge_left = 0.0


func protection_left(player_id: int) -> float:
	var state := state_of(player_id)
	return maxf(state.respawn_left, state.refuge_left) if state != null else 0.0


func is_protected(player_id: int) -> bool:
	return protection_left(player_id) > 0.0


func detection_radius(player_id: int) -> float:
	var state := state_of(player_id)
	if state != null and state.silence_left > 0.0:
		return settings.silenced_detection_radius
	return settings.detection_radius


#A racer fell into the void: it loses an attempt and comes back protected. False when none are left.
func fall(player_id: int) -> bool:
	var state := state_of(player_id)
	if state == null or not is_running() or not state.is_racing():
		return false
	state.attempts_left -= 1
	player_fell.emit(player_id, state.attempts_left)
	if state.attempts_left <= 0:
		state.eliminated = true
		racer_eliminated.emit(player_id)
		_check_end()
		return false
	state.respawn_left = settings.respawn_protection
	return true


#A shove only lands when the racer is not protected nor still recovering from the last one
func register_hit(player_id: int) -> bool:
	var state := state_of(player_id)
	if state == null or not is_running() or is_protected(player_id) or state.hit_immunity_left > 0.0:
		return false
	state.hit_immunity_left = settings.hit_immunity
	return true


#True the first time the racer passes through that vertex, which becomes its checkpoint
func reach_checkpoint(player_id: int, vertex: StringName) -> bool:
	var state := state_of(player_id)
	if state == null or state.checkpoint == vertex:
		return false
	state.checkpoint = vertex
	return true


#The racer arrives: it gets the next place and the first one to arrive opens the window for the rest
func reach_goal(player_id: int) -> void:
	var state := state_of(player_id)
	if state == null or not is_running() or not state.is_racing():
		return
	_arrived += 1
	state.place = _arrived
	state.finish_time = elapsed
	racer_finished.emit(player_id, state.place)
	if window_left < 0.0 and not _all_arrived():
		window_left = settings.finish_window
		window_opened.emit(window_left)
	_check_end()


func racers_in_race() -> int:
	return players.size()


#Ids from first to last: the ones that arrived in order, then the rest by how close they are, the eliminated at the end
func standings() -> Array[int]:
	var ids: Array[int] = []
	for id: int in players:
		ids.append(id)
	ids.sort_custom(_ahead)
	return ids


#The place the racer would take now: its final place once it arrived, else its position in the standings
func place_of(player_id: int) -> int:
	return standings().find(player_id) + 1


func _ahead(a: int, b: int) -> bool:
	var first: PlayerState = players[a]
	var second: PlayerState = players[b]
	if first.reached_goal() != second.reached_goal():
		return first.reached_goal()
	if first.reached_goal():
		return first.place < second.place
	if first.eliminated != second.eliminated:
		return second.eliminated
	if not is_equal_approx(first.progress, second.progress):
		return first.progress < second.progress
	return a < b


#The round is over when no player is still racing: every one arrived or was eliminated
func _check_end() -> void:
	if not is_running():
		return
	var any_player_arrived := false
	for state: PlayerState in players.values():
		if state.is_racing():
			return
		if state.reached_goal():
			any_player_arrived = true
	_decide(Outcome.WON if any_player_arrived else Outcome.LOST_ATTEMPTS)


func _all_arrived() -> bool:
	for state: PlayerState in players.values():
		if state.is_racing():
			return false
	return true


#Time or the window ran out: whoever is still racing is left out
func _close_race(reason: int) -> void:
	for state: PlayerState in players.values():
		if state.reached_goal():
			_decide(Outcome.WON)
			return
	_decide(reason)


func _tick_player(state: PlayerState, delta: float) -> void:
	state.hit_immunity_left = maxf(state.hit_immunity_left - delta, 0.0)
	state.respawn_left = maxf(state.respawn_left - delta, 0.0)
	state.block_cooldown = maxf(state.block_cooldown - delta, 0.0)
	state.silence_cooldown = maxf(state.silence_cooldown - delta, 0.0)
	state.refuge_cooldown = maxf(state.refuge_cooldown - delta, 0.0)
	state.block_left = maxf(state.block_left - delta, 0.0)
	state.silence_left = maxf(state.silence_left - delta, 0.0)
	state.refuge_left = maxf(state.refuge_left - delta, 0.0)


func _decide(result: int) -> void:
	if not is_running():
		return
	outcome = result
	outcome_decided.emit(result)
