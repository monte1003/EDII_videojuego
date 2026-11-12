class_name ArenaHazards
extends RefCounted

#What moves on an arena map, with no nodes: where each sweeping block is at a given time and who it touches, who stands on a
#trampoline and where it throws, and how a belt drags. The bars that turn on an island use the same math as the race (Level01Hazards)

#The block that sweeps a bridge: its size along the bridge and across it, how close a player must be and how high the feet clear it
const BLOCK_ALONG := 1.0
const BLOCK_ACROSS := 1.6
const BLOCK_REACH := 0.35
const BLOCK_CLEAR := 0.6
#A trampoline throws whoever stands this close to its middle with the feet this low; how fast up and out
const PAD_REACH := 0.95
const PAD_FEET := 0.4
const PAD_LIFT := 8.4
const PAD_PUSH := 3.2


#How far the block goes to each side of the middle of its bridge
static func block_reach(layout: ArenaLayout, sweeper: Dictionary) -> float:
	var frame := _frame(layout, sweeper)
	return maxf(float(frame["width"]) / 2.0 - BLOCK_ACROSS / 2.0 - 0.1, 0.0)


#The middle of the track of the block, on the surface of the bridge
static func block_track(layout: ArenaLayout, sweeper: Dictionary) -> Vector3:
	var frame := _frame(layout, sweeper)
	return (frame["start"] as Vector3).lerp(frame["end"], float(sweeper["at"]))


static func block_center(layout: ArenaLayout, sweeper: Dictionary, time: float) -> Vector3:
	var frame := _frame(layout, sweeper)
	var sweep := sin(TAU * time / float(sweeper["period"]) + float(sweeper["phase"])) * block_reach(layout, sweeper)
	return block_track(layout, sweeper) + (frame["side"] as Vector3) * sweep


#The way the block is going across the bridge right now
static func block_heading(layout: ArenaLayout, sweeper: Dictionary, time: float) -> Vector3:
	var turn := signf(cos(TAU * time / float(sweeper["period"]) + float(sweeper["phase"])))
	return (_frame(layout, sweeper)["side"] as Vector3) * (turn if turn != 0.0 else 1.0)


static func block_hits(layout: ArenaLayout, sweeper: Dictionary, time: float, point: Vector3) -> bool:
	var frame := _frame(layout, sweeper)
	var center := block_center(layout, sweeper, time)
	if point.y - center.y > BLOCK_CLEAR or point.y - center.y < -1.5:
		return false
	var offset := Vector3(point.x - center.x, 0.0, point.z - center.z)
	var along := absf(offset.dot(frame["direction"] as Vector3))
	var across := absf(offset.dot(frame["side"] as Vector3))
	return along <= BLOCK_ALONG / 2.0 + BLOCK_REACH and across <= BLOCK_ACROSS / 2.0 + BLOCK_REACH


static func pad_position(layout: ArenaLayout, island: StringName) -> Vector3:
	return layout.position_of(island) + (layout.pads[island]["offset"] as Vector3)


static func pad_hits(layout: ArenaLayout, island: StringName, point: Vector3) -> bool:
	var spot := pad_position(layout, island)
	if point.y - spot.y > PAD_FEET or point.y - spot.y < -0.5:
		return false
	return Vector2(point.x - spot.x, point.z - spot.z).length() <= PAD_REACH


#Up, and a little toward the middle of its island so nobody is thrown off the map
static func pad_launch(layout: ArenaLayout, island: StringName) -> Vector3:
	var inward := -(layout.pads[island]["offset"] as Vector3)
	inward.y = 0.0
	if inward.length() < 0.1:
		return Vector3(0.0, PAD_LIFT, 0.0)
	return inward.normalized() * PAD_PUSH + Vector3(0.0, PAD_LIFT, 0.0)


#Whether a point stands on the walkable part of a bridge
static func on_bridge(layout: ArenaLayout, bridge: ArenaLayout.Bridge, point: Vector3) -> bool:
	var frame := layout.frame_of(bridge)
	var start: Vector3 = frame["start"]
	var offset := Vector3(point.x - start.x, 0.0, point.z - start.z)
	var along := offset.dot(frame["direction"] as Vector3)
	var across := absf(offset.dot(frame["side"] as Vector3))
	if along < 0.0 or along > float(frame["length"]) or across > float(frame["width"]) / 2.0:
		return false
	var share := along / maxf(float(frame["length"]), 0.01)
	var height := lerpf(start.y, (frame["end"] as Vector3).y, share)
	return absf(point.y - height) < 0.6


#The speed at which a belt drags whoever stands on it; zero while the belts are stopped
static func belt_drift(layout: ArenaLayout, bridge: ArenaLayout.Bridge, stage: int, time: float) -> Vector3:
	return (layout.frame_of(bridge)["direction"] as Vector3) * layout.belt_speed * layout.belt_flow(stage, time)


static func _frame(layout: ArenaLayout, sweeper: Dictionary) -> Dictionary:
	var edge: Array = sweeper["edge"]
	return layout.frame_of(layout.bridge_between(edge[0], edge[1]))
