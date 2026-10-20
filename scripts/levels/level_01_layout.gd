class_name Level01Layout
extends RefCounted

#Single source of truth of level 1: the graph and the platforms are both built from these tables

#Meters of centre-to-centre distance that count as one unit of cost
const UNIT := 7.0

#Platform centres on the XZ plane (north is -Z, the start looks north)
const POSITIONS := {
	&"S": Vector3(0.0, 0.0, 0.0),
	&"A": Vector3(-21.0, 0.0, -7.0),
	&"B": Vector3(0.0, 0.0, -14.0),
	&"C": Vector3(21.0, 0.0, -7.0),
	&"D": Vector3(-21.0, 0.0, -28.0),
	&"E": Vector3(0.0, 0.0, -28.0),
	&"F": Vector3(21.0, 0.0, -28.0),
	&"G": Vector3(-21.0, 0.0, -49.0),
	&"H": Vector3(0.0, 0.0, -42.0),
	&"I": Vector3(21.0, 0.0, -49.0),
	&"J": Vector3(-9.2, 0.0, -56.0),
	&"M": Vector3(5.6, 0.0, -58.8),
}

const DEFAULT_RADIUS := 5.5
const RADII := {
	&"S": 6.5,
	&"M": 6.5,
}

#Cost of crossing a bridge, about the centre distance over UNIT; B to J costs 6, or 11 with E-H blocked
const EDGES := [
	[&"S", &"A", 3.0],
	[&"S", &"B", 2.0],
	[&"S", &"C", 3.0],
	[&"A", &"B", 3.0],
	[&"B", &"C", 3.0],
	[&"A", &"D", 3.0],
	[&"B", &"E", 2.0],
	[&"C", &"F", 3.0],
	[&"D", &"E", 3.0],
	[&"E", &"F", 3.0],
	[&"D", &"G", 3.0],
	[&"E", &"H", 2.0],
	[&"F", &"I", 3.0],
	[&"G", &"H", 3.0],
	[&"H", &"I", 3.0],
	[&"G", &"J", 3.0],
	[&"H", &"J", 2.0],
	[&"J", &"M", 2.0],
	[&"I", &"M", 3.0],
]

const START := &"S"
const GOAL := &"M"
const BLOCK_EDGE: Array[StringName] = [&"E", &"H"]
#Vertices where the bots may start a round (the spawn varies between rounds)
const BOT_SPAWNS: Array[StringName] = [&"A", &"C", &"D", &"F"]
#The goal is closed to the bots: every route they plan excludes it
const BOT_FORBIDDEN: Array[StringName] = [&"M"]


static func build_graph() -> WeightedGraph:
	var graph := WeightedGraph.new()
	for id: StringName in POSITIONS:
		graph.add_vertex(id)
	for edge in EDGES:
		graph.add_edge(edge[0], edge[1], edge[2])
	return graph


static func radius_of(id: StringName) -> float:
	return RADII.get(id, DEFAULT_RADIUS)
