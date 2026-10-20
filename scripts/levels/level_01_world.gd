class_name Level01World
extends Node3D

#Builds level 1 from Level01Layout: a round platform per vertex and a bridge per edge

const LILAC := Color("a98df0")
const LILAC_LIGHT := Color("c5b3f7")
const LILAC_DARK := Color("6d55c2")
const CYAN := Color("4fd6e8")
const MAGENTA := Color("ee4fb8")
const AMBER := Color("ffc857")

const BRIDGE_WIDTH := 4.2
const THICKNESS := 0.6
const FALL_Y := -12.0

#Offsets of the stations from the centre of their platform
const E_STATION_OFFSET := Vector3(-2.4, 0.0, -2.4)
const F_STATION_OFFSET := Vector3(2.4, 0.0, -2.4)
const D_REFUGE_OFFSET := Vector3(-2.2, 0.0, 0.0)

#Floating names over the places that matter: title, short explanation, colour, label height
const NAMES := {
	&"S": ["SALIDA", "Aquí empiezas", Color("fdfbff"), 4.2],
	&"M": ["META", "Zona de desconexión", Color("ffc857"), 7.6],
	&"E": ["BLOQUEAR", "Cierra un puente a los bots", Color("ee4fb8"), 3.6],
	&"F": ["SILENCIAR", "Los bots te ven menos", Color("4fd6e8"), 3.6],
	&"D": ["PAUSA DIGITAL", "Refugio: nadie te empuja", Color("ffc857"), 4.4],
	&"H": ["CHECKPOINT", "Guarda tu progreso", Color("ffc857"), 6.6],
}
const NAME_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")

var station_positions: Dictionary = {}
var refuge_center := Vector3.ZERO

var _materials: Dictionary = {}
var _barrier: MeshInstance3D
var _checkpoint_ring_material: StandardMaterial3D
var _flag: MeshInstance3D


func build(locator: PlayerLocator) -> void:
	for id: StringName in Level01Layout.POSITIONS:
		_build_platform(id, locator)
	for edge in Level01Layout.EDGES:
		_build_bridge(edge[0], edge[1], locator)
	_build_start_marks()
	_build_station(&"E", E_STATION_OFFSET, MAGENTA)
	_build_station(&"F", F_STATION_OFFSET, CYAN)
	_build_refuge()
	_build_checkpoint()
	_build_goal()
	_build_barrier()
	_build_name_labels()
	_scatter_decor()


func set_block_visual(active: bool) -> void:
	_barrier.visible = active


func set_checkpoint_active(active: bool) -> void:
	var color := AMBER if active else CYAN
	_checkpoint_ring_material.albedo_color = color
	_checkpoint_ring_material.emission = color
	_flag.material_override = _material(MAGENTA if active else LILAC_DARK, 1.4 if active else 0.0)


func _material(color: Color, emission := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [color.to_html(), emission, alpha]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.6
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = material
	return material


func _mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, casts_shadow := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	if not casts_shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _body(shape: Shape3D, xform: Transform3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = xform
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	return body


func _sensor(shape: Shape3D, xform: Transform3D) -> Area3D:
	var area := Area3D.new()
	area.transform = xform
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitorable = false
	var collider := CollisionShape3D.new()
	collider.shape = shape
	area.add_child(collider)
	add_child(area)
	return area


func _build_platform(id: StringName, locator: PlayerLocator) -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[id]
	var radius := Level01Layout.radius_of(id)

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = THICKNESS
	var body := _body(shape, Transform3D(Basis.IDENTITY, centre + Vector3(0, -THICKNESS / 2.0, 0)))

	var top_color := LILAC_LIGHT if id == Level01Layout.START or id == Level01Layout.GOAL else LILAC
	var top := CylinderMesh.new()
	top.top_radius = radius
	top.bottom_radius = radius
	top.height = THICKNESS
	top.radial_segments = 40
	top.rings = 1
	_mesh(body, top, _material(top_color), Vector3.ZERO, true)

	var skirt := CylinderMesh.new()
	skirt.top_radius = radius * 0.97
	skirt.bottom_radius = radius * 0.5
	skirt.height = 1.6
	skirt.radial_segments = 40
	skirt.rings = 1
	_mesh(body, skirt, _material(LILAC_DARK), Vector3(0, -THICKNESS / 2.0 - 0.8, 0))

	var rim := TorusMesh.new()
	rim.outer_radius = radius
	rim.inner_radius = radius - 0.14
	rim.rings = 40
	rim.ring_segments = 6
	_mesh(body, rim, _material(CYAN, 0.9), Vector3(0, THICKNESS / 2.0, 0))

	var sensor_shape := CylinderShape3D.new()
	sensor_shape.radius = radius - 0.1
	sensor_shape.height = 9.0
	var area := _sensor(sensor_shape, Transform3D(Basis.IDENTITY, centre + Vector3(0, 3.8, 0)))
	locator.watch_platform(id, area)


func _build_bridge(a: StringName, b: StringName, locator: PlayerLocator) -> void:
	var from: Vector3 = Level01Layout.POSITIONS[a]
	var to: Vector3 = Level01Layout.POSITIONS[b]
	var radius_a := Level01Layout.radius_of(a)
	var radius_b := Level01Layout.radius_of(b)
	var direction := (to - from)
	direction.y = 0.0
	var distance := direction.length()
	direction = direction.normalized()
	var basis := Basis.looking_at(direction, Vector3.UP)

	#The solid bridge reaches 0.6 m into each platform so there is no seam
	var start := radius_a - 0.6
	var end := distance - radius_b + 0.6
	var centre := from + direction * ((start + end) / 2.0) + Vector3(0, -THICKNESS / 2.0, 0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(BRIDGE_WIDTH, THICKNESS, end - start)
	var body := _body(shape, Transform3D(basis, centre))
	_mesh(body, _box(shape.size), _material(LILAC), Vector3.ZERO, true)

	#Pink strips mark where the bridge starts, one at each platform edge
	for s: float in [radius_a, distance - radius_b]:
		var strip_centre := from + direction * s + Vector3(0, 0.03, 0)
		var strip := _mesh(self, _box(Vector3(BRIDGE_WIDTH, 0.06, 0.4)), _material(MAGENTA, 0.5), strip_centre)
		strip.basis = basis

	#The sensor covers only the part of the bridge outside both platforms
	var sensor_shape := BoxShape3D.new()
	sensor_shape.size = Vector3(BRIDGE_WIDTH, 9.0, maxf(distance - radius_a - radius_b, 0.5))
	var sensor_centre := from + direction * ((radius_a + distance - radius_b) / 2.0) + Vector3(0, 3.8, 0)
	var area := _sensor(sensor_shape, Transform3D(basis, sensor_centre))
	locator.watch_bridge(a, b, area)


func _build_start_marks() -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[Level01Layout.START]
	var prism := PrismMesh.new()
	prism.size = Vector3(1.6, 1.4, 0.04)
	for step in 2:
		var arrow := _mesh(self, prism, _material(MAGENTA, 0.6), centre + Vector3(0, 0.04, -2.6 - step * 1.8))
		arrow.rotation_degrees.x = -90.0


func _build_station(id: StringName, offset: Vector3, color: Color) -> void:
	var at: Vector3 = Level01Layout.POSITIONS[id] + offset
	station_positions[id] = at
	_mesh(self, _box(Vector3(1.7, 0.9, 1.0)), _material(LILAC_DARK), at + Vector3(0, 0.45, 0), true)
	var screen := _mesh(self, _box(Vector3(1.5, 0.8, 0.1)), _material(color, 1.4), at + Vector3(0, 1.2, 0.25))
	screen.rotation_degrees.x = -20.0
	#A small disc on the floor shows the area where the station answers
	var ring := CylinderMesh.new()
	ring.top_radius = 1.6
	ring.bottom_radius = 1.6
	ring.height = 0.03
	_mesh(self, ring, _material(color, 0.6, 0.35), at + Vector3(0, 0.02, 0))


func _build_refuge() -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[&"D"] + D_REFUGE_OFFSET
	refuge_center = centre
	station_positions[&"D"] = centre
	var wall_material := _material(LILAC_DARK)
	_mesh(self, _box(Vector3(0.4, 2.4, 4.4)), wall_material, centre + Vector3(-1.8, 1.2, 0), true)
	_mesh(self, _box(Vector3(3.8, 0.4, 4.6)), _material(LILAC), centre + Vector3(0, 2.6, 0), true)
	for side in [-1.0, 1.0]:
		_mesh(self, _box(Vector3(3.4, 2.4, 0.4)), wall_material, centre + Vector3(0, 1.2, side * 2.1), true)
	#Warm window and bench: this is the calm corner
	_mesh(self, _box(Vector3(0.1, 0.8, 1.6)), _material(AMBER, 1.5), centre + Vector3(-1.55, 1.5, 0))
	_mesh(self, _box(Vector3(0.7, 0.35, 2.0)), _material(MAGENTA), centre + Vector3(-0.9, 0.18, 0))
	var ring := CylinderMesh.new()
	ring.top_radius = 3.6
	ring.bottom_radius = 3.6
	ring.height = 0.03
	_mesh(self, ring, _material(AMBER, 0.5, 0.25), centre + Vector3(0, 0.02, 0))


func _build_checkpoint() -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[&"H"]
	var ring := CylinderMesh.new()
	ring.top_radius = 1.5
	ring.bottom_radius = 1.5
	ring.height = 0.04
	_checkpoint_ring_material = StandardMaterial3D.new()
	_checkpoint_ring_material.albedo_color = CYAN
	_checkpoint_ring_material.emission_enabled = true
	_checkpoint_ring_material.emission = CYAN
	_checkpoint_ring_material.emission_energy_multiplier = 1.4
	_mesh(self, ring, _checkpoint_ring_material, centre + Vector3(0, 0.03, 0))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.08
	pole.height = 3.2
	pole.radial_segments = 8
	_mesh(self, pole, _material(LILAC_DARK), centre + Vector3(0, 1.6, 0))
	_flag = _mesh(self, _box(Vector3(1.0, 0.65, 0.05)), _material(LILAC_DARK), centre + Vector3(0.55, 2.8, 0))


func _build_goal() -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[Level01Layout.GOAL]
	var gold := _material(AMBER, 0.8)
	for side in [-1.0, 1.0]:
		var pillar := CylinderMesh.new()
		pillar.top_radius = 0.35
		pillar.bottom_radius = 0.4
		pillar.height = 4.6
		pillar.radial_segments = 12
		_mesh(self, pillar, gold, centre + Vector3(side * 3.2, 2.3, 0), true)
	_mesh(self, _box(Vector3(7.2, 0.7, 0.7)), gold, centre + Vector3(0, 4.8, 0), true)
	var crown := SphereMesh.new()
	crown.radius = 0.55
	crown.height = 1.1
	_mesh(self, crown, _material(MAGENTA, 1.2), centre + Vector3(0, 5.8, 0))
	for i in 6:
		var light := i % 2 == 0
		_mesh(self, _box(Vector3(1.0, 0.04, 0.8)), _material(Color("fdfbff") if light else Color("372c58")),
			centre + Vector3(-2.5 + i * 1.0, 0.03, 1.2))
	#A faint beam that can be seen from the start
	var beam := CylinderMesh.new()
	beam.top_radius = 0.9
	beam.bottom_radius = 1.2
	beam.height = 26.0
	beam.radial_segments = 12
	beam.rings = 1
	_mesh(self, beam, _material(CYAN, 0.8, 0.14), centre + Vector3(0, 13.0, 0))


#A translucent wall across the bridge that Bloquear closes for the bots
func _build_barrier() -> void:
	var a: Vector3 = Level01Layout.POSITIONS[Level01Layout.BLOCK_EDGE[0]]
	var b: Vector3 = Level01Layout.POSITIONS[Level01Layout.BLOCK_EDGE[1]]
	var direction := (b - a)
	direction.y = 0.0
	direction = direction.normalized()
	_barrier = _mesh(self, _box(Vector3(BRIDGE_WIDTH + 0.4, 1.8, 0.2)), _material(MAGENTA, 1.3, 0.38),
		(a + b) / 2.0 + Vector3(0, 0.9, 0))
	_barrier.basis = Basis.looking_at(direction, Vector3.UP)
	_barrier.visible = false


#Soft floating shapes far from the route; no collisions
func _scatter_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var colors: Array[Color] = [Color("f6e9ff"), LILAC_DARK, Palette.SKY_BOTTOM]
	for i in 30:
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(side * rng.randf_range(34.0, 70.0), rng.randf_range(-14.0, 8.0), rng.randf_range(-95.0, 25.0))
		var radius := rng.randf_range(2.0, 5.0)
		var mesh: Mesh
		if i % 2 == 0:
			var sphere := SphereMesh.new()
			sphere.radius = radius
			sphere.height = radius * 2.0
			sphere.radial_segments = 16
			sphere.rings = 8
			mesh = sphere
		else:
			var stone := CylinderMesh.new()
			stone.top_radius = radius
			stone.bottom_radius = radius * 0.55
			stone.height = radius * 0.9
			stone.radial_segments = 16
			mesh = stone
		var instance := _mesh(self, mesh, _material(colors[i % 3]), at)
		instance.scale.y = rng.randf_range(0.6, 1.0)


#Names float over the stations so the player knows what each place is for
func _build_name_labels() -> void:
	for id: StringName in NAMES:
		var entry: Array = NAMES[id]
		var at: Vector3 = station_positions.get(id, Level01Layout.POSITIONS[id])
		_label(entry[0], 64, entry[2], at + Vector3(0, entry[3], 0))
		_label(entry[1], 34, Color("fdfbff"), at + Vector3(0, entry[3] - 0.95, 0))


func _label(text: String, size: int, color: Color, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = NAME_FONT
	label.font_size = size
	label.pixel_size = 0.0215 * size / 64.0 if size > 40 else 0.016
	label.modulate = color
	label.outline_size = 20
	label.outline_modulate = Color("2a2145")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	add_child(label)
