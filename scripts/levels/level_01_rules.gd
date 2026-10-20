class_name Level01Rules
extends RefCounted

#The rules of level 1 with no nodes: time, attempts, abilities and the end, with one state per player id

signal block_changed(active: bool)
signal player_fell(player_id: int, attempts_left: int)
signal outcome_decided(outcome: int)

enum Outcome { RUNNING, WON, LOST_TIME, LOST_ATTEMPTS }
enum Ability { BLOCK, SILENCE, REFUGE }
enum Use { OK, COOLDOWN }


#What belongs to one player
class PlayerState:
	var id: int
	var attempts_left: int
	var checkpoint: StringName
	var reached_goal := false
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


var settings: Level01Settings
var outcome := Outcome.RUNNING
var time_left := 0.0
#Seconds since the round started
var elapsed := 0.0
var players: Dictionary = {}

var _block_was_on := false


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
		_decide(Outcome.LOST_TIME)
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
	if state == null or not is_running():
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


#A player fell into the void: it loses an attempt and comes back protected. False when none are left.
func fall(player_id: int) -> bool:
	var state := state_of(player_id)
	if state == null or not is_running():
		return false
	state.attempts_left -= 1
	player_fell.emit(player_id, state.attempts_left)
	if state.attempts_left <= 0:
		_decide(Outcome.LOST_ATTEMPTS)
		return false
	state.respawn_left = settings.respawn_protection
	return true


#A shove only lands when the player is not protected nor still recovering from the last one
func register_hit(player_id: int) -> bool:
	var state := state_of(player_id)
	if state == null or not is_running() or is_protected(player_id) or state.hit_immunity_left > 0.0:
		return false
	state.hit_immunity_left = settings.hit_immunity
	return true


#True the first time the player passes through that vertex, which becomes its checkpoint
func reach_checkpoint(player_id: int, vertex: StringName) -> bool:
	var state := state_of(player_id)
	if state == null or state.checkpoint == vertex:
		return false
	state.checkpoint = vertex
	return true


#With every player at the goal the round is won
func reach_goal(player_id: int) -> void:
	var state := state_of(player_id)
	if state == null or not is_running():
		return
	state.reached_goal = true
	for other: PlayerState in players.values():
		if not other.reached_goal:
			return
	_decide(Outcome.WON)


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
