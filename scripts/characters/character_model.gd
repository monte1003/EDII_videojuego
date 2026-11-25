class_name CharacterModel
extends Node3D

#Dive in three parts, shove, stagger and photo poses
const DIVE := &"dive/Dive"
const SLIDE := &"dive/Slide"
const RISE := &"dive/Rise"
const SHOVE := &"shove/Shove"
const STAGGER := &"shove/Stagger"
const POSES: Array[StringName] = [&"poses/Tada", &"poses/Lean", &"poses/Letters", &"poses/Jazz", &"poses/Funny", &"poses/Beats"]
#Extra moves next to the model: <id>_dive.res, <id>_shove.res and <id>_poses.res
const MOVE_LIBRARIES: Array[StringName] = [&"dive", &"shove", &"poses"]

@export var idle_animation: StringName
@export var move_animation: StringName
@export var jump_animation: StringName
@export var land_animation: StringName
@export var blend_time := 0.15
#Jump and fall blend in almost at once
@export var snap_blend_time := 0.06
#Run sped up so the feet do not slide
@export var move_speed_scale := 1.6

var _was_airborne := false
#Extra move over the four states, and whether it is held
var _move: StringName = &""
var _move_held := false

@onready var _animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_prepare(idle_animation, Animation.LOOP_LINEAR)
	_prepare(move_animation, Animation.LOOP_LINEAR)
	_prepare(jump_animation, Animation.LOOP_NONE)
	_prepare(land_animation, Animation.LOOP_NONE)
	_load_moves()
	_animation_player.play(idle_animation)


func set_state(moving: bool, airborne: bool) -> void:
	if _move != &"":
		if _move_held or _animation_player.is_playing():
			_was_airborne = airborne
			return
		_move = &""
	var target := move_animation if moving else idle_animation
	if airborne:
		target = jump_animation
	elif _was_airborne and not moving:
		target = land_animation
	elif _is_landing() and not moving:
		return
	_was_airborne = airborne
	#Compare with the assigned animation so a long jump does not restart while falling
	if _animation_player.assigned_animation != target:
		var blend := snap_blend_time if target in [jump_animation, land_animation] else blend_time
		var speed := move_speed_scale if target == move_animation else 1.0
		_animation_player.play(target, blend, speed)


func has_move(move: StringName) -> bool:
	return _animation_player.has_animation(move)


#Plays an extra move; held, it stays until stop_move; false if missing
func play_move(move: StringName, held := false, blend := 0.08, speed := 1.0) -> bool:
	if not has_move(move):
		return false
	_move = move
	_move_held = held
	_animation_player.play(move, blend, speed)
	return true


func stop_move() -> void:
	_move = &""
	_move_held = false


func is_in_move() -> bool:
	return _move != &""


func pose_count() -> int:
	var count := 0
	for pose in POSES:
		if has_move(pose):
			count += 1
	return count


func _is_landing() -> bool:
	return _animation_player.assigned_animation == land_animation and _animation_player.is_playing()


func _load_moves() -> void:
	var base := ($Model as Node).scene_file_path.get_basename()
	for library in MOVE_LIBRARIES:
		var path := "%s_%s.res" % [base, library]
		if not _animation_player.has_animation_library(library) and ResourceLoader.exists(path):
			_animation_player.add_animation_library(library, load(path) as AnimationLibrary)


#Some animations scale the hips
func _prepare(animation_name: StringName, loop: Animation.LoopMode) -> void:
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		push_error("CharacterModel: falta la animación %s" % animation_name)
		return
	animation.loop_mode = loop
	for track in range(animation.get_track_count() - 1, -1, -1):
		if animation.track_get_type(track) == Animation.TYPE_SCALE_3D:
			animation.remove_track(track)
