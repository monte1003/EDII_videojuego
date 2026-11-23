class_name SpectatorView
extends Node3D

#After its own player is done (it reached the goal, the street took it or it fell for good), a computer of a room watches the others until
#the round is over: a camera that follows one of them from behind and above, and at the bottom of the screen who it is with the keys to
#go to the previous or the next one

const DISTANCE := 7.5
const HEIGHT := 4.2
const FOLLOW := 5.0

var _round: RoundScene
var _camera: Camera3D
var _targets: Array[Player] = []
var _index := 0
var _name: Label
var _holder: Control


func begin(round_scene: RoundScene) -> void:
	_round = round_scene
	_camera = Camera3D.new()
	_camera.fov = 62.0
	add_child(_camera)
	_build_overlay()
	_collect()
	if _targets.is_empty():
		return
	var target := _targets[0]
	_camera.global_position = target.global_position + Vector3(0.0, HEIGHT, DISTANCE)
	_camera.make_current()
	_show_name()


func _process(delta: float) -> void:
	_collect()
	if _targets.is_empty():
		return
	_index = posmod(_index, _targets.size())
	var target := _targets[_index]
	var behind := target.look_direction() * -DISTANCE
	var wanted := target.global_position + Vector3(behind.x, HEIGHT, behind.z)
	_camera.global_position = _camera.global_position.lerp(wanted, 1.0 - exp(-FOLLOW * delta))
	_camera.look_at(target.global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP)
	if not _camera.current:
		_camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if _targets.size() < 2:
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("menu_left"):
		_index -= 1
		_show_name()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("menu_right"):
		_index += 1
		_show_name()


#The players of the other computers that are still on the screen
func _collect() -> void:
	_targets.clear()
	for id: int in _round.everyone:
		var player: Player = _round.everyone[id]
		if is_instance_valid(player) and player.remote and player.visible:
			_targets.append(player)


func _show_name() -> void:
	if _targets.is_empty():
		return
	var target := _targets[posmod(_index, _targets.size())]
	var slot := GameSession.lobby.find(target.player_id)
	_name.text = (slot.display_name if slot != null else "JUGADOR %d" % target.player_id).to_upper()
	_holder.modulate.a = 0.0
	create_tween().tween_property(_holder, "modulate:a", 1.0, 0.25)


func _build_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 6
	add_child(overlay)
	_holder = VBoxContainer.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_theme_constant_override("separation", 2)
	_holder.anchor_left = 0.5
	_holder.anchor_right = 0.5
	_holder.anchor_top = 1.0
	_holder.anchor_bottom = 1.0
	_holder.offset_left = -220.0
	_holder.offset_right = 220.0
	_holder.offset_top = -132.0
	overlay.add_child(_holder)
	var caption := _outlined("ESPECTANDO · LOS DEMÁS SIGUEN JUGANDO", UiKit.BUTTON_FONT, 13, Palette.LILAC)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_holder.add_child(caption)
	_name = _outlined("", UiKit.HEADING_FONT, 34, Palette.PAPER)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_holder.add_child(_name)
	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 8)
	keys.add_child(UiKit.action_chip(&"move_left", 14))
	keys.add_child(UiKit.action_chip(&"move_right", 14))
	var word := _outlined("CAMBIAR", UiKit.BUTTON_FONT, 13, Palette.PAPER)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keys.add_child(word)
	_holder.add_child(keys)


func _outlined(text: String, font: Font, size_points: int, color: Color) -> Label:
	var label := UiKit.label(text, font, size_points, color)
	label.add_theme_color_override("font_outline_color", Color(Palette.NIGHT, 0.9))
	label.add_theme_constant_override("outline_size", maxi(roundi(size_points / 5.0), 4))
	return label
