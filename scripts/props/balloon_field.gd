class_name BalloonField
extends Node3D

#Balloons tied to the ground that sway in the wind: every balloon is one draw call and every string another

const STRING_RADIUS := 0.014
const SWAY := 0.9

var _ties: Array[Dictionary] = []
var _balloons: MultiMesh
var _strings: MultiMesh
var _clock := 0.0


#A balloon tied at "base", its string "length" long, "size" times the normal balloon
func add(base: Vector3, length: float, size: float, color: Color, phase: float) -> void:
	_ties.append({"base": base, "length": length, "size": size, "color": color, "phase": phase})


func commit() -> void:
	var balloon_mesh := SphereMesh.new()
	balloon_mesh.radius = 0.5
	balloon_mesh.height = 1.2
	balloon_mesh.radial_segments = 14
	balloon_mesh.rings = 8
	var shine := StandardMaterial3D.new()
	shine.vertex_color_use_as_albedo = true
	shine.roughness = 0.22
	shine.metallic_specular = 0.9
	balloon_mesh.material = shine
	_balloons = _multi(balloon_mesh, true)
	var string_mesh := CylinderMesh.new()
	string_mesh.top_radius = STRING_RADIUS
	string_mesh.bottom_radius = STRING_RADIUS
	string_mesh.height = 1.0
	string_mesh.radial_segments = 4
	string_mesh.rings = 1
	var cord := StandardMaterial3D.new()
	cord.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cord.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
	string_mesh.material = cord
	_strings = _multi(string_mesh, false)
	for index in _ties.size():
		_balloons.set_instance_color(index, _ties[index]["color"])
	_place()


func _process(delta: float) -> void:
	_clock += delta
	if _balloons != null:
		_place()


func _multi(mesh: Mesh, colors: bool) -> MultiMesh:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = colors
	multi.mesh = mesh
	multi.instance_count = _ties.size()
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return multi


#The balloon floats over its tie and leans with the wind; the string goes from the tie to the knot
func _place() -> void:
	for index in _ties.size():
		var tie := _ties[index]
		var base: Vector3 = tie["base"]
		var length: float = tie["length"]
		var size: float = tie["size"]
		var wave: float = _clock * 0.8 + tie["phase"]
		var knot := base + Vector3(sin(wave) * SWAY, length + sin(wave * 1.3) * 0.25, cos(wave * 0.9) * SWAY * 0.7)
		_balloons.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), knot + Vector3(0.0, 0.6 * size, 0.0)))
		_strings.set_instance_transform(index, PartyKit.stretch(base, knot))
