class_name Level01Hazards
extends RefCounted

#The hazards of level 1 with no nodes: where each spinner bar points, where each sweeping block and each rolling ball is at a given time,
#and who they hit

#A racer higher than this over the floor jumped over the bar
const BAR_HEIGHT := 0.6
#How close to the bar a racer must be to be hit
const BAR_REACH := 0.85
#The block that sweeps across a bridge: its size along the bridge and across it, and how close to it a racer must be to be hit
const BLOCK_ALONG := 1.0
const BLOCK_ACROSS := 1.6
const BLOCK_REACH := 0.35
#A racer with its feet higher than this over the bridge jumped over the block
const BLOCK_HEIGHT := 0.6
#How close to a rolling ball a racer must be to be hit, and how high the feet must be to have jumped over it
const BALL_REACH := 0.35
const BALL_CLEAR := 0.8
#How far from the edge of the island the ball turns around
const BALL_MARGIN := 0.7
#A trampoline throws whoever stands within PAD_REACH of its middle with the feet no higher than PAD_FEET; how fast up and out
const PAD_REACH := 0.95
const PAD_FEET := 0.4
const PAD_LIFT := 8.8
const PAD_PUSH := 5.0

static var _pads: Dictionary = {}


#Angle of the bar in the XZ plane (from +X toward +Z) seconds after the start of the round
static func angle_at(spinner: Dictionary, time: float) -> float:
	var turned := float(spinner["speed"]) * time
	if spinner.has("surge"):
		var surge: Dictionary = spinner["surge"]
		var rate: float = surge["rate"]
		#The speed is speed * (1 + depth * sin(rate * time)); this is its integral
		turned += float(spinner["speed"]) * float(surge["depth"]) * (1.0 - cos(rate * time)) / rate
	return float(spinner["phase"]) + turned


#Distance from a point to the bar, a segment that crosses the centre of the island and reaches "arm" to both sides
static func distance_to_bar(centre: Vector3, spinner: Dictionary, time: float, point: Vector3) -> float:
	var arm: float = spinner["arm"]
	var angle := angle_at(spinner, time)
	var direction := Vector2(cos(angle), sin(angle))
	var offset := Vector2(point.x - centre.x, point.z - centre.z)
	var along := clampf(offset.dot(direction), -arm, arm)
	return (offset - direction * along).length()


#True when a racer standing at "point" (feet height "feet_y" over the floor) is touched by the bar
static func hits(centre: Vector3, spinner: Dictionary, time: float, point: Vector3, feet_y: float) -> bool:
	if feet_y > BAR_HEIGHT:
		return false
	return distance_to_bar(centre, spinner, time, point) <= BAR_REACH


#Where the bar throws a racer: along its sweep and a bit outward
static func push_direction(centre: Vector3, spinner: Dictionary, point: Vector3) -> Vector3:
	var outward := Vector3(point.x - centre.x, 0.0, point.z - centre.z)
	if outward.length() < 0.05:
		outward = Vector3.RIGHT
	outward = outward.normalized()
	var turn := signf(float(spinner["speed"]))
	var tangent := Vector3(-outward.z, 0.0, outward.x) * turn
	return (tangent * 0.7 + outward * 0.7).normalized()


#Seconds from now at which the bar will touch a racer that stays at "point", or -1 when it will not in "horizon"
static func time_to_hit(centre: Vector3, spinner: Dictionary, time: float, point: Vector3, horizon: float) -> float:
	var step := 0.05
	var ahead := 0.0
	while ahead <= horizon:
		if distance_to_bar(centre, spinner, time + ahead, point) <= BAR_REACH:
			return ahead
		ahead += step
	return -1.0


#The spot of the bridge where the block of "pusher" is at "time": on the surface at its share of the length and
#shifted across by its sweep, which crosses from one side to the other without going off the bridge
static func block_center(pusher: Dictionary, time: float) -> Vector3:
	var frame := _bridge_frame(pusher)
	var along: float = lerpf(float(frame["start"]), float(frame["end"]), float(pusher["at"]))
	var sweep: float = sin(TAU * time / float(pusher["period"]) + float(pusher["phase"])) * float(frame["reach"])
	var height: float = frame["from"].y + (frame["to"].y - frame["from"].y) * (along - frame["start"]) / maxf(frame["end"] - frame["start"], 0.001)
	var ground: Vector3 = frame["from"] + (frame["direction"] as Vector3) * along
	return Vector3(ground.x, height, ground.z) + (frame["side"] as Vector3) * sweep


#Where the block sweeps: the middle of its track on the surface of the bridge, the way the surface runs (with its slope), the way across and how far
#the block goes to each side
static func block_track(pusher: Dictionary) -> Dictionary:
	var frame := _bridge_frame(pusher)
	var start: float = frame["start"]
	var end: float = frame["end"]
	var along: float = lerpf(start, end, float(pusher["at"]))
	var from: Vector3 = frame["from"]
	var to: Vector3 = frame["to"]
	var direction: Vector3 = frame["direction"]
	var ground := from + direction * along
	var share := (along - start) / maxf(end - start, 0.001)
	return {
		"centre": Vector3(ground.x, from.y + (to.y - from.y) * share, ground.z),
		"tangent": Vector3(direction.x * (end - start), to.y - from.y, direction.z * (end - start)).normalized(),
		"side": frame["side"], "reach": frame["reach"],
	}


#The direction in which the block is going across the bridge, as a unit vector on the ground
static func block_heading(pusher: Dictionary, time: float) -> Vector3:
	var frame := _bridge_frame(pusher)
	var turn := signf(cos(TAU * time / float(pusher["period"]) + float(pusher["phase"])))
	return (frame["side"] as Vector3) * (turn if turn != 0.0 else 1.0)


#True when a racer standing at "point" is touched by the block of "pusher" at "time"
static func block_hits(pusher: Dictionary, time: float, point: Vector3) -> bool:
	var frame := _bridge_frame(pusher)
	var center := block_center(pusher, time)
	if point.y - center.y > BLOCK_HEIGHT:
		return false
	var offset := Vector3(point.x - center.x, 0.0, point.z - center.z)
	var along := absf(offset.dot(frame["direction"] as Vector3))
	var across := absf(offset.dot(frame["side"] as Vector3))
	return along <= BLOCK_ALONG / 2.0 + BLOCK_REACH and across <= BLOCK_ACROSS / 2.0 + BLOCK_REACH


#Seconds from now at which the block will touch a racer that keeps going toward "heading" at "speed", or -1 when it will not in "horizon"
static func block_time_to_hit(pusher: Dictionary, time: float, point: Vector3, heading: Vector3, speed: float, horizon: float) -> float:
	var ahead := 0.0
	while ahead <= horizon:
		var there := point + heading * speed * ahead
		if block_hits(pusher, time + ahead, Vector3(there.x, block_center(pusher, time + ahead).y, there.z)):
			return ahead
		ahead += 0.05
	return -1.0


#Half of the length of the lane of a ball: from the middle of the island to where the ball turns around
static func ball_half_lane(ball: Dictionary) -> float:
	return maxf(Level01Layout.radius_of(ball["island"]) - BALL_MARGIN, 0.5)


#The unit vector of the lane (the direction of +1) and the one across it
static func ball_lane(ball: Dictionary) -> Dictionary:
	var along := Vector3(cos(float(ball["angle"])), 0.0, sin(float(ball["angle"])))
	return {"along": along, "across": Vector3(-along.z, 0.0, along.x)}


#How far along the lane the ball is, from -1 to 1 of the half lane: it goes and comes back as a sine of the clock
static func ball_share(ball: Dictionary, time: float) -> float:
	return sin(TAU * (time + float(ball["phase"])) / float(ball["period"]))


#The middle of the ball at "time"
static func ball_center(ball: Dictionary, time: float) -> Vector3:
	var island: Vector3 = Level01Layout.POSITIONS[ball["island"]]
	return island + (ball_lane(ball)["along"] as Vector3) * ball_half_lane(ball) * ball_share(ball, time) + Vector3(0.0, Level01Layout.BALL_RADIUS, 0.0)


#The unit vector in which the ball is rolling
static func ball_heading(ball: Dictionary, time: float) -> Vector3:
	var turn := signf(cos(TAU * (time + float(ball["phase"])) / float(ball["period"])))
	return (ball_lane(ball)["along"] as Vector3) * (turn if turn != 0.0 else 1.0)


#True when a racer at "point" (feet "feet_y" over the floor) is touched by the ball
static func ball_hits(ball: Dictionary, time: float, point: Vector3, feet_y: float) -> bool:
	if feet_y > BALL_CLEAR:
		return false
	var centre := ball_center(ball, time)
	return Vector2(point.x - centre.x, point.z - centre.z).length() <= Level01Layout.BALL_RADIUS + BALL_REACH


#Where the ball throws a racer: along its roll and to the side of the lane the racer stands on
static func ball_push(ball: Dictionary, time: float, point: Vector3) -> Vector3:
	var lane := ball_lane(ball)
	var centre := ball_center(ball, time)
	var side := signf((Vector3(point.x - centre.x, 0.0, point.z - centre.z)).dot(lane["across"] as Vector3))
	return (ball_heading(ball, time) * 0.75 + (lane["across"] as Vector3) * (side if side != 0.0 else 1.0) * 0.65).normalized()


#Seconds from now at which a ball will touch a racer that stays at "point", or -1 when it will not in "horizon"
static func ball_time_to_hit(ball: Dictionary, time: float, point: Vector3, horizon: float) -> float:
	var ahead := 0.0
	while ahead <= horizon:
		if ball_hits(ball, time + ahead, point, 0.0):
			return ahead
		ahead += 0.05
	return -1.0


#True when a racer at "point" stands on the trampoline of "island"
static func pad_hits(island: StringName, point: Vector3) -> bool:
	if not _pads.has(island):
		_pads[island] = Level01Layout.pad_position(island)
	var spot: Vector3 = _pads[island]
	if point.y - spot.y > PAD_FEET:
		return false
	return Vector2(point.x - spot.x, point.z - spot.z).length() <= PAD_REACH


#What a trampoline does to whoever steps on it: up, and a little away from its middle
static func pad_launch(island: StringName, point: Vector3) -> Vector3:
	if not _pads.has(island):
		_pads[island] = Level01Layout.pad_position(island)
	var spot: Vector3 = _pads[island]
	var away := Vector3(point.x - spot.x, 0.0, point.z - spot.z)
	if away.length() < 0.1:
		away = spot - (Level01Layout.POSITIONS[island] as Vector3)
		away.y = 0.0
	return away.normalized() * PAD_PUSH + Vector3(0.0, PAD_LIFT, 0.0)


static func _bridge_frame(pusher: Dictionary) -> Dictionary:
	var edge: Array = pusher["edge"]
	var from: Vector3 = Level01Layout.POSITIONS[edge[0]]
	var to: Vector3 = Level01Layout.POSITIONS[edge[1]]
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var direction := flat.normalized()
	var width := Level01Layout.width_of(Level01Layout.kind_of(edge[0], edge[1]))
	return {
		"from": from, "to": to, "direction": direction, "side": Vector3(-direction.z, 0.0, direction.x),
		"start": Level01Layout.radius_of(edge[0]), "end": flat.length() - Level01Layout.radius_of(edge[1]),
		"reach": width / 2.0 - BLOCK_ACROSS / 2.0 - 0.1,
	}
