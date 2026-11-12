class_name SelfieLayout
extends ArenaLayout

#"El Estudio": a big photo studio laid out like a crooked grid of sets, each at its own height, around a sunken pit in the middle.
#Catwalks and rooftops high up, decks down low. Ramps and bridges go around the long way; four rows of stepping stones climb out
#of the pit straight to the corner sets, for whoever dares to jump

const HUB := &"M"
const TOP_HEIGHT := 4.5
#How high over the floor the drone flies
const DRONE_HEIGHT := 6.5
#The set of each photo: its name, where it is, its radius and its row of the grid
const SETS: Array[Array] = [
	[&"A", Vector3(-22.0, 3.5, -20.0), 5.2, 0], [&"B", Vector3(1.0, 4.5, -23.0), 5.2, 0], [&"C", Vector3(22.0, 1.0, -19.0), 5.5, 0],
	[&"D", Vector3(-24.0, 0.0, 1.0), 5.8, 1], [&"E", Vector3(24.0, 3.0, 3.0), 5.2, 1],
	[&"F", Vector3(-20.0, 2.5, 22.0), 5.2, 2], [&"G", Vector3(2.0, 0.5, 24.0), 5.5, 2], [&"I", Vector3(21.0, -1.0, 21.0), 5.8, 2],
]

#The island of each photo
var spots: Array[StringName] = []
#Where the power-ups stand
var pedestals: Array[Vector3] = []

var _graph: WeightedGraph


func _init() -> void:
	zone_colors = [Color("ff7fb2"), Color("62b7ff"), Color("86e8c6"), Color("ffd27a")]
	spawn_island = HUB
	add_island(HUB, Vector3(0.0, -1.5, 0.0), 6.5, 3)
	for entry in SETS:
		add_island(entry[0], entry[1], entry[2], entry[3])
		spots.append(entry[0])
	#The edges of the grid, each of its own kind, and four ramps out of the pit
	add_bridge(&"A", &"B")
	add_bridge(&"B", &"C", NARROW)
	add_bridge(&"C", &"E", BELT)
	add_bridge(&"E", &"I")
	add_bridge(&"G", &"I", NARROW)
	add_bridge(&"F", &"G")
	add_bridge(&"D", &"F", BELT)
	add_bridge(&"A", &"D")
	add_bridge(HUB, &"B")
	add_bridge(HUB, &"E")
	add_bridge(HUB, &"D", NARROW)
	add_bridge(HUB, &"G")
	#The short cuts: stepping stones from the pit up to the four corner sets
	add_stones(HUB, &"A", 6, 1.2, 0.7)
	add_stones(HUB, &"C", 5, 1.3, 0.8)
	add_stones(HUB, &"I", 4, 1.4, 0.9)
	add_stones(HUB, &"F", 6, 1.2, 0.7)
	#A small podium in the pit to climb on
	add_step(HUB, Vector3(-2.6, 0.0, -2.2), 1.5, 0.75)
	add_step(HUB, Vector3(2.8, 0.0, 2.0), 1.3, 0.75)

	#What wakes up photo after photo: trampolines in the low sets, the bar of the pit, blocks on the wide bridges and the belts
	for id: StringName in [&"I", &"D"]:
		var outward := position_of(id)
		outward.y = 0.0
		pads[id] = {"offset": outward.normalized() * 3.9, "from": 1}
	spinners[HUB] = {"arm": 5.4, "speed": 1.5, "phase": 0.4, "from": 2}
	sweepers.append({"edge": [&"F", &"G"], "at": 0.5, "period": 2.6, "phase": 0.0, "from": 3})
	sweepers.append({"edge": [&"A", &"D"], "at": 0.5, "period": 2.6, "phase": 1.6, "from": 3})
	sweepers.append({"edge": [&"A", &"B"], "at": 0.5, "period": 2.2, "phase": 0.8, "from": 5})
	sweepers.append({"edge": [HUB, &"E"], "at": 0.5, "period": 2.2, "phase": 2.4, "from": 5})
	belt_from = 4
	belt_period = 7.0

	#A power-up on the inner side of four sets and one in the pit
	for id: StringName in [&"B", &"C", &"F", &"I"]:
		var centre := position_of(id)
		var inward := Vector3(-centre.x, 0.0, -centre.z).normalized()
		pedestals.append(centre + inward * 4.1)
	pedestals.append(position_of(HUB) + Vector3(0.0, 0.0, 4.4))
	_graph = build_graph()


#The islands the drone flies over to go from one photo to the next, by the cheapest route of the graph
func flight_path(from: StringName, to: StringName) -> Array[Vector3]:
	var path: Array[Vector3] = []
	var route := _graph.shortest_path(from, to)
	var stops: Array[StringName] = route.path if route.found else ([from, to] as Array[StringName])
	for id in stops:
		path.append(position_of(id) + Vector3(0.0, DRONE_HEIGHT, 0.0))
	return path


#How far from the middle of its island the middle of a frame of "size" meters can go and still fit whole on the floor
func frame_room(spot: StringName, size: float) -> float:
	return maxf(radius_of(spot) - 0.35 - size * 0.7072, 0.0)
