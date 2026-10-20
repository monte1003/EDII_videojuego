class_name TutorialHud
extends RoundHud

signal skip_requested
signal continue_requested

var _total := 0
var _dot_styles: Array[StyleBoxFlat] = []

var _badge_label: Label
var _title_label: Label
var _body_label: RichTextLabel
var _dots: HBoxContainer
var _finish_panel: Control
var _continue_button: TextButton
var _first_finish_button: TextButton


func _ready() -> void:
	super()
	toast_hold = 1.6
	toast_fade = 0.4
	var root := _make_root(24)

	var column := _vbox(10)
	root.add_child(column)

	column.add_child(_build_card())
	_dots = _hbox(8)
	_dots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_dots)
	column.add_child(_make_toast())

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(_build_hint())

	_make_pause_actions([["REINTENTAR TUTORIAL", retry_requested], ["OMITIR TUTORIAL", skip_requested]], 6)
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


func show_finish(can_continue: bool, continue_text := "CONTINUAR") -> void:
	_continue_button.text = continue_text
	_continue_button.visible = can_continue
	_finish_panel.show()
	if can_continue:
		_continue_button.grab_focus()
	else:
		_first_finish_button.grab_focus()


func _build_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := _box(Color(Palette.PAPER, 0.94), 30)
	style.set_border_width_all(2)
	style.border_color = Palette.LILAC
	style.content_margin_left = 22
	style.content_margin_right = 28
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	style.shadow_size = 14
	style.shadow_color = Color(Palette.INK, 0.25)
	card.add_theme_stylebox_override("panel", style)

	var row := _hbox(18)
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
	_badge_label = _label("1/4", HEADING_FONT, 26, Palette.PAPER)
	badge.add_child(_badge_label)
	row.add_child(badge)

	var texts := _vbox()
	row.add_child(texts)
	_title_label = _label("", HEADING_FONT, 30, Palette.INK)
	texts.add_child(_title_label)
	_body_label = _rich(22, Palette.INK_SOFT)
	_body_label.custom_minimum_size = Vector2(520, 0)
	texts.add_child(_body_label)
	return card


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
	hint.add_child(_label("Esc  ·  Reintentar, omitir o salir", BODY_FONT, 18, Palette.PAPER))
	return hint


func _build_finish_panel() -> Control:
	var overlay := _overlay(0.45)
	var card := PanelContainer.new()
	var style := _box(Color(Palette.PAPER, 0.97), 36)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 32
	style.content_margin_bottom = 36
	style.shadow_size = 20
	style.shadow_color = Color(Palette.INK, 0.35)
	card.add_theme_stylebox_override("panel", style)
	overlay.get_node("Center").add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var title := _label("¡Ya estás listo!", HEADING_FONT, 54, Palette.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := _label("Completaste las cuatro zonas.", BODY_FONT, 24, Palette.INK_SOFT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	_continue_button = _make_button("CONTINUAR", continue_requested)
	box.add_child(_continue_button)
	_first_finish_button = _make_button("REPETIR TUTORIAL", retry_requested)
	box.add_child(_first_finish_button)
	box.add_child(_make_button("VOLVER AL MENÚ", menu_requested))
	return overlay
