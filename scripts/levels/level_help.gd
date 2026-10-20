class_name LevelHelp
extends CanvasLayer

#Help of a round with a fixed-size card, so the buttons never move between pages

signal finished

const CARD_WIDTH := 760.0
const BODY_HEIGHT := 300.0
const BUTTON_WIDTH := 230.0

var _pages: Array[Dictionary] = []
var _page := 0

var _root: ColorRect
var _title: Label
var _body: RichTextLabel
var _pips: HBoxContainer
var _previous: GameButton
var _next: GameButton


func _ready() -> void:
	layer = 13
	_build()
	_root.hide()


func setup(pages: Array[Dictionary]) -> void:
	_pages = pages
	for child in _pips.get_children():
		child.queue_free()
	for index in pages.size():
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(14, 14)
		_pips.add_child(pip)


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if _pages.is_empty():
		return
	_page = 0
	_show_page()
	_root.show()
	_next.grab_focus()


func close() -> void:
	_root.hide()
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed("menu_right"):
		_go(1)
	elif event.is_action_pressed("menu_left"):
		_go(-1)
	elif event.is_action_pressed("pause") or event.is_action_pressed("help"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _go(step: int) -> void:
	var target := _page + step
	if target >= _pages.size():
		close()
	elif target >= 0:
		_page = target
		_show_page()


func _show_page() -> void:
	var page := _pages[_page]
	_title.text = page["title"]
	_body.text = page["body"]
	var first := _page == 0
	_previous.modulate.a = 0.0 if first else 1.0
	_previous.disabled = first
	_previous.focus_mode = Control.FOCUS_NONE if first else Control.FOCUS_ALL
	_next.set_caption("LISTO" if _page == _pages.size() - 1 else "SIGUIENTE")
	for index in _pips.get_child_count():
		var color := Palette.CORAL if index == _page else Color(Palette.INK, 0.2)
		(_pips.get_child(index) as Panel).add_theme_stylebox_override("panel", UiKit.box(color, 7))


func _build() -> void:
	_root = ColorRect.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.color = Color(Palette.NIGHT, 0.6)
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var card := PanelContainer.new()
	var style := UiKit.card_style(0.98, 36)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 22
	style.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.add_child(box)

	_title = UiKit.heading("", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(0, BODY_HEIGHT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_font_override("normal_font", UiKit.BODY_FONT)
	_body.add_theme_font_size_override("normal_font_size", 22)
	_body.add_theme_color_override("default_color", Palette.INK)
	_body.add_theme_constant_override("line_separation", 4)
	box.add_child(_body)

	_pips = HBoxContainer.new()
	_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	_pips.add_theme_constant_override("separation", 10)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_pips)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	_previous = UiKit.game_button("ANTERIOR", false, BUTTON_WIDTH, false, 20)
	_previous.pressed.connect(_go.bind(-1))
	row.add_child(_previous)
	_next = UiKit.game_button("SIGUIENTE", true, BUTTON_WIDTH, false, 20)
	_next.pressed.connect(_go.bind(1))
	row.add_child(_next)
