class_name Bicycle
extends Node3D

#A chunky toy bicycle for the cyclists of the street, built to the size of a Citizen (about 1 m tall): it rolls toward +Z, its wheels
#spin with its speed and its frame has one bright colour

const WHEEL_RADIUS := 0.27
const TIRE_THICKNESS := 0.05
const AXLE_Y := 0.27
const WHEEL_BASE := 0.42
const TIRE_COLOR := Color("2b2547")
const RIM_COLOR := Color("fdfbff")

static var _materials: Dictionary = {}

var _wheels: Array[Node3D] = []


func build(frame_color: Color) -> void:
	var frame := _material(frame_color, 0.45)
	var steel := _material(Color("3b3560"), 0.5)
	var bottom := Vector3(0.0, 0.24, 0.0)
	var seat_top := Vector3(0.0, 0.5, -0.1)
	var head_top := Vector3(0.0, 0.56, 0.3)
	var head_bottom := Vector3(0.0, 0.44, 0.33)
	var rear := Vector3(0.0, AXLE_Y, -WHEEL_BASE)
	var front := Vector3(0.0, AXLE_Y, WHEEL_BASE)
	for part in [[bottom, seat_top], [seat_top, head_top], [bottom, head_bottom], [bottom, rear], [seat_top, rear]]:
		_tube(part[0], part[1], 0.026, frame)
	_tube(head_bottom, front, 0.022, steel)
	_tube(head_top, head_top + Vector3(0.0, 0.07, -0.03), 0.02, steel)
	var bars := head_top + Vector3(0.0, 0.07, -0.03)
	_tube(bars + Vector3(-0.2, 0.0, 0.0), bars + Vector3(0.2, 0.0, 0.0), 0.02, steel)
	for side in [-1.0, 1.0]:
		var grip := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.03
		cylinder.bottom_radius = 0.03
		cylinder.height = 0.08
		grip.mesh = cylinder
		grip.material_override = _material(TIRE_COLOR, 0.8)
		grip.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		grip.position = bars + Vector3(side * 0.22, 0.0, 0.0)
		add_child(grip)
	var saddle := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.14
	saddle.mesh = sphere
	saddle.material_override = _material(TIRE_COLOR, 0.7)
	saddle.scale = Vector3(0.9, 0.55, 1.5)
	saddle.position = seat_top + Vector3(0.0, 0.03, -0.02)
	add_child(saddle)
	var chainring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.07
	disc.bottom_radius = 0.07
	disc.height = 0.015
	chainring.mesh = disc
	chainring.material_override = steel
	chainring.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	chainring.position = bottom + Vector3(0.04, 0.0, 0.0)
	add_child(chainring)
	_wheels.append(_wheel(rear, frame_color))
	_wheels.append(_wheel(front, frame_color))
	for part in find_children("*", "MeshInstance3D", true, false):
		(part as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func roll(distance: float) -> void:
	for wheel in _wheels:
		wheel.rotation.x += distance / WHEEL_RADIUS


func _wheel(centre: Vector3, accent: Color) -> Node3D:
	var wheel := Node3D.new()
	wheel.position = centre
	add_child(wheel)
	var tire := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.outer_radius = WHEEL_RADIUS
	ring.inner_radius = WHEEL_RADIUS - TIRE_THICKNESS
	ring.rings = 20
	ring.ring_segments = 8
	tire.mesh = ring
	tire.material_override = _material(TIRE_COLOR, 0.85)
	tire.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	wheel.add_child(tire)
	#Three bars crossing at the hub, so the spin can be seen
	for angle in [0.0, 60.0, 120.0]:
		var spoke := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.022, (WHEEL_RADIUS - TIRE_THICKNESS) * 2.0, 0.03)
		spoke.mesh = box
		spoke.material_override = _material(RIM_COLOR, 0.5)
		spoke.rotation_degrees = Vector3(angle, 0.0, 0.0)
		wheel.add_child(spoke)
	var hub := MeshInstance3D.new()
	var cap := CylinderMesh.new()
	cap.top_radius = 0.05
	cap.bottom_radius = 0.05
	cap.height = 0.07
	hub.mesh = cap
	hub.material_override = _material(accent, 0.5)
	hub.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	wheel.add_child(hub)
	return wheel


func _tube(from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var length := from.distance_to(to)
	var tube := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = length + radius * 2.0
	capsule.radial_segments = 8
	capsule.rings = 2
	tube.mesh = capsule
	tube.material_override = material
	add_child(tube)
	tube.position = (from + to) / 2.0
	#A capsule stands on Y: its axis is turned to point from one end to the other
	var axis := (to - from) / maxf(length, 0.0001)
	tube.basis = Basis(Quaternion(Vector3.UP, axis))


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), roughness]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		_materials[key] = material
	return _materials[key]
