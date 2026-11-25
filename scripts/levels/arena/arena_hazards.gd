class_name ArenaHazards
extends RefCounted

#Moving pieces of an arena with no nodes: everything is a function of the round time

#Sweeping block size along and across its way, reach and feet clearance
const BLOCK_ALONG := 1.6
const BLOCK_ACROSS := 1.0
const BLOCK_REACH := 0.35
const BLOCK_CLEAR := 0.6
#Trampoline reach, feet height and launch speed
const PAD_REACH := 0.95
const PAD_FEET := 0.4
const PAD_LIFT := 8.4
#Feet height range dragged by a belt
const BELT_FEET := 0.5
#Height range in the way of a bar
const BAR_FLOOR := 1.2


#Block centre at "time", back and forth
static func block_center(sweeper: Dictionary, time: float) -> Vector3:
	var share := 0.5 + 0.5 * sin(TAU * time / float(sweeper["period"]) + float(sweeper["phase"]))
	return (sweeper["a"] as Vector3).lerp(sweeper["b"], share)


#Way from the first end to the second
static func block_way(sweeper: Dictionary) -> Vector3:
	var way: Vector3 = (sweeper["b"] as Vector3) - (sweeper["a"] as Vector3)
	way.y = 0.0
	return way.normalized()


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


#Whether a bar reaches a point now; other floors and feet above are safe
static func spinner_hits(spinner: Dictionary, time: float, point: Vector3) -> bool:
	var centre: Vector3 = spinner["at"]
	if absf(point.y - centre.y) > BAR_FLOOR:
		return false
	if Vector2(point.x - centre.x, point.z - centre.z).length() > float(spinner["arm"]) + Level01Hazards.BAR_REACH:
		return false
	return Level01Hazards.hits(centre, spinner, time, point, point.y - centre.y)


static func is_cannon(pad: Dictionary) -> bool:
	return pad.has("to")


#A pad with a beat only works in the first "on" seconds of each period
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


#Trampoline throws up, cannon along the arc to its target
static func pad_launch(pad: Dictionary, gravity: float) -> Vector3:
	if not is_cannon(pad):
		return Vector3(0.0, PAD_LIFT, 0.0)
	var from: Vector3 = pad["at"]
	var to: Vector3 = pad["to"]
	var time: float = pad["time"]
	return Vector3((to.x - from.x) / time, (to.y - from.y) / time + 0.5 * gravity * time, (to.z - from.z) / time)


#Cannon flight position after "seconds"
static func pad_arc(pad: Dictionary, seconds: float, gravity: float) -> Vector3:
	return (pad["at"] as Vector3) + pad_launch(pad, gravity) * seconds - Vector3(0.0, 0.5 * gravity * seconds * seconds, 0.0)


#Belt direction on the ground
static func belt_way(belt: Dictionary) -> Vector3:
	var way: Vector3 = (belt["b"] as Vector3) - (belt["a"] as Vector3)
	way.y = 0.0
	return way.normalized()


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


#Belt drag speed; zero while stopped
static func belt_drift(layout: ArenaLayout, belt: Dictionary, stage: int, time: float) -> Vector3:
	return belt_way(belt) * float(belt.get("speed", layout.belt_speed)) * layout.belt_flow(belt, stage, time)
