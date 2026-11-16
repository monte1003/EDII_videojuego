class_name SelfieLayout
extends ArenaLayout

#"El Plató": a long floating studio (88 x 48 m, a stadium of candy floor) with eleven sets, each with a backdrop of its own and a
#challenge of its own. In the middle a turntable under a giant ring light; along the north side the raised runway with its belt, the
#troll zone where the bots live (low pads to hop between while they shove) and the unboxing (gift boxes that pop); across the middle the
#gym (two treadmills that run opposite ways and a dumbbell that turns) and the selfie sticks (two that sweep the set); the podium of three
#heights at the west end and the dance floor at the east end; to the south the pool of balls, the red carpet before a photo wall and the
#live set on a round stage. This file is only data: the shapes, the places and links of the graph, the tricks and how high the floor is
#anywhere. SelfieStage builds it

enum Trick { NONE, SPIN, WAX, BELT, PODIUM, CARPET, PIT, BEAT, TROLL, UNBOX, GYM, STICKS }

const HUB := &"T"
#How high over a place the drone flies
const DRONE_HEIGHT := 6.5
#The island: a stadium this long and wide, with round ends of half its width
const DECK_SIZE := Vector2(88.0, 48.0)
const HALF := Vector2(44.0, 24.0)
#The turntable in the middle of the floor, flush with it: its radius and how fast it turns (radians per second)
const TURNTABLE_RADIUS := 5.0
const TURNTABLE_SPIN := 0.6
#The runway: a raised deck along the north side and the two ramps down from its ends (20 degrees). Under it there is room to walk and
#jump: a body of 1 m and a jump of 1.07 m fit under its 2.1 m
const UPPER := 2.4
const RUNWAY := Rect2(-8.0, -19.7, 16.0, 7.4)
const RAMP_RUN := 6.6
const DECK_THICKNESS := 0.3
#The candy pillars under the runway, off the axes so nobody walks right on x = 0 against them
const RUNWAY_PILLARS: Array[Vector2] = [Vector2(-5.87, -19.1), Vector2(0.13, -19.1), Vector2(6.13, -19.1), Vector2(-5.87, -12.9),
	Vector2(0.13, -12.9), Vector2(6.13, -12.9)]
const PILLAR_RADIUS := 0.3
#The podium: the first place, the second with its step in front and the third, and how high each one is. Each height is one jump
#from the next, and the first is also one trampoline from the floor
const PODIUM := Rect2(-37.5, -3.5, 7.0, 7.0)
const SECOND := Rect2(-35.5, -8.0, 4.5, 4.5)
const SECOND_STEP := Rect2(-31.0, -8.0, 1.7, 4.5)
const THIRD := Rect2(-35.5, 3.5, 4.5, 4.5)
const PODIUM_TOP := 1.8
const SECOND_TOP := 1.2
const LOW_TOP := 0.6
#The dance floor, the red carpet, the pool of balls (its foam curb, low enough not to hide feet in a photo, and its floor) and the round
#stage of the live set with its ramp
const DANCE_CENTER := Vector2(34.0, 0.0)
const DANCE_RADIUS := 5.5
const CARPET := Rect2(-3.7, 12.05, 7.4, 6.9)
const POOL_CENTER := Vector2(-17.0, 14.0)
const POOL_INNER := 5.0
const POOL_OUTER := 5.6
const POOL_WALL := 0.3
const LIVE_CENTER := Vector2(17.0, 14.0)
const LIVE_RADIUS := 5.0
const LIVE_TOP := 0.6
const LIVE_RAMP: Array = [Vector2(11.58, 9.98), Vector2(12.99, 11.02), 2.6]
#The troll zone, where the bots live: a floor walled by a low curb that a player hops over and a bot never crosses, with low pads
#to stand on ([centre, radius, top]): a bot shoves whoever is on the floor or on a low pad, but cannot reach the high one
const TROLL := Rect2(-30.5, -18.5, 13.0, 9.0)
const TROLL_CURB := 0.5
const CURB_THICKNESS := 0.4
const TROLL_PADS: Array = [[Vector2(-24.5, -13.6), 1.2, 1.2], [Vector2(-27.6, -15.9), 1.1, 0.8], [Vector2(-21.4, -15.9), 1.1, 0.8],
	[Vector2(-27.8, -11.3), 1.0, 0.8], [Vector2(-21.2, -11.3), 1.0, 0.8]]
#The unboxing: a grid of gift boxes flush with the floor; each one rattles, then pops and throws up whoever stands on it. "period"
#seconds between two pops of a box, how long it rattles first and how long its spring is out
const UNBOX_CENTER := Vector2(24.0, -14.0)
const UNBOX_CELL := 3.6
const UNBOX_GRID := 3
const UNBOX_PERIOD := 3.3
const UNBOX_WARN := 0.75
const UNBOX_POP := 0.3
const UNBOX_LIFT := 8.5
const UNBOX_THROW := 4.0
#The gym: two treadmills that run opposite ways with a still aisle between them, slower than the belt of the runway (walking
#against one keeps a body in the photo), and a dumbbell that turns slowly over them, low enough to jump
const GYM_CENTER := Vector2(-17.0, 0.0)
const TREADMILL := Vector2(8.0, 3.0)
const TREADMILL_SPEED := 1.7
#The still strip of mat between the two treadmills, where a body can stand and only has to jump the dumbbell
const GYM_AISLE := 1.2
#The selfie sticks: two giant sticks with a phone on top that sweep the set across
const STICKS_CENTER := Vector2(17.0, 0.0)
#Each set: its id, the middle of its frame, half its flat floor (x and z), the height of that floor, its trick, the turn of the
#camera of its photos in degrees (the photo looks toward the backdrop of the set) and how far in front of the middle of the frame
#the photo still draws things
const SETS: Array[Array] = [
	[&"T", Vector2(0.0, 0.0), Vector2(3.45, 3.45), 0.0, Trick.SPIN, 45.0, 9.0],
	[&"P", Vector2(-34.0, 0.0), Vector2(3.45, 3.45), PODIUM_TOP, Trick.PODIUM, 45.0, 9.0],
	[&"W", Vector2(34.0, 0.0), Vector2(3.6, 3.6), 0.0, Trick.WAX, -45.0, 9.0],
	[&"C", Vector2(0.0, 15.5), Vector2(3.6, 3.45), 0.0, Trick.CARPET, -135.0, 9.0],
	[&"F", Vector2(-17.0, 14.0), Vector2(3.45, 3.45), 0.0, Trick.PIT, 135.0, 9.0],
	[&"D", Vector2(17.0, 14.0), Vector2(3.45, 3.45), LIVE_TOP, Trick.BEAT, -135.0, 9.0],
	[&"A", Vector2(0.0, -16.0), Vector2(7.0, 3.45), UPPER, Trick.BELT, -45.0, 9.0],
	[&"Z", Vector2(-24.0, -14.0), Vector2(5.9, 4.0), 0.0, Trick.TROLL, 45.0, 9.0],
	[&"U", Vector2(24.0, -14.0), Vector2(5.0, 5.0), 0.0, Trick.UNBOX, -45.0, 9.0],
	[&"G", Vector2(-17.0, 0.0), Vector2(4.4, 3.4), 0.0, Trick.GYM, 45.0, 9.0],
	[&"S", Vector2(17.0, 0.0), Vector2(4.4, 3.6), 0.0, Trick.STICKS, -45.0, 9.0],
]
#Room a frame keeps to the edge of its set
const FRAME_MARGIN := 0.35
#The photo wall at the end of the carpet, which nobody walks through
const PHOTO_WALL := Rect2(-4.7, 19.3, 9.4, 0.3)
const PHOTO_WALL_TOP := 3.6
#The trampoline in front of the podium, and the cannon that throws up to the runway along a fixed arc
const TRAMPOLINE := Vector3(-27.7, 0.0, 0.0)
const CANNON := Vector3(3.6, 0.0, -11.5)
const CANNON_TARGET := Vector3(2.0, UPPER, -16.3)
const CANNON_TIME := 1.9
const PEDESTALS: Array[Vector3] = [Vector3(-9.5, 0.0, -8.5), Vector3(9.5, 0.0, -8.5), Vector3(0.0, 0.0, 7.6), Vector3(-26.5, 0.0, 7.5),
	Vector3(26.5, 0.0, 7.5)]
#The live set thumps every this many seconds and lifts whoever stands on its stage
const BEAT_PERIOD := 2.0

#The place of each photo
var spots: Array[StringName] = []
#Where the power-ups stand
var pedestals: Array[Vector3] = []
#The middle of the turntable
var turntable := Vector3.ZERO

var _graph: WeightedGraph
#Set id -> flat floor to each side of its middle; set id -> [trick, turn of its camera, clip]
var _room: Dictionary = {}
var _sets: Dictionary = {}


func _init() -> void:
	zone_colors = [Color("ff7a85"), Color("3fbfae"), Color("ffc857"), Color("f6a35c")]
	ground_color = Color("fff1dc")
	belt_period = 7.0
	belt_speed = 2.6
	spawn_place = HUB
	outline = CandyTerrain.rounded_box(Vector2.ZERO, DECK_SIZE, HALF.y, 0.0, 12)
	_build_places()
	_build_tricks()
	pedestals.append_array(PEDESTALS)
	_graph = build_graph()


#The floors over a point: the highest one that is not above "ceiling". Under the runway there is floor too, so "ceiling" tells
#which of them is meant
func height_at(x: float, z: float, ceiling := INF) -> float:
	var point := Vector2(x, z)
	var best := GROUND
	var tops: Array[float] = [_box_height(PODIUM, PODIUM_TOP, point), _box_height(SECOND, SECOND_TOP, point), _box_height(SECOND_STEP, LOW_TOP, point),
		_box_height(THIRD, LOW_TOP, point), _box_height(RUNWAY, UPPER, point), _slope_height(_ramp(-1.0), point), _slope_height(_ramp(1.0), point),
		_disc_height(LIVE_CENTER, LIVE_RADIUS, LIVE_TOP, point), _slope_height(LIVE_RAMP, point, LIVE_TOP), _wall_height(point), _curb_height(point)]
	for pad: Array in TROLL_PADS:
		tops.append(_disc_height(pad[0], float(pad[1]), float(pad[2]), point))
	for top in tops:
		if top > best and top <= ceiling:
			best = top
	return best


#Whether a point is inside something solid of the studio: what could stand between a set and the camera of the drone
func solid_at(point: Vector3) -> bool:
	var flat := Vector2(point.x, point.z)
	if point.y < GROUND:
		return is_inside(point.x, point.z)
	for entry: Array in [[PODIUM, PODIUM_TOP], [SECOND, SECOND_TOP], [SECOND_STEP, LOW_TOP], [THIRD, LOW_TOP]]:
		if (entry[0] as Rect2).has_point(flat) and point.y < float(entry[1]):
			return true
	if RUNWAY.has_point(flat) and point.y > UPPER - DECK_THICKNESS and point.y < UPPER:
		return true
	if flat.distance_to(LIVE_CENTER) <= LIVE_RADIUS and point.y < LIVE_TOP:
		return true
	if PHOTO_WALL.has_point(flat) and point.y < PHOTO_WALL_TOP:
		return true
	if _curb_height(flat) > -INF and point.y < TROLL_CURB:
		return true
	for pad: Array in TROLL_PADS:
		if flat.distance_to(pad[0]) <= float(pad[1]) and point.y < float(pad[2]):
			return true
	for ramp: Array in [_ramp(-1.0), _ramp(1.0)]:
		if point.y < _slope_height(ramp, flat):
			return true
	if point.y < _slope_height(LIVE_RAMP, flat, LIVE_TOP):
		return true
	if point.y < UPPER - DECK_THICKNESS:
		for pillar in RUNWAY_PILLARS:
			if flat.distance_to(pillar) < PILLAR_RADIUS:
				return true
	return _wall_height(flat) > -INF and point.y < POOL_WALL


#The floor of the island: flat everywhere
func ground_at(_point: Vector2) -> float:
	return GROUND


#The highest floor of the map
func top_height() -> float:
	return UPPER


#The places the drone flies over to go from one photo to the next, by the cheapest route of the graph
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


#The places the bots may walk: only the troll zone, which they never leave
func bot_places() -> Array[StringName]:
	var walkable: Array[StringName] = [&"Z"]
	return walkable


#Whether a point of the ground is inside the troll zone, "margin" meters in from its curb
func in_troll(point: Vector3, margin := 0.0) -> bool:
	var inner := TROLL.grow(-CURB_THICKNESS - margin)
	return inner.has_point(Vector2(point.x, point.z))


#The gift box under a point of the unboxing (row * grid + column), or -1
func unbox_cell(point: Vector3) -> int:
	var half := UNBOX_CELL * UNBOX_GRID / 2.0
	var local := Vector2(point.x - UNBOX_CENTER.x + half, point.z - UNBOX_CENTER.y + half)
	if local.x < 0.0 or local.y < 0.0 or local.x >= UNBOX_CELL * UNBOX_GRID or local.y >= UNBOX_CELL * UNBOX_GRID:
		return -1
	return floori(local.y / UNBOX_CELL) * UNBOX_GRID + floori(local.x / UNBOX_CELL)


#The middle of a gift box on the floor
func unbox_center(cell: int) -> Vector3:
	var half := UNBOX_CELL * UNBOX_GRID / 2.0
	return Vector3(UNBOX_CENTER.x - half + UNBOX_CELL * (cell % UNBOX_GRID + 0.5), GROUND, UNBOX_CENTER.y - half + UNBOX_CELL * (floori(float(cell) / UNBOX_GRID) + 0.5))


#Where a box is in its cycle at "time": 0 at rest, rattling before the pop, and the share of its pop while its spring is out
static func unbox_phase(cell: int, time: float) -> float:
	return fposmod(time + float(cell * 7 % 9) * UNBOX_PERIOD / 9.0, UNBOX_PERIOD)


static func unbox_rattling(cell: int, time: float) -> bool:
	var phase := unbox_phase(cell, time)
	return phase >= UNBOX_PERIOD - UNBOX_WARN


static func unbox_popping(cell: int, time: float) -> bool:
	return unbox_phase(cell, time) < UNBOX_POP


func trick_of(spot: StringName) -> Trick:
	return _sets[spot][0]


#The turn in degrees of the camera that takes the photos of a set
func camera_turn(spot: StringName) -> float:
	return _sets[spot][1]


#How far in front of the middle of the frame the photo of a set still draws things
func camera_clip(spot: StringName) -> float:
	return _sets[spot][2]


#The trick of the floor a body stands on (its feet at "point"), or NONE
func trick_at(point: Vector3) -> Trick:
	var flat := Vector2(point.x, point.z)
	var on_ground := absf(point.y - GROUND) < 0.4
	if on_ground and flat.distance_to(Vector2(turntable.x, turntable.z)) <= TURNTABLE_RADIUS:
		return Trick.SPIN
	if on_ground and flat.distance_to(DANCE_CENTER) <= DANCE_RADIUS:
		return Trick.WAX
	if on_ground and CARPET.has_point(flat):
		return Trick.CARPET
	if on_ground and flat.distance_to(POOL_CENTER) <= POOL_INNER:
		return Trick.PIT
	if absf(point.y - LIVE_TOP) < 0.4 and flat.distance_to(LIVE_CENTER) <= LIVE_RADIUS:
		return Trick.BEAT
	if on_ground and unbox_cell(point) >= 0:
		return Trick.UNBOX
	return Trick.NONE


#How fast the turntable drags whoever stands at "point": it turns the same way as its picture
func spin_drift(point: Vector3) -> Vector3:
	return Vector3(TURNTABLE_SPIN * (point.z - turntable.z), 0.0, -TURNTABLE_SPIN * (point.x - turntable.x))


#The low and high end of the west (-1) or east (1) ramp of the runway on the ground, and its width
func _ramp(side: float) -> Array:
	var top_x := RUNWAY.position.x if side < 0.0 else RUNWAY.end.x
	var middle_z := RUNWAY.get_center().y
	return [Vector2(top_x + side * RAMP_RUN, middle_z), Vector2(top_x, middle_z), RUNWAY.size.y]


func ramp_of(side: float) -> Array:
	return _ramp(side)


#The studio in plain numbers, with no nodes, for whoever checks it from outside: every piece of floor with its top ("rect" with its
#centre, size and turn in degrees, "disc" with its centre and radius, or "poly" with its corners on the ground; a slope says where
#it rises), the special ways (trampolines with their throw, ramps with their slope, width and length, the belt) and the sets with
#the height of their floor and the square where their frame may go
func survey() -> Dictionary:
	var floors: Array[Dictionary] = []
	var deck: Array[Vector2] = []
	for corner in outline:
		deck.append(corner)
	floors.append({"id": "deck", "top": GROUND, "poly": deck})
	for entry: Array in [["podium", PODIUM, PODIUM_TOP], ["second", SECOND, SECOND_TOP], ["second_step", SECOND_STEP, LOW_TOP],
			["third", THIRD, LOW_TOP]]:
		floors.append({"id": entry[0], "top": entry[2], "rect": _rect_entry(entry[1])})
	floors.append({"id": "runway", "top": UPPER, "bottom": UPPER - DECK_THICKNESS, "rect": _rect_entry(RUNWAY)})
	floors.append({"id": "live_stage", "top": LIVE_TOP, "disc": {"center": LIVE_CENTER, "radius": LIVE_RADIUS}})
	floors.append({"id": "pool_wall", "top": POOL_WALL, "ring": {"center": POOL_CENTER, "inner": POOL_INNER, "outer": POOL_OUTER}})
	for index in TROLL_PADS.size():
		var pad: Array = TROLL_PADS[index]
		floors.append({"id": "troll_pad_%d" % index, "top": pad[2], "disc": {"center": pad[0], "radius": pad[1]}})
	for piece: Rect2 in [Rect2(TROLL.position, Vector2(TROLL.size.x, CURB_THICKNESS)), Rect2(TROLL.position.x, TROLL.end.y - CURB_THICKNESS, TROLL.size.x, CURB_THICKNESS),
			Rect2(TROLL.position, Vector2(CURB_THICKNESS, TROLL.size.y)), Rect2(TROLL.end.x - CURB_THICKNESS, TROLL.position.y, CURB_THICKNESS, TROLL.size.y)]:
		floors.append({"id": "troll_curb", "top": TROLL_CURB, "rect": _rect_entry(piece)})
	for seconds: float in [0.0, 2.0, 4.0]:
		floors.append({"id": "turntable_%ds" % int(seconds), "top": GROUND, "disc": {"center": Vector2(turntable.x, turntable.z), "radius": TURNTABLE_RADIUS},
			"turn": TURNTABLE_SPIN * seconds, "spin": TURNTABLE_SPIN})
	var ways: Array[Dictionary] = []
	for entry: Array in [["ramp_west", _ramp(-1.0), GROUND, UPPER], ["ramp_east", _ramp(1.0), GROUND, UPPER], ["live_ramp", LIVE_RAMP, GROUND, LIVE_TOP]]:
		var ramp: Array = entry[1]
		ways.append(_ramp_entry(entry[0], ramp[0], ramp[1], float(ramp[2]), entry[2], entry[3]))
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	for pad in pads:
		if ArenaHazards.is_cannon(pad):
			ways.append({"kind": "cannon", "at": pad["at"], "reach": ArenaHazards.PAD_REACH, "impulse": ArenaHazards.pad_launch(pad, gravity), "to": pad["to"],
				"steer": Player.FLIGHT_CONTROL})
		else:
			ways.append({"kind": "trampoline", "at": pad["at"], "reach": ArenaHazards.PAD_REACH, "impulse": Vector3(0.0, ArenaHazards.PAD_LIFT, 0.0)})
	for belt in belts:
		ways.append({"kind": "belt", "a": belt["a"], "b": belt["b"], "width": belt["width"], "speed": belt_speed, "period": belt_period,
			"turns": belt.get("turns", false)})
	var sets: Array[Dictionary] = []
	for spot in spots:
		var centre := position_of(spot)
		var room: Vector2 = _room[spot]
		sets.append({"id": spot, "floor": centre.y, "trick": Trick.keys()[trick_of(spot)], "camera_turn": camera_turn(spot), "frame_margin": FRAME_MARGIN,
			"rect": _rect_entry(Rect2(Vector2(centre.x, centre.z) - room, room * 2.0))})
	var walls: Array[Dictionary] = [{"id": "photo_wall", "top": PHOTO_WALL_TOP, "rect": _rect_entry(PHOTO_WALL)}]
	for index in RUNWAY_PILLARS.size():
		walls.append({"id": "pillar_%d" % index, "top": UPPER - DECK_THICKNESS, "disc": {"center": RUNWAY_PILLARS[index], "radius": PILLAR_RADIUS}})
	return {"floors": floors, "ways": ways, "sets": sets, "walls": walls, "outline": outline}


func _rect_entry(box: Rect2) -> Dictionary:
	return {"center": box.get_center(), "size": box.size, "yaw": 0.0}


func _ramp_entry(id: String, low: Vector2, high: Vector2, width: float, bottom: float, top: float) -> Dictionary:
	var length := low.distance_to(high)
	return {"kind": "ramp", "id": id, "from": Vector3(low.x, bottom, low.y), "to": Vector3(high.x, top, high.y), "width": width, "length": length,
		"slope_degrees": rad_to_deg(atan((top - bottom) / length))}


func _build_places() -> void:
	for entry in SETS:
		var centre: Vector2 = entry[1]
		var half: Vector2 = entry[2]
		places[entry[0]] = ArenaLayout.Place.new(entry[0], Vector3(centre.x, entry[3], centre.y), minf(half.x, half.y) - 0.3, spots.size() % zone_colors.size())
		spots.append(entry[0])
		_room[entry[0]] = half
		_sets[entry[0]] = [entry[4], entry[5], entry[6]]
	var west := _ramp(-1.0)
	var east := _ramp(1.0)
	#Crossings of the floor between the sets, the foot of each ramp of the runway, the trampoline and the cannon
	for entry: Array in [[&"j1", -9.0, -8.5, 1.2], [&"j2", 9.0, -8.5, 1.2], [&"j3", -25.0, -5.6, 1.2], [&"j4", 25.0, -5.6, 1.2],
			[&"j5", -9.0, 7.5, 1.2], [&"j6", 9.0, 7.5, 1.2], [&"j7", -27.0, 6.6, 1.2], [&"j8", 27.0, 6.6, 1.2], [&"j9", 0.0, -8.6, 0.9],
			[&"jW", -29.0, -2.6, 0.8], [&"dL", 10.6, 9.3, 0.8], [&"jw", -16.0, -10.4, 0.9], [&"je", 16.0, -10.4, 0.9],
			[&"rW", (west[0] as Vector2).x - 1.2, -16.0, 1.4], [&"rE", (east[0] as Vector2).x + 1.2, -16.0, 1.4],
			[&"tpP", TRAMPOLINE.x, TRAMPOLINE.z, 0.9], [&"tpA", CANNON.x, CANNON.z, 0.9]]:
		add_place(entry[0], entry[1], entry[2], entry[3], 3)
	places[&"aW"] = ArenaLayout.Place.new(&"aW", Vector3(-6.4, UPPER, -16.0), 1.4, 1)
	places[&"aE"] = ArenaLayout.Place.new(&"aE", Vector3(6.4, UPPER, -16.0), 1.4, 1)
	places[&"pS"] = ArenaLayout.Place.new(&"pS", Vector3(SECOND_STEP.get_center().x, LOW_TOP, SECOND_STEP.get_center().y), 0.7, 2)
	places[&"p2"] = ArenaLayout.Place.new(&"p2", Vector3(SECOND.get_center().x, SECOND_TOP, SECOND.get_center().y), 1.4, 2)
	places[&"p3"] = ArenaLayout.Place.new(&"p3", Vector3(THIRD.get_center().x, LOW_TOP, THIRD.get_center().y), 1.4, 2)
	for pair: Array in [[HUB, &"j1"], [HUB, &"j2"], [HUB, &"j5"], [HUB, &"j6"], [HUB, &"j9"], [&"j1", &"j9"], [&"j2", &"j9"],
			[&"j9", &"tpA"], [&"j1", &"jw"], [&"jw", &"rW"], [&"j2", &"je"], [&"je", &"rE"], [&"rW", &"aW"], [&"rE", &"aE"], [&"aW", &"A"], [&"aE", &"A"],
			[&"j1", &"G"], [&"j3", &"G"], [&"j5", &"G"], [&"j7", &"G"], [&"j2", &"S"], [&"j4", &"S"], [&"j6", &"S"], [&"j8", &"S"],
			[&"j3", &"jW"], [&"jW", &"tpP"], [&"j7", &"tpP"], [&"j4", &"W"], [&"j8", &"W"], [&"rE", &"U"], [&"j4", &"U"], [&"j2", &"U"],
			[&"j5", &"C"], [&"j6", &"C"], [&"j6", &"dL"], [&"dL", &"D"], [&"j3", &"j7"], [&"j4", &"j8"], [&"j3", &"j1"], [&"j4", &"j2"]]:
		link(pair[0], pair[1])
	#Up the podium step by step, over the curb of the pool and over the curb of the troll zone
	for pair: Array in [[&"j3", &"pS"], [&"pS", &"p2"], [&"p2", &"P"], [&"j7", &"p3"], [&"j5", &"F"], [&"j7", &"F"], [&"j3", &"Z"], [&"rW", &"Z"]]:
		link(pair[0], pair[1], HOP, 0.3)
	link(&"tpP", &"P", LAUNCH, 0.0, 1.6)
	link(&"tpA", &"A", LAUNCH, 0.0, CANNON_TIME + 0.6)
	for pair: Array in [[&"A", &"j9"], [&"aW", &"j1"], [&"aE", &"j2"], [&"P", &"jW"], [&"P", &"p3"], [&"D", &"j8"]]:
		link(pair[0], pair[1], DROP)


#The belt along the runway, which turns around now and then, the trampoline to the podium and the cannon up to the runway; the two
#treadmills of the gym, that run opposite ways; the prop boxes that sweep the runway, the selfie sticks that sweep their set, the boom
#of microphones that turns over the dance floor and the dumbbell that turns over the treadmills. Most of them are on from the first
#photo: the studio is busy from the start
func _build_tricks() -> void:
	belts.append({"a": Vector3(-7.0, UPPER, -16.0), "b": Vector3(7.0, UPPER, -16.0), "width": 3.0, "from": 0, "turns": true})
	var gym := Vector3(GYM_CENTER.x, GROUND, GYM_CENTER.y)
	for side: float in [-1.0, 1.0]:
		var lane := gym + Vector3(0.0, 0.0, side * (TREADMILL.y / 2.0 + GYM_AISLE / 2.0))
		belts.append({"a": lane - Vector3(side * TREADMILL.x / 2.0, 0.0, 0.0), "b": lane + Vector3(side * TREADMILL.x / 2.0, 0.0, 0.0),
			"width": TREADMILL.y, "from": 0, "turns": false, "speed": TREADMILL_SPEED})
	pads.append({"at": TRAMPOLINE, "from": 0})
	pads.append({"at": CANNON, "to": CANNON_TARGET, "time": CANNON_TIME, "from": 0})
	sweepers.append({"a": Vector3(-3.6, UPPER, -13.3), "b": Vector3(-3.6, UPPER, -18.7), "period": 3.4, "phase": 0.0, "from": 0})
	sweepers.append({"a": Vector3(3.6, UPPER, -18.7), "b": Vector3(3.6, UPPER, -13.3), "period": 3.0, "phase": 1.6, "from": 2})
	var sticks := Vector3(STICKS_CENTER.x, GROUND, STICKS_CENTER.y)
	sweepers.append({"a": sticks + Vector3(-4.2, 0.0, -1.7), "b": sticks + Vector3(4.2, 0.0, -1.7), "period": 2.8, "phase": 0.0, "from": 0, "stick": true})
	sweepers.append({"a": sticks + Vector3(4.2, 0.0, 1.7), "b": sticks + Vector3(-4.2, 0.0, 1.7), "period": 3.3, "phase": 1.1, "from": 0, "stick": true})
	spinners.append({"at": Vector3(DANCE_CENTER.x, GROUND, DANCE_CENTER.y), "arm": DANCE_RADIUS - 0.6, "speed": 0.8, "phase": 0.0, "from": 0, "push": 0.6})
	spinners.append({"at": gym, "arm": 4.0, "speed": -0.6, "phase": 0.6, "from": 0, "push": 0.55})


func _box_height(box: Rect2, top: float, point: Vector2) -> float:
	return top if box.has_point(point) else -INF


func _disc_height(center: Vector2, radius: float, top: float, point: Vector2) -> float:
	return top if point.distance_to(center) <= radius else -INF


#The top of the curb of the troll zone
func _curb_height(point: Vector2) -> float:
	if TROLL.has_point(point) and not TROLL.grow(-CURB_THICKNESS).has_point(point):
		return TROLL_CURB
	return -INF


#The top of the wall of the pool, where somebody can stand
func _wall_height(point: Vector2) -> float:
	var away := point.distance_to(POOL_CENTER)
	return POOL_WALL if away >= POOL_INNER and away <= POOL_OUTER else -INF


#Height of a ramp over a point: from the floor at its low end to "top" at its high end
func _slope_height(ramp: Array, point: Vector2, top := UPPER) -> float:
	var low: Vector2 = ramp[0]
	var high: Vector2 = ramp[1]
	var length := low.distance_to(high)
	var way := (high - low) / length
	var offset := point - low
	var along := offset.dot(way)
	if along < 0.0 or along > length or absf(way.cross(offset)) > float(ramp[2]) / 2.0:
		return -INF
	return lerpf(GROUND, top, along / length)
