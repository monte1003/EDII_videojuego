class_name ArenaLayout
extends RefCounted

#Single source of truth of an arena map: ground or islands, terrain, places and graph links

#Link kinds: walk, belt (cheap with the flow), one-way drop and one-way launch
const WALK := &"walk"
const BELT := &"belt"
const DROP := &"drop"
const LAUNCH := &"launch"
#Small jump up both ways: players take it, bots never jump
const HOP := &"hop"
#Walking speed, to turn meters into seconds
const WALK_SPEED := 5.0
#Height of the ground everything stands on
const GROUND := 0.0
#Height of the void under floating islands
const VOID := -60.0
#Extra cost per meter of height difference
const HEIGHT_WEIGHT := 8.0


class Place:
	var id: StringName
	var position: Vector3
	#Flat radius of a place
	var radius: float
	#Map part that picks its colour
	var zone: int

	func _init(name: StringName, at: Vector3, size: float, part: int) -> void:
		id = name
		position = at
		radius = size
		zone = part


class Link:
	var a: StringName
	var b: StringName
	var kind: StringName
	#Seconds a to b and b to a; "back" negative when one way
	var seconds: float
	var back: float

	func _init(from: StringName, to: StringName, type: StringName, there: float, home: float) -> void:
		a = from
		b = to
		kind = type
		seconds = there
		back = home


var places: Dictionary = {}
var links: Array[Link] = []
#Colour per zone and of the ground between them
var zone_colors: Array[Color] = []
var ground_color := Color("d9ccff")
#Fence corners in order; nothing is walkable outside
var outline: PackedVector2Array = PackedVector2Array()
#Floating islands (convex outline and top) joined by bridges; none means ground everywhere
var islands: Array[Dictionary] = []
var bridges: Array[Dictionary] = []
#Terrain pieces: blocks, ramps and drums
var blocks: Array[Dictionary] = []
var ramps: Array[Dictionary] = []
var drums: Array[Dictionary] = []
#Sweeping bar: {"at", "arm", "speed", "phase", "from"}, optional "surge"
var spinners: Array[Dictionary] = []
#Back and forth block: {"a", "b", "period", "phase", "from"}
var sweepers: Array[Dictionary] = []
#Trampoline {"at", "from"}; with "to" and "time" a cannon; with "beat" it rests between periods
var pads: Array[Dictionary] = []
#Belt {"a", "b", "width", "from", "turns"}; turning belts reverse every belt_period
var belts: Array[Dictionary] = []
var belt_period := 9.0
var belt_speed := 3.0
var spawn_place: StringName = &""


#Place on the terrain at the floor height there
func add_place(id: StringName, x: float, z: float, radius: float, zone: int) -> void:
	places[id] = Place.new(id, Vector3(x, height_at(x, z), z), radius, zone)


#Link between places; drops and launches one way; "extra" adds seconds, "seconds" replaces them
func link(a: StringName, b: StringName, kind := WALK, extra := 0.0, seconds := -1.0) -> void:
	var walk := position_of(a).distance_to(position_of(b)) / WALK_SPEED + extra
	var there := seconds if seconds >= 0.0 else walk
	var back := walk
	if kind == BELT:
		#With the flow a belt adds its speed, against it subtracts it
		var length := position_of(a).distance_to(position_of(b))
		there = length / (WALK_SPEED + belt_speed) + extra
		back = length / (WALK_SPEED - belt_speed) + extra
	elif kind == DROP or kind == LAUNCH:
		back = -1.0
	links.append(Link.new(a, b, kind, there, back))


#Terrain box; solid down to "bottom", so a raised one is a deck
func add_block(center: Vector2, size: Vector2, top: float, zone: int, yaw := 0.0, bottom := GROUND) -> void:
	blocks.append({"center": center, "size": size, "top": top, "bottom": bottom, "yaw": yaw, "zone": zone, "wall": false})


#Wall too high to jump
func add_wall(from: Vector2, to: Vector2, height: float, zone: int, thickness := 0.6) -> void:
	var along := to - from
	blocks.append({"center": (from + to) / 2.0, "size": Vector2(thickness, along.length() + thickness), "top": height, "bottom": GROUND,
		"yaw": atan2(along.x, along.y), "zone": zone, "wall": true})


#Slope from low end to high end; solid to the ground or a thin walkway; "steps" looks like stairs
func add_ramp(from: Vector3, to: Vector3, width: float, zone: int, steps := false, solid := true) -> void:
	ramps.append({"from": from, "to": to, "width": width, "zone": zone, "steps": steps, "solid": solid})


#Floating island of a convex outline
func add_island(shape: PackedVector2Array, top: float, zone: int, rim: Color) -> void:
	islands.append({"outline": shape, "top": top, "zone": zone, "rim": rim})


#Wide bridge between two islands
func add_bridge(from: Vector3, to: Vector3, width: float, zone: int) -> void:
	bridges.append({"from": from, "to": to, "width": width, "zone": zone})


func add_drum(center: Vector2, radius: float, top: float, zone: int, bottom := GROUND) -> void:
	drums.append({"center": center, "radius": radius, "top": top, "bottom": bottom, "zone": zone})


func position_of(id: StringName) -> Vector3:
	return (places[id] as Place).position


func radius_of(id: StringName) -> float:
	return (places[id] as Place).radius


func zone_of(id: StringName) -> int:
	return (places[id] as Place).zone


func color_of_zone(zone: int) -> Color:
	return zone_colors[zone % zone_colors.size()]


func link_between(a: StringName, b: StringName) -> Link:
	for entry in links:
		if (entry.a == a and entry.b == b) or (entry.a == b and entry.b == a):
			return entry
	return null


#Floor height at a point: the highest piece under it and not above "ceiling"
func height_at(x: float, z: float, ceiling := INF) -> float:
	var point := Vector2(x, z)
	var best := _base_height(point, ceiling)
	for block in blocks:
		var top: float = block["top"]
		if top > best and top <= ceiling and _in_block(block, point):
			best = top
	for ramp in ramps:
		var height := _ramp_height(ramp, point)
		if height > best and height <= ceiling:
			best = height
	for drum in drums:
		var top: float = drum["top"]
		if top > best and top <= ceiling and point.distance_to(drum["center"]) <= float(drum["radius"]):
			best = top
	return best


#Inside the fence, island or bridge, at least "margin" from the edge
func is_inside(x: float, z: float, margin := 0.0) -> bool:
	var point := Vector2(x, z)
	if not islands.is_empty():
		for island in islands:
			if _in_outline(island["outline"], point, margin):
				return true
		for bridge in bridges:
			if _bridge_share(bridge, point, margin) >= 0.0:
				return true
		return false
	var turn := 0.0
	for index in outline.size():
		var from := outline[index]
		var to := outline[(index + 1) % outline.size()]
		var edge := (to - from).normalized()
		var side := edge.cross(point - from)
		if absf(side) < margin:
			return false
		if turn == 0.0:
			turn = signf(side)
		elif signf(side) != turn:
			return false
	return true


#Ground, island or bridge height under a point; void elsewhere
func _base_height(point: Vector2, ceiling: float) -> float:
	if islands.is_empty():
		return GROUND
	var best := VOID
	for island in islands:
		var top: float = island["top"]
		if top > best and top <= ceiling and Geometry2D.is_point_in_polygon(point, island["outline"]):
			best = top
	for bridge in bridges:
		var share := _bridge_share(bridge, point, 0.0)
		if share >= 0.0:
			var height := lerpf((bridge["from"] as Vector3).y, (bridge["to"] as Vector3).y, share)
			if height > best and height <= ceiling:
				best = height
	return best


#Share along a bridge (0 to 1), or -1 when off it
func _bridge_share(bridge: Dictionary, point: Vector2, margin: float) -> float:
	var from := Vector2((bridge["from"] as Vector3).x, (bridge["from"] as Vector3).z)
	var to := Vector2((bridge["to"] as Vector3).x, (bridge["to"] as Vector3).z)
	var length := from.distance_to(to)
	var way := (to - from) / maxf(length, 0.01)
	var offset := point - from
	var along := offset.dot(way)
	if along < 0.0 or along > length or absf(way.cross(offset)) > float(bridge["width"]) / 2.0 - margin:
		return -1.0
	return along / maxf(length, 0.01)


#Inside a convex outline with "margin"
func _in_outline(shape: PackedVector2Array, point: Vector2, margin: float) -> bool:
	if not Geometry2D.is_point_in_polygon(point, shape):
		return false
	if margin <= 0.0:
		return true
	for index in shape.size():
		var nearest := Geometry2D.get_closest_point_to_segment(point, shape[index], shape[(index + 1) % shape.size()])
		if point.distance_to(nearest) < margin:
			return false
	return true


#How far the map reaches from its middle
func reach() -> float:
	var far := 0.0
	for corner in outline:
		far = maxf(far, corner.length())
	if not islands.is_empty():
		far = 0.0
		for island in islands:
			for corner: Vector2 in island["outline"]:
				far = maxf(far, corner.length())
	return far


func top_height() -> float:
	var top := GROUND
	for block in blocks:
		if not block["wall"]:
			top = maxf(top, block["top"])
	for drum in drums:
		top = maxf(top, drum["top"])
	return top


#Closest place; other floors count as farther
func nearest_place(point: Vector3) -> StringName:
	var best: StringName = &""
	var best_distance := INF
	for id: StringName in places:
		var at := position_of(id)
		var distance := Vector2(point.x - at.x, point.z - at.z).length() - radius_of(id) + absf(point.y - at.y) * HEIGHT_WEIGHT
		if distance < best_distance:
			best_distance = distance
			best = id
	return best


#On the floor of a place with "margin" from its rim
func is_over(id: StringName, point: Vector3, margin := 0.0) -> bool:
	var at := position_of(id)
	return Vector2(point.x - at.x, point.z - at.z).length() <= radius_of(id) - margin and absf(point.y - at.y) < 1.5


#Graph of the map: places are vertices and links arcs costing seconds; bots skip drops and launches
func build_graph(for_bots := false) -> WeightedGraph:
	var graph := WeightedGraph.new()
	for id: StringName in places:
		graph.add_vertex(id)
	for entry in links:
		if for_bots and (entry.kind == DROP or entry.kind == LAUNCH or entry.kind == HOP):
			continue
		graph.add_edge(entry.a, entry.b, entry.seconds, false)
		if entry.back >= 0.0:
			graph.add_edge(entry.b, entry.a, entry.back, false)
	return graph


#Cheapest seconds between every pair of places, Dijkstra from each: {from: {to: seconds}}
func travel_table(graph: WeightedGraph) -> Dictionary:
	var table: Dictionary = {}
	for from: StringName in places:
		var costs := graph.costs_from(from)
		var row: Dictionary = {}
		for to: StringName in places:
			row[to] = costs.get(to, INF)
		table[from] = row
	return table


#Whether what starts at stage "from" is on at "stage"
static func is_on(entry: Dictionary, stage: int) -> bool:
	return stage >= int(entry.get("from", 0))


#Belt direction at "time": 1 forward, -1 back, 0 stopped
func belt_flow(belt: Dictionary, stage: int, time: float) -> float:
	if not is_on(belt, stage):
		return 0.0
	if not belt.get("turns", false):
		return 1.0
	return 1.0 if int(time / belt_period) % 2 == 0 else -1.0


#Seconds until turning belts turn again
func belt_turn_in(time: float) -> float:
	return belt_period - fposmod(time, belt_period)


func _in_block(block: Dictionary, point: Vector2) -> bool:
	var local := (point - (block["center"] as Vector2)).rotated(float(block["yaw"]))
	var half: Vector2 = (block["size"] as Vector2) / 2.0
	return absf(local.x) <= half.x and absf(local.y) <= half.y


#Ramp surface height over a point, or below ground when off it
func _ramp_height(ramp: Dictionary, point: Vector2) -> float:
	var from: Vector3 = ramp["from"]
	var to: Vector3 = ramp["to"]
	var run := Vector2(to.x - from.x, to.z - from.z)
	var length := run.length()
	var direction := run / maxf(length, 0.001)
	var offset := point - Vector2(from.x, from.z)
	var along := offset.dot(direction)
	var across := absf(direction.cross(offset))
	if along < 0.0 or along > length or across > float(ramp["width"]) / 2.0:
		return -INF
	return lerpf(from.y, to.y, along / maxf(length, 0.001))
