class_name SelfieRules
extends RefCounted

#Perfect selfie rules with no nodes: photo order, frame, followers, poses and power-ups

enum Phase { WAITING, TRAVEL, FRAME, LOCK, REVEAL, DONE }
enum Power { JUMP, SPEED, SHIELD }

signal photo_announced(index: int, spot: StringName)
signal frame_shown(index: int)
signal frame_locked(index: int, seconds: float)
signal photo_taken(index: int, shots: Dictionary)
#"style" picks the pose or dance, never the same twice in a row
signal pose_changed(player_id: int, posing: bool, style: int)
signal power_taken(player_id: int, pedestal: int, kind: int, seconds: float)
signal power_returned(pedestal: int, kind: int)
signal finished

const POWER_COUNT := 3
#Seconds the frame glides to a feint
const FEINT_GLIDE := 0.35

#How one player came out in one photo
class Shot:
	var inside := false
	var centered := false
	var posing := false
	var airborne := false
	var crowd := 0
	var followers := 0
	var at := Vector3.ZERO


class PlayerState:
	var id: int
	var followers := 0
	var photos := 0
	var poses := 0
	var best := 0
	var position := Vector3.ZERO
	var grounded := true
	var out := false
	var posing := false
	var pose_time := 0.0
	var pose_style := -1
	var jump_left := 0.0
	var speed_left := 0.0

	func _init(player_id: int) -> void:
		id = player_id


var settings: SelfieSettings
var sheet: ScoreSheet
var layout: SelfieLayout
var players: Dictionary = {}
#Jump height of a player, measured by the scene
var jump_height := 1.03
#Feet of everybody in the last photo, bots included
var photo_feet: Array[Vector3] = []
var phase := Phase.WAITING
var photo_index := -1
#Spots in photo order
var order: Array[StringName] = []
var time_left := 0.0
#Bot positions, counted as others in the photo
var extras: Array[Vector3] = []
#Power-up kind per pedestal (-1 gone) and seconds until it returns
var pedestal_kinds: Array[int] = []

var _rng := RandomNumberGenerator.new()
#Pose styles use their own dice so the frame stays the same on every computer
var _style_rng := RandomNumberGenerator.new()
var _phase_total := 1.0
var _wander := Vector2.ZERO
var _feint := Vector2.ZERO
var _locked := Vector2.ZERO
var _pedestal_left: Array[float] = []


func _init(round_settings: SelfieSettings, score_sheet: ScoreSheet, map: SelfieLayout, ids: Array[int], seed_value: int) -> void:
	settings = round_settings
	sheet = score_sheet
	layout = map
	_rng.seed = seed_value
	for id in ids:
		players[id] = PlayerState.new(id)
	var table := layout.travel_table(layout.build_graph())
	order = photo_order(layout.spots, settings.photo_count, table, layout.spawn_place, settings.reach_seconds, _rng)
	with_troll(order, table, layout.spawn_place, settings.reach_seconds, settings.troll_photo)
	for index in layout.pedestals.size():
		pedestal_kinds.append(index % POWER_COUNT)
		_pedestal_left.append(0.0)


#Plain jump height including the physics half step (1.07 m for 4.5 m/s)
static func jump_height_of(jump_velocity: float) -> float:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var step := 1.0 / Engine.physics_ticks_per_second
	return jump_velocity * jump_velocity / (2.0 * gravity) + jump_velocity * step / 2.0


#Every spot once in random order, refilled when empty
static func shuffled_spots(spots: Array[StringName], rng: RandomNumberGenerator) -> Array[StringName]:
	var bag: Array[StringName] = spots.duplicate()
	for index in range(bag.size() - 1, 0, -1):
		var other := rng.randi() % (index + 1)
		var kept := bag[index]
		bag[index] = bag[other]
		bag[other] = kept
	return bag


#Walkable photo order: random walk with legs under "reach" seconds, no repeats in a row
static func photo_order(spots: Array[StringName], count: int, table: Dictionary, origin: StringName, reach: float, rng: RandomNumberGenerator) -> Array[StringName]:
	var best: Array[StringName] = []
	var best_score := -INF
	for attempt in 300:
		var walk := _walk(spots, count, table, origin, reach, rng)
		var late := 0
		var at := origin
		for entry in walk:
			late += int(float(table[at][entry]) > reach)
			at = entry
		var score := _distinct(walk) * 100.0 - late
		if score > best_score:
			best = walk
			best_score = score
		if late == 0 and _distinct(walk) == mini(spots.size(), count):
			break
	return best


#Puts a troll zone photo in every round where both ways stay short
static func with_troll(walk: Array[StringName], table: Dictionary, origin: StringName, reach: float, wanted: int) -> void:
	if walk.has(&"Z") or not table.has(&"Z") or walk.is_empty():
		return
	var choices: Array[int] = [clampi(wanted, 0, walk.size() - 1)]
	for index in walk.size():
		if not choices.has(index):
			choices.append(index)
	for index in choices:
		var before: StringName = origin if index == 0 else walk[index - 1]
		var fine := before != &"Z" and float(table[before][&"Z"]) <= reach
		if index + 1 < walk.size():
			fine = fine and float(table[&"Z"][walk[index + 1]]) <= reach
		if fine:
			walk[index] = &"Z"
			return
	walk[choices[0]] = &"Z"


static func _walk(spots: Array[StringName], count: int, table: Dictionary, origin: StringName, reach: float, rng: RandomNumberGenerator) -> Array[StringName]:
	var walk: Array[StringName] = []
	var times: Dictionary = {}
	var limit := ceili(float(count) / maxf(spots.size(), 1.0))
	var at := origin
	while walk.size() < count and not spots.is_empty():
		var near: Array[StringName] = []
		var fresh: Array[StringName] = []
		var allowed: Array[StringName] = []
		for candidate in spots:
			if (candidate == at and spots.size() > 1) or int(times.get(candidate, 0)) >= limit:
				continue
			allowed.append(candidate)
			if float(table[at][candidate]) <= reach:
				near.append(candidate)
				if not times.has(candidate):
					fresh.append(candidate)
		var options := fresh if not fresh.is_empty() else near
		var pick: StringName
		if not options.is_empty():
			pick = options[rng.randi() % options.size()]
		elif not allowed.is_empty():
			pick = allowed[0]
			for candidate in allowed:
				if float(table[at][candidate]) < float(table[at][pick]):
					pick = candidate
		else:
			pick = spots[rng.randi() % spots.size()]
		walk.append(pick)
		times[pick] = int(times.get(pick, 0)) + 1
		at = pick
	return walk


static func _distinct(walk: Array[StringName]) -> int:
	var seen: Dictionary = {}
	for entry in walk:
		seen[entry] = true
	return seen.size()


func photo_count() -> int:
	return settings.photo_count


func state_of(player_id: int) -> PlayerState:
	return players.get(player_id)


func start() -> void:
	if phase == Phase.WAITING:
		_announce(0)


func tick(delta: float) -> void:
	_tick_players(delta)
	_tick_pedestals(delta)
	if phase == Phase.WAITING or phase == Phase.DONE:
		return
	time_left -= delta
	if time_left > 0.0:
		return
	match phase:
		Phase.TRAVEL:
			_enter(Phase.FRAME, settings.frame_seconds)
			frame_shown.emit(photo_index)
		Phase.FRAME:
			_locked = _offset_at(settings.frame_seconds)
			_enter(Phase.LOCK, lock_seconds_of(photo_index))
			frame_locked.emit(photo_index, _phase_total)
		Phase.LOCK:
			_shoot()
		Phase.REVEAL:
			if photo_index + 1 >= photo_count():
				phase = Phase.DONE
				finished.emit()
			else:
				_announce(photo_index + 1)


#The scene reports feet, floor contact and falls
func place(player_id: int, position: Vector3, grounded: bool, out: bool) -> void:
	var state := state_of(player_id)
	if state == null:
		return
	state.position = position
	state.grounded = grounded
	state.out = out
	if state.posing and (not grounded or out):
		_set_pose(state, false)


#Poses only standing on the floor
func set_posing(player_id: int, on: bool) -> bool:
	var state := state_of(player_id)
	if state == null or phase == Phase.WAITING or phase == Phase.DONE:
		return false
	if on and (not state.grounded or state.out):
		return false
	_set_pose(state, on)
	return true


#A remote pose only counts for the photo
func set_remote_pose(player_id: int, on: bool) -> void:
	var state := state_of(player_id)
	if state != null and state.posing != on:
		state.posing = on
		state.pose_time = 0.0


func toggle_pose(player_id: int) -> bool:
	return set_posing(player_id, not is_posing(player_id))


func is_posing(player_id: int) -> bool:
	var state := state_of(player_id)
	return state != null and state.posing


#Any blow breaks the pose
func strike(player_id: int) -> void:
	var state := state_of(player_id)
	if state != null and state.posing:
		_set_pose(state, false)


func spot() -> StringName:
	return order[photo_index % order.size()] if photo_index >= 0 else &""


#Share from the first photo to the last
func progress_of(index: int) -> float:
	return clampf(float(index) / maxf(photo_count() - 1, 1.0), 0.0, 1.0)


#Frame side once fixed
func final_size(index: int) -> float:
	return lerpf(settings.frame_start, settings.frame_end, progress_of(index))


func lock_seconds_of(index: int) -> float:
	return lerpf(settings.lock_seconds, settings.lock_end, progress_of(index))


func frame_visible() -> bool:
	return phase == Phase.FRAME or phase == Phase.LOCK


#Frame side now: starts bigger, breathes while moving, ends at its size
func frame_size() -> float:
	var size := final_size(photo_index)
	if phase != Phase.FRAME:
		return size
	var elapsed := _phase_total - time_left
	var settle := smoothstep(0.0, 1.0, elapsed / _phase_total)
	return size * lerpf(1.22, 1.0, settle) * (1.0 + 0.04 * sin(elapsed * 3.0) * (1.0 - settle))


#Frame middle now on its island floor
func frame_center() -> Vector3:
	var offset := _locked
	if phase == Phase.FRAME:
		offset = _offset_at(_phase_total - time_left)
	elif phase != Phase.LOCK and phase != Phase.REVEAL:
		offset = Vector2.ZERO
	return layout.position_of(spot()) + Vector3(offset.x, 0.0, offset.y)


#How close the fixed frame is to its shot, 0 to 1
func lock_share() -> float:
	return 1.0 - clampf(time_left / _phase_total, 0.0, 1.0) if phase == Phase.LOCK else 0.0


func is_inside(point: Vector3) -> bool:
	return in_frame(point, frame_center(), frame_size())


#Inside: over the square and from under the floor up to a jump and a meter
func in_frame(point: Vector3, centre: Vector3, size: float) -> bool:
	var rise := point.y - centre.y
	return absf(point.x - centre.x) <= size / 2.0 and absf(point.z - centre.z) <= size / 2.0 		and rise >= -settings.below_floor and rise <= ceiling()


#Highest point over the set floor that still comes out
func ceiling() -> float:
	return jump_height + settings.air_room


#Takes a pedestal power-up; the shield goes to whoever keeps the blows
func take_power(player_id: int, pedestal: int) -> bool:
	var state := state_of(player_id)
	if state == null or pedestal < 0 or pedestal >= pedestal_kinds.size() or pedestal_kinds[pedestal] < 0:
		return false
	var kind := pedestal_kinds[pedestal]
	var seconds := settings.shield_seconds if kind == Power.SHIELD else settings.boost_seconds
	if is_last(player_id):
		seconds *= settings.behind_bonus
	if kind == Power.JUMP:
		state.jump_left = seconds
	elif kind == Power.SPEED:
		state.speed_left = seconds
	pedestal_kinds[pedestal] = -1
	_pedestal_left[pedestal] = settings.power_respawn
	power_taken.emit(player_id, pedestal, kind, seconds)
	return true


#With several players, the one with fewest followers
func is_last(player_id: int) -> bool:
	if players.size() < 2:
		return false
	var mine := state_of(player_id).followers
	var someone_ahead := false
	for state: PlayerState in players.values():
		if state.followers < mine:
			return false
		someone_ahead = someone_ahead or state.followers > mine
	return someone_ahead


#Current jump and run scale
func jump_scale(player_id: int) -> float:
	var state := state_of(player_id)
	return sqrt(settings.jump_scale) if state != null and state.jump_left > 0.0 else 1.0


func speed_scale(player_id: int) -> float:
	var state := state_of(player_id)
	return settings.speed_scale if state != null and state.speed_left > 0.0 else 1.0


func points_of(player_id: int) -> int:
	var state := state_of(player_id)
	return sheet.selfie_points(state.followers) if state != null else 0


func totals() -> Dictionary:
	var result: Dictionary = {}
	for id: int in players:
		result[id] = points_of(id)
	return result


func _announce(index: int) -> void:
	photo_index = index
	var room := layout.frame_room(spot(), final_size(index) * 1.22)
	var reach := minf(lerpf(settings.wander_start, settings.wander_end, progress_of(index)), room)
	_wander = Vector2(reach, _rng.randf() * TAU)
	_feint = Vector2.ZERO
	if index >= settings.feint_from:
		var angle := _rng.randf() * TAU
		_feint = Vector2(cos(angle), sin(angle)) * minf(settings.feint_shift, layout.frame_room(spot(), final_size(index)))
	_locked = Vector2.ZERO
	_enter(Phase.TRAVEL, settings.travel_seconds)
	photo_announced.emit(index, spot())


func _enter(next: Phase, seconds: float) -> void:
	phase = next
	_phase_total = maxf(seconds, 0.01)
	time_left = _phase_total


#Frame offset from its island middle after "elapsed"
func _offset_at(elapsed: float) -> Vector2:
	var reach := _wander.x
	var slide := Vector2(sin(elapsed * 1.15 + _wander.y), sin(elapsed * 0.8 + _wander.y * 1.7)) * reach
	if _feint == Vector2.ZERO:
		return slide
	var since := elapsed - (settings.frame_seconds - settings.feint_seconds)
	return slide.lerp(_feint, smoothstep(0.0, FEINT_GLIDE, since))


func _shoot() -> void:
	var centre := frame_center()
	var size := final_size(photo_index)
	var crowd := 0
	photo_feet.clear()
	for point in extras:
		if in_frame(point, centre, size):
			crowd += 1
			photo_feet.append(point)
	var shots: Dictionary = {}
	for state: PlayerState in players.values():
		var shot := Shot.new()
		shot.at = state.position
		shot.inside = not state.out and in_frame(state.position, centre, size)
		if shot.inside:
			crowd += 1
			photo_feet.append(state.position)
		shots[state.id] = shot
	for state: PlayerState in players.values():
		var shot: Shot = shots[state.id]
		shot.crowd = crowd
		if not shot.inside:
			continue
		var away := Vector2(state.position.x - centre.x, state.position.z - centre.z).length()
		shot.centered = away <= size * settings.center_share
		shot.posing = state.posing and state.pose_time >= settings.pose_hold
		shot.airborne = not state.grounded
		shot.followers = sheet.selfie_followers(shot.centered, shot.posing, crowd) + air_bonus(shot.airborne, crowd)
		state.followers += shot.followers
		state.photos += 1
		state.poses += int(shot.posing)
		state.best = maxi(state.best, shot.followers)
	_enter(Phase.REVEAL, settings.reveal_seconds)
	photo_taken.emit(photo_index, shots)


#A photo in the air adds a small share of a pose, by crowd
func air_bonus(airborne: bool, crowd: int) -> int:
	if not airborne:
		return 0
	return roundi(sheet.selfie_pose * settings.air_share * sheet.selfie_crowd[clampi(crowd - 1, 0, sheet.selfie_crowd.size() - 1)])


func _set_pose(state: PlayerState, on: bool) -> void:
	if state.posing == on:
		return
	state.posing = on
	state.pose_time = 0.0
	if on:
		#Any style but the last one
		var pick := _style_rng.randi() % maxi(settings.pose_styles - 1, 1)
		state.pose_style = pick if pick < state.pose_style or state.pose_style < 0 or settings.pose_styles < 2 else pick + 1
	pose_changed.emit(state.id, on, state.pose_style)


func _tick_players(delta: float) -> void:
	for state: PlayerState in players.values():
		state.pose_time = state.pose_time + delta if state.posing else 0.0
		state.jump_left = maxf(state.jump_left - delta, 0.0)
		state.speed_left = maxf(state.speed_left - delta, 0.0)


func _tick_pedestals(delta: float) -> void:
	for index in pedestal_kinds.size():
		if pedestal_kinds[index] >= 0:
			continue
		_pedestal_left[index] -= delta
		if _pedestal_left[index] <= 0.0:
			pedestal_kinds[index] = _rng.randi() % POWER_COUNT
			power_returned.emit(index, pedestal_kinds[index])
