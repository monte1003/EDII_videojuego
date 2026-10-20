class_name PlayerCamera
extends Node3D

@export var mouse_sensitivity := 0.003
@export_range(-89.0, 0.0) var min_pitch_degrees := -55.0
@export_range(0.0, 89.0) var max_pitch_degrees := 25.0

@onready var _pitch_pivot: Node3D = $PitchPivot
@onready var _spring_arm: SpringArm3D = $PitchPivot/SpringArm3D


func _ready() -> void:
	var body := get_parent() as CollisionObject3D
	if body:
		_spring_arm.add_excluded_object(body.get_rid())


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	rotation.y -= motion.relative.x * mouse_sensitivity
	var pitch := _pitch_pivot.rotation.x - motion.relative.y * mouse_sensitivity
	_pitch_pivot.rotation.x = clampf(pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))


func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, global_rotation.y)
