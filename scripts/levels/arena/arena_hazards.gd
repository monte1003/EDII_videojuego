class_name ArenaHazards
extends RefCounted

#What moves on an arena map, with no nodes: where each sweeping block is at a given time and who it touches, who stands on a
#trampoline or a cannon and where it throws, who a turning bar reaches and how a belt drags. Everything is a function of the
#seconds of the round, so it can be drawn, hit and planned for from the time alone

#The block that sweeps: its size along its way and across it, how close a player must be and how high the feet clear it
const BLOCK_ALONG := 1.6
const BLOCK_ACROSS := 1.0
const BLOCK_REACH := 0.35
const BLOCK_CLEAR := 0.6
#A trampoline throws whoever stands this close to its middle with the feet this low, this fast up
const PAD_REACH := 0.95
const PAD_FEET := 0.4
const PAD_LIFT := 8.4
#How far over or under a belt the feet may be to be dragged by it
const BELT_FEET := 0.5
#How far over or under the floor of a bar somebody can be and still be in its way
const BAR_FLOOR := 1.2


#The middle of the block at "time": it goes from one end of its way to the other and back
static func block_center(sweeper: Dictionary, time: float) -> Vector3:
	var share := 0.5 + 0.5 * sin(TAU * time / float(sweeper["period"]) + float(sweeper["phase"]))
	return (sweeper["a"] as Vector3).lerp(sweeper["b"], share)


#The way from the first end to the second, on the ground
static func block_way(sweeper: Dictionary) -> Vector3:
	var way: Vector3 = (sweeper["b"] as Vector3) - (sweeper["a"] as Vector3)
	way.y = 0.0
	return way.normalized()


#The way the block is going right now
static func block_heading(sweeper: Dictionary, time: float) -> Vector3:
	var turn := signf(cos(TAU * time / float(sweeper["period"]) + float(sweeper["phase"])))
	return block_way(sweeper) * (turn if turn != 0.0 else 1.0)


static func block_hits(sweeper: Dictionary, time: float, point: Vector3) -> bool:
	var center := block_center(sweeper, time)
	if point.y - center.y > BLOCK_CLEAR or point.y - center.y < -1.5:
		return false
	var way := block_way(sweeper)
	var offset := Vector3(point.x - center.x, 0.0, point.z - center.z)
	var along := absf(offset.dot(way))
	var across := absf(offset.dot(Vector3(-way.z, 0.0, way.x)))
	return along <= BLOCK_ALONG / 2.0 + BLOCK_REACH and across <= BLOCK_ACROSS / 2.0 + BLOCK_REACH


#Whether a bar reaches a point right now; somebody on another floor or with the feet over the bar is out of its way
static func spinner_hits(spinner: Dictionary, time: float, point: Vector3) -> bool:
	var centre: Vector3 = spinner["at"]
	if absf(point.y - centre.y) > BAR_FLOOR:
		return false
	if Vector2(point.x - centre.x, point.z - centre.z).length() > float(spinner["arm"]) + Level01Hazards.BAR_REACH:
		return false
	return Level01Hazards.hits(centre, spinner, time, point, point.y - centre.y)


static func is_cannon(pad: Dictionary) -> bool:
	return pad.has("to")


#A pad with a beat only works during the first "on" seconds of each of its periods
static func pad_live(pad: Dictionary, time: float) -> bool:
	if not pad.has("beat"):
		return true
	var beat: Dictionary = pad["beat"]
	return fposmod(time + float(beat.get("phase", 0.0)), float(beat["period"])) < float(beat["on"])


static func pad_hits(pad: Dictionary, point: Vector3) -> bool:
	var spot: Vector3 = pad["at"]
	if point.y - spot.y > PAD_FEET or point.y - spot.y < -0.5:
		return false
	return Vector2(point.x - spot.x, point.z - spot.z).length() <= PAD_REACH


#What a pad does to whoever steps on it: a trampoline throws straight up, a cannon along the arc that ends at its target
static func pad_launch(pad: Dictionary, gravity: float) -> Vector3:
	if not is_cannon(pad):
		return Vector3(0.0, PAD_LIFT, 0.0)
	var from: Vector3 = pad["at"]
	var to: Vector3 = pad["to"]
	var time: float = pad["time"]
	return Vector3((to.x - from.x) / time, (to.y - from.y) / time + 0.5 * gravity * time, (to.z - from.z) / time)


#Where somebody thrown by a cannon is after "seconds" of flight
static func pad_arc(pad: Dictionary, seconds: float, gravity: float) -> Vector3:
	return (pad["at"] as Vector3) + pad_launch(pad, gravity) * seconds - Vector3(0.0, 0.5 * gravity * seconds * seconds, 0.0)


#The way a belt runs from its first end to its second, on the ground
static func belt_way(belt: Dictionary) -> Vector3:
	var way: Vector3 = (belt["b"] as Vector3) - (belt["a"] as Vector3)
	way.y = 0.0
	return way.normalized()


#Whether a point stands on a belt
static func on_belt(belt: Dictionary, point: Vector3) -> bool:
	var from: Vector3 = belt["a"]
	var to: Vector3 = belt["b"]
	var way := belt_way(belt)
	var length := Vector2(to.x - from.x, to.z - from.z).length()
	var offset := Vector3(point.x - from.x, 0.0, point.z - from.z)
	var along := offset.dot(way)
	var across := absf(offset.dot(Vector3(-way.z, 0.0, way.x)))
	if along < 0.0 or along > length or across > float(belt["width"]) / 2.0:
		return false
	return absf(point.y - lerpf(from.y, to.y, along / maxf(length, 0.01))) < BELT_FEET


#The speed at which a belt drags whoever stands on it; zero while it is stopped
static func belt_drift(layout: ArenaLayout, belt: Dictionary, stage: int, time: float) -> Vector3:
	return belt_way(belt) * layout.belt_speed * layout.belt_flow(belt, stage, time)
