extends RoundScene

#The 30 seconds before the first round to try the controls; ends when everybody votes ready or time runs out. In a room the server keeps
#the clock and the votes: once most players vote, the clock jumps to MAJORITY_SECONDS (if it had more left) and everybody goes on together

const DURATION := 30.0
const MAJORITY_SECONDS := 3.0
#How often the server tells the others the clock of the warm-up
const SHARE_EVERY := 0.5
const FALL_Y := -10.0
const STATION_RADIUS := 2.2
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(0.0, 0.05, 6.0), Vector3(-2.0, 0.05, 6.5), Vector3(2.0, 0.05, 6.5), Vector3(0.0, 0.05, 8.0),
]

var _time_left := DURATION
var _votes: Dictionary = {}
var _players: Array[Player] = []
var _station_on := false
var _done := false
var _local: Player
var _share_left := 0.0

@onready var _world: WarmupWorld = $World
@onready var _hud: WarmupHud = $Hud
@onready var _keys: LevelInput = $LevelInput


func _ready() -> void:
	super()
	_players = spawn_players(_actors, SPAWN_POINTS)
	for player in _players:
		player.dive_enabled = true
	var local := RoundScene.local_of(_players)
	_local = local
	#Each computer looks through its own player (otherwise the first camera made, the one of the server's player, stays on)
	local.view_camera().make_current()
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var air_time := 2.0 * local.jump_velocity / gravity
	var jump_height := local.jump_velocity * local.jump_velocity / (2.0 * gravity)
	_world.build(jump_height, local.move_speed * air_time)
	_keys.ready_pressed.connect(cast_vote.bind(local.player_id))
	if GameSession.is_networked():
		GameSession.net.vote_received.connect(_count_vote)
		GameSession.net.warm_received.connect(_on_warm)
	_hud.set_time(_time_left)
	_hud.set_votes(0, participants.size(), false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if paused or _done:
		return
	_time_left -= delta
	_hud.set_time(maxf(_time_left, 0.0))
	for index in _players.size():
		var player := _players[index]
		if player.remote:
			continue
		if player == _local and player.global_position.y < FALL_Y + 5.0 and player.velocity.y < 0.0:
			iris.close(0.25)
		if player.global_position.y < FALL_Y:
			_respawn(player, SPAWN_POINTS[mini(index, SPAWN_POINTS.size() - 1)])
			if player == _local:
				iris.open()
	if GameSession.is_networked() and GameSession.net.is_host():
		_share_left -= delta
		if _share_left <= 0.0:
			_share_left = SHARE_EVERY
			GameSession.net.send_warm(_time_left, _votes.size(), participants.size())
	#A client waits for the server to end the warm-up
	if _time_left <= 0.0 and (not GameSession.is_networked() or GameSession.net.is_host()):
		_finish()


#A player says they are ready; with everybody ready the warm-up ends
func cast_vote(player_id: int) -> void:
	if _done:
		return
	if GameSession.is_networked():
		if not _votes.has(player_id):
			_hud.set_votes(_votes.size() + 1, participants.size(), true)
			GameSession.net.vote()
		_votes[player_id] = true
		return
	_votes[player_id] = true
	_hud.set_votes(_votes.size(), participants.size(), true)
	if _votes.size() >= participants.size():
		_finish()


func _respawn(player: Player, point: Vector3) -> void:
	player.global_position = point
	player.clear_motion()
	_hud.toast("Otra vez")


#The server counts a vote: with most players ready the clock goes down to MAJORITY_SECONDS, and with all of them the warm-up ends
func _count_vote(player_id: int) -> void:
	if _done:
		return
	_votes[player_id] = true
	if _votes.size() * 2 > participants.size():
		_time_left = minf(_time_left, MAJORITY_SECONDS)
	_hud.set_votes(_votes.size(), participants.size(), _votes.has(GameSession.local_id))
	_share_left = 0.0


#A client follows the clock and the votes of the server
func _on_warm(seconds_left: float, votes: int, total: int) -> void:
	if _done:
		return
	_time_left = seconds_left
	_hud.set_votes(votes, total, _votes.has(GameSession.local_id))


#Next to the station the key turns it on and off; anywhere else it strikes a pose
func press_pose() -> void:
	if not _use_station():
		super()


func _use_station() -> bool:
	var flat := Vector2(_local.global_position.x - _world.station_position.x, _local.global_position.z - _world.station_position.z)
	if flat.length() > STATION_RADIUS:
		return false
	_station_on = not _station_on
	_world.set_station_active(_station_on)
	return true


func _pose_allowed(_player_id: int) -> bool:
	return not paused and not _done


func _pose_shown() -> bool:
	return not paused and not _done


func _finish() -> void:
	if _done:
		return
	_done = true
	for player in _players:
		player.set_input_enabled(false)
	if GameSession.phase == GameSession.Phase.WARMUP:
		GameSession.finish_warmup()
	else:
		GameSession.abandon()
