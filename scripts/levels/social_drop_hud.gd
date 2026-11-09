class_name SocialDropHud
extends RoundHud

#The SocialDrop screen: time left, the round and what to do now, and the controls

var _round_label: Label
var _status_label: Label
var _hint_label: RichTextLabel


func _ready() -> void:
	toast_hold = 2.6
	warn_delay = 0.4
	warn_fade = 0.6
	low_time_seconds = 10
	low_time_color = Palette.TEAL
	super()
	_round_label = _text("RONDA –", UiKit.BODY_FONT, 18)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_child(_round_label)
	_top.move_child(_round_label, 1)
	_status_label = _text("", UiKit.BUTTON_FONT, 24)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_child(_status_label)
	_top.move_child(_status_label, 2)
	_hint_label = RichTextLabel.new()
	_hint_label.bbcode_enabled = true
	_hint_label.fit_content = true
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint_label.scroll_active = false
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hint_label.add_theme_font_override("normal_font", UiKit.BUTTON_FONT)
	_hint_label.add_theme_font_size_override("normal_font_size", 22)
	_hint_label.add_theme_color_override("default_color", Palette.PAPER)
	_bottom.add_child(_hint_label)


func set_hint(markup: String) -> void:
	_hint_label.text = markup


#0 before the first spin
func set_round(number: int) -> void:
	_round_label.text = "RONDA %d" % number if number > 0 else "RONDA –"


func set_status(text: String) -> void:
	_status_label.text = text
