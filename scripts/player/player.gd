class_name Player
extends CharacterBody3D

#A player in third person; a hit throws it, flips it, leaves it lying a moment and gets it up again (the same in every round).
#Its body is soft: it squashes and stretches when it jumps and lands, leans into its run, breathes when it stands, bounces off other players
#and kicks up a little dust. All of that is only on top of the animations of its model and never changes where the body goes except the bump

signal hit_taken(hit: Hit)
signal landed(at: Vector3, hard: bool)
#Two players ran into each other and bounced apart; "strength" goes from 0 to 1
signal bumped(other: Player, strength: float)

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
#The soft body: how stiff and how damped the spring of the squash is, how much of it shows and how far the body leans into its run
const SQUASH_STIFFNESS := 120.0
const SQUASH_DAMPING := 9.5
const SQUASH_LIMIT := 0.38
const LEAN_LIMIT := 0.2
const LEAN_FOLLOW := 14.0
#A bump between players needs this closing speed (m/s) and gives this push; then it rests so one touch is one bounce
const BUMP_MIN_CLOSING := 1.4
const BUMP_PUSH := 3.4
const BUMP_REST := 0.4
const BUMP_HOP := 1.6
const DUST_EVERY := 0.26
#A pose: how far the body leans from side to side and how much taller it stands
const POSE_LEAN := 0.2
const POSE_STRETCH := 0.07
#A cannon shot: how much of its own speed the player can steer with in the air, the seconds before landing can end it, and how much of the
#speed of the flight it keeps as a skid when it lands
const FLIGHT_CONTROL := 0.3
const FLIGHT_GRACE := 0.2
const FLIGHT_SKID := 0.3

var player_id := 0
var move_input := Vector2.ZERO
var jump_requested := false
#Extra horizontal velocity from outside (a hit); it fades out on its own
var push_velocity := Vector3.ZERO
#Constant drift of the ground under the player (a conveyor belt); the round sets it every frame
var external_velocity := Vector3.ZERO
#Set by the round every frame: true while the player overlaps what hit it
var touching := false
#Striking a pose: the player stands still and cannot jump while the round keeps it on
var posing := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _model: CharacterModel
var _invulnerable := false
var _invulnerable_left := 0.0
var _hit_flight := false
var _was_airborne := false
var _stun_left := 0.0
var _input_wanted := true
var _tumble: Node3D
#The soft body: everything of the model hangs from here, so a squash grows from the feet and a lean tilts the whole body
var _body: Node3D
var _squash := 0.0
var _squash_speed := 0.0
var _lean := Vector2.ZERO
var _spin := 0.0
var _intended := Vector3.ZERO
var _peak_fall := 0.0
var _bump_rest_left := 0.0
var _dust_left := 0.0
var _celebrating := false
#The speed along the ground of a cannon shot while it lasts
var _flight := Vector3.ZERO
var _flying := false
var _flight_age := 0.0
var _tumble_axis := Vector3.RIGHT
var _tumble_angle := 0.0: set = _set_tumble_angle
var _tumble_tween: Tween

@onready var _model_pivot: Node3D = $ModelPivot
@onready var _camera_rig: PlayerCamera = $CameraRig
@onready var _input: PlayerInput = $PlayerInput


func _ready() -> void:
	#Models face +Z, so turn them to look where the camera looks
	_model_pivot.rotation.y = _camera_rig.global_rotation.y + PI
	#The model hangs from the tumble node, so a flip turns it around its middle, and that one from the soft body
	_body = Node3D.new()
	_model_pivot.add_child(_body)
	_tumble = Node3D.new()
	_tumble.position = Vector3(0.0, TUMBLE_CENTER, 0.0)
	_body.add_child(_tumble)


func set_character(character: CharacterData) -> void:
	if _model:
		_model.queue_free()
	_model = character.model_scene.instantiate() as CharacterModel
	_tumble.add_child(_model)
	_model.position = Vector3(0.0, -TUMBLE_CENTER, 0.0)


#Where the model looks, on the ground
func look_direction() -> Vector3:
	return Basis(Vector3.UP, _model_pivot.rotation.y) * Vector3.BACK


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
	if impulse.y > 3.0:
		_squash_speed += 3.0 + impulse.y * 0.4


#A cannon shot: the player flies along an arc that only it can bend a little, and lands wherever the arc ends
func launch(impulse: Vector3) -> void:
	_flight = Vector3(impulse.x, 0.0, impulse.z)
	_flying = true
	_flight_age = 0.0
	push_velocity = Vector3.ZERO
	velocity.y = impulse.y
	_squash_speed += 6.0


func is_flying() -> bool:
	return _flying


#A jump for joy: it hops, spins once in the air and lands with a little squash; the rounds call it when somebody wins
func victory_hop() -> void:
	if _celebrating or _stun_left > 0.0:
		return
	_celebrating = true
	if is_on_floor():
		velocity.y = jump_velocity * 1.25
	_squash_speed += 6.0
	var tween := create_tween()
	tween.tween_property(self, "_spin", TAU, 0.75).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_end_celebration)


#The body squashes (negative) or stretches (positive) like a spring and settles; strength 1 is a hard knock
func squash(amount: float) -> void:
	_squash_speed += amount


#A blow: it throws the player, then it flips or staggers and gets up
func take_hit(hit: Hit) -> void:
	_end_flight(false)
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
	_end_flight(false)
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
	if posing:
		move_input = Vector2.ZERO
		jump_requested = false
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if jump_requested and is_on_floor():
		velocity.y = jump_velocity
		_squash_speed += 5.0
	jump_requested = false

	if _flying:
		_flight_age += delta
		if _flight_age > FLIGHT_GRACE and is_on_floor():
			_end_flight(true)

	#Movement follows the camera direction
	var direction := _camera_rig.get_yaw_basis() * Vector3(move_input.x, 0.0, move_input.y)
	var control := FLIGHT_CONTROL if _flying else 1.0
	velocity.x = direction.x * move_speed * control + push_velocity.x + external_velocity.x + _flight.x
	velocity.z = direction.z * move_speed * control + push_velocity.z + external_velocity.z + _flight.z
	_intended = Vector3(velocity.x, 0.0, velocity.z)
	if not is_on_floor():
		_peak_fall = maxf(_peak_fall, -velocity.y)
	#Each part of the push fades on its own, so a blow along the street stops sooner sideways than forward
	push_velocity.x = move_toward(push_velocity.x, 0.0, push_decay * delta)
	push_velocity.z = move_toward(push_velocity.z, 0.0, push_decay * delta)
	move_and_slide()
	_track_landing()
	_check_bumps()

	var facing := _flight if _flying else direction
	var moving := facing.length() > 0.1
	if moving:
		var target_yaw := atan2(facing.x, facing.z)
		_model_pivot.rotation.y = lerp_angle(_model_pivot.rotation.y, target_yaw, turn_speed * delta)
	if _model:
		_model.set_state(moving, not is_on_floor())
	_tick_grace(delta)
	_animate_body(delta)
	_kick_dust(delta)


#The shot is over: when the player lands it keeps a little of the speed as a skid
func _end_flight(landed_on_floor: bool) -> void:
	if landed_on_floor:
		push_velocity = _flight * FLIGHT_SKID
	_flying = false
	_flight = Vector3.ZERO


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
		#A fall squashes the body as much as it was fast
		_squash_speed -= clampf(_peak_fall * 0.9, 1.5, 7.5)
		_peak_fall = 0.0
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


#Whoever the body runs into while going fast bounces away softly, and so does the other: a push, a little hop, a squash and a puff of dust
func _check_bumps() -> void:
	_bump_rest_left = maxf(_bump_rest_left - get_physics_process_delta_time(), 0.0)
	if _bump_rest_left > 0.0:
		return
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		var other := contact.get_collider() as Player
		if other == null or other._bump_rest_left > 0.0:
			continue
		var away := contact.get_normal()
		away.y = 0.0
		if away.length() < 0.1:
			continue
		away = away.normalized()
		var closing := (_intended - other._intended).dot(-away)
		if closing >= BUMP_MIN_CLOSING:
			_bump(other, away, clampf(closing / (move_speed * 2.0), 0.15, 1.0))
			return


func _bump(other: Player, away: Vector3, strength: float) -> void:
	var push := BUMP_PUSH + 3.0 * strength
	for pair: Array in [[self, away], [other, -away]]:
		var body := pair[0] as Player
		body.push_velocity = (body.push_velocity + (pair[1] as Vector3) * push).limit_length(8.0)
		if body.is_on_floor():
			body.velocity.y = maxf(body.velocity.y, BUMP_HOP * strength + 0.5)
		body._squash_speed -= 4.0 + 5.0 * strength
		body._bump_rest_left = BUMP_REST
	var middle := (global_position + other.global_position) / 2.0 + Vector3(0.0, 0.1, 0.0)
	ImpactFx.dust(get_parent(), middle, ImpactFx.DUST_COLOR, 4 + roundi(6.0 * strength))
	SynthSound.play(get_parent(), SynthSound.tone(230.0, 0.18, 320.0, 0.5), -9.0 + 4.0 * strength, randf_range(0.95, 1.1))
	shake_camera(0.1 + 0.2 * strength)
	other.shake_camera(0.1 + 0.2 * strength)
	bumped.emit(other, strength)
	other.bumped.emit(self, strength)


#The soft body: a spring for the squash, a lean into the movement and a soft breath when it stands still. In a hit flight or lying down it is
#left alone, so the blow looks the same as ever
func _animate_body(delta: float) -> void:
	var calm := _hit_flight or _stun_left > 0.0
	if calm:
		_squash_speed = 0.0
		_squash = move_toward(_squash, 0.0, delta * 3.0)
		_lean = _lean.move_toward(Vector2.ZERO, delta * 3.0)
	else:
		_squash_speed += (-SQUASH_STIFFNESS * _squash - SQUASH_DAMPING * _squash_speed) * delta
		_squash = clampf(_squash + _squash_speed * delta, -SQUASH_LIMIT, SQUASH_LIMIT)
		var local := _model_pivot.global_basis.inverse() * _intended
		var aim := Vector2(clampf(local.z * 0.028, -LEAN_LIMIT, LEAN_LIMIT), clampf(-local.x * 0.03, -LEAN_LIMIT, LEAN_LIMIT))
		if not is_on_floor():
			aim *= 0.5
		if posing:
			#A pose: the hip out to one side and the body swaying a little, proud of itself
			aim = Vector2(-0.1, POSE_LEAN * sin(Time.get_ticks_msec() * 0.004))
		_lean = _lean.lerp(aim, 1.0 - exp(-LEAN_FOLLOW * delta))
	var breath := sin(Time.get_ticks_msec() * 0.0022) * 0.012 if _intended.length() < 0.5 and not calm else 0.0
	if posing and not calm:
		breath = POSE_STRETCH + 0.03 * sin(Time.get_ticks_msec() * 0.008)
	var stretch := _squash + breath
	_body.basis = Basis(Vector3.UP, _spin) * Basis(Vector3.RIGHT, _lean.x) * Basis(Vector3.BACK, _lean.y) \
		* Basis.from_scale(Vector3(1.0 - 0.5 * stretch, 1.0 + stretch, 1.0 - 0.5 * stretch))


#A little puff under the feet now and then while it runs
func _kick_dust(delta: float) -> void:
	_dust_left -= delta
	if _dust_left > 0.0 or not is_on_floor() or _hit_flight or _intended.length() < move_speed * 0.7:
		return
	_dust_left = DUST_EVERY
	ImpactFx.dust(get_parent(), global_position + Vector3(0.0, 0.04, 0.0), ImpactFx.DUST_COLOR, 3)


func _end_celebration() -> void:
	_spin = 0.0
	_celebrating = false


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
