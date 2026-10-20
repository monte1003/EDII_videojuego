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

#Floating names: title, explanation, colour, height and the distance the title can be read from
const NAMES := {
	&"S": ["SALIDA", "Aquí empiezas", Color("fdfbff"), 4.0, 30.0],
	&"M": ["META", "Zona de desconexión", Color("ffc857"), 8.0, 140.0],
	&"E": ["BLOQUEAR", "Cierra un puente a los bots", Color("ee4fb8"), 3.7, 30.0],
	&"F": ["SILENCIAR", "Los bots te ven menos", Color("4fd6e8"), 3.7, 30.0],
	&"D": ["PAUSA DIGITAL", "Refugio: nadie te empuja", Color("ffc857"), 4.6, 30.0],
	&"H": ["CHECKPOINT", "Guarda tu progreso", Color("ffc857"), 4.9, 30.0],
}
#Distance up to which the explanation under a title is shown
const SUBTITLE_RANGE := 14.0
const NAME_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")

var station_positions: Dictionary = {}
var refuge_center := Vector3.ZERO

var _materials: Dictionary = {}
var _barrier: MeshInstance3D
var _props: Level01Props


#Every player has its own locator; the sensors tell each of them where it is
func build(locators: Array[PlayerLocator], refuge_radius: float) -> void:
	for id: StringName in Level01Layout.POSITIONS:
		_build_platform(id, locators)
	for edge in Level01Layout.EDGES:
		_build_bridge(edge[0], edge[1], locators)
	_build_start_marks()
	_props = Level01Props.new()
	add_child(_props)
	_props.build(refuge_radius)
	station_positions = _props.station_positions
	refuge_center = _props.refuge_center
	_build_barrier()
	_build_name_labels()
	_scatter_decor()


func set_block_visual(active: bool) -> void:
	_barrier.visible = active


func set_checkpoint_active(active: bool) -> void:
	_props.set_checkpoint_active(active)


#The station glows while its ability is working
func set_station_active(id: StringName, active: bool) -> void:
	_props.set_active(id, active)


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


func _build_platform(id: StringName, locators: Array[PlayerLocator]) -> void:
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
	for locator in locators:
		locator.watch_platform(id, area)


func _build_bridge(a: StringName, b: StringName, locators: Array[PlayerLocator]) -> void:
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
	for locator in locators:
		locator.watch_bridge(a, b, area)


func _build_start_marks() -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[Level01Layout.START]
	var prism := PrismMesh.new()
	prism.size = Vector3(1.6, 1.4, 0.04)
	for step in 2:
		var arrow := _mesh(self, prism, _material(MAGENTA, 0.6), centre + Vector3(0, 0.04, -2.6 - step * 1.8))
		arrow.rotation_degrees.x = -90.0


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
		_label(entry[0], 54, entry[2], at + Vector3(0, entry[3], 0), entry[4])
		_label(entry[1], 30, Color("fdfbff"), at + Vector3(0, entry[3] - 0.8, 0), SUBTITLE_RANGE)


func _label(text: String, size: int, color: Color, at: Vector3, visible_range: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = NAME_FONT
	label.font_size = size
	#Same size on screen at any distance, so a name never fills the view when the player stands under it
	label.fixed_size = true
	label.pixel_size = 0.0015
	label.modulate = color
	label.outline_size = 12
	label.outline_modulate = Color("2a2145")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = at
	#Fades out with distance so far labels never pile up on the screen
	label.visibility_range_end = visible_range
	label.visibility_range_end_margin = visible_range * 0.25
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(label)
