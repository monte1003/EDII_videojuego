class_name Level01Backdrop
extends Node3D

#Floating hearts, chat bubbles and typing bubbles around the islands: they give the level depth and its theme and never collide

const COUNT := 36
const COLORS: Array[Color] = [Color("ff8fb1"), Color("fdfbff"), Color("7fe3f0"), Color("c5b3f7"), Color("ffd27a")]
const HEART_POINTS := 40

var _items: Array[Dictionary] = []
var _materials: Dictionary = {}
var _clock := 0.0


func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var heart := _heart_mesh()
	for index in COUNT:
		var side := -1.0 if index % 2 == 0 else 1.0
		var at := Vector3(side * rng.randf_range(30.0, 82.0), rng.randf_range(-8.0, 24.0), rng.randf_range(-105.0, 22.0))
		var color := COLORS[rng.randi() % COLORS.size()]
		var item: Node3D
		match index % 3:
			0:
				item = _heart(heart, color)
			1:
				item = _bubble(color, false)
			_:
				item = _bubble(color, true)
		item.scale = Vector3.ONE * rng.randf_range(2.6, 6.5)
		item.position = at
		var yaw := atan2(-side, 0.8)
		item.rotation.y = yaw
		add_child(item)
		_items.append({"node": item, "base_y": at.y, "yaw": yaw, "phase": rng.randf() * TAU, "speed": rng.randf_range(0.35, 0.8)})


func _process(delta: float) -> void:
	_clock += delta
	for entry in _items:
		var node: Node3D = entry["node"]
		var wave: float = _clock * entry["speed"] + entry["phase"]
		node.position.y = entry["base_y"] + sin(wave) * 0.9
		node.rotation.y = entry["yaw"] + sin(wave * 0.7) * 0.22


func _heart(mesh: Mesh, color: Color) -> Node3D:
	var root := Node3D.new()
	_add(root, mesh, color, Vector3.ZERO)
	return root


#A speech bubble: a flat capsule with a corner tail; the typing one has three dots
func _bubble(color: Color, typing: bool) -> Node3D:
	var root := Node3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.45
	body.height = 1.9
	body.radial_segments = 20
	body.rings = 6
	var capsule := _add(root, body, color, Vector3.ZERO)
	capsule.rotation.z = PI / 2.0
	capsule.scale = Vector3(1.0, 1.0, 0.42)
	var tail := BoxMesh.new()
	tail.size = Vector3(0.42, 0.42, 0.2)
	var corner := _add(root, tail, color, Vector3(-0.55, -0.46, 0.0))
	corner.rotation.z = PI / 4.0
	if typing:
		var dot := SphereMesh.new()
		dot.radius = 0.1
		dot.height = 0.2
		dot.radial_segments = 10
		dot.rings = 5
		for step in [-1.0, 0.0, 1.0]:
			_add(root, dot, Color("6d55c2"), Vector3(step * 0.36, 0.0, 0.2))
	return root


func _add(parent: Node3D, mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.4
	_materials[key] = material
	return material


#A heart as a thin slab: the classic heart curve, closed with a fan on each face
func _heart_mesh() -> ArrayMesh:
	var outline: Array[Vector2] = []
	for index in HEART_POINTS:
		var t := TAU * index / HEART_POINTS
		outline.append(Vector2(
			16.0 * pow(sin(t), 3.0),
			13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t) + 1.5) / 32.0)
	var depth := 0.16
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var middle := Vector2(0.0, 0.05)
	for index in HEART_POINTS:
		var a := outline[index]
		var b := outline[(index + 1) % HEART_POINTS]
		_triangle(tool, Vector3(middle.x, middle.y, depth), Vector3(a.x, a.y, depth), Vector3(b.x, b.y, depth), Vector3(0, 0, 1))
		_triangle(tool, Vector3(middle.x, middle.y, -depth), Vector3(a.x, a.y, -depth), Vector3(b.x, b.y, -depth), Vector3(0, 0, -1))
		var out := Vector3((a.x + b.x) / 2.0 - middle.x, (a.y + b.y) / 2.0 - middle.y, 0.0)
		_triangle(tool, Vector3(a.x, a.y, depth), Vector3(a.x, a.y, -depth), Vector3(b.x, b.y, -depth), out)
		_triangle(tool, Vector3(a.x, a.y, depth), Vector3(b.x, b.y, -depth), Vector3(b.x, b.y, depth), out)
	tool.generate_normals()
	return tool.commit()


#Godot front faces are clockwise seen from outside; "outward" tells which way is out
func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var corners: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(outward) > 0.0:
		corners = [a, c, b]
	for corner in corners:
		tool.add_vertex(corner)
