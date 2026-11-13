class_name TrendLayout
extends ArenaLayout

#"La Plaza": a round fairground on solid ground. A plaza in the middle under the giant screen and five zones around it like the
#petals of a flower, each with its own way of making the bubbles hard to reach: a stepped tower to climb, a ramp of belts, a
#field of trampolines and pillars, a maze of low walls where the haters live, and a round stage swept by bars.
#Every zone is written in its own frame: "u" goes from the middle of the zone outward and "v" across it

enum Zone { TOWER, BELTS, BOUNCE, MAZE, BARS, PLAZA }

const CORE := &"C"
#How high over its floor a bubble floats, and the ones over a trampoline, which are only reached by bouncing
const BUBBLE_HEIGHT := 1.25
const HIGH_BUBBLE := 3.3
const ZONE_COUNT := 5
#Meters from the middle of the map to the middle of each zone, and the direction of each one (degrees from +X toward +Z)
const ZONE_RING := 26.0
const ANGLES: Array[float] = [-90.0, -18.0, 54.0, 126.0, 198.0]
const PREFIX: Array[String] = ["tw", "bl", "bo", "mz", "ba"]
const FENCE_RADIUS := 41.0
const FENCE_SIDES := 10
#The two rings of crossings between the zones
const INNER_RING := 15.0
const OUTER_RING := 31.0
#The maze: a grid of 4 by 4 cells with walls too high to jump
const CELL := 4.5
const WALL_HEIGHT := 1.8
#The heights of the three floors of the tower, which the other zones share
const MID := 1.6
const UPPER := 3.2
const TOP := 4.8

#Where a bubble can appear: {"place": id, "position": Vector3 on the floor, "zone": int, "lift": height of the bubble over it}
var points: Array[Dictionary] = []
#The cells of the maze: the only places the haters walk
var maze_places: Array[StringName] = []

var _table: Dictionary = {}


func _init() -> void:
	zone_colors = [Color("a584ff"), Color("5fdcc0"), Color("ffc24f"), Color("ff7fb2"), Color("62b7ff"), Color("fff4d6")]
	ground_color = Color("e3d8ff")
	belt_period = 8.0
	spawn_place = CORE
	for side in FENCE_SIDES:
		var angle := TAU * (side + 0.5) / FENCE_SIDES
		outline.append(Vector2(cos(angle), sin(angle)) * FENCE_RADIUS)
	_build_tower()
	_build_belts()
	_build_bounce()
	_build_maze()
	_build_bars()
	_build_plaza()
	_table = travel_table(build_graph())


#Seconds on foot from one bubble point to another: straight when they share their place, and by the cheapest route otherwise
func seconds_between(from: int, to: int) -> float:
	var a: Dictionary = points[from]
	var b: Dictionary = points[to]
	if a["place"] == b["place"]:
		return (a["position"] as Vector3).distance_to(b["position"]) / WALK_SPEED
	return _reach(a) + float(_table[a["place"]][b["place"]]) + _reach(b)


#Seconds from wherever a player stands to a bubble point
func seconds_from(spot: Vector3, to: int) -> float:
	var place := nearest_place(spot)
	var b: Dictionary = points[to]
	if place == b["place"]:
		return Vector2(spot.x - b["position"].x, spot.z - b["position"].z).length() / WALK_SPEED
	var first := Vector2(spot.x - position_of(place).x, spot.z - position_of(place).z).length() / WALK_SPEED
	return first + float(_table[place][b["place"]]) + _reach(b)


#Seconds between two places by the cheapest route
func seconds_by_route(from: StringName, to: StringName) -> float:
	return _table[from][to]


#Seconds an average walk from one bubble to the next one of a kind takes when there are "copies" bubbles of each kind alive.
#From every point it takes the walk to the closest of that many others, which is the one a share of 1 / (copies + 1) of the
#points are closer than, and averages them. The par of a trend is built from it
func expected_leg(copies: float) -> float:
	var total := 0.0
	for from in points.size():
		var times: Array[float] = []
		for to in points.size():
			if to != from:
				times.append(seconds_between(from, to))
		times.sort()
		total += times[clampi(floori(times.size() / (copies + 1.0)), 0, times.size() - 1)]
	return total / maxf(points.size(), 1.0)


#The par of a trend with "length" kinds: the seconds a good player needs. For each bubble, a share of the average walk to
#one of its kind, which is never longer than the reach within which the board keeps the kind that is needed
func par_seconds(length: int, settings: TrendSettings) -> float:
	var leg := minf(expected_leg(float(settings.bubble_target) / TrendCatalog.COUNT), settings.reach_seconds)
	return leg * settings.par_share * length


#The zone a point of the map belongs to: the one whose middle is closest, or the plaza near the middle of the map
func zone_at(spot: Vector3) -> int:
	if Vector2(spot.x, spot.z).length() < ZONE_RING - 13.0:
		return Zone.PLAZA
	var best := Zone.PLAZA
	var best_distance := INF
	for zone in ZONE_COUNT:
		var distance := Vector2(spot.x, spot.z).distance_to(_at(zone, 0.0, 0.0))
		if distance < best_distance:
			best_distance = distance
			best = zone
	return best


#A point of a zone in its own frame ("u" outward, "v" across), on the ground of the map
func zone_spot(zone: int, u: float, v: float) -> Vector3:
	return _at3(zone, u, v, GROUND)


func _reach(point: Dictionary) -> float:
	var centre := position_of(point["place"])
	return Vector2(point["position"].x - centre.x, point["position"].z - centre.z).length() / WALK_SPEED


#The way out of a zone on the ground, and the way across it
func _out(zone: int) -> Vector2:
	var angle := deg_to_rad(ANGLES[zone])
	return Vector2(cos(angle), sin(angle))


func _at(zone: int, u: float, v: float) -> Vector2:
	var out := _out(zone)
	return out * (ZONE_RING + u) + Vector2(out.y, -out.x) * v


func _at3(zone: int, u: float, v: float, y: float) -> Vector3:
	var spot := _at(zone, u, v)
	return Vector3(spot.x, y, spot.y)


#The same point on whatever floor is there
func _floor(zone: int, u: float, v: float) -> Vector3:
	var spot := _at(zone, u, v)
	return Vector3(spot.x, height_at(spot.x, spot.y), spot.y)


func _yaw(zone: int) -> float:
	var out := _out(zone)
	return atan2(out.x, out.y)


func _id(zone: int, name: String) -> StringName:
	return StringName("%s_%s" % [PREFIX[zone], name])


func _place(zone: int, name: String, u: float, v: float, radius: float) -> StringName:
	var spot := _at(zone, u, v)
	add_place(_id(zone, name), spot.x, spot.y, radius, zone)
	return _id(zone, name)


#"across" is its size along v and "deep" along u
func _block(zone: int, u: float, v: float, across: float, deep: float, top: float, bottom := GROUND) -> void:
	add_block(_at(zone, u, v), Vector2(across, deep), top, zone, _yaw(zone), bottom)


func _ramp(zone: int, u0: float, v0: float, y0: float, u1: float, v1: float, y1: float, width: float, steps := false) -> void:
	add_ramp(_at3(zone, u0, v0, y0), _at3(zone, u1, v1, y1), width, zone, steps)


func _drum(zone: int, u: float, v: float, radius: float, top: float, bottom := GROUND) -> void:
	add_drum(_at(zone, u, v), radius, top, zone, bottom)


func _point(place: StringName, zone: int, u: float, v: float, lift := BUBBLE_HEIGHT) -> void:
	points.append({"place": place, "position": _floor(zone, u, v), "zone": zone, "lift": lift})


#A point of the two rings: "ring" meters from the middle, between zone "index" and the next one
func _between(index: int, ring: float) -> Vector2:
	var angle := deg_to_rad(ANGLES[index] + 36.0)
	return Vector2(cos(angle), sin(angle)) * ring


#The tower: three square floors, each smaller than the one under it. A ramp climbs each floor and the three make a spiral;
#on the other face a row of drums goes straight up for whoever jumps well
func _build_tower() -> void:
	var zone := Zone.TOWER
	_block(zone, 0.0, 0.0, 16.0, 16.0, MID)
	_block(zone, 0.0, 0.0, 10.0, 10.0, UPPER, MID)
	_block(zone, 0.0, 0.0, 5.0, 5.0, TOP, UPPER)
	_ramp(zone, -13.5, 0.0, GROUND, -8.0, 0.0, MID, 4.0)
	_ramp(zone, -5.5, 6.5, MID, 0.5, 6.5, UPPER, 3.0, true)
	_block(zone, 2.75, 6.5, 3.0, 4.5, UPPER, MID)
	_ramp(zone, 3.75, 5.0, UPPER, 3.75, 0.5, TOP, 2.5, true)
	_block(zone, 3.75, -0.75, 2.5, 2.5, TOP, UPPER)
	_drum(zone, -3.0, -9.6, 1.3, 0.8)
	_drum(zone, 0.0, -6.3, 1.2, 2.4, MID)
	_drum(zone, -1.5, -3.6, 1.0, 4.0, UPPER)
	var gate := _place(zone, "in", -15.5, 0.0, 2.2)
	var first := _place(zone, "1", -6.5, 0.0, 1.4)
	var corner := _place(zone, "1n", -6.5, 6.5, 1.4)
	var landing := _place(zone, "l2", 2.75, 6.5, 1.3)
	var second := _place(zone, "2n", 1.25, 3.75, 1.1)
	var second_corner := _place(zone, "2c", -3.75, 3.75, 1.2)
	var second_west := _place(zone, "2w", -3.75, 0.0, 1.2)
	var last_landing := _place(zone, "l3", 3.75, -0.75, 1.1)
	var summit := _place(zone, "3", 0.0, 0.0, 2.2)
	link(gate, first)
	link(first, corner)
	link(corner, landing)
	link(landing, second)
	link(second, second_corner)
	link(second_corner, second_west)
	link(landing, last_landing)
	link(last_landing, summit)
	#Stepping off a floor is a way down that nobody climbs
	link(summit, second_west, DROP)
	link(second_west, first, DROP)
	link(second_corner, corner, DROP)
	_point(gate, zone, -12.0, -5.0)
	_point(gate, zone, -12.0, 5.0)
	_point(first, zone, -6.5, -4.0)
	_point(corner, zone, -6.5, 6.5)
	_point(second_west, zone, -3.75, 0.0)
	_point(second_corner, zone, -3.75, 3.75)
	_point(summit, zone, 0.0, 0.0)
	_point(landing, zone, 2.75, 6.5)
	_point(last_landing, zone, 3.75, -0.75)


#The belts: one wide ramp with three belts up to a terrace. One always climbs, one always comes down and the third one turns,
#so getting up means reading which one helps; a padded block sweeps the top of the ramp in the last trends
func _build_belts() -> void:
	var zone := Zone.BELTS
	_ramp(zone, -7.0, 0.0, GROUND, 4.0, 0.0, MID, 10.5)
	_block(zone, 7.5, 0.0, 17.0, 7.0, MID)
	_drum(zone, 7.5, -10.0, 1.3, 0.8)
	_drum(zone, 7.5, 10.0, 1.3, 0.8)
	belts.append({"a": _floor(zone, -6.6, -3.5), "b": _floor(zone, 3.8, -3.5), "width": 3.2, "from": 0, "turns": false})
	belts.append({"a": _floor(zone, 3.8, 0.0), "b": _floor(zone, -6.6, 0.0), "width": 3.2, "from": 0, "turns": false})
	belts.append({"a": _floor(zone, -6.6, 3.5), "b": _floor(zone, 3.8, 3.5), "width": 3.2, "from": 0, "turns": true})
	sweepers.append({"a": _at3(zone, 6.0, -6.5, MID), "b": _at3(zone, 6.0, 6.5, MID), "period": 5.0, "phase": 0.0, "from": 3})
	var gate := _place(zone, "in", -10.5, 0.0, 2.4)
	var up := _place(zone, "la", -1.5, -3.5, 1.3)
	var down := _place(zone, "lb", -1.5, 0.0, 1.3)
	var turning := _place(zone, "lc", -1.5, 3.5, 1.3)
	var terrace := _place(zone, "top", 7.5, 0.0, 2.6)
	var left := _place(zone, "tl", 7.5, -6.0, 2.0)
	var right := _place(zone, "tr", 7.5, 6.0, 2.0)
	link(gate, up, BELT)
	link(up, terrace, BELT)
	link(terrace, down, BELT)
	link(down, gate, BELT)
	link(gate, turning)
	link(turning, terrace)
	link(terrace, left)
	link(terrace, right)
	_point(gate, zone, -10.5, -5.5)
	_point(gate, zone, -10.5, 5.5)
	_point(left, zone, 7.5, -6.0)
	_point(right, zone, 7.5, 6.0)
	_point(terrace, zone, 9.5, 0.0)
	_point(up, zone, -1.5, -3.5)
	_point(turning, zone, -1.5, 3.5)
	_point(terrace, zone, 5.5, 3.0)


#The trampolines: two tall pillars that are only reached by the cannon pads that throw onto them, and two trampolines with a
#beat under bubbles that float too high to jump
func _build_bounce() -> void:
	var zone := Zone.BOUNCE
	_drum(zone, 0.0, -4.0, 2.2, 3.0)
	_drum(zone, 3.5, 4.0, 2.2, 5.0)
	_drum(zone, -6.5, -8.0, 1.5, 0.9)
	var gate := _place(zone, "in", -11.0, 0.0, 2.4)
	var first_pad := _place(zone, "p1", -4.8, -4.0, 1.0)
	var low := _place(zone, "a", 0.0, -4.0, 1.8)
	var second_pad := _place(zone, "a2", 1.0, -2.6, 0.8)
	var high := _place(zone, "b", 3.5, 4.0, 1.8)
	var third_pad := _place(zone, "p3", 8.5, -1.0, 1.0)
	var left_pad := _place(zone, "p4", -2.5, 8.5, 1.0)
	var right_pad := _place(zone, "p5", 6.5, -6.0, 1.0)
	pads.append({"at": position_of(first_pad), "to": position_of(low), "time": 1.25, "from": 0})
	pads.append({"at": position_of(second_pad), "to": position_of(high), "time": 1.3, "from": 0})
	pads.append({"at": position_of(third_pad), "to": position_of(high), "time": 1.45, "from": 0})
	pads.append({"at": position_of(left_pad), "from": 0, "beat": {"period": 2.4, "on": 1.5, "phase": 0.0}})
	pads.append({"at": position_of(right_pad), "from": 0, "beat": {"period": 2.4, "on": 1.5, "phase": 1.2}})
	link(gate, first_pad)
	link(first_pad, low, LAUNCH, 0.0, 1.45)
	link(low, second_pad)
	link(second_pad, high, LAUNCH, 0.0, 1.5)
	link(gate, third_pad)
	link(third_pad, high, LAUNCH, 0.0, 1.65)
	link(gate, left_pad)
	link(third_pad, right_pad)
	link(low, gate, DROP)
	link(high, third_pad, DROP)
	link(high, left_pad, DROP)
	_point(low, zone, 0.0, -4.0)
	_point(high, zone, 3.5, 4.0)
	_point(left_pad, zone, -2.5, 8.5, HIGH_BUBBLE)
	_point(right_pad, zone, 6.5, -6.0, HIGH_BUBBLE)
	_point(gate, zone, -8.5, 5.0)
	_point(third_pad, zone, 10.0, 5.5)
	_point(first_pad, zone, -5.5, -6.5)
	_point(second_pad, zone, 1.0, -2.6)


#The maze: sixteen cells between walls nobody can jump. It has two mouths toward the plaza and one on each side, loops
#everywhere and no dead end. Its cells are the vertices the haters walk
func _build_maze() -> void:
	var zone := Zone.MAZE
	var half := CELL * 2.0
	var walls: Array[Array] = [
		[-half, -half, -half, -CELL], [-half, CELL, -half, half], [half, -half, half, half],
		[-half, -half, -CELL, -half], [0.0, -half, half, -half], [-half, half, 0.0, half], [CELL, half, half, half],
		[0.0, -half, 0.0, 0.0], [CELL, 0.0, CELL, CELL], [0.0, CELL, 0.0, half], [-half, 0.0, -CELL, 0.0], [0.0, 0.0, CELL, 0.0],
	]
	for wall in walls:
		add_wall(_at(zone, wall[0], wall[1]), _at(zone, wall[2], wall[3]), WALL_HEIGHT, zone)
	for i in 4:
		for j in 4:
			maze_places.append(_place(zone, "%d%d" % [i, j], -half + CELL * (i + 0.5), -half + CELL * (j + 0.5), 1.5))
	#The borders between cells that have no wall: [i, j, 1 toward the next cell along u or 0 along v]
	var open: Array[Array] = [
		[0, 0, 1], [2, 0, 1], [0, 1, 1], [2, 1, 1], [0, 2, 1], [1, 2, 1], [0, 3, 1], [2, 3, 1],
		[0, 0, 0], [0, 2, 0], [1, 0, 0], [1, 1, 0], [1, 2, 0], [2, 0, 0], [2, 2, 0], [3, 0, 0], [3, 1, 0], [3, 2, 0],
	]
	for border in open:
		var i: int = border[0]
		var j: int = border[1]
		var along: int = border[2]
		link(_id(zone, "%d%d" % [i, j]), _id(zone, "%d%d" % [i + along, j + 1 - along]))
	var gate := _place(zone, "in", -12.5, 0.0, 2.4)
	var left := _place(zone, "l", -2.25, -12.0, 2.0)
	var right := _place(zone, "r", 2.25, 12.0, 2.0)
	link(gate, _id(zone, "01"))
	link(gate, _id(zone, "02"))
	link(left, _id(zone, "10"))
	link(right, _id(zone, "23"))
	for cell: String in ["00", "03", "11", "13", "20", "22", "30", "31", "33"]:
		var id := _id(zone, cell)
		points.append({"place": id, "position": position_of(id), "zone": zone, "lift": BUBBLE_HEIGHT})


#The bars: a round stage with a ramp on three sides. A long bar sweeps it all from the second trend on and a short, faster
#one joins it later, turning the other way
func _build_bars() -> void:
	var zone := Zone.BARS
	_drum(zone, 0.0, 0.0, 8.5, MID)
	_ramp(zone, -14.0, 0.0, GROUND, -8.5, 0.0, MID, 4.5)
	_ramp(zone, 0.0, -14.0, GROUND, 0.0, -8.5, MID, 4.5)
	_ramp(zone, 0.0, 14.0, GROUND, 0.0, 8.5, MID, 4.5)
	spinners.append({"at": _at3(zone, 0.0, 0.0, MID), "arm": 7.6, "speed": 1.25, "phase": 0.3, "from": 1})
	spinners.append({"at": _at3(zone, 0.0, 0.0, MID), "arm": 4.6, "speed": -2.1, "phase": 1.4, "from": 3, "surge": {"rate": 1.0, "depth": 0.4}})
	var gate := _place(zone, "in", -16.5, 0.0, 2.2)
	var west := _place(zone, "w", -5.5, 0.0, 2.0)
	var north := _place(zone, "n", 0.0, -5.5, 2.0)
	var east := _place(zone, "e", 5.5, 0.0, 2.0)
	var south := _place(zone, "s", 0.0, 5.5, 2.0)
	var left := _place(zone, "l", 0.0, -16.0, 2.0)
	var right := _place(zone, "r", 0.0, 16.0, 2.0)
	link(gate, west)
	link(west, north)
	link(north, east)
	link(east, south)
	link(south, west)
	link(left, north)
	link(right, south)
	for id: StringName in [west, north, east, south]:
		points.append({"place": id, "position": position_of(id), "zone": zone, "lift": BUBBLE_HEIGHT})
	_point(gate, zone, -13.5, 5.5)
	_point(left, zone, 0.0, -16.0)
	_point(right, zone, 0.0, 16.0)


#The plaza: the middle of the map, an inner ring of crossings between the mouths of the zones and an outer ring behind them
func _build_plaza() -> void:
	add_place(CORE, 0.0, 0.0, 5.0, Zone.PLAZA)
	for index in ZONE_COUNT:
		var inner := _between(index, INNER_RING)
		var outer := _between(index, OUTER_RING)
		add_place(StringName("K%d" % index), inner.x, inner.y, 2.6, Zone.PLAZA)
		add_place(StringName("O%d" % index), outer.x, outer.y, 2.6, Zone.PLAZA)
	for index in ZONE_COUNT:
		var inner := StringName("K%d" % index)
		var outer := StringName("O%d" % index)
		var next := (index + 1) % ZONE_COUNT
		link(CORE, _id(index, "in"))
		link(CORE, inner)
		link(inner, outer)
		link(_id(index, "in"), inner)
		link(_id(next, "in"), inner)
		points.append({"place": outer, "position": position_of(outer), "zone": Zone.PLAZA, "lift": BUBBLE_HEIGHT})
		points.append({"place": inner, "position": position_of(inner), "zone": Zone.PLAZA, "lift": BUBBLE_HEIGHT})
	#The outer ring reaches the sides of the zones next to it
	link(&"O0", &"tw_in")
	link(&"O4", &"tw_in")
	link(&"bl_tr", &"O0", DROP)
	link(&"bl_tl", &"O1", DROP)
	link(&"O1", &"bo_p4")
	link(&"O2", &"bo_p5")
	link(&"O2", &"mz_r")
	link(&"O3", &"mz_l")
	link(&"O3", &"ba_r")
	link(&"O4", &"ba_l")
