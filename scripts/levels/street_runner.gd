class_name StreetRunner
extends Player

#Street player: the usual Player with its own camera and a jump that rests after landing

signal jump_cooldown_changed(left: float, total: float)

#1 m models at 1.4, under half of a 3 m sidewalk
@export var model_scale := 1.4
#Radius that keeps the runner inside the street
@export var radius := 0.45
#Hurt body a little thinner than the model
@export var hurt_radius := 0.36
@export var hurt_height := 1.3
#Seconds after landing before another jump
@export var jump_cooldown := 1.5

var min_x := -13.0
var max_x := 20.0
var min_z := -7.0
var max_z := 7.0

#Forced yaw for the victory pose
var _forced_yaw := NAN
var _force_jump := false
var _cooldown_left := 0.0
#A jump left the ground and has not landed
var _jumped := false
var _left_ground := false


func _ready() -> void:
	move_speed = 6.0
	jump_velocity = 5.0
	push_decay = 16.0
	#Camera behind the runner facing the traffic (-X)
	_camera_rig.rotation.y = PI / 2.0
	_model_pivot.scale = Vector3.ONE * model_scale
	_camera_rig.position.y *= model_scale
	var arm := _camera_rig.get_node("PitchPivot/SpringArm3D") as SpringArm3D
	arm.spring_length *= model_scale
	super()


#Victory jump leaves at once
func jump() -> void:
	_force_jump = true


#Victory pose: still, facing "point"
func celebrate(point: Vector3) -> void:
	set_input_enabled(false)
	push_velocity = Vector3.ZERO
	reset_hit_state()
	var to_point := point - global_position
	_forced_yaw = atan2(to_point.x, to_point.z)
	victory_hop()


func _physics_process(delta: float) -> void:
	_tick_jump(delta)
	super(delta)
	_track_jump_landing()
	position.x = clampf(position.x, min_x, max_x)
	position.z = clampf(position.z, min_z, max_z)
	if not is_nan(_forced_yaw):
		_model_pivot.rotation.y = lerp_angle(_model_pivot.rotation.y, _forced_yaw, turn_speed * delta)


#A press during the rest is lost, not saved
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


func _track_jump_landing() -> void:
	if not _jumped:
		return
	if not is_on_floor():
		_left_ground = true
	elif _left_ground:
		_jumped = false
		_left_ground = false
		_cooldown_left = jump_cooldown
		jump_cooldown_changed.emit(_cooldown_left, jump_cooldown)
