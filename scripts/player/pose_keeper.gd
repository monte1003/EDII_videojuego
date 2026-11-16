class_name PoseKeeper
extends Node

#Any player can strike a pose or a dance in any round with the pose key: it stands still until it moves, jumps, leaves the floor or
#takes a blow. The keys that were already down when the pose started do not break it until they are let go, a press in the air
#waits a moment for the landing, and a floor that shakes for a frame does not count as leaving it

signal pose_changed(player_id: int, posing: bool, style: int)

#How hard the keys must be pressed for a move to end the pose
const BREAK_INPUT := 0.3
#A press in the air still strikes the pose if the player lands within this many seconds
const PRESS_BUFFER := 0.3
#Seconds off the floor before the pose ends: a bump of a moving floor does not end it
const AIR_GRACE := 0.12

#Whether the round lets a player pose right now (it is running, it has not finished)
var allowed: Callable = func(_player_id: int) -> bool: return true

var _players: Dictionary = {}
#Per player: the move keys were down when the pose started, seconds left of a press in the air, seconds off the floor
var _held: Dictionary = {}
var _pending: Dictionary = {}
var _air: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func add(player: Player) -> void:
	_players[player.player_id] = player
	_air[player.player_id] = 0.0


func is_posing(player_id: int) -> bool:
	var player: Player = _players.get(player_id)
	return player != null and player.posing


#Whether the player stands free on the floor and the round lets it pose
func can_pose(player_id: int) -> bool:
	var player: Player = _players.get(player_id)
	return player != null and is_free(player, float(_air.get(player_id, 0.0))) and allowed.call(player_id)


#Free to pose: on the floor (or off it for less than AIR_GRACE), not carried, not dazed, not down and not diving
static func is_free(player: Player, air_time := 0.0) -> bool:
	return air_time < AIR_GRACE and not player.carried and not player.is_dazed() and not player.is_down() and not player.is_diving()


#One press strikes the pose and the next one drops it; a press in the air is kept a moment for the landing
func toggle(player_id: int) -> bool:
	if is_posing(player_id):
		return set_posing(player_id, false)
	if set_posing(player_id, true):
		return true
	var player: Player = _players.get(player_id)
	if player != null and not player.is_on_floor() and allowed.call(player_id):
		_pending[player_id] = PRESS_BUFFER
	return false


func set_posing(player_id: int, on: bool) -> bool:
	var player: Player = _players.get(player_id)
	if player == null or player.posing == on or (on and not can_pose(player_id)):
		return false
	_pending.erase(player_id)
	if on:
		_held[player_id] = player.move_input.length() > BREAK_INPUT
		player.pose_style = next_style(player.pose_style, CharacterModel.POSES.size(), _rng)
	player.posing = on
	pose_changed.emit(player_id, on, player.pose_style)
	return true


func stop_all() -> void:
	for id: int in _players:
		set_posing(id, false)


#Any pose or dance but the last one
static func next_style(last: int, count: int, rng: RandomNumberGenerator) -> int:
	if count < 2:
		return 0
	var pick := rng.randi() % (count - 1)
	return pick if last < 0 or pick < last else pick + 1


#A move ends the pose only when it is a new press: a key held since the pose started counts once it is let go
static func moves(held: Dictionary, player_id: int, input: Vector2, threshold := BREAK_INPUT) -> bool:
	if input.length() <= threshold:
		held[player_id] = false
		return false
	return not bool(held.get(player_id, false))


func _physics_process(delta: float) -> void:
	for id: int in _players:
		var player: Player = _players[id]
		if not is_instance_valid(player) or player.remote:
			continue
		_air[id] = 0.0 if player.is_on_floor() else float(_air[id]) + delta
		if _pending.has(id):
			_pending[id] = float(_pending[id]) - delta
			if player.is_on_floor():
				set_posing(id, true)
			if float(_pending.get(id, 0.0)) <= 0.0:
				_pending.erase(id)
		if player.posing and (not can_pose(id) or player.jump_requested or moves(_held, id, player.move_input)):
			set_posing(id, false)
