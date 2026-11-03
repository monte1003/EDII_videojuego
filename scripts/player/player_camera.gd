class_name PlayerCamera
extends Node3D

@export var mouse_sensitivity := 0.003
@export_range(-89.0, 0.0) var min_pitch_degrees := -55.0
@export_range(0.0, 89.0) var max_pitch_degrees := 25.0
#The shake fades out in 1 / shake_decay seconds; offsets are in meters and the roll in radians
@export var shake_decay := 2.2
@export var shake_offset := 0.3
@export var shake_roll := 0.045

var _trauma := 0.0

@onready var _pitch_pivot: Node3D = $PitchPivot
@onready var _spring_arm: SpringArm3D = $PitchPivot/SpringArm3D
@onready var _camera: Camera3D = $PitchPivot/SpringArm3D/Camera3D


func _ready() -> void:
	var body := get_parent() as CollisionObject3D
	if body:
		_spring_arm.add_excluded_object(body.get_rid())
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
	rotation.y -= motion.relative.x * mouse_sensitivity
	var pitch := _pitch_pivot.rotation.x - motion.relative.y * mouse_sensitivity
	_pitch_pivot.rotation.x = clampf(pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))


func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, global_rotation.y)


#How far behind and how steeply above it looks; a round with a wide stage frames it wider
func frame(distance: float, pitch_degrees: float) -> void:
	_spring_arm.spring_length = distance
	_pitch_pivot.rotation.x = deg_to_rad(pitch_degrees)


#A knock to the camera, from 0 to 1; a bigger one while it still shakes adds up to the limit
func shake(amount: float) -> void:
	_trauma = minf(maxf(_trauma, amount), 1.0)
	set_process(true)
