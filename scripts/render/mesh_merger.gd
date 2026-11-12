class_name MeshMerger
extends RefCounted

#Joins many static pieces into one mesh per stretch of the course and per material: the very same picture with far fewer draw calls.
#Nothing is ever hidden because of its distance; a stretch is only skipped when it is out of the view of a camera, which the engine decides for each camera on its own

#Meters of the course that each stretch covers
const CELL := 60.0

#"stretch|name" -> {"tool": SurfaceTool, "material": Material, "shadow": bool}
var _parts: Dictionary = {}


#Groups positions in stretches along Z: stretch number -> the indices of the points inside it
static func cells(points: Array[Vector3], size := CELL) -> Dictionary:
	var found: Dictionary = {}
	for index in points.size():
		var cell := floori(points[index].z / size)
		if not found.has(cell):
			found[cell] = [] as Array[int]
		(found[cell] as Array[int]).append(index)
	return found


#Adds a copy of "mesh" placed by "place" and painted with "color" (the material reads the colour of each vertex); "uv_scale" stretches its UV
func add(name: StringName, material: Material, shadow: bool, mesh: Mesh, place: Transform3D, color: Color, uv_scale := Vector2.ONE) -> void:
	var key := "%d|%s" % [floori(place.origin.z / CELL), name]
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


#One mesh instance per stretch and material, added under "parent"
func commit(parent: Node3D) -> void:
	for key: String in _parts:
		var part: Dictionary = _parts[key]
		var instance := MeshInstance3D.new()
		instance.mesh = (part["tool"] as SurfaceTool).commit()
		instance.material_override = part["material"]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if part["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
	_parts.clear()
