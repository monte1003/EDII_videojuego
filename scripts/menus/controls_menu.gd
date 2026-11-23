extends MenuPage

#What each row does, its key on the keyboard and its action, which names the pad button
const ROWS := [
	["Caminar", "WASD", &"move"],
	["Saltar", "ESPACIO", &"jump"],
	["Barrer (en el aire)", "ESPACIO ×2", &"jump"],
	["Mover la cámara", "MOUSE", &"look"],
]
#Keys that only work inside the levels; they follow the Input Map
const ACTION_ROWS := [
	["Usar o posar (alterna)", &"interact"],
	["Empujar", &"shove"],
	["Estoy listo", &"ready"],
	["Ayuda", &"help"],
	["Ver el grafo", &"toggle_debug"],
	["Demostrar la ruta", &"demo_route"],
]


var _grid: GridContainer


func _ready() -> void:
	super()
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 40)
	_grid.add_theme_constant_override("v_separation", 12)
	content.add_child(_grid)
	_fill()
	InputDevice.changed.connect(_on_device_changed)


#The keys of the keyboard, or the buttons of the pad while it is in use
func _fill() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for row in ROWS:
		var key: String = row[1]
		if InputHints.uses_pad():
			key = InputHints.spoken(row[2]) + (" ×2" if key.ends_with("×2") else "")
		_add_row(_grid, row[0], key)
	for row in ACTION_ROWS:
		_add_row(_grid, row[0], InputHints.spoken(row[1]))


func _on_device_changed(_kind: int) -> void:
	_fill()


func _add_row(grid: GridContainer, action_name: String, key_name: String) -> void:
	grid.add_child(_make_label(action_name, FONT, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT))
	grid.add_child(_make_label(key_name, KEY_FONT, Palette.TEAL, HORIZONTAL_ALIGNMENT_RIGHT))


func _make_label(text: String, font: Font, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
