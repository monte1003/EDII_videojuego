class_name Level01Hazards
extends RefCounted

#Level 1 hazards with no nodes: spinners, sweeping blocks, rolling balls and comments over time

#Feet above this cleared the bar
const BAR_HEIGHT := 0.6
#Bar hit distance
const BAR_REACH := 0.85
#Sweeping block size and hit distance
const BLOCK_ALONG := 1.0
const BLOCK_ACROSS := 1.6
const BLOCK_REACH := 0.35
#Feet above this cleared the block
const BLOCK_HEIGHT := 0.6
#Ball hit distance and clearing height
const BALL_REACH := 0.35
const BALL_CLEAR := 0.8
#Ball turn-around margin from the island edge
const BALL_MARGIN := 0.7
#Deck pad reach and feet height
const LIFT_REACH := 1.3
const LIFT_FEET := 0.5

#Bar angle on XZ after "time"
static func angle_at(spinner: Dictionary, time: float) -> float:
	var turned := float(spinner["speed"]) * time
	if spinner.has("surge"):
		var surge: Dictionary = spinner["surge"]
		var rate: float = surge["rate"]
		#Integral of speed * (1 + depth * sin(rate * time))
		turned += float(spinner["speed"]) * float(surge["depth"]) * (1.0 - cos(rate * time)) / rate
	return float(spinner["phase"]) + turned


#Distance to the bar (or the closest of two crossed bars)
static func distance_to_bar(centre: Vector3, spinner: Dictionary, time: float, point: Vector3) -> float:
	var arm: float = spinner["arm"]
	var offset := Vector2(point.x - centre.x, point.z - centre.z)
	var nearest := INF
	for bar in int(spinner.get("arms", 1)):
		var angle := angle_at(spinner, time) + PI / 2.0 * bar
		var direction := Vector2(cos(angle), sin(angle))
		var along := clampf(offset.dot(direction), -arm, arm)
		nearest = minf(nearest, (offset - direction * along).length())
	return nearest


#Whether the bar touches a racer at "point"
static func hits(centre: Vector3, spinner: Dictionary, time: float, point: Vector3, feet_y: float) -> bool:
	if feet_y > BAR_HEIGHT:
		return false
	return distance_to_bar(centre, spinner, time, point) <= BAR_REACH


#Throw along the sweep and a bit outward
static func push_direction(centre: Vector3, spinner: Dictionary, point: Vector3) -> Vector3:
	var outward := Vector3(point.x - centre.x, 0.0, point.z - centre.z)
	if outward.length() < 0.05:
		outward = Vector3.RIGHT
	outward = outward.normalized()
	var turn := signf(float(spinner["speed"]))
	var tangent := Vector3(-outward.z, 0.0, outward.x) * turn
	return (tangent * 0.7 + outward * 0.7).normalized()


#Seconds until the bar reaches "point", or -1 within "horizon"
static func time_to_hit(centre: Vector3, spinner: Dictionary, time: float, point: Vector3, horizon: float) -> float:
	var step := 0.05
	var ahead := 0.0
	while ahead <= horizon:
		if distance_to_bar(centre, spinner, time + ahead, point) <= BAR_REACH:
			return ahead
		ahead += step
	return -1.0


#Block spot on the bridge at "time"
static func block_center(pusher: Dictionary, time: float) -> Vector3:
	var frame := _bridge_frame(pusher)
	var along: float = lerpf(float(frame["start"]), float(frame["end"]), float(pusher["at"]))
	var sweep: float = sin(TAU * time / float(pusher["period"]) + float(pusher["phase"])) * float(frame["reach"])
	var height: float = frame["from"].y + (frame["to"].y - frame["from"].y) * (along - frame["start"]) / maxf(frame["end"] - frame["start"], 0.001)
	var ground: Vector3 = frame["from"] + (frame["direction"] as Vector3) * along
	return Vector3(ground.x, height, ground.z) + (frame["side"] as Vector3) * sweep


#Block track: middle, run direction, across direction and reach
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


#Block heading across the bridge
static func block_heading(pusher: Dictionary, time: float) -> Vector3:
	var frame := _bridge_frame(pusher)
	var turn := signf(cos(TAU * time / float(pusher["period"]) + float(pusher["phase"])))
	return (frame["side"] as Vector3) * (turn if turn != 0.0 else 1.0)


#Whether the block touches "point" at "time"
static func block_hits(pusher: Dictionary, time: float, point: Vector3) -> bool:
	var frame := _bridge_frame(pusher)
	var center := block_center(pusher, time)
	if point.y - center.y > BLOCK_HEIGHT:
		return false
	var offset := Vector3(point.x - center.x, 0.0, point.z - center.z)
	var along := absf(offset.dot(frame["direction"] as Vector3))
	var across := absf(offset.dot(frame["side"] as Vector3))
	return along <= BLOCK_ALONG / 2.0 + BLOCK_REACH and across <= BLOCK_ACROSS / 2.0 + BLOCK_REACH


#Seconds until the block reaches a moving racer, or -1
static func block_time_to_hit(pusher: Dictionary, time: float, point: Vector3, heading: Vector3, speed: float, horizon: float) -> float:
	var ahead := 0.0
	while ahead <= horizon:
		var there := point + heading * speed * ahead
		if block_hits(pusher, time + ahead, Vector3(there.x, block_center(pusher, time + ahead).y, there.z)):
			return ahead
		ahead += 0.05
	return -1.0


#Half lane of a ball
static func ball_half_lane(ball: Dictionary) -> float:
	return maxf(Level01Layout.radius_of(ball["island"]) - BALL_MARGIN, 0.5)


#Lane and across unit vectors
static func ball_lane(ball: Dictionary) -> Dictionary:
	var along := Vector3(cos(float(ball["angle"])), 0.0, sin(float(ball["angle"])))
	return {"along": along, "across": Vector3(-along.z, 0.0, along.x)}


#Ball position on its lane, -1 to 1, as a sine of the clock
static func ball_share(ball: Dictionary, time: float) -> float:
	return sin(TAU * (time + float(ball["phase"])) / float(ball["period"]))


static func ball_center(ball: Dictionary, time: float) -> Vector3:
	var island: Vector3 = Level01Layout.POSITIONS[ball["island"]]
	return island + (ball_lane(ball)["along"] as Vector3) * ball_half_lane(ball) * ball_share(ball, time) + Vector3(0.0, Level01Layout.BALL_RADIUS, 0.0)


static func ball_heading(ball: Dictionary, time: float) -> Vector3:
	var turn := signf(cos(TAU * (time + float(ball["phase"])) / float(ball["period"])))
	return (ball_lane(ball)["along"] as Vector3) * (turn if turn != 0.0 else 1.0)


#Whether the ball touches a racer at "point"
static func ball_hits(ball: Dictionary, time: float, point: Vector3, feet_y: float) -> bool:
	if feet_y > BALL_CLEAR:
		return false
	var centre := ball_center(ball, time)
	return Vector2(point.x - centre.x, point.z - centre.z).length() <= Level01Layout.BALL_RADIUS + BALL_REACH


#Throw along the roll and to the racer's side
static func ball_push(ball: Dictionary, time: float, point: Vector3) -> Vector3:
	var lane := ball_lane(ball)
	var centre := ball_center(ball, time)
	var side := signf((Vector3(point.x - centre.x, 0.0, point.z - centre.z)).dot(lane["across"] as Vector3))
	return (ball_heading(ball, time) * 0.75 + (lane["across"] as Vector3) * (side if side != 0.0 else 1.0) * 0.65).normalized()


#Seconds until a ball reaches "point", or -1
static func ball_time_to_hit(ball: Dictionary, time: float, point: Vector3, horizon: float) -> float:
	var ahead := 0.0
	while ahead <= horizon:
		if ball_hits(ball, time + ahead, point, 0.0):
			return ahead
		ahead += 0.05
	return -1.0


#Whether a racer stands on the deck pad
static func lift_hits(lift: Dictionary, point: Vector3) -> bool:
	var spot: Vector3 = lift["pad"]
	if point.y - spot.y > LIFT_FEET:
		return false
	return Vector2(point.x - spot.x, point.z - spot.z).length() <= LIFT_REACH


#Comment cycle parts, progress and starting side
const COMMENT_IDLE := 0
const COMMENT_TYPING := 1
const COMMENT_WARNING := 2
const COMMENT_PUSHING := 3
const COMMENT_FADING := 4
#Comment push reach and clearing height
const COMMENT_ALONG := 1.1
const COMMENT_ACROSS := 0.9
const COMMENT_CLEAR := 0.7


static func comment_state(comment: Dictionary, time: float) -> Dictionary:
	var period: float = comment["period"]
	var moment := time + float(comment["phase"])
	var local := fposmod(moment, period)
	var side := 1.0 if floori(moment / period) % 2 == 0 else -1.0
	var typed: float = Level01Layout.COMMENT_TYPE
	var warned := typed + Level01Layout.COMMENT_WARN
	var pushed := warned + Level01Layout.COMMENT_PUSH
	var faded := pushed + Level01Layout.COMMENT_FADE
	var cycle := floori(moment / period)
	if local < typed:
		return {"stage": COMMENT_TYPING, "share": local / typed, "side": side, "cycle": cycle}
	if local < warned:
		return {"stage": COMMENT_WARNING, "share": (local - typed) / Level01Layout.COMMENT_WARN, "side": side, "cycle": cycle}
	if local < pushed:
		return {"stage": COMMENT_PUSHING, "share": (local - warned) / Level01Layout.COMMENT_PUSH, "side": side, "cycle": cycle}
	if local < faded:
		return {"stage": COMMENT_FADING, "share": (local - pushed) / Level01Layout.COMMENT_FADE, "side": side, "cycle": cycle}
	return {"stage": COMMENT_IDLE, "share": 0.0, "side": side, "cycle": cycle}


#Bubble middle: at its side while typed, sweeping while pushing
static func comment_center(comment: Dictionary, time: float) -> Vector3:
	var track := block_track(comment)
	var state := comment_state(comment, time)
	var half := Level01Layout.width_of(Level01Layout.kind_of(comment["edge"][0], comment["edge"][1])) / 2.0
	var rest := half - 0.4
	var lateral := rest
	match int(state["stage"]):
		COMMENT_PUSHING:
			lateral = lerpf(rest, -(half + 0.6), smoothstep(0.0, 1.0, float(state["share"])))
		COMMENT_FADING:
			lateral = -(half + 0.6)
	return (track["centre"] as Vector3) + (track["side"] as Vector3) * lateral * float(state["side"]) + Vector3(0.0, 0.7, 0.0)


#Push across the bridge toward its end side
static func comment_push(comment: Dictionary, time: float) -> Vector3:
	var track := block_track(comment)
	return -(track["side"] as Vector3) * float(comment_state(comment, time)["side"])


static func comment_hits(comment: Dictionary, time: float, point: Vector3) -> bool:
	if int(comment_state(comment, time)["stage"]) != COMMENT_PUSHING:
		return false
	var track := block_track(comment)
	var center := comment_center(comment, time)
	if point.y - (track["centre"] as Vector3).y > COMMENT_CLEAR:
		return false
	var offset := Vector3(point.x - center.x, 0.0, point.z - center.z)
	var along := absf(offset.dot(Vector3(-(track["side"] as Vector3).z, 0.0, (track["side"] as Vector3).x)))
	var across := absf(offset.dot(track["side"] as Vector3))
	return along <= COMMENT_ALONG and across <= COMMENT_ACROSS


#Seconds until the next push; 0 while pushing
static func comment_wait(comment: Dictionary, time: float) -> float:
	var state := comment_state(comment, time)
	if int(state["stage"]) == COMMENT_PUSHING:
		return 0.0
	var period: float = comment["period"]
	var local := fposmod(time + float(comment["phase"]), period)
	var start: float = Level01Layout.COMMENT_TYPE + Level01Layout.COMMENT_WARN
	return start - local if local < start else period - local + start


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
