class_name Level01Layout
extends RefCounted

#Single source of truth of level 1: graph, platforms, belts, slides, fragile bridges and obstacles

#Centre distance worth one unit of cost
const UNIT := 9.5

#Platform centres: x and z on the ground (north is -Z) and the top height
const POSITIONS := {
	&"N": Vector3(0.0, 14.0, 132.0),
	&"Aw": Vector3(-24.0, 14.0, 132.0),
	&"Ce": Vector3(24.0, 14.0, 132.0),
	&"A1": Vector3(-24.0, 14.0, 114.0),
	&"A2": Vector3(-24.0, 14.0, 98.0),
	&"A3": Vector3(-24.0, 14.0, 82.0),
	&"A4": Vector3(-24.0, 14.0, 66.0),
	&"Ax": Vector3(-24.0, 14.0, 48.0),
	&"B1": Vector3(0.0, 14.0, 114.0),
	&"B2": Vector3(0.0, 14.0, 90.0),
	&"B3": Vector3(0.0, 14.0, 67.0),
	&"C1": Vector3(24.0, 14.0, 114.0),
	&"C2": Vector3(24.0, 14.0, 98.0),
	&"C3": Vector3(24.0, 14.0, 82.0),
	&"C4": Vector3(24.0, 14.0, 66.0),
	&"Cx": Vector3(24.0, 14.0, 48.0),
	&"S": Vector3(0.0, 14.0, 48.0),
	&"h1": Vector3(-19.0, 10.0, 32.0),
	&"h2": Vector3(-34.0, 6.0, 22.0),
	&"z1": Vector3(19.0, 10.0, 32.0),
	&"z2": Vector3(9.0, 6.0, 17.0),
	&"An": Vector3(-24.0, 2.0, 4.0),
	&"A5": Vector3(-24.0, 2.0, -14.0),
	&"A6": Vector3(-24.0, 2.0, -30.0),
	&"A7": Vector3(-24.0, 2.0, -46.0),
	&"A8": Vector3(-24.0, 2.0, -62.0),
	&"Ay": Vector3(-24.0, 2.0, -80.0),
	&"Bn": Vector3(0.0, 2.0, 4.0),
	&"B5": Vector3(0.0, 2.0, -14.0),
	&"B6": Vector3(0.0, 2.0, -30.0),
	&"B7": Vector3(0.0, 2.0, -46.0),
	&"B8": Vector3(0.0, 2.0, -62.0),
	&"Cn": Vector3(24.0, 2.0, 4.0),
	&"C5": Vector3(24.0, 2.0, -14.0),
	&"C6": Vector3(24.0, 2.0, -30.0),
	&"C7": Vector3(24.0, 2.0, -46.0),
	&"C8": Vector3(24.0, 2.0, -62.0),
	&"Cy": Vector3(24.0, 2.0, -80.0),
	&"E": Vector3(0.0, 2.0, -80.0),
	&"M": Vector3(0.0, 6.0, -112.0),
}

const DEFAULT_RADIUS := 6.5
const RADII := {
	&"N": 9.0,
	&"S": 11.0,
	&"E": 10.0,
	&"M": 9.0,
	&"h1": 4.0,
	&"h2": 4.0,
	&"z1": 4.0,
	&"z2": 4.0,
}
#Way plates: squares as wide as the ways, laid along them
const PLATE := 9.0
const PLATES: Array[StringName] = [&"A1", &"A2", &"A3", &"A4", &"B1", &"B2", &"B3", &"C1", &"C2", &"C3", &"C4",
	&"A5", &"A6", &"A7", &"A8", &"B5", &"B6", &"B7", &"B8", &"C5", &"C6", &"C7", &"C8"]
#Slide turn cups, walled except where slides come in and go out
const CUPS: Array[StringName] = [&"h1", &"h2", &"z1", &"z2"]
const CUP_WALL := 1.6
#Way names on the arch over each entrance
const WAY_NAMES := {
	&"A1": "LIKES", &"B1": "COMENTARIOS", &"C1": "SCROLL", &"A5": "ALGORITMO", &"B5": "VIRAL", &"C5": "HISTORIAS",
}
#Slide names over their mouths: refresh pull, loading spiral and zigzag swipe
const SLIDE_NAMES := {&"Bn": "RECARGA", &"h1": "CARGANDO", &"z1": "DESLIZA"}

#Bridge kinds: plain, belt, one-way slide, fragile and the rest
const WALK := &"walk"
const BELT := &"belt"
const SLIDE := &"slide"
const FRAGILE := &"fragile"
const NARROW := &"narrow"
const WIDE_WIDTH := 9.0
const NARROW_WIDTH := 2.4
const SLIDE_WIDTH := 5.5
#No cost back: a slide is a one-way arc
const ONE_WAY := -1.0
#Slide speed (m/s) and rail height
const SLIDE_SPEED := 10.5
const SLIDE_RAIL := 1.2

#[a, b, cost a to b, cost b to a, kind]; costs include the wait to get past hazards
const EDGES := [
	[&"N", &"Aw", 2.4, 2.4, WALK],
	[&"N", &"Ce", 2.4, 2.4, WALK],
	[&"N", &"B1", 2.0, 2.0, WALK],
	[&"Aw", &"A1", 2.2, 2.2, WALK],
	[&"A1", &"A2", 2.2, 2.2, WALK],
	[&"A2", &"A3", 1.8, 1.8, WALK],
	[&"A3", &"A4", 2.2, 2.2, WALK],
	[&"A4", &"Ax", 1.6, 1.6, WALK],
	[&"Ax", &"S", 2.4, 2.4, WALK],
	[&"B1", &"B2", 5.2, 5.2, WALK],
	[&"B2", &"B3", 5.2, 5.2, WALK],
	[&"B3", &"S", 2.0, 2.0, WALK],
	[&"Ce", &"C1", 1.6, 1.6, WALK],
	[&"C1", &"C2", 2.2, 2.2, WALK],
	[&"C2", &"C3", 1.8, 1.8, WALK],
	[&"C3", &"C4", 2.2, 2.2, WALK],
	[&"C4", &"Cx", 1.4, 3.6, BELT],
	[&"Cx", &"S", 2.4, 2.4, WALK],
	[&"S", &"Bn", 1.6, ONE_WAY, SLIDE],
	[&"S", &"h1", 1.2, ONE_WAY, SLIDE],
	[&"h1", &"h2", 1.0, ONE_WAY, SLIDE],
	[&"h2", &"An", 0.9, ONE_WAY, SLIDE],
	[&"S", &"z1", 1.1, ONE_WAY, SLIDE],
	[&"z1", &"z2", 1.0, ONE_WAY, SLIDE],
	[&"z2", &"Cn", 1.0, ONE_WAY, SLIDE],
	[&"An", &"A5", 1.9, 1.9, WALK],
	[&"A5", &"A6", 2.6, 2.6, WALK],
	[&"A6", &"A7", 1.7, 1.7, WALK],
	[&"A7", &"A8", 2.6, 2.6, WALK],
	[&"A8", &"Ay", 1.9, 1.9, WALK],
	[&"Ay", &"E", 2.6, 2.6, WALK],
	[&"Bn", &"B5", 1.9, 1.9, WALK],
	[&"B5", &"B6", 2.6, 2.6, WALK],
	[&"B6", &"B7", 2.4, 2.4, WALK],
	[&"B7", &"B8", 2.6, 2.6, WALK],
	[&"B8", &"E", 2.4, 2.4, WALK],
	[&"Cn", &"C5", 1.9, 1.9, WALK],
	[&"C5", &"C6", 2.3, 2.3, WALK],
	[&"C6", &"C7", 2.3, 2.3, WALK],
	[&"C7", &"C8", 1.7, 1.7, WALK],
	[&"C8", &"Cy", 1.9, 1.9, WALK],
	[&"Cy", &"E", 2.6, 2.6, WALK],
	[&"E", &"M", 3.4, 3.4, WALK],
]

#Comments: a bubble typed on one side that sweeps across; "at" is its share of the bridge
const COMMENTS := [
	{"edge": [&"C5", &"C6"], "at": 0.5, "period": 6.0, "phase": 2.0, "words": ["mi día", "spoiler", "ya vi", "mood"]},
]
#Comment cycle: typed, flashing, pushing and deflating
const COMMENT_TYPE := 1.5
const COMMENT_WARN := 0.9
const COMMENT_PUSH := 0.35
const COMMENT_FADE := 0.6
#Decks under every way bridge, so a fall costs the way back and not an attempt
const DECK_DEPTH := 5.0
const DECK_MARGIN := 3.5
const DECK_EXTRA := 4.0
const DECK_PAD_OUT := 3.5
const DECK_PAD_SIDE := 1.0
#Bubble landing on a plate: off the ball line and out of the bar's reach
const DECK_LANDING_IN := 2.9
#A fall from the second axe row of Comentarios goes back to its first plate
const LIFT_BACK := {"B2|B3": &"B1"}
const DECK_CORNER := 0.9
#Deck corner radius and soft rim; no rim where the edge lies inside another deck
const DECK_ROUND := 2.0
const DECK_RIM := 1.6
const DECK_TUBE := 0.55
#Rim pieces per corner and side test step
const DECK_CORNER_STEPS := 5
const DECK_RIM_STEP := 0.25
#Height over a deck floor that counts as standing or falling on it
const DECK_CATCH := 3.0

const START := &"N"
const GOAL := &"M"
#The two plazas save progress
const CHECKPOINTS: Array[StringName] = [&"S", &"E"]

#Spinner bars: "arm" half length, "speed" rad/s with sign, "phase" start angle, optional "surge"
const SPINNERS := {
	&"A2": {"arm": 4.2, "speed": 1.15, "phase": 0.3, "arms": 2},
	&"A3": {"arm": 4.2, "speed": -2.0, "phase": 2.0, "surge": {"depth": 0.5, "rate": 1.1}},
	&"B2": {"arm": 4.2, "speed": 1.2, "phase": 0.8, "arms": 2},
	&"B6": {"arm": 4.2, "speed": 1.7, "phase": 0.0, "surge": {"depth": 0.45, "rate": 0.9}},
	&"B8": {"arm": 4.2, "speed": -1.1, "phase": 1.0, "arms": 2},
	&"C5": {"arm": 4.2, "speed": 1.5, "phase": 0.6},
	&"C7": {"arm": 4.2, "speed": -1.8, "phase": 1.2, "surge": {"depth": 0.45, "rate": 0.9}},
}

#Turning belts: forward until "phase", then reversing every "period"; arrows blink before
const TURNS := [
	{"edge": [&"C4", &"Cx"], "period": 17.0, "phase": 8.0},
]
const TURN_WARNING := 1.5

#Rolling balls back and forth along "angle" through the middle every "period"
const BALLS := [
	{"island": &"Ay", "angle": 0.0, "period": 3.0, "phase": 0.4},
]
const BALL_RADIUS := 0.5

#Sweeping blocks at "at" of a bridge, side to side every "period"; "look" is its model
const PUSHERS := [
	{"edge": [&"A2", &"A3"], "at": 0.5, "period": 2.6, "phase": 1.4, "look": &"like_hand"},
	{"edge": [&"B6", &"B7"], "at": 0.5, "period": 2.4, "phase": 0.5, "look": &"hashtag"},
]

#Comentarios axes: comment rows swinging like pendulums, each "lag" behind the last
const AXES := [
	{"edge": [&"B1", &"B2"], "count": 5, "period": 2.4, "phase": 0.0, "lag": 0.6, "words": ["ratio", "jaja", "spam", "+1", "lol"]},
	{"edge": [&"B2", &"B3"], "count": 5, "period": 2.2, "phase": 0.9, "lag": 0.55, "words": ["cringe", "f", "xd", "ok", "bot"]},
]
#Axe pivot height, rod length, swing and comment size
const AXE_PIVOT := 7.6
const AXE_ROD := 7.0
const AXE_SWING := 1.05
const AXE_BLADE := Vector3(3.0, 1.7, 1.0)

#Likes punchers: a box at one side punching a like across at "at" every period
const PUNCHERS := [
	{"edge": [&"Aw", &"A1"], "at": 0.3, "side": 1.0, "period": 2.6, "phase": 0.0},
	{"edge": [&"Aw", &"A1"], "at": 0.7, "side": -1.0, "period": 2.6, "phase": 1.3},
	{"edge": [&"A1", &"A2"], "at": 0.3, "side": -1.0, "period": 2.2, "phase": 0.4},
	{"edge": [&"A1", &"A2"], "at": 0.7, "side": 1.0, "period": 2.2, "phase": 1.5},
	{"edge": [&"A3", &"A4"], "at": 0.3, "side": 1.0, "period": 2.0, "phase": 0.2},
	{"edge": [&"A3", &"A4"], "at": 0.7, "side": -1.0, "period": 2.0, "phase": 1.2},
]
#Punch reach and cycle parts: shake, fly, hold and return
const PUNCH_REACH := 6.4
const PUNCH_WINDUP := 0.5
const PUNCH_OUT := 0.14
const PUNCH_HOLD := 0.3
const PUNCH_BACK := 0.7
#The like as the hit test sees it
const PUNCH_FIST := Vector3(1.6, 1.5, 1.2)

#Runs of things rolling from the far plate to the near one: scroll wheels or giant balls
const ROLLER := &"roller"
const BOULDER := &"boulder"
const RUNS := [
	{"kind": ROLLER, "from": &"C2", "to": &"C1", "speed": 4.6, "every": 1.5, "phase": 0.0},
	{"kind": ROLLER, "from": &"C4", "to": &"C3", "speed": 5.0, "every": 1.3, "phase": 0.7},
	{"kind": BOULDER, "from": &"A6", "to": &"A5", "speed": 6.0, "every": 1.7, "phase": 0.0},
	{"kind": BOULDER, "from": &"A8", "to": &"A7", "speed": 6.5, "every": 1.5, "phase": 0.8},
]
#Wheel radius and length; giant ball radius, lanes and lane warning
const ROLLER_RADIUS := 0.45
const ROLLER_LENGTH := 4.4
const BOULDER_RADIUS := 1.2
const BOULDER_LANES: Array[float] = [-3.0, 0.0, 3.0]
const BOULDER_WARN := 1.2
#Seconds to rise and to sink
const RUN_RISE := 0.35

#Viral fans: spin up, blow across for "blow" seconds and rest every "period"
const FANS := [
	{"edge": [&"B5", &"B6"], "side": -1.0, "period": 4.4, "blow": 1.9, "phase": 0.0, "power": 4.2},
	{"edge": [&"B7", &"B8"], "side": 1.0, "period": 4.0, "blow": 1.8, "phase": 1.6, "power": 4.4},
]
const FAN_SPIN_UP := 0.9

#Historias story plates: tiles that shake, drop and come back
const TILE_PLATES: Array[StringName] = [&"C6", &"C8"]
const TILE_GRID := 3
const TILE_GAP := 0.12
const TILE_SHAKE := 0.7
const TILE_GONE := 4.0

#"shortcuts" false leaves out narrow bridges (none in this course)
static func build_graph(shortcuts := true) -> WeightedGraph:
	var graph := WeightedGraph.new()
	for id: StringName in POSITIONS:
		graph.add_vertex(id)
	for edge in EDGES:
		if edge[4] == NARROW and not shortcuts:
			continue
		graph.add_edge(edge[0], edge[1], edge[2], false)
		if edge[3] != ONE_WAY:
			graph.add_edge(edge[1], edge[0], edge[3], false)
	return graph


static func radius_of(id: StringName) -> float:
	if PLATES.has(id):
		return PLATE / 2.0
	return RADII.get(id, DEFAULT_RADIUS)


static func is_plate(id: StringName) -> bool:
	return PLATES.has(id)


static func kind_of(a: StringName, b: StringName) -> StringName:
	for edge in EDGES:
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a):
			return edge[4]
	return &""


static func width_of(kind: StringName) -> float:
	if kind == NARROW:
		return NARROW_WIDTH
	return SLIDE_WIDTH if kind == SLIDE else WIDE_WIDTH


#Smoothed island height around a point, for scenery
static func height_at(z: float) -> float:
	var total := 0.0
	var weights := 0.0
	for id: StringName in POSITIONS:
		var position: Vector3 = POSITIONS[id]
		var weight := exp(-pow((position.z - z) / 22.0, 2.0))
		total += position.y * weight
		weights += weight
	return total / maxf(weights, 0.0001)


static func fragile_edges() -> Array[Array]:
	var found: Array[Array] = []
	for edge in EDGES:
		if edge[4] == FRAGILE:
			found.append([edge[0], edge[1]])
	return found


#Sweeping block of a bridge, or empty
static func pusher_of(a: StringName, b: StringName) -> Dictionary:
	for pusher: Dictionary in PUSHERS:
		var edge: Array = pusher["edge"]
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a):
			return pusher
	return {}


#Belt flow at "time" on the ground, or zero
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


#Slide flow downhill, or zero
static func slide_flow(a: StringName, b: StringName) -> Vector3:
	for edge in EDGES:
		if edge[4] != SLIDE:
			continue
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a):
			return _flat_direction(edge[0], edge[1])
	return Vector3.ZERO


#Ground drift on a bridge at "time" (m/s)
static func drift(a: StringName, b: StringName, time: float, belt_speed: float) -> Vector3:
	var flow := belt_flow(a, b, time)
	if flow != Vector3.ZERO:
		return flow * belt_speed
	return slide_flow(a, b) * SLIDE_SPEED


#Turn schedule of a belt, or empty
static func turn_of(a: StringName, b: StringName) -> Dictionary:
	for turn: Dictionary in TURNS:
		var edge: Array = turn["edge"]
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a):
			return turn
	return {}


#True while the belt flows forward
static func belt_forward(turn: Dictionary, time: float) -> bool:
	var first: float = turn["phase"]
	if time < first:
		return true
	return (1 + int(floorf((time - first) / float(turn["period"])))) % 2 == 0


#True just before the belt turns
static func belt_warning(turn: Dictionary, time: float) -> bool:
	var first: float = turn["phase"]
	var next := first
	if time >= first:
		next = first + (1.0 + floorf((time - first) / float(turn["period"]))) * float(turn["period"])
	return next - time <= TURN_WARNING


#Belt costs both ways: cheap with the flow
static func belt_costs(edge: Array, forward: bool) -> Vector2:
	return Vector2(edge[2], edge[3]) if forward else Vector2(edge[3], edge[2])


#Bridges with a deck under them
static func soft_edges() -> Array[Array]:
	var found: Array[Array] = []
	for edge in EDGES:
		if edge[4] != SLIDE and edge[1] != GOAL:
			found.append([edge[0], edge[1]])
	return found


#Comment of a bridge, or empty
static func comment_of(a: StringName, b: StringName) -> Dictionary:
	for comment: Dictionary in COMMENTS:
		var edge: Array = comment["edge"]
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a):
			return comment
	return {}


#Deck under a bridge: top, size, turn and its pad and landing
static func deck_of(edge: Array) -> Dictionary:
	var from: Vector3 = POSITIONS[edge[0]]
	var to: Vector3 = POSITIONS[edge[1]]
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var direction := flat.normalized()
	var top := minf(from.y, to.y) - DECK_DEPTH
	var start_first := from.z >= to.z
	var start: StringName = edge[0] if start_first else edge[1]
	var away := direction if start_first else -direction
	#Pad on the side facing the course middle, never under a fan
	var side := Vector3(-away.z, 0.0, away.x)
	if side.x * (POSITIONS[start] as Vector3).x > 0.0 or (is_zero_approx(side.x) and side.z < 0.0):
		side = -side
	var fan := fan_of(edge[0], edge[1])
	if not fan.is_empty() and side.dot(across_of(edge[0], edge[1])) * float(fan["side"]) > 0.0:
		side = -side
	var pad: Vector3 = POSITIONS[start] + away * (radius_of(start) + DECK_PAD_OUT) + side * (width_of(kind_of(edge[0], edge[1])) / 2.0 + DECK_PAD_SIDE)
	pad.y = top
	return {
		"edge": edge, "top": top, "yaw": atan2(direction.x, direction.z),
		"center": Vector3((from.x + to.x) / 2.0, top, (from.z + to.z) / 2.0),
		"size": Vector2(width_of(kind_of(edge[0], edge[1])) + 2.0 * DECK_MARGIN, flat.length() + DECK_EXTRA),
		"lift": {"edge": edge, "to": LIFT_BACK.get("%s|%s" % edge, start), "pad": pad,
			"landing": deck_landing(LIFT_BACK.get("%s|%s" % edge, start), away)},
	}


#Bubble landing on the start platform of the bridge
static func deck_landing(start: StringName, away: Vector3) -> Vector3:
	var centre: Vector3 = POSITIONS[start]
	if not PLATES.has(start):
		#On a ball island it lands beside the ball line
		for ball: Dictionary in BALLS:
			if ball["island"] == start:
				return centre + Vector3(-sin(float(ball["angle"])), 0.0, cos(float(ball["angle"]))) * 2.6
		return centre
	if not SPINNERS.has(start):
		#On the half of the plate where nothing rolls
		var ahead := centre + away * DECK_LANDING_IN
		return centre - away * DECK_LANDING_IN if run_at(ahead, 0.5) >= 0 else ahead
	var side := Vector3(-away.z, 0.0, away.x)
	if side.x * centre.x > 0.0:
		side = -side
	return centre + (away + side) * (PLATE / 2.0 - DECK_CORNER)


#Distance to the deck edge, negative inside
static func deck_distance(deck: Dictionary, point: Vector3) -> float:
	var size: Vector2 = deck["size"]
	var local := Basis(Vector3.UP, float(deck["yaw"])).inverse() * (point - (deck["center"] as Vector3))
	var corner := Vector2(absf(local.x), absf(local.z)) - (size / 2.0 - Vector2.ONE * DECK_ROUND)
	return Vector2(maxf(corner.x, 0.0), maxf(corner.y, 0.0)).length() + minf(maxf(corner.x, corner.y), 0.0) - DECK_ROUND


#Inside the deck floor, "inset" from its edge
static func deck_holds(deck: Dictionary, point: Vector3, inset := 0.0) -> bool:
	return deck_distance(deck, point) <= -inset


#Outward direction at a deck edge point
static func deck_normal(deck: Dictionary, point: Vector3) -> Vector3:
	var size: Vector2 = deck["size"]
	var basis := Basis(Vector3.UP, float(deck["yaw"]))
	var local := basis.inverse() * (point - (deck["center"] as Vector3))
	var corner := Vector2(absf(local.x), absf(local.z)) - (size / 2.0 - Vector2.ONE * DECK_ROUND)
	var out := Vector2(signf(local.x), 0.0) if corner.x >= corner.y else Vector2(0.0, signf(local.z))
	if corner.x > 0.0 and corner.y > 0.0:
		out = Vector2(corner.x * signf(local.x), corner.y * signf(local.z)).normalized()
	return basis * Vector3(out.x, 0.0, out.y)


#Every deck in soft_edges order
static func all_decks() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for edge in soft_edges():
		found.append(deck_of(edge))
	return found


#Bubble that catches whoever is on the decks at "point"; overlaps pick the one going furthest back
static func deck_catching(decks: Array[Dictionary], point: Vector3) -> Dictionary:
	var best: Dictionary = {}
	for deck in decks:
		var top: float = deck["top"]
		if point.y < top - 0.5 or point.y > top + DECK_CATCH or not deck_holds(deck, point, -0.3):
			continue
		var lift: Dictionary = deck["lift"]
		if best.is_empty() or (POSITIONS[lift["to"]] as Vector3).z > (POSITIONS[best["to"]] as Vector3).z:
			best = lift
	return best


#Deck rim line with outward directions and corner flags
static func _rim_loop(deck: Dictionary) -> Array[Dictionary]:
	var size: Vector2 = deck["size"]
	var basis := Basis(Vector3.UP, float(deck["yaw"]))
	var centre: Vector3 = deck["center"]
	var half := size / 2.0 - Vector2.ONE * DECK_ROUND
	var middles: Array[Vector2] = [Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y), Vector2(half.x, -half.y)]
	var reach := DECK_ROUND - DECK_TUBE
	var found: Array[Dictionary] = []
	for index in 4:
		for step in DECK_CORNER_STEPS + 1:
			var angle := PI / 2.0 * (index + float(step) / DECK_CORNER_STEPS)
			var out := Vector2(cos(angle), sin(angle))
			var spot := middles[index] + out * reach
			found.append({"at": centre + basis * Vector3(spot.x, 0.0, spot.y), "out": basis * Vector3(out.x, 0.0, out.y), "corner": true})
		var way := Vector2(cos(PI / 2.0 * (index + 1)), sin(PI / 2.0 * (index + 1)))
		var from := middles[index] + way * reach
		var to := middles[(index + 1) % 4] + way * reach
		var count := maxi(ceili(from.distance_to(to) / DECK_RIM_STEP), 1)
		for step in range(1, count):
			var spot := from.lerp(to, float(step) / count)
			found.append({"at": centre + basis * Vector3(spot.x, 0.0, spot.y), "out": basis * Vector3(way.x, 0.0, way.y), "corner": false})
	return found


#Rim stretches that stand; none inside another deck at the same height
static func deck_rim(edge: Array) -> Array[Dictionary]:
	var edges := soft_edges()
	var own := edges.find(edge)
	var deck := deck_of(edge)
	var others: Array[Dictionary] = []
	var orders: Array[int] = []
	for index in edges.size():
		var other := deck_of(edges[index])
		var reach := ((other["size"] as Vector2).length() + (deck["size"] as Vector2).length()) / 2.0 + 1.0
		if index != own and is_equal_approx(float(other["top"]), float(deck["top"])) and (other["center"] as Vector3).distance_to(deck["center"]) < reach:
			others.append(other)
			orders.append(index)
	var loop := _rim_loop(deck)
	var kept: Array[bool] = []
	for point in loop:
		var rim_edge: Vector3 = (point["at"] as Vector3) + (point["out"] as Vector3) * DECK_TUBE
		var stands := true
		for index in others.size():
			var away := deck_distance(others[index], rim_edge)
			if away < -0.05:
				stands = false
			elif absf(away) <= 0.05 and orders[index] < own and deck_normal(others[index], rim_edge).dot(point["out"] as Vector3) > 0.95:
				stands = false
		kept.append(stands)
	var found: Array[Dictionary] = []
	if not kept.has(false):
		found.append({"points": _rim_points(loop, range(loop.size())), "closed": true})
		return found
	var start := (kept.find(false) + 1) % loop.size()
	var run: Array = []
	for step in loop.size():
		var index := (start + step) % loop.size()
		if kept[index]:
			run.append(index)
		elif not run.is_empty():
			found.append({"points": _rim_points(loop, run), "closed": false})
			run = []
	if not run.is_empty():
		found.append({"points": _rim_points(loop, run), "closed": false})
	return found


#Stretch points without the middle of straight sides
static func _rim_points(loop: Array[Dictionary], run: Array) -> PackedVector3Array:
	var points := PackedVector3Array()
	for at in run.size():
		var index: int = run[at]
		var ends := at == 0 or at == run.size() - 1
		if ends or loop[index]["corner"] or loop[run[at - 1]]["corner"] or loop[run[at + 1]]["corner"]:
			points.append(loop[index]["at"])
	return points


#Rim wall boxes along the stretches
static func deck_walls(edge: Array) -> Array[Dictionary]:
	return rim_walls(deck_rim(edge))


#Walls of the rim stretches
static func rim_walls(rim: Array[Dictionary]) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for stretch in rim:
		var points: PackedVector3Array = stretch["points"]
		var closed: bool = stretch["closed"]
		var count := points.size() if closed else points.size() - 1
		for index in count:
			var from := points[index]
			var to := points[(index + 1) % points.size()]
			var way := to - from
			var length := way.length()
			if length < 0.01:
				continue
			var ahead := way / length
			var before := DECK_TUBE if not closed and index == 0 else 0.15
			var after := DECK_TUBE if not closed and index == count - 1 else 0.15
			var centre := from + ahead * (length + after - before) / 2.0
			found.append({"center": centre, "size": Vector3(DECK_TUBE * 2.0, DECK_RIM, length + before + after), "yaw": atan2(ahead.x, ahead.z)})
	return found


#Deck pads, unknown to the graph
static func deck_lifts() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for edge in soft_edges():
		found.append(deck_of(edge)["lift"])
	return found


#Unit vector across a bridge, to the left going forward
static func across_of(a: StringName, b: StringName) -> Vector3:
	for edge in EDGES:
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a):
			var along := _flat_direction(edge[0], edge[1])
			return Vector3(-along.z, 0.0, along.x)
	return Vector3.ZERO


static func _same_edge(edge: Array, a: StringName, b: StringName) -> bool:
	return (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a)


#Axe rows, punchers and fan of a bridge
static func axes_of(a: StringName, b: StringName) -> Dictionary:
	for row: Dictionary in AXES:
		if _same_edge(row["edge"], a, b):
			return row
	return {}


static func punchers_of(a: StringName, b: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for puncher: Dictionary in PUNCHERS:
		if _same_edge(puncher["edge"], a, b):
			found.append(puncher)
	return found


static func fan_of(a: StringName, b: StringName) -> Dictionary:
	for fan: Dictionary in FANS:
		if _same_edge(fan["edge"], a, b):
			return fan
	return {}


#Run line from the far plate middle to the near one, with along and across vectors
static func run_line(run: Dictionary) -> Dictionary:
	var from: Vector3 = POSITIONS[run["from"]]
	var to: Vector3 = POSITIONS[run["to"]]
	var along := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length := along.length()
	along /= maxf(length, 0.001)
	return {"from": from, "to": to, "along": along, "across": Vector3(-along.z, 0.0, along.x), "length": length}


#Run under a point with "margin", or -1
static func run_at(point: Vector3, margin := 0.0) -> int:
	for index in RUNS.size():
		var line := run_line(RUNS[index])
		var offset := point - (line["from"] as Vector3)
		var along := offset.dot(line["along"] as Vector3)
		if along >= -margin and along <= float(line["length"]) + margin and absf(offset.dot(line["across"] as Vector3)) <= PLATE / 2.0 + margin 				and absf(point.y - (line["from"] as Vector3).y) < 3.0:
			return index
	return -1


#Tile centres of a story plate
static func tile_centers(id: StringName) -> Array[Vector3]:
	var centre: Vector3 = POSITIONS[id]
	var step := PLATE / TILE_GRID
	var found: Array[Vector3] = []
	for row in TILE_GRID:
		for column in TILE_GRID:
			found.append(centre + Vector3((column - (TILE_GRID - 1) / 2.0) * step, 0.0, (row - (TILE_GRID - 1) / 2.0) * step))
	return found


static func tile_side() -> float:
	return PLATE / TILE_GRID - TILE_GAP


static func _flat_direction(from: StringName, to: StringName) -> Vector3:
	var direction: Vector3 = POSITIONS[to] - POSITIONS[from]
	direction.y = 0.0
	return direction.normalized()
