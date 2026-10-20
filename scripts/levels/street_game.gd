class_name StreetGame
extends Node3D

#Street minigame: dodge the cars and pedestrians that push you toward the end line until time runs out

enum Phase { COUNTDOWN, RUNNING, ENDED }

const SCREEN_ID := &"street_game"
#1.5 m wide: half of the sidewalk, so the sidewalk is not a safe place
const PEDESTRIAN_RADIUS := 0.75
const PEDESTRIAN_HEIGHT := 1.8
const CAR_COLORS: Array[Color] = [
	Color("e14b6a"), Color("2f9fb8"), Color("e08a22"), Color("7b6cf6"), Color("3fb27f"), Color("fd567f"),
]
const PEDESTRIAN_COLORS: Array[Color] = [
	Color("f4c27a"), Color("9ad1f5"), Color("c9a0f0"), Color("f59ab3"), Color("8fd6b4"),
]

#A row where obstacles appear: a car lane or a sidewalk
class Lane:
	var kind: int
	var z: float
	#Offset from z (0 on car lanes); on a sidewalk a quarter of its width, upper or lower half
	var slot_offset: float
	var timer := 0.0
	var last_spawn := -100.0
	#Length of the last vehicle of this lane, for the side-by-side test
	var last_length := 0.0

	func _init(lane_kind: int, lane_z: float, lane_slot_offset: float) -> void:
		kind = lane_kind
		z = lane_z
		slot_offset = lane_slot_offset


#Used when the scene runs without going through character select
@export var default_character: CharacterData

@export_group("Round")
@export var time_limit := 60.0
@export var countdown_seconds := 3.0

@export_group("Street")
@export_range(1, 5) var lane_count := 3
@export var lane_width := 3.0
@export var sidewalk_width := 3.0
#The runner starts at start_x and loses when a hit throws it past end_x
@export var start_x := -7.0
@export var end_x := 11.0
#Where obstacles appear (off screen) and where they are removed
@export var spawn_x := -36.0
@export var despawn_x := 26.0

@export_group("Obstacles")
@export var car_speed := 7.0
@export var car_length := 4.0
@export var car_width := 2.4
@export var pedestrian_speed := 2.6
#Speed multiplier of the whole flow at the start and at the end of the round
@export var start_speed_scale := 1.0
@export var end_speed_scale := 2.2
@export var car_interval_min := 1.6
@export var car_interval_max := 3.4
@export var pedestrian_interval_min := 1.0
@export var pedestrian_interval_max := 2.4
#A lane waits if every other lane spawned this recently, so the street is never a full wall
@export var wall_window := 0.6
#Cars that may run side by side; with 3 lanes, 2 always leaves one lane to escape through
@export var max_cars_side_by_side := 2
#Extra meters between cars of different lanes for them not to count as side by side
@export var car_side_gap := 2.5
#Throw-back speed of each kind of hit (about 4.5 m for a car and 2.5 m for a pedestrian)
@export var car_knockback := 12.0
@export var pedestrian_knockback := 9.0
#Chance that a car is replaced by a tank as wide as two lanes
@export_range(0.0, 1.0) var tank_chance := 0.01
@export var tank_length := 6.0
@export var tank_knockback := 15.0
#Speed of the shove up or down the screen that takes the runner out of the obstacle's way
@export var side_shove := 8.0

@export_group("Victory")
@export var win_zoom_time := 1.4
#Far enough to keep the whole victory jump in the frame
@export var win_camera_offset := Vector3(-5.6, 1.8, 2.2)
@export var win_fov := 40.0

var phase := Phase.COUNTDOWN
var elapsed := 0.0

var _runner: StreetRunner
var _lanes: Array[Lane] = []
var _obstacles: Array[StreetObstacle] = []
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _phase_timer := 0.0
var _countdown_shown := 0
var _paused := false
#After a victory the whole street stops
var _frozen := false
#A tank was drawn but has not found room yet
var _tank_pending := false
var _next_speed_notice := 1
var _hud_timer := 0.0

@onready var _camera: Camera3D = $Camera3D
@onready var _world: StreetWorld = $World
@onready var _actors: Node3D = $Actors
@onready var _obstacle_root: Node3D = $Obstacles
@onready var _hud: StreetHud = $Hud
@onready var _pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	if ScreenFlow.tree.has(SCREEN_ID):
		ScreenFlow.mark_current(SCREEN_ID)
	_rng.randomize()
	var half_width := lane_count * lane_width / 2.0
	_world.build(half_width, sidewalk_width, lane_count, spawn_x - 10.0, despawn_x + 10.0, end_x)
	_build_lanes(half_width)
	_spawn_runner(half_width)

	_pause_menu.opened.connect(_on_pause_opened)
	_pause_menu.closed.connect(_on_pause_closed)
	_hud.retry_requested.connect(_retry)
	_hud.menu_requested.connect(ScreenFlow.back)
	_hud.set_hint("%s / %s para moverte · %s salta · Esquiva autos y peatones · Aguanta %d s" % [
		InputHints.key_markup(&"move_forward"), InputHints.key_markup(&"move_back"),
		InputHints.key_markup(&"jump"), int(time_limit)])
	_hud.set_time(time_limit)
	_hud.set_speed(start_speed_scale)
	_hud.set_danger(0.0)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_phase_timer = countdown_seconds
	_countdown_shown = ceili(_phase_timer)
	_hud.show_countdown(str(_countdown_shown))


func _build_lanes(half_width: float) -> void:
	for index in lane_count:
		_lanes.append(Lane.new(StreetObstacle.Kind.CAR, -half_width + lane_width * (index + 0.5), 0.0))
	for side in [-1.0, 1.0]:
		_lanes.append(Lane.new(StreetObstacle.Kind.PEDESTRIAN, side * (half_width + sidewalk_width / 2.0),
			sidewalk_width / 4.0))
	for lane in _lanes:
		lane.timer = _rng.randf_range(0.0, _interval_max(lane.kind))


func _spawn_runner(half_width: float) -> void:
	var character := GameState.get_character(GameState.PLAYER_ONE)
	if character == null:
		character = default_character
	_runner = StreetRunner.new()
	_runner.player_id = GameState.PLAYER_ONE
	_runner.street_half_width = half_width
	_runner.sidewalk_height = StreetWorld.SIDEWALK_HEIGHT
	var edge := half_width + sidewalk_width - _runner.radius
	_runner.min_z = -edge
	_runner.max_z = edge
	_actors.add_child(_runner)
	_runner.position = Vector3(start_x, 0.0, 0.0)
	_runner.set_character(character)


func _physics_process(delta: float) -> void:
	if _paused:
		return
	_clock += delta
	match phase:
		Phase.COUNTDOWN:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_begin_round()
			else:
				var shown := ceili(_phase_timer)
				if shown != _countdown_shown:
					_countdown_shown = shown
					_hud.show_countdown(str(shown))
		Phase.RUNNING:
			_update_running(delta)
	#The street keeps flowing during the countdown and after a defeat
	if not _frozen:
		_update_obstacles(delta)


func _begin_round() -> void:
	phase = Phase.RUNNING
	elapsed = 0.0
	_hud.hide_countdown()
	_runner.set_input_enabled(true)
	_hud.toast("¡Aguanta! Cada choque te empuja hacia el FIN")


func _update_running(delta: float) -> void:
	elapsed += delta
	if elapsed >= time_limit:
		_hud.set_time(0.0)
		_finish(true, "¡Aguantaste!",
			"%d segundos sin dejarte arrastrar por la corriente. Mirar antes de moverte también es cuidarte." % int(time_limit))
		return

	_check_hits()
	if _runner.position.x >= end_x:
		_hud.set_danger(1.0)
		_finish(false, "Te arrastró la corriente",
			"Aguantaste %d s. Cada choque te hace retroceder: anticipa el camino e inténtalo de nuevo." % floori(elapsed))
		return

	#Tells the player every third of the round that the flow got faster
	if _next_speed_notice < 3 and elapsed >= time_limit * _next_speed_notice / 3.0:
		_next_speed_notice += 1
		_hud.toast("¡Todo va más rápido!")

	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		_hud.set_time(time_limit - elapsed)
		_hud.set_speed(_speed_scale())
		_hud.set_danger((_runner.position.x - start_x) / (end_x - start_x))


func _speed_scale() -> float:
	return lerpf(start_speed_scale, end_speed_scale, clampf(elapsed / time_limit, 0.0, 1.0))


func _finish(victory: bool, title: String, message: String) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	_runner.set_input_enabled(false)
	#A late Esc press must not open the pause menu over the final panel
	_pause_menu.set_process_unhandled_input(false)
	if not victory:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_hud.show_end(title, message, victory)
		return

	#Victory: the street stops, the camera moves in front of the runner and then the panel shows
	_frozen = true
	_hud.hide_play_ui()
	#Aimed above the head: the jump goes about 1.3 m up
	var focus := _runner.position + Vector3(0.0, 0.85 * _runner.model_scale, 0.0)
	var target := Transform3D(Basis(), _runner.position + win_camera_offset).looking_at(focus, Vector3.UP)
	_runner.celebrate(target.origin)
	_clear_view(target.origin)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "global_transform", target, win_zoom_time)
	tween.tween_property(_camera, "fov", win_fov, win_zoom_time)
	tween.chain().tween_callback(_runner.jump)
	tween.chain().tween_interval(0.8)
	tween.chain().tween_callback(func() -> void:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_hud.show_end(title, message, victory))


#Obstacles between the close-up camera and the runner shrink away so they never hide it
func _clear_view(camera_position: Vector3) -> void:
	for obstacle in _obstacles:
		var from_x := minf(camera_position.x, _runner.position.x) - 2.5
		var to_x := maxf(camera_position.x, _runner.position.x) + 1.0
		var in_path := obstacle.position.x + obstacle.half_extents.x >= from_x \
			and obstacle.position.x - obstacle.half_extents.x <= to_x \
			and absf(obstacle.position.z - (camera_position.z + _runner.position.z) / 2.0) <= obstacle.half_extents.y + 2.0
		if in_path:
			create_tween().tween_property(obstacle, "scale", Vector3.ONE * 0.01, 0.3)


func _retry() -> void:
	get_tree().reload_current_scene()


func _update_obstacles(delta: float) -> void:
	for lane in _lanes:
		lane.timer -= delta
		if lane.timer <= 0.0:
			_try_spawn(lane)

	var multiplier := _speed_scale()
	for index in range(_obstacles.size() - 1, -1, -1):
		var obstacle := _obstacles[index]
		obstacle.position.x += obstacle.base_speed * multiplier * delta
		if obstacle.position.x - obstacle.half_extents.x > despawn_x:
			obstacle.queue_free()
			_obstacles.remove_at(index)


func _try_spawn(lane: Lane) -> void:
	var others_busy := true
	for other in _lanes:
		if other != lane and _clock - other.last_spawn > wall_window:
			others_busy = false
			break
	if others_busy:
		lane.timer = wall_window
		return
	if lane.kind == StreetObstacle.Kind.PEDESTRIAN:
		_spawn_pedestrian(lane)
		return
	if not _tank_pending and _rng.randf() < tank_chance:
		_tank_pending = true
	#A tank that does not fit yet waits for the next car instead of being lost
	if _tank_pending and _try_spawn_tank(lane):
		_tank_pending = false
		return
	var single: Array[Lane] = [lane]
	if _side_by_side(car_length, single) >= max_cars_side_by_side:
		lane.timer = 0.25
		return
	_mark_spawned(lane, car_length)
	var car := StreetObstacle.new()
	car.build_car(CAR_COLORS[_rng.randi() % CAR_COLORS.size()], car_length, car_width)
	car.base_speed = car_speed
	car.knockback = car_knockback
	_place(car, lane.z, 0.0)


func _spawn_pedestrian(lane: Lane) -> void:
	_mark_spawned(lane, 0.0)
	var pedestrian := StreetObstacle.new()
	pedestrian.build_pedestrian(PEDESTRIAN_COLORS[_rng.randi() % PEDESTRIAN_COLORS.size()],
		PEDESTRIAN_RADIUS, PEDESTRIAN_HEIGHT)
	pedestrian.base_speed = pedestrian_speed
	pedestrian.knockback = pedestrian_knockback
	var slot := lane.slot_offset if _rng.randf() < 0.5 else -lane.slot_offset
	_place(pedestrian, lane.z + slot, StreetWorld.SIDEWALK_HEIGHT)


#A tank fills this lane and a neighbour, so it counts as two cars; false when no neighbour has room
func _try_spawn_tank(lane: Lane) -> bool:
	var car_lanes: Array[Lane] = []
	for candidate in _lanes:
		if candidate.kind == StreetObstacle.Kind.CAR:
			car_lanes.append(candidate)
	var index := car_lanes.find(lane)
	var partners: Array[Lane] = []
	for step in [-1, 1]:
		if index + step >= 0 and index + step < car_lanes.size():
			partners.append(car_lanes[index + step])
	if partners.size() == 2 and _rng.randf() < 0.5:
		partners.reverse()
	for partner in partners:
		#The tank must not overlap the last car of the neighbour lane
		if _too_close(tank_length, partner):
			continue
		var pair: Array[Lane] = [lane, partner]
		if _side_by_side(tank_length, pair) + 2 > max_cars_side_by_side:
			continue
		_mark_spawned(lane, tank_length)
		_mark_spawned(partner, tank_length)
		var tank := StreetObstacle.new()
		tank.build_tank(tank_length, lane_width + car_width)
		tank.base_speed = car_speed
		tank.knockback = tank_knockback
		_place(tank, (lane.z + partner.z) / 2.0, 0.0)
		_hud.toast("¡Cuidado, viene un tanque!")
		return true
	return false


#Cars in other lanes that would run side by side with a new vehicle of "length"
func _side_by_side(length: float, ignored: Array[Lane]) -> int:
	var count := 0
	for other in _lanes:
		if other.kind == StreetObstacle.Kind.CAR and not ignored.has(other) and _too_close(length, other):
			count += 1
	return count


#True when a new vehicle of "length" would still overlap (plus the gap) the last one of "lane"
func _too_close(length: float, lane: Lane) -> bool:
	var window := ((length + lane.last_length) / 2.0 + car_side_gap) / (car_speed * _speed_scale())
	return _clock - lane.last_spawn < window


func _mark_spawned(lane: Lane, length: float) -> void:
	lane.last_spawn = _clock
	lane.last_length = length
	lane.timer = _rng.randf_range(_interval_min(lane.kind), _interval_max(lane.kind))


func _place(obstacle: StreetObstacle, z: float, height: float) -> void:
	obstacle.position = Vector3(spawn_x, height, z)
	_obstacle_root.add_child(obstacle)
	_obstacles.append(obstacle)


#The runner stays invulnerable while it touches any obstacle, so one contact is one hit
func _check_hits() -> void:
	var hit_by: StreetObstacle = null
	for obstacle in _obstacles:
		if obstacle.overlaps(_runner.position, _runner.radius):
			hit_by = obstacle
			break
	_runner.touching = hit_by != null
	if hit_by == null or not _runner.can_be_hit():
		return
	_runner.take_hit(hit_by.knockback, _shove_side(hit_by), side_shove)
	match hit_by.kind:
		StreetObstacle.Kind.CAR:
			_hud.warn("¡Choque!")
		StreetObstacle.Kind.TANK:
			_hud.warn("¡TANQUE!")
		_:
			_hud.warn("¡Ups!")


#Up or down the screen, away from the obstacle's centre; toward the open side near an edge
func _shove_side(obstacle: StreetObstacle) -> float:
	var side := signf(_runner.position.z - obstacle.position.z)
	if side == 0.0:
		side = -1.0 if _rng.randf() < 0.5 else 1.0
	var room := _runner.max_z - _runner.position.z if side > 0.0 else _runner.position.z - _runner.min_z
	if room < 1.0:
		side = -side
	return side


func _interval_min(kind: int) -> float:
	return car_interval_min if kind == StreetObstacle.Kind.CAR else pedestrian_interval_min


func _interval_max(kind: int) -> float:
	return car_interval_max if kind == StreetObstacle.Kind.CAR else pedestrian_interval_max


func _on_pause_opened() -> void:
	_paused = true
	_actors.process_mode = Node.PROCESS_MODE_DISABLED


func _on_pause_closed() -> void:
	_paused = false
	_actors.process_mode = Node.PROCESS_MODE_INHERIT
