class_name StreetObstacle
extends Node3D

#A car or a pedestrian of the street minigame. The look is made of placeholder primitives
#until the final models arrive; the game only reads the numbers below, so a model can
#replace the look without touching the rules.

enum Kind { CAR, PEDESTRIAN, TANK }

var kind := Kind.CAR
var base_speed := 0.0
#Half size of the footprint on the XZ plane, used by the hit test
var half_extents := Vector2.ZERO
#Speed the runner is thrown back with when this obstacle hits it
var knockback := 0.0


func build_car(color: Color, length: float, width: float) -> void:
	kind = Kind.CAR
	half_extents = Vector2(length, width) / 2.0
	_add_box(Vector3(0.0, 0.55, 0.0), Vector3(length, 0.8, width), color)
	_add_box(Vector3(-length * 0.08, 1.25, 0.0), Vector3(length * 0.5, 0.6, width * 0.86), color.lightened(0.35))
	#Headlights on the +X side show which way the car is going
	_add_box(Vector3(length / 2.0, 0.6, 0.0), Vector3(0.08, 0.22, width * 0.7), Color("fff3b0"))


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


func build_pedestrian(color: Color, radius: float, height: float) -> void:
	kind = Kind.PEDESTRIAN
	half_extents = Vector2(radius, radius)
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position.y = height / 2.0
	add_child(instance)


func overlaps(point: Vector3, radius: float) -> bool:
	return absf(point.x - position.x) <= half_extents.x + radius \
		and absf(point.z - position.z) <= half_extents.y + radius


func _add_box(center: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = center
	add_child(instance)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
