class_name CharacterModel
extends Node3D

@export var idle_animation: StringName
@export var walk_animation: StringName
@export var blend_time := 0.2

@onready var _animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_animation_player.get_animation(idle_animation).loop_mode = Animation.LOOP_LINEAR
	_animation_player.get_animation(walk_animation).loop_mode = Animation.LOOP_LINEAR
	_animation_player.play(idle_animation)


func set_moving(moving: bool) -> void:
	var target := walk_animation if moving else idle_animation
	if _animation_player.current_animation != target:
		_animation_player.play(target, blend_time)
