class_name TrendHud
extends RoundHud

#The trend war screen: the clock of the zone and, under it, the trend the player follows now as one big chip with the count of the trends
#completed beside it. When a zone is announced its name shows for a moment, and an arrow on the edge points to the zone while it is out
#of view. Nothing else

const SLOT := 72.0
const POP_SCALE := 1.6
#How far under the middle of the screen the name of the zone sits
const ZONE_DROP := 90.0

var _strip: TrendStrip
var _count: Label
var _pop: Tween
var _zone_label: Label
var _zone_tween: Tween
var _pointer: TrendPointer


func _ready() -> void:
	low_time_seconds = 5
	low_time_beat = true
	toast_hold = 1.4
	super()
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size = Vector2(0, SLOT + 8.0)
	_top.add_child(row)
	_top.move_child(row, 1)
	_strip = TrendStrip.new()
	_strip.slot = SLOT
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_strip)
	_count = _text("0", UiKit.BUTTON_FONT, 34)
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_count)
	_zone_label = _text("", UiKit.BUTTON_FONT, 40, Palette.GOLD)
	_zone_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_zone_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_zone_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_zone_label.offset_top += ZONE_DROP
	_zone_label.offset_bottom += ZONE_DROP
	_zone_label.modulate.a = 0.0
	add_child(_zone_label)
	_pointer = TrendPointer.new()
	add_child(_pointer)
	_strip.hide()


#The name of a zone that is announced pops in under the middle of the screen in its colour and fades after "seconds"
func show_zone(title: String, color: Color, seconds: float) -> void:
	_zone_label.text = title
	_zone_label.add_theme_color_override("font_color", color)
	_pointer.color = color
	if _zone_tween != null and _zone_tween.is_valid():
		_zone_tween.kill()
	_zone_label.pivot_offset = _zone_label.size / 2.0
	_zone_label.scale = Vector2.ONE * 1.4
	_zone_label.modulate.a = 1.0
	_zone_tween = create_tween()
	_zone_tween.tween_property(_zone_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_zone_tween.tween_interval(maxf(seconds - 0.8, 0.2))
	_zone_tween.tween_property(_zone_label, "modulate:a", 0.0, 0.5)


#The arrow toward the zone, aimed with the camera of the player of this screen
func point_zone(camera: Camera3D, target: Vector3, wanted: bool) -> void:
	_pointer.aim(camera, target, wanted)


#The trend to follow now: its chip pops in big and settles
func set_trend(kind: int) -> void:
	var chain: Array[int] = [kind]
	_strip.set_chain(chain)
	_strip.show()
	if _pop != null and _pop.is_valid():
		_pop.kill()
	_strip.pivot_offset = _strip.custom_minimum_size / 2.0
	_strip.scale = Vector2.ONE * POP_SCALE
	_pop = create_tween()
	_pop.tween_property(_strip, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


#How many trends it completed; the number jumps when it grows
func set_count(count: int) -> void:
	_count.text = str(count)
	_count.pivot_offset = _count.size / 2.0
	var jump := create_tween()
	jump.tween_property(_count, "scale", Vector2.ONE * 1.4, 0.08)
	jump.tween_property(_count, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
