class_name SelfieLayout
extends ArenaLayout

#"El Estudio": a film lot built on solid ground inside an eight-sided fence. Eight sets, one per photo, at three heights: three on
#the ground at the south, two side stages and a low dance floor in the middle, and two rooftops at the north, the highest one
#reached by a long ramp, by a walkway from the other roof or by a cannon. Whoever falls from a set lands on the ground of the lot

const HUB := &"M"
#How high over the floor the drone flies
const DRONE_HEIGHT := 6.5
const LOW := 0.8
const MID := 1.6
const UPPER := 3.2
const TOP := 4.8
#The set of each photo: its name, its middle, how much flat floor it has to each side of it (x and z), its height and its zone
const SETS: Array[Array] = [
	[&"A", Vector2(-16.0, -18.5), Vector2(6.0, 5.0), TOP, 0], [&"B", Vector2(9.0, -19.0), Vector2(6.0, 5.0), UPPER, 0],
	[&"C", Vector2(24.0, -3.0), Vector2(6.0, 6.0), MID, 1], [&"D", Vector2(-24.0, 1.0), Vector2(6.0, 6.0), MID, 1],
	[&"H", Vector2(1.0, -4.0), Vector2(5.75, 5.75), LOW, 3],
	[&"E", Vector2(22.0, 16.0), Vector2(5.6, 5.6), GROUND, 2], [&"F", Vector2(-21.0, 17.0), Vector2(5.6, 5.6), GROUND, 2],
	[&"G", Vector2(1.0, 20.0), Vector2(5.4, 5.4), GROUND, 2],
]
#Room a frame keeps to the edge of its set
const FRAME_MARGIN := 0.35

#The place of each photo
var spots: Array[StringName] = []
#Where the power-ups stand
var pedestals: Array[Vector3] = []

var _graph: WeightedGraph
#Set id -> flat floor to each side of its middle
var _room: Dictionary = {}


func _init() -> void:
	zone_colors = [Color("ff7fb2"), Color("62b7ff"), Color("86e8c6"), Color("ffd27a")]
	ground_color = Color("f1e2ff")
	belt_period = 7.0
	spawn_place = HUB
	outline = PackedVector2Array([Vector2(-32, -18), Vector2(-24, -26), Vector2(24, -26), Vector2(32, -18),
		Vector2(32, 18), Vector2(24, 26), Vector2(-24, 26), Vector2(-32, 18)])
	_build_terrain()
	_build_places()
	_build_hazards()
	for spot: Vector2 in [Vector2(-11, 13), Vector2(12, 11), Vector2(-3.5, -17), Vector2(14, -9), Vector2(-13, -7)]:
		pedestals.append(Vector3(spot.x, height_at(spot.x, spot.y), spot.y))
	_graph = build_graph()


#The islands the drone flies over to go from one photo to the next, by the cheapest route of the graph
func flight_path(from: StringName, to: StringName) -> Array[Vector3]:
	var path: Array[Vector3] = []
	var route := _graph.shortest_path(from, to)
	var stops: Array[StringName] = route.path if route.found else ([from, to] as Array[StringName])
	for id in stops:
		path.append(position_of(id) + Vector3(0.0, DRONE_HEIGHT, 0.0))
	return path


#The flat floor of a set to each side of its middle, in meters (x and z)
func room_of(spot: StringName) -> Vector2:
	return _room[spot]


#How far from the middle of its set the middle of a square frame of "size" meters can go and still fit whole on its floor
func frame_room(spot: StringName, size: float) -> float:
	var room: Vector2 = _room[spot]
	return maxf(minf(room.x, room.y) - FRAME_MARGIN - size / 2.0, 0.0)


#The blocks of the raised sets, the ramps up to them and the two walkways between the roofs
func _build_terrain() -> void:
	for entry in SETS:
		var half: Vector2 = entry[2]
		if float(entry[3]) > GROUND:
			add_block(entry[1], half * 2.0, entry[3], entry[4])
	#Ramps from the ground to the two side stages and to the dance floor
	add_ramp(Vector3(-12.5, GROUND, 1.0), Vector3(-18.0, MID, 1.0), 4.5, 1)
	add_ramp(Vector3(12.5, GROUND, -3.0), Vector3(18.0, MID, -3.0), 4.5, 1)
	add_ramp(Vector3(1.0, GROUND, 4.75), Vector3(1.0, LOW, 1.75), 4.0, 3)
	#The long ramp along the south face of the highest roof, with a landing at its top
	add_ramp(Vector3(-5.0, GROUND, -12.0), Vector3(-20.0, TOP, -12.0), 3.0, 0, true)
	add_block(Vector2(-21.25, -12.0), Vector2(2.5, 3.0), TOP, 0)
	#Two walkways with room to walk under them. One climbs from the east stage to a deck beside the low roof; the other one
	#goes from that roof up to the high one. Each meets the edges it joins squarely, so its top is flush with them
	add_ramp(Vector3(19.5, MID, -9.0), Vector3(19.5, UPPER, -14.0), 3.0, 1, false, false)
	add_block(Vector2(18.0, -16.0), Vector2(6.0, 4.0), UPPER, 0, 0.0, UPPER - 0.5)
	add_ramp(Vector3(3.0, UPPER, -19.0), Vector3(-10.0, TOP, -18.5), 3.2, 0, false, false)


func _build_places() -> void:
	add_place(HUB, 0.0, 8.5, 5.0, 3)
	for entry in SETS:
		var centre: Vector2 = entry[1]
		var half: Vector2 = entry[2]
		add_place(entry[0], centre.x, centre.y, minf(half.x, half.y) - 0.2, entry[4])
		spots.append(entry[0])
		_room[entry[0]] = half
	#Crossings on the ground, the ends of the ramps and of the walkways, and the two pads
	add_place(&"we", 15.0, 7.0, 2.5, 2)
	add_place(&"ww", -14.0, 9.0, 2.5, 2)
	add_place(&"wd", -11.0, 1.0, 2.0, 1)
	add_place(&"wc", 11.0, -3.0, 2.0, 1)
	add_place(&"wa", -3.2, -12.0, 1.4, 0)
	add_place(&"wt", -21.25, -12.0, 1.1, 0)
	add_place(&"wn", -3.5, -17.0, 2.0, 0)
	add_place(&"c1", 19.5, -8.0, 0.9, 1)
	add_place(&"b1", 19.5, -15.5, 1.0, 0)
	add_place(&"pa", -9.5, -5.5, 1.0, 3)
	add_place(&"pb", -1.0, -15.5, 1.0, 3)
	for pair: Array in [[HUB, &"G"], [HUB, &"we"], [HUB, &"ww"], [HUB, &"H"], [HUB, &"wd"], [&"we", &"E"], [&"ww", &"F"], [&"G", &"E"], [&"G", &"F"],
			[&"ww", &"wd"], [&"wd", &"D"], [&"we", &"wc"], [&"wc", &"C"], [&"wd", &"wa"], [&"wa", &"wt"], [&"wt", &"A"], [&"wa", &"wn"],
			[&"C", &"c1"], [&"c1", &"b1"], [&"b1", &"B"], [&"B", &"A"], [&"wd", &"pa"], [&"wa", &"pb"]]:
		link(pair[0], pair[1])
	link(&"pa", &"A", LAUNCH, 0.0, 2.1)
	link(&"pb", &"B", LAUNCH, 0.0, 1.7)
	for pair: Array in [[&"A", &"wa"], [&"B", &"wc"], [&"H", &"wa"], [&"C", &"wc"], [&"D", &"wd"]]:
		link(pair[0], pair[1], DROP)


#What wakes up photo after photo: the two pads work from the start; then the bar of the dance floor, blocks on the walkways,
#the belt that turns the long ramp against whoever climbs it, and blocks on the ramps of the side stages
func _build_hazards() -> void:
	pads.append({"at": position_of(&"pa"), "to": position_of(&"A"), "time": 1.9, "from": 0})
	pads.append({"at": position_of(&"pb"), "to": position_of(&"B"), "time": 1.7, "from": 0})
	spinners.append({"at": position_of(&"H"), "arm": 5.0, "speed": 1.5, "phase": 0.4, "from": 2})
	_sweep(Vector3(19.5, 2.4, -11.5), Vector3(19.5, MID, -9.0), Vector3(19.5, UPPER, -14.0), 3.0, 2.6, 0.0, 3)
	_sweep(Vector3(-3.5, 4.0, -18.75), Vector3(3.0, UPPER, -19.0), Vector3(-10.0, TOP, -18.5), 3.2, 2.6, 1.6, 3)
	belts.append({"a": Vector3(-19.6, 4.67, -12.0), "b": Vector3(-5.4, 0.13, -12.0), "width": 2.4, "from": 4, "turns": true})
	_sweep(Vector3(-15.25, 0.8, 1.0), Vector3(-12.5, GROUND, 1.0), Vector3(-18.0, MID, 1.0), 4.5, 2.2, 0.8, 5)
	_sweep(Vector3(15.25, 0.8, -3.0), Vector3(12.5, GROUND, -3.0), Vector3(18.0, MID, -3.0), 4.5, 2.2, 2.4, 5)


#A block that goes from side to side of a way: "middle" is where it crosses it, "from" and "to" the ends of the way and "width" its width
func _sweep(middle: Vector3, from: Vector3, to: Vector3, width: float, period: float, phase: float, stage: int) -> void:
	var way := Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
	var side := Vector3(-way.z, 0.0, way.x) * maxf(width / 2.0 - ArenaHazards.BLOCK_ALONG / 2.0 - 0.1, 0.0)
	sweepers.append({"a": middle - side, "b": middle + side, "period": period, "phase": phase, "from": stage})
