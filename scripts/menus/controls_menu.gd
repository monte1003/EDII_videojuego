extends MenuPage

const ROWS := [
	["Caminar", "WASD"],
	["Saltar", "ESPACIO"],
	["Mover la cámara", "MOUSE"],
]
#Keys that only work inside the levels; they follow the Input Map
const ACTION_ROWS := [
	["Interactuar", &"interact"],
	["Ayuda", &"help"],
	["Ver el grafo", &"toggle_debug"],
	["Demostrar la ruta", &"demo_route"],
]


func _ready() -> void:
	super()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for row in ROWS:
		_add_row(grid, row[0], row[1])
	for row in ACTION_ROWS:
		_add_row(grid, row[0], InputHints.key_label(row[1]))


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
