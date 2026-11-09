class_name Level01World
extends Node3D

#Builds level 1 from Level01Layout: a round platform per vertex, a bridge per edge (plain, conveyor belt, slide or fragile), a cannon on some
#islands and a spinner on others

#Start and goal stand out from the lilac course: cool mint to leave, warm sun to arrive
const MINT := Color("86e8c6")
const MINT_DARK := Color("4cb797")
const SUN := Color("ffd27a")
const SUN_DARK := Color("e0a23d")
const CORAL := Color("ff7a85")
const SKY := Color("62b7ff")
const TEAL := Color("5fdcc0")
const LIME := Color("86e05f")
const AQUA := Color("4fd3e8")
const VIOLET := Color("a584ff")
const ROSE := Color("ff7fb2")
const TANGERINE := Color("ffa84f")
const CYAN := Color("4fd6e8")
const MAGENTA := Color("ee4fb8")
const AMBER := Color("ffc857")
#The colour of each island follows its stretch of the course, from mint at the start to gold at the goal
const TIERS := {
	&"N": MINT, &"O": TEAL, &"P": TEAL, &"Q": SKY, &"R": SKY, &"T": SKY, &"U": VIOLET, &"V": VIOLET, &"W": VIOLET,
	&"X": ROSE, &"Y": ROSE, &"Z": ROSE, &"S": SUN, &"A": TANGERINE, &"B": TANGERINE, &"C": TANGERINE,
	&"D": LIME, &"E": LIME, &"F": LIME, &"G": LIME, &"H": AQUA, &"I": AQUA, &"J": AQUA, &"K": ROSE, &"L": ROSE, &"M": SUN,
}
#Bridges are pale so the coloured islands stand out
const BRIDGE_COLOR := Color("fff2f7")
const EDGE_SHADER: Shader = preload("res://assets/shaders/edge_light.gdshader")
const CANDY_VERTEX: Shader = preload("res://assets/shaders/candy_vertex.gdshader")
const GLOW_VERTEX: Shader = preload("res://assets/shaders/tint_glow.gdshader")
const BOARD_TEXTURE: Texture2D = preload("res://assets/textures/board_checker.png")
const BELT_TEXTURE: Texture2D = preload("res://assets/textures/belt_chevrons.png")
const SLIDE_TEXTURE: Texture2D = preload("res://assets/textures/slide_chevrons.png")

#How far into a platform a bridge reaches, so there is no seam
const BRIDGE_OVERLAP := 0.25
const THICKNESS := 0.6
#The lights along the sides of a bridge: they say where its edge is, and flash when the bridge is about to fall
const EDGE_WIDTH := 0.2
const EDGE_HEIGHT := 0.07
#A light strip stands a little out of the side of its bridge and stops short of the islands, so it never shares a face with anything
const EDGE_LIFT := 0.012
const EDGE_TRIM := 0.2
#Where the marks of a belt or a fragile bridge sit: just past the rim of the island
const MARK_INSET := 0.45
const FALL_Y := -12.0
#Meters of bridge that one chevron of the belt covers
const BELT_TILE := 3.0
#The rails of a slide are this thick; the gate over its mouth is a ring this wide and this far in from the island
const RAIL_THICKNESS := 0.3
const GATE_RADIUS := 2.15
const GATE_INSET := 1.4
#The arc of a cannon is marked by this many hoops; the pad and the target are these wide
const HOOPS := 7
const CANNON_RADIUS := 1.6
const TARGET_RADIUS := 2.1
#How long a fragile bridge takes to drop out of sight or to come back, and how far it drops
const DROP_TIME := 0.5
const DROP_DEPTH := 9.0
#The padded block that sweeps a bridge: across the bridge, high and along it, which is what the hit test measures
const BLOCK_SIZE := Vector3(1.6, 0.9, 1.0)
#How far the block leans toward where it goes, at the most, in radians
const BLOCK_LEAN := 0.16

const NAME_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
#The islands over which a big sign tells the stretch of the course
const TIER_SIGNS: Array[StringName] = [&"Q", &"W", &"Z", &"S", &"B", &"I"]
#Distance up to which the explanation under a title is shown
const SUBTITLE_RANGE := 14.0
#The candy bumper around each island and the lights on it
const RIM_TUBE := 0.22
const RIM_HEIGHT := 0.4
const RIM_STRIPE := 1.5
#Room left in the bumper at the mouth of each bridge, on each side of it
const RIM_GAP := 0.3
const BULB_SPACING := 1.6
const BULB_HEIGHT := 0.44

var station_positions: Dictionary = {}
var refuge_center := Vector3.ZERO

var _materials: Dictionary = {}
var _barrier: MeshInstance3D
var _props: Level01Props
var _belt_speed := 2.6
var _clock := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
#"a|b" with the two ids in order -> what the bridge is made of
var _bridges: Dictionary = {}
var _belts: Array[StandardMaterial3D] = []
var _slides: Array[StandardMaterial3D] = []
#Every cannon by "from>to": its pad; and the materials of its hoops, which light up one after the other
var _cannons: Dictionary = {}
var _hoops: Array[StandardMaterial3D] = []
var _flashing: Dictionary = {}
var _spinners: Dictionary = {}
var _blocks: Array[Dictionary] = []
#The rolling balls with their lanes, the trampolines by island and the belts about to turn around
var _balls: Array[Dictionary] = []
var _pads: Dictionary = {}
var _belt_warning: Dictionary = {}
var _set: Level01Set
var _bulb_spots: Array[Transform3D] = []
var _bulb_colors: Array[Color] = []
var _bulb_phases: Array[float] = []
#The light strips of the bridges that do not fall: one box per side, drawn together
var _edge_spots: Array[Transform3D] = []
var _edge_colors: Array[Color] = []
#Islands and plain bridges are joined in a few meshes per stretch of the course, painted by vertex
var _merger := MeshMerger.new()
var _merged_materials: Dictionary = {}


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
	_build_balls()
	_build_pads()
	_build_cannons()
	_build_barrier()
	_build_name_labels()
	_scatter_decor()
	_set = Level01Set.new()
	add_child(_set)
	_set.build()
	add_child(PartyKit.bulbs(_bulb_spots, _bulb_colors, _bulb_phases))
	_commit_edge_lights()
	_merger.commit(self)


#The three lights of the gantry over the start follow the countdown, and the crowd roars when somebody arrives
func set_start_lights(count: int, go: bool) -> void:
	_set.set_start_lights(count, go)


func celebrate_finish() -> void:
	_set.celebrate()


func cheer(power: float) -> void:
	_set.cheer(power)


func set_block_visual(active: bool) -> void:
	_barrier.visible = active


func set_checkpoint_active(vertex: StringName, active: bool) -> void:
	_props.set_checkpoint_active(vertex, active)


#The station glows while its ability is working
func set_station_active(id: StringName, active: bool) -> void:
	_props.set_active(id, active)


#The bars turn with the clock of the round, the same one the rules use to hit
func update_hazards(time: float) -> void:
	for block in _blocks:
		var node: Node3D = block["node"]
		var pusher: Dictionary = block["pusher"]
		node.global_position = Level01Hazards.block_center(pusher, time)
		#It leans toward where it is going, like a padded thing that is being pushed along
		var lean := cos(TAU * time / float(pusher["period"]) + float(pusher["phase"])) * BLOCK_LEAN
		node.basis = (block["basis"] as Basis) * Basis(Vector3.BACK, lean)
	for id: StringName in _spinners:
		var pivot: Node3D = _spinners[id]
		pivot.rotation.y = -Level01Hazards.angle_at(Level01Layout.SPINNERS[id], time)
	for entry in _balls:
		_place_ball(entry, time)


#A belt flows from its first island to its second or, after turning around, the other way: its chevrons point where it goes
func set_belt_direction(a: StringName, b: StringName, forward: bool) -> void:
	var record: Dictionary = _bridges.get(_key(a, b), {})
	if record.is_empty() or record["kind"] != Level01Layout.BELT:
		return
	(record["material"] as StandardMaterial3D).uv1_scale.y = (-1.0 if forward else 1.0) * float(record["length"]) / BELT_TILE


#The arrows of a belt blink while it is about to turn around
func warn_belt(a: StringName, b: StringName, on: bool) -> void:
	var key := _key(a, b)
	if on:
		_belt_warning[key] = true
		return
	_belt_warning.erase(key)
	var record: Dictionary = _bridges.get(key, {})
	if record.has("material"):
		(record["material"] as StandardMaterial3D).emission_enabled = false


#The block of that bridge squashes when it hits somebody and springs back
func pulse_block(pusher: Dictionary) -> void:
	for block in _blocks:
		if block["pusher"] != pusher:
			continue
		var model: Node3D = block["model"]
		var tween := create_tween()
		tween.tween_property(model, "scale", Vector3(1.3, 0.6, 1.3), 0.06)
		tween.tween_property(model, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


#A trampoline squashes when somebody steps on it
func bounce_pad(id: StringName) -> void:
	var pad: Node3D = _pads.get(id)
	if pad == null:
		return
	var tween := create_tween()
	tween.tween_property(pad, "scale", Vector3(1.2, 0.45, 1.2), 0.06)
	tween.tween_property(pad, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


#A cannon squashes, blows a burst of confetti and booms when somebody is thrown
func fire_cannon(launch: Dictionary) -> void:
	var pad: Node3D = _cannons.get("%s>%s" % [launch["from"], launch["to"]])
	if pad == null:
		return
	var tween := create_tween()
	tween.tween_property(pad, "scale", Vector3(1.25, 0.4, 1.25), 0.07)
	tween.tween_property(pad, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	ImpactFx.confetti(self, pad.global_position + Vector3(0.0, 0.6, 0.0), 36, 55.0, 6.5)
	SynthSound.play(self, SynthSound.tone(150.0, 0.4, 480.0, 0.6), -4.0, 1.0)


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
		(record["edge_material"] as StandardMaterial3D).emission_energy_multiplier = 1.0


#A fragile bridge drops out of sight (no floor) or comes back
func set_bridge_open(a: StringName, b: StringName, open: bool) -> void:
	var record: Dictionary = _bridges.get(_key(a, b), {})
	if record.is_empty():
		return
	(record["collider"] as CollisionShape3D).set_deferred("disabled", not open)
	var visual: Node3D = record["visual"]
	var rest_y: float = record["rest_y"]
	var tween := create_tween()
	if open:
		visual.visible = true
		tween.tween_property(visual, "global_position:y", rest_y, DROP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(visual, "global_position:y", rest_y - DROP_DEPTH, DROP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(visual.hide)
	for strip: Node3D in record["strips"]:
		strip.visible = open


func _process(delta: float) -> void:
	_clock += delta
	for belt in _belts:
		belt.uv1_offset.y = fposmod(_clock * _belt_speed / BELT_TILE, 1.0)
	for slide in _slides:
		slide.uv1_offset.y = fposmod(_clock * Level01Layout.SLIDE_SPEED / BELT_TILE, 1.0)
	#A pulse of light runs along the hoops of every cannon, from the pad to the target
	for index in _hoops.size():
		var wave := maxf(0.0, sin(_clock * 6.0 - float(index % HOOPS) * 0.8))
		_hoops[index].emission_energy_multiplier = 0.9 + 2.2 * wave * wave
	for key: String in _flashing:
		var record: Dictionary = _bridges[key]
		(record["material"] as StandardMaterial3D).emission_energy_multiplier = 0.3 + 1.6 * absf(sin(_clock * 9.0))
		(record["edge_material"] as StandardMaterial3D).emission_energy_multiplier = 1.0 + 3.0 * absf(sin(_clock * 9.0))
	for key: String in _belt_warning:
		var belt := (_bridges[key] as Dictionary)["material"] as StandardMaterial3D
		belt.emission_enabled = true
		belt.emission = CORAL
		belt.emission_energy_multiplier = 0.2 + 1.4 * absf(sin(_clock * 10.0))


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
#A material of its own that can be changed later, unlike the shared ones of _material
func _material_copy(color: Color, emission: float, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission
	return material


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
	_body(shape, Transform3D(Basis.IDENTITY, centre + Vector3(0, -THICKNESS / 2.0, 0)))

	var is_start := id == Level01Layout.START
	var is_goal := id == Level01Layout.GOAL
	var top_color: Color = TIERS[id]
	var skirt_color := top_color.darkened(0.35)
	#The rim is white and one more colour that warns: gold to arrive, hot pink where a bar sweeps the island, the colour of the island elsewhere
	var rim_b := top_color.darkened(0.12)
	if is_goal:
		rim_b = AMBER
	elif Level01Layout.SPINNERS.has(id):
		rim_b = MAGENTA
	elif is_start:
		rim_b = MINT_DARK
	var top := CylinderMesh.new()
	top.top_radius = radius
	top.bottom_radius = radius
	top.height = THICKNESS
	top.radial_segments = 40
	top.rings = 1
	var body_at := centre + Vector3(0.0, -THICKNESS / 2.0, 0.0)
	_merger.add(&"board", _merged(&"board"), true, top, Transform3D(Basis.IDENTITY, body_at), top_color)

	var skirt := CylinderMesh.new()
	skirt.top_radius = radius * 0.97
	skirt.bottom_radius = radius * 0.5
	skirt.height = 1.6
	skirt.radial_segments = 40
	skirt.rings = 1
	_merger.add(&"skirt", _merged(&"skirt"), false, skirt, Transform3D(Basis.IDENTITY, body_at + Vector3(0.0, -THICKNESS / 2.0 - 0.8, 0.0)), skirt_color)

	#Two flat discs in the middle make a bullseye in lighter and plain tones of the colour of the island
	for ring in [[0.46, 0.28, 0.02], [0.3, 0.0, 0.027]]:
		var disc := CylinderMesh.new()
		disc.top_radius = radius * float(ring[0])
		disc.bottom_radius = disc.top_radius
		disc.height = 0.03
		disc.radial_segments = 40
		disc.rings = 1
		_merger.add(&"board", _merged(&"board"), false, disc, Transform3D(Basis.IDENTITY, centre + Vector3(0.0, float(ring[2]), 0.0)),
			top_color.lightened(float(ring[1])))

	_build_rim(body_at, id, radius, rim_b)
	_rim_lights(id, centre, radius)

	#A ring of light under the skirt, so the island hovers
	var underglow := TorusMesh.new()
	underglow.outer_radius = radius * 0.52
	underglow.inner_radius = radius * 0.52 - 0.22
	underglow.rings = 32
	underglow.ring_segments = 6
	_merger.add(&"glow", _merged(&"glow"), false, underglow, Transform3D(Basis.IDENTITY, body_at + Vector3(0.0, -THICKNESS / 2.0 - 1.55, 0.0)), rim_b.lightened(0.2))

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
	var width := Level01Layout.width_of(kind)
	var direction := (to - from)
	direction.y = 0.0
	var distance := direction.length()
	direction = direction.normalized()

	#The surface is a straight ramp from the edge of one island to the edge of the other, and reaches a little into each of them
	var run := distance - radius_a - radius_b
	var slope := (to.y - from.y) / maxf(run, 0.1)
	var start := from + direction * (radius_a - BRIDGE_OVERLAP) + Vector3(0.0, -slope * BRIDGE_OVERLAP, 0.0)
	var end := from + direction * (distance - radius_b + BRIDGE_OVERLAP)
	end.y = to.y + slope * BRIDGE_OVERLAP
	var basis := Basis.looking_at((end - start).normalized(), Vector3.UP)
	var length := start.distance_to(end)
	var centre := (start + end) / 2.0 - basis.y * THICKNESS / 2.0
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, THICKNESS, length)
	var body := _body(shape, Transform3D(basis, centre))
	var material: StandardMaterial3D = null
	var visual: MeshInstance3D = null
	if kind == Level01Layout.WALK or kind == Level01Layout.NARROW:
		#A bridge that never moves is part of the joined mesh of its stretch
		_merger.add(&"board", _merged(&"board"), true, _box(shape.size), Transform3D(basis, centre), BRIDGE_COLOR)
	else:
		material = _bridge_material(kind, length)
		visual = _mesh(body, _box(shape.size), material, Vector3.ZERO, true)
	var edge_material := _edge_material(kind)
	var edge_length := shape.size.z - 2.0 * (BRIDGE_OVERLAP + EDGE_TRIM)
	for side in [-1.0, 1.0]:
		var edge_at := Vector3(side * (width / 2.0 - EDGE_WIDTH / 2.0 + EDGE_LIFT), THICKNESS / 2.0, 0.0)
		if kind == Level01Layout.FRAGILE:
			_mesh(visual, _box(Vector3(EDGE_WIDTH, EDGE_HEIGHT, edge_length)), edge_material, edge_at)
		else:
			_edge_spots.append(Transform3D(basis.scaled_local(Vector3(EDGE_WIDTH, EDGE_HEIGHT, edge_length)), centre + basis * edge_at))
			_edge_colors.append(edge_material.albedo_color)

	if kind == Level01Layout.SLIDE:
		_build_slide_rails(basis, centre, width, length)
	#Marks where a belt, a slide or a fragile bridge starts, lying on the ramp just past each island
	var strips: Array[Node3D] = []
	if kind == Level01Layout.BELT or kind == Level01Layout.FRAGILE or kind == Level01Layout.SLIDE:
		var strip_color := MINT_DARK if kind == Level01Layout.BELT else MAGENTA
		if kind == Level01Layout.SLIDE:
			strip_color = SKY
		for along: float in [BRIDGE_OVERLAP + MARK_INSET, length - BRIDGE_OVERLAP - MARK_INSET]:
			var strip := _mesh(self, _box(Vector3(width, 0.05, 0.4)), _material(strip_color, 0.5), start - basis.z * along + basis.y * 0.03)
			strip.basis = basis
			strips.append(strip)
	_bridges[_key(a, b)] = {
		"visual": visual, "collider": body.get_child(0), "strips": strips, "material": material, "kind": kind,
		"edge_material": edge_material, "rest_y": centre.y, "length": length}

	#The sensor covers only the part of the bridge outside both platforms, as high as the ramp needs
	var sensor_shape := BoxShape3D.new()
	sensor_shape.size = Vector3(width, 9.0, maxf(length - 2.0 * BRIDGE_OVERLAP, 0.5))
	var sensor_centre := (start + end) / 2.0 + basis.y * 3.8
	var area := _sensor(sensor_shape, Transform3D(basis, sensor_centre))
	for locator in locators:
		locator.watch_bridge(a, b, area)
	var pusher := Level01Layout.pusher_of(a, b)
	if not pusher.is_empty() and not _has_block(pusher):
		_build_block(pusher)


#The rails of a slide keep whoever rides it on: a padded wall on each side, a light along its top and a ring over the mouth
func _build_slide_rails(basis: Basis, centre: Vector3, width: float, length: float) -> void:
	var rail_length := length - 2.0 * (BRIDGE_OVERLAP + EDGE_TRIM)
	var shape := BoxShape3D.new()
	shape.size = Vector3(RAIL_THICKNESS, Level01Layout.SLIDE_RAIL, rail_length)
	var surface := centre + basis.y * THICKNESS / 2.0
	for side in [-1.0, 1.0]:
		var at: Vector3 = surface + basis.x * side * (width / 2.0 - RAIL_THICKNESS / 2.0) + basis.y * Level01Layout.SLIDE_RAIL / 2.0
		_body(shape, Transform3D(basis, at))
		_merger.add(&"board", _merged(&"board"), true, _box(shape.size), Transform3D(basis, at), SKY.lightened(0.55))
		var light_at := Vector3(side * (width / 2.0 - RAIL_THICKNESS / 2.0), THICKNESS / 2.0 + Level01Layout.SLIDE_RAIL + EDGE_HEIGHT / 2.0, 0.0)
		_edge_spots.append(Transform3D(basis.scaled_local(Vector3(RAIL_THICKNESS * 0.7, EDGE_HEIGHT, rail_length)), centre + basis * light_at))
		_edge_colors.append(Color("b8dcff"))
	#A glowing ring marks the mouth, and the slide goes through it
	var ring := TorusMesh.new()
	ring.inner_radius = GATE_RADIUS - 0.14
	ring.outer_radius = GATE_RADIUS + 0.14
	ring.rings = 36
	ring.ring_segments = 8
	var gate_at := surface + basis.z * (length / 2.0 - BRIDGE_OVERLAP - GATE_INSET) + basis.y * 0.2
	var gate := _mesh(self, ring, _material(SKY.lightened(0.3), 1.4), gate_at, false)
	gate.basis = basis * Basis(Vector3.RIGHT, PI / 2.0)


func _commit_edge_lights() -> void:
	var strip := BoxMesh.new()
	var material := ShaderMaterial.new()
	material.shader = EDGE_SHADER
	strip.material = material
	var places: Array[Vector3] = []
	for spot in _edge_spots:
		places.append(spot.origin)
	var groups := MeshMerger.cells(places)
	for cell: int in groups:
		var members: Array[int] = groups[cell]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = strip
		multi.instance_count = members.size()
		for slot in members.size():
			multi.set_instance_transform(slot, _edge_spots[members[slot]])
			multi.set_instance_color(slot, _edge_colors[members[slot]])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


func _has_block(pusher: Dictionary) -> bool:
	for block in _blocks:
		if block["pusher"] == pusher:
			return true
	return false


#The block that sweeps a bridge: a padded striped cushion that goes from one side to the other along a rail with a yellow bumper at each end
func _build_block(pusher: Dictionary) -> void:
	var track := Level01Hazards.block_track(pusher)
	var tangent: Vector3 = track["tangent"]
	var ramp := Basis.looking_at(tangent, Vector3.UP)
	var side: Vector3 = track["side"]
	var reach: float = track["reach"]
	var centre: Vector3 = track["centre"]
	var holder := Node3D.new()
	add_child(holder)
	var model := PropKit.make(&"foam_block", BLOCK_SIZE)
	holder.add_child(model)
	_blocks.append({"node": holder, "model": model, "pusher": pusher, "basis": ramp})
	holder.global_position = Level01Hazards.block_center(pusher, 0.0)
	holder.basis = ramp
	#The rail lies on the surface across the whole path of the block and the bumpers stand at its ends
	var rail_width := (reach + BLOCK_SIZE.x / 2.0 + 0.15) * 2.0
	var rail := _mesh(self, _box(Vector3(rail_width, 0.03, BLOCK_SIZE.z + 0.45)), PartyKit.paint(PartyKit.INK, 0.0, 0.6), centre + ramp.y * 0.02)
	rail.basis = ramp
	var bumper := CylinderMesh.new()
	bumper.top_radius = 0.17
	bumper.bottom_radius = 0.2
	bumper.height = 0.42
	bumper.radial_segments = 14
	bumper.rings = 1
	for way in [-1.0, 1.0]:
		var post := _mesh(self, bumper, PartyKit.paint(PartyKit.YELLOW, 0.8, 0.35), centre + side * (rail_width / 2.0) * way + ramp.y * 0.2, true)
		post.basis = ramp


#One light colour per kind of bridge: cool for a plain one, mint for a belt and coral for a fragile one
func _edge_material(kind: StringName) -> StandardMaterial3D:
	var color := Color("7ae6ff")
	if kind == Level01Layout.SLIDE:
		color = Color("8ec5ff")
	elif kind == Level01Layout.BELT:
		color = Color("4cf2b0")
	elif kind == Level01Layout.FRAGILE:
		color = Color("ff6f7d")
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.0
	material.roughness = 0.4
	return material


#A belt flows from its first vertex to its second: the chevrons run that way
func _bridge_material(kind: StringName, length: float) -> StandardMaterial3D:
	if kind == Level01Layout.BELT:
		var belt := StandardMaterial3D.new()
		belt.albedo_texture = BELT_TEXTURE
		belt.roughness = 0.55
		belt.uv1_scale = Vector3(1.0, -length / BELT_TILE, 1.0)
		_belts.append(belt)
		return belt
	if kind == Level01Layout.SLIDE:
		var slide := StandardMaterial3D.new()
		slide.albedo_texture = SLIDE_TEXTURE
		slide.roughness = 0.35
		slide.emission_enabled = true
		slide.emission_texture = SLIDE_TEXTURE
		slide.emission_energy_multiplier = 0.25
		slide.uv1_scale = Vector3(1.0, -length / BELT_TILE, 1.0)
		_slides.append(slide)
		return slide
	if kind == Level01Layout.FRAGILE:
		var fragile := _board_copy(CORAL)
		fragile.emission_enabled = true
		fragile.emission = Color("ff6f7d")
		fragile.emission_energy_multiplier = 0.2
		return fragile
	return _board(BRIDGE_COLOR)


#The bumper around an island, in the colour of what the island is for, with a gap where each bridge comes in
func _build_rim(body_at: Vector3, id: StringName, radius: float, color: Color) -> void:
	var arcs := _free_arcs(_mouths(id, radius, RIM_GAP))
	if arcs.is_empty():
		return
	var ring := radius - 0.12
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arc in arcs:
		PartyKit.add_arc_tube(tool, ring, RIM_TUBE, arc.x, arc.y, maxi(2, ceili((arc.y - arc.x) * ring / 0.6)), 8)
	_merger.add(&"rim", _merged(&"rim"), false, tool.commit(), Transform3D(Basis.IDENTITY, body_at + Vector3(0.0, RIM_HEIGHT, 0.0)), color,
		Vector2(roundf(TAU * radius / RIM_STRIPE), 1.0))


#The materials of the joined meshes: they read the colour of each vertex, so one serves every island and bridge
func _merged(kind: StringName) -> Material:
	if _merged_materials.has(kind):
		return _merged_materials[kind]
	var material: Material
	if kind == &"board":
		var board := _board_copy(Color.WHITE)
		board.vertex_color_use_as_albedo = true
		board.vertex_color_is_srgb = true
		material = board
	elif kind == &"skirt":
		var skirt := StandardMaterial3D.new()
		skirt.roughness = 0.6
		skirt.vertex_color_use_as_albedo = true
		skirt.vertex_color_is_srgb = true
		material = skirt
	elif kind == &"rim":
		material = ShaderMaterial.new()
		(material as ShaderMaterial).shader = CANDY_VERTEX
	else:
		material = ShaderMaterial.new()
		(material as ShaderMaterial).shader = GLOW_VERTEX
	_merged_materials[kind] = material
	return material


#Where the bridges of an island start on its rim: the angle toward each one and half of the angle it covers, with "margin" meters on each side
func _mouths(id: StringName, radius: float, margin: float) -> Array[Vector2]:
	var found: Array[Vector2] = []
	var centre: Vector3 = Level01Layout.POSITIONS[id]
	for edge in Level01Layout.EDGES:
		if edge[0] != id and edge[1] != id:
			continue
		var other: StringName = edge[1] if edge[0] == id else edge[0]
		var to: Vector3 = Level01Layout.POSITIONS[other] - centre
		var half := asin(minf((Level01Layout.width_of(edge[4]) / 2.0 + margin) / radius, 1.0))
		found.append(Vector2(atan2(to.z, to.x), half))
	return found


#The stretches of the circle that no mouth covers, as (from, to) angles; the one that crosses the zero angle goes past TAU
func _free_arcs(mouths: Array[Vector2]) -> Array[Vector2]:
	var covered: Array[Vector2] = []
	for mouth in mouths:
		var start := fposmod(mouth.x - mouth.y, TAU)
		var end := start + mouth.y * 2.0
		if end > TAU:
			covered.append(Vector2(start, TAU))
			covered.append(Vector2(0.0, end - TAU))
		else:
			covered.append(Vector2(start, end))
	covered.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var merged: Array[Vector2] = []
	for span in covered:
		if not merged.is_empty() and span.x <= merged[-1].y:
			merged[-1] = Vector2(merged[-1].x, maxf(merged[-1].y, span.y))
		else:
			merged.append(span)
	var free: Array[Vector2] = []
	if merged.is_empty():
		free.append(Vector2(0.0, TAU))
		return free
	for index in merged.size() - 1:
		free.append(Vector2(merged[index].y, merged[index + 1].x))
	if merged[0].x > 0.0 or merged[-1].y < TAU:
		free.append(Vector2(merged[-1].y, merged[0].x + TAU))
	return free.filter(func(arc: Vector2) -> bool: return arc.y - arc.x > 0.08)


#Little lights along the rim of an island, left out where a bridge comes in
func _rim_lights(id: StringName, centre: Vector3, radius: float) -> void:
	var mouths := _mouths(id, radius, 0.5)
	var count := roundi(TAU * radius / BULB_SPACING)
	for step in count:
		var angle := TAU * step / count
		var blocked := false
		for mouth in mouths:
			if absf(angle_difference(angle, mouth.x)) < mouth.y:
				blocked = true
		if blocked:
			continue
		var ring := radius - 0.12
		_bulb_spots.append(Transform3D(Basis.IDENTITY, centre + Vector3(cos(angle) * ring, BULB_HEIGHT - 0.3 + 0.28, sin(angle) * ring)))
		_bulb_colors.append(PartyKit.PALETTE[(step + int(absf(centre.z))) % PartyKit.PALETTE.size()])
		_bulb_phases.append(angle * 3.0 + centre.z * 0.12)


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


#Each rolling ball: a faint track on the floor along a diameter of its island, a bright stud at each end and a candy sphere that rolls along it
func _build_balls() -> void:
	for ball: Dictionary in Level01Layout.BALLS:
		var island: Vector3 = Level01Layout.POSITIONS[ball["island"]]
		var lane := Level01Hazards.ball_lane(ball)
		var half := Level01Hazards.ball_half_lane(ball)
		var strip_material := StandardMaterial3D.new()
		strip_material.albedo_color = Color(MAGENTA, 0.3)
		strip_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var width := Level01Layout.BALL_RADIUS * 2.0 + 0.3
		var strip := _mesh(self, _box(Vector3(width, 0.02, half * 2.0)), strip_material, island + Vector3(0.0, 0.03, 0.0))
		strip.basis = Basis.looking_at(lane["along"] as Vector3, Vector3.UP)
		var stud := CylinderMesh.new()
		stud.top_radius = 0.38
		stud.bottom_radius = 0.38
		stud.height = 0.05
		stud.radial_segments = 20
		stud.rings = 1
		for way in [-1.0, 1.0]:
			_mesh(self, stud, PartyKit.paint(MAGENTA, 1.1, 0.4), island + (lane["along"] as Vector3) * half * way + Vector3(0.0, 0.04, 0.0))
		var sphere := SphereMesh.new()
		sphere.radius = Level01Layout.BALL_RADIUS
		sphere.height = Level01Layout.BALL_RADIUS * 2.0
		sphere.radial_segments = 20
		sphere.rings = 10
		var rolling := _mesh(self, sphere, PartyKit.candy(Color("fdfbff"), MAGENTA, 6.0, 0.0, 0.3), island, true)
		var entry := {"ball": ball, "ball_node": rolling}
		_balls.append(entry)
		_place_ball(entry, 0.0)


#The ball rolls along its diameter, turning as far as it has gone
func _place_ball(entry: Dictionary, time: float) -> void:
	var ball: Dictionary = entry["ball"]
	var node: MeshInstance3D = entry["ball_node"]
	var centre := Level01Hazards.ball_center(ball, time)
	var along := Level01Hazards.ball_lane(ball)["along"] as Vector3
	var island: Vector3 = Level01Layout.POSITIONS[ball["island"]]
	node.global_position = centre
	node.basis = Basis(Vector3.UP.cross(along).normalized(), (centre - island).dot(along) / Level01Layout.BALL_RADIUS)


#A trampoline: a candy cushion with a bright pad on top, on the quiet side of its island
func _build_pads() -> void:
	for id: StringName in Level01Layout.PADS:
		var pad := Node3D.new()
		pad.position = Level01Layout.pad_position(id)
		add_child(pad)
		var cushion := CylinderMesh.new()
		cushion.top_radius = 0.95
		cushion.bottom_radius = 1.05
		cushion.height = 0.22
		cushion.radial_segments = 24
		cushion.rings = 1
		_mesh(pad, cushion, PartyKit.candy(Color("fdfbff"), CYAN, 10.0, 0.0, 0.2), Vector3(0.0, 0.11, 0.0), true)
		var surface := CylinderMesh.new()
		surface.top_radius = 0.78
		surface.bottom_radius = 0.78
		surface.height = 0.06
		surface.radial_segments = 24
		surface.rings = 1
		_mesh(pad, surface, _material(AMBER, 1.2), Vector3(0.0, 0.23, 0.0))
		_pads[id] = pad


#Each cannon: a pad on its island with arrows toward where it throws, a row of hoops along the arc it flies, and a target ring where it lands
func _build_cannons() -> void:
	var cushion := CylinderMesh.new()
	cushion.top_radius = CANNON_RADIUS
	cushion.bottom_radius = CANNON_RADIUS + 0.12
	cushion.height = 0.26
	cushion.radial_segments = 28
	cushion.rings = 1
	var surface := CylinderMesh.new()
	surface.top_radius = CANNON_RADIUS - 0.2
	surface.bottom_radius = CANNON_RADIUS - 0.2
	surface.height = 0.06
	surface.radial_segments = 28
	surface.rings = 1
	var arrow := PrismMesh.new()
	arrow.size = Vector3(1.2, 1.2, 0.04)
	var hoop := TorusMesh.new()
	hoop.inner_radius = 1.35
	hoop.outer_radius = 1.75
	hoop.rings = 28
	hoop.ring_segments = 8
	var target := TorusMesh.new()
	target.inner_radius = TARGET_RADIUS - 0.16
	target.outer_radius = TARGET_RADIUS
	target.rings = 36
	target.ring_segments = 6
	for launch: Dictionary in Level01Layout.LAUNCHES:
		var spot := Level01Layout.launch_pad(launch)
		var aim := Level01Layout.launch_landing(launch) - spot
		aim.y = 0.0
		aim = aim.normalized()
		var pad := Node3D.new()
		pad.position = spot
		add_child(pad)
		_mesh(pad, cushion, PartyKit.candy(Color("fdfbff"), AMBER, 10.0, 0.0, 0.2), Vector3(0.0, 0.13, 0.0), true)
		_mesh(pad, surface, _material(AMBER, 1.3), Vector3(0.0, 0.27, 0.0))
		var flat := Basis.looking_at(aim, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2.0)
		var cushion_mark := _mesh(pad, arrow, _material(Color("fdfbff"), 0.8), Vector3(0.0, 0.31, 0.0))
		cushion_mark.basis = flat
		#Arrows painted on the floor lead from the middle of the island to the pad
		for step in 3:
			var painted := _mesh(self, arrow, _material(AMBER, 0.9), spot - aim * (2.6 + step * 1.6) + Vector3(0.0, 0.045, 0.0))
			painted.basis = flat
		_cannons["%s>%s" % [launch["from"], launch["to"]]] = pad
		for index in HOOPS:
			var seconds := float(launch["time"]) * float(index + 1) / float(HOOPS + 1)
			var at := Level01Hazards.launch_point(launch, seconds, _gravity)
			var heading := Level01Hazards.launch_velocity(launch, _gravity) - Vector3(0.0, _gravity * seconds, 0.0)
			var material := _material_copy(AMBER, 1.0, 0.95)
			_hoops.append(material)
			var ring := _mesh(self, hoop, material, at + Vector3(0.0, 0.9, 0.0))
			ring.basis = Basis.looking_at(heading.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0)
		var landing := Level01Layout.launch_landing(launch)
		_mesh(self, target, _material(AMBER, 1.2), landing + Vector3(0.0, 0.05, 0.0))
		var core := _mesh(self, target, _material(Color("fdfbff"), 0.8), landing + Vector3(0.0, 0.055, 0.0))
		core.scale = Vector3(0.55, 1.0, 0.55)


#A translucent wall across the bridge that Bloquear closes for the bots
func _build_barrier() -> void:
	var a: Vector3 = Level01Layout.POSITIONS[Level01Layout.BLOCK_EDGE[0]]
	var b: Vector3 = Level01Layout.POSITIONS[Level01Layout.BLOCK_EDGE[1]]
	var direction := (b - a)
	direction.y = 0.0
	direction = direction.normalized()
	_barrier = _mesh(self, _box(Vector3(Level01Layout.WIDE_WIDTH + 0.4, 1.8, 0.2)), _material(MAGENTA, 1.3, 0.38),
		(a + b) / 2.0 + Vector3(0, 0.9, 0))
	_barrier.basis = Basis.looking_at(direction, Vector3.UP)
	_barrier.visible = false


func _scatter_decor() -> void:
	var backdrop := Level01Backdrop.new()
	add_child(backdrop)
	backdrop.build()


#Names float over the stations so the player knows what each place is for: title, explanation, colour, place, height and reach
func _build_name_labels() -> void:
	var goal: Vector3 = Level01Layout.POSITIONS[Level01Layout.GOAL]
	var entries := [
		["META", "Zona de desconexión", AMBER, goal, 8.0, 140.0],
		["BLOQUEAR", "Cierra un puente a los bots", MAGENTA, station_positions[&"block"], 3.7, 30.0],
		["SILENCIAR", "Los bots te ven menos", CYAN, station_positions[&"silence"], 3.7, 30.0],
		["PAUSA DIGITAL", "Refugio: nadie te empuja", AMBER, station_positions[&"refuge"], 4.6, 30.0],
	]
	for launch: Dictionary in Level01Layout.LAUNCHES:
		entries.append(["CAÑÓN", "Te lanza a la isla %s" % launch["to"], AMBER, Level01Layout.launch_pad(launch), 3.4, 30.0])
	for edge in Level01Layout.EDGES:
		if edge[4] == Level01Layout.SLIDE:
			entries.append(["TOBOGÁN", "Solo baja, y muy rápido", SKY, Level01Layout.POSITIONS[edge[0]], 5.2, 30.0])
	for vertex: StringName in _props.checkpoint_positions:
		entries.append(["CHECKPOINT", "Guarda tu progreso", AMBER, _props.checkpoint_positions[vertex], 4.9, 30.0])
	for entry in entries:
		_label(entry[0], 54, entry[2], entry[3] + Vector3(0, entry[4], 0), entry[5])
		_label(entry[1], 30, Color("fdfbff"), entry[3] + Vector3(0, entry[4] - 0.8, 0), SUBTITLE_RANGE)
	#Big signs over the islands where each stretch of the course starts, in the colour of that stretch
	for index in TIER_SIGNS.size():
		var vertex: StringName = TIER_SIGNS[index]
		var sign_label := Label3D.new()
		sign_label.text = "TRAMO %d" % (index + 1)
		sign_label.font = NAME_FONT
		sign_label.font_size = 200
		sign_label.pixel_size = 0.014
		sign_label.modulate = (TIERS[vertex] as Color).lightened(0.35)
		sign_label.outline_size = 36
		sign_label.outline_modulate = Color("2a2145")
		sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign_label.position = (Level01Layout.POSITIONS[vertex] as Vector3) + Vector3(0.0, 13.0, 0.0)
		#A sign is only for reading from near: it fades out smoothly as it gets far so the signs of the whole course never pile up
		sign_label.visibility_range_end = 90.0
		sign_label.visibility_range_end_margin = 30.0
		sign_label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(sign_label)


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
	label.no_depth_test = false
	label.position = at
	#Fades out with distance so far labels never pile up on the screen
	label.visibility_range_end = visible_range
	label.visibility_range_end_margin = visible_range * 0.25
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(label)
