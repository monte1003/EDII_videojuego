class_name PhoneGripModifier
extends SkeletonModifier3D

#Makes a walk animation hold a phone with both hands. It runs after the AnimationPlayer
#every frame, so the legs and the rest of the walk stay as they are:
#  1. the right hand turns palm up (the phone sits on it) and the elbow lifts it a little;
#  2. the left arm bends (two-bone IK) so the left wrist meets the other side of the phone;
#  3. the left hand turns palm up too.
#Rolls go around each bone's own axis (+Y points along the bone on Meshy's skeletons) and
#are split between forearm and hand, so the wrists do not twist like a candy wrapper.
#Bone global poses are computed here from the local ones (_global) instead of asking the
#skeleton: get_bone_global_pose() in the middle of a modification crashed Godot 4.7.2
#(heap corruption) when rendering, and so did a TwoBoneIK3D aimed at the phone.

@export var right_arm := &"RightArm"
@export var right_forearm := &"RightForeArm"
@export var right_hand := &"RightHand"
@export var left_arm := &"LeftArm"
@export var left_forearm := &"LeftForeArm"
@export var left_hand := &"LeftHand"
#Values found by rendering the "Texting Walk" on the three pedestrians
@export var forearm_roll_degrees := -90.0
@export var hand_roll_degrees := -90.0
#Extra bend of the right elbow; negative brings the phone up toward the face
@export var elbow_lift_degrees := -15.0
#Where the left wrist goes, in the right hand bone's space (skeleton units). Zero disables it
@export var left_target_in_right_hand := Vector3.ZERO


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_rotate_local(skeleton, right_forearm, Vector3.UP, forearm_roll_degrees)
	_rotate_local(skeleton, right_hand, Vector3.UP, hand_roll_degrees)
	_rotate_local(skeleton, right_forearm, Vector3.RIGHT, elbow_lift_degrees)
	if left_target_in_right_hand != Vector3.ZERO:
		var hand := skeleton.find_bone(right_hand)
		if hand >= 0:
			_reach(skeleton, _global(skeleton, hand) * left_target_in_right_hand)
	#The left side is a mirror of the right one, so its roll goes the other way
	_rotate_local(skeleton, left_forearm, Vector3.UP, -forearm_roll_degrees)
	_rotate_local(skeleton, left_hand, Vector3.UP, -hand_roll_degrees)


func _rotate_local(skeleton: Skeleton3D, bone_name: StringName, axis: Vector3, degrees: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0 or degrees == 0.0:
		return
	var pose := skeleton.get_bone_pose_rotation(bone) * Quaternion(axis, deg_to_rad(degrees))
	skeleton.set_bone_pose_rotation(bone, pose)


#Two-bone IK of the left arm toward "target" (skeleton space). The elbow stays on the side
#where the animation had it, so the arm never flips
func _reach(skeleton: Skeleton3D, target: Vector3) -> void:
	var upper := skeleton.find_bone(left_arm)
	var lower := skeleton.find_bone(left_forearm)
	var end := skeleton.find_bone(left_hand)
	if upper < 0 or lower < 0 or end < 0:
		return
	var shoulder := _global(skeleton, upper).origin
	var elbow := _global(skeleton, lower).origin
	var wrist := _global(skeleton, end).origin
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(wrist)
	var to_target := target - shoulder
	var distance := clampf(to_target.length(), absf(upper_length - lower_length) + 0.001,
		upper_length + lower_length - 0.001)
	var direction := to_target.normalized()
	#Elbow side: the part of the current elbow offset that is not along the target line
	var side := (elbow - shoulder) - direction * (elbow - shoulder).dot(direction)
	if side.length_squared() < 0.000001:
		return
	side = side.normalized()
	#Law of cosines: angle at the shoulder between the target line and the upper arm
	var cos_angle := (upper_length * upper_length + distance * distance - lower_length * lower_length) \
		/ (2.0 * upper_length * distance)
	var angle := acos(clampf(cos_angle, -1.0, 1.0))
	var new_elbow := shoulder + direction * cos(angle) * upper_length + side * sin(angle) * upper_length

	_aim_bone(skeleton, upper, elbow - shoulder, new_elbow - shoulder)
	var moved_elbow := _global(skeleton, lower).origin
	var moved_wrist := _global(skeleton, end).origin
	_aim_bone(skeleton, lower, moved_wrist - moved_elbow, (shoulder + direction * distance) - moved_elbow)


#Turns a bone (in skeleton space) so the direction "from" becomes "to", keeping its parent
func _aim_bone(skeleton: Skeleton3D, bone: int, from: Vector3, to: Vector3) -> void:
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001:
		return
	var turn := Quaternion(from.normalized(), to.normalized())
	var aimed := turn * _global(skeleton, bone).basis.get_rotation_quaternion()
	var parent := skeleton.get_bone_parent(bone)
	var parent_rotation := Quaternion.IDENTITY
	if parent >= 0:
		parent_rotation = _global(skeleton, parent).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, parent_rotation.inverse() * aimed)


#Pose of a bone in skeleton space, chaining the local poses up to the root
func _global(skeleton: Skeleton3D, bone: int) -> Transform3D:
	var pose := skeleton.get_bone_pose(bone)
	var parent := skeleton.get_bone_parent(bone)
	while parent >= 0:
		pose = skeleton.get_bone_pose(parent) * pose
		parent = skeleton.get_bone_parent(parent)
	return pose
