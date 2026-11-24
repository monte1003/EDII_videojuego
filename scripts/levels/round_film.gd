class_name RoundFilm
extends Node3D

#The opening of a round, like a broadcast: black bars come in, a film camera flies over the map in a few shots while the name of the
#minigame slides in, and then it swoops down to the camera of the player, where the countdown takes over. Enter skips it

signal finished

const BAR_SHARE := 0.1
const HANDOFF_TIME := 1.4

#A shot: where the camera starts and what it looks at, where it ends and what it looks at then, and how long it takes
class Shot:
	var from_at: Vector3
	var from_look: Vector3
	var to_at: Vector3
	var to_look: Vector3
	var seconds: float

	func _init(start_at: Vector3, start_look: Vector3, end_at: Vector3, end_look: Vector3, length: float) -> void:
		from_at = start_at
		from_look = start_look
		to_at = end_at
		to_look = end_look
		seconds = length


var _camera: CinemaCamera
var _overlay: CanvasLayer
var _bars: Array[ColorRect] = []
var _card: VBoxContainer
var _hint: Control
#In a room the film cannot be skipped: it plays at once on every computer and the countdown starts after it on all of them
var skippable := true
var _skipped := false
var _over := false
var _timer: Timer


#Plays the shots, shows the title and lands on "handoff"
#Seconds a film of these shots takes when nobody skips it: every shot and the flight down to the player
static func length_of(shots: Array[Shot]) -> float:
	if shots.is_empty():
		return 0.0
	var seconds := HANDOFF_TIME
	for shot in shots:
		seconds += maxf(shot.seconds - 0.05, 0.01)
	return seconds


func play(shots: Array[Shot], title: String, tagline: String, step: String, handoff: Camera3D) -> void:
	_camera = CinemaCamera.new()
	_camera.fov = 62.0
	add_child(_camera)
	_camera.make_current()
	_build_overlay(title, tagline, step)
	_letterbox(true, 0.6)
	_show_card(0.9)
	for index in shots.size():
		var shot := shots[index]
		_camera.place(shot.from_at, shot.from_look)
		_camera.glide(shot.to_at, shot.to_look, shot.seconds, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		if index > 0:
			SynthSound.play(self, SynthSound.whoosh(0.5), -16.0)
		if await _hold(shot.seconds - 0.05):
			break
	_hide_card()
	if not _skipped and is_instance_valid(handoff):
		var target := handoff.global_transform
		_camera.glide(target.origin, target.origin - target.basis.z * 12.0, HANDOFF_TIME, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
		_camera.zoom_to(handoff.fov, HANDOFF_TIME)
		SynthSound.play(self, SynthSound.whoosh(HANDOFF_TIME), -11.0)
		await _hold(HANDOFF_TIME)
	_end(handoff)


func _unhandled_input(event: InputEvent) -> void:
	if skippable and event.is_action_pressed("menu_confirm") and not _skipped:
		get_viewport().set_input_as_handled()
		_skipped = true
		if _timer != null:
			_timer.stop()
			_timer.timeout.emit()


func _end(handoff: Camera3D) -> void:
	if _over:
		return
	_over = true
	if is_instance_valid(handoff):
		handoff.make_current()
	_letterbox(false, 0.35)
	var away := create_tween()
	away.tween_interval(0.4)
	away.tween_callback(queue_free)
	finished.emit()


#Waits on a timer of the film (Enter ends it early); true when Enter asked to skip. A wait still running when the round closes never ends
func _hold(seconds: float) -> bool:
	if _skipped:
		return true
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = maxf(seconds, 0.01)
	add_child(_timer)
	_timer.start()
	await _timer.timeout
	_timer.queue_free()
	_timer = null
	return _skipped


func _build_overlay(title: String, tagline: String, step: String) -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 9
	add_child(_overlay)
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if not top:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
		_overlay.add_child(bar)
		_bars.append(bar)
	_card = VBoxContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_constant_override("separation", -2)
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = 80.0
	_card.offset_top = -270.0
	_card.modulate.a = 0.0
	_overlay.add_child(_card)
	if step != "":
		_card.add_child(_outlined(step, UiKit.BUTTON_FONT, 16, Palette.LILAC))
	_card.add_child(_outlined(title.to_upper(), UiKit.HEADING_FONT, 62, Palette.PAPER))
	if tagline != "":
		_card.add_child(_outlined(tagline, UiKit.BUTTON_FONT, 17, Palette.GOLD))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiKit.action_chip(&"menu_confirm", 13, "ENTER"))
	row.add_child(_outlined("SALTAR", UiKit.BUTTON_FONT, 13, Palette.PAPER))
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -190.0
	row.offset_top = -46.0
	row.modulate.a = 0.55 if skippable else 0.0
	_overlay.add_child(row)
	_hint = row


func _letterbox(on: bool, seconds: float) -> void:
	var height := get_viewport().get_visible_rect().size.y * (BAR_SHARE if on else 0.0)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_bars[0], "offset_bottom", height, seconds)
	tween.tween_property(_bars[1], "offset_top", -height, seconds)
	if not on:
		tween.tween_property(_hint, "modulate:a", 0.0, seconds)


#The name of the minigame slides up at the bottom left after a moment
func _show_card(delay: float) -> void:
	_card.position.y += 40.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, 0.5).set_delay(delay)
	tween.tween_property(_card, "position:y", _card.position.y - 40.0, 0.7).set_delay(delay)


func _hide_card() -> void:
	create_tween().tween_property(_card, "modulate:a", 0.0, 0.3)


func _outlined(text: String, font: Font, size_points: int, color: Color) -> Label:
	var label := UiKit.label(text, font, size_points, color)
	label.add_theme_color_override("font_outline_color", Color(Palette.NIGHT, 0.9))
	label.add_theme_constant_override("outline_size", maxi(roundi(size_points / 5.0), 4))
	return label
