class_name ZoneBot
extends ChaserBot

#A bot that lives in a zone of its own and never leaves it: it walks straight on a flat floor, with no graph, so it never gets stuck on
#ramps or steps. It goes after the closest player inside its zone and shoves it with the usual warning; with nobody inside it wanders;
#while a photo is taken in its zone it runs into the frame to spoil it. A curb the bot never crosses keeps it in too

#How far inside the edge of its zone the bot keeps, and how close to a player it stops; it reaches whoever stands on a low pad of
#its zone but not on the high one
const EDGE_ROOM := 0.7
const REACH_HEIGHT := 1.0
const CLOSE := 1.1
#Seconds before it picks another spot to wander to
const WANDER_TIME := 2.6

#The floor of its zone on the ground
var bounds := Rect2()
#Where to go to be in the photo, or zero when there is no photo in its zone
var frame_point := Vector3.ZERO

var _wander := Vector3.ZERO
var _wander_left := 0.0
var _rng := RandomNumberGenerator.new()


#Builds the body of a bot: a capsule like the one of the players and the root its model hangs from
static func make() -> ZoneBot:
	var bot := ZoneBot.new()
	bot.collision_layer = 2
	bot.collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.5
	bot.add_child(collider)
	var root := Node3D.new()
	root.name = "VisualRoot"
	bot.add_child(root)
	return bot


#Puts the bot at a spot of its zone and wakes it up
func place(spot: Vector3, seed_value: int) -> void:
	global_position = spot
	_rng.seed = seed_value
	_wander = spot
	push_reach_height = REACH_HEIGHT
	state = State.CHASE


func _physics_process(delta: float) -> void:
	_clock += delta
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	dazed_left = maxf(dazed_left - delta, 0.0)
	knock = knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)
	var wanted := Vector3.ZERO
	if state != State.INACTIVE and dazed_left <= 0.0:
		_update_push(delta)
		if _windup_left <= 0.0 and not hold_movement:
			wanted = _steer(delta)
	wanted = _keep_inside(_with_separation(wanted))
	velocity.x = wanted.x + knock.x
	velocity.z = wanted.z + knock.z
	move_and_slide()
	if _visual != null:
		_look().set_moving(wanted.length() > 0.1)
	_face(wanted if wanted.length() > 0.1 else _to_player_flat(), delta)
	if global_position.y < -15.0:
		place(Vector3(bounds.get_center().x, 0.2, bounds.get_center().y), _rng.randi())


#Where it heads now: into the frame of a photo of its zone, at the closest player that is in its zone, or to a spot of its own
func _steer(delta: float) -> Vector3:
	var goal := Vector3.ZERO
	if frame_point != Vector3.ZERO:
		goal = frame_point
	else:
		var closest := INF
		for candidate in _ctx.targets:
			if candidate.node == null or not is_instance_valid(candidate.node):
				continue
			var at: Vector3 = candidate.node.global_position
			if not bounds.grow(0.5).has_point(Vector2(at.x, at.z)):
				continue
			var distance := _flat(at - global_position).length()
			if distance < closest:
				closest = distance
				goal = at
		if goal != Vector3.ZERO and closest < CLOSE:
			return Vector3.ZERO
	if goal == Vector3.ZERO:
		_wander_left -= delta
		if _wander_left <= 0.0 or _flat(_wander - global_position).length() < 0.6:
			_wander_left = WANDER_TIME
			var inner := bounds.grow(-EDGE_ROOM - 0.5)
			_wander = Vector3(_rng.randf_range(inner.position.x, inner.end.x), 0.0, _rng.randf_range(inner.position.y, inner.end.y))
		goal = _wander
	var way := _flat(goal - global_position)
	if way.length() < 0.15:
		return Vector3.ZERO
	return way.normalized() * move_speed


#It never steps out of its zone: the part of its walk that would take it over the edge is left out
func _keep_inside(wanted: Vector3) -> Vector3:
	var inner := bounds.grow(-EDGE_ROOM)
	var at := Vector2(global_position.x, global_position.z)
	if at.x <= inner.position.x and wanted.x < 0.0 or at.x >= inner.end.x and wanted.x > 0.0:
		wanted.x = 0.0
	if at.y <= inner.position.y and wanted.z < 0.0 or at.y >= inner.end.y and wanted.z > 0.0:
		wanted.z = 0.0
	return wanted
