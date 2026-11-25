class_name NameKeyboard
extends CanvasLayer

#On-screen keyboard for the name with the pad: square deletes, triangle spaces, Options accepts

signal accepted(text: String)
signal cancelled

const ROWS: Array[String] = ["1234567890", "QWERTYUIOP", "ASDFGHJKLÑ", "ZXCVBNM.-_"]
const KEY_SIZE := Vector2(56, 50)
const GAP := 7
#Bottom row in columns of the rows above
const WIDE_KEYS := [["ESPACIO", 4], ["BORRAR", 3], ["LISTO", 3]]

var _text := ""
var _limit := 12
var _root: ColorRect
var _card: PanelContainer
var _shown: Label
var _caret: ColorRect
var _count: Label
var _keys: Array[Array] = []
var _wide: Array[Button] = []
var _pad_only: Array[Control] = []
var _clock := 0.0
var _tween: Tween


func _init() -> void:
	layer = 30
	visible = false


func _ready() -> void:
	_build()
	_link_keys()
	InputDevice.changed.connect(_on_device_changed)
	_on_device_changed(0)


func is_open() -> bool:
	return visible


#Opens with the current name; "limit" is the most letters
func open(text: String, limit: int) -> void:
	_limit = limit
	_text = text.strip_edges().to_upper().left(limit)
	_refresh()
	visible = true
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2.ONE * 0.96
	_root.modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_root, "modulate:a", 1.0, 0.18)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.22)
	(_keys[1][0] as Button).grab_focus()


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_caret.modulate.a = 1.0 if fmod(_clock, 1.0) < 0.55 else 0.0


#Real keyboard keys and pad buttons with their own job go first
func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	var key := event as InputEventKey
	if key != null:
		match key.keycode:
			KEY_BACKSPACE:
				_erase()
			KEY_ENTER, KEY_KP_ENTER:
				_accept()
			KEY_ESCAPE:
				_cancel()
			_:
				if key.unicode < 32:
					return
				_write(char(key.unicode))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton:
		if event.is_action("shove"):
			_erase()
		elif event.is_action("help"):
			_write(" ")
		elif event.is_action("pause"):
			_accept()
		elif event.is_action("menu_back"):
			_cancel()
		else:
			return
		get_viewport().set_input_as_handled()


#Nothing behind hears the keys while open
func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _write(letter: String) -> void:
	if _text.length() >= _limit:
		_shake()
		return
	_text += letter.to_upper()
	_refresh()
	_shown.scale = Vector2.ONE * 1.06
	create_tween().tween_property(_shown, "scale", Vector2.ONE, 0.12)


func _erase() -> void:
	if _text.is_empty():
		return
	_text = _text.left(_text.length() - 1)
	UiSound.play_click()
	_refresh()


func _accept() -> void:
	UiSound.play_click()
	_close()
	accepted.emit(_text.strip_edges())


func _cancel() -> void:
	_close()
	cancelled.emit()


func _close() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	visible = false


func _refresh() -> void:
	_shown.text = _text
	_count.text = "%d/%d" % [_text.length(), _limit]
	_count.add_theme_color_override("font_color", Palette.CORAL if _text.length() >= _limit else Palette.INK_SOFT)


#The name is full: the card shakes
func _shake() -> void:
	var base := _card.position
	var shake := create_tween()
	for step in [10.0, -8.0, 5.0, 0.0]:
		shake.tween_property(_card, "position:x", base.x + step, 0.04)


func _on_device_changed(_kind: int) -> void:
	for node in _pad_only:
		node.visible = InputHints.uses_pad()


func _build() -> void:
	_root = ColorRect.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.color = Color(Palette.NIGHT, 0.62)
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_card = PanelContainer.new()
	var style := UiKit.card_style(0.98, 36)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_card.add_theme_stylebox_override("panel", style)
	center.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	_card.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	var title := UiKit.label("TU NOMBRE", UiKit.BUTTON_FONT, 13, Palette.INK_SOFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_count = UiKit.label("", UiKit.BUTTON_FONT, 13, Palette.INK_SOFT)
	top.add_child(_count)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	line.custom_minimum_size = Vector2(0, 58)
	column.add_child(line)
	_shown = UiKit.label("", UiKit.BOLD_FONT, 40, Palette.INK)
	_shown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(_shown)
	_caret = ColorRect.new()
	_caret.color = Palette.CORAL
	_caret.custom_minimum_size = Vector2(3, 38)
	_caret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_caret)
	var rule := ColorRect.new()
	rule.color = Palette.CORAL
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	var space := Control.new()
	space.custom_minimum_size = Vector2(0, 10)
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(space)

	for row_text in ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", GAP)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(row)
		var keys: Array = []
		for letter in row_text:
			var key := _key(letter, KEY_SIZE.x, false)
			key.pressed.connect(_write.bind(letter))
			row.add_child(key)
			keys.append(key)
		_keys.append(keys)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", GAP)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(bottom)
	for index in WIDE_KEYS.size():
		var columns: int = WIDE_KEYS[index][1]
		var key := _key(WIDE_KEYS[index][0], KEY_SIZE.x * columns + GAP * (columns - 1), index == 2)
		key.add_theme_font_size_override("font_size", 15)
		bottom.add_child(key)
		_wide.append(key)
	_wide[0].pressed.connect(_write.bind(" "))
	_wide[1].pressed.connect(_erase)
	_wide[2].pressed.connect(_accept)

	var hints := HBoxContainer.new()
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	hints.add_theme_constant_override("separation", 22)
	hints.custom_minimum_size = Vector2(0, 44)
	column.add_child(hints)
	for hint in [[&"shove", "RETROCESO", "BORRAR", false], [&"help", "", "ESPACIO", true], [&"pause", "ENTER", "LISTO", false],
			[&"menu_back", "ESC", "VOLVER", false]]:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 8)
		pair.alignment = BoxContainer.ALIGNMENT_CENTER
		pair.add_child(UiKit.action_chip(hint[0], 14, hint[1]))
		var word := UiKit.label(hint[2], UiKit.BUTTON_FONT, 12, Palette.INK_SOFT)
		word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pair.add_child(word)
		hints.add_child(pair)
		if hint[3]:
			_pad_only.append(pair)


#Key with a hint cap; selected it fills coral and grows
func _key(text: String, width: float, main: bool) -> Button:
	var key := Button.new()
	key.text = text
	key.custom_minimum_size = Vector2(width, KEY_SIZE.y)
	key.focus_mode = Control.FOCUS_ALL
	key.add_theme_font_override("font", UiKit.BUTTON_FONT)
	key.add_theme_font_size_override("font_size", 19)
	var rest := UiKit.key_cap()
	if main:
		rest.bg_color = Palette.PILL
		rest.border_color = Palette.PILL.darkened(0.18)
	var lit := UiKit.key_cap()
	lit.bg_color = Palette.PILL.lightened(0.08 if main else 0.0)
	lit.border_color = Palette.PILL.darkened(0.22)
	var down := lit.duplicate() as StyleBoxFlat
	down.border_width_bottom = 2
	down.content_margin_top = 4
	key.add_theme_stylebox_override("normal", rest)
	key.add_theme_stylebox_override("hover", lit)
	key.add_theme_stylebox_override("focus", lit)
	key.add_theme_stylebox_override("pressed", down)
	key.add_theme_stylebox_override("hover_pressed", down)
	key.add_theme_color_override("font_color", Palette.PAPER if main else Palette.INK)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		key.add_theme_color_override(state, Palette.PAPER)
	key.pressed.connect(UiSound.play_click)
	key.focus_entered.connect(_grow.bind(key, 1.08))
	key.focus_exited.connect(_grow.bind(key, 1.0))
	key.resized.connect(func() -> void: key.pivot_offset = key.size / 2.0)
	return key


func _grow(key: Button, scale_to: float) -> void:
	if scale_to > 1.0:
		UiSound.play_hover()
	create_tween().tween_property(key, "scale", Vector2.ONE * scale_to, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


#Each key knows its four neighbours, wrapping, so the d-pad never leaves the keyboard
func _link_keys() -> void:
	var count: int = ROWS[0].length()
	var under: Array[Button] = []
	for index in WIDE_KEYS.size():
		for column in int(WIDE_KEYS[index][1]):
			under.append(_wide[index])
	for row in _keys.size():
		for column in count:
			var key: Button = _keys[row][column]
			_point(key, SIDE_LEFT, _keys[row][posmod(column - 1, count)])
			_point(key, SIDE_RIGHT, _keys[row][posmod(column + 1, count)])
			_point(key, SIDE_TOP, under[column] if row == 0 else _keys[row - 1][column])
			_point(key, SIDE_BOTTOM, under[column] if row == _keys.size() - 1 else _keys[row + 1][column])
	var first := 0
	for index in _wide.size():
		var columns: int = WIDE_KEYS[index][1]
		var middle := first + floori(columns / 2.0)
		_point(_wide[index], SIDE_LEFT, _wide[posmod(index - 1, _wide.size())])
		_point(_wide[index], SIDE_RIGHT, _wide[posmod(index + 1, _wide.size())])
		_point(_wide[index], SIDE_TOP, _keys[_keys.size() - 1][middle])
		_point(_wide[index], SIDE_BOTTOM, _keys[0][middle])
		first += columns


func _point(key: Button, side: Side, other: Control) -> void:
	key.set_focus_neighbor(side, key.get_path_to(other))
