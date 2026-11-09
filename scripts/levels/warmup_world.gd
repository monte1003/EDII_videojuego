class_name WarmupWorld
extends Node3D

#The warm-up room: a plaza, low bars, a gap and a console, all sized from the real jump of the player

const SLAB_RADIUS := 13.0
const SLAB_THICKNESS := 0.6
const FLOOR_COLOR := Color("b79cf8")
const MINT := Color("86e8c6")
const CYAN := Color("4fd6e8")
const MAGENTA := Color("ee4fb8")
const AMBER := Color("ffc857")
const BOARD_TEXTURE: Texture2D = preload("res://assets/textures/board_checker.png")
#Giant pieces floating around the plaza: model, how many, size range and whether the size is the height
const DECOR: Array[Dictionary] = [
	{"id": &"cloud", "count": 8, "size": Vector2(14.0, 24.0), "tall": false},
	{"id": &"heart", "count": 4, "size": Vector2(4.0, 7.0), "tall": true},
	{"id": &"bubble", "count": 3, "size": Vector2(6.0, 9.0), "tall": false},
	{"id": &"bell", "count": 2, "size": Vector2(4.0, 6.0), "tall": true},
	{"id": &"phone", "count": 2, "size": Vector2(8.0, 12.0), "tall": true},
	{"id": &"island", "count": 3, "size": Vector2(9.0, 14.0), "tall": false},
]

var station_position := Vector3.ZERO

var _station_materials: Array[StandardMaterial3D] = []
var _board_materials: Dictionary = {}
var _decor: Array[Dictionary] = []
var _clock := 0.0


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
	for material in _station_materials:
		material.emission_enabled = active
		material.emission = AMBER
		material.emission_energy_multiplier = 0.6


func _process(delta: float) -> void:
	_clock += delta
	for entry in _decor:
		var node: Node3D = entry["node"]
		var wave: float = _clock * entry["speed"] + entry["phase"]
		node.position.y = entry["base_y"] + sin(wave) * 0.8
		node.rotation.y = entry["yaw"] + sin(wave * 0.7) * 0.2


func _build_sky() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.36, 0.62, 1.0)
	sky_material.sky_horizon_color = Color(1.0, 0.84, 0.93)
	sky_material.sky_curve = 0.2
	sky_material.ground_bottom_color = Color(1.0, 0.8, 0.86)
	sky_material.ground_horizon_color = Color(1.0, 0.84, 0.93)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.96, 0.8, 0.98)
	environment.fog_density = 0.0016
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_color = Color(1, 0.94, 0.86)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)


func _build_slab() -> void:
	_cylinder_body(Vector3(0.0, 0.0, 0.0), SLAB_RADIUS, _board(FLOOR_COLOR))
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
	_cylinder_body(center, radius, _board(MINT))
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


func _cylinder_body(center: Vector3, radius: float, material: Material) -> void:
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
	instance.material_override = material
	body.add_child(instance)
	add_child(body)


#A low striped bumper: the box is what stops the player and the models are laid end to end along it
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
	var base := PropKit.base_size(&"bumper")
	var pieces := maxi(roundi(size.x / (height / base.y * base.x)), 1)
	var piece_length := size.x / pieces
	for index in pieces:
		var piece := PropKit.make(&"bumper", Vector3(piece_length, 0.0, 0.0))
		piece.position = Vector3(-size.x / 2.0 + piece_length * (index + 0.5), -height / 2.0, 0.0)
		body.add_child(piece)
	add_child(body)


func _station(at: Vector3) -> void:
	var base := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 0.85
	mesh.height = 1.1
	base.mesh = mesh
	base.material_override = _material(Color("7a5fdc"))
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
	var heart := PropKit.make(&"heart", Vector3(0.0, 1.1, 0.0))
	heart.position = at + Vector3(0.0, 1.45, 0.0)
	add_child(heart)
	_station_materials = PropKit.own_materials(heart)
	_register_decor(heart, 0.0, 0.0, 1.1)
	set_station_active(false)


func _scatter_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for kind in DECOR:
		for _step in kind["count"] as int:
			var size := rng.randf_range((kind["size"] as Vector2).x, (kind["size"] as Vector2).y)
			var item: Node3D
			if kind["tall"]:
				item = PropKit.make_tall(kind["id"], size, Color.WHITE, false)
			else:
				item = PropKit.make_long(kind["id"], size, Color.WHITE, false)
			var angle := rng.randf() * TAU
			var distance := 30.0 + size * 0.5 + rng.randf_range(0.0, 22.0)
			item.position = Vector3(cos(angle) * distance, rng.randf_range(-4.0, 14.0), sin(angle) * distance)
			item.rotation.y = -angle + PI / 2.0
			add_child(item)
			_register_decor(item, item.rotation.y, rng.randf() * TAU, rng.randf_range(0.35, 0.8))


func _register_decor(node: Node3D, yaw: float, phase: float, speed: float) -> void:
	_decor.append({"node": node, "base_y": node.position.y, "yaw": yaw, "phase": phase, "speed": speed})


#A game-show floor: the checker texture tinted with the colour of the piece, mapped in world space
func _board(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _board_materials.has(key):
		return _board_materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = BOARD_TEXTURE
	material.roughness = 0.55
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / 6.0
	_board_materials[key] = material
	return material


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
