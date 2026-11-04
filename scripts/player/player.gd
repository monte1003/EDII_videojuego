class_name Player
extends CharacterBody3D

#A player in third person; a hit throws it, flips it, leaves it lying a moment and gets it up again (the same in every round)

signal hit_taken(hit: Hit)
signal landed(at: Vector3, hard: bool)

#What a blow does to the player
class Hit:
	#Horizontal speed of the blow in world space (m/s); it fades out on its own
	var push := Vector3.ZERO
	#Seconds lying on the ground after a flip, or the stumble of a hit that does not flip
	var stun := 0.0
	var flips := false
	#How hard it feels, from 0 to 1: the hop, the shake of the camera and the effects
	var strength := 0.0

@export var move_speed := 5.0
@export var jump_velocity := 4.5
@export var turn_speed := 12.0
@export var push_decay := 18.0
#Grace after getting up from a hit; it also lasts while the player still touches what hit it
@export var invulnerable_time := 0.6

#Where the body turns when it flips: its middle, so it rolls instead of swinging from the feet
const TUMBLE_CENTER := 0.5
const LYING_HEIGHT := 0.28
const GET_UP_TIME := 0.32

var player_id := 0
var move_input := Vector2.ZERO
var jump_requested := false
#Extra horizontal velocity from outside (a hit); it fades out on its own
var push_velocity := Vector3.ZERO
#Constant drift of the ground under the player (a conveyor belt); the round sets it every frame
var external_velocity := Vector3.ZERO
#Set by the round every frame: true while the player overlaps what hit it
var touching := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _model: CharacterModel
var _invulnerable := false
var _invulnerable_left := 0.0
var _hit_flight := false
var _was_airborne := false
var _stun_left := 0.0
var _input_wanted := true
var _tumble: Node3D
var _tumble_axis := Vector3.RIGHT
var _tumble_angle := 0.0: set = _set_tumble_angle
var _tumble_tween: Tween

@onready var _model_pivot: Node3D = $ModelPivot
@onready var _camera_rig: PlayerCamera = $CameraRig
@onready var _input: PlayerInput = $PlayerInput


func _ready() -> void:
	#Models face +Z, so turn them to look where the camera looks
	_model_pivot.rotation.y = _camera_rig.global_rotation.y + PI
	#The model hangs from the tumble node, so a flip turns it around its middle
	_tumble = Node3D.new()
	_tumble.position = Vector3(0.0, TUMBLE_CENTER, 0.0)
	_model_pivot.add_child(_tumble)


func set_character(character: CharacterData) -> void:
	if _model:
		_model.queue_free()
	_model = character.model_scene.instantiate() as CharacterModel
	_tumble.add_child(_model)
	_model.position = Vector3(0.0, -TUMBLE_CENTER, 0.0)


func view_camera() -> Camera3D:
	return _camera_rig.get_node("PitchPivot/SpringArm3D/Camera3D") as Camera3D


func frame_camera(distance: float, pitch_degrees: float) -> void:
	_camera_rig.frame(distance, pitch_degrees)


func shake_camera(amount: float) -> void:
	_camera_rig.shake(amount)


func can_be_hit() -> bool:
	return not _invulnerable


func is_down() -> bool:
	return _stun_left > 0.0


#A plain shove: the horizontal part fades out and the vertical part is a small hop
func apply_push(impulse: Vector3) -> void:
	push_velocity = Vector3(impulse.x, 0.0, impulse.z)
	velocity.y = maxf(velocity.y, impulse.y)


#A blow: it throws the player, then it flips or staggers and gets up
func take_hit(hit: Hit) -> void:
	push_velocity = hit.push
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


#Stops every kind of motion, used when the player is put back somewhere
func clear_motion() -> void:
	velocity = Vector3.ZERO
	push_velocity = Vector3.ZERO
	move_input = Vector2.ZERO
	jump_requested = false
	reset_hit_state()


#Back on its feet at once, with no grace left
func reset_hit_state() -> void:
	_stun_left = 0.0
	_invulnerable = false
	_hit_flight = false
	_reset_tumble()
	if _model_pivot != null:
		_model_pivot.visible = true
	_apply_input()


func set_input_enabled(enabled: bool) -> void:
	_input_wanted = enabled
	_apply_input()


func _physics_process(delta: float) -> void:
	_tick_stun(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if jump_requested and is_on_floor():
		velocity.y = jump_velocity
	jump_requested = false

	#Movement follows the camera direction
	var direction := _camera_rig.get_yaw_basis() * Vector3(move_input.x, 0.0, move_input.y)
	velocity.x = direction.x * move_speed + push_velocity.x + external_velocity.x
	velocity.z = direction.z * move_speed + push_velocity.z + external_velocity.z
	#Each part of the push fades on its own, so a blow along the street stops sooner sideways than forward
	push_velocity.x = move_toward(push_velocity.x, 0.0, push_decay * delta)
	push_velocity.z = move_toward(push_velocity.z, 0.0, push_decay * delta)
	move_and_slide()
	_track_landing()

	var moving := direction.length() > 0.1
	if moving:
		var target_yaw := atan2(direction.x, direction.z)
		_model_pivot.rotation.y = lerp_angle(_model_pivot.rotation.y, target_yaw, turn_speed * delta)
	if _model:
		_model.set_state(moving, not is_on_floor())
	_tick_grace(delta)


func _apply_input() -> void:
	_input.enabled = _input_wanted and _stun_left <= 0.0


func _tick_stun(delta: float) -> void:
	if _stun_left <= 0.0:
		return
	_stun_left -= delta
	if _stun_left <= 0.0:
		_apply_input()


func _track_landing() -> void:
	var grounded := is_on_floor()
	if grounded and _was_airborne:
		landed.emit(global_position, _hit_flight)
		_hit_flight = false
	_was_airborne = not grounded


#Blinks while it cannot be hit and is back on its feet
func _tick_grace(delta: float) -> void:
	if _invulnerable:
		_invulnerable_left -= delta
		if _invulnerable_left <= 0.0 and not touching:
			_invulnerable = false
	_model_pivot.visible = not _invulnerable or _stun_left > 0.0 or fmod(Time.get_ticks_msec() / 1000.0, 0.16) > 0.08


#A flip is a somersault toward where the blow sends the player, a lie on the ground and a get-up; a stagger is a quick lean
func _play_tumble(hit: Hit, air: float) -> void:
	if _tumble_tween != null and _tumble_tween.is_valid():
		_tumble_tween.kill()
	var knock := Vector3(hit.push.x, 0.0, hit.push.z).normalized()
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
	if _tumble != null:
		_tumble.position.y = TUMBLE_CENTER


func _set_tumble_angle(value: float) -> void:
	_tumble_angle = value
	if _tumble != null:
		_tumble.basis = Basis(_tumble_axis, value)
