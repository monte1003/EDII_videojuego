class_name RacerAutopilot
extends Node

#Chance and length of a phone stop at an island
const DISTRACTION_CHANCE := 0.3
const DISTRACTION_TIME := Vector2(0.8, 2.0)
#Clumsy racer: more and longer stops, and misses this share of jumps
const CLUMSY_DISTRACTION_CHANCE := 0.6
const CLUMSY_DISTRACTION_TIME := Vector2(1.5, 3.5)
const CLUMSY_MISS := 0.35

#Test helper that plays a level 1 racer: shortest route, timed jumps and dodges

#Look-ahead time and turns tried before stepping into what cannot be jumped
const LOOK_AHEAD := 0.7
const DODGES: Array[float] = [0.0, 0.9, -0.9, 1.57, -1.57]

var graph: WeightedGraph
var locator: PlayerLocator
var rng: RandomNumberGenerator
#Seconds of the round, to know where the spinners point
var clock: Callable
var enabled := false
#Side offset on a bridge by id so racers do not push each other
var lane_width := 0.0
#The bridge that is about to fall: the racer waits at its gate instead of crossing it
var danger_edge: Array[StringName] = []
#Whether it may stop to scroll its phone on an island (off to time the course)
var distractible := true
#Forced island order to time one way; empty takes the cheapest route
var forced_route: Array[StringName] = []
#Plays like a person that is not good at the game
var clumsy := false

var _player: Player
var _vertex: StringName = Level01Layout.START
var _route: Array[StringName] = []
var _committed := false
var _leg_vertex: StringName = &""
var _leg_point := Vector3.ZERO
var _dirty := true
var _seen_version := -1
var _last_plan := -100.0
var _time := 0.0
var _distracted_left := 0.0
#Rolled at each island to decide missed jumps
var _miss_roll := 1.0
#Deck pad to walk to after a fall
var _deck: Dictionary = {}
#Plans as if fallen fragile bridges come back
var _open := Level01Layout.build_graph()


func _init() -> void:
	#It decides before its Player moves
	process_physics_priority = -2


func setup(player: Player, skill: float) -> void:
	_player = player
	_player.move_speed *= skill


#After a fall the racer starts again from the checkpoint
func reset_to(vertex: StringName) -> void:
	_vertex = vertex
	_deck = {}
	_committed = false
	_route.clear()
	_dirty = true
	_distracted_left = 0.0


func current_vertex() -> StringName:
	return _leg_vertex if _committed else _vertex


func _physics_process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(_player) or not is_instance_valid(locator):
		return
	if not enabled:
		_set_move(Vector3.ZERO)
		return
	_check_fall()
	if not _deck.is_empty():
		_walk_deck()
		return
	if _distracted_left > 0.0:
		_distracted_left -= delta
		_set_move(Vector3.ZERO)
		return
	if not _committed and not locator.on_bridge and locator.vertex != _vertex and locator.vertex != &"":
		_vertex = locator.vertex
		_dirty = true
	if _dirty or graph.version != _seen_version:
		_plan()
	var wanted := _against_wind(_dodge(_walk()))
	_set_move(wanted)
	_jump_spinners()
	_jump_blocks()
	_jump_balls()
	_jump_comments()
	_jump_rollers()


#Dropped onto a deck: go to the bubble pad
func _check_fall() -> void:
	if not _deck.is_empty() or _player.carried or not _player.is_on_floor():
		return
	var at := _player.global_position
	if at.y >= (Level01Layout.POSITIONS[current_vertex()] as Vector3).y - 2.5:
		return
	_deck = Level01Layout.deck_catching(Level01Layout.all_decks(), at)
	if not _deck.is_empty():
		_committed = false


#Walks to the pad, then continues after the bubble
func _walk_deck() -> void:
	var pad: Vector3 = _deck["pad"]
	if _player.carried:
		_set_move(Vector3.ZERO)
		return
	if _player.global_position.y > pad.y + 3.0:
		_vertex = _deck["to"]
		_deck = {}
		_route.clear()
		_dirty = true
		return
	_set_move(_toward(pad) if not _reached(pad) else Vector3.ZERO)


func _plan() -> void:
	if _time - _last_plan < 0.4:
		return
	_last_plan = _time
	_dirty = false
	_seen_version = graph.version
	_route.clear()
	var at := forced_route.find(current_vertex())
	if at >= 0:
		for index in range(at + 1, forced_route.size()):
			_route.append(forced_route[index])
		return
	var result := _open.shortest_path(current_vertex(), Level01Layout.GOAL)
	if result.found:
		for index in range(1, result.path.size()):
			_route.append(result.path[index])


func _walk() -> Vector3:
	if _committed:
		if _reached(_leg_point):
			_arrive()
			return Vector3.ZERO
		return _toward(_leg_point)
	if _route.is_empty():
		var centre: Vector3 = Level01Layout.POSITIONS[_vertex]
		return _toward(centre) if not _reached(centre) else Vector3.ZERO
	var next: StringName = _route[0]
	var gate := _gate_point(_vertex, next) + _lane(_vertex, next)
	if not _reached(gate):
		return _toward(gate)
	#At the gate the bridge must be open; a fallen fragile one is waited for
	if not graph.is_edge_enabled(_vertex, next):
		return Vector3.ZERO
	if _is_danger(_vertex, next):
		return Vector3.ZERO
	_committed = true
	_leg_vertex = next
	_leg_point = _gate_point(next, _vertex) + _lane(_vertex, next)
	_route.pop_front()
	return _toward(_leg_point)


func _arrive() -> void:
	_vertex = _leg_vertex
	_committed = false
	_miss_roll = rng.randf() if clumsy else 1.0
	var chance := CLUMSY_DISTRACTION_CHANCE if clumsy else DISTRACTION_CHANCE
	var time := CLUMSY_DISTRACTION_TIME if clumsy else DISTRACTION_TIME
	#A good racer never stops on a plate that drops or where things roll; a clumsy one may
	var busy := Level01Layout.TILE_PLATES.has(_vertex) or Level01Layout.run_at(Level01Layout.POSITIONS[_vertex]) >= 0
	if distractible and _vertex != Level01Layout.GOAL and (clumsy or not busy) and rng.randf() < chance:
		_distracted_left = rng.randf_range(time.x, time.y)


#Whether the racer makes the jump it decided on: a clumsy one misses some
func _jumps() -> bool:
	return _miss_roll >= CLUMSY_MISS


func _is_danger(a: StringName, b: StringName) -> bool:
	return danger_edge.size() == 2 and ((danger_edge[0] == a and danger_edge[1] == b) or (danger_edge[0] == b and danger_edge[1] == a))


#The bar of the island it stands on: it jumps when the bar is about to reach it
func _jump_spinners() -> void:
	if not _jumps() or _committed or not Level01Layout.SPINNERS.has(_vertex) or not _player.is_on_floor() or not clock.is_valid():
		return
	var centre: Vector3 = Level01Layout.POSITIONS[_vertex]
	var wait := Level01Hazards.time_to_hit(centre, Level01Layout.SPINNERS[_vertex], clock.call(), _player.global_position, 0.5)
	if wait >= 0.12 and wait <= 0.35:
		_player.jump_requested = true


#Jumps the sweeping block of its bridge in time
func _jump_blocks() -> void:
	if not _jumps() or not _committed or not _player.is_on_floor() or not clock.is_valid():
		return
	var pusher := Level01Layout.pusher_of(_vertex, _leg_vertex)
	if pusher.is_empty():
		return
	var wait := Level01Hazards.block_time_to_hit(pusher, clock.call(), _player.global_position, _toward(_leg_point), _player.move_speed, 0.6)
	if wait >= 0.15 and wait <= 0.38:
		_player.jump_requested = true


#Jumps the comment push in time
func _jump_comments() -> void:
	if not _jumps() or not _committed or not _player.is_on_floor() or not clock.is_valid():
		return
	var comment := Level01Layout.comment_of(_vertex, _leg_vertex)
	if comment.is_empty():
		return
	var wait := Level01Hazards.comment_wait(comment, clock.call())
	var bubble := Level01Hazards.comment_center(comment, clock.call())
	var near := Vector2(_player.global_position.x - bubble.x, _player.global_position.z - bubble.z).length() < 3.2
	if near and wait >= 0.08 and wait <= 0.3:
		_player.jump_requested = true


#Jumps a rolling ball in time
func _jump_balls() -> void:
	if not _jumps() or _committed or not _player.is_on_floor() or not clock.is_valid():
		return
	for ball: Dictionary in Level01Layout.BALLS:
		if ball["island"] != _vertex:
			continue
		var wait := Level01Hazards.ball_time_to_hit(ball, clock.call(), _player.global_position, 0.6)
		if wait >= 0.2 and wait <= 0.36:
			_player.jump_requested = true


#Before what cannot be jumped: turn aside, wait if safe, or step back
func _dodge(wanted: Vector3) -> Vector3:
	if not clock.is_valid() or wanted == Vector3.ZERO or not _player.is_on_floor():
		return wanted
	var now: float = clock.call()
	var at := _player.global_position
	for turn in DODGES:
		var way := wanted.rotated(Vector3.UP, turn)
		if _clear(at, way, now):
			return way
	if _clear(at, Vector3.ZERO, now):
		return Vector3.ZERO
	return -wanted


func _clear(at: Vector3, way: Vector3, now: float) -> bool:
	if not _inside(at + way * _player.move_speed * LOOK_AHEAD):
		return false
	var ahead := 0.0
	while ahead <= LOOK_AHEAD:
		if Level01Traps.blocking_hit(at + way * _player.move_speed * ahead, now + ahead) != Level01Traps.Kind.NONE:
			return false
		ahead += 0.05
	return true


#Well inside the way, so a side step never nears an edge
func _inside(point: Vector3) -> bool:
	var index := Level01Layout.run_at(point)
	if index >= 0:
		var line := Level01Layout.run_line(Level01Layout.RUNS[index])
		return absf((point - (line["from"] as Vector3)).dot(line["across"] as Vector3)) <= Level01Layout.PLATE / 2.0 - 1.0
	if _committed:
		var frame := Level01Traps.bridge_frame([_vertex, _leg_vertex])
		return absf((point - (frame["from"] as Vector3)).dot(frame["across"] as Vector3)) <= float(frame["width"]) / 2.0 - 1.0
	return true


#On a bridge with a fan that blows it leans into the wind
func _against_wind(wanted: Vector3) -> Vector3:
	if not clock.is_valid() or not locator.on_bridge:
		return wanted
	var fan := Level01Layout.fan_of(locator.bridge_a, locator.bridge_b)
	if fan.is_empty():
		return wanted
	var wind := Level01Traps.fan_drift(fan, clock.call(), _player.global_position)
	if wind == Vector3.ZERO:
		return wanted
	return (wanted - wind.normalized() * 0.85).normalized()


#The scroll wheels of the run it stands on: it jumps when one is about to reach it
func _jump_rollers() -> void:
	if not _jumps() or not _player.is_on_floor() or not clock.is_valid():
		return
	var index := Level01Layout.run_at(_player.global_position, 1.0)
	if index < 0 or Level01Layout.RUNS[index]["kind"] != Level01Layout.ROLLER:
		return
	var now: float = clock.call()
	var way := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	var ahead := 0.0
	while ahead <= 0.4:
		if Level01Traps.run_hits(Level01Layout.RUNS[index], index, now + ahead, _player.global_position + way * ahead):
			if ahead >= 0.1:
				_player.jump_requested = true
			return
		ahead += 0.05


func _gate_point(from: StringName, to: StringName) -> Vector3:
	var from_pos: Vector3 = Level01Layout.POSITIONS[from]
	var direction: Vector3 = Level01Layout.POSITIONS[to] - from_pos
	direction.y = 0.0
	return from_pos + direction.normalized() * (Level01Layout.radius_of(from) - 1.0)


#The side of the bridge from a to b at which this racer walks, the same all along it
func _lane(a: StringName, b: StringName) -> Vector3:
	var direction: Vector3 = Level01Layout.POSITIONS[b] - Level01Layout.POSITIONS[a]
	direction.y = 0.0
	direction = direction.normalized()
	return Vector3(-direction.z, 0.0, direction.x) * lane_width * (1.0 if _player.player_id % 2 == 0 else -1.0)


func _reached(point: Vector3) -> bool:
	return Vector2(point.x - _player.global_position.x, point.z - _player.global_position.z).length() <= 0.7


func _toward(point: Vector3) -> Vector3:
	var flat := Vector3(point.x - _player.global_position.x, 0.0, point.z - _player.global_position.z)
	return flat.normalized()


#Move input in the racer's camera space
func _set_move(direction: Vector3) -> void:
	var local := (_player.get_node("CameraRig") as PlayerCamera).get_yaw_basis().inverse() * direction
	_player.move_input = Vector2(local.x, local.z)
