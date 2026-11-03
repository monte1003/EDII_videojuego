class_name Level01Hazards
extends RefCounted

#The spinners of level 1 with no nodes: where each bar points at a given time and who it hits

#A racer higher than this over the floor jumped over the bar
const BAR_HEIGHT := 0.6
#How close to the bar a racer must be to be hit
const BAR_REACH := 0.85


#Angle of the bar in the XZ plane (from +X toward +Z) seconds after the start of the round
static func angle_at(spinner: Dictionary, time: float) -> float:
	return float(spinner["phase"]) + float(spinner["speed"]) * time


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
