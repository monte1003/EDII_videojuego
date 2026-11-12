class_name ArenaWorld
extends Node3D

#Builds an arena map from its layout: the islands with their candy bumpers and lights, the bridges and ramps, and what moves on them
#(turning bars, sweeping blocks, trampolines and belts). The static pieces are joined in a few meshes; nothing here decides a rule

const BOARD_TEXTURE: Texture2D = preload("res://assets/textures/board_checker.png")
const BELT_TEXTURE: Texture2D = preload("res://assets/textures/belt_chevrons.png")
const CANDY_VERTEX: Shader = preload("res://assets/shaders/candy_vertex.gdshader")
const GLOW_VERTEX: Shader = preload("res://assets/shaders/tint_glow.gdshader")
const BRIDGE_COLOR := Color("fff2f7")
const EDGE_COLOR := Color("7ae6ff")
const BELT_EDGE := Color("4cf2b0")
const HAZARD_RIM := Color("ee4fb8")
const THICKNESS := 0.6
#How far a bridge reaches into each island, so there is never a gap between them
const BRIDGE_OVERLAP := 0.25
const EDGE_WIDTH := 0.2
const EDGE_HEIGHT := 0.07
const RIM_TUBE := 0.22
const RIM_HEIGHT := 0.4
const RIM_STRIPE := 1.5
const RIM_GAP := 0.3
const BULB_SPACING := 1.6
const BELT_TILE := 3.0
const BLOCK_SIZE := Vector3(1.6, 0.9, 1.0)
const BAR_HEIGHT := 0.6
#Seconds before a turn in which a belt blinks
const BELT_WARNING := 1.5
#Seconds a piece takes to pop in when its stage starts
const POP_TIME := 0.5

var layout: ArenaLayout

var _merger := MeshMerger.new()
var _merged_materials: Dictionary = {}
var _platform_areas: Dictionary = {}
var _bridge_areas: Array[Array] = []
var _spinners: Dictionary = {}
var _blocks: Array[Dictionary] = []
var _pads: Dictionary = {}
var _belts: Array[Dictionary] = []
var _bulb_spots: Array[Transform3D] = []
var _bulb_colors: Array[Color] = []
var _bulb_phases: Array[float] = []
var _stage := -1


func build(arena: ArenaLayout) -> void:
	layout = arena
	for id: StringName in layout.islands:
		_build_island(id)
	for bridge in layout.bridges:
		_build_bridge(bridge)
	for stone in layout.stones:
		_build_stone(stone)
	_merger.commit(self)
	add_child(PartyKit.bulbs(_bulb_spots, _bulb_colors, _bulb_phases))
	_build_spinners()
	_build_blocks()
	_build_pads()
	set_stage(0, false)


#Tells a locator about every island and bridge, so it knows where its player stands
func watch(locator: PlayerLocator) -> void:
	for id: StringName in _platform_areas:
		locator.watch_platform(id, _platform_areas[id])
	for entry in _bridge_areas:
		locator.watch_bridge(entry[0], entry[1], entry[2])


#Shows what starts at this stage of the round; with "pop" the new pieces grow in instead of just appearing
func set_stage(stage: int, pop := true) -> void:
	if stage == _stage:
		return
	_stage = stage
	for id: StringName in _spinners:
		_reveal(_spinners[id], ArenaLayout.is_on(layout.spinners[id], stage), pop)
	for block in _blocks:
		_reveal(block["node"], ArenaLayout.is_on(block["sweeper"], stage), pop)
		_reveal(block["rail"], ArenaLayout.is_on(block["sweeper"], stage), false)
	for id: StringName in _pads:
		_reveal(_pads[id], ArenaLayout.is_on(layout.pads[id], stage), pop)


#Puts every moving piece where it is at "time" seconds of the round
func update(time: float) -> void:
	for id: StringName in _spinners:
		var pivot: Node3D = _spinners[id]
		if pivot.visible:
			pivot.rotation.y = -Level01Hazards.angle_at(layout.spinners[id], time)
	for block in _blocks:
		var node: Node3D = block["node"]
		if node.visible:
			node.global_position = ArenaHazards.block_center(layout, block["sweeper"], time)
	var flow := layout.belt_flow(_stage, time)
	var warning := flow != 0.0 and layout.belt_turn_in(time) < BELT_WARNING
	for belt in _belts:
		var material: StandardMaterial3D = belt["material"]
		var tiles: float = belt["tiles"]
		material.uv1_scale = Vector3(1.0, -tiles if flow >= 0.0 else tiles, 1.0)
		material.uv1_offset = Vector3(0.0, fposmod(time * layout.belt_speed / BELT_TILE, 1.0) if flow != 0.0 else 0.0, 0.0)
		material.emission_energy_multiplier = 0.25 + 1.3 * absf(sin(time * 10.0)) if warning else (0.25 if flow != 0.0 else 0.0)
		material.albedo_color = Color.WHITE if flow != 0.0 else Color(0.72, 0.72, 0.8)


#The trampoline dips and springs back
func bounce_pad(id: StringName) -> void:
	var pad: Node3D = _pads.get(id)
	if pad == null:
		return
	var tween := create_tween()
	tween.tween_property(pad, "scale", Vector3(1.15, 0.35, 1.15), 0.06)
	tween.tween_property(pad, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _reveal(node: Node3D, on: bool, pop: bool) -> void:
	if node.visible == on:
		return
	node.visible = on
	if on and pop:
		node.scale = Vector3.ONE * 0.01
		create_tween().tween_property(node, "scale", Vector3.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_island(id: StringName) -> void:
	var centre := layout.position_of(id)
	var radius := layout.radius_of(id)
	var color := layout.color_of(id)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = THICKNESS
	var body_at := centre + Vector3(0.0, -THICKNESS / 2.0, 0.0)
	_body(shape, Transform3D(Basis.IDENTITY, body_at))

	var top := _disc(radius, radius, THICKNESS)
	_merger.add(&"board", _merged(&"board"), true, top, Transform3D(Basis.IDENTITY, body_at), color)
	var skirt := _disc(radius * 0.97, radius * 0.5, 1.6)
	_merger.add(&"skirt", _merged(&"skirt"), false, skirt, Transform3D(Basis.IDENTITY, body_at + Vector3(0.0, -THICKNESS / 2.0 - 0.8, 0.0)), color.darkened(0.35))
	#Two flat discs in the middle make a bullseye in lighter tones of the island
	for ring: Array in [[0.46, 0.28, 0.02], [0.3, 0.0, 0.027]]:
		var disc := _disc(radius * float(ring[0]), radius * float(ring[0]), 0.03)
		_merger.add(&"board", _merged(&"board"), false, disc, Transform3D(Basis.IDENTITY, centre + Vector3(0.0, float(ring[2]), 0.0)), color.lightened(float(ring[1])))
	#The bumper warns in hot pink where a bar will sweep the island
	var rim_color := HAZARD_RIM if layout.spinners.has(id) else color.darkened(0.12)
	_build_rim(body_at, id, radius, rim_color)
	_rim_lights(id, centre, radius)
	var underglow := TorusMesh.new()
	underglow.outer_radius = radius * 0.52
	underglow.inner_radius = radius * 0.52 - 0.22
	underglow.rings = 32
	underglow.ring_segments = 6
	_merger.add(&"glow", _merged(&"glow"), false, underglow, Transform3D(Basis.IDENTITY, body_at + Vector3(0.0, -THICKNESS / 2.0 - 1.55, 0.0)), rim_color.lightened(0.2))

	var sensor := CylinderShape3D.new()
	sensor.radius = radius - 0.1
	sensor.height = 9.0
	_platform_areas[id] = _sensor(sensor, Transform3D(Basis.IDENTITY, centre + Vector3(0.0, 3.8, 0.0)))


#A stepping stone: a small drum with a light band, to jump on
func _build_stone(stone: Dictionary) -> void:
	var centre: Vector3 = stone["position"]
	var radius: float = stone["radius"]
	var color := layout.zone_colors[int(stone["zone"]) % layout.zone_colors.size()].lightened(0.25)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = THICKNESS
	var body_at := centre + Vector3(0.0, -THICKNESS / 2.0, 0.0)
	_body(shape, Transform3D(Basis.IDENTITY, body_at))
	_merger.add(&"board", _merged(&"board"), true, _disc(radius, radius, THICKNESS), Transform3D(Basis.IDENTITY, body_at), color)
	_merger.add(&"skirt", _merged(&"skirt"), false, _disc(radius * 0.92, radius * 0.4, 0.9), Transform3D(Basis.IDENTITY, body_at + Vector3(0.0, -THICKNESS / 2.0 - 0.45, 0.0)), color.darkened(0.35))
	var band := TorusMesh.new()
	band.outer_radius = radius + 0.05
	band.inner_radius = radius - 0.12
	band.rings = 24
	band.ring_segments = 6
	_merger.add(&"glow", _merged(&"glow"), false, band, Transform3D(Basis.IDENTITY, centre + Vector3(0.0, -0.08, 0.0)), PartyKit.YELLOW)


#A straight ramp from the edge of one island to the edge of the other
func _build_bridge(bridge: ArenaLayout.Bridge) -> void:
	var frame := layout.frame_of(bridge)
	var width: float = frame["width"]
	var direction: Vector3 = frame["direction"]
	var from: Vector3 = frame["start"]
	var to: Vector3 = frame["end"]
	var slope := (to.y - from.y) / maxf(float(frame["length"]), 0.1)
	var start := from - direction * BRIDGE_OVERLAP - Vector3(0.0, slope * BRIDGE_OVERLAP, 0.0)
	var end := to + direction * BRIDGE_OVERLAP + Vector3(0.0, slope * BRIDGE_OVERLAP, 0.0)
	var basis := Basis.looking_at((end - start).normalized(), Vector3.UP)
	var length := start.distance_to(end)
	var centre := (start + end) / 2.0 - basis.y * THICKNESS / 2.0
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, THICKNESS, length)
	var body := _body(shape, Transform3D(basis, centre))
	var box := BoxMesh.new()
	box.size = shape.size
	var edge_color := EDGE_COLOR
	if bridge.kind == ArenaLayout.BELT:
		var material := StandardMaterial3D.new()
		material.albedo_texture = BELT_TEXTURE
		material.roughness = 0.55
		material.emission_enabled = true
		material.emission = BELT_EDGE
		material.emission_energy_multiplier = 0.0
		var visual := MeshInstance3D.new()
		visual.mesh = box
		visual.material_override = material
		body.add_child(visual)
		_belts.append({"material": material, "tiles": length / BELT_TILE})
		edge_color = BELT_EDGE
	else:
		_merger.add(&"board", _merged(&"board"), true, box, Transform3D(basis, centre), BRIDGE_COLOR)
	var edge := BoxMesh.new()
	edge.size = Vector3(EDGE_WIDTH, EDGE_HEIGHT, length - 2.0 * BRIDGE_OVERLAP - 0.4)
	for side: float in [-1.0, 1.0]:
		var edge_at := centre + basis * Vector3(side * (width / 2.0 - EDGE_WIDTH / 2.0), THICKNESS / 2.0 + EDGE_HEIGHT / 2.0, 0.0)
		_merger.add(&"glow", _merged(&"glow"), false, edge, Transform3D(basis, edge_at), edge_color)
	var sensor := BoxShape3D.new()
	sensor.size = Vector3(width, 9.0, maxf(length - 2.0 * BRIDGE_OVERLAP, 0.5))
	_bridge_areas.append([bridge.a, bridge.b, _sensor(sensor, Transform3D(basis, (start + end) / 2.0 + basis.y * 3.8))])


func _build_spinners() -> void:
	for id: StringName in layout.spinners:
		var spinner: Dictionary = layout.spinners[id]
		var pivot := Node3D.new()
		pivot.position = layout.position_of(id) + Vector3(0.0, 0.02, 0.0)
		add_child(pivot)
		pivot.add_child(PropKit.make(&"bumper", Vector3(float(spinner["arm"]) * 2.0, BAR_HEIGHT, 0.6)))
		pivot.add_child(PropKit.make_tall(&"cone", 1.5))
		_spinners[id] = pivot


#The padded block of each sweeper and the dark rail it runs on, with a yellow stop at each end
func _build_blocks() -> void:
	for sweeper in layout.sweepers:
		var edge: Array = sweeper["edge"]
		var frame := layout.frame_of(layout.bridge_between(edge[0], edge[1]))
		var from: Vector3 = frame["start"]
		var to: Vector3 = frame["end"]
		var ramp := Basis.looking_at((to - from).normalized(), Vector3.UP)
		var holder := Node3D.new()
		add_child(holder)
		holder.add_child(PropKit.make(&"foam_block", BLOCK_SIZE))
		holder.basis = ramp
		holder.global_position = ArenaHazards.block_center(layout, sweeper, 0.0)
		var rail := Node3D.new()
		add_child(rail)
		rail.basis = ramp
		rail.global_position = ArenaHazards.block_track(layout, sweeper)
		var rail_width := (ArenaHazards.block_reach(layout, sweeper) + BLOCK_SIZE.x / 2.0 + 0.15) * 2.0
		var strip := BoxMesh.new()
		strip.size = Vector3(rail_width, 0.03, BLOCK_SIZE.z + 0.45)
		_piece(rail, strip, PartyKit.paint(PartyKit.INK, 0.0, 0.6), Vector3(0.0, 0.02, 0.0))
		var stop := _disc(0.17, 0.2, 0.42)
		for way: float in [-1.0, 1.0]:
			_piece(rail, stop, PartyKit.paint(PartyKit.YELLOW, 0.8, 0.35), Vector3(rail_width / 2.0 * way, 0.2, 0.0))
		_blocks.append({"node": holder, "rail": rail, "sweeper": sweeper})


#A trampoline: a dark base, a pink ring and a yellow skin that glows
func _build_pads() -> void:
	for id: StringName in layout.pads:
		var pad := Node3D.new()
		pad.position = ArenaHazards.pad_position(layout, id) + Vector3(0.0, 0.03, 0.0)
		add_child(pad)
		_piece(pad, _disc(ArenaHazards.PAD_REACH + 0.2, ArenaHazards.PAD_REACH + 0.3, 0.16), PartyKit.paint(PartyKit.INK, 0.0, 0.6), Vector3(0.0, 0.08, 0.0))
		_piece(pad, _disc(ArenaHazards.PAD_REACH, ArenaHazards.PAD_REACH, 0.08), PartyKit.paint(PartyKit.YELLOW, 0.7, 0.3), Vector3(0.0, 0.19, 0.0))
		var ring := TorusMesh.new()
		ring.outer_radius = ArenaHazards.PAD_REACH + 0.22
		ring.inner_radius = ArenaHazards.PAD_REACH - 0.02
		ring.rings = 28
		ring.ring_segments = 8
		_piece(pad, ring, PartyKit.candy(PartyKit.WHITE, PartyKit.PINK, 12.0, 0.0, 0.2), Vector3(0.0, 0.2, 0.0))
		_pads[id] = pad


func _piece(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _disc(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 40 if maxf(top_radius, bottom_radius) > 1.5 else 18
	mesh.rings = 1
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


#The materials of the joined meshes read the colour of each vertex, so one serves every island and bridge
func _merged(kind: StringName) -> Material:
	if _merged_materials.has(kind):
		return _merged_materials[kind]
	var material: Material
	if kind == &"board":
		var board := StandardMaterial3D.new()
		board.albedo_texture = BOARD_TEXTURE
		board.roughness = 0.55
		board.uv1_triplanar = true
		board.uv1_world_triplanar = true
		board.uv1_scale = Vector3.ONE / 6.0
		board.vertex_color_use_as_albedo = true
		board.vertex_color_is_srgb = true
		material = board
	elif kind == &"skirt":
		var skirt := StandardMaterial3D.new()
		skirt.roughness = 0.6
		skirt.vertex_color_use_as_albedo = true
		skirt.vertex_color_is_srgb = true
		material = skirt
	else:
		var shaded := ShaderMaterial.new()
		shaded.shader = CANDY_VERTEX if kind == &"rim" else GLOW_VERTEX
		material = shaded
	_merged_materials[kind] = material
	return material


#The bumper around an island, with a gap where each bridge comes in
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


#Where the bridges of an island start on its rim: the angle toward each one and half of the angle it covers
func _mouths(id: StringName, radius: float, margin: float) -> Array[Vector2]:
	var found: Array[Vector2] = []
	var centre := layout.position_of(id)
	for bridge in layout.bridges:
		if bridge.a != id and bridge.b != id:
			continue
		var to := layout.position_of(bridge.b if bridge.a == id else bridge.a) - centre
		var half := asin(minf((float(ArenaLayout.WIDTHS[bridge.kind]) / 2.0 + margin) / radius, 1.0))
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
	var joined: Array[Vector2] = []
	for span in covered:
		if not joined.is_empty() and span.x <= joined[-1].y:
			joined[-1] = Vector2(joined[-1].x, maxf(joined[-1].y, span.y))
		else:
			joined.append(span)
	var free: Array[Vector2] = []
	if joined.is_empty():
		free.append(Vector2(0.0, TAU))
		return free
	for index in joined.size() - 1:
		free.append(Vector2(joined[index].y, joined[index + 1].x))
	if joined[0].x > 0.0 or joined[-1].y < TAU:
		free.append(Vector2(joined[-1].y, joined[0].x + TAU))
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
		_bulb_spots.append(Transform3D(Basis.IDENTITY, centre + Vector3(cos(angle) * ring, RIM_HEIGHT + 0.02, sin(angle) * ring)))
		_bulb_colors.append(PartyKit.PALETTE[(step + int(absf(centre.z))) % PartyKit.PALETTE.size()])
		_bulb_phases.append(angle * 3.0 + centre.z * 0.12)
