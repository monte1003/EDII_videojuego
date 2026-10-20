class_name LevelHud
extends RoundHud

signal help_requested

var _dots: HBoxContainer
var _dot_styles: Array[StyleBoxFlat] = []
var _protection: PanelContainer
var _protection_label: Label
var _prompt: PanelContainer
var _prompt_label: RichTextLabel
var _chips: Dictionary = {}
var _debug_panel: PanelContainer
var _debug_label: RichTextLabel


func _ready() -> void:
	super()
	var root := _make_root(22)

	var top := _hbox()
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(top)
	top.add_child(_build_status_card())
	var top_center := _vbox(8)
	top_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_center)
	top_center.add_child(_make_toast())
	_protection = _build_pill(Palette.AMBER, 22, Palette.PAPER)
	_protection_label = _protection.get_child(0) as Label
	_protection.hide()
	top_center.add_child(_protection)
	top_center.add_child(_make_warning())
	_debug_panel = _build_debug_panel()
	#On the right under the top bar, so it never squeezes the toasts
	var side := MarginContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_theme_constant_override("margin_top", 120)
	root.add_child(side)
	_debug_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_debug_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side.add_child(_debug_panel)

	var bottom := _vbox(10)
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
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

	_make_countdown()
	_make_end("REINTENTAR NIVEL")
	_make_pause_actions([["AYUDA", help_requested], ["REINTENTAR NIVEL", retry_requested]])
	_build_help_button()


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


func set_debug_visible(shown: bool) -> void:
	_debug_panel.visible = shown


func set_debug_text(markup: String) -> void:
	_debug_label.text = markup


func _build_status_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override("panel", _card_style())
	var row := _hbox(16)
	card.add_child(row)
	_timer_label = _label("2:00", HEADING_FONT, 46, Palette.INK)
	_timer_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(_timer_label)
	var column := _vbox()
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
	var row := _hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
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
		var box := _vbox()
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
