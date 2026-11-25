class_name Level01World
extends Node3D

#Builds level 1 from Level01Layout: plates, islands, bridges, decks and every obstacle

#Start mint and goal sun stand out from the lilac course
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
#Island colours by stretch, from mint at the start to gold at the goal, one per way
const TIERS := {
	&"N": MINT, &"Aw": ROSE, &"A1": ROSE, &"A2": ROSE, &"A3": ROSE, &"A4": ROSE, &"Ax": ROSE,
	&"B1": SKY, &"B2": SKY, &"B3": SKY, &"Ce": VIOLET, &"C1": VIOLET, &"C2": VIOLET, &"C3": VIOLET, &"C4": VIOLET, &"Cx": VIOLET,
	&"S": SUN, &"h1": AQUA, &"h2": AQUA, &"z1": AQUA, &"z2": AQUA,
	&"An": TANGERINE, &"A5": TANGERINE, &"A6": TANGERINE, &"A7": TANGERINE, &"A8": TANGERINE, &"Ay": TANGERINE,
	&"Bn": LIME, &"B5": LIME, &"B6": LIME, &"B7": LIME, &"B8": LIME, &"Cn": AQUA, &"C5": AQUA, &"C6": AQUA, &"C7": AQUA, &"C8": AQUA, &"Cy": AQUA,
	&"E": SUN, &"M": SUN,
}
#Pale bridges so the islands stand out
const BRIDGE_COLOR := Color("fff2f7")
const EDGE_SHADER: Shader = preload("res://assets/shaders/edge_light.gdshader")
const CANDY_VERTEX: Shader = preload("res://assets/shaders/candy_vertex.gdshader")
const GLOW_VERTEX: Shader = preload("res://assets/shaders/tint_glow.gdshader")
const BOARD_TEXTURE: Texture2D = preload("res://assets/textures/board_checker.png")
const BELT_TEXTURE: Texture2D = preload("res://assets/textures/belt_chevrons.png")
const SLIDE_TEXTURE: Texture2D = preload("res://assets/textures/slide_chevrons.png")

#Bridge overlap into a platform, so there is no seam
const BRIDGE_OVERLAP := 0.25
#Bridges sit a hair low to avoid flicker
const SEAM_DROP := 0.02
const THICKNESS := 0.6
#Edge lights mark the bridge edge and flash before a fall
const EDGE_WIDTH := 0.2
const EDGE_HEIGHT := 0.07
#Light strips stand out a little and stop short of islands
const EDGE_LIFT := 0.012
const EDGE_TRIM := 0.2
#Belt and fragile marks just past the island rim
const MARK_INSET := 0.45
const FALL_Y := -12.0
#Bridge meters per belt chevron
const BELT_TILE := 3.0
#Slide rail thickness and mouth ring size
const RAIL_THICKNESS := 0.3
const GATE_RADIUS := 2.15
const GATE_INSET := 1.4
#Safety decks look like inflatable pools so a fall reads as a catch
const DECK_COLOR := Color("8fe3cf")
const DECK_RING := Color("4fc6e8")
const DECK_RING_TOP := Color("ff8fc4")
const DECK_RING_TOP_TUBE := 0.32
const LIFT_PAD_RADIUS := 1.4
#Solid letters of the goal name and of the fall warning
const GOAL_WORD_HEIGHT := 3.4
const GOAL_WORD_DEPTH := 0.6
const SATURATED_DEPTH := 0.2
#Fragile bridge drop time and depth
const DROP_TIME := 0.5
const DROP_DEPTH := 9.0
#Sweeping block size across, high and along
const BLOCK_SIZE := Vector3(1.6, 0.9, 1.0)
const BELL_HEIGHT := 1.0
#Block lean toward its way, in radians
const BLOCK_LEAN := 0.16

#Comment word size on its bubble
const COMMENT_WORD_HEIGHT := 0.8
const COMMENT_WORD_WIDTH := 1.6
const BUBBLE_SHADER: Shader = preload("res://assets/shaders/bubble.gdshader")
#Ride bubble and the small bubble over each pad
const LIFT_BUBBLE_RADIUS := 0.95
const PAD_BUBBLE_RADIUS := 0.5
const PAD_BUBBLE_HEIGHT := 1.9
#Board height of the way and slide arches
const WAY_SIGN_HEIGHT := 4.7
const SLIDE_SIGN_HEIGHT := 4.7
#Island bumper and its lights
const RIM_TUBE := 0.22
const RIM_HEIGHT := 0.4
const RIM_STRIPE := 1.5
#Bumper gap beside each bridge mouth
const RIM_GAP := 0.3
const BULB_SPACING := 1.6
const BULB_HEIGHT := 0.44

var _materials: Dictionary = {}
var _props: Level01Props
var _traps: Level01TrapView
var _belt_speed := 2.6
var _clock := 0.0
#"a|b" -> bridge parts
var _bridges: Dictionary = {}
var _belts: Array[StandardMaterial3D] = []
var _slides: Array[StandardMaterial3D] = []
#Pad of each deck by its bridge
var _lift_pads: Dictionary = {}
var _flashing: Dictionary = {}
var _spinners: Dictionary = {}
var _blocks: Array[Dictionary] = []
#Rolling balls, trampolines and belts about to turn
var _balls: Array[Dictionary] = []
#Comment bubbles and saturated signs per bridge
var _comments: Array[Dictionary] = []
var _saturated: Dictionary = {}
var _belt_warning: Dictionary = {}
var _set: Level01Set
var _bulb_spots: Array[Transform3D] = []
var _bulb_colors: Array[Color] = []
var _bulb_phases: Array[float] = []
#Light strips of bridges that never fall, drawn together
var _edge_spots: Array[Transform3D] = []
var _edge_colors: Array[Color] = []
#Islands and plain bridges joined per stretch, painted by vertex
var _merger := MeshMerger.new()
var _merged_materials: Dictionary = {}
#Way plates and cup walls use the candy ground
var _terrain: CandyTerrain


#Each racer has its own locator fed by the sensors
func build(locators: Array[PlayerLocator], belt_speed: float, tiles: Level01Tiles) -> void:
	_belt_speed = belt_speed
	_terrain = CandyTerrain.new(self)
	for id: StringName in Level01Layout.POSITIONS:
		if Level01Layout.is_plate(id):
			_build_plate(id, locators)
		else:
			_build_platform(id, locators)
		if Level01Layout.CUPS.has(id):
			_build_cup_wall(id)
	for edge in Level01Layout.EDGES:
		_build_bridge(edge[0], edge[1], edge[4], locators)
	_build_start_marks()
	_props = Level01Props.new()
	add_child(_props)
	_props.build()
	_build_spinners()
	_build_balls()
	_build_decks()
	_build_lift_pads()
	_build_comments()
	_traps = Level01TrapView.new()
	add_child(_traps)
	_traps.build(tiles)
	_build_name_labels()
	_scatter_decor()
	_set = Level01Set.new()
	add_child(_set)
	_set.build()
	add_child(PartyKit.bulbs(_bulb_spots, _bulb_colors, _bulb_phases))
	_commit_edge_lights()
	_merger.commit(self)
	_terrain.commit()


#Gantry lights follow the countdown; the crowd roars at arrivals
func set_start_lights(count: int, go: bool) -> void:
	_set.set_start_lights(count, go)


func celebrate_finish() -> void:
	_set.celebrate()


func cheer(power: float) -> void:
	_set.cheer(power)


func set_checkpoint_active(vertex: StringName, active: bool) -> void:
	_props.set_checkpoint_active(vertex, active)


#Everything moves with the round clock the rules use
func update_hazards(time: float, tiles: Level01Tiles) -> void:
	_traps.update(time, tiles)
	for block in _blocks:
		var node: Node3D = block["node"]
		var pusher: Dictionary = block["pusher"]
		node.global_position = Level01Hazards.block_center(pusher, time)
		#Leans toward its way like something pushed
		var lean := cos(TAU * time / float(pusher["period"]) + float(pusher["phase"])) * BLOCK_LEAN
		node.basis = (block["basis"] as Basis) * Basis(Vector3.BACK, lean)
	for id: StringName in _spinners:
		var pivot: Node3D = _spinners[id]
		pivot.rotation.y = -Level01Hazards.angle_at(Level01Layout.SPINNERS[id], time)
	for entry in _balls:
		_place_ball(entry, time)
	for entry in _comments:
		_update_comment(entry, time)


#Chevrons point where the belt flows
func set_belt_direction(a: StringName, b: StringName, forward: bool) -> void:
	var record: Dictionary = _bridges.get(_key(a, b), {})
	if record.is_empty() or record["kind"] != Level01Layout.BELT:
		return
	(record["material"] as StandardMaterial3D).uv1_scale.y = (-1.0 if forward else 1.0) * float(record["length"]) / BELT_TILE


#Belt arrows blink before turning
func warn_belt(a: StringName, b: StringName, on: bool) -> void:
	var key := _key(a, b)
	if on:
		_belt_warning[key] = true
		return
	_belt_warning.erase(key)
	var record: Dictionary = _bridges.get(key, {})
	if record.has("material"):
		(record["material"] as StandardMaterial3D).emission_enabled = false


#The block squashes on a hit
func pulse_block(pusher: Dictionary) -> void:
	for block in _blocks:
		if block["pusher"] != pusher:
			continue
		var model: Node3D = block["model"]
		var tween := create_tween()
		tween.tween_property(model, "scale", Vector3(1.3, 0.6, 1.3), 0.06)
		tween.tween_property(model, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


#Ride bubble that swells in around the body
func lift_bubble() -> Node3D:
	var ball := SphereMesh.new()
	ball.radius = LIFT_BUBBLE_RADIUS
	ball.height = LIFT_BUBBLE_RADIUS * 2.0
	ball.radial_segments = 24
	ball.rings = 12
	var bubble := MeshInstance3D.new()
	bubble.mesh = ball
	bubble.material_override = _bubble_material()
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubble.position = Vector3(0.0, 0.85, 0.0)
	bubble.scale = Vector3.ONE * 0.2
	bubble.create_tween().tween_property(bubble, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return bubble


#Pop with confetti and a plop
func pop_bubble(bubble: Node3D) -> void:
	if not is_instance_valid(bubble):
		return
	ImpactFx.confetti(self, bubble.global_position, 24, 55.0, 4.0)
	SynthSound.play(self, SynthSound.tone(520.0, 0.18, 900.0, 0.5), -9.0)
	bubble.queue_free()


func _bubble_material() -> ShaderMaterial:
	var shell := ShaderMaterial.new()
	shell.shader = BUBBLE_SHADER
	shell.set_shader_parameter("tint", Color("bfe9ff"))
	shell.set_shader_parameter("glow", 1.3)
	return shell


#Deck pad squash, confetti and sound
func squash_lift_pad(lift: Dictionary) -> void:
	var pad: Node3D = _lift_pads.get(_key(lift["edge"][0], lift["edge"][1]))
	if pad == null:
		return
	var tween := create_tween()
	tween.tween_property(pad, "scale", Vector3(1.25, 0.4, 1.25), 0.07)
	tween.tween_property(pad, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	ImpactFx.confetti(self, pad.global_position + Vector3(0.0, 0.6, 0.0), 36, 55.0, 6.5)
	SynthSound.play(self, SynthSound.tone(150.0, 0.4, 480.0, 0.6), -4.0, 1.0)


#A fragile bridge flashes with a saturated sign until it returns
func flash_bridge(a: StringName, b: StringName, on: bool) -> void:
	var key := _key(a, b)
	if on:
		_flashing[key] = true
		_show_saturated(a, b)
		return
	_flashing.erase(key)
	var record: Dictionary = _bridges.get(key, {})
	if record.has("material"):
		(record["material"] as StandardMaterial3D).emission_energy_multiplier = 0.2
		(record["edge_material"] as StandardMaterial3D).emission_energy_multiplier = 1.0


#Fragile bridge drops out of sight or comes back
func set_bridge_open(a: StringName, b: StringName, open: bool) -> void:
	var record: Dictionary = _bridges.get(_key(a, b), {})
	if record.is_empty():
		return
	(record["collider"] as CollisionShape3D).set_deferred("disabled", not open)
	var visual: Node3D = record["visual"]
	var rest_y: float = record["rest_y"]
	var tween := create_tween()
	if open:
		if _saturated.has(_key(a, b)):
			(_saturated[_key(a, b)] as Node3D).hide()
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


#Own material that can change later
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
	#White rim plus a warning colour: gold to arrive, hot pink with a bar
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

	#Bullseye of two discs
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

	#Light ring under the skirt so the island hovers
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

	#Straight ramp between platform edges, reaching round rims without notches
	var run := distance - radius_a - radius_b
	var slope := (to.y - from.y) / maxf(run, 0.1)
	var inset_a := radius_a if slope < -0.001 else _bridge_inset(a, width)
	var inset_b := radius_b if slope > 0.001 else _bridge_inset(b, width)
	if slope < -0.001:
		_build_apron(a, direction, width)
	elif slope > 0.001:
		_build_apron(b, -direction, width)
	var start := from + direction * inset_a + Vector3(0.0, -slope * (radius_a - inset_a) - SEAM_DROP, 0.0)
	var end := from + direction * (distance - inset_b)
	end.y = to.y + slope * (radius_b - inset_b) - SEAM_DROP
	var basis := Basis.looking_at((end - start).normalized(), Vector3.UP)
	var length := start.distance_to(end)
	var centre := (start + end) / 2.0 - basis.y * THICKNESS / 2.0
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, THICKNESS, length)
	var body := _body(shape, Transform3D(basis, centre))
	var material: StandardMaterial3D = null
	var visual: MeshInstance3D = null
	if kind == Level01Layout.WALK or kind == Level01Layout.NARROW:
		#Still bridges join the stretch mesh
		_merger.add(&"board", _merged(&"board"), true, _box(shape.size), Transform3D(basis, centre), _bridge_color(a, b))
	else:
		material = _bridge_material(kind, length)
		visual = _mesh(body, _box(shape.size), material, Vector3.ZERO, true)
	var edge_material := _edge_material(kind)
	var edge_length := shape.size.z - 2.0 * (BRIDGE_OVERLAP + EDGE_TRIM)
	if kind == Level01Layout.BELT:
		#Belts get candy rails and drums
		var trim := Node3D.new()
		trim.position = Vector3(0.0, THICKNESS / 2.0, 0.0)
		visual.add_child(trim)
		BeltKit.dress(trim, length - 2.0 * BRIDGE_OVERLAP, width, MINT_DARK)
	for side in ([] if kind == Level01Layout.BELT else [-1.0, 1.0]):
		var edge_at := Vector3(side * (width / 2.0 - EDGE_WIDTH / 2.0 + EDGE_LIFT), THICKNESS / 2.0, 0.0)
		if kind == Level01Layout.FRAGILE:
			_mesh(visual, _box(Vector3(EDGE_WIDTH, EDGE_HEIGHT, edge_length)), edge_material, edge_at)
		else:
			_edge_spots.append(Transform3D(basis.scaled_local(Vector3(EDGE_WIDTH, EDGE_HEIGHT, edge_length)), centre + basis * edge_at))
			_edge_colors.append(edge_material.albedo_color)

	if kind == Level01Layout.SLIDE:
		_build_slide_rails(basis, centre, width, length)
	#Marks where belts, slides and fragile bridges start
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

	#Sensor only on the bridge part outside both platforms
	var sensor_shape := BoxShape3D.new()
	sensor_shape.size = Vector3(width, 9.0, maxf(length - 2.0 * BRIDGE_OVERLAP, 0.5))
	var sensor_centre := (start + end) / 2.0 + basis.y * 3.8
	var area := _sensor(sensor_shape, Transform3D(basis, sensor_centre))
	for locator in locators:
		locator.watch_bridge(a, b, area)
	var pusher := Level01Layout.pusher_of(a, b)
	if not pusher.is_empty() and not _has_block(pusher):
		_build_block(pusher)


#Slide rails with lights and a mouth ring; way bridges take a light tone of their way
func _bridge_color(a: StringName, b: StringName) -> Color:
	var one: Color = TIERS[a]
	var other: Color = TIERS[b]
	if one == other:
		return one.lerp(BRIDGE_COLOR, 0.62)
	return BRIDGE_COLOR


#Flat piece between a round rim and a ramp side
func _build_apron(id: StringName, outward: Vector3, width: float) -> void:
	var radius := Level01Layout.radius_of(id)
	var inset := _bridge_inset(id, width)
	if Level01Layout.is_plate(id) or radius - inset < 0.05:
		return
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, THICKNESS, radius - inset)
	var place := Transform3D(Basis.looking_at(outward, Vector3.UP),
		(Level01Layout.POSITIONS[id] as Vector3) + outward * (inset + shape.size.z / 2.0) + Vector3(0.0, -SEAM_DROP - THICKNESS / 2.0, 0.0))
	_body(shape, place)
	_merger.add(&"board", _merged(&"board"), true, _box(shape.size), place, TIERS[id])


#Bridge start distance from a platform middle
func _bridge_inset(id: StringName, width: float) -> float:
	var radius := Level01Layout.radius_of(id)
	if Level01Layout.is_plate(id):
		return radius
	return sqrt(maxf(radius * radius - width * width / 4.0, 0.0)) - 0.05


#Way plate with bumpers and bulbs on two sides, open at both ends
func _build_plate(id: StringName, locators: Array[PlayerLocator]) -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[id]
	var half := Level01Layout.PLATE / 2.0
	var outline := PackedVector2Array([Vector2(centre.x - half, centre.z - half), Vector2(centre.x + half, centre.z - half),
		Vector2(centre.x + half, centre.z + half), Vector2(centre.x - half, centre.z + half)])
	var color: Color = TIERS[id]
	var rim := MAGENTA if Level01Layout.SPINNERS.has(id) else color.darkened(0.12)
	var mouths: Array[Vector3] = [Vector3(centre.x, centre.z - half, half - 0.05), Vector3(centre.x, centre.z + half, half - 0.05)]
	#Story plates use their tiles as the floor
	if not Level01Layout.TILE_PLATES.has(id):
		_terrain.island(outline, centre.y, color, rim, mouths)
	var sensor_shape := BoxShape3D.new()
	sensor_shape.size = Vector3(Level01Layout.PLATE - 0.2, 9.0, Level01Layout.PLATE - 0.2)
	var area := _sensor(sensor_shape, Transform3D(Basis.IDENTITY, centre + Vector3(0, 3.8, 0)))
	for locator in locators:
		locator.watch_platform(id, area)


#Invisible cup wall except at the slide mouths
func _build_cup_wall(id: StringName) -> void:
	var centre: Vector3 = Level01Layout.POSITIONS[id]
	var radius := Level01Layout.radius_of(id)
	var mouths := _mouths(id, radius, 0.4)
	var steps := 36
	for step in steps:
		var angle := TAU * (step + 0.5) / steps
		var open := false
		for mouth in mouths:
			open = open or absf(angle_difference(angle, mouth.x)) < mouth.y
		if open:
			continue
		var from := Vector2(centre.x, centre.z) + Vector2(cos(TAU * step / steps), sin(TAU * step / steps)) * (radius - 0.1)
		var to := Vector2(centre.x, centre.z) + Vector2(cos(TAU * (step + 1) / steps), sin(TAU * (step + 1) / steps)) * (radius - 0.1)
		_terrain.wall(from, to, centre.y, Level01Layout.CUP_WALL)


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
	#Glowing ring at the mouth
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


#Block model: a like, two bells or a hashtag
func _block_model(look: StringName) -> Node3D:
	if look == &"bell":
		var pair := Node3D.new()
		for way: float in [-1.0, 1.0]:
			var bell := PropKit.make_tall(&"bell", BELL_HEIGHT)
			bell.position.x = way * BLOCK_SIZE.x / 4.0
			pair.add_child(bell)
		return pair
	if look == &"like_hand" or look == &"hashtag":
		return PropKit.make_long(look, BLOCK_SIZE.x)
	return PropKit.make(&"foam_block", BLOCK_SIZE)


func _has_block(pusher: Dictionary) -> bool:
	for block in _blocks:
		if block["pusher"] == pusher:
			return true
	return false


#Sweeping block on a rail with yellow bumpers
func _build_block(pusher: Dictionary) -> void:
	var track := Level01Hazards.block_track(pusher)
	var tangent: Vector3 = track["tangent"]
	var ramp := Basis.looking_at(tangent, Vector3.UP)
	var side: Vector3 = track["side"]
	var reach: float = track["reach"]
	var centre: Vector3 = track["centre"]
	var holder := Node3D.new()
	add_child(holder)
	var model := _block_model(pusher.get("look", &"foam_block"))
	#Faces the start of the course
	if tangent.z > 0.0:
		model.rotation.y = PI
	holder.add_child(model)
	_blocks.append({"node": holder, "model": model, "pusher": pusher, "basis": ramp})
	holder.global_position = Level01Hazards.block_center(pusher, 0.0)
	holder.basis = ramp
	#Rail across the block's whole path
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


#Edge light colour per bridge kind
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


#Chevrons run from the first vertex to the second
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


#Island bumper in its colour with gaps for bridges
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


#Vertex-colour materials shared by every island and bridge
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


#Bridge mouths on an island rim with "margin"
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


#Circle stretches no mouth covers, as angle pairs
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


#Rim lights except at bridge mouths
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


#Spinner bars sweeping around a pole
func _build_spinners() -> void:
	for id: StringName in Level01Layout.SPINNERS:
		var spinner: Dictionary = Level01Layout.SPINNERS[id]
		var pivot := Node3D.new()
		pivot.position = Level01Layout.POSITIONS[id] + Vector3(0, 0.02, 0)
		add_child(pivot)
		for bar in int(spinner.get("arms", 1)):
			var tube := PropKit.make(&"bumper", Vector3(float(spinner["arm"]) * 2.0, Level01Hazards.BAR_HEIGHT, 0.6))
			tube.rotation.y = -PI / 2.0 * bar
			pivot.add_child(tube)
		pivot.add_child(PropKit.make_tall(&"cone", 1.5))
		_spinners[id] = pivot


#Rolling ball track, end studs and candy sphere
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


#Rolls along its diameter, turning with distance
func _place_ball(entry: Dictionary, time: float) -> void:
	var ball: Dictionary = entry["ball"]
	var node: MeshInstance3D = entry["ball_node"]
	var centre := Level01Hazards.ball_center(ball, time)
	var along := Level01Hazards.ball_lane(ball)["along"] as Vector3
	var island: Vector3 = Level01Layout.POSITIONS[ball["island"]]
	node.global_position = centre
	node.basis = Basis(Vector3.UP.cross(along).normalized(), (centre - island).dot(along) / Level01Layout.BALL_RADIUS)


#Deck pads with an arrow and a small bubble
func _build_lift_pads() -> void:
	var cushion := CylinderMesh.new()
	cushion.top_radius = LIFT_PAD_RADIUS
	cushion.bottom_radius = LIFT_PAD_RADIUS + 0.12
	cushion.height = 0.26
	cushion.radial_segments = 28
	cushion.rings = 1
	var surface := CylinderMesh.new()
	surface.top_radius = LIFT_PAD_RADIUS - 0.2
	surface.bottom_radius = LIFT_PAD_RADIUS - 0.2
	surface.height = 0.06
	surface.radial_segments = 28
	surface.rings = 1
	var arrow := PrismMesh.new()
	arrow.size = Vector3(1.2, 1.2, 0.04)
	var markers: Array[Vector3] = []
	for lift: Dictionary in Level01Layout.deck_lifts():
		var spot: Vector3 = lift["pad"]
		var aim: Vector3 = lift["landing"] - spot
		aim.y = 0.0
		aim = aim.normalized()
		var pad := Node3D.new()
		pad.position = spot
		add_child(pad)
		_mesh(pad, cushion, PartyKit.candy(Color("fdfbff"), AMBER, 10.0, 0.0, 0.2), Vector3(0.0, 0.13, 0.0), true)
		_mesh(pad, surface, _material(AMBER, 1.3), Vector3(0.0, 0.27, 0.0))
		var mark := _mesh(pad, arrow, _material(Color("fdfbff"), 0.8), Vector3(0.0, 0.31, 0.0))
		mark.basis = Basis.looking_at(aim, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2.0)
		_lift_pads[_key(lift["edge"][0], lift["edge"][1])] = pad
		markers.append(spot + Vector3(0.0, PAD_BUBBLE_HEIGHT, 0.0))
	var ball := SphereMesh.new()
	ball.radius = PAD_BUBBLE_RADIUS
	ball.height = PAD_BUBBLE_RADIUS * 2.0
	ball.radial_segments = 16
	ball.rings = 8
	ball.material = _bubble_material()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = ball
	multi.instance_count = markers.size()
	for index in markers.size():
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, markers[index]))
	var bubbles := MultiMeshInstance3D.new()
	bubbles.multimesh = multi
	bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bubbles)


#Soft decks under every way bridge; overlapping decks share one floor
func _build_decks() -> void:
	for edge in Level01Layout.soft_edges():
		var deck := Level01Layout.deck_of(edge)
		var centre: Vector3 = deck["center"]
		var top: float = deck["top"]
		#Same colour and height for overlapping decks
		var outline := CandyTerrain.rounded_box(Vector2(centre.x, centre.z), deck["size"], Level01Layout.DECK_ROUND, -float(deck["yaw"]), 6)
		_terrain.tray(outline, top, DECK_COLOR)
		var rim := Level01Layout.deck_rim(edge)
		for stretch in rim:
			var points: PackedVector3Array = stretch["points"]
			var lower := PackedVector3Array()
			var upper := PackedVector3Array()
			for point in points:
				lower.append(point + Vector3(0.0, Level01Layout.DECK_TUBE, 0.0))
				upper.append(point + Vector3(0.0, Level01Layout.DECK_RIM - DECK_RING_TOP_TUBE, 0.0))
			if stretch["closed"]:
				lower.append(lower[0])
				upper.append(upper[0])
			_terrain.rail(lower, DECK_RING, false, Level01Layout.DECK_TUBE, true, 8)
			_terrain.rail(upper, DECK_RING_TOP, false, DECK_RING_TOP_TUBE, true, 8)
		#Walls follow the rings
		var walls := StaticBody3D.new()
		add_child(walls)
		for piece in Level01Layout.rim_walls(rim):
			var wall_size: Vector3 = piece["size"]
			var wall := BoxShape3D.new()
			wall.size = wall_size
			var collider := CollisionShape3D.new()
			collider.shape = wall
			collider.transform = Transform3D(Basis(Vector3.UP, float(piece["yaw"])), (piece["center"] as Vector3) + Vector3(0.0, wall_size.y / 2.0, 0.0))
			walls.add_child(collider)


#Comment bubbles and their source lights
func _build_comments() -> void:
	for comment: Dictionary in Level01Layout.COMMENTS:
		var holder := Node3D.new()
		holder.hide()
		add_child(holder)
		holder.add_child(PropKit.make(&"bubble", Vector3(2.0, 1.7, 1.2)))
		var track := Level01Hazards.block_track(comment)
		var flat_tangent := Vector3((track["tangent"] as Vector3).x, 0.0, (track["tangent"] as Vector3).z).normalized()
		holder.basis = Basis.looking_at(flat_tangent, Vector3.UP)
		var shape := Word3D.mesh_of("", COMMENT_WORD_HEIGHT, COMMENT_WORD_WIDTH, 0.2)
		for facing: float in [1.0, -1.0]:
			var word := MeshInstance3D.new()
			word.mesh = shape
			word.material_override = Word3D.paint(Word3D.FACE, MAGENTA.darkened(0.25))
			word.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			word.position = Vector3(0.0, 0.85, facing * 0.62)
			word.rotation.y = 0.0 if facing > 0.0 else PI
			holder.add_child(word)
		var strip_material := _material_copy(MAGENTA, 0.9, 0.55)
		var strip := _mesh(self, _box(Vector3(Level01Layout.WIDE_WIDTH, 0.03, 2.4)), strip_material, (track["centre"] as Vector3) + Vector3(0.0, 0.05, 0.0))
		strip.basis = Basis.looking_at(track["tangent"] as Vector3, Vector3.UP)
		strip.hide()
		_comments.append({"comment": comment, "holder": holder, "shape": shape, "word": "", "strip": strip, "strip_material": strip_material})


#Typed, flashing, sweeping and deflating
func _update_comment(entry: Dictionary, time: float) -> void:
	var comment: Dictionary = entry["comment"]
	var state := Level01Hazards.comment_state(comment, time)
	var stage := int(state["stage"])
	var holder: Node3D = entry["holder"]
	var strip: MeshInstance3D = entry["strip"]
	holder.visible = stage != Level01Hazards.COMMENT_IDLE
	var warning := stage == Level01Hazards.COMMENT_WARNING
	strip.visible = stage == Level01Hazards.COMMENT_TYPING or warning
	if not holder.visible:
		return
	var share := float(state["share"])
	holder.global_position = Level01Hazards.comment_center(comment, time)
	var words: Array = comment["words"]
	var word := String(words[int(state["cycle"]) % words.size()])
	var grown := 1.0
	match stage:
		Level01Hazards.COMMENT_TYPING:
			grown = lerpf(0.3, 1.0, 1.0 - pow(1.0 - share, 3.0))
		Level01Hazards.COMMENT_WARNING:
			grown = 1.0 + 0.07 * sin(time * 32.0)
		Level01Hazards.COMMENT_FADING:
			grown = 1.0 - share
	holder.scale = Vector3.ONE * maxf(grown, 0.01)
	var shape: TextMesh = entry["shape"]
	if entry["word"] != word:
		entry["word"] = word
		var natural := Word3D.FONT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, Word3D.FONT_SIZE).x
		shape.pixel_size = minf(COMMENT_WORD_HEIGHT / Word3D.FONT_SIZE, COMMENT_WORD_WIDTH / maxf(natural, 1.0))
	var typed := word.substr(0, ceili(word.length() * minf(share * 1.4, 1.0))) if stage == Level01Hazards.COMMENT_TYPING else word
	if shape.text != typed:
		shape.text = typed
	(entry["strip_material"] as StandardMaterial3D).emission_energy_multiplier = 0.5 + (2.2 * absf(sin(time * 12.0)) if warning else 0.0)


#Saturated sign facing the start
func _show_saturated(a: StringName, b: StringName) -> void:
	var key := _key(a, b)
	if not _saturated.has(key):
		var from: Vector3 = Level01Layout.POSITIONS[a]
		var to: Vector3 = Level01Layout.POSITIONS[b]
		var toward_start := Vector3(from.x - to.x, 0.0, from.z - to.z) * (1.0 if from.z >= to.z else -1.0)
		var sign_at := Node3D.new()
		sign_at.position = (from + to) / 2.0 + Vector3(0.0, 2.6, 0.0)
		add_child(sign_at)
		sign_at.basis = Basis.looking_at(-toward_start.normalized(), Vector3.UP)
		sign_at.add_child(Word3D.make("SATURADA", 1.05, 5.2, Color("2a2145"), SATURATED_DEPTH, CORAL))
		_saturated[key] = sign_at
	(_saturated[key] as Node3D).show()


func _scatter_decor() -> void:
	var backdrop := Level01Backdrop.new()
	add_child(backdrop)
	backdrop.build()


#Course names: arches over each way and slide, and META over the goal
func _build_name_labels() -> void:
	var goal: Vector3 = Level01Layout.POSITIONS[Level01Layout.GOAL]
	#Faces the course
	var goal_word := Word3D.make("META", GOAL_WORD_HEIGHT, GOAL_WORD_HEIGHT * 4.0, AMBER.darkened(0.5), GOAL_WORD_DEPTH, AMBER)
	goal_word.position = goal + Vector3(0.0, 9.6, 0.0)
	add_child(goal_word)
	#Still arches join into a few meshes
	var signs := Node3D.new()
	add_child(signs)
	for vertex: StringName in Level01Layout.WAY_NAMES:
		var entrance := (Level01Layout.POSITIONS[vertex] as Vector3) + Vector3(0.0, 0.0, Level01Layout.PLATE / 2.0 - 0.3)
		var way_arch := SignBoard.arch(Level01Layout.WAY_NAMES[vertex], (TIERS[vertex] as Color).darkened(0.08), Level01Layout.PLATE + 0.9,
			WAY_SIGN_HEIGHT, 1.6, Level01Layout.DECK_DEPTH)
		way_arch.position = entrance
		signs.add_child(way_arch)
	var plaza: Vector3 = Level01Layout.POSITIONS[&"S"]
	for vertex: StringName in Level01Layout.SLIDE_NAMES:
		var toward: Vector3 = Level01Layout.POSITIONS[vertex] - plaza
		toward.y = 0.0
		toward = toward.normalized()
		var slide_arch := SignBoard.arch(Level01Layout.SLIDE_NAMES[vertex], SKY.darkened(0.1), Level01Layout.SLIDE_WIDTH + 1.4, SLIDE_SIGN_HEIGHT, 1.3)
		slide_arch.position = plaza + toward * (Level01Layout.radius_of(&"S") - 0.6)
		slide_arch.rotation.y = atan2(-toward.x, -toward.z)
		signs.add_child(slide_arch)
	StaticBatch.join(signs, [], false)
