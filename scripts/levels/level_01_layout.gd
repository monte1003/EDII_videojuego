class_name Level01Layout
extends RefCounted

#Single source of truth of level 1, the feed race: the graph, the platforms, the belts, the fragile bridges and the spinners are all built from these tables

#Meters of centre-to-centre distance that count as one unit of cost
const UNIT := 9.5

#Platform centres on the XZ plane (north is -Z, the start looks north)
const POSITIONS := {
	&"S": Vector3(0.0, 0.0, 0.0),
	&"A": Vector3(-32.5, 0.0, -12.0),
	&"B": Vector3(0.0, 0.0, -21.5),
	&"C": Vector3(32.5, 0.0, -12.0),
	&"D": Vector3(-43.0, 0.0, -43.0),
	&"E": Vector3(-15.0, 0.0, -39.0),
	&"F": Vector3(15.0, 0.0, -39.0),
	&"G": Vector3(43.0, 0.0, -43.0),
	&"H": Vector3(-27.0, 0.0, -70.0),
	&"I": Vector3(0.0, 0.0, -65.0),
	&"J": Vector3(27.0, 0.0, -70.0),
	&"K": Vector3(-12.0, 0.0, -94.5),
	&"L": Vector3(12.0, 0.0, -94.5),
	&"M": Vector3(0.0, 0.0, -119.0),
}

const DEFAULT_RADIUS := 5.5
const RADII := {
	&"S": 7.0,
	&"M": 7.0,
	&"I": 6.5,
	&"E": 6.0,
	&"G": 6.0,
	&"L": 6.0,
}

#Kinds of bridge: a plain one, a conveyor belt that flows from the first vertex to the second, and a fragile one
#that the feed takes down for a while
const WALK := &"walk"
const BELT := &"belt"
const FRAGILE := &"fragile"

#[a, b, cost a to b, cost b to a, kind]; a belt costs little with the flow and a lot against it, and the
#costs of the islands with a spinner include its risk. Seven routes from S to M stay within 2 of the best one
const EDGES := [
	[&"S", &"A", 3.0, 3.0, WALK],
	[&"S", &"B", 2.0, 2.0, WALK],
	[&"S", &"C", 3.0, 3.0, WALK],
	[&"A", &"B", 3.0, 3.0, WALK],
	[&"B", &"C", 3.0, 3.0, WALK],
	[&"A", &"D", 3.0, 3.0, WALK],
	[&"B", &"E", 3.5, 3.5, WALK],
	[&"B", &"F", 3.0, 3.0, WALK],
	[&"C", &"G", 2.5, 5.5, BELT],
	[&"D", &"E", 3.5, 3.5, WALK],
	[&"E", &"F", 3.5, 3.5, WALK],
	[&"F", &"G", 3.5, 3.5, WALK],
	[&"D", &"H", 3.0, 3.0, FRAGILE],
	[&"E", &"H", 3.5, 3.5, WALK],
	[&"I", &"E", 2.5, 5.5, BELT],
	[&"F", &"I", 3.0, 3.0, WALK],
	[&"F", &"J", 3.0, 3.0, WALK],
	[&"G", &"J", 3.0, 3.0, FRAGILE],
	[&"H", &"I", 3.0, 3.0, FRAGILE],
	[&"I", &"J", 3.0, 3.0, WALK],
	[&"H", &"K", 3.0, 3.0, WALK],
	[&"I", &"K", 3.0, 3.0, FRAGILE],
	[&"I", &"L", 3.5, 3.5, WALK],
	[&"J", &"L", 2.5, 5.5, BELT],
	[&"K", &"L", 2.5, 2.5, WALK],
	[&"K", &"M", 3.0, 3.0, WALK],
	[&"L", &"M", 3.5, 3.5, WALK],
]

const START := &"S"
const GOAL := &"M"
#The vertex that saves the progress of whoever passes through it
const CHECKPOINT := &"I"
#Where each ability is used
const STATIONS := {
	&"block": &"F",
	&"silence": &"H",
	&"refuge": &"D",
}
#The bridge that Bloquear closes for the bots
const BLOCK_EDGE: Array[StringName] = [&"F", &"J"]
#Vertices where the bots may start a round (the spawn varies between rounds)
const BOT_SPAWNS: Array[StringName] = [&"A", &"C", &"E", &"G", &"H", &"J"]
#The goal is closed to the bots: every route they plan excludes it
const BOT_FORBIDDEN: Array[StringName] = [&"M"]

#Islands with a bar that sweeps the whole island: "arm" is the half length, "speed" the turn in radians per second
#(the sign is the direction) and "phase" the angle at the start
const SPINNERS := {
	&"E": {"arm": 4.4, "speed": 1.3, "phase": 0.0},
	&"G": {"arm": 4.4, "speed": -1.5, "phase": 1.2},
	&"L": {"arm": 4.2, "speed": 1.8, "phase": 2.4},
}


static func build_graph() -> WeightedGraph:
	var graph := WeightedGraph.new()
	for id: StringName in POSITIONS:
		graph.add_vertex(id)
	for edge in EDGES:
		graph.add_edge(edge[0], edge[1], edge[2], false)
		graph.add_edge(edge[1], edge[0], edge[3], false)
	return graph


static func radius_of(id: StringName) -> float:
	return RADII.get(id, DEFAULT_RADIUS)


static func kind_of(a: StringName, b: StringName) -> StringName:
	for edge in EDGES:
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a):
			return edge[4]
	return &""


#The bridges the feed may take down
static func fragile_edges() -> Array[Array]:
	var found: Array[Array] = []
	for edge in EDGES:
		if edge[4] == FRAGILE:
			found.append([edge[0], edge[1]])
	return found


#Unit vector of the flow of the belt between a and b as seen on the ground, or zero when it is not a belt
static func belt_flow(a: StringName, b: StringName) -> Vector3:
	for edge in EDGES:
		if edge[4] != BELT:
			continue
		if edge[0] == a and edge[1] == b:
			return _flat_direction(edge[0], edge[1])
		if edge[0] == b and edge[1] == a:
			return _flat_direction(edge[0], edge[1])
	return Vector3.ZERO


static func _flat_direction(from: StringName, to: StringName) -> Vector3:
	var direction: Vector3 = POSITIONS[to] - POSITIONS[from]
	direction.y = 0.0
	return direction.normalized()
