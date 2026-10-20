class_name StreetObstacle
extends Node3D

#A car, tank or pedestrian of the street minigame; cars and the tank are drawn with primitives, pedestrians use the bot models

enum Kind { CAR, PEDESTRIAN, TANK }

const GLASS_COLOR := Color("34416f")
const TIRE_COLOR := Color("23242f")
const HUB_COLOR := Color("d9dbe8")
const HEADLIGHT_COLOR := Color("fff3b0")
const TAILLIGHT_COLOR := Color("ff5c7a")
#Pedestrians walk, they do not run like the bots do
const WALK_ANIMATION_SCALE := 1.05
#The bot models are small next to the runner and this keeps the sidewalk crowd readable
const PEDESTRIAN_SCALE := 1.7

static var _materials: Dictionary = {}

var kind := Kind.CAR
var base_speed := 0.0
#Half size of the footprint on the XZ plane, used by the hit test
var half_extents := Vector2.ZERO
#Speed the runner is thrown back with when this obstacle hits it
var knockback := 0.0

var _walker: BotLook


func _ready() -> void:
	if _walker != null:
		_walker.set_moving(true)


#Hatchback that drives toward +X: low body, tapered glass cabin, wheels and lights
func build_car(color: Color, length: float, width: float) -> void:
	kind = Kind.CAR
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


#The model faces +Z, so it is turned to walk toward +X like the cars
func build_pedestrian(model_scene: PackedScene, radius: float) -> void:
	kind = Kind.PEDESTRIAN
	half_extents = Vector2(radius, radius)
	var model := model_scene.instantiate() as BotLook
	if model == null:
		push_error("StreetObstacle: el modelo del peatón no es un BotLook")
		return
	if model is BotModel:
		(model as BotModel).run_speed_scale = WALK_ANIMATION_SCALE
	model.rotation.y = PI / 2.0
	model.scale = Vector3.ONE * PEDESTRIAN_SCALE
	add_child(model)
	_walker = model


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


func _material(color: Color, glow: bool) -> StandardMaterial3D:
	var key := "%s%s" % [color.to_html(), glow]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.8
	_materials[key] = material
	return material
