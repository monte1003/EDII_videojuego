class_name ArenaLayout
extends RefCounted

#The single source of truth of an arena map: one solid ground with relief and a fence all around, so there is no void anywhere.
#Blocks, ramps and drums raise the ground into terraces, and walls split it. On the terrain go the places (the vertices of the
#graph: crossings, summits, clearings) and the links between them (its edges, which cost seconds of travel), and what moves:
#bars, blocks, trampolines, cannons and belts. The world is built from it, the bots walk its graph and the rules measure with it

#Kinds of link: a plain way, a way over a belt (cheap with its flow and dear against it), a step down from a terrace that
#nobody can climb back, and the throw of a trampoline or a cannon, also one way
const WALK := &"walk"
const BELT := &"belt"
const DROP := &"drop"
const LAUNCH := &"launch"
#Speed of somebody on foot, to turn meters into seconds of travel
const WALK_SPEED := 5.0
#Height of the ground everything stands on
const GROUND := 0.0
#How much farther than its distance on the ground a place feels for each meter it is above or below
const HEIGHT_WEIGHT := 8.0


class Place:
	var id: StringName
	var position: Vector3
	#Flat room around it: whoever stands this close is "at" the place
	var radius: float
	#Which part of the map it belongs to: it picks its colour
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
	#Seconds from a to b and from b to a; "back" is negative when there is no way back
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
#One colour per zone of the map, and the colour of the ground between them
var zone_colors: Array[Color] = []
var ground_color := Color("d9ccff")
#The fence: the corners of the map on the ground, in order. Nothing can be walked outside it
var outline: PackedVector2Array = PackedVector2Array()
#The terrain. Block: {"center": Vector2, "size": Vector2, "top", "bottom", "yaw", "zone", "wall": bool}.
#Ramp: {"from": Vector3, "to": Vector3, "width", "zone", "steps": bool, "solid": bool}. Drum: {"center": Vector2, "radius", "top", "bottom", "zone"}
var blocks: Array[Dictionary] = []
var ramps: Array[Dictionary] = []
var drums: Array[Dictionary] = []
#A bar that sweeps a circle: {"at": Vector3, "arm", "speed", "phase", "from"} and optionally "surge" {"rate", "depth"}
var spinners: Array[Dictionary] = []
#A padded block that goes back and forth between two points: {"a": Vector3, "b": Vector3, "period", "phase", "from"}
var sweepers: Array[Dictionary] = []
#A trampoline: {"at": Vector3, "from"}. With "to" (Vector3) and "time" it is a cannon that throws along an arc to that point.
#With "beat" {"period", "on", "phase"} it only works for "on" seconds of every "period"
var pads: Array[Dictionary] = []
#A belt lying on the terrain from "a" to "b": {"a": Vector3, "b": Vector3, "width", "from", "turns": bool}; one that turns runs the other way every belt_period
var belts: Array[Dictionary] = []
var belt_period := 9.0
var belt_speed := 3.0
#Where the players start, one per player
var spawn_place: StringName = &""


#A place at a point of the terrain: its height is the one of the floor there
func add_place(id: StringName, x: float, z: float, radius: float, zone: int) -> void:
	places[id] = Place.new(id, Vector3(x, height_at(x, z), z), radius, zone)


#A way between two places. Plain ways and belts go both ways; a drop and a launch only from the first place to the second.
#"extra" are seconds added for what is in the way; "seconds" replaces the time of the way there (a launch says its own)
func link(a: StringName, b: StringName, kind := WALK, extra := 0.0, seconds := -1.0) -> void:
	var walk := position_of(a).distance_to(position_of(b)) / WALK_SPEED + extra
	var there := seconds if seconds >= 0.0 else walk
	var back := walk
	if kind == BELT:
		#With the flow the belt adds its speed, against it takes it away
		var length := position_of(a).distance_to(position_of(b))
		there = length / (WALK_SPEED + belt_speed) + extra
		back = length / (WALK_SPEED - belt_speed) + extra
	elif kind == DROP or kind == LAUNCH:
		back = -1.0
	links.append(Link.new(a, b, kind, there, back))


#A box of terrain: its middle and its size on the ground, how high its top is and how far it is turned. It is solid down to
#"bottom", so a block that starts above the ground is a deck with room to walk under it
func add_block(center: Vector2, size: Vector2, top: float, zone: int, yaw := 0.0, bottom := GROUND) -> void:
	blocks.append({"center": center, "size": size, "top": top, "bottom": bottom, "yaw": yaw, "zone": zone, "wall": false})


#A wall between two points of the ground, too high to jump
func add_wall(from: Vector2, to: Vector2, height: float, zone: int, thickness := 0.6) -> void:
	var along := to - from
	blocks.append({"center": (from + to) / 2.0, "size": Vector2(thickness, along.length() + thickness), "top": height, "bottom": GROUND,
		"yaw": atan2(along.x, along.y), "zone": zone, "wall": true})


#A slope from the middle of its low end to the middle of its high end. Solid, it is filled down to the ground; otherwise it
#is a thin walkway with room under it. With "steps" it looks like a staircase
func add_ramp(from: Vector3, to: Vector3, width: float, zone: int, steps := false, solid := true) -> void:
	ramps.append({"from": from, "to": to, "width": width, "zone": zone, "steps": steps, "solid": solid})


#A round pillar to stand on
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


#How high the floor is at a point of the map: the highest piece of terrain that is under it and not above "ceiling"
func height_at(x: float, z: float, ceiling := INF) -> float:
	var best := GROUND
	var point := Vector2(x, z)
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


#Whether a point of the ground is inside the fence, "margin" meters or more away from it
func is_inside(x: float, z: float, margin := 0.0) -> bool:
	var point := Vector2(x, z)
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


#How far the map reaches from its middle
func reach() -> float:
	var far := 0.0
	for corner in outline:
		far = maxf(far, corner.length())
	return far


#The highest floor of the map
func top_height() -> float:
	var top := GROUND
	for block in blocks:
		if not block["wall"]:
			top = maxf(top, block["top"])
	for drum in drums:
		top = maxf(top, drum["top"])
	return top


#The place a point belongs to: the closest one, where a place on another floor counts as farther than it is
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


#Whether a point stands on the floor of a place (with "margin" meters to spare from its rim)
func is_over(id: StringName, point: Vector3, margin := 0.0) -> bool:
	var at := position_of(id)
	return Vector2(point.x - at.x, point.z - at.z).length() <= radius_of(id) - margin and absf(point.y - at.y) < 1.5


#The graph of the map: a place is a vertex and a link is one arc each way it can be travelled, at the cost of its seconds.
#The bots walk it without the drops and the launches: they never jump off a terrace nor step on a trampoline
func build_graph(for_bots := false) -> WeightedGraph:
	var graph := WeightedGraph.new()
	for id: StringName in places:
		graph.add_vertex(id)
	for entry in links:
		if for_bots and (entry.kind == DROP or entry.kind == LAUNCH):
			continue
		graph.add_edge(entry.a, entry.b, entry.seconds, false)
		if entry.back >= 0.0:
			graph.add_edge(entry.b, entry.a, entry.back, false)
	return graph


#Seconds of the cheapest route between every pair of places, by Dijkstra from each one: {from: {to: seconds}}
func travel_table(graph: WeightedGraph) -> Dictionary:
	var table: Dictionary = {}
	for from: StringName in places:
		var costs := graph.costs_from(from)
		var row: Dictionary = {}
		for to: StringName in places:
			row[to] = costs.get(to, INF)
		table[from] = row
	return table


#Whether what starts at stage "from" is already on at "stage"
static func is_on(entry: Dictionary, stage: int) -> bool:
	return stage >= int(entry.get("from", 0))


#Which way a belt runs at "time": 1 from its first end to the second, -1 the other way, 0 while it is stopped
func belt_flow(belt: Dictionary, stage: int, time: float) -> float:
	if not is_on(belt, stage):
		return 0.0
	if not belt.get("turns", false):
		return 1.0
	return 1.0 if int(time / belt_period) % 2 == 0 else -1.0


#Seconds until the belts that turn do it again
func belt_turn_in(time: float) -> float:
	return belt_period - fposmod(time, belt_period)


func _in_block(block: Dictionary, point: Vector2) -> bool:
	var local := (point - (block["center"] as Vector2)).rotated(float(block["yaw"]))
	var half: Vector2 = (block["size"] as Vector2) / 2.0
	return absf(local.x) <= half.x and absf(local.y) <= half.y


#Height of the surface of a ramp over a point, or a number under the ground when the point is not over it
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
