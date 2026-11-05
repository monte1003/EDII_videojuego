class_name BalloonField
extends Node3D

#Balloons tied to the ground that sway in the wind: one draw call for the balloons and one for the strings of each stretch of the course

const STRING_RADIUS := 0.014
const SWAY := 0.9

var _ties: Array[Dictionary] = []
var _cells: Array[Dictionary] = []
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
	var bases: Array[Vector3] = []
	for tie in _ties:
		bases.append(tie["base"])
	var groups := MeshMerger.cells(bases)
	for cell: int in groups:
		var members: Array[int] = groups[cell]
		var balloons := _multi(balloon_mesh, true, members.size())
		var strings := _multi(string_mesh, false, members.size())
		for slot in members.size():
			balloons.set_instance_color(slot, _ties[members[slot]]["color"])
		var entry := {"balloons": balloons, "strings": strings, "members": members}
		_cells.append(entry)
		_place(entry)


func _process(delta: float) -> void:
	_clock += delta
	for entry in _cells:
		_place(entry)


func _multi(mesh: Mesh, colors: bool, count: int) -> MultiMesh:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = colors
	multi.mesh = mesh
	multi.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return multi


#The balloon floats over its tie and leans with the wind; the string goes from the tie to the knot
func _place(entry: Dictionary) -> void:
	var balloons: MultiMesh = entry["balloons"]
	var strings: MultiMesh = entry["strings"]
	var members: Array[int] = entry["members"]
	for slot in members.size():
		var tie := _ties[members[slot]]
		var base: Vector3 = tie["base"]
		var length: float = tie["length"]
		var size: float = tie["size"]
		var wave: float = _clock * 0.8 + tie["phase"]
		var knot := base + Vector3(sin(wave) * SWAY, length + sin(wave * 1.3) * 0.25, cos(wave * 0.9) * SWAY * 0.7)
		balloons.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), knot + Vector3(0.0, 0.6 * size, 0.0)))
		strings.set_instance_transform(slot, PartyKit.stretch(base, knot))
