class_name CharacterModel
extends Node3D

@export var idle_animation: StringName
@export var walk_animation: StringName
@export var blend_time := 0.2

@onready var _animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	for animation_name in [idle_animation, walk_animation]:
		var animation := _animation_player.get_animation(animation_name)
		animation.loop_mode = Animation.LOOP_LINEAR
		_remove_scale_tracks(animation)
	_animation_player.play(idle_animation)


func set_moving(moving: bool) -> void:
	var target := walk_animation if moving else idle_animation
	if _animation_player.current_animation != target:
		_animation_player.play(target, blend_time)


#Meshy animations can scale the hips, which changes the character size
func _remove_scale_tracks(animation: Animation) -> void:
	for track in range(animation.get_track_count() - 1, -1, -1):
		if animation.track_get_type(track) == Animation.TYPE_SCALE_3D:
			animation.remove_track(track)
