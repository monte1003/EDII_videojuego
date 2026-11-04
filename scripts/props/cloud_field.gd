class_name CloudField
extends Node3D

#Many clouds in a single draw call: each is a flat cluster of puffs that drifts along X and comes back from the other side

const SHADER: Shader = preload("res://assets/shaders/cloud_puff.gdshader")

var _clouds: Array[Dictionary] = []
var _multi: MultiMesh
var _count := 0
var _left := 0.0
var _width := 1.0


#"area_x" is the stretch (from, to) in which clouds drift and wrap around
func setup(area_x: Vector2) -> void:
	_left = area_x.x
	_width = area_x.y - area_x.x


#A cloud of "size" meters at "center", drifting "speed" m/s
func add_cloud(center: Vector3, size: float, color: Color, speed: float, rng: RandomNumberGenerator) -> void:
	var puffs: Array[Dictionary] = []
	for _step in rng.randi_range(4, 7):
		var radius := size * rng.randf_range(0.55, 1.0)
		puffs.append({
			"offset": Vector3(rng.randf_range(-1.6, 1.6) * size, rng.randf_range(-0.2, 0.3) * size, rng.randf_range(-0.8, 0.8) * size),
			"scale": Vector3(radius * 2.0, radius * 0.9, radius * 1.6),
		})
	_clouds.append({"center": center, "speed": speed, "color": color, "puffs": puffs})
	_count += puffs.size()


func commit() -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 10
	sphere.rings = 5
	var material := ShaderMaterial.new()
	material.shader = SHADER
	sphere.material = material
	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_colors = true
	_multi.mesh = sphere
	_multi.instance_count = _count
	var slot := 0
	for cloud in _clouds:
		for _puff in (cloud["puffs"] as Array).size():
			_multi.set_instance_color(slot, cloud["color"])
			slot += 1
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-400.0, -100.0, -400.0), Vector3(800.0, 200.0, 800.0))
	add_child(instance)
	_place()


func _process(delta: float) -> void:
	if _multi == null:
		return
	for cloud in _clouds:
		var center: Vector3 = cloud["center"]
		center.x += (cloud["speed"] as float) * delta
		if center.x > _left + _width:
			center.x -= _width
		cloud["center"] = center
	_place()


func _place() -> void:
	var slot := 0
	for cloud in _clouds:
		var center: Vector3 = cloud["center"]
		for puff: Dictionary in cloud["puffs"]:
			var basis := Basis.from_scale(puff["scale"] as Vector3)
			_multi.set_instance_transform(slot, Transform3D(basis, center + (puff["offset"] as Vector3)))
			slot += 1
