class_name ChaserBot
extends CharacterBody3D

#Shared bot AI: the role picks a target, Dijkstra plans the route, the bot walks it

signal push_announced(bot: ChaserBot)
signal push_landed(bot: ChaserBot, direction: Vector3, player_id: int)
signal route_changed(bot: ChaserBot)

enum State { INACTIVE, CHASE, SEARCH }

#Fade of a shove speed, in m/s per second
const KNOCK_DECAY := 14.0

@export_group("Movement")
@export var move_speed := 4.3
@export var waypoint_tolerance := 0.6
@export var gate_inset := 1.0
@export var stop_distance := 1.5
@export var turn_speed := 10.0
#Distance bots keep from each other on a platform
@export var separation_radius := 2.8
@export_range(0.0, 1.5) var separation_weight := 1.2
#Wait at a gate while another bot on the same bridge is this close
@export var bridge_gap := 4.5
#Distance from the platform rim the bot keeps
@export var rim_margin := 0.9

@export_group("Planning")
#Minimum seconds between two Dijkstra calls
@export var recalc_interval := 0.4
@export var perception_interval := 0.25

@export_group("Perception")
#Seconds without seeing the player before patrolling
@export var lose_time := 5.0
@export var patrol_idle_time := 1.5

@export_group("Push")
@export var push_enabled := true
@export var push_trigger_range := 2.8
@export var push_hit_range := 3.2
#Shoves only reach this height difference
@export var push_reach_height := 1.5
@export var push_windup := 0.55
@export var push_cooldown := 1.8

var appearance: BotAppearance
var role: BotRole = ChaseRole.new()
var state := State.INACTIVE
var current_vertex: StringName = &""
var target_vertex: StringName = &""
#Vertices left after the current one
var route: Array[StringName] = []
var route_cost := INF
var route_found := false
var route_message := ""
#Drift of a conveyor belt, set by the level every frame
var external_velocity := Vector3.ZERO
#For scripted demos: ignore perception and keep the target
var manual_target := false
#Keeps the bot still, to show a route before walking it
var hold_movement := false
#Shove from a player: throw speed that fades and daze seconds
var knock := Vector3.ZERO
var dazed_left := 0.0

var _ctx: ChaseContext
var _focus: ChaseTarget
var _push_target: ChaseTarget
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
#Node3D so a BotLook member does not leave scripts alive at exit
var _visual: Node3D

@onready var _visual_root: Node3D = $VisualRoot


func setup(context: ChaseContext, bot_appearance: BotAppearance, start_vertex: StringName) -> void:
	_ctx = context
	_ctx.bots.append(self)
	current_vertex = start_vertex
	global_position = _ctx.positions[start_vertex]
	set_appearance(bot_appearance)


func _exit_tree() -> void:
	if _ctx != null:
		_ctx.bots.erase(self)


func set_appearance(bot_appearance: BotAppearance) -> void:
	appearance = bot_appearance
	role = BotRoles.make(appearance.role)
	if _visual:
		_visual.queue_free()
		_visual = null
	if appearance.model_scene != null:
		_visual = appearance.model_scene.instantiate() as Node3D
	if _visual == null:
		var provisional := BotVisual.new()
		provisional.build(appearance)
		_visual = provisional
	_visual_root.add_child(_visual)


#Starts the hunt knowing where the player is; the role decides where to go
func activate(known_vertex: StringName) -> void:
	state = State.CHASE
	_last_seen = _clock
	var watched := _watched()
	var wanted := &""
	if not manual_target and watched != null:
		wanted = role.pick_target(self, _ctx, watched)
	set_target(wanted if wanted != &"" else known_vertex)


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


#Shoved by a player: thrown back, drops its push and stays dazed
func take_shove(push: Vector3, seconds: float) -> void:
	knock = Vector3(push.x, 0.0, push.z)
	dazed_left = seconds
	_windup_left = 0.0
	_push_target = null
	_push_cooldown_left = maxf(_push_cooldown_left, seconds)
	if _visual != null:
		_look().set_alert(false)


func is_dazed() -> bool:
	return dazed_left > 0.0


func role_kind() -> int:
	return appearance.role if appearance != null else BotRole.Kind.CHASE


func anchor_vertex() -> StringName:
	return _leg_vertex if _committed else current_vertex


func clock() -> float:
	return _clock


#Destination for the debug view
func planned_vertices() -> Array[StringName]:
	var result: Array[StringName] = []
	result.append(anchor_vertex())
	result.append_array(route)
	return result


func is_crossing() -> bool:
	return _committed


#Ends of the bridge being crossed; empty on a platform
func crossing_pair() -> Array[StringName]:
	var pair: Array[StringName] = []
	if _committed:
		pair.append(current_vertex)
		pair.append(_leg_vertex)
	return pair


func debug_info() -> Dictionary:
	return {
		"name": appearance.display_name if appearance else "Bot",
		"color": appearance.debug_color if appearance else Color.WHITE,
		"from": anchor_vertex(),
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
	dazed_left = maxf(dazed_left - delta, 0.0)
	knock = knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)
	if state != State.INACTIVE and dazed_left <= 0.0:
		_perception_timer += delta
		if _perception_timer >= perception_interval:
			_perception_timer = 0.0
			_perceive()
		if _dirty or _ctx.graph.version != _seen_version:
			_try_recalculate()
		_update_push(delta)
		if _windup_left <= 0.0 and not hold_movement:
			wanted = _walk(delta)

	wanted = _stay_on_platform(_with_separation(wanted))
	velocity.x = wanted.x + external_velocity.x + knock.x
	velocity.z = wanted.z + external_velocity.z + knock.z
	move_and_slide()
	if _visual != null:
		_look().set_moving(wanted.length() > 0.1)
	_face(wanted if wanted.length() > 0.1 else _to_player_flat(), delta)
	if global_position.y < -15.0:
		_recover_from_fall()


func _perceive() -> void:
	if manual_target:
		return
	var seen := _nearest_noticed()
	if seen != null:
		_focus = seen
		_last_seen = _clock
		if state == State.SEARCH:
			state = State.CHASE
		var wanted := role.pick_target(self, _ctx, seen)
		if wanted != &"":
			set_target(wanted)
	elif state == State.CHASE and _clock - _last_seen > lose_time:
		state = State.SEARCH
		_patrol_timer = 0.0


#Closest noticed player, or any when the role needs no sight
func _nearest_noticed() -> ChaseTarget:
	var best: ChaseTarget = null
	var best_distance := INF
	for candidate in _ctx.targets:
		var distance := _flat(candidate.node.global_position - global_position).length()
		if role.needs_sight() and distance > candidate.detection_radius:
			continue
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


#Player this bot watches; the closest if it noticed nobody yet
func _watched() -> ChaseTarget:
	#A racer that left the course is freed with its node
	if _focus != null and not (is_instance_valid(_focus.node) and is_instance_valid(_focus.locator)):
		_focus = null
	if _focus != null:
		return _focus
	var best: ChaseTarget = null
	var best_distance := INF
	for candidate in _ctx.targets:
		var distance := _flat(candidate.node.global_position - global_position).length()
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _try_recalculate() -> void:
	if _clock - _last_recalc < recalc_interval:
		return
	_last_recalc = _clock
	_dirty = false
	_seen_version = _ctx.graph.version
	if target_vertex == &"":
		return
	var result := _ctx.graph.shortest_path(anchor_vertex(), target_vertex, _ctx.forbidden, _ctx.traffic_for(self))
	route_found = result.found
	route_cost = result.cost
	route_message = result.reason
	route.clear()
	if result.found:
		for index in range(1, result.path.size()):
			route.append(result.path[index])
	route_changed.emit(self)


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
		#The bridge must still be open to start crossing
		if not _ctx.graph.is_edge_enabled(current_vertex, next):
			_dirty = true
			return Vector3.ZERO
		#Another bot near the gate on that bridge: wait, it fits only one
		if _bridge_taken(current_vertex, next):
			return Vector3.ZERO
		_committed = true
		_leg_vertex = next
		_leg_point = _gate_point(next, current_vertex)
		route.pop_front()
		return _toward(_leg_point)

	return _idle_walk(delta)


#At its target: chase on the same platform, patrol or wait
func _idle_walk(delta: float) -> Vector3:
	var watched := _watched()
	var on_same_platform := watched != null and not watched.locator.on_bridge and watched.locator.vertex == current_vertex
	if state == State.CHASE and on_same_platform:
		var to_player := _flat(watched.node.global_position - global_position)
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
	var crowded := _ctx.traffic_for(self)
	for neighbor in _ctx.graph.neighbors(current_vertex):
		if not _ctx.forbidden.has(neighbor):
			options.append(neighbor)
	var free: Array[StringName] = options.filter(func(vertex: StringName) -> bool: return not crowded.has(vertex))
	if not free.is_empty():
		options = free
	if options.is_empty():
		return
	set_target(options[randi() % options.size()])


func _bridge_taken(from: StringName, to: StringName) -> bool:
	for other in _ctx.bots:
		if other == self or not other._committed:
			continue
		var same_bridge := (other.current_vertex == from and other._leg_vertex == to) \
			or (other.current_vertex == to and other._leg_vertex == from)
		if same_bridge and _flat(other.global_position - global_position).length() < bridge_gap:
			return true
	return false


func _gate_point(from: StringName, to: StringName) -> Vector3:
	var from_pos: Vector3 = _ctx.positions[from]
	var to_pos: Vector3 = _ctx.positions[to]
	var direction := _flat(to_pos - from_pos).normalized()
	var radius: float = _ctx.radii.get(from, 5.5)
	return from_pos + direction * (radius - gate_inset)


func _reached(point: Vector3) -> bool:
	return _flat(point - global_position).length() <= waypoint_tolerance


func _toward(point: Vector3) -> Vector3:
	return _flat(point - global_position).normalized() * move_speed


func _look() -> BotLook:
	return _visual as BotLook


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func _to_player_flat() -> Vector3:
	if _ctx == null:
		return Vector3.ZERO
	var watched := _watched()
	if watched == null or not is_instance_valid(watched.node):
		return Vector3.ZERO
	return _flat(watched.node.global_position - global_position)


#Bots never walk off the rim; only players fall
func _stay_on_platform(wanted: Vector3) -> Vector3:
	if _committed or state == State.INACTIVE or wanted == Vector3.ZERO:
		return wanted
	var centre: Vector3 = _ctx.positions[current_vertex]
	var radial := _flat(global_position - centre)
	var limit: float = _ctx.radii.get(current_vertex, 5.5) - rim_margin
	if radial.length() < limit or wanted.dot(radial) <= 0.0:
		return wanted
	var outward := radial.normalized()
	return wanted - outward * wanted.dot(outward)


#Pushes away from other bots on the platform
func _with_separation(wanted: Vector3) -> Vector3:
	if _committed or state == State.INACTIVE:
		return wanted
	var away := Vector3.ZERO
	for other in _ctx.bots:
		if other == self or other._committed:
			continue
		var offset := _flat(global_position - other.global_position)
		var distance := offset.length()
		if distance < separation_radius and distance > 0.01:
			away += offset / distance * (1.0 - distance / separation_radius)
	if away == Vector3.ZERO:
		return wanted
	return (wanted + away * move_speed * separation_weight).limit_length(move_speed)


func _face(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.1:
		return
	var yaw := atan2(direction.x, direction.z)
	_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, yaw, turn_speed * delta)


#Failsafe: puts a fallen bot back on its last platform
func _recover_from_fall() -> void:
	_committed = false
	global_position = _ctx.positions[current_vertex]
	velocity = Vector3.ZERO
	_dirty = true


func _update_push(delta: float) -> void:
	_push_cooldown_left = maxf(_push_cooldown_left - delta, 0.0)
	if _windup_left > 0.0:
		_windup_left -= delta
		if _windup_left <= 0.0:
			_resolve_push()
		return
	if not push_enabled or _push_cooldown_left > 0.0:
		return
	for candidate in _ctx.targets:
		if candidate.protected:
			continue
		var offset := candidate.node.global_position - global_position
		if _flat(offset).length() <= push_trigger_range and absf(offset.y) < push_reach_height:
			_push_target = candidate
			_windup_left = push_windup
			_look().set_alert(true)
			push_announced.emit(self)
			return


func _resolve_push() -> void:
	_look().set_alert(false)
	_look().play_push()
	_push_cooldown_left = push_cooldown
	var victim := _push_target
	_push_target = null
	if victim == null or victim.protected or absf(victim.node.global_position.y - global_position.y) >= push_reach_height:
		return
	var offset := _flat(victim.node.global_position - global_position)
	if offset.length() <= push_hit_range:
		push_landed.emit(self, offset.normalized(), victim.player_id)
