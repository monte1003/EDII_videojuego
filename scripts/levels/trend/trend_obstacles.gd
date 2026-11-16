class_name TrendObstacles
extends RefCounted

#What moves in the zones of La Plaza, with no nodes: where each platform of the archipelago is, which screens of the maze are up and
#where the likes of the tower fall, and who is inside the glass of the gravity or in the pond. The platforms that sink keep their own
#state, set off by whoever stands on them; everything else is a function of the seconds of the round, so it can be drawn, hit and
#planned for from the time alone

enum Sink { REST, SHAKE, FALL, UNDER, RISE }
enum Light { OPEN, SHUT, WARN }

#A platform that sinks shakes for a moment after somebody steps on it, goes down under the water, waits there and comes back up
const SINK_SHAKE := 0.7
const SINK_FALL := 0.6
const SINK_UNDER := 2.6
const SINK_RISE := 0.9
const SINK_DEPTH := 1.8
#How far over a platform the feet may be to stand on it, and how low over the pond they must be to have fallen in
const ISLET_FEET := 0.3
const POND_FEET := 0.7
#The screens of the maze: seconds each group stays up, seconds it takes to go up or down, and the warning before it moves
const SCREEN_UP := 3.0
const SCREEN_MOVE := 0.5
const SCREEN_WARN := 1.0
#From how high a screen blocks the way, and how close to it a player is pushed aside while it rises
const SCREEN_BLOCKS := 0.25
const SCREEN_CLEAR := 0.35
#The likes of the tower: on each floor one falls every few seconds, a little further around than the last one. Its mark shows
#LIKE_WARN seconds before it lands, it drops in the last LIKE_FALL of them and hits for LIKE_HIT seconds after landing
const LIKE_EVERY: Array[float] = [1.5, 1.9, 2.5]
const LIKE_START: Array[float] = [0.4, 1.1, 1.8]
const LIKE_STEP: Array[int] = [3, 5, 1]
const LIKE_WARN := 1.0
const LIKE_FALL := 0.45
const LIKE_HIT := 0.2
const LIKE_GONE := 0.45
const LIKE_DROP := 8.0
const LIKE_REACH := 1.3

var layout: TrendLayout
#The state of every platform that sinks: {index: {"state": Sink, "left": seconds}}
var sinks: Dictionary = {}


func _init(plaza: TrendLayout) -> void:
	layout = plaza
	for index in layout.islets.size():
		if layout.islets[index]["kind"] == &"sink":
			sinks[index] = {"state": Sink.REST, "left": 0.0}


#Moves the platforms that sink on: one at rest starts shaking when somebody stands on it. "feet" are the points where the players stand
func tick(delta: float, time: float, feet: Array[Vector3]) -> void:
	for index: int in sinks:
		var entry: Dictionary = sinks[index]
		match int(entry["state"]):
			Sink.REST:
				for point in feet:
					if islet_holds(index, point, time):
						_sink_to(entry, Sink.SHAKE, SINK_SHAKE)
						break
			_:
				entry["left"] = float(entry["left"]) - delta
				if float(entry["left"]) <= 0.0:
					match int(entry["state"]):
						Sink.SHAKE:
							_sink_to(entry, Sink.FALL, SINK_FALL)
						Sink.FALL:
							_sink_to(entry, Sink.UNDER, SINK_UNDER)
						Sink.UNDER:
							_sink_to(entry, Sink.RISE, SINK_RISE)
						Sink.RISE:
							_sink_to(entry, Sink.REST, 0.0)


func _sink_to(entry: Dictionary, state: Sink, seconds: float) -> void:
	entry["state"] = state
	entry["left"] = seconds


#How far a platform has gone under, from 0 (at rest) to 1 (all the way down)
func sink_share(index: int) -> float:
	if not sinks.has(index):
		return 0.0
	var entry: Dictionary = sinks[index]
	match int(entry["state"]):
		Sink.FALL:
			return 1.0 - float(entry["left"]) / SINK_FALL
		Sink.UNDER:
			return 1.0
		Sink.RISE:
			return float(entry["left"]) / SINK_RISE
	return 0.0


func is_shaking(index: int) -> bool:
	return sinks.has(index) and int(sinks[index]["state"]) == Sink.SHAKE


#Where a platform is at "time": the middle of its top and how it is turned
func islet_transform(index: int, time: float) -> Transform3D:
	var islet := layout.islets[index]
	var at: Vector3 = islet["at"]
	var yaw: float = islet["yaw"]
	match islet["kind"]:
		&"slide":
			var share := 0.5 - 0.5 * cos(TAU * time / float(islet["period"]) + float(islet["phase"]))
			at = at.lerp(islet["to"], share)
		&"turn":
			yaw += float(islet["spin"]) * time
		&"sink":
			at.y -= SINK_DEPTH * sink_share(index)
	return Transform3D(Basis(Vector3.UP, yaw), at)


#Whether a point stands on the top of a platform at "time"; "margin" widens it
func islet_holds(index: int, point: Vector3, time: float, margin := 0.1) -> bool:
	var place := islet_transform(index, time)
	if absf(point.y - place.origin.y) > ISLET_FEET:
		return false
	return islet_covers(index, point, time, margin)


#Whether a point is over the top of a platform, whatever its height
func islet_covers(index: int, point: Vector3, time: float, margin := 0.0) -> bool:
	var islet := layout.islets[index]
	var place := islet_transform(index, time)
	var size: Vector2 = islet["size"]
	if islet["round"]:
		return Vector2(point.x - place.origin.x, point.z - place.origin.z).length() <= size.x + margin
	var local := place.basis.inverse() * (point - place.origin)
	return absf(local.x) <= size.x / 2.0 + margin and absf(local.z) <= size.y / 2.0 + margin


#How far apart (meters, edge to edge) two platforms are at "time"; a negative index is the dock
func islet_gap(a: int, b: int, time: float) -> float:
	var best := INF
	for point in _rim(a, time):
		for other in _rim(b, time):
			best = minf(best, Vector2(point.x - other.x, point.z - other.z).length())
	return best


#Points along the edge of a platform (or along the edge of the dock), for distances
func _rim(index: int, time: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if index < 0:
		for step in 21:
			var v := lerpf(-TrendLayout.POND_HALF.y, TrendLayout.POND_HALF.y, step / 20.0)
			points.append(layout.zone_spot(TrendLayout.Zone.ISLANDS, -TrendLayout.POND_HALF.x, v))
		return points
	var islet := layout.islets[index]
	var place := islet_transform(index, time)
	var size: Vector2 = islet["size"]
	if islet["round"]:
		for step in 24:
			var angle := TAU * step / 24.0
			points.append(place.origin + Vector3(cos(angle), 0.0, sin(angle)) * size.x)
		return points
	var half := Vector3(size.x / 2.0, 0.0, size.y / 2.0)
	for step in 8:
		var share := step / 8.0
		for corner: Array in [[Vector3(-1, 0, -1), Vector3(1, 0, -1)], [Vector3(1, 0, -1), Vector3(1, 0, 1)],
				[Vector3(1, 0, 1), Vector3(-1, 0, 1)], [Vector3(-1, 0, 1), Vector3(-1, 0, -1)]]:
			var local := ((corner[0] as Vector3) * half).lerp((corner[1] as Vector3) * half, share)
			points.append(place * local)
	return points


#Whether a player standing at this point has fallen into the pond
func in_pond(point: Vector3) -> bool:
	return point.y < POND_FEET and layout.over_pond(point, -0.2)


#Where somebody that fell into the pond comes back: the point of the dock closest to where it fell
func pond_exit(point: Vector3) -> Vector3:
	var best := layout.docks[0]
	for spot in layout.docks:
		if spot.distance_to(point) < best.distance_to(point):
			best = spot
	return best


#How far up a group of screens is at "time", from 0 (sunk in the floor) to 1 (all the way up). The two groups take turns
func screen_rise(group: int, time: float) -> float:
	var cycle := 2.0 * (SCREEN_UP + SCREEN_MOVE)
	var beat := fposmod(time + (SCREEN_UP + SCREEN_MOVE) * group, cycle)
	if beat < SCREEN_UP:
		return 1.0
	if beat < SCREEN_UP + SCREEN_MOVE:
		return 1.0 - (beat - SCREEN_UP) / SCREEN_MOVE
	if beat < cycle - SCREEN_MOVE:
		return 0.0
	return (beat - cycle + SCREEN_MOVE) / SCREEN_MOVE


#Seconds until a group of screens starts to move again
func screen_change_in(group: int, time: float) -> float:
	var cycle := 2.0 * (SCREEN_UP + SCREEN_MOVE)
	var beat := fposmod(time + (SCREEN_UP + SCREEN_MOVE) * group, cycle)
	if beat < SCREEN_UP:
		return SCREEN_UP - beat
	if beat < SCREEN_UP + SCREEN_MOVE:
		return 0.0
	if beat < cycle - SCREEN_MOVE:
		return cycle - SCREEN_MOVE - beat
	return 0.0


#The light of a group: green while it is down, red while it is up, and it blinks before it moves and while it moves
func screen_light(group: int, time: float) -> Light:
	var rise := screen_rise(group, time)
	if (rise > 0.0 and rise < 1.0) or screen_change_in(group, time) <= SCREEN_WARN:
		return Light.WARN
	return Light.SHUT if rise >= 1.0 else Light.OPEN


func screen_blocks(index: int, time: float) -> bool:
	return screen_rise(int(layout.screens[index]["group"]), time) > SCREEN_BLOCKS


#Whether the border between two cells of the maze can be crossed at "time"
func maze_open(link: Array, time: float) -> bool:
	return int(link[2]) < 0 or not screen_blocks(int(link[2]), time)


#A player standing where a screen is rising is moved out of it at once: the way out toward the closer side, or zero
func screen_nudge(point: Vector3, time: float) -> Vector3:
	return _screen_way(point, time, false)


#A player standing where a screen is about to rise is told to leave: the way out toward the closer side, or zero
func screen_warning(point: Vector3, time: float) -> Vector3:
	return _screen_way(point, time, true)


func _screen_way(point: Vector3, time: float, waking: bool) -> Vector3:
	if point.y > TrendLayout.SCREEN_HEIGHT:
		return Vector3.ZERO
	for screen in layout.screens:
		var group := int(screen["group"])
		var rise := screen_rise(group, time)
		if waking and not (rise <= 0.0 and screen_change_in(group, time) <= SCREEN_WARN * 0.6):
			continue
		if not waking and not (rise > 0.0 and rise < 1.0 and screen_rise(group, time + 0.05) > rise):
			continue
		var from: Vector3 = screen["from"]
		var to: Vector3 = screen["to"]
		var along := Vector2(to.x - from.x, to.z - from.z)
		var length := along.length()
		along /= length
		var offset := Vector2(point.x - from.x, point.z - from.z)
		var reach := offset.dot(along)
		var side := along.cross(offset)
		var room := TrendLayout.SCREEN_THICKNESS / 2.0 + SCREEN_CLEAR
		if reach < 0.0 or reach > length or absf(side) >= room:
			continue
		var normal := Vector2(-along.y, along.x) * (1.0 if side >= 0.0 else -1.0)
		var away := normal * (room - absf(side) + 0.05)
		return Vector3(away.x, 0.0, away.y)
	return Vector3.ZERO


#The likes that are falling or just landed at "time": {"at": Vector3 (where it lands), "level": int, "left": seconds until it
#lands (negative once it has)}
func likes(time: float) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for level in LIKE_EVERY.size():
		var spots: Array = layout.like_spots[level]
		var every: float = LIKE_EVERY[level]
		var first := ceili((time - LIKE_GONE - LIKE_START[level]) / every)
		var last := floori((time + LIKE_WARN - LIKE_START[level]) / every)
		for count in range(maxi(first, 0), last + 1):
			var lands := LIKE_START[level] + count * every
			found.append({"at": spots[(count * LIKE_STEP[level]) % spots.size()], "level": level, "left": lands - time})
	return found


#Where a like that lands on a player throws it: outward from the middle of the tower, or zero when no like hits this point now
func like_push(point: Vector3, time: float) -> Vector3:
	for like in likes(time):
		var left: float = like["left"]
		if left > 0.0 or left < -LIKE_HIT:
			continue
		var at: Vector3 = like["at"]
		if point.y < at.y - 0.3 or point.y > at.y + 1.5 or Vector2(point.x - at.x, point.z - at.z).length() > LIKE_REACH:
			continue
		var centre := layout.tower_center()
		var away := Vector3(point.x - centre.x, 0.0, point.z - centre.z)
		return away.normalized() if away.length() > 0.05 else Vector3.RIGHT
	return Vector3.ZERO


#Whether a point is inside the glass of the gravity zone
func in_glass(point: Vector3) -> bool:
	var centre := layout.zone_center(TrendLayout.Zone.GRAVITY)
	return Vector2(point.x - centre.x, point.z - centre.z).length() <= TrendLayout.GRAVITY_RADIUS \
		and point.y > -0.5 and point.y < TrendLayout.GRAVITY_CEILING + 0.5


#The pad a player is on: on the floor when its feet are on it, under the glass when its head is; -1 when there is none
func floor_pad_at(point: Vector3) -> int:
	if point.y > 0.35:
		return -1
	return _pad_at(layout.floor_pads, point)


func ceiling_pad_at(point: Vector3) -> int:
	if point.y + 1.0 < TrendLayout.GRAVITY_CEILING - 0.35:
		return -1
	return _pad_at(layout.ceiling_pads, point)


func _pad_at(pads: Array[Vector3], point: Vector3) -> int:
	for index in pads.size():
		if Vector2(point.x - pads[index].x, point.z - pads[index].z).length() <= TrendLayout.GRAVITY_PAD:
			return index
	return -1
