class_name Level01Traps
extends RefCounted

#The new obstacles of level 1 with no nodes, all from the clock of the round: where each axe swings, where each like punches, where each
#scroll wheel and each giant ball rolls, when each fan blows, and who they hit. The racer is a capsule as wide as BODY_RADIUS

const BODY_RADIUS := 0.3
#Heights over the feet at which the body is tested against what hits it
const BODY_SAMPLES: Array[float] = [0.15, 0.5, 0.85]
#A scroll wheel is cleared when the feet are this much under its top
const ROLLER_CLEAR := 0.1
#Every kind of thing the trap tests may report
enum Kind { NONE, AXE, PUNCH, ROLLER, BOULDER }


#The walkable part of the bridge between the two vertices of "edge": where it starts and ends along it, the way along it and across it
static func bridge_frame(edge: Array) -> Dictionary:
	var from: Vector3 = Level01Layout.POSITIONS[edge[0]]
	var to: Vector3 = Level01Layout.POSITIONS[edge[1]]
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var along := flat.normalized()
	return {
		"from": from, "along": along, "across": Vector3(-along.z, 0.0, along.x),
		"start": Level01Layout.radius_of(edge[0]), "end": flat.length() - Level01Layout.radius_of(edge[1]),
		"width": Level01Layout.width_of(Level01Layout.kind_of(edge[0], edge[1])), "floor": from.y,
	}


#A point of a bridge: "along" meters from the middle of its first vertex and "across" meters to the side, on its floor
static func bridge_point(frame: Dictionary, along: float, across: float) -> Vector3:
	var at: Vector3 = (frame["from"] as Vector3) + (frame["along"] as Vector3) * along + (frame["across"] as Vector3) * across
	at.y = frame["floor"]
	return at


#Where the axes of a row hang: the point of the floor under each pivot, from the first vertex of its bridge to the second
static func axe_spots(row: Dictionary) -> Array[Vector3]:
	var frame := bridge_frame(row["edge"])
	var count := int(row["count"])
	var found: Array[Vector3] = []
	for index in count:
		found.append(bridge_point(frame, lerpf(float(frame["start"]), float(frame["end"]), (index + 0.5) / count), 0.0))
	return found


#How far an axe of the row has swung (radians, positive toward the "across" of its bridge) at "time"; each one lags behind the one before it
static func axe_angle(row: Dictionary, index: int, time: float) -> float:
	var moment := time + float(row["phase"]) - index * float(row["lag"])
	return Level01Layout.AXE_SWING * sin(TAU * moment / float(row["period"]))


#Which way it is swinging: 1 toward "across", -1 the other way
static func axe_heading(row: Dictionary, index: int, time: float) -> float:
	var moment := time + float(row["phase"]) - index * float(row["lag"])
	return 1.0 if cos(TAU * moment / float(row["period"])) >= 0.0 else -1.0


#The middle of the comment at the end of an axe and the two axes of its face: "rod" from the pivot to the comment and "wide" across it
static func axe_blade(row: Dictionary, index: int, time: float) -> Dictionary:
	var frame := bridge_frame(row["edge"])
	var spot: Vector3 = axe_spots(row)[index]
	var angle := axe_angle(row, index, time)
	var across: Vector3 = frame["across"]
	var rod := across * sin(angle) - Vector3.UP * cos(angle)
	var pivot := spot + Vector3.UP * Level01Layout.AXE_PIVOT
	return {"center": pivot + rod * Level01Layout.AXE_ROD, "rod": rod, "wide": across * cos(angle) + Vector3.UP * sin(angle),
		"along": frame["along"], "pivot": pivot}


#Whether the body standing with its feet at "feet" is touched by any axe of the row; returns the index of the axe, or -1
static func axe_hits(row: Dictionary, time: float, feet: Vector3) -> int:
	var half := Level01Layout.AXE_BLADE / 2.0
	for index in int(row["count"]):
		var blade := axe_blade(row, index, time)
		var centre: Vector3 = blade["center"]
		for lift in BODY_SAMPLES:
			var offset := feet + Vector3.UP * lift - centre
			if absf(offset.dot(blade["along"] as Vector3)) <= half.z + BODY_RADIUS and absf(offset.dot(blade["wide"] as Vector3)) <= half.x + BODY_RADIUS \
					and absf(offset.dot(blade["rod"] as Vector3)) <= half.y + BODY_RADIUS:
				return index
	return -1


#The cycle of a puncher: how far its like is out (0 back, 1 at its full reach, a little under 0 while it shakes) and whether it hits
static func punch_out(puncher: Dictionary, time: float) -> float:
	var local := fposmod(time + float(puncher["phase"]), float(puncher["period"]))
	var windup := Level01Layout.PUNCH_WINDUP
	var out := windup + Level01Layout.PUNCH_OUT
	var hold := out + Level01Layout.PUNCH_HOLD
	var back := hold + Level01Layout.PUNCH_BACK
	if local < windup:
		return -0.05 * smoothstep(0.0, 1.0, local / windup)
	if local < out:
		return 1.0 - pow(1.0 - (local - windup) / Level01Layout.PUNCH_OUT, 2.0)
	if local < hold:
		return 1.0
	if local < back:
		return 1.0 - smoothstep(0.0, 1.0, (local - hold) / Level01Layout.PUNCH_BACK)
	return 0.0


#Whether the like is flying out or held out: the only moments it hits
static func punch_live(puncher: Dictionary, time: float) -> bool:
	var local := fposmod(time + float(puncher["phase"]), float(puncher["period"]))
	return local >= Level01Layout.PUNCH_WINDUP and local < Level01Layout.PUNCH_WINDUP + Level01Layout.PUNCH_OUT + Level01Layout.PUNCH_HOLD


#Whether it is shaking before it punches, to tell it is coming
static func punch_winding(puncher: Dictionary, time: float) -> bool:
	return fposmod(time + float(puncher["phase"]), float(puncher["period"])) < Level01Layout.PUNCH_WINDUP


#Where the like is: on the floor of the bridge at its share, from just out of the side it stands on toward the other side
static func punch_fist(puncher: Dictionary, time: float) -> Vector3:
	var frame := bridge_frame(puncher["edge"])
	var rest := float(frame["width"]) / 2.0 + Level01Layout.PUNCH_FIST.z / 2.0
	var lateral := float(puncher["side"]) * (rest - Level01Layout.PUNCH_REACH * punch_out(puncher, time))
	return bridge_point(frame, lerpf(float(frame["start"]), float(frame["end"]), float(puncher["at"])), lateral)


#While it is out the like hits anything between its barrel and itself: what it went through on its way out is thrown too
static func punch_hits(puncher: Dictionary, time: float, feet: Vector3) -> bool:
	if not punch_live(puncher, time):
		return false
	var frame := bridge_frame(puncher["edge"])
	var fist := punch_fist(puncher, time)
	var offset := feet - fist
	var size := Level01Layout.PUNCH_FIST
	var side := float(puncher["side"])
	#How far toward its barrel from the like the body is: from just in front of the like to the edge of the bridge it came from
	var back := offset.dot(frame["across"] as Vector3) * side
	var reach := float(frame["width"]) / 2.0 + size.z - (fist - (frame["from"] as Vector3)).dot(frame["across"] as Vector3) * side
	if absf(offset.dot(frame["along"] as Vector3)) > size.x / 2.0 + BODY_RADIUS or back < -size.z / 2.0 - BODY_RADIUS or back > reach:
		return false
	return offset.y < size.y + 0.1 and offset.y > -0.6


#The like throws whoever it hits toward the other side of the bridge
static func punch_push(puncher: Dictionary) -> Vector3:
	return -(bridge_frame(puncher["edge"])["across"] as Vector3) * float(puncher["side"])


#How fast a fan is turning (0 still, 1 at full blow): it spins up first, so it can be seen coming
static func fan_spin(fan: Dictionary, time: float) -> float:
	var local := fposmod(time + float(fan["phase"]), float(fan["period"]))
	var up := Level01Layout.FAN_SPIN_UP
	if local < up:
		return local / up
	if local < up + float(fan["blow"]):
		return 1.0
	return clampf(1.0 - (local - up - float(fan["blow"])) / 0.5, 0.0, 1.0)


static func fan_blowing(fan: Dictionary, time: float) -> bool:
	var local := fposmod(time + float(fan["phase"]), float(fan["period"]))
	return local >= Level01Layout.FAN_SPIN_UP and local < Level01Layout.FAN_SPIN_UP + float(fan["blow"])


#What the wind of a fan does to a body at "at": it drags it across the bridge toward the side away from the fan while it is over the bridge
#(also in the air, a few meters over it)
static func fan_drift(fan: Dictionary, time: float, at: Vector3) -> Vector3:
	if not fan_blowing(fan, time):
		return Vector3.ZERO
	var frame := bridge_frame(fan["edge"])
	var offset := at - (frame["from"] as Vector3)
	var along := offset.dot(frame["along"] as Vector3)
	if along < float(frame["start"]) - 0.5 or along > float(frame["end"]) + 0.5 or offset.y < -2.0 or offset.y > 5.0:
		return Vector3.ZERO
	return -(frame["across"] as Vector3) * float(fan["side"]) * float(fan["power"])


#How long a run is in seconds for one of its things: rising, rolling the whole way and sinking
static func run_travel(run: Dictionary) -> float:
	return 2.0 * Level01Layout.RUN_RISE + float(Level01Layout.run_line(run)["length"]) / float(run["speed"])


#The lanes of the "number"-th thing of a run, as meters across the way from its middle. Scroll wheels go left and right by turns and every
#fifth comes in pairs, a wall to jump; giant balls follow a fixed pattern that never fills the three lanes
const BOULDER_PATTERN: Array = [[1], [0, 2], [1], [0], [2], [0, 1], [2], [1, 2], [0], [1]]


static func run_lanes(run: Dictionary, index: int, number: int) -> Array[float]:
	var lanes: Array[float] = []
	if run["kind"] == Level01Layout.ROLLER:
		var offset := Level01Layout.ROLLER_LENGTH / 2.0 + 0.05
		if posmod(number, 5) == 4:
			lanes.append_array([-offset, offset])
		else:
			lanes.append(offset if posmod(number + index, 2) == 0 else -offset)
		return lanes
	for lane: int in BOULDER_PATTERN[posmod(number + index * 3, BOULDER_PATTERN.size())]:
		lanes.append(Level01Layout.BOULDER_LANES[lane])
	return lanes


#Every thing of a run that is out at "time": {"number", "along" (meters from the far end), "lift" (0 in its slot, 1 rolling), "lanes", "live"}
static func run_items(run: Dictionary, index: int, time: float) -> Array[Dictionary]:
	var every := float(run["every"])
	var travel := run_travel(run)
	var length := float(Level01Layout.run_line(run)["length"])
	var rise := Level01Layout.RUN_RISE
	var shifted := time - float(run["phase"])
	var found: Array[Dictionary] = []
	for number in range(ceili((shifted - travel) / every), floori(shifted / every) + 1):
		var age := shifted - number * every
		if age < 0.0 or age > travel:
			continue
		var along := clampf((age - rise) * float(run["speed"]), 0.0, length)
		var lift := 1.0
		if age < rise:
			lift = age / rise
		elif age > travel - rise:
			lift = (travel - age) / rise
		found.append({"number": number, "along": along, "lift": lift, "lanes": run_lanes(run, index, number), "live": lift >= 0.999})
	return found


#How lit the lane of a run of giant balls is: it lights up in the seconds before a ball rises in it (1 just before), 0 when none is coming
static func lane_warning(run: Dictionary, index: int, lane: float, time: float) -> float:
	var every := float(run["every"])
	var shifted := time - float(run["phase"])
	var best := 0.0
	for number in range(floori(shifted / every) + 1, floori((shifted + Level01Layout.BOULDER_WARN) / every) + 1):
		var left := number * every - shifted
		if run_lanes(run, index, number).has(lane):
			best = maxf(best, 1.0 - left / Level01Layout.BOULDER_WARN)
	return best


#The middle of a thing of a run, given its "along", one of its lanes and how far out of its slot it is
static func run_point(run: Dictionary, along: float, lane: float, lift: float) -> Vector3:
	var line := Level01Layout.run_line(run)
	var radius := Level01Layout.ROLLER_RADIUS if run["kind"] == Level01Layout.ROLLER else Level01Layout.BOULDER_RADIUS
	var at: Vector3 = (line["from"] as Vector3) + (line["along"] as Vector3) * along + (line["across"] as Vector3) * lane
	at.y = (line["from"] as Vector3).y + radius * (2.0 * lift - 1.0)
	return at


#Whether the body with its feet at "feet" is touched by a thing of the run (a scroll wheel can be jumped over, a giant ball cannot)
static func run_hits(run: Dictionary, index: int, time: float, feet: Vector3) -> bool:
	var line := Level01Layout.run_line(run)
	var offset := feet - (line["from"] as Vector3)
	var along := offset.dot(line["along"] as Vector3)
	var lateral := offset.dot(line["across"] as Vector3)
	var rolls: bool = run["kind"] == Level01Layout.ROLLER
	if rolls and offset.y > 2.0 * Level01Layout.ROLLER_RADIUS - ROLLER_CLEAR:
		return false
	for item in run_items(run, index, time):
		if not item["live"]:
			continue
		for lane: float in item["lanes"]:
			if rolls:
				if absf(along - float(item["along"])) <= Level01Layout.ROLLER_RADIUS + BODY_RADIUS and absf(lateral - lane) <= Level01Layout.ROLLER_LENGTH / 2.0 + BODY_RADIUS:
					return true
			elif Vector2(along - float(item["along"]), lateral - lane).length() <= Level01Layout.BOULDER_RADIUS + BODY_RADIUS + 0.05:
				return true
	return false


#Things that roll throw whoever they hit back the way they roll
static func run_push(run: Dictionary) -> Vector3:
	return Level01Layout.run_line(run)["along"]


#What hits the body with its feet at "feet" at "time" among the traps that cannot be jumped (axes, likes and giant balls), for whoever plans
#a way through them: Kind.NONE when nothing does
static func blocking_hit(feet: Vector3, time: float) -> int:
	for row: Dictionary in Level01Layout.AXES:
		if _near_edge(row["edge"], feet) and axe_hits(row, time, feet) >= 0:
			return Kind.AXE
	for puncher: Dictionary in Level01Layout.PUNCHERS:
		if _near_edge(puncher["edge"], feet) and punch_hits(puncher, time, feet):
			return Kind.PUNCH
	var index := Level01Layout.run_at(feet, 1.5)
	if index >= 0:
		var run: Dictionary = Level01Layout.RUNS[index]
		if run["kind"] == Level01Layout.BOULDER and run_hits(run, index, time, feet):
			return Kind.BOULDER
	return Kind.NONE


#Whether a point is over the bridge of "edge" or close to it, so the tests far from it are skipped
static func _near_edge(edge: Array, point: Vector3) -> bool:
	var a: Vector3 = Level01Layout.POSITIONS[edge[0]]
	var b: Vector3 = Level01Layout.POSITIONS[edge[1]]
	var flat := Vector2(point.x, point.z)
	return Geometry2D.get_closest_point_to_segment(flat, Vector2(a.x, a.z), Vector2(b.x, b.z)).distance_to(flat) < 8.0 and absf(point.y - a.y) < 4.0
