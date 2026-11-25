class_name FairMenu
extends CanvasLayer

#Staff menu on the fair screen (Esc); removing a name asks once more

signal name_removed(shown: String)
signal leave_requested
signal quit_requested

var ranking: FairRanking

var _stack: VBoxContainer


func _ready() -> void:
	layer = 60
	hide()
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(Palette.NIGHT, 0.85)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 4)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_stack)


func open() -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_main()


func close() -> void:
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _show_main() -> void:
	_clear()
	_title("PANTALLA DE FERIA")
	var first := _option("CONTINUAR", Palette.PILL, close)
	_option("QUITAR UN NOMBRE DEL RANKING", Palette.TEAL, _show_names.bind(""))
	_option("SALIR AL MENÚ PRINCIPAL", Palette.AMBER, leave_requested.emit)
	_option("CERRAR EL JUEGO", Palette.CORAL, quit_requested.emit)
	first.grab_focus()


#Every ranking name, best first; picking one asks first
func _show_names(notice: String) -> void:
	_clear()
	_title("QUITAR UN NOMBRE DEL RANKING")
	if notice != "":
		var said := UiKit.label(notice, UiKit.BUTTON_FONT, 18, Palette.GOLD)
		said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stack.add_child(said)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stack.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var order := ranking.ordered() if ranking != null else ([] as Array[Dictionary])
	if order.is_empty():
		var empty := UiKit.label("Todavía no hay nombres en el ranking.", UiKit.BODY_FONT, 20, Color(Palette.PAPER, 0.8))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)
	var first: TextButton
	for index in order.size():
		var entry := order[index]
		var row := UiKit.text_button("%d. %s · %d" % [index + 1, str(entry["name"]), int(entry["total"])], Palette.TEAL, 22)
		row.light = true
		row.pressed.connect(_confirm.bind(str(entry["name"]), int(entry["total"])))
		list.add_child(row)
		if first == null:
			first = row
	var back := _option("VOLVER", Palette.PILL, _show_main)
	(first if first != null else back).grab_focus()


func _confirm(shown: String, total: int) -> void:
	_clear()
	_title("¿QUITAR A %s (%d) DEL RANKING?" % [shown.to_upper(), total])
	var keep := _option("NO, VOLVER", Palette.PILL, _show_names.bind(""))
	_option("SÍ, QUITARLO", Palette.CORAL, _remove.bind(shown))
	keep.grab_focus()


func _remove(shown: String) -> void:
	if ranking != null and ranking.remove(shown):
		name_removed.emit(shown)
	_show_names("%s SALIÓ DEL RANKING" % shown.to_upper())


func _clear() -> void:
	for child in _stack.get_children():
		_stack.remove_child(child)
		child.queue_free()


func _title(text: String) -> void:
	var title := UiKit.label(text, UiKit.BUTTON_FONT, 20, Color(Palette.PAPER, 0.75))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stack.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(gap)


func _option(text: String, accent: Color, action: Callable) -> TextButton:
	var button := UiKit.text_button(text, accent, 26)
	button.light = true
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	_stack.add_child(button)
	return button
