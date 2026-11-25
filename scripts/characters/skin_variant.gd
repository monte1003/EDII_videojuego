class_name SkinVariant
extends RefCounted

#Repeated characters wear the same drawing with the hue turned; variant 0 is the original

const SHADER: Shader = preload("res://assets/shaders/skin_variant.gdshader")
#Hue turn per variant, as a share of the colour wheel
const HUE_SHIFTS: Array[float] = [0.0, 0.42, 0.68, 0.18]

static var _cache: Dictionary = {}


#Repaints every mesh under "model"; 0 leaves it as it is
static func apply(model: Node, index: int) -> void:
	if model == null or index <= 0:
		return
	var shift := HUE_SHIFTS[index % HUE_SHIFTS.size()]
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original != null and original.albedo_texture != null:
				mesh.set_surface_override_material(surface, _paint(original, shift))


static func _paint(original: StandardMaterial3D, shift: float) -> ShaderMaterial:
	var key := "%d_%s" % [original.get_instance_id(), shift]
	if not _cache.has(key):
		var paint := ShaderMaterial.new()
		paint.shader = SHADER
		paint.set_shader_parameter("albedo_texture", original.albedo_texture)
		paint.set_shader_parameter("albedo_color", original.albedo_color)
		paint.set_shader_parameter("hue_shift", shift)
		paint.set_shader_parameter("roughness", original.roughness)
		paint.set_shader_parameter("metallic", original.metallic)
		_cache[key] = paint
	return _cache[key]
