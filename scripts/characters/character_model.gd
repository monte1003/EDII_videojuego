class_name CharacterModel
extends Node3D

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

@onready var _animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_prepare(idle_animation, Animation.LOOP_LINEAR)
	_prepare(move_animation, Animation.LOOP_LINEAR)
	_prepare(jump_animation, Animation.LOOP_NONE)
	_prepare(land_animation, Animation.LOOP_NONE)
	_animation_player.play(idle_animation)


func set_state(moving: bool, airborne: bool) -> void:
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


func _is_landing() -> bool:
	return _animation_player.assigned_animation == land_animation and _animation_player.is_playing()


#Meshy animations can scale the hips, which changes the character size
func _prepare(animation_name: StringName, loop: Animation.LoopMode) -> void:
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		push_error("CharacterModel: falta la animación %s" % animation_name)
		return
	animation.loop_mode = loop
	for track in range(animation.get_track_count() - 1, -1, -1):
		if animation.track_get_type(track) == Animation.TYPE_SCALE_3D:
			animation.remove_track(track)
