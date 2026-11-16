class_name TrendLayout
extends ArenaLayout

#"La Plaza": one big round island floating over a sea of clouds, flat and all joined: the plaza in the middle holds the giant screen,
#and around it, close and open to each other like petals, five zones with their own shape, colour and obstacle: the jump challenge (a
#bar that sweeps a round floor), airplane mode (a glass cylinder where the gravity turns over), the sea of memes (platforms over a pond),
#the locked screen (a maze of screens that rise and sink by turns) and the rain of likes (a stepped tower with trampolines). Each round
#of the game is played in one zone and its bubbles are only born on the points that zone lists. Every zone is written in its own frame:
#"u" goes from the middle of the map outward through the middle of the zone and "v" across it

enum Zone { ROLLER, GRAVITY, ISLANDS, MAZE, TOWER, PLAZA }

const CORE := &"C"
const ZONE_COUNT := 5
#Direction of each zone (degrees from +X toward +Z), how far its middle is from the middle of the map and how far the zone reaches
const ANGLES: Array[float] = [-90.0, -18.0, 54.0, 126.0, 198.0]
const DISTANCES: Array[float] = [27.0, 24.0, 33.0, 27.0, 28.0]
const SPANS: Array[float] = [12.5, 9.5, 15.0, 13.5, 13.0]
const PREFIX: Array[String] = ["ro", "gv", "ar", "mz", "tw"]
#The name of each zone, from the language of the social networks: a challenge everybody copies, the mode that makes you float, a pond of
#memes, a screen that will not unlock and the likes that rain on whoever climbs
const LABELS: Array[String] = ["RETO DEL SALTO", "MODO AVIÓN", "MAR DE MEMES", "PANTALLA BLOQUEADA", "LLUVIA DE LIKES"]
const FENCE_RADIUS := 48.0
const FENCE_SIDES := 10
#The whole map is one round island this wide; the plaza in its middle is this wide and its middle place this wide
const BASE_RADIUS := 48.0
const HUB_RADIUS := 12.0
const CORE_RADIUS := 6.0
#The carpet of each zone, in its own frame: a disc of this radius, or a box ([middle u, length along u, width across v]) for the
#sea of memes and the locked screen
const ISLAND_RADII: Array[float] = [13.0, 10.5, 0.0, 0.0, 14.0]
const ISLAND_BOXES := {2: [-4.0, 33.0, 24.0], 3: [-1.5, 22.0, 21.0]}
#How high over its floor a bubble floats
const BUBBLE_LIFT := 1.2

#The roller: a bar as long as the floor is wide that turns around a post, faster and slower by turns
const ROLLER_ARM := 10.5
const ROLLER_SPEED := 0.8
const ROLLER_SURGE := {"rate": 0.7, "depth": 0.55}
const ROLLER_POST := 0.75
#The gravity zone: a glass cylinder, the height of its glass, how weak the pull is inside and how big its pads are. The glass is on
#its own collision layer: the players stand on it but the arm of their camera goes through
const GRAVITY_RADIUS := 8.0
const GRAVITY_CEILING := 7.0
const GRAVITY_SCALE := 0.35
const GRAVITY_PAD := 1.1
const GLASS_THICKNESS := 0.3
const GLASS_BIT := 2
#The archipelago: the pond (half its depth along u and across v), the height of its platforms and dock and of the walls around it
const POND_HALF := Vector2(10.0, 8.0)
const ISLE_TOP := 1.6
const POND_WALL := 3.5
#The maze: cells, height of its walls and screens (too high to jump) and how thick they are
const CELL := 4.5
const MAZE_SIZE := 4
const SCREEN_HEIGHT := 2.2
const SCREEN_THICKNESS := 0.5
#The tower: radius and height of each of its three floors over the ground
const TOWER_RADII: Array[float] = [9.5, 6.2, 3.2]
const TOWER_TOPS: Array[float] = [2.0, 4.0, 6.0]

#One entry per zone: {"center": Vector3, "entry": StringName, "span": float}
var zones: Array[Dictionary] = []
#Where a bubble can be born: {"zone": int, "position": Vector3 (the middle of the bubble), "floor": float (the floor under it)}
var slots: Array[Dictionary] = []
#The crossings on the way from the plaza to each zone and the mouths of the zones
var common_places: Array[StringName] = []
#Gravity: the pads on the floor and under the glass
var floor_pads: Array[Vector3] = []
var ceiling_pads: Array[Vector3] = []
#Archipelago: {"kind": SINK, SLIDE or TURN, "at": Vector3 (middle of its top at rest), "round": bool, "size": Vector2 (across, deep)
#or the radius in x, "yaw", "to": Vector3 and "period", "phase" when it slides, "spin" (rad/s) when it turns}
var islets: Array[Dictionary] = []
#Where somebody that falls in the pond comes back: points along the dock
var docks: Array[Vector3] = []
#Maze: {"from": Vector3, "to": Vector3, "group": 0 or 1}, the middle of each cell, the borders that can be crossed
#([cell, cell, screen index or -1 when always open]) and the cells that open to the outside
var screens: Array[Dictionary] = []
var maze_cells: Array[Vector3] = []
var maze_links: Array[Array] = []
var maze_mouths: Array[int] = []
#Tower: where the likes fall on each floor
var like_spots: Array[Array] = []

var _table: Dictionary = {}


func _init() -> void:
	zone_colors = [Color("ff8a5c"), Color("62b7ff"), Color("5fdcc0"), Color("ff7fb2"), Color("a584ff"), Color("fff4d6")]
	ground_color = Color("e3d8ff")
	spawn_place = CORE
	for side in FENCE_SIDES:
		var angle := TAU * (side + 0.5) / FENCE_SIDES
		outline.append(Vector2(cos(angle), sin(angle)) * FENCE_RADIUS)
	for zone in ZONE_COUNT:
		zones.append({"center": _at3(zone, 0.0, 0.0, GROUND), "entry": &"", "span": SPANS[zone]})
	_build_roller()
	_build_gravity()
	_build_islands()
	_build_maze()
	_build_tower()
	_build_base()
	_build_plaza()
	_table = travel_table(build_graph())


#The order in which the five trends use the zones: each zone once, shuffled by the seed
static func draw_zones(seed_value: int) -> Array[int]:
	var picker := RandomNumberGenerator.new()
	picker.seed = seed_value
	var order: Array[int] = []
	for zone in ZONE_COUNT:
		order.append(zone)
	for index in range(order.size() - 1, 0, -1):
		var other := picker.randi() % (index + 1)
		var kept := order[index]
		order[index] = order[other]
		order[other] = kept
	return order


func zone_center(zone: int) -> Vector3:
	return zones[zone]["center"]


func zone_entry(zone: int) -> StringName:
	return zones[zone]["entry"]


#Whether a point of the ground belongs to a zone, "margin" meters inside its edge
func in_zone(zone: int, point: Vector3, margin := 0.0) -> bool:
	var centre := zone_center(zone)
	return Vector2(point.x - centre.x, point.z - centre.z).length() <= float(SPANS[zone]) - margin


#The zone a point belongs to, or the plaza when it is in none
func zone_at(point: Vector3) -> int:
	for zone in ZONE_COUNT:
		if in_zone(zone, point):
			return zone
	return Zone.PLAZA


#The points of a zone where its bubbles are born
func zone_slots(zone: int) -> Array[int]:
	var found: Array[int] = []
	for index in slots.size():
		if int(slots[index]["zone"]) == zone:
			found.append(index)
	return found


#A point of a zone in its own frame, on the ground of the map
func zone_spot(zone: int, u: float, v: float) -> Vector3:
	return _at3(zone, u, v, GROUND)


#How far the frame of a zone is turned around the vertical
func zone_yaw(zone: int) -> float:
	return _yaw(zone)


#A point of the map in the frame of a zone: (u, v)
func to_zone(zone: int, point: Vector3) -> Vector2:
	var centre := zone_center(zone)
	var offset := Vector2(point.x - centre.x, point.z - centre.z)
	var out := _out(zone)
	return Vector2(offset.dot(out), offset.dot(Vector2(out.y, -out.x)))


#The middle of the tower, and the floor of the tower a point stands on: 0 for the ground, then 1 to 3
func tower_center() -> Vector3:
	return zone_center(Zone.TOWER)


func tower_level(point: Vector3) -> int:
	var centre := tower_center()
	var flat := Vector2(point.x - centre.x, point.z - centre.z).length()
	var level := 0
	for index in TOWER_TOPS.size():
		if flat <= TOWER_RADII[index] + 0.2 and point.y > TOWER_TOPS[index] - 0.6:
			level = index + 1
	return level


#Where the play of a zone starts: its mouth, or the dock of the archipelago, which is up a ramp from it
func zone_start(zone: int) -> StringName:
	return &"ar_dock" if zone == Zone.ISLANDS else zone_entry(zone)


#Seconds on foot from the middle of the plaza to where the play of a zone starts, by the routes of the map
func approach_seconds(zone: int) -> float:
	return _table[CORE][zone_start(zone)]


func seconds_by_route(from: StringName, to: StringName) -> float:
	return _table[from][to]


#Where an item knocked out of a player stays floating: a little over the floor, and under the glass inside the gravity zone
func float_height(point: Vector3) -> float:
	var centre := zone_center(Zone.GRAVITY)
	if Vector2(point.x - centre.x, point.z - centre.z).length() <= GRAVITY_RADIUS:
		return clampf(point.y + 0.5, 1.0, GRAVITY_CEILING - 1.0)
	return point.y + BUBBLE_LIFT


#Everything a check from outside needs to measure the map without nodes. A piece is {"id", "top"} and one of "rect" {"center":
#Vector2, "size": Vector2, "yaw": degrees}, where a point is on it when (point - center).rotated(yaw) is within half its size, "disc"
#{"center", "radius"} or "poly" (the corners). "floors" holds every floor (the platforms that move once per moment, with "time"; the
#ones that sink with the seconds they hold, "holds"); "walls" what cannot be crossed, the screens of the maze with their group.
#"links" holds the trampolines (where, where to, the push and its seconds), the ramps (slope in degrees, width and length), the pads
#of the gravity and the way back from the pond. Then the plaza, every zone, every bubble and the volume of the gravity
func describe() -> Dictionary:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var obstacles := TrendObstacles.new(self)
	var floors: Array[Dictionary] = []
	for index in islands.size():
		floors.append({"id": "island_%d" % index, "top": islands[index]["top"], "poly": islands[index]["outline"]})
	for index in bridges.size():
		var bridge := bridges[index]
		var from: Vector3 = bridge["from"]
		var to: Vector3 = bridge["to"]
		floors.append({"id": "bridge_%d" % index, "top": from.y, "rect": {"center": Vector2((from.x + to.x) / 2.0, (from.z + to.z) / 2.0),
			"size": Vector2(bridge["width"], Vector2(to.x - from.x, to.z - from.z).length()), "yaw": rad_to_deg(atan2(to.x - from.x, to.z - from.z))}})
	var walls: Array[Dictionary] = []
	for index in blocks.size():
		var block := blocks[index]
		var piece := {"id": "block_%d" % index, "top": block["top"], "rect": {"center": block["center"], "size": block["size"], "yaw": rad_to_deg(block["yaw"])}}
		if block["wall"]:
			walls.append(piece)
		else:
			floors.append(piece)
	for index in drums.size():
		floors.append({"id": "drum_%d" % index, "top": drums[index]["top"], "disc": {"center": drums[index]["center"], "radius": drums[index]["radius"]}})
	for index in islets.size():
		var islet := islets[index]
		var cycle := 0.0
		match islet["kind"]:
			&"slide":
				cycle = float(islet["period"])
			&"turn":
				cycle = TAU / absf(float(islet["spin"]))
		for step in (8 if cycle > 0.0 else 1):
			var time := cycle * step / 8.0
			var place := obstacles.islet_transform(index, time)
			var piece := {"id": "islet_%d" % index, "kind": islet["kind"], "top": place.origin.y, "time": time}
			var size: Vector2 = islet["size"]
			if islet["round"]:
				piece["disc"] = {"center": Vector2(place.origin.x, place.origin.z), "radius": size.x}
			else:
				piece["rect"] = {"center": Vector2(place.origin.x, place.origin.z), "size": size, "yaw": rad_to_deg(place.basis.get_euler().y)}
			if islet["kind"] == &"sink":
				piece["holds"] = TrendObstacles.SINK_SHAKE
			floors.append(piece)
	for index in screens.size():
		var from: Vector3 = screens[index]["from"]
		var to: Vector3 = screens[index]["to"]
		walls.append({"id": "screen_%d" % index, "top": SCREEN_HEIGHT, "group": screens[index]["group"], "rect": {"center": Vector2(from.x + to.x, from.z + to.z) / 2.0,
			"size": Vector2(SCREEN_THICKNESS, from.distance_to(to) - SCREEN_THICKNESS), "yaw": rad_to_deg(atan2(to.x - from.x, to.z - from.z))}})
	var links_out: Array[Dictionary] = []
	for pad in pads:
		links_out.append({"kind": "trampoline", "at": pad["at"], "to": pad["to"], "impulse": ArenaHazards.pad_launch(pad, gravity), "seconds": pad["time"]})
	for ramp in ramps:
		var from: Vector3 = ramp["from"]
		var to: Vector3 = ramp["to"]
		var run := Vector2(to.x - from.x, to.z - from.z).length()
		links_out.append({"kind": "ramp", "from": from, "to": to, "width": ramp["width"], "slope": rad_to_deg(atan2(to.y - from.y, run)), "length": run})
	for pad in floor_pads:
		links_out.append({"kind": "gravity_pad", "side": "floor", "at": pad, "radius": GRAVITY_PAD})
	for pad in ceiling_pads:
		links_out.append({"kind": "gravity_pad", "side": "ceiling", "at": pad, "radius": GRAVITY_PAD})
	var pond_center := zone_center(Zone.ISLANDS)
	var dock_piece := ""
	for index in blocks.size():
		if not blocks[index]["wall"] and _in_block(blocks[index], Vector2(docks[0].x, docks[0].z)) and is_equal_approx(float(blocks[index]["top"]), ISLE_TOP):
			dock_piece = "block_%d" % index
	links_out.append({"kind": "comeback", "zone": Zone.ISLANDS, "from": {"rect": {"center": Vector2(pond_center.x, pond_center.z),
		"size": Vector2(POND_HALF.y, POND_HALF.x) * 2.0, "yaw": rad_to_deg(_yaw(Zone.ISLANDS))}, "below": TrendObstacles.POND_FEET}, "to": docks, "piece": dock_piece})
	var zone_list: Array[Dictionary] = []
	for zone in ZONE_COUNT:
		var tops: Array[float] = []
		for slot in slots:
			if int(slot["zone"]) == zone and not tops.has(float(slot["floor"])):
				tops.append(float(slot["floor"]))
		var centre := zone_center(zone)
		zone_list.append({"id": zone, "label": LABELS[zone], "center": centre, "span": SPANS[zone], "disc": {"center": Vector2(centre.x, centre.z), "radius": SPANS[zone]},
			"entry": position_of(zone_entry(zone)), "start": position_of(zone_start(zone)), "tops": tops})
	var bubbles: Array[Dictionary] = []
	for slot in slots:
		bubbles.append({"zone": slot["zone"], "position": slot["position"]})
	return {"floors": floors, "walls": walls, "links": links_out,
		"plaza": {"center": position_of(CORE), "radius": CORE_RADIUS, "spawn_radius": CORE_RADIUS * 0.62},
		"zones": zone_list, "bubbles": bubbles,
		"gravity": {"center": zone_center(Zone.GRAVITY), "radius": GRAVITY_RADIUS, "floor": GROUND, "ceiling": GRAVITY_CEILING, "scale": GRAVITY_SCALE},
		"roller": {"center": zone_center(Zone.ROLLER), "arm": ROLLER_ARM, "bar_height": Level01Hazards.BAR_HEIGHT, "reach": Level01Hazards.BAR_REACH}}


#The way out of a zone on the ground, and the way across it
func _out(zone: int) -> Vector2:
	var angle := deg_to_rad(ANGLES[zone])
	return Vector2(cos(angle), sin(angle))


func _at(zone: int, u: float, v: float) -> Vector2:
	var out := _out(zone)
	return out * (DISTANCES[zone] + u) + Vector2(out.y, -out.x) * v


func _at3(zone: int, u: float, v: float, y: float) -> Vector3:
	var spot := _at(zone, u, v)
	return Vector3(spot.x, y, spot.y)


#A point at "radius" from the middle of a zone, "degrees" from its u axis toward its v axis
func _polar(zone: int, radius: float, degrees: float, y: float) -> Vector3:
	var angle := deg_to_rad(degrees)
	return _at3(zone, radius * cos(angle), radius * sin(angle), y)


func _yaw(zone: int) -> float:
	var out := _out(zone)
	return atan2(out.x, out.y)


func _id(zone: int, name: String) -> StringName:
	return StringName("%s_%s" % [PREFIX[zone], name])


func _place_at(zone: int, name: String, spot: Vector3, radius: float) -> StringName:
	add_place(_id(zone, name), spot.x, spot.z, radius, zone)
	return _id(zone, name)


func _block(zone: int, u: float, v: float, across: float, deep: float, top: float, bottom := GROUND) -> void:
	add_block(_at(zone, u, v), Vector2(across, deep), top, zone, _yaw(zone), bottom)


func _slot(zone: int, spot: Vector3, floor_height: float) -> void:
	slots.append({"zone": zone, "position": spot, "floor": floor_height})


#The mouth of a zone: the place on the ground where it is entered from the ring
func _entry(zone: int, u: float) -> StringName:
	var gate := _place_at(zone, "in", _at3(zone, u, 0.0, GROUND), 2.4)
	zones[zone]["entry"] = gate
	return gate


#The roller: a round floor with a post in the middle and a long bar that sweeps it all, faster and slower by turns. The bubbles wait
#on the inner rings, where the bar is slowest
func _build_roller() -> void:
	var zone := Zone.ROLLER
	var centre := zone_center(zone)
	add_drum(Vector2(centre.x, centre.z), ROLLER_POST, 1.2, zone)
	spinners.append({"at": centre, "arm": ROLLER_ARM, "speed": ROLLER_SPEED, "phase": 0.0, "from": 0, "surge": ROLLER_SURGE})
	_entry(zone, -13.5)
	for step in 4:
		_slot(zone, _polar(zone, 3.2, 45.0 + 90.0 * step, BUBBLE_LIFT), GROUND)
	for step in 5:
		_slot(zone, _polar(zone, 6.0, 72.0 * step, BUBBLE_LIFT), GROUND)
	for degrees: float in [108.0, 252.0]:
		_slot(zone, _polar(zone, 8.5, degrees, BUBBLE_LIFT), GROUND)
	for degrees: float in [100.0, 220.0, 340.0]:
		_slot(zone, _polar(zone, 4.6, degrees, BUBBLE_LIFT), GROUND)


#The gravity zone: a cylinder of glass. Its floor and the underside of its glass hold pads; a pad turns the pull over and throws the
#player to the other side. The middle pads are one over the other, so a player can bounce up and down without stopping
func _build_gravity() -> void:
	var zone := Zone.GRAVITY
	_entry(zone, -10.5)
	floor_pads.append(_polar(zone, 0.0, 0.0, GROUND))
	ceiling_pads.append(_polar(zone, 0.0, 0.0, GRAVITY_CEILING))
	for step in 3:
		floor_pads.append(_polar(zone, 4.6, 60.0 + 120.0 * step, GROUND))
		ceiling_pads.append(_polar(zone, 4.6, 120.0 * step, GRAVITY_CEILING))
	#Near the column of the middle pads, over the outer floor pads, along the glass and low enough for a jump from the floor
	_slot(zone, _polar(zone, 1.8, 90.0, 3.6), GROUND)
	_slot(zone, _polar(zone, 1.8, 270.0, 5.2), GROUND)
	for step in 3:
		_slot(zone, _polar(zone, 3.2, 60.0 + 120.0 * step, 4.5), GROUND)
		_slot(zone, _polar(zone, 6.4, 120.0 * step, GRAVITY_CEILING - 0.7), GROUND)
	for degrees: float in [30.0, 90.0, 210.0, 270.0]:
		_slot(zone, _polar(zone, 6.4, degrees, 2.7), GROUND)
	for degrees: float in [0.0, 120.0]:
		_slot(zone, _polar(zone, 3.2, degrees, 3.8), GROUND)


#The archipelago: a dock at the height of the platforms, a pond walled on the other three sides and three lanes of platforms over it.
#One lane sinks under whoever steps on it, one slides back and forth and turns, and one turns
func _build_islands() -> void:
	var zone := Zone.ISLANDS
	var gate := _entry(zone, -20.5)
	_block(zone, -12.0, 0.0, 20.0, 4.0, ISLE_TOP)
	add_ramp(_at3(zone, -19.0, 0.0, GROUND), _at3(zone, -14.0, 0.0, ISLE_TOP), 5.0, zone)
	_block(zone, 1.0, -9.0, 2.0, 22.0, POND_WALL)
	_block(zone, 1.0, 9.0, 2.0, 22.0, POND_WALL)
	_block(zone, 11.0, 0.0, 16.0, 2.0, POND_WALL)
	var dock := _place_at(zone, "dock", _at3(zone, -12.0, 0.0, ISLE_TOP), 2.0)
	link(gate, dock)
	for v: float in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		docks.append(_at3(zone, -11.2, v, ISLE_TOP))
	var lane := 4.8
	for u: float in [-6.5, -1.5, 3.5, 8.0]:
		_islet(zone, {"kind": &"sink", "at": _at3(zone, u, -lane, ISLE_TOP), "round": true, "size": Vector2(1.7, 1.7)})
	_islet(zone, {"kind": &"slide", "at": _at3(zone, -7.0, 0.0, ISLE_TOP), "to": _at3(zone, -4.0, 0.0, ISLE_TOP), "round": false,
		"size": Vector2(3.4, 3.4), "period": 5.0, "phase": 0.0})
	_islet(zone, {"kind": &"turn", "at": _at3(zone, 1.0, 0.0, ISLE_TOP), "round": false, "size": Vector2(2.0, 5.4), "spin": 0.65})
	_islet(zone, {"kind": &"slide", "at": _at3(zone, 5.8, 0.0, ISLE_TOP), "to": _at3(zone, 8.2, 0.0, ISLE_TOP), "round": false,
		"size": Vector2(3.4, 3.4), "period": 4.4, "phase": 1.3})
	_islet(zone, {"kind": &"turn", "at": _at3(zone, -5.5, lane, ISLE_TOP), "round": false, "size": Vector2(2.0, 5.4), "spin": -0.6})
	_islet(zone, {"kind": &"sink", "at": _at3(zone, 0.5, lane, ISLE_TOP), "round": true, "size": Vector2(1.7, 1.7)})
	_islet(zone, {"kind": &"turn", "at": _at3(zone, 6.0, lane, ISLE_TOP), "round": false, "size": Vector2(2.0, 5.4), "spin": 0.7})
	#A bubble over every platform: over the middle of the way of the ones that slide, so the platform passes under it
	for islet in islets:
		var at: Vector3 = islet["at"]
		if islet["kind"] == &"slide":
			at = (at + (islet["to"] as Vector3)) / 2.0
		_slot(zone, at + Vector3(0.0, BUBBLE_LIFT, 0.0), ISLE_TOP)
	#And between the platforms that sink, reached from the edge of either
	for u: float in [-4.0, 1.0, 5.75]:
		_slot(zone, _at3(zone, u, -lane, ISLE_TOP + 1.4), ISLE_TOP)


func _islet(zone: int, islet: Dictionary) -> void:
	islet["yaw"] = _yaw(zone)
	if not islet.has("phase"):
		islet["phase"] = 0.0
	islets.append(islet)


#The pond in the frame of its zone: whether a point is over it
func over_pond(point: Vector3, margin := 0.0) -> bool:
	var local := to_zone(Zone.ISLANDS, point)
	return absf(local.x) <= POND_HALF.x - margin and absf(local.y) <= POND_HALF.y - margin


#The maze: 4 by 4 cells with walls too high to jump. Some borders are always open, some always shut, and the screens of two groups
#take turns: while one group is up the other is down. With either group up every cell can be reached from the two mouths
func _build_maze() -> void:
	var zone := Zone.MAZE
	var half := CELL * MAZE_SIZE / 2.0
	_entry(zone, -half - 2.5)
	#Kind of each inner border: "o" open, "w" wall, "a" and "b" the two groups of screens. Along u: [i, j] is the border between
	#cell (i, j) and (i + 1, j); across: between (i, j) and (i, j + 1)
	var along: Array[String] = ["a", "o", "w", "b", "w", "b", "a", "o", "o", "w", "b", "a"]
	var across: Array[String] = ["o", "w", "o", "b", "o", "a", "a", "o", "b", "o", "o", "o"]
	for i in MAZE_SIZE:
		for j in MAZE_SIZE:
			maze_cells.append(_at3(zone, -half + CELL * (i + 0.5), -half + CELL * (j + 0.5), GROUND))
	for i in MAZE_SIZE - 1:
		for j in MAZE_SIZE:
			var u := -half + CELL * (i + 1)
			_border(zone, along[i * MAZE_SIZE + j], i * MAZE_SIZE + j, (i + 1) * MAZE_SIZE + j,
				Vector2(u, -half + CELL * j), Vector2(u, -half + CELL * (j + 1)))
	for i in MAZE_SIZE:
		for j in MAZE_SIZE - 1:
			var v := -half + CELL * (j + 1)
			_border(zone, across[i * (MAZE_SIZE - 1) + j], i * MAZE_SIZE + j, i * MAZE_SIZE + j + 1,
				Vector2(-half + CELL * i, v), Vector2(-half + CELL * (i + 1), v))
	#The outer walls, with the two mouths in the middle of the front
	for j in MAZE_SIZE:
		if j == 1 or j == 2:
			maze_mouths.append(j)
		else:
			_wall(zone, Vector2(-half, -half + CELL * j), Vector2(-half, -half + CELL * (j + 1)))
	_wall(zone, Vector2(half, -half), Vector2(half, half))
	_wall(zone, Vector2(-half, -half), Vector2(half, -half))
	_wall(zone, Vector2(-half, half), Vector2(half, half))
	#A post at every inner corner, so the screens fit between them
	for i in range(1, MAZE_SIZE):
		for j in range(1, MAZE_SIZE):
			_block(zone, -half + CELL * i, -half + CELL * j, SCREEN_THICKNESS, SCREEN_THICKNESS, SCREEN_HEIGHT)
	for cell: Array in [[0, 0], [1, 0], [0, 3], [1, 1], [1, 2], [1, 3], [2, 0], [2, 1], [2, 2], [2, 3], [3, 0], [3, 1], [3, 2], [3, 3]]:
		_slot(zone, maze_cells[int(cell[0]) * MAZE_SIZE + int(cell[1])] + Vector3(0.0, BUBBLE_LIFT, 0.0), GROUND)


func _border(zone: int, kind: String, a: int, b: int, from: Vector2, to: Vector2) -> void:
	match kind:
		"o":
			maze_links.append([a, b, -1])
		"w":
			_wall(zone, from, to)
		_:
			maze_links.append([a, b, screens.size()])
			screens.append({"from": _at3(zone, from.x, from.y, GROUND), "to": _at3(zone, to.x, to.y, GROUND), "group": 0 if kind == "a" else 1})


func _wall(zone: int, from: Vector2, to: Vector2) -> void:
	add_wall(_at(zone, from.x, from.y), _at(zone, to.x, to.y), SCREEN_HEIGHT, zone, SCREEN_THICKNESS)


#The tower: three round floors, each smaller and higher than the one under it. A trampoline on each floor throws onto the next one;
#stepping off a floor drops to the one under it. Likes fall from above on every floor
func _build_tower() -> void:
	var zone := Zone.TOWER
	var centre := tower_center()
	for index in TOWER_TOPS.size():
		add_drum(Vector2(centre.x, centre.z), TOWER_RADII[index], TOWER_TOPS[index], zone)
	var gate := _entry(zone, -14.5)
	#The ground around it, a ring of each floor and the top
	var ground_ring: Dictionary = {}
	for degrees: float in [0.0, 45.0, 90.0, 135.0, 225.0, 270.0, 315.0]:
		ground_ring[degrees] = _place_at(zone, "g%d" % degrees, _polar(zone, 12.0, degrees, GROUND), 1.4)
	var rings: Array[Dictionary] = [{}, {}]
	var ring_radii: Array[float] = [7.4, 4.4]
	for level in 2:
		for step in 8:
			var degrees := 45.0 * step
			rings[level][degrees] = _place_at(zone, "%d_%d" % [level + 1, degrees], _polar(zone, ring_radii[level], degrees, TOWER_TOPS[level]), 1.2)
	var top := _place_at(zone, "top", _polar(zone, 0.0, 0.0, TOWER_TOPS[2]), 2.4)
	#The ground: around both sides from the mouth, with the trampoline right in front of it
	var order: Array[float] = [135.0, 90.0, 45.0, 0.0, 315.0, 270.0, 225.0]
	link(gate, ground_ring[135.0])
	link(gate, ground_ring[225.0])
	for index in order.size() - 1:
		link(ground_ring[order[index]], ground_ring[order[index + 1]])
	var first := _place_at(zone, "p0", _polar(zone, 12.2, 180.0, GROUND), 0.9)
	link(gate, first)
	_pad(first, _polar(zone, 7.4, 180.0, TOWER_TOPS[0]), rings[0][180.0], 1.1)
	#A second one behind the tower, past the ground ring, for whoever fell on that side
	var back := _place_at(zone, "p0b", _polar(zone, 13.2, 0.0, GROUND), 0.9)
	link(ground_ring[0.0], back)
	_pad(back, _polar(zone, 7.4, 0.0, TOWER_TOPS[0]), rings[0][0.0], 1.25)
	for level in 2:
		for step in 8:
			var degrees := 45.0 * step
			link(rings[level][degrees], rings[level][fposmod(degrees + 45.0, 360.0)])
			#Stepping off a floor
			if level == 0 and ground_ring.has(degrees):
				link(rings[level][degrees], ground_ring[degrees], DROP)
			elif level == 1:
				link(rings[level][degrees], rings[0][degrees], DROP)
	for degrees: float in [0.0, 90.0, 180.0, 270.0]:
		link(top, rings[1][degrees], DROP)
	#Two trampolines on each upper floor, on its outer edge, a short walk from where the one under it lands: a spiral up the front
	for degrees: float in [140.0, 220.0]:
		var pad := _place_at(zone, "p1_%d" % degrees, _polar(zone, 8.75, degrees, TOWER_TOPS[0]), 0.9)
		link(rings[0][135.0 if degrees < 180.0 else 225.0], pad)
		_pad(pad, _polar(zone, 4.4, degrees, TOWER_TOPS[1]), rings[1][135.0 if degrees < 180.0 else 225.0], 1.1)
	for degrees: float in [100.0, 260.0]:
		var pad := _place_at(zone, "p2_%d" % degrees, _polar(zone, 5.6, degrees, TOWER_TOPS[1]), 0.9)
		link(rings[1][90.0 if degrees < 180.0 else 270.0], pad)
		_pad(pad, _polar(zone, 1.2, degrees, TOWER_TOPS[2]), top, 1.1)
	#The likes fall on each floor in turn, around it
	like_spots = [[], [], []]
	for step in 8:
		like_spots[0].append(_polar(zone, 7.9, 22.5 + 45.0 * step, TOWER_TOPS[0]))
	for step in 6:
		like_spots[1].append(_polar(zone, 4.7, 60.0 * step, TOWER_TOPS[1]))
	for step in 3:
		like_spots[2].append(_polar(zone, 1.6, 30.0 + 120.0 * step, TOWER_TOPS[2]))
	for degrees: float in [40.0, 110.0, 250.0, 320.0]:
		_slot(zone, _polar(zone, 11.4, degrees, BUBBLE_LIFT), GROUND)
	for degrees: float in [20.0, 60.0, 115.0, 245.0, 300.0, 340.0]:
		_slot(zone, _polar(zone, 7.9, degrees, TOWER_TOPS[0] + BUBBLE_LIFT), TOWER_TOPS[0])
	for degrees: float in [60.0, 180.0, 300.0]:
		_slot(zone, _polar(zone, 4.8, degrees, TOWER_TOPS[1] + BUBBLE_LIFT), TOWER_TOPS[1])
	_slot(zone, _polar(zone, 0.0, 0.0, TOWER_TOPS[2] + BUBBLE_LIFT), TOWER_TOPS[2])


#A trampoline that throws along an arc onto the floor above, in "seconds" of flight
func _pad(place: StringName, to: Vector3, landing: StringName, seconds: float) -> void:
	pads.append({"at": position_of(place), "to": to, "time": seconds, "from": 0})
	link(place, landing, LAUNCH, 0.0, seconds + 0.3)


#The map is one island: the plaza and the five zones stand on the same floor, with no void between them
func _build_base() -> void:
	add_island(CandyTerrain.circle(Vector2.ZERO, BASE_RADIUS, 96), GROUND, Zone.PLAZA, Color("ff8fc7"))


#The outline of the carpet of a zone on the ground: the floor where its play is, drawn in its colour
func zone_outline(zone: int) -> PackedVector2Array:
	var shape := PackedVector2Array()
	if ISLAND_BOXES.has(zone):
		var box: Array = ISLAND_BOXES[zone]
		for corner in CandyTerrain.rounded_box(Vector2(float(box[0]), 0.0), Vector2(float(box[1]), float(box[2])), 4.5, 0.0, 6):
			shape.append(_at(zone, corner.x, corner.y))
		return shape
	var center := zone_center(zone)
	return CandyTerrain.circle(Vector2(center.x, center.z), ISLAND_RADII[zone], 56)


#The plaza: the middle of the map and a crossing on the way from it to the mouth of each zone
func _build_plaza() -> void:
	add_place(CORE, 0.0, 0.0, CORE_RADIUS, Zone.PLAZA)
	for zone in ZONE_COUNT:
		var gate := position_of(zone_entry(zone))
		var spot := (_out(zone) * CORE_RADIUS).lerp(Vector2(gate.x, gate.z), 0.5)
		add_place(StringName("K%d" % zone), spot.x, spot.y, 2.0, Zone.PLAZA)
		common_places.append(StringName("K%d" % zone))
		common_places.append(zone_entry(zone))
	for zone in ZONE_COUNT:
		var crossing := StringName("K%d" % zone)
		link(CORE, crossing)
		link(crossing, zone_entry(zone))
