class_name TrendHud
extends RoundHud

#The trend war screen: the clock of the trend and, under it, the trend itself as a row of icons. Nothing else

const SLOT := 64.0
const REVEAL_SCALE := 2.1

var _strip: TrendStrip
var _holder: CenterContainer
var _reveal: Tween


func _ready() -> void:
	low_time_seconds = 5
	low_time_beat = true
	toast_hold = 1.4
	super()
	_holder = CenterContainer.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.custom_minimum_size = Vector2(0, SLOT + 8.0)
	_top.add_child(_holder)
	_top.move_child(_holder, 1)
	_strip = TrendStrip.new()
	_strip.slot = SLOT
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_strip)


#A new trend: it shows big for a moment and settles under the clock
func show_trend(chain: Array[int], seconds: float) -> void:
	_strip.set_chain(chain)
	if _reveal != null and _reveal.is_valid():
		_reveal.kill()
	_strip.pivot_offset = Vector2(_strip.custom_minimum_size.x / 2.0, 0.0)
	_strip.scale = Vector2.ONE * REVEAL_SCALE
	_strip.modulate.a = 0.0
	_reveal = create_tween()
	_reveal.tween_property(_strip, "modulate:a", 1.0, 0.15)
	_reveal.tween_interval(maxf(seconds - 0.65, 0.1))
	_reveal.tween_property(_strip, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_done(count: int) -> void:
	_strip.set_done(count)


#The trend ran out without being completed: the row shakes and dims
func miss() -> void:
	var home := _strip.position
	var shake := create_tween()
	for offset: float in [8.0, -7.0, 5.0, -3.0, 0.0]:
		shake.tween_property(_strip, "position:x", home.x + offset, 0.05)
	shake.tween_property(_strip, "modulate:a", 0.35, 0.25)
