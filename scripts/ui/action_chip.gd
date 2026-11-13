class_name ActionChip
extends Control

#The chip of an action that only makes sense now: the key and one word, near the player or over the rival it is aimed at. It
#comes in with a bounce, beats softly while the action is ready, sinks when the key is pressed, shows its recharge as a bar
#that fills under the key and goes away with a fade when there is nothing to do. Every screen has its own chips

const IN_TIME := 0.24
const OUT_TIME := 0.24
const SINK_TIME := 0.12
const BEAT_SPEED := 6.0
const BEAT_SIZE := 0.04
const BAR_HEIGHT := 4.0
const DIM := 0.62

var _row: HBoxContainer
var _key: PanelContainer
var _word: Label
var _caption: Label
var _shown := false
var _charge := 1.0
var _clock := 0.0
var _sink := 0.0
var _hot := false
var _tween: Tween
var _caption_tween: Tween


func _init(key_text: String, word: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)
	_key = UiKit.key_chip(key_text, 18)
	_row.add_child(_key)
	_word = _text(word, UiKit.BUTTON_FONT, 15, Palette.PAPER)
	_row.add_child(_word)
	_caption = _text("", UiKit.BODY_FONT, 17, Palette.GOLD)
	_caption.modulate.a = 0.0
	_row.add_child(_caption)
	_fit.call_deferred()


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_sink = maxf(_sink - delta / SINK_TIME, 0.0)
	var ready := _charge >= 1.0
	var beat := 1.0 + (BEAT_SIZE * sin(_clock * BEAT_SPEED) if ready else 0.0)
	var base := scale.x if _tween != null and _tween.is_running() else 1.0
	if _tween == null or not _tween.is_running():
		scale = Vector2.ONE * beat * (1.0 - 0.14 * _sink)
	else:
		scale = Vector2.ONE * base
	if _charge < 1.0 or _sink > 0.0:
		queue_redraw()


func _draw() -> void:
	if _charge >= 1.0:
		return
	#The recharge: a thin bar under the key that fills from the left
	var width := _key.size.x
	var top := _key.size.y + 5.0
	draw_rect(Rect2(0.0, top, width, BAR_HEIGHT), Color(Palette.NIGHT, 0.55), true)
	draw_rect(Rect2(0.0, top, width * clampf(_charge, 0.0, 1.0), BAR_HEIGHT), Palette.GOLD, true)


#Comes in with a bounce, or goes away with a fade
func set_shown(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if on:
		visible = true
		_fit()
		scale = Vector2.ONE * 0.5
		_tween.set_parallel(true)
		_tween.tween_property(self, "modulate:a", 1.0 if _charge >= 1.0 else DIM, IN_TIME).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector2.ONE, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		SynthSound.play(self, SynthSound.tone(880.0, 0.07, 240.0, 0.3), -14.0)
	else:
		_tween.tween_property(self, "modulate:a", 0.0, OUT_TIME).set_ease(Tween.EASE_IN)
		_tween.tween_callback(hide)


func is_shown() -> bool:
	return _shown


#The key was pressed: the chip sinks for a moment
func press() -> void:
	_sink = 1.0


#How much of the recharge is done, from 0 to 1; while it is not 1 the chip is dim and the bar shows
func set_charge(share: float) -> void:
	var was := _charge
	_charge = clampf(share, 0.0, 1.0)
	if _shown and (_tween == null or not _tween.is_running()):
		modulate.a = 1.0 if _charge >= 1.0 else DIM
	if was < 1.0 and _charge >= 1.0 and _shown:
		_sink = 0.0
	queue_redraw()


#The word of the chip, and whether it is lit (an action that is on right now)
func set_word(word: String, hot := false) -> void:
	if _word.text != word:
		_word.text = word
		_fit()
	if hot != _hot:
		_hot = hot
		_word.add_theme_color_override("font_color", Palette.GOLD if hot else Palette.PAPER)


#A short line next to the chip that says what the action is for; it fades by itself
func teach(text: String, seconds := 3.2) -> void:
	_caption.text = text
	_fit()
	if _caption_tween != null and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption.modulate.a = 0.0
	_caption_tween = create_tween()
	_caption_tween.tween_property(_caption, "modulate:a", 1.0, 0.3)
	_caption_tween.tween_interval(seconds)
	_caption_tween.tween_property(_caption, "modulate:a", 0.0, 0.5)


#The middle of the chip goes to a point of the screen
func place(screen_point: Vector2) -> void:
	position = screen_point - size / 2.0


func _fit() -> void:
	if _row == null:
		return
	size = _row.get_combined_minimum_size()
	pivot_offset = size / 2.0


#White text with a dark outline, as in the rest of the screens of a round
func _text(text: String, font: Font, size_points: int, color: Color) -> Label:
	var label := UiKit.label(text, font, size_points, color)
	label.add_theme_color_override("font_outline_color", Color(Palette.NIGHT, 0.88))
	label.add_theme_constant_override("outline_size", maxi(roundi(size_points / 6.0), 3))
	return label
