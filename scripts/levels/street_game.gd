class_name StreetGame
extends RoundScene

#Street minigame: dodge the cars and pedestrians that push you toward the end line until time runs out

enum Phase { COUNTDOWN, RUNNING, ENDED }

const SCREEN_ID := &"street_game"
const RUNNER_SCENE: PackedScene = preload("res://scenes/characters/street_runner.tscn")
#Warm and saturated on a cool street: the hazards are the first thing the eye finds
const CAR_COLORS: Array[Color] = [
	Color("ff6f7d"), Color("ffb347"), Color("ff8fc0"), Color("ffd95a"), Color("ff9a6b"),
]
#The toy hatchback is twice as common as the minibus
const CAR_MODELS: Array[StringName] = [&"car_hatch", &"car_hatch", &"van"]
#Most cars have a roof of another colour
const ROOF_COLORS: Array[Color] = [Color("fff6e6"), Color("fdfbff"), Color("3a3358")]
const TWO_TONE_CHANCE := 0.65
#Meters from the end line where the edge of the screen starts to glow
const DANGER_RANGE := 6.0

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
#How far back the runner may walk
@export var back_limit := 6.0
#Where obstacles appear (off screen) and where they are removed
@export var spawn_x := -36.0
@export var despawn_x := 26.0
#Pedestrians are heavy models: they only exist near the play area, so they appear closer and leave sooner
@export var walker_spawn_x := -24.0
@export var walker_despawn_x := 16.0

@export_group("Obstacles")
@export var car_speed := 7.0
@export var car_length := 4.0
@export var car_width := 2.4
@export var pedestrian_speed := 2.4
#Speed multiplier of the whole flow at the start and at the end of the round
@export var start_speed_scale := 1.0
@export var end_speed_scale := 3.5
@export var car_interval_min := 1.6
@export var car_interval_max := 3.4
@export var pedestrian_interval_min := 0.6
@export var pedestrian_interval_max := 1.4
#A lane waits if every other lane spawned this recently, so the street is never a full wall
@export var wall_window := 0.6
#Cars that may run side by side; with 3 lanes, 2 always leaves one lane to escape through
@export var max_cars_side_by_side := 2
#Extra meters between cars of different lanes for them not to count as side by side
@export var car_side_gap := 2.5
#Throw-back speed of each kind of hit (about 6 m for a car or a pedestrian: the push fades at 16 m/s per second)
@export var car_knockback := 14.0
@export var pedestrian_knockback := 14.0
#Chance that a car is replaced by a tank as wide as two lanes
@export_range(0.0, 1.0) var tank_chance := 0.02
@export var tank_length := 6.0
@export var tank_knockback := 16.0
@export var cyclist_knockback := 14.0
@export var cone_knockback := 12.0
#Chances, when a car lane has room, that a rider or a row of cones comes instead of a car
@export_range(0.0, 1.0) var cyclist_chance := 0.14
@export_range(0.0, 1.0) var cone_chance := 0.12
@export var cyclist_length := 2.1
#Speed of the shove up or down the screen that takes the runner out of the obstacle's way
@export var side_shove := 8.0

@export_group("Belt")
#The whole street is a conveyor that drags the runner toward the end line, in m/s at the start
@export var belt_speed := 4.0
#How much of the flow's speed-up the belt follows (0 keeps it constant)
@export_range(0.0, 1.0) var belt_ramp := 0.5

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
#Hits the runner took in the round; the score counts them
var hits_taken := 0
#After a victory the whole street stops
var _frozen := false
#A tank was drawn but has not found room yet
var _tank_pending := false
var _next_speed_notice := 1
var _hud_timer := 0.0

@onready var _world: StreetWorld = $World
@onready var _obstacle_root: Node3D = $Obstacles
@onready var _hud: StreetHud = $Hud


func _ready() -> void:
	super()
	if ScreenFlow.tree.has(SCREEN_ID):
		ScreenFlow.mark_current(SCREEN_ID)
	_rng.randomize()
	var half_width := lane_count * lane_width / 2.0
	_world.build(half_width, sidewalk_width, lane_count, spawn_x - 10.0, despawn_x + 10.0, end_x)
	_build_lanes(half_width)
	_spawn_runner(half_width)

	_help.setup(HelpPages.street({"time_limit": time_limit, "jump_cooldown": _runner.jump_cooldown}))
	_hud.retry_requested.connect(_retry)
	_hud.menu_requested.connect(GameSession.abandon)
	_runner.hit_taken.connect(_on_runner_hit)
	_runner.landed.connect(_on_runner_landed)
	_runner.jump_cooldown_changed.connect(_hud.set_jump_cooldown)
	_hud.set_time(time_limit)
	var move_keys := " ".join([InputHints.key_label(&"move_forward"), InputHints.key_label(&"move_left"),
		InputHints.key_label(&"move_back"), InputHints.key_label(&"move_right")])
	_hud.show_mission("%d s contra la cinta" % int(time_limit), [move_keys, InputHints.key_label(&"jump")])

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_phase_timer = countdown_seconds
	_hud.tick_countdown(_phase_timer)


func _help_allowed() -> bool:
	return phase != Phase.ENDED


func _build_lanes(half_width: float) -> void:
	for index in lane_count:
		_lanes.append(Lane.new(StreetObstacle.Kind.CAR, -half_width + lane_width * (index + 0.5), 0.0))
	for side in [-1.0, 1.0]:
		_lanes.append(Lane.new(StreetObstacle.Kind.PEDESTRIAN, side * (half_width + sidewalk_width / 2.0),
			sidewalk_width / 4.0))
	for lane in _lanes:
		lane.timer = _rng.randf_range(0.0, _interval_max(lane.kind))


func _spawn_runner(half_width: float) -> void:
	var slot := participants[0]
	_runner = RUNNER_SCENE.instantiate() as StreetRunner
	_runner.player_id = slot.player_id
	var edge := half_width + sidewalk_width - _runner.radius
	_runner.min_z = -edge
	_runner.max_z = edge
	_runner.min_x = start_x - back_limit
	_runner.max_x = end_x + 10.0
	_actors.add_child(_runner)
	_runner.position = Vector3(start_x, 0.0, 0.0)
	_runner.set_character(slot.character)
	_runner.set_input_enabled(false)


func _physics_process(delta: float) -> void:
	if paused:
		return
	_clock += delta
	match phase:
		Phase.COUNTDOWN:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_begin_round()
			else:
				_hud.tick_countdown(_phase_timer)
		Phase.RUNNING:
			_update_running(delta)
	#The street keeps flowing during the countdown and after a defeat
	if not _frozen:
		_update_obstacles(delta)


func _begin_round() -> void:
	phase = Phase.RUNNING
	elapsed = 0.0
	_hud.show_go()
	_runner.set_input_enabled(true)


func _update_running(delta: float) -> void:
	elapsed += delta
	_run_belt()
	if elapsed >= time_limit:
		_hud.set_time(0.0)
		_finish(true, "En pie", "")
		return

	_check_hits()
	if _runner.position.x >= end_x:
		_finish(false, "Arrastrado", "")
		return

	#The edge of the screen glows when the end line is close
	_hud.set_danger((1.0 - (end_x - _runner.position.x) / DANGER_RANGE) * 0.9)

	#Tells the player every third of the round that the flow got faster
	if _next_speed_notice < 3 and elapsed >= time_limit * _next_speed_notice / 3.0:
		_next_speed_notice += 1
		_hud.warn("Más rápido")

	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		_hud.set_time(time_limit - elapsed)


#The belt drags the runner while it is on the ground and the ground markings slide with it
func _run_belt() -> void:
	var speed := belt_speed * (1.0 + (_speed_scale() - 1.0) * belt_ramp)
	_world.set_belt_speed(speed)
	_runner.external_velocity = Vector3(speed, 0.0, 0.0) if _runner.is_on_floor() else Vector3.ZERO


func _stop_belt() -> void:
	_world.set_belt_speed(0.0)
	_runner.external_velocity = Vector3.ZERO


func _speed_scale() -> float:
	return lerpf(start_speed_scale, end_speed_scale, clampf(elapsed / time_limit, 0.0, 1.0))


func _finish(victory: bool, title: String, message: String) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	_stop_belt()
	_runner.set_input_enabled(false)
	#A late Esc press must not open the pause menu over the final panel
	_pause_menu.set_process_unhandled_input(false)
	_hud.set_danger(0.0)
	if not victory:
		_hud.show_banner("FIN", "%d s" % floori(elapsed), Palette.GOLD)
		get_tree().create_timer(1.5).timeout.connect(_end_round.bind(victory, title, message))
		return

	#Victory: the street stops, a camera leaves the runner's view for the front of the runner and then the panel shows
	_frozen = true
	_hud.hide_play_ui()
	#Aimed above the head: the jump goes about 1.3 m up
	var focus := _runner.position + Vector3(0.0, 0.85 * _runner.model_scale, 0.0)
	var target := Transform3D(Basis(), _runner.position + win_camera_offset).looking_at(focus, Vector3.UP)
	_runner.celebrate(target.origin)
	_clear_view(target.origin)
	var view := _runner.view_camera()
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_transform = view.global_transform
	camera.fov = view.fov
	camera.make_current()
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_transform", target, win_zoom_time)
	tween.tween_property(camera, "fov", win_fov, win_zoom_time)
	tween.chain().tween_callback(_runner.jump)
	tween.tween_callback(_hud.show_banner.bind("%d S" % int(time_limit), "%d %s" % [hits_taken, "golpe" if hits_taken == 1 else "golpes"]))
	tween.chain().tween_interval(1.2)
	tween.chain().tween_callback(_end_round.bind(victory, title, message))


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


#Inside a session the results screen takes over; on its own the HUD shows the end panel
func _end_round(victory: bool, title: String, message: String) -> void:
	var lines: Array[Array] = [["Segundos", "%d s" % floori(elapsed)], ["Objetivo", "%d s" % int(time_limit)]]
	var result := RoundResult.make(SCREEN_ID, victory, title, message, lines)
	var score := _score(victory)
	if not finish_round(result.with_score(score, {_runner.player_id: score.points})):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_hud.show_end(title, message, victory)


#Points for the seconds held and, when the whole round was held, for the hits that were not taken
func _score(victory: bool) -> RoundScore:
	var sheet := GameSession.score_sheet
	var seconds := sheet.street_seconds if victory else minf(elapsed / time_limit, 0.999) * sheet.street_seconds
	var points := sheet.street_points(seconds, hits_taken)
	if not victory:
		return RoundScore.make(sheet, points, "%d de %d s" % [floori(elapsed), int(time_limit)])
	return RoundScore.make(sheet, points, "%d %s" % [hits_taken, "golpe" if hits_taken == 1 else "golpes"], [
		["Aguantar", "+%d" % sheet.street_survive], ["Sin golpes", "+%d" % (points - sheet.street_survive)]])


func _retry() -> void:
	if GameSession.is_playing_round():
		GameSession.restart_round()
	else:
		ScreenFlow.reload_current()


func _update_obstacles(delta: float) -> void:
	for lane in _lanes:
		lane.timer -= delta
		if lane.timer <= 0.0:
			_try_spawn(lane)

	var multiplier := _speed_scale()
	for index in range(_obstacles.size() - 1, -1, -1):
		var obstacle := _obstacles[index]
		obstacle.advance(delta, multiplier)
		var leaves_at := walker_despawn_x if obstacle.kind == StreetObstacle.Kind.PEDESTRIAN else despawn_x
		if obstacle.position.x - obstacle.half_extents.x > leaves_at:
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
	var roll := _rng.randf()
	if roll < cone_chance:
		_spawn_cones(lane)
	elif roll < cone_chance + cyclist_chance:
		_spawn_cyclist(lane)
	else:
		_spawn_car(lane)


func _spawn_car(lane: Lane) -> void:
	var model: StringName = CAR_MODELS[_rng.randi() % CAR_MODELS.size()]
	_mark_spawned(lane, car_length)
	var car := StreetObstacle.new()
	var body := CAR_COLORS[_rng.randi() % CAR_COLORS.size()]
	var roof := ROOF_COLORS[_rng.randi() % ROOF_COLORS.size()] if _rng.randf() < TWO_TONE_CHANCE else body
	car.build_car(model, body, car_length, _rng, roof)
	car.base_speed = car_speed
	car.knockback = car_knockback
	_place(car, lane.z, 0.0)


func _spawn_cyclist(lane: Lane) -> void:
	_mark_spawned(lane, cyclist_length)
	var rider := StreetObstacle.new()
	rider.build_cyclist(_rng)
	rider.base_speed = car_speed
	rider.knockback = cyclist_knockback
	_place(rider, lane.z, 0.0)


#Three cones across the lane: they ride the belt with the traffic and a jump clears them
func _spawn_cones(lane: Lane) -> void:
	_mark_spawned(lane, 1.0)
	for offset in [-0.9, 0.0, 0.9]:
		var cone := StreetObstacle.new()
		cone.build_cone()
		cone.base_speed = car_speed
		cone.knockback = cone_knockback
		_place(cone, lane.z + offset, 0.0)


func _spawn_pedestrian(lane: Lane) -> void:
	_mark_spawned(lane, 0.0)
	var pedestrian := StreetObstacle.new()
	pedestrian.build_pedestrian(_rng)
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
		_hud.warn("Tanque")
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
	var from_x := walker_spawn_x if obstacle.kind == StreetObstacle.Kind.PEDESTRIAN else spawn_x
	obstacle.position = Vector3(from_x, height, z)
	_obstacle_root.add_child(obstacle)
	_obstacles.append(obstacle)


#The runner stays invulnerable while it touches any obstacle, so one contact is one hit
func _check_hits() -> void:
	var hit_by: StreetObstacle = null
	for obstacle in _obstacles:
		if obstacle.contact(_runner.position, _runner.hurt_radius, _runner.hurt_height):
			hit_by = obstacle
			break
	_runner.touching = hit_by != null
	if hit_by == null or not _runner.can_be_hit():
		return
	var hit := Player.Hit.new()
	hit.push = Vector3(hit_by.knockback, 0.0, _shove_side(hit_by) * side_shove)
	hit.stun = hit_by.stun
	hit.flips = hit_by.flips
	hit.strength = hit_by.strength
	_runner.take_hit(hit)
	hits_taken += 1
	hit_by.react()
	if hit_by.kind in [StreetObstacle.Kind.CAR, StreetObstacle.Kind.TANK] and _rng.randf() < 0.5:
		SynthSound.play(self, SynthSound.honk(), -8.0, _rng.randf_range(0.9, 1.1))


#The blow is felt: dust and stars where it landed, the edge of the screen flashes and the game stops for a breath
func _on_runner_hit(hit: Player.Hit) -> void:
	ImpactFx.blow(self, _runner, hit, _rng, true)
	_hud.flash(Palette.CORAL, 0.3 + 0.3 * hit.strength, 0.45)


func _on_runner_landed(_at: Vector3, hard: bool) -> void:
	ImpactFx.landing(self, _runner, hard, _rng)


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
