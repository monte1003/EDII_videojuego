class_name MeshMerger
extends RefCounted

#Joins static pieces into one mesh per stretch and material; nothing is hidden by distance

const CELL := 60.0

#"stretch|name" -> {"tool", "material", "shadow"}
var _parts: Dictionary = {}


#Positions grouped in stretches along Z
static func cells(points: Array[Vector3], size := CELL) -> Dictionary:
	var found: Dictionary = {}
	for index in points.size():
		var cell := floori(points[index].z / size)
		if not found.has(cell):
			found[cell] = [] as Array[int]
		(found[cell] as Array[int]).append(index)
	return found


#Adds a placed and coloured copy of "mesh"; "cell_z" puts a mesh drawn in place in its real stretch
func add(name: StringName, material: Material, shadow: bool, mesh: Mesh, place: Transform3D, color: Color, uv_scale := Vector2.ONE, cell_z := NAN) -> void:
	var key := "%d|%s" % [floori((place.origin.z if is_nan(cell_z) else cell_z) / CELL), name]
	if not _parts.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_parts[key] = {"tool": tool, "material": material, "shadow": shadow}
	var tool: SurfaceTool = _parts[key]["tool"]
	var normals := place.basis.inverse().transposed()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var shades: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var coords: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := order.size() if order.size() > 0 else vertices.size()
		for step in count:
			var index := order[step] if order.size() > 0 else step
			tool.set_color(color)
			tool.set_normal((normals * shades[index]).normalized())
			if index < coords.size():
				tool.set_uv(coords[index] * uv_scale)
			tool.add_vertex(place * vertices[index])


#One mesh per stretch and material under "parent"
func commit(parent: Node3D) -> void:
	for key: String in _parts:
		var part: Dictionary = _parts[key]
		var instance := MeshInstance3D.new()
		instance.mesh = (part["tool"] as SurfaceTool).commit()
		instance.material_override = part["material"]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if part["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
	_parts.clear()
