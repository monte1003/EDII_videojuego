class_name CloudField
extends Node3D

#Drifting clouds moved by the shader; one draw call per row along Z

const SHADER: Shader = preload("res://assets/shaders/cloud_puff.gdshader")
const ROW := 120.0

var _clouds: Array[Dictionary] = []
var _left := 0.0
var _width := 1.0


#"area_x" is the range where clouds drift and wrap
func setup(area_x: Vector2) -> void:
	_left = area_x.x
	_width = area_x.y - area_x.x


#Cloud of "size" meters drifting "speed" m/s
func add_cloud(center: Vector3, size: float, color: Color, speed: float, rng: RandomNumberGenerator) -> void:
	var puffs: Array[Dictionary] = []
	for _step in rng.randi_range(4, 7):
		var radius := size * rng.randf_range(0.55, 1.0)
		puffs.append({
			"offset": Vector3(rng.randf_range(-1.6, 1.6) * size, rng.randf_range(-0.2, 0.3) * size, rng.randf_range(-0.8, 0.8) * size),
			"scale": Vector3(radius * 2.0, radius * 0.9, radius * 1.6),
		})
	_clouds.append({"center": center, "speed": speed, "color": color, "puffs": puffs, "size": size})


func commit() -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 10
	sphere.rings = 5
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("left", _left)
	material.set_shader_parameter("width", _width)
	sphere.material = material
	var centres: Array[Vector3] = []
	for cloud in _clouds:
		centres.append(cloud["center"])
	var groups := MeshMerger.cells(centres, ROW)
	for cell: int in groups:
		var members: Array[int] = groups[cell]
		var puffs := 0
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for index in members:
			var cloud := _clouds[index]
			puffs += (cloud["puffs"] as Array).size()
			var reach: float = cloud["size"] * 3.0
			var centre: Vector3 = cloud["center"]
			low = low.min(centre - Vector3.ONE * reach)
			high = high.max(centre + Vector3.ONE * reach)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.use_custom_data = true
		multi.mesh = sphere
		multi.instance_count = puffs
		var slot := 0
		for index in members:
			var cloud := _clouds[index]
			var centre: Vector3 = cloud["center"]
			for puff: Dictionary in cloud["puffs"]:
				var basis := Basis.from_scale(puff["scale"] as Vector3)
				multi.set_instance_transform(slot, Transform3D(basis, centre + (puff["offset"] as Vector3)))
				multi.set_instance_color(slot, cloud["color"])
				#Start X and speed for the shader
				multi.set_instance_custom_data(slot, Color(centre.x, cloud["speed"], 0.0, 0.0))
				slot += 1
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		#A row sweeps the whole width over time
		instance.custom_aabb = AABB(Vector3(_left - 40.0, low.y, low.z), Vector3(_width + 80.0, high.y - low.y, high.z - low.z))
		add_child(instance)
