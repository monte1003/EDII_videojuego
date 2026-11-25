class_name StaticBatch
extends RefCounted

#Joins still meshes per material, shadow and layer; with "cell" they join by patches of ground


#"shadows" off: the joined meshes cast no shadow
static func join(root: Node3D, moving: Array[Node], shadows := true, cell := 0.0) -> void:
	var skip: Dictionary = {}
	for node in moving:
		if node != null:
			skip[node] = true
	var tools: Dictionary = {}
	var looks: Dictionary = {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var piece := node as MeshInstance3D
		if piece.mesh == null or _moves(piece, root, skip):
			continue
		var place := _place_in(piece, root)
		var patch := "%d,%d|" % [floori(place.origin.x / cell), floori(place.origin.z / cell)] if cell > 0.0 else ""
		var keys: Array[String] = []
		for surface in piece.mesh.get_surface_count():
			var key := _key_of(piece, surface)
			keys.append("" if key == "" else patch + key)
		#A piece joins whole or not at all
		if keys.has(""):
			continue
		for surface in keys.size():
			var key := keys[surface]
			if not tools.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = tool
				looks[key] = [piece.get_active_material(surface), piece.cast_shadow, piece.layers]
			(tools[key] as SurfaceTool).append_from(piece.mesh, surface, place)
		piece.mesh = null
	for key: String in tools:
		var joined := MeshInstance3D.new()
		joined.mesh = (tools[key] as SurfaceTool).commit()
		joined.material_override = looks[key][0]
		joined.cast_shadow = looks[key][1] if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		joined.layers = looks[key][2]
		root.add_child(joined)


#Join key: material, shadow and vertex format; empty when it cannot join
static func _key_of(piece: MeshInstance3D, surface: int) -> String:
	var material := piece.get_active_material(surface)
	if material == null or piece.material_overlay != null:
		return ""
	if piece.mesh is ArrayMesh and (piece.mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
		return ""
	var arrays := piece.mesh.surface_get_arrays(surface)
	if arrays[Mesh.ARRAY_BONES] != null:
		return ""
	var data := ""
	for index in Mesh.ARRAY_MAX:
		data += "1" if arrays[index] != null else "0"
	return "%d|%d|%d|%s" % [material.get_instance_id(), piece.cast_shadow, piece.layers, data]


#Pieces under something that moves, is hidden or has its own script stay apart
static func _moves(piece: Node, root: Node, skip: Dictionary) -> bool:
	var at := piece
	while at != null and at != root:
		if skip.has(at) or (at is Node3D and not (at as Node3D).visible) or at.get_script() != null:
			return true
		at = at.get_parent()
	return false


#Transform seen from "root", tree ready or not
static func _place_in(piece: Node3D, root: Node3D) -> Transform3D:
	var place := Transform3D.IDENTITY
	var at: Node = piece
	while at != null and at != root:
		if at is Node3D:
			place = (at as Node3D).transform * place
		at = at.get_parent()
	return place
