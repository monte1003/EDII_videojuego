class_name LevelHud
extends CanvasLayer

signal help_requested
signal retry_requested
signal menu_requested

const TEXT_BUTTON := preload("res://scenes/ui/text_button.tscn")
const HEADING_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
const BODY_FONT: Font = preload("res://assets/ui/fonts/body_font.tres")
const LILAC := Color("cdbcf7")

var _timer_label: Label
var _dots: HBoxContainer
var _dot_styles: Array[StyleBoxFlat] = []
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _warning: Label
var _protection: PanelContainer
var _protection_label: Label
var _prompt: PanelContainer
var _prompt_label: RichTextLabel
var _countdown: Label
var _chips: Dictionary = {}
var _debug_panel: PanelContainer
var _debug_label: RichTextLabel
var _end: Control
var _end_title: Label
var _end_message: Label
var _end_first_button: TextButton
var _pause_actions: Control


func _ready() -> void:
	layer = 5
	var root := MarginContainer.new()
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
	_protection = _build_pill(Palette.AMBER, 22, Palette.PAPER)
	_protection_label = _protection.get_child(0) as Label
	_protection.hide()
	top_center.add_child(_protection)
	_warning = Label.new()
	_warning.add_theme_font_override("font", HEADING_FONT)
	_warning.add_theme_font_size_override("font_size", 44)
	_warning.add_theme_color_override("font_color", Color("ffd23f"))
	_warning.add_theme_color_override("font_outline_color", Color("2a2145"))
	_warning.add_theme_constant_override("outline_size", 12)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_warning.modulate.a = 0.0
	top_center.add_child(_warning)
	_debug_panel = _build_debug_panel()
	#The debug panel sits on the right under the top bar so it never squeezes the toasts
	var side := MarginContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_theme_constant_override("margin_top", 120)
	root.add_child(side)
	_debug_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_debug_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side.add_child(_debug_panel)

	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	_prompt = _build_pill(Palette.INK, 22, Palette.PAPER)
	_prompt.get_child(0).queue_free()
	_prompt_label = RichTextLabel.new()
	_prompt_label.bbcode_enabled = true
	_prompt_label.fit_content = true
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_prompt_label.scroll_active = false
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.add_theme_font_override("normal_font", HEADING_FONT)
	_prompt_label.add_theme_font_size_override("normal_font_size", 24)
	_prompt_label.add_theme_color_override("default_color", Palette.PAPER)
	_prompt.add_child(_prompt_label)
	_prompt.hide()
	bottom.add_child(_prompt)
	bottom.add_child(_build_chips())

	_countdown = Label.new()
	_countdown.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_countdown.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_countdown.grow_vertical = Control.GROW_DIRECTION_BOTH
	_countdown.add_theme_font_override("font", HEADING_FONT)
	_countdown.add_theme_font_size_override("font_size", 140)
	_countdown.add_theme_color_override("font_color", Palette.PAPER)
	_countdown.add_theme_color_override("font_outline_color", Palette.PILL)
	_countdown.add_theme_constant_override("outline_size", 24)
	_countdown.hide()
	add_child(_countdown)

	_end = _build_end()
	_pause_actions = _build_pause_actions()
	_build_help_button()


#---- public API ------------------------------------------------------------------------

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
	_timer_label.add_theme_color_override("font_color", Palette.CORAL if whole <= 20 else Palette.INK)


func set_attempts(left: int, total: int) -> void:
	for index in _dot_styles.size():
		_dot_styles[index].bg_color = Palette.PILL if index < left else Color(Palette.INK, 0.18)
	_dots.tooltip_text = "%d de %d intentos" % [left, total]


func set_ability(id: StringName, status: String, available: bool) -> void:
	var chip: Dictionary = _chips[id]
	(chip["status"] as Label).text = status
	(chip["style"] as StyleBoxFlat).border_color = Palette.TEAL if available else Color(Palette.INK, 0.25)


func show_prompt(markup: String) -> void:
	_prompt_label.text = markup
	_prompt.show()


func hide_prompt() -> void:
	_prompt.hide()


func show_protection(text: String) -> void:
	_protection_label.text = text
	_protection.show()


func hide_protection() -> void:
	_protection.hide()


func toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(3.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


#A short flash for the dodge warning
func warn(text: String) -> void:
	_warning.text = text
	_warning.modulate.a = 1.0
	create_tween().tween_property(_warning, "modulate:a", 0.0, 0.9).set_delay(0.5)


func set_debug_visible(shown: bool) -> void:
	_debug_panel.visible = shown


func set_debug_text(markup: String) -> void:
	_debug_label.text = markup


func show_end(title: String, message: String, victory: bool) -> void:
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", Palette.TEAL if victory else Palette.CORAL)
	_end_message.text = message
	_end.show()
	_end_first_button.grab_focus()


func show_pause_actions(shown: bool) -> void:
	_pause_actions.visible = shown


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


func _build_status_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override("panel", _card_style())
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	_timer_label = _label("2:00", HEADING_FONT, 46, Palette.INK)
	_timer_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(_timer_label)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	column.add_child(_label("INTENTOS", HEADING_FONT, 18, Palette.INK_SOFT))
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 8)
	column.add_child(_dots)
	for index in 3:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 18)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := _box(Palette.PILL, 9)
		dot.add_theme_stylebox_override("panel", style)
		_dots.add_child(dot)
		_dot_styles.append(style)
	return card


func _build_chips() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for entry in [[&"block", "BLOQUEAR (isla E)"], [&"silence", "SILENCIAR (isla F)"], [&"pause", "PAUSA DIGITAL (isla D)"]]:
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := _card_style(0.9)
		style.set_corner_radius_all(22)
		style.content_margin_top = 6
		style.content_margin_bottom = 8
		style.shadow_size = 6
		style.set_border_width_all(3)
		style.border_color = Color(Palette.INK, 0.25)
		chip.add_theme_stylebox_override("panel", style)
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(box)
		box.add_child(_label(entry[1], HEADING_FONT, 20, Palette.INK))
		var status := _label("", BODY_FONT, 18, Palette.INK_SOFT)
		box.add_child(status)
		row.add_child(chip)
		_chips[entry[0]] = {"status": status, "style": style}
	return row


func _build_debug_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := _card_style(0.92)
	style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", style)
	_debug_label = _rich(18, Palette.INK)
	_debug_label.custom_minimum_size = Vector2(330, 0)
	panel.add_child(_debug_label)
	panel.hide()
	return panel


func _make_button(text: String, on_pressed: Signal) -> TextButton:
	var button := TEXT_BUTTON.instantiate() as TextButton
	button.text = text
	button.custom_minimum_size = Vector2(380, 56)
	button.pressed.connect(on_pressed.emit)
	return button


func _overlay(alpha: float) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.06, 0.05, 0.14, alpha)
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


func _build_end() -> Control:
	var overlay := _overlay(0.5)
	var card := PanelContainer.new()
	var style := _card_style(0.97)
	style.set_corner_radius_all(36)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 30
	style.content_margin_bottom = 34
	card.add_theme_stylebox_override("panel", style)
	overlay.get_node("Center").add_child(card)
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
	_end_first_button = _make_button("REINTENTAR NIVEL", retry_requested)
	box.add_child(_end_first_button)
	box.add_child(_make_button("VOLVER AL MENÚ", menu_requested))
	return overlay


#Extra action that appears under the pause menu's own exit button
func _build_pause_actions() -> Control:
	var holder := CanvasLayer.new()
	holder.layer = 11
	add_child(holder)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -200.0
	box.offset_right = 200.0
	box.offset_top = 56.0
	box.offset_bottom = 190.0
	box.hide()
	holder.add_child(box)
	for entry in [["AYUDA", help_requested], ["REINTENTAR NIVEL", retry_requested]]:
		var button := _make_button(entry[0], entry[1])
		box.add_child(button)
		#The button script sets dark text on load; the pause backdrop is dark
		button.add_theme_color_override("font_color", Palette.PAPER)
	return box


#A round "?" in the corner; it can be clicked whenever the mouse is free (pause menu)
func _build_help_button() -> void:
	var holder := CanvasLayer.new()
	holder.layer = 11
	add_child(holder)
	var button := Button.new()
	button.text = "?"
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -84.0
	button.offset_right = -24.0
	button.offset_top = 22.0
	button.offset_bottom = 82.0
	var look := _box(Palette.PILL, 30)
	look.set_border_width_all(3)
	look.border_color = Palette.PAPER
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, look)
	button.add_theme_font_override("font", HEADING_FONT)
	button.add_theme_font_size_override("font_size", 36)
	button.add_theme_color_override("font_color", Palette.PAPER)
	button.add_theme_color_override("font_hover_color", Palette.PAPER)
	button.add_theme_color_override("font_pressed_color", Palette.PAPER)
	button.pressed.connect(help_requested.emit)
	holder.add_child(button)
	var hint := _label("%s · Ayuda" % InputHints.key_label(&"help"), HEADING_FONT, 16, Palette.PAPER)
	hint.add_theme_color_override("font_outline_color", Palette.INK)
	hint.add_theme_constant_override("outline_size", 8)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -120.0
	hint.offset_right = -14.0
	hint.offset_top = 84.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(hint)
