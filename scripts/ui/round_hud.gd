class_name RoundHud
extends CanvasLayer

#Shared base of the in-round screens: toast, warning flash, countdown, end panel

signal retry_requested
signal menu_requested

const HEADING_FONT := UiKit.HEADING_FONT
const BODY_FONT := UiKit.BODY_FONT

var toast_hold := 3.2
var toast_fade := 0.5
var warn_delay := 0.5
var warn_fade := 0.9
var low_time_seconds := 20
var low_time_color := Palette.CORAL

var _timer_label: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _warning: Label
var _countdown: Label
var _end: Control
var _end_title: Label
var _end_message: Label
var _end_first_button: GameButton


func _ready() -> void:
	layer = 5


func show_countdown(text: String) -> void:
	_countdown.text = text
	_countdown.show()
	_countdown.pivot_offset = _countdown.size / 2.0
	_countdown.scale = Vector2.ONE * 1.3
	create_tween().tween_property(_countdown, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_countdown() -> void:
	_countdown.hide()


func set_time(seconds: float) -> void:
	var whole := int(ceil(maxf(seconds, 0.0)))
	_timer_label.text = "%d:%02d" % [floori(whole / 60.0), whole % 60]
	_timer_label.add_theme_color_override("font_color", low_time_color if whole <= low_time_seconds else Palette.INK)


func toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(toast_hold)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, toast_fade)


func warn(text: String) -> void:
	_warning.text = text
	_warning.modulate.a = 1.0
	create_tween().tween_property(_warning, "modulate:a", 0.0, warn_fade).set_delay(warn_delay)


func show_end(title: String, message: String, victory: bool) -> void:
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", Palette.TEAL if victory else Palette.CORAL)
	_end_message.text = message
	_end.show()
	_end_first_button.grab_focus()


func _make_root(margin: int) -> MarginContainer:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_top", "margin_bottom", "margin_left", "margin_right"]:
		root.add_theme_constant_override(side, margin)
	add_child(root)
	return root


func _hbox(separation := -1) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if separation >= 0:
		box.add_theme_constant_override("separation", separation)
	return box


func _vbox(separation := -1) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if separation >= 0:
		box.add_theme_constant_override("separation", separation)
	return box


func _box(color: Color, radius: int) -> StyleBoxFlat:
	return UiKit.box(color, radius)


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	return UiKit.label(text, font, size, color)


func _rich(size: int, color: Color) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.add_theme_font_override("normal_font", BODY_FONT)
	rich.add_theme_font_size_override("normal_font_size", size)
	rich.add_theme_color_override("default_color", color)
	return rich


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
	return UiKit.card_style(alpha)


#A dimmed full-screen layer with a centered container named "Center"
func _overlay(alpha: float) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(Palette.NIGHT, alpha)
	overlay.hide()
	var holder := CanvasLayer.new()
	holder.layer = 12
	add_child(holder)
	holder.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.name = "Center"
	overlay.add_child(center)
	return overlay


func _make_toast() -> PanelContainer:
	_toast = _build_pill(Palette.TEAL, 24, Palette.PAPER)
	_toast_label = _toast.get_child(0) as Label
	_toast.modulate.a = 0.0
	return _toast


func _make_warning() -> Label:
	_warning = _label("", HEADING_FONT, 44, Palette.GOLD)
	_warning.add_theme_color_override("font_outline_color", Palette.EDGE)
	_warning.add_theme_constant_override("outline_size", 12)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_warning.modulate.a = 0.0
	return _warning


func _make_countdown() -> void:
	_countdown = _label("", HEADING_FONT, 140, Palette.PAPER)
	_countdown.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_countdown.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_countdown.grow_vertical = Control.GROW_DIRECTION_BOTH
	_countdown.add_theme_color_override("font_outline_color", Palette.PILL)
	_countdown.add_theme_constant_override("outline_size", 24)
	_countdown.hide()
	add_child(_countdown)


func _make_end(retry_text: String) -> void:
	_end = _overlay(0.5)
	var card := PanelContainer.new()
	var style := _card_style(0.97)
	style.set_corner_radius_all(36)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 30
	style.content_margin_bottom = 34
	card.add_theme_stylebox_override("panel", style)
	_end.get_node("Center").add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiKit.STACK_GAP)
	card.add_child(box)
	_end_title = _label("", HEADING_FONT, 50, Palette.INK)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_title)
	_end_message = _label("", BODY_FONT, 22, Palette.INK_SOFT)
	_end_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_message.custom_minimum_size = Vector2(560, 0)
	box.add_child(_end_message)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)
	_end_first_button = UiKit.game_button(retry_text)
	_end_first_button.pressed.connect(retry_requested.emit)
	box.add_child(_end_first_button)
	var menu_button := UiKit.game_button("VOLVER AL MENÚ", false)
	menu_button.pressed.connect(menu_requested.emit)
	box.add_child(menu_button)
