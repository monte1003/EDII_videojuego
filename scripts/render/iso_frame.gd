class_name IsoFrame
extends RefCounted

#An isometric shot: an orthogonal camera tilted down and turned 45 degrees from the frame, placed so that a patch of ground and
#every body in it fit with some room around. No nodes: it only works out where the camera goes and how much it sees

const DEFAULT_PITCH := 32.0
const DEFAULT_TURN := 45.0
#How tall a body is counted, how far the camera stands back along its view and the room left around everything
const BODY_HEIGHT := 1.1
const DISTANCE := 40.0
const MARGIN := 1.15

#Where the camera stands and looks, and how tall the view is in meters (the "size" of an orthogonal Camera3D that keeps its height)
var transform := Transform3D.IDENTITY
var size := 1.0


#Frames the patch "frame_size" (meters on the ground, turned "frame_yaw" radians) around "center" together with the bodies whose feet
#are at "feet". "aspect" is width / height of the picture. The view looks down "pitch_degrees" and turns "turn_degrees" from the frame
static func fit(center: Vector3, frame_size: Vector2, feet: Array[Vector3], aspect: float, frame_yaw := 0.0,
		pitch_degrees := DEFAULT_PITCH, turn_degrees := DEFAULT_TURN, margin := MARGIN) -> IsoFrame:
	var shot := IsoFrame.new()
	var basis := Basis(Vector3.UP, frame_yaw + deg_to_rad(turn_degrees)) * Basis(Vector3.RIGHT, -deg_to_rad(pitch_degrees))
	var points: Array[Vector3] = []
	var half := frame_size / 2.0
	var turn := Basis(Vector3.UP, frame_yaw)
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		points.append(center + turn * Vector3(corner.x, 0.0, corner.y))
	for foot in feet:
		points.append(foot)
		points.append(foot + Vector3(0.0, BODY_HEIGHT, 0.0))
	var right := basis.x
	var up := basis.y
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point in points:
		var across := Vector2(point.dot(right), point.dot(up))
		low = Vector2(minf(low.x, across.x), minf(low.y, across.y))
		high = Vector2(maxf(high.x, across.x), maxf(high.y, across.y))
	var middle := (low + high) / 2.0
	var depth := center.dot(basis.z)
	var target := right * middle.x + up * middle.y + basis.z * depth
	shot.size = maxf(high.y - low.y, (high.x - low.x) / maxf(aspect, 0.01)) * margin
	shot.transform = Transform3D(basis, target + basis.z * DISTANCE)
	return shot


#Turns "camera" into this shot: orthogonal, keeping its height, with room in front and behind for the whole set
func apply(camera: Camera3D) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = size
	camera.near = 0.5
	camera.far = DISTANCE * 2.5
	camera.global_transform = transform


#How tall a body of "height" meters looks in the picture, as a share of its height
func body_share(height := 1.0) -> float:
	var pitch := absf(transform.basis.z.angle_to(Vector3(transform.basis.z.x, 0.0, transform.basis.z.z)))
	return height * cos(pitch) / size
