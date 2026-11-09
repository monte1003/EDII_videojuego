class_name PropKit
extends RefCounted

#The decorative models of the game: each one is fitted to a size in meters, centred and with its base at y = 0

const FOLDER := "res://assets/props/%s/%s.glb"
#Where the windows of each car start, as a share of its height (the headlights sit just below them)
const GLASS_LOW := {&"car_hatch": 0.53, &"van": 0.5}

const GLASS_SHADER: Shader = preload("res://assets/shaders/car_glass.gdshader")

static var _scenes: Dictionary = {}
static var _bounds: Dictionary = {}
static var _tints: Dictionary = {}


#"size" has the target size per axis; an axis left at 0 follows the average scale of the others
static func make(id: StringName, size: Vector3, tint := Color.WHITE, casts_shadow := true) -> Node3D:
	var model := _scene(id).instantiate() as Node3D
	var box := _box(id, model)
	var factors := Vector3(_factor(size.x, box.size.x), _factor(size.y, box.size.y), _factor(size.z, box.size.z))
	var known := 0
	var total := 0.0
	for axis in 3:
		if factors[axis] > 0.0:
			known += 1
			total += factors[axis]
	var average := total / maxf(known, 1.0)
	for axis in 3:
		if factors[axis] <= 0.0:
			factors[axis] = average
	model.scale = factors
	model.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z) * factors
	var root := Node3D.new()
	root.name = String(id)
	root.add_child(model)
	if tint != Color.WHITE:
		_apply_tint(model, tint)
	if not casts_shadow:
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


#Fitted by one measure only: the height, the length (X) or the width (Z)
static func make_tall(id: StringName, height: float, tint := Color.WHITE, casts_shadow := true) -> Node3D:
	return make(id, Vector3(0.0, height, 0.0), tint, casts_shadow)


static func make_long(id: StringName, length: float, tint := Color.WHITE, casts_shadow := true) -> Node3D:
	return make(id, Vector3(length, 0.0, 0.0), tint, casts_shadow)


#A car with open glass: the dark window pixels of its texture let the people inside show through; "tint" colours the body
static func make_car(id: StringName, length: float, tint: Color, roof_tint := Color.TRANSPARENT) -> Node3D:
	var root := make(id, Vector3(length, 0.0, 0.0))
	var box := _bounds[id] as AABB
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var base := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if base != null and base.albedo_texture != null:
				mesh.set_surface_override_material(surface, _glass(base.albedo_texture, tint, roof_tint, box, GLASS_LOW.get(id, 0.5)))
	return root


#Box of a model already made by make, in the space of the root it returned: its real size on screen, for hit boxes
static func measure(root: Node3D) -> AABB:
	return _measure(root)


#Size of the model as it comes, to know the proportions before placing it
static func base_size(id: StringName) -> Vector3:
	if not _bounds.has(id):
		var model := _scene(id).instantiate() as Node3D
		_box(id, model)
		model.free()
	return (_bounds[id] as AABB).size


#Gives the model its own materials and returns them, so the caller can make it glow or change colour later
static func own_materials(model: Node3D) -> Array[StandardMaterial3D]:
	var owned: Array[StandardMaterial3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var base := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if base == null:
				continue
			var copy := base.duplicate() as StandardMaterial3D
			mesh.set_surface_override_material(surface, copy)
			owned.append(copy)
	return owned


static func _glass(texture: Texture2D, tint: Color, roof_tint: Color, box: AABB, glass_low: float) -> ShaderMaterial:
	if roof_tint.a == 0.0:
		roof_tint = tint
	var key := "glass_%d_%s_%s" % [texture.get_instance_id(), tint.to_html(), roof_tint.to_html()]
	if not _tints.has(key):
		var material := ShaderMaterial.new()
		material.shader = GLASS_SHADER
		material.set_shader_parameter("albedo_tex", texture)
		material.set_shader_parameter("tint", tint)
		material.set_shader_parameter("roof_tint", roof_tint)
		material.set_shader_parameter("glass_low", glass_low)
		material.set_shader_parameter("feet_y", box.position.y)
		material.set_shader_parameter("body_height", box.size.y)
		_tints[key] = material
	return _tints[key]


static func _factor(wanted: float, current: float) -> float:
	if wanted <= 0.0 or current <= 0.0:
		return 0.0
	return wanted / current


static func _scene(id: StringName) -> PackedScene:
	if not _scenes.has(id):
		_scenes[id] = load(FOLDER % [id, id])
	return _scenes[id]


#Size of the meshes of a model in its own space; it is the same for every copy, so it is kept
static func _box(id: StringName, model: Node3D) -> AABB:
	if not _bounds.has(id):
		_bounds[id] = _measure(model)
	return _bounds[id]


static func _measure(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var offset := Transform3D()
		var step: Node = mesh
		while step != model and step != null:
			offset = (step as Node3D).transform * offset
			step = step.get_parent()
		var part := offset * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


static func _apply_tint(model: Node3D, tint: Color) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var base := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if base == null:
				continue
			var key := "%d_%s" % [base.get_instance_id(), tint.to_html()]
			if not _tints.has(key):
				var copy := base.duplicate() as StandardMaterial3D
				copy.albedo_color = base.albedo_color * tint
				_tints[key] = copy
			mesh.set_surface_override_material(surface, _tints[key])
