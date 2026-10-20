class_name StreetHud
extends CanvasLayer

#HUD of the street minigame: time left, speed of the flow, how close the runner is to the
#end line, toasts, the countdown and the end panel. Same look as LevelHud.

signal retry_requested
signal menu_requested

const TEXT_BUTTON := preload("res://scenes/ui/text_button.tscn")
const HEADING_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
const BODY_FONT: Font = preload("res://assets/ui/fonts/body_font.tres")
const LILAC := Color("cdbcf7")

var _timer_label: Label
var _speed_label: Label
var _danger_bar: ProgressBar
var _danger_fill: StyleBoxFlat
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _warning: Label
var _hint_label: RichTextLabel
var _countdown: Label
var _end: Control
var _end_title: Label
var _end_message: Label
var _end_first_button: TextButton
var _play_ui: Control


func _ready() -> void:
	layer = 5
	var root := MarginContainer.new()
	_play_ui = root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_top", "margin_bottom", "margin_left", "margin_right"]:
		root.add_theme_constant_override(side, 22)
	add_child(root)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(top)
	top.add_child(_build_status_card())
	var top_center := VBoxContainer.new()
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_center.add_theme_constant_override("separation", 8)
	top.add_child(top_center)
	_toast = _build_pill(Palette.TEAL, 24, Palette.PAPER)
	_toast_label = _toast.get_child(0) as Label
	_toast.modulate.a = 0.0
	top_center.add_child(_toast)
	_warning = _label("", HEADING_FONT, 44, Color("ffd23f"))
	_warning.add_theme_color_override("font_outline_color", Palette.EDGE)
	_warning.add_theme_constant_override("outline_size", 12)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_warning.modulate.a = 0.0
	top_center.add_child(_warning)
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

	_countdown = _label("", HEADING_FONT, 140, Palette.PAPER)
	_countdown.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_countdown.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_countdown.grow_vertical = Control.GROW_DIRECTION_BOTH
	_countdown.add_theme_color_override("font_outline_color", Palette.PILL)
	_countdown.add_theme_constant_override("outline_size", 24)
	_countdown.hide()
	add_child(_countdown)

	_end = _build_end()


#---- public API ------------------------------------------------------------------------

#Hides the cards and hints during the victory close-up; the end panel is separate
func hide_play_ui() -> void:
	create_tween().tween_property(_play_ui, "modulate:a", 0.0, 0.3)


func set_hint(markup: String) -> void:
	_hint_label.text = markup


func set_time(seconds: float) -> void:
	var whole := int(ceil(maxf(seconds, 0.0)))
	_timer_label.text = "%d:%02d" % [floori(whole / 60.0), whole % 60]
	_timer_label.add_theme_color_override("font_color", Palette.TEAL if whole <= 10 else Palette.INK)


func set_speed(multiplier: float) -> void:
	_speed_label.text = "x%.1f" % multiplier


#0 is the start position, 1 is the end line
func set_danger(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	_danger_bar.value = ratio
	_danger_fill.bg_color = Palette.CORAL if ratio >= 0.66 else Palette.AMBER if ratio >= 0.33 else Palette.TEAL


func show_countdown(text: String) -> void:
	_countdown.text = text
	_countdown.show()
	_countdown.pivot_offset = _countdown.size / 2.0
	_countdown.scale = Vector2.ONE * 1.3
	create_tween().tween_property(_countdown, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_countdown() -> void:
	_countdown.hide()


func toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


#A short flash, used when the runner gets hit
func warn(text: String) -> void:
	_warning.text = text
	_warning.modulate.a = 1.0
	create_tween().tween_property(_warning, "modulate:a", 0.0, 0.7).set_delay(0.3)


func show_end(title: String, message: String, victory: bool) -> void:
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", Palette.TEAL if victory else Palette.CORAL)
	_end_message.text = message
	_end.show()
	_end_first_button.grab_focus()


#---- builders --------------------------------------------------------------------------

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.corner_detail = 12
	return style


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_pill(color: Color, size: int, text_color: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := _box(color, 100)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	pill.add_theme_stylebox_override("panel", style)
	pill.add_child(_label("", HEADING_FONT, size, text_color))
	return pill


func _card_style(alpha := 0.94) -> StyleBoxFlat:
	var style := _box(Color(Palette.PAPER, alpha), 28)
	style.set_border_width_all(2)
	style.border_color = LILAC
	style.content_margin_left = 20
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	style.shadow_size = 12
	style.shadow_color = Color(Palette.INK, 0.25)
	return style


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override("panel", _card_style())
	return card


func _build_status_card() -> PanelContainer:
	var card := _card()
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	_timer_label = _label("1:00", HEADING_FONT, 46, Palette.INK)
	_timer_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(_timer_label)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	column.add_child(_label("VELOCIDAD", HEADING_FONT, 18, Palette.INK_SOFT))
	_speed_label = _label("x1.0", HEADING_FONT, 26, Palette.INK)
	column.add_child(_speed_label)
	return card


func _build_danger_card() -> PanelContainer:
	var card := _card()
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
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


func _make_button(text: String, on_pressed: Signal) -> TextButton:
	var button := TEXT_BUTTON.instantiate() as TextButton
	button.text = text
	button.custom_minimum_size = Vector2(380, 56)
	button.pressed.connect(on_pressed.emit)
	return button


func _build_end() -> Control:
	var holder := CanvasLayer.new()
	holder.layer = 12
	add_child(holder)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.06, 0.05, 0.14, 0.5)
	overlay.hide()
	holder.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var card := PanelContainer.new()
	var style := _card_style(0.97)
	style.set_corner_radius_all(36)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 30
	style.content_margin_bottom = 34
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	_end_title = _label("", HEADING_FONT, 50, Palette.INK)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_title)
	_end_message = _label("", BODY_FONT, 22, Palette.INK_SOFT)
	_end_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_message.custom_minimum_size = Vector2(560, 0)
	box.add_child(_end_message)
	_end_first_button = _make_button("REINTENTAR", retry_requested)
	box.add_child(_end_first_button)
	box.add_child(_make_button("VOLVER AL MENÚ", menu_requested))
	return overlay
