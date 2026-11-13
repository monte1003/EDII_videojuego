class_name ArenaWorld
extends Node3D

#Builds an arena map from its layout: the ground, the terraces, ramps, drums and walls on it, the fence around it all, and what
#moves (turning bars, sweeping blocks, trampolines, cannons and belts). The static pieces are joined in a few meshes and collide
#as plain boxes, prisms and cylinders, with no gap between them; nothing here decides a rule

const BOARD_TEXTURE: Texture2D = preload("res://assets/textures/board_checker.png")
const BELT_TEXTURE: Texture2D = preload("res://assets/textures/belt_chevrons.png")
const CANDY_VERTEX: Shader = preload("res://assets/shaders/candy_vertex.gdshader")
const GLOW_VERTEX: Shader = preload("res://assets/shaders/tint_glow.gdshader")
const WALKWAY_COLOR := Color("fff2f7")
const EDGE_COLOR := Color("7ae6ff")
const BELT_EDGE := Color("4cf2b0")
const CANNON_COLOR := Color("ffc857")
#The lighter layer on top of every block, like the icing of a cake, and how far it sticks out
const LIP := 0.3
const LIP_OUT := 0.14
#How much darker than its top the body of a block is
const BODY_SHADE := 0.2
#A walkway is this thick and reaches this far into what it joins, so there is never a gap
const WALK_THICKNESS := 0.5
const OVERLAP := 0.25
const EDGE_WIDTH := 0.2
const EDGE_HEIGHT := 0.07
#How high each step of a staircase looks
const STEP_RISE := 0.16
#The ground goes on this far past the fence, and is this thick
const GROUND_MARGIN := 90.0
const GROUND_DEPTH := 2.0
#The fence: a wall nobody sees, far higher than any jump, behind a low candy rail on a curb
const FENCE_HEIGHT := 18.0
const FENCE_THICKNESS := 1.0
const RAIL_HEIGHT := 0.66
const RAIL_TUBE := 0.24
const RAIL_STRIPE := 1.5
const CURB_HEIGHT := 0.32
const CURB_WIDTH := 0.7
const BULB_SPACING := 2.0
#The sensors that tell a locator where its player is: how high over a floor they reach and how wide a link is
const SENSOR_HEIGHT := 3.0
const SENSOR_SINK := 0.4
const LINK_WIDTH := 2.4
#A place this small gets no mark on its floor
const MARK_MIN := 2.4
const BELT_TILE := 3.0
const BELT_LIFT := 0.035
#The padded block: across its way, high and along its way, which is what the hit test measures
const BLOCK_SIZE := Vector3(ArenaHazards.BLOCK_ACROSS, 0.9, ArenaHazards.BLOCK_ALONG)
const BAR_HEIGHT := 0.6
const HOOPS := 5
#Seconds before a turn in which a belt blinks
const BELT_WARNING := 1.5
#Seconds a piece takes to pop in when its stage starts
const POP_TIME := 0.5

var layout: ArenaLayout

var _merger := MeshMerger.new()
var _merged_materials: Dictionary = {}
var _place_areas: Dictionary = {}
var _link_areas: Array[Array] = []
var _spinners: Array[Node3D] = []
var _blocks: Array[Dictionary] = []
var _pads: Array[Dictionary] = []
var _belts: Array[Dictionary] = []
var _bulb_spots: Array[Transform3D] = []
var _bulb_colors: Array[Color] = []
var _bulb_phases: Array[float] = []
var _stage := -1
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func build(arena: ArenaLayout) -> void:
	layout = arena
	_build_ground()
	for block in layout.blocks:
		_build_block(block)
	for ramp in layout.ramps:
		_build_ramp(ramp)
	for drum in layout.drums:
		_build_drum(drum)
	_build_fence()
	for id: StringName in layout.places:
		_build_place(id)
	for entry in layout.links:
		_build_link(entry)
	_merger.commit(self)
	add_child(PartyKit.bulbs(_bulb_spots, _bulb_colors, _bulb_phases))
	_build_spinners()
	_build_blocks()
	_build_pads()
	_build_belts()
	set_stage(0, false)


#Tells a locator about every place and link, so it knows where its player stands
func watch(locator: PlayerLocator) -> void:
	for id: StringName in _place_areas:
		locator.watch_platform(id, _place_areas[id])
	for entry in _link_areas:
		locator.watch_bridge(entry[0], entry[1], entry[2])


#Shows what starts at this stage of the round; with "pop" the new pieces grow in instead of just appearing
func set_stage(stage: int, pop := true) -> void:
	if stage == _stage:
		return
	_stage = stage
	for index in _spinners.size():
		_reveal(_spinners[index], ArenaLayout.is_on(layout.spinners[index], stage), pop)
	for block in _blocks:
		_reveal(block["node"], ArenaLayout.is_on(block["sweeper"], stage), pop)
		_reveal(block["rail"], ArenaLayout.is_on(block["sweeper"], stage), false)
	for entry in _pads:
		_reveal(entry["node"], ArenaLayout.is_on(entry["pad"], stage), pop)


#Puts every moving piece where it is at "time" seconds of the round
func update(time: float) -> void:
	for index in _spinners.size():
		var pivot := _spinners[index]
		if pivot.visible:
			pivot.rotation.y = -Level01Hazards.angle_at(layout.spinners[index], time)
	for block in _blocks:
		var node: Node3D = block["node"]
		if node.visible:
			node.global_position = ArenaHazards.block_center(block["sweeper"], time)
	for entry in _pads:
		#A pad with a beat sinks and goes dark while it rests
		var skin: Node3D = entry["skin"]
		var live := ArenaHazards.pad_live(entry["pad"], time)
		skin.scale.y = lerpf(skin.scale.y, 1.0 if live else 0.25, 0.3)
		(entry["material"] as StandardMaterial3D).emission_energy_multiplier = 1.1 if live else 0.05
	var warning := layout.belt_turn_in(time) < BELT_WARNING
	for entry in _belts:
		var belt: Dictionary = entry["belt"]
		var flow := layout.belt_flow(belt, _stage, time)
		var material: StandardMaterial3D = entry["material"]
		var tiles: float = entry["tiles"]
		material.uv1_scale = Vector3(1.0, -tiles if flow >= 0.0 else tiles, 1.0)
		material.uv1_offset = Vector3(0.0, fposmod(time * layout.belt_speed / BELT_TILE, 1.0) if flow != 0.0 else 0.0, 0.0)
		var blinks: bool = warning and flow != 0.0 and belt.get("turns", false)
		material.emission_energy_multiplier = 0.25 + 1.3 * absf(sin(time * 10.0)) if blinks else (0.25 if flow != 0.0 else 0.0)
		material.albedo_color = Color.WHITE if flow != 0.0 else Color(0.72, 0.72, 0.8)


#The pad dips and springs back
func bounce_pad(index: int) -> void:
	if index < 0 or index >= _pads.size():
		return
	var pad: Node3D = _pads[index]["node"]
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


#One flat floor under the whole map and well past its fence: whatever falls from a terrace lands on it
func _build_ground() -> void:
	var side := (layout.reach() + GROUND_MARGIN) * 2.0
	var shape := BoxShape3D.new()
	shape.size = Vector3(side, GROUND_DEPTH, side)
	_body(shape, Transform3D(Basis.IDENTITY, Vector3(0.0, ArenaLayout.GROUND - GROUND_DEPTH / 2.0, 0.0)))
	var plane := PlaneMesh.new()
	plane.size = Vector2(side, side)
	_merger.add(&"ground", _merged(&"board"), false, plane, Transform3D(Basis.IDENTITY, Vector3(0.0, ArenaLayout.GROUND, 0.0)), layout.ground_color)


#A terrace or a deck: a box with a lighter layer on top. A wall is a plain box with a pale cap
func _build_block(block: Dictionary) -> void:
	var center: Vector2 = block["center"]
	var size: Vector2 = block["size"]
	var top: float = block["top"]
	var bottom: float = block["bottom"]
	var height := top - bottom
	var basis := Basis(Vector3.UP, float(block["yaw"]))
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, height, size.y)
	_body(shape, Transform3D(basis, Vector3(center.x, bottom + height / 2.0, center.y)))
	var color := layout.color_of_zone(block["zone"])
	if block["wall"]:
		_merger.add(&"board", _merged(&"board"), true, _box(shape.size), Transform3D(basis, Vector3(center.x, bottom + height / 2.0, center.y)), color.darkened(0.08))
		_merger.add(&"board", _merged(&"board"), false, _box(Vector3(size.x + 0.18, 0.2, size.y + 0.18)),
			Transform3D(basis, Vector3(center.x, top - 0.02, center.y)), color.lightened(0.6))
		return
	var lip := minf(LIP, height)
	if height - lip > 0.02:
		_merger.add(&"board", _merged(&"board"), true, _box(Vector3(size.x, height - lip, size.y)),
			Transform3D(basis, Vector3(center.x, bottom + (height - lip) / 2.0, center.y)), color.darkened(BODY_SHADE))
	_merger.add(&"board", _merged(&"board"), true, _box(Vector3(size.x + LIP_OUT * 2.0, lip, size.y + LIP_OUT * 2.0)),
		Transform3D(basis, Vector3(center.x, top - lip / 2.0, center.y)), color)


#A slope. Solid, it is a prism filled down to the ground (smooth or with steps); otherwise a thin walkway with lights on its sides
func _build_ramp(ramp: Dictionary) -> void:
	var from: Vector3 = ramp["from"]
	var to: Vector3 = ramp["to"]
	var width: float = ramp["width"]
	var run := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length := run.length()
	var direction := run / maxf(length, 0.001)
	var slope := (to.y - from.y) / maxf(length, 0.001)
	var low := from - direction * OVERLAP - Vector3(0.0, slope * OVERLAP, 0.0)
	var high := to + direction * OVERLAP + Vector3(0.0, slope * OVERLAP, 0.0)
	var color := layout.color_of_zone(ramp["zone"])
	if not ramp["solid"]:
		var basis := Basis.looking_at((high - low).normalized(), Vector3.UP)
		var span := low.distance_to(high)
		var centre := (low + high) / 2.0 - basis.y * WALK_THICKNESS / 2.0
		var shape := BoxShape3D.new()
		shape.size = Vector3(width, WALK_THICKNESS, span)
		_body(shape, Transform3D(basis, centre))
		_merger.add(&"board", _merged(&"board"), true, _box(shape.size), Transform3D(basis, centre), WALKWAY_COLOR)
		var edge := _box(Vector3(EDGE_WIDTH, EDGE_HEIGHT, span - 2.0 * OVERLAP - 0.4))
		for way: float in [-1.0, 1.0]:
			var edge_at := centre + basis * Vector3(way * (width / 2.0 - EDGE_WIDTH / 2.0), WALK_THICKNESS / 2.0 + EDGE_HEIGHT / 2.0, 0.0)
			_merger.add(&"glow", _merged(&"glow"), false, edge, Transform3D(basis, edge_at), EDGE_COLOR)
		return
	low.y = maxf(low.y, ArenaLayout.GROUND)
	var side := Vector3(-direction.z, 0.0, direction.x) * width / 2.0
	var floor_y := ArenaLayout.GROUND
	var corners: Array[Vector3] = [low - side, low + side, high + side, high - side]
	var points := PackedVector3Array()
	for corner in corners:
		points.append(corner)
		points.append(Vector3(corner.x, floor_y, corner.z))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	_body(shape, Transform3D.IDENTITY)
	if ramp["steps"]:
		_build_steps(low, high, width, color)
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var down := Vector3(0.0, floor_y, 0.0)
	var feet: Array[Vector3] = []
	for corner in corners:
		feet.append(Vector3(corner.x, 0.0, corner.z) + down)
	var up := Vector3(-direction.x * slope, 1.0, -direction.z * slope).normalized()
	_quad(tool, corners[0], corners[1], corners[2], corners[3], up)
	_quad(tool, feet[0], corners[0], corners[3], feet[3], -side.normalized())
	_quad(tool, feet[1], corners[1], corners[2], feet[2], side.normalized())
	_quad(tool, feet[3], corners[3], corners[2], feet[2], direction)
	_quad(tool, feet[0], corners[0], corners[1], feet[1], -direction)
	_merger.add(&"board", _merged(&"board"), true, tool.commit(), Transform3D.IDENTITY, color.lightened(0.12))


#A staircase over the slope of a ramp: boxes that rise one after the other, in two tones so each step reads
func _build_steps(low: Vector3, high: Vector3, width: float, color: Color) -> void:
	var count := maxi(ceili((high.y - low.y) / STEP_RISE), 2)
	var run := Vector3(high.x - low.x, 0.0, high.z - low.z)
	var basis := Basis(Vector3.UP, atan2(run.x, run.z))
	var depth := run.length() / count
	for step in count:
		var top := lerpf(low.y, high.y, (step + 0.5) / count)
		var middle := low + run * ((step + 0.5) / count)
		var height := maxf(top - ArenaLayout.GROUND, 0.05)
		_merger.add(&"board", _merged(&"board"), true, _box(Vector3(width, height, depth)),
			Transform3D(basis, Vector3(middle.x, ArenaLayout.GROUND + height / 2.0, middle.z)), color.lightened(0.3) if step % 2 == 0 else color.lightened(0.05))


#A round pillar to stand on, with the same lighter layer on top as the blocks
func _build_drum(drum: Dictionary) -> void:
	var center: Vector2 = drum["center"]
	var radius: float = drum["radius"]
	var top: float = drum["top"]
	var bottom: float = drum["bottom"]
	var height := top - bottom
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	_body(shape, Transform3D(Basis.IDENTITY, Vector3(center.x, bottom + height / 2.0, center.y)))
	var color := layout.color_of_zone(drum["zone"])
	var lip := minf(LIP, height)
	if height - lip > 0.02:
		_merger.add(&"board", _merged(&"board"), true, _disc(radius, radius, height - lip),
			Transform3D(Basis.IDENTITY, Vector3(center.x, bottom + (height - lip) / 2.0, center.y)), color.darkened(BODY_SHADE))
	_merger.add(&"board", _merged(&"board"), true, _disc(radius + LIP_OUT, radius + LIP_OUT, lip),
		Transform3D(Basis.IDENTITY, Vector3(center.x, top - lip / 2.0, center.y)), color)


#The fence along every side of the outline: an unseen wall, a curb, a candy rail with lights and a post at each corner
func _build_fence() -> void:
	var middle := Vector2.ZERO
	for corner in layout.outline:
		middle += corner / layout.outline.size()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in layout.outline.size():
		var from := layout.outline[index]
		var to := layout.outline[(index + 1) % layout.outline.size()]
		var along := (to - from).normalized()
		var outward := Vector2(along.y, -along.x)
		if outward.dot((from + to) / 2.0 - middle) < 0.0:
			outward = -outward
		var length := from.distance_to(to)
		var basis := Basis(Vector3.UP, atan2(along.x, along.y))
		var centre := (from + to) / 2.0 + outward * FENCE_THICKNESS / 2.0
		var shape := BoxShape3D.new()
		shape.size = Vector3(FENCE_THICKNESS, FENCE_HEIGHT, length + FENCE_THICKNESS * 2.0)
		_body(shape, Transform3D(basis, Vector3(centre.x, ArenaLayout.GROUND + FENCE_HEIGHT / 2.0 - 1.0, centre.y)))
		var curb_at := (from + to) / 2.0 + outward * CURB_WIDTH / 2.0
		_merger.add(&"board", _merged(&"board"), false, _box(Vector3(CURB_WIDTH, CURB_HEIGHT, length + CURB_WIDTH)),
			Transform3D(basis, Vector3(curb_at.x, ArenaLayout.GROUND + CURB_HEIGHT / 2.0, curb_at.y)), PartyKit.WHITE)
		var rail_from := Vector3(from.x, RAIL_HEIGHT, from.y) + Vector3(outward.x, 0.0, outward.y) * CURB_WIDTH / 2.0
		var rail_to := Vector3(to.x, RAIL_HEIGHT, to.y) + Vector3(outward.x, 0.0, outward.y) * CURB_WIDTH / 2.0
		_add_tube(tool, rail_from, rail_to, RAIL_TUBE, 8)
		var count := maxi(roundi(length / BULB_SPACING), 1)
		for step in count:
			var at := rail_from.lerp(rail_to, (step + 0.5) / count)
			_bulb_spots.append(Transform3D(Basis.IDENTITY, at + Vector3(0.0, RAIL_TUBE + 0.06, 0.0)))
			_bulb_colors.append(PartyKit.PALETTE[(step + index) % PartyKit.PALETTE.size()])
			_bulb_phases.append(step * 0.7 + index * 1.3)
		_merger.add(&"board", _merged(&"board"), false, _disc(0.34, 0.4, RAIL_HEIGHT + 0.5),
			Transform3D(Basis.IDENTITY, rail_from + Vector3(0.0, (0.5 - RAIL_HEIGHT) / 2.0, 0.0)), PartyKit.PALETTE[index % PartyKit.PALETTE.size()])
	_merger.add(&"rim", _merged(&"rim"), false, tool.commit(), Transform3D.IDENTITY, PartyKit.PINK)


#A straight candy tube between two points, with its stripes counted along it
func _add_tube(tool: SurfaceTool, from: Vector3, to: Vector3, radius: float, sides: int) -> void:
	var along := (to - from).normalized()
	var across := Vector3.UP.cross(along).normalized()
	var stripes := roundf(from.distance_to(to) / RAIL_STRIPE)
	for side in sides:
		var turns: Array[float] = [TAU * side / sides, TAU * (side + 1) / sides]
		var rim: Array[Vector3] = []
		for turn in turns:
			rim.append(across * cos(turn) + Vector3.UP * sin(turn))
		var corners: Array[Vector3] = [from + rim[0] * radius, to + rim[0] * radius, to + rim[1] * radius, from + rim[1] * radius]
		var normals: Array[Vector3] = [rim[0], rim[0], rim[1], rim[1]]
		var coords: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(stripes, 0.0), Vector2(stripes, 1.0), Vector2(0.0, 1.0)]
		var order: Array[int] = [0, 1, 2, 0, 2, 3]
		if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(rim[0] + rim[1]) > 0.0:
			order = [0, 2, 1, 0, 3, 2]
		for index in order:
			tool.set_normal(normals[index])
			tool.set_uv(coords[index])
			tool.add_vertex(corners[index])


#A flat face of four corners that is seen from the side "outward" points to
func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	var corners: Array[Vector3] = [a, b, c, a, c, d]
	if (b - a).cross(c - a).dot(outward) > 0.0:
		corners = [a, c, b, a, d, c]
	for corner in corners:
		tool.set_normal(outward)
		tool.add_vertex(corner)


#The sensor of a place and, when it is big enough, a mark on its floor: two flat discs in lighter tones of its zone
func _build_place(id: StringName) -> void:
	var centre := layout.position_of(id)
	var radius := layout.radius_of(id)
	var sensor := CylinderShape3D.new()
	sensor.radius = maxf(radius - 0.1, 0.4)
	sensor.height = SENSOR_HEIGHT
	_place_areas[id] = _sensor(sensor, Transform3D(Basis.IDENTITY, centre + Vector3(0.0, SENSOR_HEIGHT / 2.0 - SENSOR_SINK, 0.0)))
	if radius < MARK_MIN:
		return
	var color := layout.color_of_zone(layout.zone_of(id))
	for ring: Array in [[0.8, 0.35, 0.02], [0.5, 0.6, 0.027]]:
		var disc := _disc(radius * float(ring[0]), radius * float(ring[0]), 0.03)
		_merger.add(&"board", _merged(&"board"), false, disc, Transform3D(Basis.IDENTITY, centre + Vector3(0.0, float(ring[2]), 0.0)), color.lightened(float(ring[1])))


#The sensor of a link that is walked: a box along it, from the rim of one place to the rim of the other
func _build_link(entry: ArenaLayout.Link) -> void:
	if entry.kind == ArenaLayout.DROP or entry.kind == ArenaLayout.LAUNCH:
		return
	var from := layout.position_of(entry.a)
	var to := layout.position_of(entry.b)
	var way := (to - from).normalized()
	var start := from + way * layout.radius_of(entry.a)
	var end := to - way * layout.radius_of(entry.b)
	if (end - start).dot(way) < 0.5:
		return
	var basis := Basis.looking_at(way, Vector3.UP)
	var sensor := BoxShape3D.new()
	sensor.size = Vector3(LINK_WIDTH, SENSOR_HEIGHT, start.distance_to(end))
	_link_areas.append([entry.a, entry.b, _sensor(sensor, Transform3D(basis, (start + end) / 2.0 + Vector3(0.0, SENSOR_HEIGHT / 2.0 - SENSOR_SINK, 0.0)))])


func _build_spinners() -> void:
	for spinner in layout.spinners:
		var pivot := Node3D.new()
		pivot.position = (spinner["at"] as Vector3) + Vector3(0.0, 0.02, 0.0)
		add_child(pivot)
		pivot.add_child(PropKit.make(&"bumper", Vector3(float(spinner["arm"]) * 2.0, BAR_HEIGHT, 0.6)))
		pivot.add_child(PropKit.make_tall(&"cone", 1.5))
		_spinners.append(pivot)


#The padded block of each sweeper and the dark rail it runs on, with a yellow stop at each end
func _build_blocks() -> void:
	for sweeper in layout.sweepers:
		var from: Vector3 = sweeper["a"]
		var to: Vector3 = sweeper["b"]
		var basis := Basis.looking_at((to - from).normalized(), Vector3.UP)
		var holder := Node3D.new()
		add_child(holder)
		holder.add_child(PropKit.make(&"foam_block", BLOCK_SIZE))
		holder.basis = basis
		holder.global_position = ArenaHazards.block_center(sweeper, 0.0)
		var rail := Node3D.new()
		add_child(rail)
		rail.basis = basis
		rail.global_position = (from + to) / 2.0
		var rail_length := from.distance_to(to) + BLOCK_SIZE.z + 0.3
		_piece(rail, _box(Vector3(BLOCK_SIZE.x + 0.45, 0.03, rail_length)), PartyKit.paint(PartyKit.INK, 0.0, 0.6), Vector3(0.0, 0.02, 0.0))
		for way: float in [-1.0, 1.0]:
			_piece(rail, _disc(0.17, 0.2, 0.42), PartyKit.paint(PartyKit.YELLOW, 0.8, 0.35), Vector3(0.0, 0.2, rail_length / 2.0 * way))
		_blocks.append({"node": holder, "rail": rail, "sweeper": sweeper})


#A trampoline is a dark base, a pink ring and a yellow skin that glows; a cannon is a gold cushion with an arrow toward where
#it throws, a row of hoops along its arc and a ring where it lands
func _build_pads() -> void:
	for pad in layout.pads:
		var node := Node3D.new()
		node.position = (pad["at"] as Vector3) + Vector3(0.0, 0.03, 0.0)
		add_child(node)
		var cannon := ArenaHazards.is_cannon(pad)
		var color := CANNON_COLOR if cannon else PartyKit.YELLOW
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.3
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.1
		_piece(node, _disc(ArenaHazards.PAD_REACH + 0.2, ArenaHazards.PAD_REACH + 0.3, 0.16), PartyKit.paint(PartyKit.INK, 0.0, 0.6), Vector3(0.0, 0.08, 0.0))
		var skin := _piece(node, _disc(ArenaHazards.PAD_REACH, ArenaHazards.PAD_REACH, 0.08), material, Vector3(0.0, 0.19, 0.0))
		var ring := TorusMesh.new()
		ring.outer_radius = ArenaHazards.PAD_REACH + 0.22
		ring.inner_radius = ArenaHazards.PAD_REACH - 0.02
		ring.rings = 28
		ring.ring_segments = 8
		_piece(node, ring, PartyKit.candy(PartyKit.WHITE, PartyKit.ORANGE if cannon else PartyKit.PINK, 12.0, 0.0, 0.2), Vector3(0.0, 0.2, 0.0))
		_pads.append({"node": node, "pad": pad, "skin": skin, "material": material})
		if cannon:
			_build_arc(node, pad)


#What tells where a cannon throws: an arrow on its skin, hoops along the flight and a ring on the floor where it ends
func _build_arc(node: Node3D, pad: Dictionary) -> void:
	var from: Vector3 = pad["at"]
	var to: Vector3 = pad["to"]
	var aim := Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
	var arrow := PrismMesh.new()
	arrow.size = Vector3(0.9, 0.9, 0.04)
	var mark := _piece(node, arrow, PartyKit.paint(PartyKit.WHITE, 0.8, 0.3), Vector3(0.0, 0.25, 0.0))
	mark.basis = Basis.looking_at(aim, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2.0)
	var hoop := TorusMesh.new()
	hoop.inner_radius = 1.25
	hoop.outer_radius = 1.6
	hoop.rings = 24
	hoop.ring_segments = 6
	var time: float = pad["time"]
	for index in HOOPS:
		var seconds := time * float(index + 1) / float(HOOPS + 1)
		var heading := ArenaHazards.pad_launch(pad, _gravity) - Vector3(0.0, _gravity * seconds, 0.0)
		var ring := _piece(self, hoop, PartyKit.paint(CANNON_COLOR, 1.3, 0.4), ArenaHazards.pad_arc(pad, seconds, _gravity) + Vector3(0.0, 0.9, 0.0))
		ring.basis = Basis.looking_at(heading.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0)
	var target := TorusMesh.new()
	target.inner_radius = 1.5
	target.outer_radius = 1.72
	target.rings = 32
	target.ring_segments = 6
	_piece(self, target, PartyKit.paint(CANNON_COLOR, 1.2, 0.4), to + Vector3(0.0, 0.06, 0.0))


#A belt is a strip with arrows lying on the floor it drags over
func _build_belts() -> void:
	for belt in layout.belts:
		var from: Vector3 = belt["a"]
		var to: Vector3 = belt["b"]
		var basis := Basis.looking_at((to - from).normalized(), Vector3.UP)
		var length := from.distance_to(to)
		var material := StandardMaterial3D.new()
		material.albedo_texture = BELT_TEXTURE
		material.roughness = 0.55
		material.emission_enabled = true
		material.emission = BELT_EDGE
		material.emission_energy_multiplier = 0.0
		var strip := _piece(self, _box(Vector3(float(belt["width"]), 0.05, length)), material, (from + to) / 2.0 + basis.y * BELT_LIFT)
		strip.basis = basis
		_belts.append({"belt": belt, "material": material, "tiles": length / BELT_TILE})


func _piece(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


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


#The materials of the joined meshes read the colour of each vertex, so one serves every piece of the map
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
	else:
		var shaded := ShaderMaterial.new()
		shaded.shader = CANDY_VERTEX if kind == &"rim" else GLOW_VERTEX
		material = shaded
	_merged_materials[kind] = material
	return material
