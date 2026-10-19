class_name ChaserBot
extends CharacterBody3D

#Shared AI of every bot. It plans on the graph (Dijkstra) and walks the planned route with
#physics. The look lives under VisualRoot and can be swapped without touching this script.
#
#Walking model: a route is a list of vertices. To cross from u to v the bot first walks to a
#"gate" just inside platform u, then (committed) along the bridge to a gate just inside v.
#Both gates are inside convex platforms, so straight lines never leave the walkable ground.
#Once committed, a bot always finishes the crossing, even if the bridge gets blocked.

signal push_announced(bot: ChaserBot)
signal push_landed(bot: ChaserBot, direction: Vector3)
signal route_changed(bot: ChaserBot)

enum State { INACTIVE, CHASE, SEARCH }

@export_group("Movement")
@export var move_speed := 4.3
@export var waypoint_tolerance := 0.6
@export var gate_inset := 1.0
@export var stop_distance := 1.1
@export var turn_speed := 10.0

@export_group("Planning")
#Minimum seconds between two Dijkstra calls of the same bot
@export var recalc_interval := 0.4
@export var perception_interval := 0.25

@export_group("Perception")
#Seconds without seeing the player before the bot gives up and patrols
@export var lose_time := 5.0
@export var patrol_idle_time := 1.5

@export_group("Push")
@export var push_enabled := true
@export var push_trigger_range := 2.3
@export var push_hit_range := 2.9
@export var push_windup := 0.7
@export var push_cooldown := 2.5

var appearance: BotAppearance
var state := State.INACTIVE
var current_vertex: StringName = &""
var target_vertex: StringName = &""
#Remaining vertices after the one the bot is at (or is crossing toward)
var route: Array[StringName] = []
var route_cost := INF
var route_found := false
var route_message := ""
#Set by the level for scripted demos: ignores perception and keeps the given target
var manual_target := false
#Keeps the bot standing still (used to show a route before the bot starts to walk it)
var hold_movement := false

var _ctx: ChaseContext
var _clock := 0.0
var _last_recalc := -100.0
var _last_seen := 0.0
var _seen_version := -1
var _dirty := false
var _perception_timer := 0.0
var _committed := false
var _leg_vertex: StringName = &""
var _leg_point := Vector3.ZERO
var _patrol_timer := 0.0
var _windup_left := 0.0
var _push_cooldown_left := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _visual: Node3D

@onready var _visual_root: Node3D = $VisualRoot


func setup(context: ChaseContext, bot_appearance: BotAppearance, start_vertex: StringName) -> void:
	_ctx = context
	current_vertex = start_vertex
	global_position = _ctx.positions[start_vertex]
	set_appearance(bot_appearance)


#Swaps the look only: nothing else in the bot depends on it
func set_appearance(bot_appearance: BotAppearance) -> void:
	appearance = bot_appearance
	if _visual:
		_visual.queue_free()
		_visual = null
	if appearance.model_scene != null:
		_visual = appearance.model_scene.instantiate() as Node3D
	else:
		var provisional := BotVisual.new()
		provisional.build(appearance)
		_visual = provisional
	_visual_root.add_child(_visual)


#Starts the hunt knowing where the player is, whatever the detection radius
func activate(known_vertex: StringName) -> void:
	state = State.CHASE
	_last_seen = _clock
	set_target(known_vertex)


func deactivate() -> void:
	state = State.INACTIVE
	route.clear()
	_committed = false
	_windup_left = 0.0


func set_target(vertex: StringName) -> void:
	if vertex == target_vertex and route_found:
		return
	target_vertex = vertex
	_dirty = true


#Where the bot is heading right now, for the debug view
func planned_vertices() -> Array[StringName]:
	var result: Array[StringName] = []
	result.append(_leg_vertex if _committed else current_vertex)
	result.append_array(route)
	return result


func is_crossing() -> bool:
	return _committed


func debug_info() -> Dictionary:
	return {
		"name": appearance.display_name if appearance else "Bot",
		"color": appearance.debug_color if appearance else Color.WHITE,
		"from": _leg_vertex if _committed else current_vertex,
		"target": target_vertex,
		"route": planned_vertices(),
		"cost": route_cost,
		"found": route_found,
		"message": route_message,
		"state": State.keys()[state],
	}


func _physics_process(delta: float) -> void:
	_clock += delta
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	var wanted := Vector3.ZERO
	if state != State.INACTIVE:
		_perception_timer += delta
		if _perception_timer >= perception_interval:
			_perception_timer = 0.0
			_perceive()
		if _dirty or _ctx.graph.version != _seen_version:
			_try_recalculate()
		_update_push(delta)
		if _windup_left <= 0.0 and not hold_movement:
			wanted = _walk(delta)

	velocity.x = wanted.x
	velocity.z = wanted.z
	move_and_slide()
	_face(wanted if wanted.length() > 0.1 else _to_player_flat(), delta)
	if global_position.y < -15.0:
		_recover_from_fall()


#---- perception ------------------------------------------------------------------------

func _perceive() -> void:
	if manual_target:
		return
	var distance := _flat(_ctx.player.global_position - global_position).length()
	if distance <= _ctx.detection_radius:
		_last_seen = _clock
		if state == State.SEARCH:
			state = State.CHASE
		_choose_target_from_player()
	elif state == State.CHASE and _clock - _last_seen > lose_time:
		state = State.SEARCH
		_patrol_timer = 0.0


#The player's platform; if the player is on a bridge, the end that makes the bot cross it
#when it is open, or the nearest end when it is blocked (the bot waits at the entrance)
func _choose_target_from_player() -> void:
	var candidates := _ctx.locator.chase_candidates()
	if candidates.size() == 1:
		set_target(candidates[0])
		return
	var bridge_open := _ctx.graph.is_edge_enabled(candidates[0], candidates[1])
	var anchor := _leg_vertex if _committed else current_vertex
	var best: StringName = &""
	var best_cost := INF if not bridge_open else -1.0
	for candidate in candidates:
		var result := _ctx.graph.shortest_path(anchor, candidate, _ctx.forbidden)
		if not result.found:
			continue
		if bridge_open and result.cost > best_cost or not bridge_open and result.cost < best_cost:
			best_cost = result.cost
			best = candidate
	if best != &"":
		set_target(best)


#---- planning --------------------------------------------------------------------------

func _try_recalculate() -> void:
	if _clock - _last_recalc < recalc_interval:
		return
	_last_recalc = _clock
	_dirty = false
	_seen_version = _ctx.graph.version
	if target_vertex == &"":
		return
	var anchor := _leg_vertex if _committed else current_vertex
	var result := _ctx.graph.shortest_path(anchor, target_vertex, _ctx.forbidden)
	route_found = result.found
	route_cost = result.cost
	route_message = result.reason
	route.clear()
	if result.found:
		for index in range(1, result.path.size()):
			route.append(result.path[index])
	route_changed.emit(self)


#---- walking ---------------------------------------------------------------------------

func _walk(delta: float) -> Vector3:
	if _committed:
		if _reached(_leg_point):
			current_vertex = _leg_vertex
			_committed = false
		else:
			return _toward(_leg_point)

	if not route.is_empty():
		var next: StringName = route[0]
		var gate := _gate_point(current_vertex, next)
		if not _reached(gate):
			return _toward(gate)
		#At the gate: the bridge must still be open to start crossing it
		if not _ctx.graph.is_edge_enabled(current_vertex, next):
			_dirty = true
			return Vector3.ZERO
		_committed = true
		_leg_vertex = next
		_leg_point = _gate_point(next, current_vertex)
		route.pop_front()
		return _toward(_leg_point)

	return _idle_walk(delta)


#The bot is at its target: chase the player on the same platform, patrol, or wait in the middle
func _idle_walk(delta: float) -> Vector3:
	var on_same_platform := not _ctx.locator.on_bridge and _ctx.locator.vertex == current_vertex
	if state == State.CHASE and on_same_platform:
		var to_player := _flat(_ctx.player.global_position - global_position)
		if to_player.length() > stop_distance:
			return to_player.normalized() * move_speed
		return Vector3.ZERO
	if state == State.SEARCH and not manual_target:
		_patrol_timer += delta
		if _patrol_timer >= patrol_idle_time:
			_patrol_timer = 0.0
			_pick_patrol_target()
	var centre: Vector3 = _ctx.positions[current_vertex]
	if _flat(centre - global_position).length() > waypoint_tolerance:
		return _toward(centre)
	return Vector3.ZERO


func _pick_patrol_target() -> void:
	var options: Array[StringName] = []
	for neighbor in _ctx.graph.neighbors(current_vertex):
		if not _ctx.forbidden.has(neighbor):
			options.append(neighbor)
	if options.is_empty():
		return
	set_target(options[randi() % options.size()])


func _gate_point(from: StringName, to: StringName) -> Vector3:
	var from_pos: Vector3 = _ctx.positions[from]
	var to_pos: Vector3 = _ctx.positions[to]
	var direction := _flat(to_pos - from_pos).normalized()
	var radius: float = _ctx.radii.get(from, 5.5)
	#A point inside "from" on the side that faces "to"
	return from_pos + direction * (radius - gate_inset)


func _reached(point: Vector3) -> bool:
	return _flat(point - global_position).length() <= waypoint_tolerance


func _toward(point: Vector3) -> Vector3:
	return _flat(point - global_position).normalized() * move_speed


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func _to_player_flat() -> Vector3:
	if _ctx == null or _ctx.player == null:
		return Vector3.ZERO
	return _flat(_ctx.player.global_position - global_position)


func _face(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.1:
		return
	var yaw := atan2(direction.x, direction.z)
	_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, yaw, turn_speed * delta)


#Failsafe only: puts a fallen bot back on the platform it last used
func _recover_from_fall() -> void:
	_committed = false
	global_position = _ctx.positions[current_vertex]
	velocity = Vector3.ZERO
	_dirty = true


#---- push ------------------------------------------------------------------------------

func _update_push(delta: float) -> void:
	_push_cooldown_left = maxf(_push_cooldown_left - delta, 0.0)
	if _windup_left > 0.0:
		_windup_left -= delta
		if _windup_left <= 0.0:
			_resolve_push()
		return
	if not push_enabled or _push_cooldown_left > 0.0 or _ctx.player_protected:
		return
	var offset := _ctx.player.global_position - global_position
	if _flat(offset).length() <= push_trigger_range and absf(offset.y) < 1.5:
		_windup_left = push_windup
		if _visual and _visual.has_method("set_alert"):
			_visual.call("set_alert", true)
		push_announced.emit(self)


func _resolve_push() -> void:
	if _visual and _visual.has_method("set_alert"):
		_visual.call("set_alert", false)
	_push_cooldown_left = push_cooldown
	if _ctx.player_protected:
		return
	var offset := _flat(_ctx.player.global_position - global_position)
	if offset.length() <= push_hit_range:
		push_landed.emit(self, offset.normalized())
