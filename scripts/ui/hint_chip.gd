class_name HintChip
extends PanelContainer

#Key cap of an action: the key on keyboard, the DualSense button on pad; switches by itself

var _action: StringName
var _size := 20
var _keys_text := ""


#"keys_text" shows on the keyboard; a tail like " x2" also shows on the pad
func _init(action: StringName, size_points := 20, keys_text := "") -> void:
	_action = action
	_size = size_points
	_keys_text = keys_text if keys_text != "" else InputHints.entry_label(action)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	InputDevice.changed.connect(_on_device_changed)
	_fill()


func _on_device_changed(_kind: int) -> void:
	_fill()


func _fill() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var button := InputHints.pad_of(_action)
	if not InputHints.uses_pad() or button.is_empty():
		add_theme_stylebox_override("panel", UiKit.key_cap())
		add_child(UiKit.label(_keys_text, UiKit.HEADING_FONT, _size, Palette.INK))
		return
	var bare := StyleBoxEmpty.new()
	bare.content_margin_left = 2
	bare.content_margin_right = 4
	add_theme_stylebox_override("panel", bare)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	if button.has("text"):
		row.add_child(_word_button(button["text"]))
	else:
		row.add_child(PadGlyph.new(button, _size))
	var tail := _keys_text.find(" ×")
	if tail >= 0:
		var count := UiKit.label(_keys_text.substr(tail + 1), UiKit.HEADING_FONT, _size, Palette.PAPER)
		count.add_theme_color_override("font_outline_color", Color(Palette.NIGHT, 0.88))
		count.add_theme_constant_override("outline_size", maxi(roundi(_size / 5.0), 3))
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(count)
	reset_size()


#Dark pill with a printed word (R1, OPTIONS)
func _word_button(word: String) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiKit.box(PadGlyph.BODY, 120)
	style.content_margin_left = 11
	style.content_margin_right = 11
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", style)
	pill.add_child(UiKit.label(word, UiKit.HEADING_FONT, _size, Palette.PAPER))
	return pill
