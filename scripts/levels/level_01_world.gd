class_name Level01World
extends Node3D

#Builds level 1 from Level01Layout: a round platform per vertex, a bridge per edge (plain, conveyor belt or fragile) and a spinner on some islands

const LILAC := Color("b79cf8")
const LILAC_DARK := Color("7a5fdc")
#Start and goal stand out from the lilac course: cool mint to leave, warm sun to arrive
const MINT := Color("86e8c6")
const MINT_DARK := Color("4cb797")
const SUN := Color("ffd27a")
const SUN_DARK := Color("e0a23d")
const CORAL := Color("ff7a85")
const CYAN := Color("4fd6e8")
const MAGENTA := Color("ee4fb8")
const AMBER := Color("ffc857")
const BOARD_TEXTURE: Texture2D = preload("res://assets/textures/board_checker.png")
const BELT_TEXTURE: Texture2D = preload("res://assets/textures/belt_chevrons.png")

const BRIDGE_WIDTH := 4.2
const THICKNESS := 0.6
const FALL_Y := -12.0
#Meters of bridge that one chevron of the belt covers
const BELT_TILE := 3.0
#How long a fragile bridge takes to drop out of sight or to come back, and how far it drops
const DROP_TIME := 0.5
const DROP_DEPTH := 9.0

const NAME_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
#Distance up to which the explanation under a title is shown
const SUBTITLE_RANGE := 14.0

var station_positions: Dictionary = {}
var refuge_center := Vector3.ZERO

var _materials: Dictionary = {}
var _barrier: MeshInstance3D
var _props: Level01Props
var _belt_speed := 2.6
var _clock := 0.0
#"a|b" with the two ids in order -> what the bridge is made of
var _bridges: Dictionary = {}
var _belts: Array[StandardMaterial3D] = []
var _flashing: Dictionary = {}
var _spinners: Dictionary = {}


#Every racer has its own locator; the sensors tell each of them where it is
func build(locators: Array[PlayerLocator], refuge_radius: float, belt_speed: float) -> void:
	_belt_speed = belt_speed
	for id: StringName in Level01Layout.POSITIONS:
		_build_platform(id, locators)
	for edge in Level01Layout.EDGES:
		_build_bridge(edge[0], edge[1], edge[4], locators)
	_build_start_marks()
	_props = Level01Props.new()
	add_child(_props)
	_props.build(refuge_radius)
	station_positions = _props.station_positions
	refuge_center = _props.refuge_center
	_build_spinners()
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


#The bars turn with the clock of the round, the same one the rules use to hit
func update_hazards(time: float) -> void:
	for id: StringName in _spinners:
		var pivot: Node3D = _spinners[id]
		pivot.rotation.y = -Level01Hazards.angle_at(Level01Layout.SPINNERS[id], time)


#A fragile bridge flashes while it is about to fall
func flash_bridge(a: StringName, b: StringName, on: bool) -> void:
	var key := _key(a, b)
	if on:
		_flashing[key] = true
		return
	_flashing.erase(key)
	var record: Dictionary = _bridges.get(key, {})
	if record.has("material"):
		(record["material"] as StandardMaterial3D).emission_energy_multiplier = 0.2


#A fragile bridge drops out of sight (no floor) or comes back
func set_bridge_open(a: StringName, b: StringName, open: bool) -> void:
	var record: Dictionary = _bridges.get(_key(a, b), {})
	if record.is_empty():
		return
	(record["collider"] as CollisionShape3D).set_deferred("disabled", not open)
	var visual: Node3D = record["visual"]
	var tween := create_tween()
	if open:
		visual.visible = true
		tween.tween_property(visual, "position:y", 0.0, DROP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(visual, "position:y", -DROP_DEPTH, DROP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(visual.hide)
	for strip: Node3D in record["strips"]:
		strip.visible = open


func _process(delta: float) -> void:
	_clock += delta
	for belt in _belts:
		belt.uv1_offset.y = fposmod(_clock * _belt_speed / BELT_TILE, 1.0)
	for key: String in _flashing:
		var record: Dictionary = _bridges[key]
		(record["material"] as StandardMaterial3D).emission_energy_multiplier = 0.3 + 1.6 * absf(sin(_clock * 9.0))


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


#A game-show floor: the checker texture tinted with the colour of the piece, mapped in world space
func _board(color: Color) -> StandardMaterial3D:
	var key := "board_%s" % color.to_html()
	if not _materials.has(key):
		_materials[key] = _board_copy(color)
	return _materials[key]


func _board_copy(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = BOARD_TEXTURE
	material.roughness = 0.55
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / 6.0
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


func _key(a: StringName, b: StringName) -> String:
	return "%s|%s" % [a, b] if String(a) < String(b) else "%s|%s" % [b, a]


func _build_platform(id: StringName, locators: Array[PlayerLocator]) -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[id]
	var radius := Level01Layout.radius_of(id)

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = THICKNESS
	var body := _body(shape, Transform3D(Basis.IDENTITY, centre + Vector3(0, -THICKNESS / 2.0, 0)))

	var is_start := id == Level01Layout.START
	var is_goal := id == Level01Layout.GOAL
	var top_color := MINT if is_start else (SUN if is_goal else LILAC)
	var skirt_color := MINT_DARK if is_start else (SUN_DARK if is_goal else LILAC_DARK)
	#The rim warns: white to leave, gold to arrive, hot pink where a bar sweeps the island
	var rim_color := Color("fdfbff") if is_start else (AMBER if is_goal else (MAGENTA if Level01Layout.SPINNERS.has(id) else CYAN))
	var top := CylinderMesh.new()
	top.top_radius = radius
	top.bottom_radius = radius
	top.height = THICKNESS
	top.radial_segments = 40
	top.rings = 1
	_mesh(body, top, _board(top_color), Vector3.ZERO, true)

	var skirt := CylinderMesh.new()
	skirt.top_radius = radius * 0.97
	skirt.bottom_radius = radius * 0.5
	skirt.height = 1.6
	skirt.radial_segments = 40
	skirt.rings = 1
	_mesh(body, skirt, _material(skirt_color), Vector3(0, -THICKNESS / 2.0 - 0.8, 0))

	var rim := TorusMesh.new()
	rim.outer_radius = radius
	rim.inner_radius = radius - 0.14
	rim.rings = 40
	rim.ring_segments = 6
	_mesh(body, rim, _material(rim_color, 0.9), Vector3(0, THICKNESS / 2.0, 0))

	var sensor_shape := CylinderShape3D.new()
	sensor_shape.radius = radius - 0.1
	sensor_shape.height = 9.0
	var area := _sensor(sensor_shape, Transform3D(Basis.IDENTITY, centre + Vector3(0, 3.8, 0)))
	for locator in locators:
		locator.watch_platform(id, area)


func _build_bridge(a: StringName, b: StringName, kind: StringName, locators: Array[PlayerLocator]) -> void:
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
	var material := _bridge_material(kind, end - start)
	var visual := _mesh(body, _box(shape.size), material, Vector3.ZERO, true)

	#Strips mark where the bridge starts, one at each platform edge
	var strips: Array[Node3D] = []
	var strip_color := MINT_DARK if kind == Level01Layout.BELT else MAGENTA
	for s: float in [radius_a, distance - radius_b]:
		var strip_centre := from + direction * s + Vector3(0, 0.03, 0)
		var strip := _mesh(self, _box(Vector3(BRIDGE_WIDTH, 0.06, 0.4)), _material(strip_color, 0.5), strip_centre)
		strip.basis = basis
		strips.append(strip)
	_bridges[_key(a, b)] = {
		"visual": visual, "collider": body.get_child(0), "strips": strips, "material": material, "kind": kind}

	#The sensor covers only the part of the bridge outside both platforms
	var sensor_shape := BoxShape3D.new()
	sensor_shape.size = Vector3(BRIDGE_WIDTH, 9.0, maxf(distance - radius_a - radius_b, 0.5))
	var sensor_centre := from + direction * ((radius_a + distance - radius_b) / 2.0) + Vector3(0, 3.8, 0)
	var area := _sensor(sensor_shape, Transform3D(basis, sensor_centre))
	for locator in locators:
		locator.watch_bridge(a, b, area)


#A belt flows from its first vertex to its second: the chevrons run that way
func _bridge_material(kind: StringName, length: float) -> StandardMaterial3D:
	if kind == Level01Layout.BELT:
		var belt := StandardMaterial3D.new()
		belt.albedo_texture = BELT_TEXTURE
		belt.roughness = 0.55
		belt.uv1_scale = Vector3(1.0, -length / BELT_TILE, 1.0)
		_belts.append(belt)
		return belt
	if kind == Level01Layout.FRAGILE:
		var fragile := _board_copy(CORAL)
		fragile.emission_enabled = true
		fragile.emission = Color("ff6f7d")
		fragile.emission_energy_multiplier = 0.2
		return fragile
	return _board(LILAC)


func _build_start_marks() -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[Level01Layout.START]
	var prism := PrismMesh.new()
	prism.size = Vector3(1.6, 1.4, 0.04)
	for step in 2:
		var arrow := _mesh(self, prism, _material(MAGENTA, 0.6), centre + Vector3(0, 0.04, -3.4 - step * 1.8))
		arrow.rotation_degrees.x = -90.0


#The bar of each spinner island: a striped tube that sweeps the floor around a pole
func _build_spinners() -> void:
	for id: StringName in Level01Layout.SPINNERS:
		var spinner: Dictionary = Level01Layout.SPINNERS[id]
		var pivot := Node3D.new()
		pivot.position = Level01Layout.POSITIONS[id] + Vector3(0, 0.02, 0)
		add_child(pivot)
		pivot.add_child(PropKit.make(&"bumper", Vector3(float(spinner["arm"]) * 2.0, Level01Hazards.BAR_HEIGHT, 0.6)))
		pivot.add_child(PropKit.make_tall(&"cone", 1.5))
		_spinners[id] = pivot


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


func _scatter_decor() -> void:
	var backdrop := Level01Backdrop.new()
	add_child(backdrop)
	backdrop.build()


#Names float over the stations so the player knows what each place is for: title, explanation, colour, place, height and reach
func _build_name_labels() -> void:
	var start: Vector3 = Level01Layout.POSITIONS[Level01Layout.START]
	var goal: Vector3 = Level01Layout.POSITIONS[Level01Layout.GOAL]
	var entries := [
		["SALIDA", "Aquí empiezas", Color("fdfbff"), start, 4.0, 30.0],
		["META", "Zona de desconexión", AMBER, goal, 8.0, 140.0],
		["BLOQUEAR", "Cierra un puente a los bots", MAGENTA, station_positions[&"block"], 3.7, 30.0],
		["SILENCIAR", "Los bots te ven menos", CYAN, station_positions[&"silence"], 3.7, 30.0],
		["PAUSA DIGITAL", "Refugio: nadie te empuja", AMBER, station_positions[&"refuge"], 4.6, 30.0],
		["CHECKPOINT", "Guarda tu progreso", AMBER, station_positions[&"checkpoint"], 4.9, 30.0],
	]
	for entry in entries:
		_label(entry[0], 54, entry[2], entry[3] + Vector3(0, entry[4], 0), entry[5])
		_label(entry[1], 30, Color("fdfbff"), entry[3] + Vector3(0, entry[4] - 0.8, 0), SUBTITLE_RANGE)


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
