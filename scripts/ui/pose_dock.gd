class_name PoseDock
extends CanvasLayer

#The pose key, always at the bottom of the screen during a round: the key and one word in white. It dims while the pose cannot be
#struck (in the air, dazed), turns gold and breathes while the player poses, sinks when the key is pressed and hides when the round
#is over. "source" says the state every frame

enum State { HIDDEN, BLOCKED, READY, POSING }

const BOTTOM := 26.0
const FADE := 0.22
const BLOCKED_ALPHA := 0.38
const READY_ALPHA := 0.9
const SINK_TIME := 0.14

var source: Callable = func() -> int: return State.HIDDEN

var _holder: Control
var _row: HBoxContainer
var _key: PanelContainer
var _word: Label
var _state := State.HIDDEN
var _clock := 0.0
var _sink := 0.0
var _glow := 0.0


func _init() -> void:
	layer = 6
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.modulate.a = 0.0
	add_child(_holder)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 10)
	_holder.add_child(_row)
	_key = UiKit.key_chip(InputHints.key_label(&"interact"), 17)
	_row.add_child(_key)
	_word = UiKit.label("POSAR", UiKit.BUTTON_FONT, 15, Palette.PAPER)
	_word.add_theme_color_override("font_outline_color", Color(Palette.NIGHT, 0.88))
	_word.add_theme_constant_override("outline_size", 4)
	_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row.add_child(_word)
	_holder.draw.connect(_draw_glow)


func _process(delta: float) -> void:
	_clock += delta
	_sink = maxf(_sink - delta / SINK_TIME, 0.0)
	var next: int = source.call()
	if next != _state:
		_state = next as State
		_word.text = "POSANDO" if _state == State.POSING else "POSAR"
		_word.add_theme_color_override("font_color", Palette.GOLD if _state == State.POSING else Palette.PAPER)
	var target := 0.0
	match _state:
		State.BLOCKED:
			target = BLOCKED_ALPHA
		State.READY, State.POSING:
			target = READY_ALPHA
	_holder.modulate.a = move_toward(_holder.modulate.a, target, delta / FADE)
	_glow = move_toward(_glow, 1.0 if _state == State.POSING else 0.0, delta / FADE)
	var view := _holder.get_viewport_rect().size
	var size := _row.get_combined_minimum_size()
	_row.size = size
	_holder.size = size
	_holder.pivot_offset = size / 2.0
	_holder.position = Vector2((view.x - size.x) / 2.0, view.y - BOTTOM - size.y)
	var breath := 1.0 + 0.035 * sin(_clock * 5.0) * _glow
	_holder.scale = Vector2.ONE * breath * (1.0 - 0.1 * _sink)
	_holder.queue_redraw()


#The key was pressed: the dock sinks for a moment
func press() -> void:
	_sink = 1.0


#While the player poses, a thin gold line under the word that grows from its middle
func _draw_glow() -> void:
	if _glow <= 0.01:
		return
	var left := _word.position.x
	var width := _word.size.x * _glow
	var top := _row.size.y + 3.0
	var middle := left + _word.size.x / 2.0
	_holder.draw_rect(Rect2(middle - width / 2.0, top, width, 3.0), Color(Palette.GOLD, 0.9 * _glow), true)
