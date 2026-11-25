class_name PoseKeeper
extends Node

#Pose key in any round: stand still until moving, jumping, leaving the floor or being hit

signal pose_changed(player_id: int, posing: bool, style: int)

#Input strength that ends a pose
const BREAK_INPUT := 0.3
#A press in the air still poses if landing within this time
const PRESS_BUFFER := 0.3
#Seconds off the floor before the pose ends
const AIR_GRACE := 0.12

#Whether the round allows posing now
var allowed: Callable = func(_player_id: int) -> bool: return true

var _players: Dictionary = {}
#Per player: move keys held at pose start, air press timer and air time
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


#On the floor and allowed by the round
func can_pose(player_id: int) -> bool:
	var player: Player = _players.get(player_id)
	return player != null and is_free(player, float(_air.get(player_id, 0.0))) and allowed.call(player_id)


#On the floor, not carried, dazed, down or diving
static func is_free(player: Player, air_time := 0.0) -> bool:
	return air_time < AIR_GRACE and not player.carried and not player.is_dazed() and not player.is_down() and not player.is_diving()


#One press poses, the next drops it; an air press waits for landing
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


#Only a new press ends the pose; keys held since the start count once released
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
		if not player.posing:
			continue
		#Input is read from what the player asked; a jump that ends the pose is handed back
		var jumped := player.asked_jump or player.jump_requested
		if not can_pose(id) or jumped or moves(_held, id, player.asked_move):
			set_posing(id, false)
			if jumped:
				player.jump_requested = true
