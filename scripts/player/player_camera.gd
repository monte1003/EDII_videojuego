class_name PlayerCamera
extends Node3D

@export var mouse_sensitivity := 0.003
@export var stick_speed := Vector2(2.6, 1.7)
@export_range(-89.0, 0.0) var min_pitch_degrees := -55.0
@export_range(0.0, 89.0) var max_pitch_degrees := 25.0
#Shake fades in 1 / shake_decay seconds; offsets in meters, roll in radians
@export var shake_decay := 2.2
@export var shake_offset := 0.3
@export var shake_roll := 0.045

var _trauma := 0.0
var _base_fov := 70.0
var _kick: Tween

@onready var _pitch_pivot: Node3D = $PitchPivot
@onready var _spring_arm: SpringArm3D = $PitchPivot/SpringArm3D
@onready var _camera: Camera3D = $PitchPivot/SpringArm3D/Camera3D


func _ready() -> void:
	var body := get_parent() as CollisionObject3D
	if body:
		_spring_arm.add_excluded_object(body.get_rid())
	_base_fov = _camera.fov
	set_process(false)


func _process(delta: float) -> void:
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	var power := _trauma * _trauma
	_camera.h_offset = randf_range(-1.0, 1.0) * shake_offset * power
	_camera.v_offset = randf_range(-1.0, 1.0) * shake_offset * power
	_camera.rotation.z = randf_range(-1.0, 1.0) * shake_roll * power
	if _trauma <= 0.0:
		set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	_turn(motion.relative.x * mouse_sensitivity, motion.relative.y * mouse_sensitivity)


#Right stick turns it in radians per second, only while the round holds the mouse
func _physics_process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		_turn(look.x * stick_speed.x * delta, look.y * stick_speed.y * delta)


func _turn(yaw: float, pitch_step: float) -> void:
	rotation.y -= yaw
	var pitch := _pitch_pivot.rotation.x - pitch_step
	_pitch_pivot.rotation.x = clampf(pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))


func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, global_rotation.y)


#Distance and pitch; wide stages frame it wider
func frame(distance: float, pitch_degrees: float) -> void:
	_spring_arm.spring_length = distance
	_pitch_pivot.rotation.x = deg_to_rad(pitch_degrees)


#FOV kick of "degrees" that returns in "seconds"
func kick(degrees: float, seconds: float) -> void:
	if _kick != null and _kick.is_valid():
		_kick.kill()
	_camera.fov = _base_fov + degrees
	_kick = create_tween()
	_kick.tween_property(_camera, "fov", _base_fov, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


#Camera knock 0 to 1; stacks up to the limit
func shake(amount: float) -> void:
	_trauma = minf(maxf(_trauma, amount), 1.0)
	set_process(true)
