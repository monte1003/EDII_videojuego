class_name SpectatorDirector
extends Node

#The camera of the fair screen inside a round it watches without playing. It cuts between a wide shot of the whole field (going round it
#from high up, as the openings of the rounds do) and shots that follow one player from behind and above, and it chooses by what happens:
#a shove or a fall cuts to whoever took it, somebody finishing hands the camera to someone still playing, the last one in play keeps it;
#with nothing happening it takes turns. No shot lasts less than MIN_SHOT seconds, so it never cuts too fast

#Who is in focus (-1 for the wide shot) and why, for the banner of the frame
signal focus_changed(player_id: int, reason: String)

const MIN_SHOT := 4.0
const MAX_SHOT := 8.5
#Every this many shots, the wide one
const WIDE_EVERY := 3
#A player this far under the ground it stood on a moment ago is falling
const FALL_DROP := 2.5
const FOLLOW_DISTANCE := 5.4
const FOLLOW_HEIGHT := 2.5
#The ranking covers the right quarter of the screen: the subject slides to the middle of the rest (as in the trailer)
const SHIFT := 0.23

var camera := CinemaCamera.new()

var _round: RoundScene
var _target := -2
var _shot_age := 0.0
var _shot_length := MIN_SHOT
var _shots := 0
var _wanted := -1
var _wanted_reason := ""
var _done: Dictionary = {}
var _ground: Dictionary = {}
var _falling: Dictionary = {}
var _angle := 0.0
var _focus := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_round = get_parent() as RoundScene
	camera.fov = 58.0
	add_child(camera)
	_rng.randomize()


func _process(delta: float) -> void:
	if _round == null or _round.filming or _round.everyone.is_empty():
		return
	if get_viewport().get_camera_3d() != camera:
		camera.make_current()
	_watch_falls(delta)
	_shot_age += delta
	var lost := _target >= 0 and not _valid(_target)
	if _target == -2 or lost or _shot_age >= _shot_length or (_wanted >= 0 and _shot_age >= MIN_SHOT):
		_cut()
	_frame(delta)


#A shove landed on a player
func on_struck(player_id: int) -> void:
	_want(player_id, "¡EMPUJÓN!")
	if _target == player_id:
		camera.punch(6.0, 0.5)


#A player finished its round: the camera goes to someone still in play
func on_done(player_id: int) -> void:
	_done[player_id] = true
	if _target == player_id:
		var next := _next_playing()
		if next >= 0:
			_want(next, "EL ÚLTIMO EN PIE" if _playing().size() == 1 else "SIGUE EN JUEGO")


func _want(player_id: int, reason: String) -> void:
	if _valid(player_id):
		_wanted = player_id
		_wanted_reason = reason


func _cut() -> void:
	_shots += 1
	var target := -1
	var reason := ""
	if _wanted >= 0 and _valid(_wanted):
		target = _wanted
		reason = _wanted_reason
	elif _shots % WIDE_EVERY != 1:
		target = _next_playing()
		reason = "EL ÚLTIMO EN PIE" if _playing().size() == 1 else "EN JUEGO"
	_wanted = -1
	_target = target
	_shot_age = 0.0
	_shot_length = _rng.randf_range(MIN_SHOT + 1.0, MAX_SHOT)
	_angle = _rng.randf_range(0.0, TAU)
	if target >= 0:
		_focus = (_round.everyone[target] as Node3D).global_position
	focus_changed.emit(target, reason)
	_frame(0.0)


#Where the camera goes this frame: around the field, or behind and above the player in focus
func _frame(delta: float) -> void:
	if _target < 0:
		var area := _round.playing_area()
		var center := area.get_center() if area.size != Vector3.ZERO else _middle_of_players()
		var radius := clampf(maxf(area.size.x, area.size.z) * 0.6, 12.0, 45.0)
		_angle += delta * 0.12
		camera.h_offset = SHIFT * radius * 1.1
		camera.place(center + Vector3(sin(_angle) * radius, radius * 0.55, cos(_angle) * radius), center)
		return
	var body := _round.everyone[_target] as Node3D
	_focus = _focus.lerp(body.global_position, 1.0 - exp(-6.0 * delta))
	_angle += delta * 0.15
	camera.h_offset = SHIFT * FOLLOW_DISTANCE
	camera.place(_focus + Vector3(sin(_angle) * FOLLOW_DISTANCE, FOLLOW_HEIGHT, cos(_angle) * FOLLOW_DISTANCE), _focus + Vector3(0.0, 0.9, 0.0))


#The ground of each player follows it up at once and down slowly; well under it, the player is falling (said once per fall)
func _watch_falls(delta: float) -> void:
	for id: int in _round.everyone:
		if not _valid(id):
			continue
		var height := (_round.everyone[id] as Node3D).global_position.y
		var ground := maxf(height, lerpf(float(_ground.get(id, height)), height, delta * 0.5))
		_ground[id] = ground
		var falling := height < ground - FALL_DROP
		if falling and not _falling.get(id, false):
			_want(id, "¡SE CAYÓ!")
		_falling[id] = falling


func _valid(player_id: int) -> bool:
	var body: Variant = _round.everyone.get(player_id)
	return body != null and is_instance_valid(body) and (body as Node3D).visible


func _playing() -> Array[int]:
	var ids: Array[int] = []
	for id: int in _round.everyone:
		if _valid(id) and not _done.has(id):
			ids.append(id)
	ids.sort()
	return ids


#The next one in play after the one in focus (all of them when nobody is still playing)
func _next_playing() -> int:
	var ids := _playing()
	if ids.is_empty():
		for id: int in _round.everyone:
			if _valid(id):
				ids.append(id)
		ids.sort()
	if ids.is_empty():
		return -1
	for id in ids:
		if id > _target:
			return id
	return ids[0]


func _middle_of_players() -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for id: int in _round.everyone:
		if _valid(id):
			sum += (_round.everyone[id] as Node3D).global_position
			count += 1
	return sum / maxf(count, 1.0)
