class_name CharacterModel
extends Node3D

#The dive, in its three parts, the shove and the stagger of whoever takes it, and the poses and dances of a photo
const DIVE := &"dive/Dive"
const SLIDE := &"dive/Slide"
const RISE := &"dive/Rise"
const SHOVE := &"shove/Shove"
const STAGGER := &"shove/Stagger"
const POSES: Array[StringName] = [&"poses/Tada", &"poses/Lean", &"poses/Letters", &"poses/Jazz", &"poses/Funny", &"poses/Beats"]
#The extra moves of a character live next to its model, one library per file: <id>_dive.res, <id>_shove.res and <id>_poses.res
const MOVE_LIBRARIES: Array[StringName] = [&"dive", &"shove", &"poses"]

@export var idle_animation: StringName
@export var move_animation: StringName
@export var jump_animation: StringName
@export var land_animation: StringName
@export var blend_time := 0.15
#El salto y la caida entran casi de golpe: con la mezcla normal llegan tarde
@export var snap_blend_time := 0.06
#La carrera va mas rapida que como viene: a su ritmo original los pies patinan mucho
@export var move_speed_scale := 1.6

var _was_airborne := false
#The extra move that plays over the four states, and whether it stays until somebody stops it
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
		#A move that is not held gives way to the states as soon as it ends
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
	#Se compara con la animacion asignada y no con la que suena: asi un salto largo
	#no vuelve a empezar cuando su animacion ya termino y el personaje sigue cayendo
	if _animation_player.assigned_animation != target:
		var blend := snap_blend_time if target in [jump_animation, land_animation] else blend_time
		var speed := move_speed_scale if target == move_animation else 1.0
		_animation_player.play(target, blend, speed)


func has_move(move: StringName) -> bool:
	return _animation_player.has_animation(move)


#Plays an extra move over the states. Held, it stays in its last frame (or keeps looping) until stop_move; otherwise the states
#come back when it ends. False when this character does not have it
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


#How many poses and dances this character has for a photo
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


#Some animations scale the hips, which changes the character size
func _prepare(animation_name: StringName, loop: Animation.LoopMode) -> void:
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		push_error("CharacterModel: falta la animación %s" % animation_name)
		return
	animation.loop_mode = loop
	for track in range(animation.get_track_count() - 1, -1, -1):
		if animation.track_get_type(track) == Animation.TYPE_SCALE_3D:
			animation.remove_track(track)
