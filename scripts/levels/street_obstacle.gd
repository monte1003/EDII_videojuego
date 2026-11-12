class_name StreetObstacle
extends Node3D

#A vehicle, cone or pedestrian of the street minigame; the hit box is measured from the model it shows. Everybody that is a
#person (walkers, riders, the ones inside the cars) is a Citizen: a hero in another tone, looking at the phone

enum Kind { CAR, PEDESTRIAN, TANK, CYCLIST, CONE }

#The hit box is this share of the model, so a near miss feels fair and a hit always shows
const HIT_FORGIVENESS := 0.94
#Seconds a new obstacle takes to pop in at the edge of the street
const POP_IN_TIME := 0.4
#Pedestrians walk, they do not run; the stride is matched to the speed they cross at
const WALK_ANIMATION_PER_MPS := 0.75
const MAX_WALK_SPEED := 2.4
const PEDESTRIAN_HALF := 0.34
const PEDESTRIAN_HEIGHT := 1.5
const CONE_HEIGHT := 0.8
#A rider is 1.5 times the size of the model, which makes the bike about 2 m long
const CYCLIST_SCALE := 1.5
const CYCLIST_HALF := Vector2(0.97, 0.36)
const CYCLIST_HEIGHT := 1.6
#Height of the hips of a seated person above its feet, in the units of the model (see make_street_anims.gd)
const SEATED_HIPS := 0.1
#The people far from the camera are not drawn and none of them casts a shadow; the ones inside a car are small, so they go sooner
const WALKER_DRAW_DISTANCE := 30.0
const PASSENGER_DRAW_DISTANCE := 20.0
#Where the people sit in each car: the size they have there and, for each seat, its share of the length (toward the front),
#of the height (the hips) and of the width. The driver comes first and always rides; each other seat is taken some of the time
const SEATS := {
	&"car_hatch": {"size": 1.3, "seats": [Vector3(0.12, 0.42, -0.2), Vector3(0.12, 0.42, 0.2), Vector3(-0.2, 0.42, 0.0)]},
	&"van": {"size": 1.35, "seats": [Vector3(0.27, 0.42, -0.21), Vector3(0.27, 0.42, 0.21), Vector3(-0.02, 0.42, -0.21),
		Vector3(-0.02, 0.42, 0.21), Vector3(-0.3, 0.42, 0.0)]},
}
const SEAT_TAKEN_CHANCE := 0.45
const SEAT_COLOR := Color("3a3358")

static var _interiors: Dictionary = {}
static var _seat_material: StandardMaterial3D

var kind := Kind.CAR
var base_speed := 0.0
#Half size of the hit box on the XZ plane and its height from the ground it stands on
var half_extents := Vector2.ZERO
var height := 1.0
#What a hit does to the runner: the throw-back speed, the seconds it loses control, whether it flips and how hard it feels (0 to 1)
var knockback := 0.0
var stun := 0.0
var flips := false
var strength := 1.0

var _visual: Node3D
var _walker: Citizen
var _rider: Cyclist
var _anchor_z := 0.0
var _sway := 0.0
var _sway_rate := 0.0
var _clock := 0.0
var _react: Tween


func _init() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_clock = randf() * TAU


func _ready() -> void:
	_anchor_z = position.z
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, POP_IN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


#A hatchback or a minibus driving toward +X; "color" tints the cream body, "roof" its roof, and people sit inside
func build_car(model_id: StringName, color: Color, length: float, rng: RandomNumberGenerator, roof := Color.TRANSPARENT) -> void:
	_set_kind(Kind.CAR)
	var box := _adopt(PropKit.make_car(model_id, length, color, roof))
	_furnish(model_id, box)
	_seat_people(model_id, box, rng)


#Rare obstacle as wide as two lanes; its cannon points +X, the way it goes
func build_tank(length: float, width: float) -> void:
	_set_kind(Kind.TANK)
	_adopt(PropKit.make(&"tank", Vector3(length, 0.0, width * 0.93)))


#A rider that weaves a little inside its lane, on a bike, with its eyes on the phone
func build_cyclist(rng: RandomNumberGenerator) -> void:
	_set_kind(Kind.CYCLIST)
	_rider = Cyclist.new()
	_rider.build(rng)
	_rider.scale = Vector3.ONE * CYCLIST_SCALE
	_rider.rotation.y = PI / 2.0
	_visual.add_child(_rider)
	_limit_view(_rider.rider, WALKER_DRAW_DISTANCE)
	half_extents = CYCLIST_HALF
	height = CYCLIST_HEIGHT
	_sway = 0.4
	_sway_rate = 2.6


#A traffic cone riding the belt: low enough to jump over
func build_cone() -> void:
	_set_kind(Kind.CONE)
	_adopt(PropKit.make_tall(&"cone", CONE_HEIGHT))


#A walker that looks at its phone; the model faces +Z, so it is turned to walk toward +X like the cars
func build_pedestrian(rng: RandomNumberGenerator) -> void:
	_set_kind(Kind.PEDESTRIAN)
	_walker = Citizen.new()
	_walker.build(Citizen.Pose.WALK, rng, rng.randf())
	var size := rng.randf_range(1.3, 1.5)
	_walker.scale = Vector3.ONE * size
	_walker.rotation.y = PI / 2.0
	_visual.add_child(_walker)
	_limit_view(_walker, WALKER_DRAW_DISTANCE)
	half_extents = Vector2.ONE * PEDESTRIAN_HALF * size / 1.4
	height = PEDESTRIAN_HEIGHT * size / 1.4
	_sway = 0.5
	_sway_rate = 1.1


#Drives forward at "flow" times its own speed and keeps its weave; pedestrians and riders sway across their row
func advance(delta: float, flow: float) -> void:
	_clock += delta
	var step := base_speed * flow * delta
	position.x += step
	if _walker != null:
		_walker.set_speed(minf(base_speed * flow * WALK_ANIMATION_PER_MPS, MAX_WALK_SPEED))
	if _rider != null:
		_rider.roll(step, delta)
	if _sway > 0.0:
		position.z = _anchor_z + sin(_clock * _sway_rate) * _sway
	if kind == Kind.CYCLIST:
		_visual.rotation.x = cos(_clock * _sway_rate) * 0.07


#True when a body standing at "point" (its feet) with a round footprint of "radius" and "body_height" touches the hit box
#Circle (the body footprint) against box on the ground plane: the gap from the box to the circle centre on each
#axis (0 when inside) is compared with the radius, both squared so there is no square root. Same idea as the
#sphere-vs-AABB test in C. Ericson, "Real-Time Collision Detection", ch. 5, plus a height check. Adapted and
#written by the team; Godot does not take part here
func contact(point: Vector3, radius: float, body_height: float) -> bool:
	if point.y >= position.y + height - 0.05 or point.y + body_height <= position.y + 0.02:
		return false
	var gap_x := maxf(absf(point.x - position.x) - half_extents.x, 0.0)
	var gap_z := maxf(absf(point.z - position.z) - half_extents.y, 0.0)
	return gap_x * gap_x + gap_z * gap_z <= radius * radius


#The jolt of a vehicle that just hit something: it squashes along its way and springs back
func react() -> void:
	if _react != null and _react.is_valid():
		_react.kill()
	_visual.scale = Vector3(0.9, 1.04, 1.0)
	_visual.rotation.z = 0.05 if kind != Kind.PEDESTRIAN else 0.0
	_react = create_tween().set_parallel(true).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_react.tween_property(_visual, "scale", Vector3.ONE, 0.45)
	_react.tween_property(_visual, "rotation:z", 0.0, 0.45)


func _set_kind(value: Kind) -> void:
	kind = value
	match kind:
		Kind.CAR:
			stun = 0.7
			flips = true
			strength = 0.85
		Kind.TANK:
			stun = 0.8
			flips = true
			strength = 1.0
		Kind.CYCLIST:
			stun = 0.55
			flips = true
			strength = 0.6
		Kind.CONE:
			stun = 0.22
			strength = 0.25
		Kind.PEDESTRIAN:
			stun = 0.3
			strength = 0.4


#Takes the model made by PropKit: its real size is the hit box; returns that size
func _adopt(model: Node3D) -> AABB:
	var box := PropKit.measure(model)
	half_extents = Vector2(box.size.x, box.size.z) * HIT_FORGIVENESS / 2.0
	height = box.size.y
	#The models come facing -X, so they are turned to drive toward +X
	model.rotation.y = PI
	_visual.add_child(model)
	return box


#Seats and a dashboard, so the inside of the car does not look empty through the glass; one mesh per kind of car
func _furnish(model_id: StringName, box: AABB) -> void:
	if not SEATS.has(model_id):
		return
	if not _interiors.has(model_id):
		var layout: Dictionary = SEATS[model_id]
		var seats: Array = layout["seats"]
		var surface := SurfaceTool.new()
		var cushion := BoxMesh.new()
		cushion.size = Vector3(0.62, 0.16, 0.7)
		var back := BoxMesh.new()
		back.size = Vector3(0.14, 0.62, 0.7)
		var dash := BoxMesh.new()
		dash.size = Vector3(0.4, 0.26, box.size.z * 0.55)
		for seat: Vector3 in seats:
			var at := Vector3(seat.x * box.size.x, seat.y * box.size.y, seat.z * box.size.z)
			surface.append_from(cushion, 0, Transform3D(Basis.IDENTITY, at + Vector3(0.0, -0.16, 0.0)))
			surface.append_from(back, 0, Transform3D(Basis.IDENTITY, at + Vector3(-0.34, 0.2, 0.0)))
		var front: Vector3 = seats[0]
		surface.append_from(dash, 0, Transform3D(Basis.IDENTITY, Vector3(front.x * box.size.x + 0.4, front.y * box.size.y + 0.08, 0.0)))
		_interiors[model_id] = surface.commit()
	if _seat_material == null:
		_seat_material = StandardMaterial3D.new()
		_seat_material.albedo_color = SEAT_COLOR
		_seat_material.roughness = 0.8
	var interior := MeshInstance3D.new()
	interior.mesh = _interiors[model_id]
	interior.material_override = _seat_material
	interior.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(interior)


#The driver always rides; the other seats fill up at random. They face where the car goes and look at their phones
func _seat_people(model_id: StringName, box: AABB, rng: RandomNumberGenerator) -> void:
	if not SEATS.has(model_id):
		return
	var layout: Dictionary = SEATS[model_id]
	var seats: Array = layout["seats"]
	var size: float = layout["size"]
	for index in seats.size():
		if index > 0 and rng.randf() > SEAT_TAKEN_CHANCE:
			continue
		var seat: Vector3 = seats[index]
		var person := Citizen.new()
		person.build(Citizen.Pose.SIT, rng, rng.randf())
		person.scale = Vector3.ONE * size
		person.rotation.y = PI / 2.0
		person.position = Vector3(seat.x * box.size.x, seat.y * box.size.y - SEATED_HIPS * size, seat.z * box.size.z)
		_visual.add_child(person)
		_limit_view(person, PASSENGER_DRAW_DISTANCE)


#The far ones are not drawn and none casts a shadow
func _limit_view(person: Citizen, distance: float) -> void:
	for mesh in person.meshes():
		mesh.visibility_range_end = distance
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
