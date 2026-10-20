class_name WarmupWorld
extends Node3D

#The warm-up room: a plaza, low bars, a gap and a console, all sized from the real jump of the player

const SLAB_RADIUS := 13.0
const SLAB_THICKNESS := 0.6
const FLOOR_COLOR := Color("cdbcf7")
const SKIRT_COLOR := Color("9d88e0")
const CYAN := Color("4fd6e8")
const MAGENTA := Color("ee4fb8")
const AMBER := Color("ffc857")

var station_position := Vector3.ZERO

var _station_material: StandardMaterial3D


func build(jump_height: float, jump_reach: float) -> void:
	_build_sky()
	_build_slab()
	var low := snappedf(jump_height * 0.45, 0.05)
	for angle in [-38.0, 0.0, 38.0]:
		var radians := deg_to_rad(angle)
		_bar(Vector3(sin(radians) * 8.5, 0.0, -cos(radians) * 8.5), radians, low)
	var gap := snappedf(jump_reach * 0.5, 0.1)
	_island(Vector3(0.0, 0.0, -(SLAB_RADIUS + gap + 3.0)), 3.0)
	station_position = Vector3(7.5, 0.0, 4.5)
	_station(station_position)
	_scatter_decor()


#The console lights up when the player uses it
func set_station_active(active: bool) -> void:
	var color := AMBER if active else MAGENTA
	_station_material.albedo_color = color
	_station_material.emission = color


func _build_sky() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.737, 0.784, 0.98)
	sky_material.sky_horizon_color = Color(0.85, 0.72, 0.92)
	sky_material.ground_bottom_color = Color(0.973, 0.643, 0.702)
	sky_material.ground_horizon_color = Color(0.85, 0.72, 0.92)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.85, 0.76, 0.95)
	environment.fog_density = 0.004
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_color = Color(1, 0.95, 0.93)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)


func _build_slab() -> void:
	_cylinder_body(Vector3(0.0, 0.0, 0.0), SLAB_RADIUS, FLOOR_COLOR)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = SLAB_RADIUS - 0.18
	torus.outer_radius = SLAB_RADIUS + 0.02
	torus.rings = 64
	torus.ring_segments = 8
	rim.mesh = torus
	rim.material_override = _material(CYAN, 1.2)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)


func _island(center: Vector3, radius: float) -> void:
	_cylinder_body(center, radius, FLOOR_COLOR)
	var mark := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.1
	disc.height = 0.04
	mark.mesh = disc
	mark.material_override = _material(AMBER, 1.0)
	mark.position = center + Vector3(0.0, 0.03, 0.0)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)


func _cylinder_body(center: Vector3, radius: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = center + Vector3(0.0, -SLAB_THICKNESS / 2.0, 0.0)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = SLAB_THICKNESS
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.92
	mesh.height = SLAB_THICKNESS
	mesh.radial_segments = 48
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	body.add_child(instance)
	add_child(body)


func _bar(at: Vector3, yaw: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.position = at + Vector3(0.0, height / 2.0, 0.0)
	body.rotation.y = yaw
	var size := Vector3(3.4, height, 0.5)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(MAGENTA, 0.5)
	body.add_child(instance)
	add_child(body)


func _station(at: Vector3) -> void:
	var base := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 0.85
	mesh.height = 1.1
	base.mesh = mesh
	base.material_override = _material(Color("6d55c2"))
	base.position = at + Vector3(0.0, 0.55, 0.0)
	add_child(base)
	var body := StaticBody3D.new()
	body.position = base.position
	var shape := CylinderShape3D.new()
	shape.radius = 0.8
	shape.height = 1.1
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	var screen := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.06
	screen.mesh = disc
	_station_material = _material(MAGENTA, 1.6)
	screen.material_override = _station_material
	screen.position = at + Vector3(0.0, 1.13, 0.0)
	add_child(screen)


func _scatter_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var colors: Array[Color] = [Color("a98df0"), MAGENTA, CYAN, AMBER]
	for index in 14:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(24.0, 48.0)
		var bubble := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var radius := rng.randf_range(0.8, 2.4)
		sphere.radius = radius
		sphere.height = radius * 2.0
		bubble.mesh = sphere
		bubble.material_override = _material(colors[index % colors.size()], 0.25, 0.7)
		bubble.position = Vector3(cos(angle) * distance, rng.randf_range(-6.0, 9.0), sin(angle) * distance)
		bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bubble)


func _material(color: Color, emission := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.6
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
