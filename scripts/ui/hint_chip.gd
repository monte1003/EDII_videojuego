class_name HintChip
extends PanelContainer

#The cap of a control hint for one action: the key while the keyboard is in use, the DualSense button while the pad is, drawn as
#PlayStation games show it. It changes by itself when the player picks up the other device; on the keyboard it looks exactly like the
#key caps of before

var _action: StringName
var _size := 20
var _keys_text := ""


#"keys_text" is what shows on the keyboard (the key of the action when empty); a tail like " ×2" also shows next to the pad button
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


#A button with a word printed on it (R1, OPTIONS): a dark pill with light letters, like the round buttons
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
