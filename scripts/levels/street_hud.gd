class_name StreetHud
extends RoundHud

var _speed_label: Label
var _danger_bar: ProgressBar
var _danger_fill: StyleBoxFlat
var _hint_label: RichTextLabel
var _play_ui: Control


func _ready() -> void:
	super()
	toast_hold = 2.6
	warn_delay = 0.3
	warn_fade = 0.7
	low_time_seconds = 10
	low_time_color = Palette.TEAL
	var root := _make_root(22)
	_play_ui = root

	var top := _hbox()
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(top)
	top.add_child(_build_status_card())
	var top_center := _vbox(8)
	top_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_center)
	top_center.add_child(_make_toast())
	top_center.add_child(_make_warning())
	top.add_child(_build_danger_card())

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

	_make_countdown()
	_make_end("REINTENTAR")


#Hides the cards and hints during the victory close-up; the end panel is separate
func hide_play_ui() -> void:
	create_tween().tween_property(_play_ui, "modulate:a", 0.0, 0.3)


func set_hint(markup: String) -> void:
	_hint_label.text = markup


func set_speed(multiplier: float) -> void:
	_speed_label.text = "x%.1f" % multiplier


#0 is the start position, 1 is the end line
func set_danger(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	_danger_bar.value = ratio
	_danger_fill.bg_color = Palette.CORAL if ratio >= 0.66 else Palette.AMBER if ratio >= 0.33 else Palette.TEAL


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override("panel", _card_style())
	return card


func _build_status_card() -> PanelContainer:
	var card := _card()
	var row := _hbox(16)
	card.add_child(row)
	_timer_label = _label("1:00", HEADING_FONT, 46, Palette.INK)
	_timer_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(_timer_label)
	var column := _vbox()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	column.add_child(_label("VELOCIDAD", HEADING_FONT, 18, Palette.INK_SOFT))
	_speed_label = _label("x1.0", HEADING_FONT, 26, Palette.INK)
	column.add_child(_speed_label)
	return card


func _build_danger_card() -> PanelContainer:
	var card := _card()
	var column := _vbox(6)
	card.add_child(column)
	column.add_child(_label("CERCA DEL FIN", HEADING_FONT, 18, Palette.INK_SOFT))
	_danger_bar = ProgressBar.new()
	_danger_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_bar.custom_minimum_size = Vector2(220, 22)
	_danger_bar.min_value = 0.0
	_danger_bar.max_value = 1.0
	_danger_bar.step = 0.0
	_danger_bar.show_percentage = false
	_danger_bar.add_theme_stylebox_override("background", _box(Color(Palette.INK, 0.15), 11))
	_danger_fill = _box(Palette.TEAL, 11)
	_danger_bar.add_theme_stylebox_override("fill", _danger_fill)
	column.add_child(_danger_bar)
	return card
