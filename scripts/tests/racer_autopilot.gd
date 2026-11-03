class_name RacerAutopilot
extends Node

#Chance that the racer stops to scroll its phone when it reaches an island, and for how long
const DISTRACTION_CHANCE := 0.3
const DISTRACTION_TIME := Vector2(0.8, 2.0)

#Test helper that plays a racer of level 1 in place of a keyboard: it walks the shortest route to the goal like a player would, jumps the spinners and
#sometimes stops to scroll its phone. The game never uses it; it only sets the actions of its Player, like the keyboard does for a person.

var graph: WeightedGraph
var locator: PlayerLocator
var rng: RandomNumberGenerator
#Seconds of the round, to know where the spinners point
var clock: Callable
var enabled := false
#The bridge that is about to fall: the racer waits at its gate instead of crossing it
var danger_edge: Array[StringName] = []

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


func _init() -> void:
	#It decides before its Player moves
	process_physics_priority = -2


func setup(player: Player, skill: float) -> void:
	_player = player
	_player.move_speed *= skill


#After a fall the racer starts again from the checkpoint
func reset_to(vertex: StringName) -> void:
	_vertex = vertex
	_committed = false
	_route.clear()
	_dirty = true
	_distracted_left = 0.0


func current_vertex() -> StringName:
	return _leg_vertex if _committed else _vertex


func _physics_process(delta: float) -> void:
	_time += delta
	if not enabled or _player == null:
		_set_move(Vector3.ZERO)
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
	var wanted := _walk()
	_set_move(wanted)
	_jump_spinners()


func _plan() -> void:
	if _time - _last_plan < 0.4:
		return
	_last_plan = _time
	_dirty = false
	_seen_version = graph.version
	_route.clear()
	var result := graph.shortest_path(current_vertex(), Level01Layout.GOAL)
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
	var gate := _gate_point(_vertex, next)
	if not _reached(gate):
		return _toward(gate)
	#At the gate the bridge must be open and not about to fall
	if not graph.is_edge_enabled(_vertex, next):
		_dirty = true
		return Vector3.ZERO
	if _is_danger(_vertex, next):
		return Vector3.ZERO
	_committed = true
	_leg_vertex = next
	_leg_point = _gate_point(next, _vertex)
	_route.pop_front()
	return _toward(_leg_point)


func _arrive() -> void:
	_vertex = _leg_vertex
	_committed = false
	if _vertex != Level01Layout.GOAL and rng.randf() < DISTRACTION_CHANCE:
		_distracted_left = rng.randf_range(DISTRACTION_TIME.x, DISTRACTION_TIME.y)


func _is_danger(a: StringName, b: StringName) -> bool:
	return danger_edge.size() == 2 and ((danger_edge[0] == a and danger_edge[1] == b) or (danger_edge[0] == b and danger_edge[1] == a))


#The bar of the island it stands on: it jumps when the bar is about to reach it
func _jump_spinners() -> void:
	if _committed or not Level01Layout.SPINNERS.has(_vertex) or not _player.is_on_floor() or not clock.is_valid():
		return
	var centre: Vector3 = Level01Layout.POSITIONS[_vertex]
	var wait := Level01Hazards.time_to_hit(centre, Level01Layout.SPINNERS[_vertex], clock.call(), _player.global_position, 0.5)
	if wait >= 0.12 and wait <= 0.35:
		_player.jump_requested = true


func _gate_point(from: StringName, to: StringName) -> Vector3:
	var from_pos: Vector3 = Level01Layout.POSITIONS[from]
	var direction: Vector3 = Level01Layout.POSITIONS[to] - from_pos
	direction.y = 0.0
	return from_pos + direction.normalized() * (Level01Layout.radius_of(from) - 1.0)


func _reached(point: Vector3) -> bool:
	return Vector2(point.x - _player.global_position.x, point.z - _player.global_position.z).length() <= 0.7


func _toward(point: Vector3) -> Vector3:
	var flat := Vector3(point.x - _player.global_position.x, 0.0, point.z - _player.global_position.z)
	return flat.normalized()


#The camera of the racer never turns, so the move input is the direction on the ground
func _set_move(direction: Vector3) -> void:
	_player.move_input = Vector2(direction.x, direction.z)
