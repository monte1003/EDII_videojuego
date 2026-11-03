class_name StreetRunner
extends Player

#Player of the street minigame: the usual third-person Player with its own camera, a jump that rests after landing, and a hit
#that throws it back, flips it and gets it up again

signal hit_taken(hit: Hit)
signal landed(at: Vector3, hard: bool)
signal jump_cooldown_changed(left: float, total: float)

#What an obstacle does to the runner when it hits
class Hit:
	var back_speed := 0.0
	var side := 0.0
	var side_speed := 0.0
	#Seconds lying on the ground after a flip, or the stumble of a hit that does not flip
	var stun := 0.0
	var flips := false
	#How hard it feels, from 0 to 1: the hop, the shake of the camera and the effects
	var strength := 0.0

#The models are 1 m tall, so 1.4 keeps them a bit under half of a 3 m sidewalk
@export var model_scale := 1.4
#Radius that keeps the runner inside the street
@export var radius := 0.45
#The body that obstacles touch: a little thinner than the model, as tall as it
@export var hurt_radius := 0.36
@export var hurt_height := 1.3
#Seconds after landing from a jump in which a jump press does nothing
@export var jump_cooldown := 1.5
#How fast the throw-back and the side shove fade, in m/s per second
@export var street_push_decay := 16.0
#Grace after getting up from a hit; it also lasts while the runner still touches any obstacle
@export var invulnerable_time := 0.6

#Where the body turns when it flips: its middle, so it rolls instead of swinging from the feet
const TUMBLE_CENTER := 0.5
const LYING_HEIGHT := 0.28
const GET_UP_TIME := 0.32

var min_x := -13.0
var max_x := 20.0
var min_z := -7.0
var max_z := 7.0
#Set by the game every frame: true while the runner overlaps an obstacle
var touching := false

var _back_speed := 0.0
var _side_speed := 0.0
var _invulnerable := false
var _invulnerable_left := 0.0
#When set, the runner turns to this yaw instead of following the input (victory pose)
var _forced_yaw := NAN
var _force_jump := false
var _cooldown_left := 0.0
#A jump is under way: it started on the ground and has not landed yet
var _jumped := false
var _left_ground := false
var _was_airborne := false
var _hit_flight := false
var _stun_left := 0.0
var _input_wanted := true
var _tumble: Node3D
var _tumble_axis := Vector3.RIGHT
var _tumble_angle := 0.0: set = _set_tumble_angle
var _tumble_tween: Tween


func _ready() -> void:
	move_speed = 6.0
	jump_velocity = 5.0
	#The camera starts behind the runner looking at the oncoming traffic (-X)
	_camera_rig.rotation.y = PI / 2.0
	_model_pivot.scale = Vector3.ONE * model_scale
	_camera_rig.position.y *= model_scale
	var arm := _camera_rig.get_node("PitchPivot/SpringArm3D") as SpringArm3D
	arm.spring_length *= model_scale
	_tumble = Node3D.new()
	_tumble.position = Vector3(0.0, TUMBLE_CENTER, 0.0)
	_model_pivot.add_child(_tumble)
	super()


#The model hangs from the tumble node, so a flip turns it around its middle
func set_character(character: CharacterData) -> void:
	super(character)
	_model.reparent(_tumble, false)
	_model.position = Vector3(0.0, -TUMBLE_CENTER, 0.0)


func set_input_enabled(enabled: bool) -> void:
	_input_wanted = enabled
	_apply_input()


func can_be_hit() -> bool:
	return not _invulnerable


func shake_camera(amount: float) -> void:
	_camera_rig.shake(amount)


#Throws the runner back (+X) and out of the obstacle's way, then it flips or staggers and gets up
func take_hit(hit: Hit) -> void:
	_back_speed = maxf(_back_speed, hit.back_speed)
	_side_speed = hit.side * hit.side_speed
	velocity.y = maxf(velocity.y, 1.6 + 2.2 * hit.strength)
	_hit_flight = true
	var air := 2.0 * velocity.y / _gravity
	_stun_left = air + hit.stun if hit.flips else hit.stun
	_invulnerable = true
	_invulnerable_left = invulnerable_time + _stun_left
	_apply_input()
	_play_tumble(hit, air)
	_camera_rig.shake(0.3 + 0.55 * hit.strength)
	hit_taken.emit(hit)


#The victory jump: it leaves at once, even if the jump is resting
func jump() -> void:
	_force_jump = true


#Victory pose: no more motion and the runner turns to look at "point"
func celebrate(point: Vector3) -> void:
	set_input_enabled(false)
	_back_speed = 0.0
	_side_speed = 0.0
	_invulnerable = false
	_stun_left = 0.0
	_reset_tumble()
	_model_pivot.visible = true
	var to_point := point - global_position
	_forced_yaw = atan2(to_point.x, to_point.z)


func _physics_process(delta: float) -> void:
	_tick_stun(delta)
	_tick_jump(delta)
	_back_speed = move_toward(_back_speed, 0.0, street_push_decay * delta)
	_side_speed = move_toward(_side_speed, 0.0, street_push_decay * delta)
	push_velocity = Vector3(_back_speed, 0.0, _side_speed)
	super(delta)
	_track_landing()
	position.x = clampf(position.x, min_x, max_x)
	position.z = clampf(position.z, min_z, max_z)

	if _invulnerable:
		_invulnerable_left -= delta
		if _invulnerable_left <= 0.0 and not touching:
			_invulnerable = false
	#Blinks while it cannot be hit and is back on its feet
	_model_pivot.visible = not _invulnerable or _stun_left > 0.0 or fmod(Time.get_ticks_msec() / 1000.0, 0.16) > 0.08
	if not is_nan(_forced_yaw):
		_model_pivot.rotation.y = lerp_angle(_model_pivot.rotation.y, _forced_yaw, turn_speed * delta)


func _apply_input() -> void:
	super.set_input_enabled(_input_wanted and _stun_left <= 0.0)


func _tick_stun(delta: float) -> void:
	if _stun_left <= 0.0:
		return
	_stun_left -= delta
	if _stun_left <= 0.0:
		_apply_input()


#A pressed jump leaves at once; after landing the next one waits and a press in the meantime is lost, not saved
func _tick_jump(delta: float) -> void:
	if _force_jump:
		_force_jump = false
		_cooldown_left = 0.0
		jump_requested = true
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
		jump_requested = false
		jump_cooldown_changed.emit(_cooldown_left, jump_cooldown)
	elif jump_requested and is_on_floor():
		_jumped = true


func _track_landing() -> void:
	var grounded := is_on_floor()
	if _jumped:
		if not grounded:
			_left_ground = true
		elif _left_ground:
			_jumped = false
			_left_ground = false
			_cooldown_left = jump_cooldown
			jump_cooldown_changed.emit(_cooldown_left, jump_cooldown)
	if grounded and _was_airborne:
		landed.emit(global_position, _hit_flight)
		_hit_flight = false
	_was_airborne = not grounded


#A flip is a somersault toward where the blow sends the runner, a lie on the ground and a get-up; a stagger is a quick lean
func _play_tumble(hit: Hit, air: float) -> void:
	if _tumble_tween != null and _tumble_tween.is_valid():
		_tumble_tween.kill()
	var knock := Vector3(hit.back_speed, 0.0, hit.side * hit.side_speed).normalized()
	var local := Basis(Vector3.UP, _model_pivot.rotation.y).inverse() * knock
	_tumble_axis = Vector3(local.z, 0.0, -local.x)
	if _tumble_axis.length() < 0.01:
		_tumble_axis = Vector3.RIGHT
	_tumble_axis = _tumble_axis.normalized()
	_tumble_tween = create_tween()
	if not hit.flips:
		_tumble_tween.tween_property(self, "_tumble_angle", 0.5, 0.1).set_ease(Tween.EASE_OUT)
		_tumble_tween.tween_property(self, "_tumble_angle", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		return
	#Full turn in the air and a quarter more: it lands lying on its back
	_tumble_tween.tween_property(self, "_tumble_angle", TAU + PI / 2.0, air * 0.92) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tumble_tween.parallel().tween_property(_tumble, "position:y", LYING_HEIGHT, 0.12).set_delay(air * 0.8)
	_tumble_tween.tween_interval(hit.stun)
	_tumble_tween.tween_property(self, "_tumble_angle", TAU, GET_UP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tumble_tween.parallel().tween_property(_tumble, "position:y", TUMBLE_CENTER, GET_UP_TIME)
	_tumble_tween.tween_callback(_reset_tumble)


func _reset_tumble() -> void:
	if _tumble_tween != null and _tumble_tween.is_valid():
		_tumble_tween.kill()
	_tumble_angle = 0.0
	_tumble.position.y = TUMBLE_CENTER


func _set_tumble_angle(value: float) -> void:
	_tumble_angle = value
	if _tumble != null:
		_tumble.basis = Basis(_tumble_axis, value)
