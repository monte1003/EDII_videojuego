extends RoundScene

#The 30 seconds before the first round to try the controls; ends when everybody votes ready or time runs out

const DURATION := 30.0
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

@onready var _world: WarmupWorld = $World
@onready var _hud: WarmupHud = $Hud
@onready var _keys: LevelInput = $LevelInput


func _ready() -> void:
	super()
	_players = spawn_players(_actors, SPAWN_POINTS)
	var local := _players[0]
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var air_time := 2.0 * local.jump_velocity / gravity
	var jump_height := local.jump_velocity * local.jump_velocity / (2.0 * gravity)
	_world.build(jump_height, local.move_speed * air_time)
	_keys.confirm_pressed.connect(cast_vote.bind(local.player_id))
	_keys.interact_pressed.connect(_use_station)
	_hud.set_time(_time_left)
	_hud.set_votes(0, participants.size(), false)
	_hud.toast("Prueba los controles: la partida empieza enseguida")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if paused or _done:
		return
	_time_left -= delta
	_hud.set_time(maxf(_time_left, 0.0))
	for index in _players.size():
		if _players[index].global_position.y < FALL_Y:
			_respawn(_players[index], SPAWN_POINTS[mini(index, SPAWN_POINTS.size() - 1)])
	if _time_left <= 0.0:
		_finish()


#A player says they are ready; with everybody ready the warm-up ends
func cast_vote(player_id: int) -> void:
	if _done:
		return
	_votes[player_id] = true
	_hud.set_votes(_votes.size(), participants.size(), true)
	if _votes.size() >= participants.size():
		_finish()


func _respawn(player: Player, point: Vector3) -> void:
	player.global_position = point
	player.clear_motion()
	_hud.toast("Sin problema, ¡otra vez!")


func _use_station() -> void:
	var flat := Vector2(_players[0].global_position.x - _world.station_position.x, _players[0].global_position.z - _world.station_position.z)
	if flat.length() > STATION_RADIUS:
		return
	_station_on = not _station_on
	_world.set_station_active(_station_on)
	_hud.toast("¡Eso es! Así se usan las consolas")


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
