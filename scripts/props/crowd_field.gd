class_name CrowdField
extends Node3D

#A crowd of cheering beans in a single draw call: add every place, then commit once

const SHADER: Shader = preload("res://assets/shaders/crowd_bob.gdshader")
const BODY_RADIUS := 0.3
const BODY_HEIGHT := 1.0
const FAN_COLORS: Array[Color] = [
	Color("ff6b8b"), Color("ffcf4a"), Color("4fd6e8"), Color("8e6bff"), Color("6ee7a5"), Color("ff9a5c"), Color("fdfbff"),
]

var _spots: Array[Transform3D] = []
var _colors: Array[Color] = []
var _material: ShaderMaterial


#A fan standing at "at", looking where "yaw" says (0 looks toward +Z), "size" times the normal height
func add_fan(at: Vector3, yaw: float, size: float, color: Color) -> void:
	_spots.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), at))
	_colors.append(color)


#The whole crowd jumps higher while "amount" is above 1
func set_excitement(amount: float) -> void:
	if _material != null:
		_material.set_shader_parameter("excitement", amount)


func commit() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _fan_mesh(_material)
	multi.instance_count = _spots.size()
	for index in _spots.size():
		multi.set_instance_transform(index, _spots[index])
		multi.set_instance_color(index, _colors[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


#A bean with its arms up and two dark eyes: the body and the arms take the colour of each fan, the eyes stay dark
func _fan_mesh(body_material: Material) -> ArrayMesh:
	var capsule := CapsuleMesh.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	capsule.radial_segments = 8
	capsule.rings = 2
	var arm := CapsuleMesh.new()
	arm.radius = 0.075
	arm.height = 0.5
	arm.radial_segments = 4
	arm.rings = 1
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	body.append_from(capsule, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, BODY_HEIGHT / 2.0, 0.0)))
	for side: float in [-1.0, 1.0]:
		body.append_from(arm, 0, Transform3D(Basis(Vector3.BACK, side * deg_to_rad(28.0)), Vector3(side * 0.37, 0.95, 0.0)))
	var eye := SphereMesh.new()
	eye.radius = 0.055
	eye.height = 0.11
	eye.radial_segments = 4
	eye.rings = 2
	var eyes := SurfaceTool.new()
	eyes.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		eyes.append_from(eye, 0, Transform3D(Basis.IDENTITY, Vector3(side * 0.11, 0.72, BODY_RADIUS - 0.03)))
	var mesh := ArrayMesh.new()
	body.commit(mesh)
	eyes.commit(mesh)
	mesh.surface_set_material(0, body_material)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2a2145")
	dark.roughness = 0.5
	mesh.surface_set_material(1, dark)
	return mesh
