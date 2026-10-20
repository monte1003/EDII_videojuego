class_name BotModel
extends BotLook

#Final bot model: idle and run while it walks, a wind-up while it warns and a shove when it hits

@export var idle_animation: StringName = &"idle/Idle"
@export var run_animation: StringName = &"run/Running"
@export var alert_animation: StringName = &"alert/Alert"
@export var push_animation: StringName = &"push/Push"
@export var blend_time := 0.12
@export var run_speed_scale := 1.6

var _moving := false
var _alerting := false
var _pushing := false

@onready var _animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	super()
	_prepare(idle_animation, Animation.LOOP_LINEAR)
	_prepare(run_animation, Animation.LOOP_LINEAR)
	_prepare(alert_animation, Animation.LOOP_NONE)
	_prepare(push_animation, Animation.LOOP_NONE)
	_animation_player.animation_finished.connect(_on_animation_finished)
	_refresh()


func set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	_refresh()


func set_alert(active: bool) -> void:
	super(active)
	_alerting = active
	_refresh()


func play_push() -> void:
	_pushing = true
	_play(push_animation, 0.04)


func _refresh() -> void:
	if _pushing:
		return
	if _alerting:
		_play(alert_animation, blend_time)
	elif _moving:
		_play(run_animation, blend_time)
	else:
		_play(idle_animation, blend_time)


func _play(animation_name: StringName, blend: float) -> void:
	if _animation_player.assigned_animation == animation_name and _animation_player.is_playing():
		return
	var speed := run_speed_scale if animation_name == run_animation else 1.0
	_animation_player.play(animation_name, blend, speed)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == push_animation:
		_pushing = false
		_refresh()


#Meshy animations can scale the hips, which changes the character size
func _prepare(animation_name: StringName, loop: Animation.LoopMode) -> void:
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		push_error("BotModel: falta la animación %s" % animation_name)
		return
	animation.loop_mode = loop
	for track in range(animation.get_track_count() - 1, -1, -1):
		if animation.track_get_type(track) == Animation.TYPE_SCALE_3D:
			animation.remove_track(track)
