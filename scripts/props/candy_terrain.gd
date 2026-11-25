class_name CandyTerrain
extends RefCounted

#Floating candy ground: checkered tops, skirts, striped bumpers with bulbs, ramps and inlays

const BOARD_TEXTURE: Texture2D = preload("res://assets/textures/board_checker.png")
const CANDY_VERTEX: Shader = preload("res://assets/shaders/candy_vertex.gdshader")
const GLOW_VERTEX: Shader = preload("res://assets/shaders/tint_glow.gdshader")
const EDGE_SHADER: Shader = preload("res://assets/shaders/edge_light.gdshader")

const THICKNESS := 0.6
#Skirt depth and how much narrower its bottom is
const SKIRT_DEPTH := 1.6
const SKIRT_NARROW := 0.55
#Bumper tube thickness, lift and stripe length
const RIM_TUBE := 0.22
const RIM_LIFT := 0.1
const RIM_INSET := 0.12
const RIM_STRIPE := 1.5
const RIM_STEP := 0.6
const BULB_SPACING := 1.6
const BULB_LIFT := 0.42
#The invisible rim wall is higher than a jump plus dive
const WALL_HEIGHT := 1.6
const WALL_THICKNESS := 0.4
const EDGE_WIDTH := 0.2
const EDGE_HEIGHT := 0.07
const RAMP_THICKNESS := 0.5

var merger := MeshMerger.new()
#Rim wall height; raised pieces near a rim need more
var wall_height := WALL_HEIGHT

var _root: Node3D
var _materials: Dictionary = {}
var _bulb_spots: Array[Transform3D] = []
var _bulb_colors: Array[Color] = []
var _bulb_phases: Array[float] = []
var _edge_spots: Array[Transform3D] = []
var _edge_colors: Array[Color] = []
var _bulb_palette: Array[Color] = PartyKit.PALETTE


#"root" holds the bodies and the joined meshes
func _init(root: Node3D) -> void:
	_root = root


func set_bulb_palette(colors: Array[Color]) -> void:
	_bulb_palette = colors


#Round outline of "steps" corners
static func circle(center: Vector2, radius: float, steps := 48) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in steps:
		var angle := TAU * step / steps
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


#Rounded box turned "yaw"; corner at half the short side makes a stadium
static func rounded_box(center: Vector2, size: Vector2, corner: float, yaw := 0.0, steps := 8) -> PackedVector2Array:
	var points := PackedVector2Array()
	var half := size / 2.0 - Vector2.ONE * corner
	var middles: Array[Vector2] = [Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y), Vector2(half.x, -half.y)]
	for index in 4:
		for step in steps + 1:
			var angle := PI / 2.0 * index + PI / 2.0 * step / steps
			var local := middles[index] + Vector2(cos(angle), sin(angle)) * corner
			var point := center + local.rotated(yaw)
			if points.is_empty() or (point.distance_to(points[-1]) > 0.01 and point.distance_to(points[0]) > 0.01):
				points.append(point)
	return points


#Convex island with a striped bumper; a mouth (x, z, half width) leaves the rim open
func island(outline: PackedVector2Array, top: float, color: Color, rim: Color, mouths: Array[Vector3] = [], walled := false, bulbs := true) -> void:
	slab(outline, top, top - THICKNESS, color, true)
	_skirt(outline, top - THICKNESS, color.darkened(0.35))
	_rim(outline, top, rim, mouths, walled, bulbs)


#Floor without its own bumper, for joined floors
func tray(outline: PackedVector2Array, top: float, color: Color) -> void:
	slab(outline, top, top - THICKNESS, color, true)
	_skirt(outline, top - THICKNESS, color.darkened(0.35))


#Raised block on a floor, with bumper and no skirt
func platform(outline: PackedVector2Array, top: float, bottom: float, color: Color, rim: Color, mouths: Array[Vector3] = [], bulbs := true) -> void:
	slab(outline, top, bottom, color, true)
	_rim(outline, top, rim, mouths, false, bulbs)


#Solid prism from "bottom" to "top"
func slab(outline: PackedVector2Array, top: float, bottom: float, color: Color, collide := true, sides := Color.TRANSPARENT) -> void:
	if collide:
		var points := PackedVector3Array()
		for corner in outline:
			points.append(Vector3(corner.x, top, corner.y))
			points.append(Vector3(corner.x, bottom, corner.y))
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		_body(shape)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cap(tool, outline, top, Vector3.UP)
	_add(&"board", true, tool, color, outline)
	var skin := SurfaceTool.new()
	skin.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sides(skin, outline, top, bottom, outline)
	_add(&"board", true, skin, sides if sides.a > 0.0 else color.darkened(0.18), outline)


#Flat non-colliding shape on a floor: lanes, marks and carpets
func inlay(outline: PackedVector2Array, height: float, color: Color, glow := false) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cap(tool, outline, height, Vector3.UP)
	_add(&"glow" if glow else &"plain", false, tool, color, outline)


#Straight walkway with light strips; collides as a box under its floor
func ramp(from: Vector3, to: Vector3, width: float, color: Color, edge: Color = Color("7ae6ff"), overlap := 0.3) -> void:
	var way := (to - from).normalized()
	var low := from - way * overlap
	var high := to + way * overlap
	var basis := Basis.looking_at(way, Vector3.UP if absf(way.y) < 0.99 else Vector3.BACK)
	var length := low.distance_to(high)
	var centre := (low + high) / 2.0 - basis.y * RAMP_THICKNESS / 2.0
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, RAMP_THICKNESS, length)
	_body(shape, Transform3D(basis, centre))
	merger.add(&"board", material(&"board"), true, _box(shape.size), Transform3D(basis, centre), color)
	if edge.a <= 0.0:
		return
	for side: float in [-1.0, 1.0]:
		var at := centre + basis * Vector3(side * (width / 2.0 - EDGE_WIDTH / 2.0), RAMP_THICKNESS / 2.0 + EDGE_HEIGHT / 2.0, 0.0)
		_edge_spots.append(Transform3D(basis.scaled_local(Vector3(EDGE_WIDTH, EDGE_HEIGHT, length - 0.8)), at))
		_edge_colors.append(edge)


#Solid slope from "low" to "high" with light strips
func wedge(low: Vector3, high: Vector3, width: float, color: Color, bottom: float, edge: Color = Color("7ae6ff")) -> void:
	var run := Vector3(high.x - low.x, 0.0, high.z - low.z)
	var way := run.normalized()
	var side := Vector3(-way.z, 0.0, way.x) * width / 2.0
	var top: Array[Vector3] = [low - side, low + side, high + side, high - side]
	var points := PackedVector3Array()
	for corner in top:
		points.append(corner)
		points.append(Vector3(corner.x, bottom, corner.z))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	_body(shape)
	var feet: Array[Vector3] = []
	for corner in top:
		feet.append(Vector3(corner.x, bottom, corner.z))
	var slope := (high.y - low.y) / maxf(run.length(), 0.01)
	var up := Vector3(-way.x * slope, 1.0, -way.z * slope).normalized()
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	_triangle(face, top[0], top[1], top[2], up)
	_triangle(face, top[0], top[2], top[3], up)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pair: Array in [[0, 3, -side.normalized()], [1, 2, side.normalized()], [3, 2, way]]:
		var a: int = pair[0]
		var b: int = pair[1]
		_triangle(walls, feet[a], top[a], top[b], pair[2])
		_triangle(walls, feet[a], top[b], feet[b], pair[2])
	var middle := PackedVector2Array([Vector2(low.x, low.z), Vector2(high.x, high.z)])
	_add(&"board", true, face, color, middle)
	_add(&"board", true, walls, color.darkened(0.18), middle)
	if edge.a <= 0.0:
		return
	var length := run.length() / cos(atan(slope))
	var basis := Basis.looking_at((high - low).normalized(), Vector3.UP)
	for way_side: float in [-1.0, 1.0]:
		var at := (low + high) / 2.0 + basis * Vector3(way_side * (width / 2.0 - EDGE_WIDTH / 2.0), EDGE_HEIGHT / 2.0, 0.0)
		_edge_spots.append(Transform3D(basis.scaled_local(Vector3(EDGE_WIDTH, EDGE_HEIGHT, length - 0.4)), at))
		_edge_colors.append(edge)


#Striped bumper tube along a line; closed when the last point is the first
func rail(points: PackedVector3Array, color: Color, bulbs := false, radius := RIM_TUBE, round_ends := false, sides := 10) -> void:
	var line: Array[Vector3] = []
	for point in points:
		line.append(point)
	var closed := line.size() > 2 and line[0].distance_to(line[-1]) < 0.01
	if closed:
		line.pop_back()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := _sweep(tool, line, closed, radius, sides, 0.0)
	if round_ends and not closed and line.size() >= 2:
		_round_end(tool, line[0], (line[1] - line[0]).normalized(), -1.0, radius, sides, 0.0)
		_round_end(tool, line[-1], (line[-1] - line[-2]).normalized(), 1.0, radius, sides, length / RIM_STRIPE)
	if bulbs:
		_bulbs_on(line, closed, Vector3.ZERO, 0.0)
	merger.add(&"rim", material(&"rim"), false, _commit(tool), Transform3D.IDENTITY, color, Vector2.ONE, (points[0].z + points[-1].z) / 2.0)


#Invisible wall from "from" to "to"
func wall(from: Vector2, to: Vector2, bottom: float, height := WALL_HEIGHT) -> void:
	var along := to - from
	var length := along.length()
	if length < 0.05:
		return
	var shape := BoxShape3D.new()
	shape.size = Vector3(WALL_THICKNESS, height, length)
	var middle := (from + to) / 2.0
	_body(shape, Transform3D(Basis(Vector3.UP, atan2(along.x, along.y)), Vector3(middle.x, bottom + height / 2.0, middle.y)))


#Bulbs on any spots in the bulb colours
func add_bulb(at: Vector3, phase: float) -> void:
	_bulb_spots.append(Transform3D(Basis.IDENTITY, at))
	_bulb_colors.append(_bulb_palette[_bulb_spots.size() % _bulb_palette.size()])
	_bulb_phases.append(phase)


#Materials read the vertex colour, so one serves the whole map
func material(kind: StringName) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var made: Material
	match kind:
		&"board":
			var board := StandardMaterial3D.new()
			board.albedo_texture = BOARD_TEXTURE
			board.roughness = 0.55
			board.uv1_triplanar = true
			board.uv1_world_triplanar = true
			board.uv1_scale = Vector3.ONE / 6.0
			board.vertex_color_use_as_albedo = true
			board.vertex_color_is_srgb = true
			made = board
		&"plain", &"skirt":
			var plain := StandardMaterial3D.new()
			plain.roughness = 0.6 if kind == &"skirt" else 0.45
			plain.vertex_color_use_as_albedo = true
			plain.vertex_color_is_srgb = true
			made = plain
		&"rim":
			made = ShaderMaterial.new()
			(made as ShaderMaterial).shader = CANDY_VERTEX
		_:
			made = ShaderMaterial.new()
			(made as ShaderMaterial).shader = GLOW_VERTEX
	_materials[kind] = made
	return made


#Joins meshes, bulbs and light strips under the root
func commit() -> void:
	merger.commit(_root)
	if not _bulb_spots.is_empty():
		_root.add_child(PartyKit.bulbs(_bulb_spots, _bulb_colors, _bulb_phases))
	if _edge_spots.is_empty():
		return
	var strip := BoxMesh.new()
	var shaded := ShaderMaterial.new()
	shaded.shader = EDGE_SHADER
	strip.material = shaded
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = strip
	multi.instance_count = _edge_spots.size()
	for slot in _edge_spots.size():
		multi.set_instance_transform(slot, _edge_spots[slot])
		multi.set_instance_color(slot, _edge_colors[slot])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(instance)


#Skirt narrowing toward a ring of light
func _skirt(outline: PackedVector2Array, at: float, color: Color) -> void:
	var middle := _middle(outline)
	var upper := _scaled(outline, middle, 0.97)
	var lower := _scaled(outline, middle, SKIRT_NARROW)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sides(tool, upper, at, at - SKIRT_DEPTH, lower)
	_cap(tool, lower, at - SKIRT_DEPTH, Vector3.DOWN)
	_add(&"skirt", false, tool, color, outline)
	var glow := SurfaceTool.new()
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector3] = []
	for corner in _scaled(outline, middle, SKIRT_NARROW * 0.96):
		ring.append(Vector3(corner.x, at - SKIRT_DEPTH - 0.05, corner.y))
	_sweep(glow, ring, true, 0.11, 6, 0.0)
	_add(&"glow", false, glow, color.lightened(0.55), outline)


#Bumper, bulbs and wall along the rim, skipping the mouths
func _rim(outline: PackedVector2Array, top: float, color: Color, mouths: Array[Vector3], walled: bool, bulbs: bool) -> void:
	var middle := _middle(outline)
	var samples: Array[Vector3] = []
	var opens: Array[bool] = []
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var pieces := maxi(ceili(a.distance_to(b) / RIM_STEP), 1)
		var inward := (middle - (a + b) / 2.0).normalized() * RIM_INSET
		var run_from := -1.0
		for piece in pieces + 1:
			var share := float(piece) / pieces
			var open := piece < pieces and _in_mouth(a.lerp(b, share + 0.5 / pieces), mouths)
			if piece < pieces:
				var spot := a.lerp(b, share) + inward
				samples.append(Vector3(spot.x, top + RIM_LIFT, spot.y))
				opens.append(open)
			if walled:
				if piece < pieces and not open and run_from < 0.0:
					run_from = share
				if (open or piece == pieces) and run_from >= 0.0:
					wall(a.lerp(b, run_from) + inward, a.lerp(b, share) + inward, top, wall_height)
					run_from = -1.0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lift := Vector3(0.0, BULB_LIFT - RIM_LIFT, 0.0)
	var first_open := opens.find(true)
	if first_open < 0:
		_sweep(tool, samples, true, RIM_TUBE, 10, 0.0)
		if bulbs:
			_bulbs_on(samples, true, lift, 0.0)
	else:
		var run: Array[Vector3] = []
		var travelled := 0.0
		for step in samples.size() + 1:
			var index := (first_open + 1 + step) % samples.size()
			var closes := opens[(index - 1 + samples.size()) % samples.size()] or step == samples.size()
			if closes and run.size() >= 2:
				var length := _sweep(tool, run, false, RIM_TUBE, 10, travelled / RIM_STRIPE)
				if bulbs:
					_bulbs_on(run, false, lift, travelled)
				travelled += length
			if closes:
				run = []
			run.append(samples[index])
	_add(&"rim", false, tool, color, outline)


func _in_mouth(point: Vector2, mouths: Array[Vector3]) -> bool:
	for mouth in mouths:
		if point.distance_to(Vector2(mouth.x, mouth.y)) <= mouth.z:
			return true
	return false


#Bulbs every BULB_SPACING meters
func _bulbs_on(line: Array[Vector3], closed: bool, lift: Vector3, travelled: float) -> void:
	var count := line.size() if closed else line.size() - 1
	var along := travelled
	for index in count:
		var from := line[index] + lift
		var to := line[(index + 1) % line.size()] + lift
		_bulbs_along(from, to, along)
		along += from.distance_to(to)


func _bulbs_along(from: Vector3, to: Vector3, travelled: float) -> void:
	var length := from.distance_to(to)
	var first := fposmod(-travelled, BULB_SPACING)
	var along := first
	while along < length:
		add_bulb(from.lerp(to, along / length), (travelled + along) * 0.45)
		along += BULB_SPACING


#Flat fan over a convex outline
func _cap(tool: SurfaceTool, outline: PackedVector2Array, height: float, facing: Vector3) -> void:
	var middle := _middle(outline)
	var centre := Vector3(middle.x, height, middle.y)
	for index in outline.size():
		var a := Vector3(outline[index].x, height, outline[index].y)
		var b_point := outline[(index + 1) % outline.size()]
		var b := Vector3(b_point.x, height, b_point.y)
		_triangle(tool, centre, a, b, facing)


#Side walls between two outlines
func _sides(tool: SurfaceTool, upper: PackedVector2Array, top: float, bottom: float, lower: PackedVector2Array) -> void:
	var middle := _middle(upper)
	for index in upper.size():
		var next := (index + 1) % upper.size()
		var a := Vector3(upper[index].x, top, upper[index].y)
		var b := Vector3(upper[next].x, top, upper[next].y)
		var c := Vector3(lower[next].x, bottom, lower[next].y)
		var d := Vector3(lower[index].x, bottom, lower[index].y)
		var out_2 := ((upper[index] + upper[next]) / 2.0 - middle).normalized()
		var outward := Vector3(out_2.x, 0.0, out_2.y)
		_triangle(tool, a, b, c, outward)
		_triangle(tool, a, c, d, outward)


#Smooth tube with rings turned halfway at each point; returns its length
func _sweep(tool: SurfaceTool, line: Array[Vector3], closed: bool, radius: float, sides: int, u_from: float) -> float:
	var count := line.size()
	if count < 2:
		return 0.0
	var rings: Array[Array] = []
	var coords: Array[float] = []
	var travelled := 0.0
	for index in count + (1 if closed else 0):
		var at := line[index % count]
		if index > 0:
			travelled += line[(index - 1) % count].distance_to(at)
		var before := line[(index - 1 + count) % count] if (closed or index > 0) else at
		var after := line[(index + 1) % count] if (closed or index < count - 1) else at
		var along := (after - before).normalized()
		var up := Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT
		var across := up.cross(along).normalized()
		var lift := along.cross(across).normalized()
		var ring: Array = []
		for side in sides + 1:
			var turn := TAU * side / sides
			var normal := across * cos(turn) + lift * sin(turn)
			ring.append([at + normal * radius, normal])
		rings.append(ring)
		coords.append(u_from + travelled / RIM_STRIPE)
	for index in rings.size() - 1:
		for side in sides:
			var corners: Array[Array] = [rings[index][side], rings[index + 1][side], rings[index + 1][side + 1], rings[index][side + 1]]
			var uvs: Array[Vector2] = [Vector2(coords[index], float(side) / sides), Vector2(coords[index + 1], float(side) / sides),
				Vector2(coords[index + 1], float(side + 1) / sides), Vector2(coords[index], float(side + 1) / sides)]
			var outward: Vector3 = (corners[0][1] as Vector3) + (corners[2][1] as Vector3)
			var order: Array[int] = [0, 1, 2, 0, 2, 3]
			var a: Vector3 = corners[0][0]
			if ((corners[1][0] as Vector3) - a).cross((corners[2][0] as Vector3) - a).dot(outward) > 0.0:
				order = [0, 2, 1, 0, 3, 2]
			for corner in order:
				tool.set_normal(corners[corner][1])
				tool.set_uv(uvs[corner])
				tool.add_vertex(corners[corner][0])
	return travelled


#Half ball closing an open tube without a seam
func _round_end(tool: SurfaceTool, at: Vector3, along: Vector3, out: float, radius: float, sides: int, u: float) -> void:
	var up := Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT
	var across := up.cross(along).normalized()
	var lift := along.cross(across).normalized()
	var steps := 3
	var rings: Array[Array] = []
	for step in steps + 1:
		var tilt := PI / 2.0 * step / steps
		var ring: Array[Vector3] = []
		for side in sides + 1:
			var turn := TAU * side / sides
			ring.append((across * cos(turn) + lift * sin(turn)) * cos(tilt) + along * out * sin(tilt))
		rings.append(ring)
	for step in steps:
		for side in sides:
			var normals: Array[Vector3] = [rings[step][side], rings[step + 1][side], rings[step + 1][side + 1], rings[step][side + 1]]
			for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = at + normals[triangle[0]] * radius
				var b: Vector3 = at + normals[triangle[1]] * radius
				var c: Vector3 = at + normals[triangle[2]] * radius
				if (b - a).cross(c - a).length_squared() < 0.000001:
					continue
				var order: Array = triangle
				if (b - a).cross(c - a).dot(normals[triangle[0]] + normals[triangle[1]] + normals[triangle[2]]) > 0.0:
					order = [triangle[0], triangle[2], triangle[1]]
				for corner: int in order:
					tool.set_normal(normals[corner])
					tool.set_uv(Vector2(u, float(side) / sides))
					tool.add_vertex(at + normals[corner] * radius)


#Triangle whose front looks along "facing"
func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, facing: Vector3) -> void:
	var corners: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(facing) > 0.0:
		corners = [a, c, b]
	for corner in corners:
		tool.set_normal(facing)
		tool.set_uv(Vector2.ZERO)
		tool.add_vertex(corner)


func _middle(outline: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for corner in outline:
		sum += corner
	return sum / maxf(outline.size(), 1.0)


func _scaled(outline: PackedVector2Array, middle: Vector2, share: float) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	for corner in outline:
		scaled.append(middle + (corner - middle) * share)
	return scaled


func _commit(tool: SurfaceTool) -> ArrayMesh:
	return tool.commit()


#Adds a mesh to the stretch where its outline lies
func _add(kind: StringName, shadow: bool, tool: SurfaceTool, color: Color, outline: PackedVector2Array) -> void:
	merger.add(kind, material(kind), shadow, _commit(tool), Transform3D.IDENTITY, color, Vector2.ONE, _middle(outline).y)


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _body(shape: Shape3D, place := Transform3D.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = place
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	_root.add_child(body)
	return body
