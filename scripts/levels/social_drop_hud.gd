class_name SocialDropHud
extends RoundHud

#The SocialDrop screen: time left, the round and what to do now, and the controls

var _round_label: Label
var _status_label: Label
var _hint_label: RichTextLabel


func _ready() -> void:
	super()
	toast_hold = 2.6
	warn_delay = 0.4
	warn_fade = 0.6
	low_time_seconds = 10
	low_time_color = Palette.TEAL
	var root := _make_root(22)

	var top := _hbox()
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(top)
	top.add_child(_build_status_card())
	var top_center := _vbox(8)
	top_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_center)
	top_center.add_child(_make_toast())
	top_center.add_child(_make_warning())

	var hint := _build_pill(Palette.INK, 22, Palette.PAPER)
	hint.get_child(0).queue_free()
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	_hint_label = RichTextLabel.new()
	_hint_label.bbcode_enabled = true
	_hint_label.fit_content = true
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint_label.scroll_active = false
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.add_theme_font_override("normal_font", HEADING_FONT)
	_hint_label.add_theme_font_size_override("normal_font_size", 22)
	_hint_label.add_theme_color_override("default_color", Palette.PAPER)
	hint.add_child(_hint_label)
	root.add_child(hint)

	_make_end("REINTENTAR")


func set_hint(markup: String) -> void:
	_hint_label.text = markup


#0 before the first spin
func set_round(number: int) -> void:
	_round_label.text = "RONDA %d" % number if number > 0 else "RONDA –"


func set_status(text: String) -> void:
	_status_label.text = text


func _build_status_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override("panel", _card_style())
	var row := _hbox(16)
	card.add_child(row)
	_timer_label = _label("1:00", HEADING_FONT, 46, Palette.INK)
	_timer_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(_timer_label)
	var column := _vbox()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	_round_label = _label("RONDA –", HEADING_FONT, 18, Palette.INK_SOFT)
	column.add_child(_round_label)
	_status_label = _label("", HEADING_FONT, 24, Palette.INK)
	_status_label.custom_minimum_size = Vector2(250, 0)
	column.add_child(_status_label)
	return card
