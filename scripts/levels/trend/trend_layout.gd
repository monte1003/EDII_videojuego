class_name TrendLayout
extends ArenaLayout

#"La Plaza": an uneven floating square. A raised core under the giant screen with two lookout towers beside it, an inner ring of
#four islands at different heights and an outer ring of eight that dips into low corners. Ramps join the heights, two narrow
#shortcuts cut across, two stretches of the outer ring are only stepping stones and more stones climb to the towers

const CORE := &"C"
const TOP_HEIGHT := 4.5
#How high over the floor a bubble floats
const BUBBLE_HEIGHT := 1.25
#Every island: where it is, its radius and its quarter of the map (4 is the core and its towers)
const ISLANDS := {
	&"C": [Vector3(0.0, 3.0, 0.0), 6.0, 4],
	&"T1": [Vector3(11.0, 4.5, -11.0), 3.2, 4], &"T2": [Vector3(-12.0, 4.5, 12.0), 3.2, 4],
	&"N1": [Vector3(2.0, 1.5, -15.0), 5.0, 0], &"E1": [Vector3(15.0, 2.2, 3.0), 4.5, 1],
	&"S1": [Vector3(-3.0, 1.0, 15.0), 5.2, 2], &"W1": [Vector3(-15.0, 1.8, -2.0), 4.6, 3],
	&"N2": [Vector3(-4.0, 0.0, -30.0), 6.0, 0], &"NE": [Vector3(20.0, -1.0, -22.0), 6.5, 0],
	&"E2": [Vector3(31.0, 0.6, -2.0), 5.2, 1], &"ES": [Vector3(22.0, -1.2, 21.0), 6.0, 1],
	&"S2": [Vector3(2.0, 0.0, 31.0), 5.8, 2], &"SW": [Vector3(-21.0, -0.8, 23.0), 6.4, 2],
	&"W2": [Vector3(-31.0, 0.4, 3.0), 5.4, 3], &"WN": [Vector3(-22.0, 1.2, -20.0), 5.8, 3],
}

#Where a bubble can appear: {"island": id, "position": Vector3}
var points: Array[Dictionary] = []

var _table: Dictionary = {}


func _init() -> void:
	zone_colors = [Color("86e8c6"), Color("62b7ff"), Color("a584ff"), Color("ff7fb2"), Color("ffd27a")]
	spawn_island = CORE
	for id: StringName in ISLANDS:
		var entry: Array = ISLANDS[id]
		add_island(id, entry[0], entry[1], entry[2])
	#Ramps from the core to the inner ring and from there down to the outer ring; narrow ramps up to the towers
	for side: String in ["N", "E", "S", "W"]:
		add_bridge(CORE, StringName(side + "1"))
		add_bridge(StringName(side + "1"), StringName(side + "2"))
	add_bridge(CORE, &"T1", NARROW)
	add_bridge(CORE, &"T2", NARROW)
	#Two narrow shortcuts across the inner ring
	add_bridge(&"E1", &"S1", NARROW)
	add_bridge(&"W1", &"N1", NARROW)
	#The outer ring: wide bridges with a block and belts; two of its stretches have no bridge, only stones
	add_bridge(&"N2", &"NE")
	add_bridge(&"NE", &"E2", BELT)
	add_bridge(&"E2", &"ES")
	add_bridge(&"S2", &"SW")
	add_bridge(&"SW", &"W2", BELT)
	add_bridge(&"W2", &"WN")
	add_stones(&"ES", &"S2", 2, 1.4, 1.0)
	add_stones(&"WN", &"N2", 2, 1.3, 0.8)
	add_stones(&"E1", &"T1", 2, 1.2, 0.6)
	add_stones(&"W1", &"T2", 3, 1.0, 0.5)
	#A stepped podium under the giant screen and drums to climb in the two biggest corners
	add_step(CORE, Vector3.ZERO, 2.4, 0.7)
	add_step(CORE, Vector3.ZERO, 1.2, 1.4)
	add_step(&"NE", Vector3(-1.8, 0.0, 1.6), 1.6, 0.75)
	add_step(&"SW", Vector3(1.6, 0.0, -1.8), 1.6, 0.75)

	#Stage 1: bars on the outer islands of each side and trampolines in the low corners. Stage 2: the belts run. Stage 3: the blocks
	var turns: Array[float] = [1.5, -1.7, 1.6, -1.45]
	var sides: Array[StringName] = [&"N2", &"E2", &"S2", &"W2"]
	for index in 4:
		var spinner := {"arm": radius_of(sides[index]) - 1.1, "speed": turns[index], "phase": index * 0.9, "from": 1}
		if index % 2 == 1:
			spinner["surge"] = {"rate": 0.9, "depth": 0.45}
		spinners[sides[index]] = spinner
	for corner: StringName in [&"NE", &"ES", &"SW"]:
		var outward := position_of(corner)
		outward.y = 0.0
		pads[corner] = {"offset": outward.normalized() * 3.6, "from": 1}
	belt_from = 2
	belt_period = 8.0
	for edge: Array in [[&"N2", &"NE"], [&"E2", &"ES"], [&"S2", &"SW"], [&"W2", &"WN"]]:
		sweepers.append({"edge": edge, "at": 0.5, "period": 2.6, "phase": sweepers.size() * 1.3, "from": 3})
	_place_points()
	_table = travel_table(build_graph())


#Seconds on foot from one bubble point to another: across the island when they share it, and by the cheapest route of the graph otherwise
func seconds_between(from: int, to: int) -> float:
	var a: Dictionary = points[from]
	var b: Dictionary = points[to]
	if a["island"] == b["island"]:
		return (a["position"] as Vector3).distance_to(b["position"]) / WALK_SPEED
	return _table[a["island"]][b["island"]]


#Seconds from wherever a player stands to a bubble point
func seconds_from(place: Vector3, to: int) -> float:
	var island := nearest_island(place)
	var b: Dictionary = points[to]
	if island == b["island"]:
		return Vector2(place.x - b["position"].x, place.z - b["position"].z).length() / WALK_SPEED
	return _table[island][b["island"]]


#The par of a trend: the seconds of the fastest way to fetch its kinds in order from "place", trying every choice of bubble.
#"by_kind" is {kind: [point indices that hold it]}; a bubble can be fetched only once
func par_seconds(place: Vector3, chain: Array[int], by_kind: Dictionary) -> float:
	return _best_from(place, -1, chain, 0, by_kind, [])


func _best_from(place: Vector3, at: int, chain: Array[int], step: int, by_kind: Dictionary, used: Array[int]) -> float:
	if step >= chain.size():
		return 0.0
	var best := INF
	for point: int in by_kind.get(chain[step], []):
		if used.has(point):
			continue
		var leg := seconds_from(place, point) if at < 0 else seconds_between(at, point)
		used.append(point)
		best = minf(best, leg + _best_from(place, point, chain, step + 1, by_kind, used))
		used.pop_back()
	return best


#Four points on the core, one on top of each tower and two on every other island, to the sides of the way to the middle
func _place_points() -> void:
	for id: StringName in islands:
		var centre := position_of(id)
		var reach := radius_of(id) * 0.55
		if id == CORE:
			for index in 4:
				var angle := PI / 4.0 + PI / 2.0 * index
				_add_point(id, centre + Vector3(cos(angle), 0.0, sin(angle)) * reach * 1.25)
			#One more on top of the podium
			_add_point(id, centre + Vector3(0.0, 1.4, 0.0))
		elif radius_of(id) < 4.0:
			_add_point(id, centre)
		else:
			var inward := Vector3(-centre.x, 0.0, -centre.z).normalized()
			var across := Vector3(-inward.z, 0.0, inward.x)
			for way: float in [-1.0, 1.0]:
				_add_point(id, centre + across * reach * way)


func _add_point(island: StringName, at: Vector3) -> void:
	points.append({"island": island, "position": at})
