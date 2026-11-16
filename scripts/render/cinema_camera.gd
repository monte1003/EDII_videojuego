class_name CinemaCamera
extends Camera3D

#A film camera for the big moments: it is placed by a point and the point it looks at, glides between shots with eased moves, circles
#around a point and shakes with "trauma" (a blow adds trauma, it fades by itself and the shake grows with its square, so small blows
#barely move it and big ones rock it). A faint hand-held sway keeps it alive between moves

const TRAUMA_FADE := 1.3
const SHAKE_MOVE := 0.32
const SHAKE_TURN := 0.05
const SWAY := 0.035

var trauma := 0.0
var sway := 1.0

var _at := Vector3.ZERO
var _look := Vector3.FORWARD
var _clock := 0.0
var _noise := FastNoiseLite.new()
var _move: Tween
var _zoom: Tween
var _rest_fov := 60.0


func _ready() -> void:
	_rest_fov = fov
	_noise.seed = 7
	_noise.frequency = 0.9


func _process(delta: float) -> void:
	_clock += delta
	trauma = maxf(trauma - TRAUMA_FADE * delta, 0.0)
	var strength := trauma * trauma
	var drift := Vector3(_noise.get_noise_2d(_clock * 0.35, 0.0), _noise.get_noise_2d(0.0, _clock * 0.3), 0.0) * SWAY * sway
	var jolt := Vector3(_noise.get_noise_2d(_clock * 22.0, 10.0), _noise.get_noise_2d(20.0, _clock * 22.0), _noise.get_noise_2d(_clock * 22.0, 30.0)) * SHAKE_MOVE * strength
	global_position = _at + drift + jolt
	if global_position.distance_to(_look) > 0.01:
		look_at(_look + jolt * 0.5, Vector3.UP)
	rotate_object_local(Vector3.FORWARD, _noise.get_noise_2d(_clock * 18.0, 50.0) * SHAKE_TURN * strength)


#A blow: "amount" from 0 to 1 adds to the trauma
func shake(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


#A cut: the camera is there at once
func place(at: Vector3, look: Vector3) -> void:
	_stop_move()
	_at = at
	_look = look


#A move to a new shot in "seconds", eased in and out
func glide(at: Vector3, look: Vector3, seconds: float, trans := Tween.TRANS_SINE, ease_type := Tween.EASE_IN_OUT) -> Tween:
	_stop_move()
	_move = create_tween().set_parallel().set_trans(trans).set_ease(ease_type)
	_move.tween_property(self, "_at", at, seconds)
	_move.tween_property(self, "_look", look, seconds)
	return _move


#Circles around "centre" at "radius" and "height" over it, from one angle to another (degrees, 0 looks from +Z), looking at "look"
func orbit(centre: Vector3, radius: float, height: float, from_degrees: float, to_degrees: float, seconds: float, look: Vector3) -> Tween:
	_stop_move()
	_look = look
	_move = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move.tween_method(func(angle: float) -> void:
		_at = centre + Vector3(sin(deg_to_rad(angle)) * radius, height, cos(deg_to_rad(angle)) * radius), from_degrees, to_degrees, seconds)
	return _move


#A quick change of the field of view that eases back: a punch in when something lands
func punch(degrees: float, seconds := 0.5) -> void:
	if _zoom != null and _zoom.is_valid():
		_zoom.kill()
	fov = _rest_fov - degrees
	_zoom = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom.tween_property(self, "fov", _rest_fov, seconds)


func zoom_to(degrees: float, seconds: float) -> void:
	if _zoom != null and _zoom.is_valid():
		_zoom.kill()
	_rest_fov = degrees
	_zoom = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_zoom.tween_property(self, "fov", degrees, seconds)


func is_moving() -> bool:
	return _move != null and _move.is_running()


func _stop_move() -> void:
	if _move != null and _move.is_valid():
		_move.kill()
