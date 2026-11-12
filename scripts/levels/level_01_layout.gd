class_name Level01Layout
extends RefCounted

#Single source of truth of level 1, the feed race: the graph, the platforms and their heights, the belts, the slides, the cannons, the fragile and
#narrow bridges, the spinners, the sweeping blocks, the rolling balls and the trampolines are all built from these tables. Everything that moves is a
#function of the seconds of the round, so it can be drawn, hit and planned for from the time alone. The course has two parts: the run up (N to S, climbing)
#and the island field (S to M), which ends at the goal. Each part has three ways: the left and the right ones are longer or higher at the start but
#pay it back later with a slide or a cannon, and the middle one is the straight line with narrow bridges and bars; they take about the same time

#Meters of centre-to-centre distance that count as one unit of cost
const UNIT := 9.5

#Platform centres: x and z on the ground (north is -Z, the start looks north) and y, how high the top of the island is
const POSITIONS := {
	&"N": Vector3(0.0, 0.0, 158.0),
	&"O": Vector3(-21.0, 2.0, 137.0),
	&"P": Vector3(26.0, 1.0, 142.0),
	&"Q": Vector3(0.0, 3.0, 116.0),
	&"R": Vector3(-36.0, 6.0, 117.0),
	&"T": Vector3(48.0, 2.0, 120.0),
	&"U": Vector3(-30.0, 12.0, 86.0),
	&"V": Vector3(24.0, 8.0, 90.0),
	&"W": Vector3(0.0, 8.0, 72.0),
	&"X": Vector3(-30.0, 6.0, 48.0),
	&"Y": Vector3(35.0, 12.0, 60.0),
	&"Z": Vector3(0.0, 11.0, 38.0),
	&"S": Vector3(0.0, 12.0, 0.0),
	&"A": Vector3(-34.0, 14.0, -12.0),
	&"B": Vector3(0.0, 12.0, -21.5),
	&"C": Vector3(34.0, 14.0, -12.0),
	&"D": Vector3(-48.0, 15.0, -52.0),
	&"E": Vector3(-15.0, 14.0, -39.0),
	&"F": Vector3(15.0, 12.0, -39.0),
	&"G": Vector3(46.0, 23.0, -42.0),
	&"H": Vector3(-27.0, 16.0, -70.0),
	&"I": Vector3(0.0, 14.0, -65.0),
	&"J": Vector3(36.0, 14.0, -80.0),
	&"K": Vector3(-12.0, 18.0, -94.5),
	&"L": Vector3(12.0, 16.0, -94.5),
	&"M": Vector3(0.0, 20.0, -119.0),
}

const DEFAULT_RADIUS := 5.5
const RADII := {
	&"N": 7.0,
	&"S": 7.0,
	&"M": 7.0,
	&"Q": 6.5,
	&"W": 6.5,
	&"Z": 6.0,
	&"I": 6.5,
	&"E": 6.0,
	&"G": 6.0,
	&"L": 6.0,
	&"A": 7.2,
	&"C": 7.2,
	&"X": 6.3,
	&"Y": 6.3,
	&"P": 6.0,
	&"U": 6.2,
	&"J": 7.0,
}

#Kinds of bridge: a plain one, a conveyor belt that flows from the first vertex to the second, a slide that goes downhill from the first vertex
#to the second and never the other way, a fragile one that the feed takes down for a while, and a narrow one that is a shortcut: shorter and
#cheaper, but with little room to be pushed
const WALK := &"walk"
const BELT := &"belt"
const SLIDE := &"slide"
const FRAGILE := &"fragile"
const NARROW := &"narrow"
const WIDE_WIDTH := 4.2
const NARROW_WIDTH := 2.0
#The cost back along a slide: there is none, it is a one-way arc of the graph
const ONE_WAY := -1.0
#How fast a slide carries whoever is on it (m/s), and how high its rails are
const SLIDE_SPEED := 10.5
const SLIDE_RAIL := 1.2

#[a, b, cost a to b, cost b to a, kind]; a belt costs little with the flow and a lot against it, a slide only goes one way, and the
#costs of the islands with a spinner and of the bridges with a sweeping block include their risk
const EDGES := [
	[&"N", &"O", 3.0, 3.0, WALK],
	[&"N", &"P", 3.0, 3.0, WALK],
	[&"N", &"Q", 4.5, 4.5, NARROW],
	[&"O", &"Q", 3.5, 3.5, WALK],
	[&"P", &"Q", 4.0, 4.0, WALK],
	[&"O", &"R", 3.0, 3.0, WALK],
	[&"P", &"T", 4.0, 4.0, WALK],
	[&"P", &"V", 5.5, 5.5, WALK],
	[&"R", &"U", 2.5, 5.5, BELT],
	[&"U", &"X", 2.5, ONE_WAY, SLIDE],
	[&"Q", &"W", 4.5, 4.5, NARROW],
	[&"U", &"W", 4.0, 4.0, WALK],
	[&"V", &"W", 4.0, 4.0, WALK],
	[&"V", &"Y", 4.0, 4.0, FRAGILE],
	[&"W", &"X", 4.5, 4.5, WALK],
	[&"W", &"Y", 4.0, 4.0, WALK],
	[&"W", &"Z", 4.0, 4.0, WALK],
	[&"X", &"Z", 3.5, 3.5, FRAGILE],
	[&"Y", &"Z", 4.5, 4.5, FRAGILE],
	[&"Z", &"S", 4.5, 4.5, WALK],
	[&"S", &"A", 4.0, 4.0, WALK],
	[&"S", &"B", 2.5, 2.5, WALK],
	[&"S", &"C", 4.0, 4.0, WALK],
	[&"A", &"B", 4.0, 4.0, WALK],
	[&"B", &"C", 4.0, 4.0, WALK],
	[&"A", &"D", 4.5, 4.5, WALK],
	[&"B", &"E", 2.5, 2.5, WALK],
	[&"B", &"F", 2.5, 2.5, WALK],
	[&"D", &"E", 4.0, 4.0, WALK],
	[&"E", &"H", 4.0, 4.0, WALK],
	[&"I", &"E", 2.5, 5.5, BELT],
	[&"F", &"I", 5.0, 5.0, WALK],
	[&"F", &"J", 5.0, 5.0, WALK],
	[&"G", &"J", 2.5, ONE_WAY, SLIDE],
	[&"H", &"I", 3.0, 3.0, FRAGILE],
	[&"I", &"J", 4.5, 4.5, WALK],
	[&"H", &"K", 3.0, 3.0, WALK],
	[&"I", &"K", 3.5, 3.5, FRAGILE],
	[&"I", &"L", 3.5, 3.5, WALK],
	[&"J", &"L", 3.0, 3.0, WALK],
	[&"K", &"L", 2.5, 2.5, WALK],
	[&"K", &"M", 3.0, 3.0, WALK],
	[&"L", &"M", 3.0, 3.0, WALK],
	[&"B", &"I", 4.5, 4.5, NARROW],
	[&"C", &"F", 3.0, 3.0, NARROW],
	[&"A", &"E", 3.0, 3.0, NARROW],
]

#Cannons: a pad on the island "from" throws whoever steps on it along an arc that lands in the middle of the island "to" "time" seconds later;
#"cost" is what the flight is worth in the graph. There is no bridge under it and nobody can fly back
const LAUNCHES := [
	{"from": &"T", "to": &"Y", "time": 3.3, "cost": 2.0},
	{"from": &"D", "to": &"K", "time": 3.4, "cost": 2.0},
	{"from": &"C", "to": &"G", "time": 2.2, "cost": 1.5},
]
#The pad stands this far inside the rim of its island, on the side of the island it throws toward
const LAUNCH_INSET := 1.8

const START := &"N"
const GOAL := &"M"
#The vertices that save the progress of whoever passes through them
const CHECKPOINTS: Array[StringName] = [&"W", &"I"]
#Where each ability is used
const STATIONS := {
	&"block": &"F",
	&"silence": &"H",
	&"refuge": &"D",
}
#The bridge that Bloquear closes for the bots
const BLOCK_EDGE: Array[StringName] = [&"F", &"J"]
#Vertices where the bots may start a round (the spawn varies between rounds)
const BOT_SPAWNS: Array[StringName] = [&"A", &"C", &"E", &"H", &"J", &"R", &"T", &"X", &"Y"]
#The goal is closed to the bots: every route they plan excludes it
const BOT_FORBIDDEN: Array[StringName] = [&"M"]

#Islands with a bar that sweeps the whole island: "arm" is the half length, "speed" the turn in radians per second
#(the sign is the direction) and "phase" the angle at the start. A bar with a "surge" speeds up and slows down by "depth" (a share of its
#speed) as the sine of "rate" radians per second, and it never stops or turns back
const SPINNERS := {
	&"Q": {"arm": 5.0, "speed": 1.7, "phase": 0.6},
	&"X": {"arm": 4.2, "speed": -2.0, "phase": 2.0, "surge": {"depth": 0.5, "rate": 1.1}},
	&"Z": {"arm": 4.6, "speed": 2.1, "phase": 4.0},
	&"E": {"arm": 4.4, "speed": 1.9, "phase": 0.0, "surge": {"depth": 0.45, "rate": 0.9}},
	&"L": {"arm": 4.2, "speed": 2.5, "phase": 2.4, "surge": {"depth": 0.5, "rate": 1.3}},
}

#Belts that turn around: each flows from its first island to its second until "phase" seconds, then the other way, and turns again every
#"period" seconds. Its arrows blink TURN_WARNING seconds before each turn. The belt that climbs to the slide of the run up never turns
const TURNS := [
	{"edge": [&"I", &"E"], "period": 21.0, "phase": 10.0},
]
const TURN_WARNING := 1.5

#Candy balls that never stop rolling across an island, back and forth along a diameter in the direction "angle" (radians from +X toward +Z):
#a full trip there and back takes "period" seconds and "phase" says where in it the ball is at the start. The ball is small enough to jump over
const BALLS := [
	{"island": &"O", "angle": 0.6, "period": 5.0, "phase": 0.0},
	{"island": &"R", "angle": 2.2, "period": 5.4, "phase": 1.7},
	{"island": &"V", "angle": 1.0, "period": 4.8, "phase": 3.1},
	{"island": &"B", "angle": 0.0, "period": 5.2, "phase": 0.9},
	{"island": &"S", "angle": 1.2, "period": 5.8, "phase": 2.4},
]
const BALL_RADIUS := 0.5

#Islands with a trampoline on the side where no bridge comes in: it throws whoever steps on it up into the air and a little outward
const PADS: Array[StringName] = [&"P", &"A"]
const PAD_DISTANCE := 2.9

#Bridges with a block that sweeps across them: it sits "at" that share of the bridge and goes from side to side in "period" seconds
const PUSHERS := [
	{"edge": [&"U", &"W"], "at": 0.5, "period": 3.4, "phase": 0.0},
	{"edge": [&"V", &"W"], "at": 0.5, "period": 3.0, "phase": PI},
	{"edge": [&"F", &"I"], "at": 0.5, "period": 3.6, "phase": 1.0},
	{"edge": [&"E", &"H"], "at": 0.5, "period": 2.8, "phase": 2.0},
	{"edge": [&"P", &"T"], "at": 0.5, "period": 3.2, "phase": 0.5},
	{"edge": [&"A", &"D"], "at": 0.5, "period": 3.0, "phase": 1.6},
]


#"shortcuts" false leaves out the narrow bridges: the course as it was before them, for the checks that measure plain routes. "launches" false
#leaves out the cannons, which is the course the bots walk: they cannot be thrown
static func build_graph(shortcuts := true, launches := true) -> WeightedGraph:
	var graph := WeightedGraph.new()
	for id: StringName in POSITIONS:
		graph.add_vertex(id)
	for edge in EDGES:
		if edge[4] == NARROW and not shortcuts:
			continue
		graph.add_edge(edge[0], edge[1], edge[2], false)
		if edge[3] != ONE_WAY:
			graph.add_edge(edge[1], edge[0], edge[3], false)
	if launches:
		for launch: Dictionary in LAUNCHES:
			graph.add_edge(launch["from"], launch["to"], launch["cost"], false)
	return graph


static func radius_of(id: StringName) -> float:
	return RADII.get(id, DEFAULT_RADIUS)


static func kind_of(a: StringName, b: StringName) -> StringName:
	for edge in EDGES:
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a):
			return edge[4]
	return &""


#How wide a bridge of that kind is
static func width_of(kind: StringName) -> float:
	return NARROW_WIDTH if kind == NARROW else WIDE_WIDTH


#How high the islands around a place on the course are (a smooth average), for the scenery that follows the climb
static func height_at(z: float) -> float:
	var total := 0.0
	var weights := 0.0
	for id: StringName in POSITIONS:
		var position: Vector3 = POSITIONS[id]
		var weight := exp(-pow((position.z - z) / 22.0, 2.0))
		total += position.y * weight
		weights += weight
	return total / maxf(weights, 0.0001)


#The bridges the feed may take down
static func fragile_edges() -> Array[Array]:
	var found: Array[Array] = []
	for edge in EDGES:
		if edge[4] == FRAGILE:
			found.append([edge[0], edge[1]])
	return found


#The sweeping block of the bridge between a and b, or an empty dictionary when it has none
static func pusher_of(a: StringName, b: StringName) -> Dictionary:
	for pusher: Dictionary in PUSHERS:
		var edge: Array = pusher["edge"]
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a):
			return pusher
	return {}


#Unit vector of the flow of the belt between a and b as seen on the ground at "time", or zero when it is not a belt
static func belt_flow(a: StringName, b: StringName, time := 0.0) -> Vector3:
	for edge in EDGES:
		if edge[4] != BELT:
			continue
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a):
			var flow := _flat_direction(edge[0], edge[1])
			var turn := turn_of(edge[0], edge[1])
			if not turn.is_empty() and not belt_forward(turn, time):
				flow = -flow
			return flow
	return Vector3.ZERO


#Unit vector of the flow of the slide between a and b (the way down), or zero when it is not a slide
static func slide_flow(a: StringName, b: StringName) -> Vector3:
	for edge in EDGES:
		if edge[4] != SLIDE:
			continue
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a):
			return _flat_direction(edge[0], edge[1])
	return Vector3.ZERO


#How the ground under whoever is on the bridge between a and b drifts at "time" (m/s): a belt carries at "belt_speed", a slide much faster
static func drift(a: StringName, b: StringName, time: float, belt_speed: float) -> Vector3:
	var flow := belt_flow(a, b, time)
	if flow != Vector3.ZERO:
		return flow * belt_speed
	return slide_flow(a, b) * SLIDE_SPEED


#The turning schedule of the belt between a and b, or an empty dictionary when it never turns
static func turn_of(a: StringName, b: StringName) -> Dictionary:
	for turn: Dictionary in TURNS:
		var edge: Array = turn["edge"]
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a):
			return turn
	return {}


#True while the belt flows from its first island to its second
static func belt_forward(turn: Dictionary, time: float) -> bool:
	var first: float = turn["phase"]
	if time < first:
		return true
	return (1 + int(floorf((time - first) / float(turn["period"])))) % 2 == 0


#True in the seconds before the belt turns around
static func belt_warning(turn: Dictionary, time: float) -> bool:
	var first: float = turn["phase"]
	var next := first
	if time >= first:
		next = first + (1.0 + floorf((time - first) / float(turn["period"]))) * float(turn["period"])
	return next - time <= TURN_WARNING


#What the belt of "edge" costs to cross from its first island to its second and back: with the flow is cheap, against it is dear
static func belt_costs(edge: Array, forward: bool) -> Vector2:
	return Vector2(edge[2], edge[3]) if forward else Vector2(edge[3], edge[2])


#The cannon that throws from "from" to "to", or an empty dictionary when there is none
static func launch_of(from: StringName, to: StringName) -> Dictionary:
	for launch: Dictionary in LAUNCHES:
		if launch["from"] == from and launch["to"] == to:
			return launch
	return {}


#The cannons that stand on an island
static func launches_from(id: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for launch: Dictionary in LAUNCHES:
		if launch["from"] == id:
			found.append(launch)
	return found


#Where the pad of a cannon is: on the island it leaves, toward the island it lands on
static func launch_pad(launch: Dictionary) -> Vector3:
	var from: Vector3 = POSITIONS[launch["from"]]
	return from + _flat_direction(launch["from"], launch["to"]) * (radius_of(launch["from"]) - LAUNCH_INSET)


#Where the arc of a cannon ends: the middle of the island it lands on
static func launch_landing(launch: Dictionary) -> Vector3:
	return POSITIONS[launch["to"]]


#Where the trampoline of an island is: in the middle of the widest stretch of the rim that no bridge touches
static func pad_position(id: StringName) -> Vector3:
	var centre: Vector3 = POSITIONS[id]
	var angles: Array[float] = []
	for edge in EDGES:
		if edge[0] == id or edge[1] == id:
			var other: StringName = edge[1] if edge[0] == id else edge[0]
			var to: Vector3 = POSITIONS[other] - centre
			angles.append(fposmod(atan2(to.z, to.x), TAU))
	angles.sort()
	var best_start := 0.0
	var best_gap := 0.0
	for index in angles.size():
		var next := angles[(index + 1) % angles.size()] + (TAU if index == angles.size() - 1 else 0.0)
		if next - angles[index] > best_gap:
			best_gap = next - angles[index]
			best_start = angles[index]
	var middle := best_start + best_gap / 2.0
	return centre + Vector3(cos(middle), 0.0, sin(middle)) * PAD_DISTANCE


static func _flat_direction(from: StringName, to: StringName) -> Vector3:
	var direction: Vector3 = POSITIONS[to] - POSITIONS[from]
	direction.y = 0.0
	return direction.normalized()
