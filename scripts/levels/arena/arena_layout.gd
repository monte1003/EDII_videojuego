class_name ArenaLayout
extends RefCounted

#The single source of truth of an arena map: round islands joined by bridges, and what moves on them. The world is built from it,
#the graph of the bots comes from it and the rules measure with it. Each map fills these tables in its own class

const PLAIN := &"plain"
const NARROW := &"narrow"
const BELT := &"belt"
const WIDTHS := {PLAIN: 3.4, NARROW: 1.9, BELT: 3.4}
#Speed of somebody on foot, to turn meters into seconds of travel
const WALK_SPEED := 5.0
#Seconds a narrow bridge adds to the cost of a route: it is slower to cross with care
const NARROW_COST := 0.4

class Island:
	var id: StringName
	var position: Vector3
	var radius: float
	#Which part of the map it belongs to: it picks its colour
	var zone: int

	func _init(name: StringName, at: Vector3, size: float, part: int) -> void:
		id = name
		position = at
		radius = size
		zone = part


class Bridge:
	var a: StringName
	var b: StringName
	var kind: StringName

	func _init(from: StringName, to: StringName, type: StringName) -> void:
		a = from
		b = to
		kind = type


var islands: Dictionary = {}
var bridges: Array[Bridge] = []
#One colour per zone of the map
var zone_colors: Array[Color] = []
#Island id -> {"arm", "speed", "phase", "from"} and optionally "surge" {"rate", "depth"}: a bar that sweeps the whole island
var spinners: Dictionary = {}
#{"edge": [a, b], "at", "period", "phase", "from"}: a block that goes from side to side of a bridge
var sweepers: Array[Dictionary] = []
#Island id -> {"offset": Vector3, "from"}: a trampoline
var pads: Dictionary = {}
#Seconds between two turns of the belts, the speed of a belt and the stage at which they start to run
var belt_period := 9.0
var belt_speed := 3.0
var belt_from := 0
#Where the players start, one per player
var spawn_island: StringName = &""
#Stepping stones: small platforms to jump across, outside the graph. {"position": Vector3, "radius": float, "zone": int}
var stones: Array[Dictionary] = []


func add_island(id: StringName, at: Vector3, radius: float, zone: int) -> void:
	islands[id] = Island.new(id, at, radius, zone)


func add_bridge(a: StringName, b: StringName, kind := PLAIN) -> void:
	bridges.append(Bridge.new(a, b, kind))


#A row of stepping stones between two islands, a little out of line so each jump has to be aimed: a short cut for whoever dares
func add_stones(a: StringName, b: StringName, count: int, radius: float, sway := 0.9) -> void:
	var from := position_of(a)
	var to := position_of(b)
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var direction := flat.normalized()
	var side := Vector3(-direction.z, 0.0, direction.x)
	var start := from + direction * radius_of(a)
	var end := to - direction * radius_of(b)
	start.y = from.y
	end.y = to.y
	for index in count:
		var share := (index + 1.0) / (count + 1.0)
		var at := start.lerp(end, share) + side * sway * (1.0 if index % 2 == 0 else -1.0)
		stones.append({"position": at, "radius": radius, "zone": (islands[a] as Island).zone if share < 0.5 else (islands[b] as Island).zone})


#A drum standing on an island, to climb on: "offset" from the middle of the island and "height" over its floor
func add_step(island: StringName, offset: Vector3, radius: float, height: float) -> void:
	stones.append({"position": position_of(island) + Vector3(offset.x, height, offset.z), "radius": radius, "zone": (islands[island] as Island).zone})


func position_of(id: StringName) -> Vector3:
	return (islands[id] as Island).position


func radius_of(id: StringName) -> float:
	return (islands[id] as Island).radius


func color_of(id: StringName) -> Color:
	return zone_colors[(islands[id] as Island).zone % zone_colors.size()]


func bridge_between(a: StringName, b: StringName) -> Bridge:
	for bridge in bridges:
		if (bridge.a == a and bridge.b == b) or (bridge.a == b and bridge.b == a):
			return bridge
	return null


#The island whose middle is closest to a point, measured on the ground
func nearest_island(point: Vector3) -> StringName:
	var best: StringName = &""
	var best_distance := INF
	for id: StringName in islands:
		var at := position_of(id)
		var distance := Vector2(point.x - at.x, point.z - at.z).length() - radius_of(id)
		if distance < best_distance:
			best_distance = distance
			best = id
	return best


#Whether a point is over the floor of an island (with "margin" meters to spare from its rim)
func is_over(id: StringName, point: Vector3, margin := 0.0) -> bool:
	var at := position_of(id)
	return Vector2(point.x - at.x, point.z - at.z).length() <= radius_of(id) - margin


#The walkable stretch of a bridge: where it leaves the first island and reaches the second, its direction on the ground, the way across and its width
func frame_of(bridge: Bridge) -> Dictionary:
	var from := position_of(bridge.a)
	var to := position_of(bridge.b)
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var direction := flat.normalized()
	var start := from + direction * radius_of(bridge.a)
	var end := to - direction * radius_of(bridge.b)
	return {"start": start, "end": end, "direction": direction, "side": Vector3(-direction.z, 0.0, direction.x),
		"width": float(WIDTHS[bridge.kind]), "length": Vector2(end.x - start.x, end.z - start.z).length()}


#Seconds to go from the middle of one island to the middle of the next over their bridge, on foot
func travel_seconds(bridge: Bridge) -> float:
	var from := position_of(bridge.a)
	var to := position_of(bridge.b)
	var seconds := from.distance_to(to) / WALK_SPEED
	if bridge.kind == NARROW:
		seconds += NARROW_COST
	return seconds


#The graph of the map: an island is a vertex and a bridge is an edge that costs its seconds of travel; "narrow" false leaves the narrow ones out
func build_graph(narrow := true) -> WeightedGraph:
	var graph := WeightedGraph.new()
	for id: StringName in islands:
		graph.add_vertex(id)
	for bridge in bridges:
		if narrow or bridge.kind != NARROW:
			graph.add_edge(bridge.a, bridge.b, travel_seconds(bridge))
	return graph


#Seconds of the cheapest route between every pair of islands, by Dijkstra from each one: {from: {to: seconds}}
func travel_table(graph: WeightedGraph) -> Dictionary:
	var table: Dictionary = {}
	for from: StringName in islands:
		var row: Dictionary = {}
		for to: StringName in islands:
			var route := graph.shortest_path(from, to)
			row[to] = route.cost if route.found else INF
		table[from] = row
	return table


#Whether what starts at stage "from" is already on at "stage"
static func is_on(entry: Dictionary, stage: int) -> bool:
	return stage >= int(entry.get("from", 0))


#Which way a belt runs at "time": 1 from its first island to the second, -1 the other way, 0 while it is stopped
func belt_flow(stage: int, time: float) -> float:
	if stage < belt_from:
		return 0.0
	return 1.0 if int(time / belt_period) % 2 == 0 else -1.0


#Seconds until the belts turn around
func belt_turn_in(time: float) -> float:
	return belt_period - fposmod(time, belt_period)
