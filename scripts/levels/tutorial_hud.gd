class_name TutorialHud
extends CanvasLayer

signal retry_requested
signal skip_requested
signal menu_requested
signal continue_requested

const TEXT_BUTTON := preload("res://scenes/ui/text_button.tscn")
const HEADING_FONT: Font = preload("res://assets/ui/fonts/heading_font.tres")
const BODY_FONT: Font = preload("res://assets/ui/fonts/body_font.tres")

var _total := 0
var _dot_styles: Array[StyleBoxFlat] = []
var _toast_tween: Tween

var _badge_label: Label
var _title_label: Label
var _body_label: RichTextLabel
var _dots: HBoxContainer
var _toast: PanelContainer
var _toast_label: Label
var _pause_actions: Control
var _finish_panel: Control
var _continue_button: TextButton
var _first_finish_button: TextButton


func _ready() -> void:
	layer = 5
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_top", "margin_bottom", "margin_left", "margin_right"]:
		root.add_theme_constant_override(side, 24)
	add_child(root)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	root.add_child(column)

	column.add_child(_build_card())
	_dots = HBoxContainer.new()
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.add_theme_constant_override("separation", 8)
	_dots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_dots)
	_toast = _build_toast()
	column.add_child(_toast)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(_build_hint())

	_pause_actions = _build_pause_actions()
	_finish_panel = _build_finish_panel()


func setup(step_count: int) -> void:
	_total = step_count
	for i in step_count:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := _box(Palette.INK, 7)
		dot.add_theme_stylebox_override("panel", style)
		_dots.add_child(dot)
		_dot_styles.append(style)


#Wraps a key name so it stands out inside the instruction text
static func key_markup(text: String) -> String:
	return "[color=#%s]%s[/color]" % [Palette.TEAL.to_html(false), text]


func show_step(index: int, title: String, body: String) -> void:
	_badge_label.text = "%d/%d" % [index + 1, _total]
	_title_label.text = title
	_body_label.text = body
	for i in _dot_styles.size():
		var color := Color(Palette.INK, 0.2)
		if i < index:
			color = Palette.TEAL
		elif i == index:
			color = Palette.PILL
		_dot_styles[i].bg_color = color


func toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func show_pause_actions(shown: bool) -> void:
	_pause_actions.visible = shown


func show_finish(can_continue: bool) -> void:
	_continue_button.visible = can_continue
	_finish_panel.show()
	if can_continue:
		_continue_button.grab_focus()
	else:
		_first_finish_button.grab_focus()


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.corner_detail = 12
	return style


func _make_label(text: String, font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text: String, on_pressed: Signal) -> TextButton:
	var button := TEXT_BUTTON.instantiate() as TextButton
	button.text = text
	button.custom_minimum_size = Vector2(380, 56)
	button.pressed.connect(on_pressed.emit)
	return button


func _build_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := _box(Color(Palette.PAPER, 0.94), 30)
	style.set_border_width_all(2)
	style.border_color = Color("cdbcf7")
	style.content_margin_left = 22
	style.content_margin_right = 28
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	style.shadow_size = 14
	style.shadow_color = Color(Palette.INK, 0.25)
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_style := _box(Palette.PILL, 100)
	badge_style.content_margin_left = 18
	badge_style.content_margin_right = 18
	badge_style.content_margin_top = 8
	badge_style.content_margin_bottom = 8
	badge.add_theme_stylebox_override("panel", badge_style)
	_badge_label = _make_label("1/4", HEADING_FONT, 26, Palette.PAPER)
	badge.add_child(_badge_label)
	row.add_child(badge)

	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	_title_label = _make_label("", HEADING_FONT, 30, Palette.INK)
	texts.add_child(_title_label)
	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_label.custom_minimum_size = Vector2(520, 0)
	_body_label.add_theme_font_override("normal_font", BODY_FONT)
	_body_label.add_theme_font_size_override("normal_font_size", 22)
	_body_label.add_theme_color_override("default_color", Palette.INK_SOFT)
	texts.add_child(_body_label)
	return card


func _build_toast() -> PanelContainer:
	var toast_panel := PanelContainer.new()
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toast_panel.modulate.a = 0.0
	var style := _box(Palette.TEAL, 100)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	toast_panel.add_theme_stylebox_override("panel", style)
	_toast_label = _make_label("", HEADING_FONT, 24, Palette.PAPER)
	toast_panel.add_child(_toast_label)
	return toast_panel


func _build_hint() -> PanelContainer:
	var hint := PanelContainer.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := _box(Color(Palette.INK, 0.4), 100)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 4
	style.content_margin_bottom = 6
	hint.add_theme_stylebox_override("panel", style)
	hint.add_child(_make_label("Esc  ·  Reintentar, omitir o salir", BODY_FONT, 18, Palette.PAPER))
	return hint


#Extra actions that appear under the pause menu's own exit button
func _build_pause_actions() -> Control:
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 11
	add_child(menu_layer)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -200.0
	box.offset_right = 200.0
	box.offset_top = 56.0
	box.offset_bottom = 190.0
	box.add_theme_constant_override("separation", 6)
	box.hide()
	menu_layer.add_child(box)
	for entry in [["REINTENTAR TUTORIAL", retry_requested], ["OMITIR TUTORIAL", skip_requested]]:
		var button := _make_button(entry[0], entry[1])
		box.add_child(button)
		#The button script sets its own dark text color on load; here the backdrop is dark
		button.add_theme_color_override("font_color", Palette.PAPER)
	return box


func _build_finish_panel() -> Control:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.06, 0.05, 0.14, 0.45)
	overlay.hide()
	var finish_layer := CanvasLayer.new()
	finish_layer.layer = 12
	add_child(finish_layer)
	finish_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var card := PanelContainer.new()
	var style := _box(Color(Palette.PAPER, 0.97), 36)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 32
	style.content_margin_bottom = 36
	style.shadow_size = 20
	style.shadow_color = Color(Palette.INK, 0.35)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var title := _make_label("¡Ya estás listo!", HEADING_FONT, 54, Palette.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := _make_label("Completaste las cuatro zonas.", BODY_FONT, 24, Palette.INK_SOFT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	_continue_button = _make_button("CONTINUAR", continue_requested)
	box.add_child(_continue_button)
	_first_finish_button = _make_button("REPETIR TUTORIAL", retry_requested)
	box.add_child(_first_finish_button)
	box.add_child(_make_button("VOLVER AL MENÚ", menu_requested))
	return overlay
