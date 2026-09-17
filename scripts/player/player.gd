class_name Player
extends CharacterBody3D

@export var move_speed := 5.0
@export var jump_velocity := 4.5
@export var turn_speed := 12.0

var player_id := 0
var move_input := Vector2.ZERO
var jump_requested := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _model: CharacterModel

@onready var _model_pivot: Node3D = $ModelPivot
@onready var _camera_rig: PlayerCamera = $CameraRig
@onready var _input: PlayerInput = $PlayerInput


func _ready() -> void:
	#Models face +Z, so turn them to look where the camera looks
	_model_pivot.rotation.y = _camera_rig.global_rotation.y + PI


func set_character(character: CharacterData) -> void:
	if _model:
		_model.queue_free()
	_model = character.model_scene.instantiate() as CharacterModel
	_model_pivot.add_child(_model)


func set_input_enabled(enabled: bool) -> void:
	_input.enabled = enabled


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if jump_requested and is_on_floor():
		velocity.y = jump_velocity
	jump_requested = false

	#Movement follows the camera direction
	var direction := _camera_rig.get_yaw_basis() * Vector3(move_input.x, 0.0, move_input.y)
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	move_and_slide()

	var moving := direction.length() > 0.1
	if moving:
		var target_yaw := atan2(direction.x, direction.z)
		_model_pivot.rotation.y = lerp_angle(_model_pivot.rotation.y, target_yaw, turn_speed * delta)
	if _model:
		_model.set_moving(moving)
