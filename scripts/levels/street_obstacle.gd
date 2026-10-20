class_name StreetObstacle
extends Node3D

#A car, tank, pedestrian or cyclist of the street minigame. Tanks are placeholder
#primitives; the others use a model when there is one. The game only reads the numbers
#below, so a model can replace the look without touching the rules.

enum Kind { CAR, PEDESTRIAN, TANK, CYCLIST }

#Meters walked per step of the bob of the capsule that stands in when there is no model
const STEP_LENGTH := 0.7
const BOB_HEIGHT := 0.05
const BOB_SWAY := 0.05
#The walk animation is sped up to follow faster pedestrians, but only this much
const MAX_ANIMATION_SPEED := 2.5
#Phone held in the right hand, in meters. A bit big so it reads from the game camera.
#On Meshy's skeletons the hand bone's +Y points to the fingers and +Z out of the back of the
#hand, so the phone sits on the palm side (-Z) with its screen facing away from the palm
const PHONE_BONE := &"RightHand"
const PHONE_SIZE := Vector3(0.1, 0.18, 0.016)
const PHONE_OFFSET := Vector3(0.0, 0.04, -0.022)
const PHONE_BODY := Color("23212b")
const PHONE_SCREEN := Color("8fd3ff")
#Both hands hold the phone: the left wrist goes here, from the phone's centre, in the right
#hand bone's axes (meters)
const LEFT_GRIP_OFFSET := Vector3(0.11, -0.04, -0.05)
#Delivery box on the cyclist's rear rack, as fractions of the bike's length: centre behind
#the middle, height of the rack, and size (along, up, across)
const BOX_CENTER_BACK := 0.34
const BOX_RACK_HEIGHT := 0.41
const BOX_SIZE := Vector3(0.21, 0.22, 0.23)
const BOX_COLOR := Color("ffd23f")
const BOX_TEXT := "Didi"
const BOX_TEXT_COLOR := Color("e0561b")
const BOX_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
#How far a cyclist tilts into a change of side, in radians
const MAX_LEAN := 0.18
#Bot models as pedestrians: they are small next to the runner, and they walk, not run
const BOT_PEDESTRIAN_SCALE := 1.7
const BOT_WALK_ANIMATION_SCALE := 1.05
#Colours of the primitive hatchback used when there is no car model
const GLASS_COLOR := Color("34416f")
const TIRE_COLOR := Color("23242f")
const HUB_COLOR := Color("d9dbe8")
const HEADLIGHT_COLOR := Color("fff3b0")
const TAILLIGHT_COLOR := Color("ff5c7a")

static var _phone_body_material: StandardMaterial3D
static var _phone_screen_material: StandardMaterial3D
#Tinted copies of the car model's materials, one per material and colour
static var _car_materials: Dictionary = {}

var kind := Kind.CAR
var base_speed := 0.0
#Half size of the footprint on the XZ plane, used by the hit test
var half_extents := Vector2.ZERO
#Speed the runner is thrown back with when this obstacle hits it
var knockback := 0.0
#Centre of the sidewalk a pedestrian or cyclist goes along, and the Z a cyclist steers to
var lane_z := 0.0
var target_z := 0.0
#Speed it moved at in the last frame (a cyclist goes slower than its base behind someone)
var current_speed := 0.0

var _walked := 0.0
var _phase := 0.0
var _visual: Node3D
var _animation_player: AnimationPlayer
#A bot model walking the sidewalk; it animates itself
var _walker: BotLook
#Meters per second the walk animation covers when it plays at normal speed
var _animation_walk_speed := 1.0


#"model" is scaled to "length", stands on the ground and faces +X (the car model faces -X).
#Its body is white, so multiplying the texture by "color" paints the body and leaves the
#windows, tyres and lights dark. The hit box is the scaled model's footprint. Without a
#model a primitive hatchback of "length" by "width" stands in: low body, tapered glass
#cabin, wheels and lights
func build_car(model: PackedScene, color: Color, length: float, width: float) -> void:
	kind = Kind.CAR
	if model != null:
		var instance := model.instantiate() as Node3D
		_visual = Node3D.new()
		_visual.rotation.y = PI
		add_child(_visual)
		_visual.add_child(instance)
		var bounds := _bounds_of(instance)
		var size := length / maxf(bounds.size.x, 0.01)
		instance.scale = Vector3.ONE * size
		var centre := bounds.get_center()
		instance.position = Vector3(-centre.x, -bounds.position.y, -centre.z) * size
		half_extents = Vector2(bounds.size.x, bounds.size.z) * size / 2.0
		for node in instance.find_children("*", "MeshInstance3D", true, false):
			_tint(node as MeshInstance3D, color)
		return
	half_extents = Vector2(length, width) / 2.0
	var cabin_x := -length * 0.07
	_add_box(Vector3(0.0, 0.34, 0.0), Vector3(length * 0.98, 0.3, width * 0.94), color.darkened(0.4))
	_add_box(Vector3(0.0, 0.7, 0.0), Vector3(length, 0.55, width), color)
	_add_box(Vector3(length * 0.5 - 0.1, 0.62, 0.0), Vector3(0.22, 0.2, width * 0.98), color.lightened(0.18))
	_add_mesh(_frustum(Vector2(length * 0.56, width * 0.86), Vector2(length * 0.36, width * 0.7), 0.58),
		Vector3(cabin_x, 0.98, 0.0), GLASS_COLOR)
	_add_box(Vector3(cabin_x - length * 0.01, 1.58, 0.0), Vector3(length * 0.38, 0.08, width * 0.72), color.lightened(0.3))
	for side in [-1.0, 1.0]:
		_add_wheel(Vector3(length * 0.3, 0.42, side * (width / 2.0 - 0.08)), side)
		_add_wheel(Vector3(-length * 0.3, 0.42, side * (width / 2.0 - 0.08)), side)
		_add_box(Vector3(length / 2.0 + 0.02, 0.74, side * width * 0.3), Vector3(0.08, 0.2, 0.46), HEADLIGHT_COLOR, true)
		_add_box(Vector3(-length / 2.0 - 0.02, 0.74, side * width * 0.3), Vector3(0.08, 0.18, 0.4), TAILLIGHT_COLOR, true)


#Rare obstacle as wide as two lanes; its gun points +X, the way it goes
func build_tank(length: float, width: float) -> void:
	kind = Kind.TANK
	half_extents = Vector2(length, width) / 2.0
	var hull := Color("5b6b3a")
	var track := Color("2f3326")
	for side in [-1.0, 1.0]:
		_add_box(Vector3(0.0, 0.45, side * (width / 2.0 - 0.45)), Vector3(length, 0.9, 0.9), track)
	_add_box(Vector3(0.0, 1.05, 0.0), Vector3(length * 0.92, 0.7, width - 1.0), hull)
	_add_box(Vector3(-length * 0.08, 1.75, 0.0), Vector3(length * 0.42, 0.7, width * 0.5), hull.lightened(0.15))
	_add_box(Vector3(length * 0.32, 1.8, 0.0), Vector3(length * 0.5, 0.22, 0.22), track)


#"model" is scaled to "height", stands on the ground and faces +X (the models face +Z).
#Every surface gets "material", one flat colour. If the model has an animation it loops,
#starting at a random point so pedestrians do not walk in step. Without a model a capsule
#stands in. "half_size" is the hit box: x along the street (the stride), y across it (the
#shoulders); the model's own bounds are useless here because its rest pose has the arms open.
#A bot model (BotLook) keeps its own colours, size and animations instead
func build_pedestrian(model: PackedScene, material: Material, half_size: Vector2, height: float,
		animation_walk_speed: float) -> void:
	kind = Kind.PEDESTRIAN
	half_extents = half_size
	_visual = Node3D.new()
	add_child(_visual)
	_phase = randf() * TAU
	if model == null:
		var mesh := CapsuleMesh.new()
		mesh.radius = half_size.y
		mesh.height = height
		var capsule := MeshInstance3D.new()
		capsule.mesh = mesh
		capsule.material_override = material
		capsule.position.y = height / 2.0
		_visual.add_child(capsule)
		return

	var instance := model.instantiate() as Node3D
	_visual.add_child(instance)
	_visual.rotation.y = PI / 2.0
	if instance is BotLook:
		_setup_bot_walker(instance as BotLook)
		return
	var bounds := _bounds_of(instance)
	var size := height / maxf(bounds.size.y, 0.01)
	instance.scale = Vector3.ONE * size
	var centre := bounds.get_center()
	instance.position = Vector3(-centre.x, -bounds.position.y, -centre.z) * size
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = material
	_attach_phone(instance)

	var players := instance.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_animation_player = players[0] as AnimationPlayer
	_animation_walk_speed = animation_walk_speed
	var animation_name: StringName = _animation_player.get_animation_list()[0]
	var animation := _animation_player.get_animation(animation_name)
	animation.loop_mode = Animation.LOOP_LINEAR
	_animation_player.play(animation_name)
	_animation_player.seek(randf() * animation.length, true)


#The bot models keep their own colours and size and play their run slowed to a walk
func _setup_bot_walker(bot: BotLook) -> void:
	if bot is BotModel:
		(bot as BotModel).run_speed_scale = BOT_WALK_ANIMATION_SCALE
	bot.scale = Vector3.ONE * BOT_PEDESTRIAN_SCALE
	_walker = bot


func _ready() -> void:
	if _walker != null:
		_walker.set_moving(true)


#"model" is scaled to "length", stands on the ground and faces +X (the bike model faces -X).
#Rider and bike get "material", one flat colour like the pedestrians; a yellow delivery box
#with the brand on its sides sits on the rear rack. The hit box is the scaled model's
#footprint. Without a model a flat box stands in
func build_cyclist(model: PackedScene, material: Material, length: float) -> void:
	kind = Kind.CYCLIST
	_visual = Node3D.new()
	add_child(_visual)
	if model == null:
		half_extents = Vector2(length / 2.0, 0.3)
		var placeholder := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(length, length * 0.6, 0.4)
		placeholder.mesh = mesh
		placeholder.material_override = material
		placeholder.position.y = length * 0.3
		_visual.add_child(placeholder)
	else:
		var holder := Node3D.new()
		holder.rotation.y = PI
		_visual.add_child(holder)
		var instance := model.instantiate() as Node3D
		holder.add_child(instance)
		var bounds := _bounds_of(instance)
		var size := length / maxf(bounds.size.x, 0.01)
		instance.scale = Vector3.ONE * size
		var centre := bounds.get_center()
		instance.position = Vector3(-centre.x, -bounds.position.y, -centre.z) * size
		half_extents = Vector2(bounds.size.x, bounds.size.z) * size / 2.0
		for node in instance.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = material
	_add_delivery_box(length)


#Tilts the cyclist toward the side it is moving to (direction -1, 0 or 1 on Z)
func lean(direction: float, delta: float) -> void:
	if _visual:
		_visual.rotation.x = lerpf(_visual.rotation.x, direction * MAX_LEAN, 1.0 - exp(-8.0 * delta))


#Moves along the street at "speed". The walk animation follows the speed; the capsule
#bobs per meter walked
func advance(speed: float, delta: float) -> void:
	var distance := speed * delta
	position.x += distance
	if kind != Kind.PEDESTRIAN or _walker != null:
		return
	if _animation_player:
		_animation_player.speed_scale = clampf(speed / _animation_walk_speed, 0.5, MAX_ANIMATION_SPEED)
		return
	_walked += distance
	var step := _walked / STEP_LENGTH * PI + _phase
	_visual.position.y = absf(sin(step)) * BOB_HEIGHT
	_visual.rotation.x = sin(step) * BOB_SWAY


func overlaps(point: Vector3, radius: float) -> bool:
	return absf(point.x - position.x) <= half_extents.x + radius \
		and absf(point.z - position.z) <= half_extents.y + radius


func _add_box(center: Vector3, size: Vector3, color: Color, glow := false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add_mesh(mesh, center, color, glow)


func _add_mesh(mesh: Mesh, center: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, glow)
	instance.position = center
	add_child(instance)
	return instance


#Wheel with its hub; "side" is the side of the car (-1 or 1) so the hub shows outward
func _add_wheel(center: Vector3, side: float) -> void:
	var tire := CylinderMesh.new()
	tire.top_radius = 0.42
	tire.bottom_radius = 0.42
	tire.height = 0.34
	tire.radial_segments = 14
	tire.rings = 1
	var wheel := _add_mesh(tire, center, TIRE_COLOR)
	wheel.rotation.x = PI / 2.0
	var hub := CylinderMesh.new()
	hub.top_radius = 0.2
	hub.bottom_radius = 0.2
	hub.height = 0.05
	hub.radial_segments = 10
	hub.rings = 1
	var cap := _add_mesh(hub, center + Vector3(0.0, 0.0, side * 0.18), HUB_COLOR)
	cap.rotation.x = PI / 2.0


#Box that is narrower at the top: bottom and top are (length, width) on the XZ plane
func _frustum(bottom: Vector2, top: Vector2, height: float) -> ArrayMesh:
	var low := [Vector3(-bottom.x / 2.0, 0.0, -bottom.y / 2.0), Vector3(bottom.x / 2.0, 0.0, -bottom.y / 2.0),
		Vector3(bottom.x / 2.0, 0.0, bottom.y / 2.0), Vector3(-bottom.x / 2.0, 0.0, bottom.y / 2.0)]
	var high := [Vector3(-top.x / 2.0, height, -top.y / 2.0), Vector3(top.x / 2.0, height, -top.y / 2.0),
		Vector3(top.x / 2.0, height, top.y / 2.0), Vector3(-top.x / 2.0, height, top.y / 2.0)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0.0, height / 2.0, 0.0)
	for index in 4:
		var next := (index + 1) % 4
		_quad(tool, low[index], low[next], high[next], high[index], center)
	_quad(tool, high[0], high[1], high[2], high[3], center)
	tool.generate_normals()
	return tool.commit()


#Godot front faces are clockwise seen from outside; "center" tells which way is out
func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, center: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	var outward := (a + b + c + d) / 4.0 - center
	var corners := [a, b, c, d]
	if normal.dot(outward) > 0.0:
		corners = [a, d, c, b]
	for index in [0, 1, 2, 0, 2, 3]:
		tool.add_vertex(corners[index])


func _add_delivery_box(length: float) -> void:
	var size := BOX_SIZE * length
	var centre := Vector3(-BOX_CENTER_BACK * length, BOX_RACK_HEIGHT * length + size.y / 2.0, 0.0)
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = _material(BOX_COLOR)
	box.position = centre
	_visual.add_child(box)
	#The brand on both sides and on the back; a Label3D faces +Z unless turned
	for face: Array in [[Vector3(0, 0, size.z / 2.0), 0.0], [Vector3(0, 0, -size.z / 2.0), PI],
			[Vector3(-size.x / 2.0, 0, 0), -PI / 2.0]]:
		var label := Label3D.new()
		label.text = BOX_TEXT
		label.font = BOX_FONT
		label.font_size = 64
		label.pixel_size = size.x * 0.0058
		label.modulate = BOX_TEXT_COLOR
		label.outline_size = 0
		label.double_sided = false
		label.position = centre + face[0] * 1.02
		label.rotation.y = face[1]
		_visual.add_child(label)


#Puts a phone in the right hand; models without that bone simply have none
func _attach_phone(model: Node3D) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	if skeleton.find_bone(PHONE_BONE) < 0:
		return
	if _phone_body_material == null:
		_phone_body_material = _material(PHONE_BODY)
		_phone_screen_material = _material(PHONE_SCREEN)
		_phone_screen_material.emission_enabled = true
		_phone_screen_material.emission = PHONE_SCREEN
		_phone_screen_material.emission_energy_multiplier = 0.6

	#Bone space can be in other units (Meshy's skeletons are in cm): undo its scale
	var skeleton_scale := 1.0
	var current: Node = skeleton
	while current != model and current is Node3D:
		skeleton_scale *= (current as Node3D).scale.x
		current = current.get_parent()
	#The walk carries the hands palm down and apart; the grip turns them up and brings the
	#left hand to the phone, which hangs from the right hand
	var grip := PhoneGripModifier.new()
	grip.left_target_in_right_hand = (PHONE_OFFSET + LEFT_GRIP_OFFSET) / skeleton_scale
	skeleton.add_child(grip)
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = PHONE_BONE
	skeleton.add_child(attachment)
	var phone := Node3D.new()
	phone.scale = Vector3.ONE / skeleton_scale
	phone.position = PHONE_OFFSET / skeleton_scale
	attachment.add_child(phone)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = PHONE_SIZE
	body.mesh = body_mesh
	body.material_override = _phone_body_material
	phone.add_child(body)
	var screen := MeshInstance3D.new()
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(PHONE_SIZE.x * 0.88, PHONE_SIZE.y * 0.9, 0.002)
	screen.mesh = screen_mesh
	screen.material_override = _phone_screen_material
	screen.position.z = -PHONE_SIZE.z / 2.0 - 0.001
	phone.add_child(screen)


#Box of all the meshes under "root", in root's own space (works outside the scene tree)
func _bounds_of(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var to_root := Transform3D.IDENTITY
		#A skinned mesh is drawn by its skeleton: the node chain (like Meshy's Armature at
		#0.01 scale) does not apply, its vertices are already in the model's space
		var current: Node = mesh_instance if mesh_instance.skin == null else root
		while current != root and current is Node3D:
			to_root = (current as Node3D).transform * to_root
			current = current.get_parent()
		var box := to_root * mesh_instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _tint(mesh_instance: MeshInstance3D, color: Color) -> void:
	for surface in mesh_instance.mesh.get_surface_count():
		var base := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
		if base == null:
			continue
		var key := "%d_%s" % [base.get_instance_id(), color.to_html()]
		if not _car_materials.has(key):
			var tinted := base.duplicate() as BaseMaterial3D
			tinted.albedo_color = color
			_car_materials[key] = tinted
		mesh_instance.set_surface_override_material(surface, _car_materials[key])


func _material(color: Color, glow := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.8
	return material
