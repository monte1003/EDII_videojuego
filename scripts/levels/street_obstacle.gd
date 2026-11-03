class_name StreetObstacle
extends Node3D

#A vehicle, cone or pedestrian of the street minigame; the hit box is measured from the model it shows

enum Kind { CAR, PEDESTRIAN, TANK, CYCLIST, CONE }

#The hit box is this share of the model, so a near miss feels fair and a hit always shows
const HIT_FORGIVENESS := 0.94
#Seconds a new obstacle takes to pop in at the edge of the street
const POP_IN_TIME := 0.4
#Pedestrians walk, they do not run; the stride is matched to the speed they cross at
const WALK_ANIMATION_PER_MPS := 0.55
const PEDESTRIAN_SCALE := 0.95
const PEDESTRIAN_HALF := Vector2(0.34, 0.34)
const HEAVY_HALF := Vector2(0.46, 0.4)
const PEDESTRIAN_HEIGHT := 1.7
const CONE_HEIGHT := 0.8
#A pedestrian model has about 30,000 triangles, so the ones far from the camera are not drawn and none casts a shadow
const WALKER_DRAW_DISTANCE := 38.0
#The figures of Axel come as plain white models, so each gets clothes: legs, body and head colours
const TROUSERS: Array[Color] = [Color("3d3a6e"), Color("4a4f7a"), Color("2f2d4f"), Color("5a4a7a")]
const SHIRTS: Array[Color] = [Color("ff6f7d"), Color("ffb347"), Color("ff8fc0"), Color("ffd95a"), Color("ff9a6b")]
const SKINS: Array[Color] = [Color("f5c6a5"), Color("d9a074"), Color("b9794f"), Color("ffd9bf"), Color("8d5a3b")]
const BIKE_DARK := Color("2c2a4a")
const HELMET := Color("ffd95a")

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
var _walker: AnimationPlayer
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


#A hatchback, a minibus or a micro car driving toward +X; "color" tints the cream body
func build_car(model_id: StringName, color: Color, length: float) -> void:
	_set_kind(Kind.CAR)
	_adopt(PropKit.make_long(model_id, length, color))


#Rare obstacle as wide as two lanes; its cannon points +X, the way it goes
func build_tank(length: float, width: float) -> void:
	_set_kind(Kind.TANK)
	_adopt(PropKit.make(&"tank", Vector3(length, 0.0, width * 0.93)))


#A delivery rider that weaves a little inside its lane
func build_cyclist(length: float) -> void:
	_set_kind(Kind.CYCLIST)
	var rider := PropKit.make_long(&"cyclist", length)
	PropKit.dress(rider, BIKE_DARK, SHIRTS[randi() % SHIRTS.size()], HELMET, 0.45, 0.86)
	_adopt(rider)
	_sway = 0.4
	_sway_rate = 2.6


#A traffic cone riding the belt: low enough to jump over
func build_cone() -> void:
	_set_kind(Kind.CONE)
	_adopt(PropKit.make_tall(&"cone", CONE_HEIGHT))


#A walker that looks at its phone; the model faces +Z, so it is turned to walk toward +X like the cars
func build_pedestrian(model_scene: PackedScene, heavy: bool) -> void:
	_set_kind(Kind.PEDESTRIAN)
	var model := model_scene.instantiate() as Node3D
	model.rotation.y = PI / 2.0
	model.scale = Vector3.ONE * PEDESTRIAN_SCALE
	PropKit.dress(model, TROUSERS[randi() % TROUSERS.size()], SHIRTS[randi() % SHIRTS.size()], SKINS[randi() % SKINS.size()])
	_visual.add_child(model)
	half_extents = HEAVY_HALF if heavy else PEDESTRIAN_HALF
	height = PEDESTRIAN_HEIGHT
	_sway = 0.5
	_sway_rate = 1.1
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).visibility_range_end = WALKER_DRAW_DISTANCE
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_walker = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _walker == null:
		return
	for clip_name in _walker.get_animation_list():
		if clip_name != &"RESET":
			_walker.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
			_walker.play(clip_name)
			_walker.seek(randf() * _walker.current_animation_length)
			break


#Drives forward at "flow" times its own speed and keeps its weave; pedestrians and riders sway across their row
func advance(delta: float, flow: float) -> void:
	_clock += delta
	position.x += base_speed * flow * delta
	if _walker != null:
		_walker.speed_scale = base_speed * flow * WALK_ANIMATION_PER_MPS
	if _sway > 0.0:
		position.z = _anchor_z + sin(_clock * _sway_rate) * _sway
	if kind == Kind.CYCLIST:
		_visual.rotation.x = cos(_clock * _sway_rate) * 0.07


#True when a body standing at "point" (its feet) with a round footprint of "radius" and "body_height" touches the hit box
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


#Takes the model made by PropKit: its real size is the hit box
func _adopt(model: Node3D) -> void:
	var box := PropKit.measure(model)
	half_extents = Vector2(box.size.x, box.size.z) * HIT_FORGIVENESS / 2.0
	height = box.size.y
	#The models come facing -X, so they are turned to drive toward +X
	model.rotation.y = PI
	_visual.add_child(model)
