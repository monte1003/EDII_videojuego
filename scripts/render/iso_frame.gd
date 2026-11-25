class_name IsoFrame
extends RefCounted

#Isometric shot: orthogonal camera fit to a patch of ground and its bodies

const DEFAULT_PITCH := 32.0
const DEFAULT_TURN := 45.0
#Body height, camera distance and margin
const BODY_HEIGHT := 1.1
const DISTANCE := 40.0
const MARGIN := 1.15

#Camera transform and view height in meters
var transform := Transform3D.IDENTITY
var size := 1.0


#Fits the patch and the bodies at "feet"; "aspect" is width / height
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


#Applies this shot to "camera"
func apply(camera: Camera3D) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = size
	camera.near = 0.5
	camera.far = DISTANCE * 2.5
	camera.global_transform = transform


#Share of the picture a body of "height" takes
func body_share(height := 1.0) -> float:
	var pitch := absf(transform.basis.z.angle_to(Vector3(transform.basis.z.x, 0.0, transform.basis.z.z)))
	return height * cos(pitch) / size
