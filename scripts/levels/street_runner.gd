class_name StreetRunner
extends Node3D

#Player of the street minigame. It only moves across the street (Z). Its X position changes
#only when an obstacle throws it back, so every hit is ground that cannot be won back.
#It can jump, just for fun: the hit test ignores the height, so jumping never saves it.

#The models are 1 m tall, so 1.4 leaves them a bit under half of a 3 m sidewalk
@export var model_scale := 1.4
@export var move_speed := 6.0
@export var radius := 0.45
@export var jump_velocity := 5.0
#How fast the throw-back and the side shove fade, in m/s per second
@export var push_decay := 16.0
#Minimum grace after a hit; it also lasts while the runner still touches any obstacle
@export var invulnerable_time := 1.2
@export var turn_speed := 12.0
@export var up_action: StringName = &"move_forward"
@export var down_action: StringName = &"move_back"
@export var jump_action: StringName = &"jump"

var player_id := 0
var input_enabled := false
var min_z := -7.0
var max_z := 7.0
#Beyond this |z| the runner is on a raised sidewalk
var street_half_width := 4.5
var sidewalk_height := 0.0
var push_speed := 0.0
var side_speed := 0.0
#Set by the game every frame: true while the runner overlaps an obstacle
var touching := false

var _invulnerable := false
var _invulnerable_left := 0.0
var _ground_y := 0.0
var _jump_height := 0.0
var _vertical_speed := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
#When set, the runner turns to this yaw instead of following the input (victory pose)
var _forced_yaw := NAN
var _model: CharacterModel
var _model_pivot := Node3D.new()


func _ready() -> void:
	add_child(_model_pivot)
	_model_pivot.scale = Vector3.ONE * model_scale
	_model_pivot.rotation.y = _yaw_for(0.0)


func set_character(character: CharacterData) -> void:
	if _model:
		_model.queue_free()
		_model = null
	if character == null or character.model_scene == null:
		push_error("StreetRunner: personaje sin modelo")
		return
	_model = character.model_scene.instantiate() as CharacterModel
	_model_pivot.add_child(_model)


func can_be_hit() -> bool:
	return not _invulnerable


#Throws the runner back (+X) and out of the obstacle's way (side is -1 or 1 on Z)
func take_hit(back_speed: float, side: float, shove_speed: float) -> void:
	push_speed = maxf(push_speed, back_speed)
	side_speed = side * shove_speed
	_invulnerable = true
	_invulnerable_left = invulnerable_time


func jump() -> void:
	if _jump_height <= 0.0:
		_vertical_speed = jump_velocity


#Victory pose: no more motion and the runner turns to look at "point"
func celebrate(point: Vector3) -> void:
	input_enabled = false
	push_speed = 0.0
	side_speed = 0.0
	_invulnerable = false
	_model_pivot.visible = true
	var to_point := point - global_position
	_forced_yaw = atan2(to_point.x, to_point.z)


func _physics_process(delta: float) -> void:
	var axis := 0.0
	if input_enabled:
		axis = Input.get_axis(up_action, down_action)
		if Input.is_action_just_pressed(jump_action):
			jump()
	position.z = clampf(position.z + (axis * move_speed + side_speed) * delta, min_z, max_z)
	position.x += push_speed * delta
	push_speed = move_toward(push_speed, 0.0, push_decay * delta)
	side_speed = move_toward(side_speed, 0.0, push_decay * delta)

	_vertical_speed -= _gravity * delta
	_jump_height = maxf(_jump_height + _vertical_speed * delta, 0.0)
	if _jump_height <= 0.0:
		_vertical_speed = 0.0
	var ground := sidewalk_height if absf(position.z) > street_half_width else 0.0
	_ground_y = move_toward(_ground_y, ground, 2.0 * delta)
	position.y = _ground_y + _jump_height

	if _invulnerable:
		_invulnerable_left -= delta
		if _invulnerable_left <= 0.0 and not touching:
			_invulnerable = false
	#Blinks while it cannot be hit
	_model_pivot.visible = not _invulnerable or fmod(Time.get_ticks_msec() / 1000.0, 0.16) > 0.08
	var yaw := _forced_yaw if not is_nan(_forced_yaw) else _yaw_for(axis)
	_model_pivot.rotation.y = lerp_angle(_model_pivot.rotation.y, yaw, turn_speed * delta)
	if _model:
		_model.set_state(absf(axis) > 0.1, _jump_height > 0.0)


#Faces the oncoming traffic (-X) and leans toward the side it moves to.
#Models face +Z, so the yaw of a direction d is atan2(d.x, d.z)
func _yaw_for(axis: float) -> float:
	return atan2(-1.0, axis * 1.2)
